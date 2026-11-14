const request = require('supertest');
const app = require('../src/app');
const Business = require('../src/models/Business');
const User = require('../src/models/User');
const Staff = require('../src/models/Staff');
const Subscription = require('../src/models/Subscription');
const access = require('../src/services/entitlementService');
const chotu = require('../src/services/chotu/chotuService');
const gateway = require('../src/services/razorpayService');
const Intent = require('../src/models/SubscriptionPaymentIntent');
const renewal = require('../src/services/subscriptionRenewalService');
const tokenService = require('../src/services/tokenService');
require('./setup');

describe('Business subscription and Chotu access', () => {
  let token, businessId, user;
  const future = () => new Date(Date.now() + 86400000);
  beforeEach(async () => {
    const registration = await request(app).post('/api/v1/auth/register').send({ email: 'access@example.com', password: 'Password@123' });
    token = registration.body.data.accessToken;
    user = await User.findOne({ email: 'access@example.com' });
    businessId = (await Business.findOne({ ownerId: user._id }))._id;
    jest.spyOn(chotu, 'parseVoiceCommand').mockResolvedValue({ command: { intent: 'CHAT' } });
  });
  afterEach(() => jest.restoreAllMocks());
  const api = (method, path, body) => request(app)[method](`/api/v1${path}`).set('Authorization', `Bearer ${token}`).send(body || {});
  const seed = (data) => Business.collection.updateOne({ _id: businessId }, { $set: data });

  test.each([
    ['future enabled', true, () => future(), 200],
    ['future disabled', false, () => future(), 403],
    ['expired', true, () => new Date(Date.now() - 1000), 403],
    ['null expiry', true, () => null, 403],
    ['invalid expiry', true, () => 'bad-date', 403],
    ['ISO string instead of BSON Date', true, () => future().toISOString(), 403],
    ['string flag', 'true', () => future(), 403],
  ])('%s', async (_, enabled, date, expected) => {
    await seed({ isSubscription: enabled, subscriptionExpiresAt: date(), isChotuAiActive: true });
    const result = await api('post', '/chotu/parse', { text: 'hello' });
    expect(result.status).toBe(expected);
    expect(chotu.parseVoiceCommand).toHaveBeenCalledTimes(expected === 200 ? 1 : 0);
  });

  test('missing fields and exact expiry boundary deny', async () => {
    const now = new Date('2026-11-14T12:00:00Z');
    expect(access.evaluate({ isSubscription: true, subscriptionExpiresAt: now, isChotuAiActive: true }, now).chotuAiAccess).toBe(false);
    await Business.collection.updateOne({ _id: businessId }, { $unset: { subscriptionExpiresAt: '', isChotuAiActive: '' }, $set: { isSubscription: true } });
    expect((await api('post', '/chotu/parse', { text: 'hello' })).status).toBe(403);
  });

  test('manual extension restores access with the same token and preserves flag', async () => {
    await seed({ isSubscription: true, subscriptionExpiresAt: new Date(0), isChotuAiActive: true });
    expect((await api('get', '/inventory')).status).toBe(403);
    expect((await api('get', '/subscription/status')).body.data.isActive).toBe(false);
    expect((await Business.collection.findOne({ _id: businessId })).isSubscription).toBe(true);
    await seed({ subscriptionExpiresAt: future() });
    expect((await api('get', '/inventory')).status).toBe(200);
    expect((await api('post', '/chotu/parse', { text: 'hello' })).status).toBe(200);
    const status = (await api('get', '/subscription/status')).body.data;
    expect(status).toMatchObject({ isActive: true, isSubscribed: true, isSubscriptionActive: true, hasInventory: true });
    expect((await api('get', '/auth/me')).body.data.user.subscription.isActive).toBe(true);
    await seed({ isChotuAiActive: false });
    expect((await api('post', '/chotu/parse', { text: 'hello' })).status).toBe(403);
    expect((await api('get', '/inventory')).status).toBe(200);
    await seed({ isSubscription: false });
    expect((await api('get', '/inventory')).status).toBe(403);
    expect((await api('get', '/subscription/status')).status).toBe(200);
    expect((await api('get', '/products')).status).toBe(200); // advertised free POS feature
  });

  test('legacy flags and status reads never grant or write canonical controls', async () => {
    await Subscription.findOneAndUpdate({ businessId }, { $set: { isSubscriptionActive: true, expiresAt: future() } });
    const prior = await Business.collection.findOne({ _id: businessId });
    const count = await Subscription.countDocuments();
    expect((await api('get', '/subscription/status')).body.data.isActive).toBe(false);
    expect(await Subscription.countDocuments()).toBe(count);
    expect((await Business.collection.findOne({ _id: businessId })).subscriptionExpiresAt).toEqual(prior.subscriptionExpiresAt);
  });

  test.each(['/chotu/health', '/chotu/logs', '/chotu/agent/sessions/secret'])('all AI routes deny first: %s', async (path) => {
    expect((await api('get', path)).status).toBe(403);
  });

  test('profile, onboarding and entitlement mass assignment is denied', async () => {
    for (const body of [{ isSubscription: true }, { subscriptionExpiresAt: future().toISOString() }, { isChotuAiActive: true }, { subscription: { isActive: true } }, { 'nested.isChotuAiActive': true }]) {
      expect((await api('put', '/profile', body)).status).toBe(403);
      expect((await api('patch', '/onboarding/business', body)).status).toBe(403);
    }
    expect((await api('patch', '/subscription/status', { isSubscription: true, expiresAt: future().toISOString() })).status).toBe(403);
    expect((await Business.collection.findOne({ _id: businessId })).isSubscription).toBe(false);
  });

  test('anonymous or forged tenant identity does not become an owner session', async () => {
    expect((await request(app).get('/api/v1/subscription/status').set('x-business-id', String(businessId))).status).toBe(401);
    expect((await request(app).get('/api/v1/profile').set('Authorization', 'Bearer forged').set('x-business-id', String(businessId))).status).toBe(401);
    const other = await Business.create({ ownerId: new (require('mongoose').Types.ObjectId)() });
    expect((await request(app).get('/api/v1/profile').set('Authorization', `Bearer ${token}`).set('x-business-id', String(other._id))).status).toBe(403);
    const stranger = await User.create({ email: 'stranger@example.com', passwordHash: 'not-used', role: 'Cashier', businessId });
    const strangerToken = tokenService.generateAccessToken(stranger);
    expect((await request(app).get('/api/v1/profile').set('Authorization', `Bearer ${strangerToken}`)).status).toBe(403);
  });

  test('staff membership works but POS permission is required for Chotu', async () => {
    await seed({ isSubscription: true, subscriptionExpiresAt: future(), isChotuAiActive: true });
    const member = await User.create({ email: 'member@example.com', passwordHash: 'not-used', role: 'Cashier', businessId });
    await Staff.create({ userId: member._id, businessId, name: 'Member', role: 'Cashier', permissions: [] });
    const response = await request(app).post('/api/v1/chotu/parse').set('Authorization', `Bearer ${tokenService.generateAccessToken(member)}`).send({ text: 'hello' });
    expect(response.status).toBe(403);
  });

  test('background AI entry cannot bypass revocation with a stale business object', async () => {
    const ai = require('../src/services/aiAgentService');
    const build = jest.spyOn(ai, 'buildBusinessContext');
    await expect(ai.generateReply({ business: { _id: businessId, isSubscription: true, isChotuAiActive: true }, messageText: 'hello' })).rejects.toMatchObject({ code: 'SUBSCRIPTION_REQUIRED' });
    expect(build).not.toHaveBeenCalled();
  });

  test('unverified renewal is rejected while plans, status and checkout remain available', async () => {
    expect((await request(app).get('/api/v1/subscription/plans')).status).toBe(200);
    expect((await api('post', '/subscription/activate', { paymentRef: 'made-up-utr', amount: 300 })).body.error.code).toBe('PAYMENT_VERIFICATION_REQUIRED');
    expect((await api('get', '/subscription/status')).body.data.upiPayUrl).toContain('am=300');
  });

  test('verified renewals extend exactly once without changing manual flags', async () => {
    await seed({ isSubscription: false, subscriptionExpiresAt: future(), isChotuAiActive: false });
    const before = (await access.read(businessId)).expiresAt;
    jest.spyOn(gateway, 'getRazorpayClient').mockReturnValue({
      orders: { create: jest.fn(async () => ({ id: 'order_subscription' })) },
      payments: { fetch: jest.fn(async () => ({ id: 'pay_captured', order_id: 'order_subscription', status: 'captured', amount: 30000, currency: 'INR' })) },
    });
    const checkout = await api('post', '/subscription/payment-order', { amount: 1, days: 999 });
    expect(checkout.body.data).toMatchObject({ amount: 30000, days: 30 });
    const payment = { razorpay_payment_id: 'pay_captured', razorpay_order_id: 'order_subscription' };
    const first = await api('post', '/subscription/activate', payment);
    expect(first.status).toBe(200);
    expect(first.body.data).toMatchObject({ paymentVerified: true, isSubscription: false, isChotuAiActive: false, isActive: false });
    const expiry = (await access.read(businessId)).expiresAt;
    expect(expiry.getTime()).toBe(before.getTime() + 30 * 86400000);
    await Promise.all([renewal.verify(businessId, payment), renewal.verify(businessId, payment)]);
    expect((await access.read(businessId)).expiresAt).toEqual(expiry);
    await seed({ isSubscription: true });
    expect((await api('get', '/subscription/status')).body.data.isActive).toBe(true);
    expect((await api('post', '/chotu/parse', { text: 'hello' })).status).toBe(403);
  });

  test('mismatched payment/business and forged controls do not grant', async () => {
    await Intent.create({ businessId, providerOrderId: 'order_bad', amount: 30000, currency: 'INR', days: 30 });
    jest.spyOn(gateway, 'getRazorpayClient').mockReturnValue({ payments: { fetch: async () => ({ id: 'p', order_id: 'order_bad', status: 'authorized', amount: 30000, currency: 'INR' }) } });
    expect((await api('post', '/subscription/activate', { razorpay_payment_id: 'p', razorpay_order_id: 'order_bad' })).status).toBe(400);
    expect((await access.read(businessId)).expiresAt).toBeNull();
  });

  test('schema rejects boolean strings and invalid dates', async () => {
    expect(new Business({ ownerId: user._id, isSubscription: 'true' }).validateSync()).toBeDefined();
    expect(new Business({ ownerId: user._id, isChotuAiActive: 'yes' }).validateSync()).toBeDefined();
    expect(new Business({ ownerId: user._id, subscriptionExpiresAt: 'invalid' }).validateSync()).toBeDefined();
  });

  test('platform administrator changes canonical controls without inventing expiry', async () => {
    await User.updateOne({ _id: user._id }, { $set: { isSuperAdmin: true } });
    const enabled = await api('patch', '/subscription/status', { isSubscription: true, isChotuAiActive: true });
    expect(enabled.status).toBe(200);
    expect(enabled.body.data.isActive).toBe(false);
    expect(enabled.body.data.expiresAt).toBeNull();
    const extended = await api('patch', '/subscription/status', { subscriptionExpiresAt: future().toISOString() });
    expect(extended.body.data.isActive).toBe(true);
    const invalid = await api('patch', '/subscription/status', { isSubscription: 'true' });
    expect(invalid.status).toBe(400);
  });

  test('registering the platform contact email does not grant administrator rights', async () => {
    const owner = await User.create({ email: 'chandanyaduvanshi190@gmail.com', passwordHash: 'not-used', role: 'owner' });
    await Business.create({ ownerId: owner._id });
    const response = await request(app).patch('/api/v1/subscription/status')
      .set('Authorization', `Bearer ${tokenService.generateAccessToken(owner)}`).send({ isSubscription: true });
    expect(response.status).toBe(403);
    expect(await require('../src/services/superadminService').seedSuperAdmin()).toBeNull();
    expect((await User.findById(owner._id)).isSuperAdmin).toBe(false);
    await expect(require('../src/services/superadminService').login(owner.email, 'anything')).rejects.toMatchObject({ statusCode: 401 });
  });

  test('unverified legacy password recovery cannot take over entitlement administrators', async () => {
    await User.updateOne({ _id: user._id }, { $set: { isSuperAdmin: true } });
    const response = await request(app).post('/api/v1/auth/reset-password').send({ email: user.email, newPassword: 'Replacement@123' });
    expect(response.status).toBe(403);
    const login = await request(app).post('/api/v1/auth/login').send({ email: user.email, password: 'Password@123' });
    expect(login.status).toBe(200);
    expect(login.body.data.user.subscription.isActive).toBe(false);
    expect(login.body.data.user.business.subscription.isActive).toBe(false);
  });

  test('inactive businesses can create a renewal intent using only server-owned checkout values', async () => {
    const create = jest.fn().mockResolvedValue({ id: 'order_checkout' });
    jest.spyOn(gateway, 'getRazorpayClient').mockReturnValue({ orders: { create } });
    const response = await api('post', '/subscription/payment-order', { businessId: 'spoofed', amount: 1, days: 9999 });
    expect(response.status).toBe(200);
    expect(create.mock.calls[0][0]).toMatchObject({ amount: 30000, currency: 'INR', notes: { businessId: String(businessId) } });
    const intent = await Intent.findOne({ providerOrderId: response.body.data.orderId }).lean();
    expect(String(intent.businessId)).toBe(String(businessId));
    expect(intent.days).toBe(30);
    expect((await access.read(businessId)).isActive).toBe(false);
  });

  test('renewal checkout without gateway configuration fails without granting access', async () => {
    jest.spyOn(gateway, 'getRazorpayClient').mockReturnValue(null);
    expect((await api('post', '/subscription/payment-order')).status).toBe(503);
    expect((await access.read(businessId)).expiresAt).toBeNull();
  });

  test('administrator login and user details calculate access instead of legacy status', async () => {
    await User.updateOne({ _id: user._id }, { $set: { isSuperAdmin: true, 'subscription.status': 'active' } });
    const admin = require('../src/services/superadminService');
    expect((await admin.login(user.email, 'Password@123')).user.subscription.isActive).toBe(false);
    const details = await admin.getUserById(user._id);
    expect(details.user.subscription.isActive).toBe(false);
    expect(details.business.subscription.isActive).toBe(false);
  });

  test.each([false, 'true', null])('AI permission must be a literal true: %s', async (flag) => {
    await seed({ isSubscription: true, subscriptionExpiresAt: future(), isChotuAiActive: flag });
    expect((await api('post', '/chotu/parse', { text: 'hello' })).status).toBe(403);
    expect(chotu.parseVoiceCommand).not.toHaveBeenCalled();
  });

  test('signed webhook renewal is verified and replay-safe, without changing manual controls', async () => {
    const crypto = require('crypto');
    const secret = 'entitlement-webhook-fixture';
    const previousSecret = process.env.RAZORPAY_WEBHOOK_SECRET;
    process.env.RAZORPAY_WEBHOOK_SECRET = secret;
    try {
      await Intent.create({ businessId, providerOrderId: 'order_webhook', amount: 30000, currency: 'INR', days: 30 });
      jest.spyOn(gateway, 'getRazorpayClient').mockReturnValue({ payments: { fetch: async () => ({ id: 'payment_w', order_id: 'order_webhook', status: 'captured', amount: 30000, currency: 'INR' }) } });
      const payload = { event: 'payment.captured', payload: { payment: { entity: { id: 'payment_w', order_id: 'order_webhook' } } } };
      const signature = crypto.createHmac('sha256', secret).update(JSON.stringify(payload)).digest('hex');
      const send = (sig) => request(app).post('/api/v1/payments/webhook').set('x-razorpay-signature', sig).send(payload);
      expect((await send('forged')).status).toBe(400);
      expect((await access.read(businessId)).expiresAt).toBeNull();
      expect((await send(signature)).status).toBe(200);
      const first = await access.read(businessId);
      expect(first.isActive).toBe(false);
      expect(first.isChotuAiActive).toBe(false);
      expect((await send(signature)).status).toBe(200);
      expect((await access.read(businessId)).expiresAt).toEqual(first.expiresAt);
    } finally {
      if (previousSecret === undefined) delete process.env.RAZORPAY_WEBHOOK_SECRET;
      else process.env.RAZORPAY_WEBHOOK_SECRET = previousSecret;
    }
  });
});
