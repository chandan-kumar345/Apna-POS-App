jest.mock('../src/services/storefrontOtpTransport', () => ({ send: jest.fn(async () => ({ messageId: 'test-message' })) }));
const mongoose = require('mongoose');
const request = require('supertest');
const app = require('../src/app');
const Business = require('../src/models/Business');
const Customer = require('../src/models/Customer');
const Order = require('../src/models/Order');
const { Challenge, Session } = require('../src/models/StorefrontCustomerAuth');
const service = require('../src/services/storefrontCustomerAuthService');
const transport = require('../src/services/storefrontOtpTransport');
require('./setup');

describe('WhatsApp storefront customer authentication', () => {
  let business;
  const phone = '9876543210';
  const otp = () => transport.send.mock.calls.at(-1)[1];
  beforeAll(async () => { await Promise.all([Customer.init(), Challenge.init(), Session.init()]); });
  beforeEach(async () => {
    transport.send.mockReset().mockResolvedValue({ messageId: 'test-message' });
    business = await Business.create({ ownerId: new mongoose.Types.ObjectId(), profile: { slug: 'qr-cafe', name: 'QR Cafe' } });
    await require('../src/models/Table').create({ businessId: business._id, tableNumber: 1, name: 'T01' });
  });
  const send = () => service.send('qr-cafe', { phone });
  const verify = (challenge, extra = {}) => service.verify('qr-cafe', { phone, challengeId: challenge.challengeId, code: otp(), ...extra });

  test('real API issues a private challenge, persists a CRM lead and verifies exact code', async () => {
    const sent = await request(app).post('/api/v1/storefront/qr-cafe/customer/send-otp').send({ phone });
    expect(sent.status).toBe(200);
    expect(sent.body.data).toMatchObject({ channel: 'whatsapp', expiresIn: 300, resendAfter: 60 });
    expect(sent.body.data.otp).toBeUndefined();
    expect(await Customer.findOne({ businessId: business._id, phone })).toMatchObject({ name: 'Valued Customer', phoneVerifiedAt: null });
    const verified = await request(app).post('/api/v1/storefront/qr-cafe/customer/verify-otp').send({ phone, challengeId: sent.body.data.challengeId, code: otp() });
    expect(verified.status).toBe(200);
    expect(verified.body.data.customer.name).toBe('Valued Customer');
    expect(verified.body.data.token).toMatch(/^[a-f0-9]{64}$/);
    const me = await request(app).get('/api/v1/storefront/qr-cafe/customer/me').set('x-storefront-session', verified.body.data.token);
    expect(me.status).toBe(200);
    expect(me.body.data.id).toBe(verified.body.data.customer.id);
    expect(me.headers['cache-control']).toBe('no-store');
  });

  test('wrong and universal six-digit codes do not authenticate; OTP is single-use', async () => {
    const challenge = await send();
    const correct = otp();
    const wrong = correct === '123456' ? '111111' : '123456';
    await expect(verify(challenge, { code: wrong })).rejects.toMatchObject({ statusCode: 401 });
    expect(await Session.countDocuments()).toBe(0);
    const result = await verify(challenge);
    expect(result.customer.name).toBe('Valued Customer');
    await expect(verify(challenge)).rejects.toMatchObject({ statusCode: 401 });
    expect(await Session.countDocuments()).toBe(1);
    const stored = await Challenge.findOne({ businessId: business._id, phone }).select('+codeHash').lean();
    expect(stored.codeHash).not.toBe(correct);
    expect(stored.codeHash).toHaveLength(64);
  });

  test('five wrong attempts, expired challenges and resend cooldown are enforced', async () => {
    const challenge = await send();
    await expect(send()).rejects.toMatchObject({ statusCode: 429 });
    const wrong = otp() === '111111' ? '222222' : '111111';
    for (let i = 0; i < 5; i++) await expect(verify(challenge, { code: wrong })).rejects.toMatchObject({ statusCode: 401 });
    await expect(verify(challenge)).rejects.toMatchObject({ statusCode: 401 });
    await Challenge.updateOne({ businessId: business._id, phone }, { $set: { attempts: 0, expiresAt: new Date(Date.now() - 1000) } });
    await expect(verify(challenge)).rejects.toMatchObject({ statusCode: 401 });
  });

  test('optional name updates CRM after verification and blank returning login preserves it', async () => {
    const challenge = await send();
    const first = await verify(challenge, { name: '  Aman  ' });
    await Challenge.updateOne({ businessId: business._id, phone }, { $set: { resendAt: new Date(0) } });
    const second = await verify(await send(), { name: '' });
    expect(second.customer).toMatchObject({ id: first.customer.id, name: 'Aman' });
    expect(await Customer.countDocuments({ businessId: business._id })).toBe(1);
    expect((await Customer.findOne({ businessId: business._id, phone })).phoneVerifiedAt).toBeTruthy();
  });

  test('database history survives a new login and excludes other phones/restaurants', async () => {
    const first = await verify(await send());
    const make = (number, customerPhone, bId = business._id) => Order.create({ businessId: bId, orderNumber: number,
      customerPhone, orderType: 'dineIn', tableNumber: 'T01', items: [{ name: 'Pizza', quantity: 1, price: 100 }],
      subtotal: 100, taxAmount: 5, totalAmount: 105 });
    await make('mine', '+91 9876543210');
    await make('other-phone', '9123456789');
    const other = await Business.create({ ownerId: new mongoose.Types.ObjectId(), profile: { slug: 'other-cafe' } });
    await make('other-restaurant', phone, other._id);
    await expect(service.orders('other-cafe', first.token)).rejects.toMatchObject({ statusCode: 401 });
    await Challenge.updateOne({ businessId: business._id, phone }, { $set: { resendAt: new Date(0) } });
    const returning = await verify(await send());
    const orders = await service.orders('qr-cafe', returning.token);
    expect(orders.map(row => row.orderNumber)).toEqual(['mine']);
    await expect(service.orders('qr-cafe', 'merchant-jwt')).rejects.toMatchObject({ statusCode: 401 });
  });

  test('failed Meta delivery does not report success or create a fake profile', async () => {
    transport.send.mockRejectedValueOnce(new Error('provider offline'));
    await expect(send()).rejects.toMatchObject({ statusCode: 503 });
    expect(await Customer.countDocuments({ businessId: business._id })).toBe(0);
    expect(await Challenge.countDocuments()).toBe(0);
  });

  test('verified orders use the session customer rather than body phone/name/ID', async () => {
    const verified = await verify(await send(), { name: 'Aman' });
    const response = await request(app).post('/api/v1/storefront/qr-cafe/order')
      .set('x-storefront-session', verified.token).send({
        businessId: String(business._id), orderId: 'customer-auth-order', orderNumber: 'QR-AUTH-1',
        orderType: 'dineIn', tableNumber: 'T01', customerPhone: '9123456789', customerName: 'Spoofed',
        customerId: new mongoose.Types.ObjectId(), items: [{ name: 'Pizza', quantity: 1, price: 100 }],
        subtotal: 100, taxAmount: 5, totalAmount: 105,
      });
    expect(response.status).toBe(201);
    const order = await Order.findOne({ businessId: business._id, orderNumber: 'QR-AUTH-1' });
    expect(String(order.customerId)).toBe(verified.customer.id);
    expect(order.customerName).toBe('Aman');
    expect(order.customerPhone).toBe(phone);
    expect((await service.orders('qr-cafe', verified.token)).map(row => row.orderNumber)).toContain('QR-AUTH-1');
  });

  test('concurrent valid confirmations consume one challenge only', async () => {
    const challenge = await send();
    const results = await Promise.allSettled([verify(challenge), verify(challenge)]);
    expect(results.filter(row => row.status === 'fulfilled')).toHaveLength(1);
    expect(await Session.countDocuments()).toBe(1);
  });
});
