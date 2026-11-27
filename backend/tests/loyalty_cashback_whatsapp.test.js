const crypto = require('crypto');
const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../src/app');
const Business = require('../src/models/Business');
const Order = require('../src/models/Order');
const CustomerLoyalty = require('../src/models/CustomerLoyalty');
const LoyaltyTransaction = require('../src/models/LoyaltyTransaction');
const loyaltyService = require('../src/services/loyaltyService');
const whatsappService = require('../src/services/whatsappService');
const grantBusinessAccess = require('./helpers/grantBusinessAccess');
require('./setup');

describe('Loyalty Cashback WhatsApp Delivery Tracking, Webhook & Idempotent Retry', () => {
  let authToken;
  let businessId;
  const origEnv = process.env.NODE_ENV;
  const origFetch = global.fetch;

  beforeEach(async () => {
    process.env.NODE_ENV = 'test';
    const regRes = await request(app).post('/api/v1/auth/register').send({
      name: 'Pizza 47 Owner',
      email: 'cashback_wa_owner@apnapos.com',
      password: 'SecurePassword@123',
      phone: '9822223333',
      companyName: 'Pizza 47',
    });
    authToken = regRes.body.data.accessToken;
    await grantBusinessAccess(authToken);

    const meRes = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${authToken}`);
    businessId = meRes.body.data.business._id || meRes.body.data.business.id;

    // Configure realistic store WhatsApp credentials & active 10% cashback program
    await Business.updateOne(
      { _id: businessId },
      {
        $set: {
          'whatsappSettings.enabled': true,
          'whatsappSettings.phoneNumberId': '987654321012345',
          'whatsappSettings.accessToken': 'Bearer EAAGliveTestToken12345',
          'whatsappSettings.appSecret': 'test_app_secret_12345',
        },
      }
    );

    await request(app)
      .post('/api/v1/loyalty/programs')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        id: 'prog_cashback_wa',
        type: 'cashback',
        title: 'Cashback\nRewards',
        description: 'Earn 10% cashback on orders.',
        cashbackType: 'percentage',
        cashbackPercentage: 10,
        minimumOrder: 100,
        maximumCashback: 500,
        isActive: true,
        status: 'active',
      });
  });

  afterEach(() => {
    process.env.NODE_ENV = origEnv;
    global.fetch = origFetch;
  });

  test('1. Records exact Meta error code & failed status when WhatsApp dispatch fails synchronously', async () => {
    process.env.NODE_ENV = 'development';
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 429,
      json: async () => ({
        error: {
          message: 'Too many messages sent from this phone number in a short period of time',
          type: 'OAuthException',
          code: 131056,
          error_subcode: 2494055,
        },
      }),
    });

    const order = await Order.create({
      businessId,
      orderNumber: 'ORD-WA-FAIL-1',
      orderType: 'dineIn',
      customerName: 'Rohan\nVerma',
      customerPhone: '9876543210',
      items: [{ name: 'Farmhouse Pizza', price: 1000, quantity: 1 }],
      subtotal: 1000,
      totalAmount: 1000,
      status: 'completed',
      isPaid: true,
    });

    const earnRes = await loyaltyService.awardPointsForCompletedOrder(businessId, order);
    expect(earnRes.earned).toBe(true);
    expect(earnRes.cashbackAwarded).toBe(100);
    expect(earnRes.whatsappNotification.status).toBe('failed');
    expect(earnRes.whatsappNotification.errorCode).toBe('131056');
    expect(earnRes.whatsappNotification.error).toContain('131056');

    const tx = await LoyaltyTransaction.findById(earnRes.transactionId);
    expect(tx.whatsappStatus).toBe('failed');
    expect(tx.whatsappErrorCode).toBe('131056');
    expect(tx.whatsappError).toContain('Meta Rate Limit');
    expect(tx.whatsappAttempts).toBe(1);
    expect(tx.whatsappPhoneNumberId).toBe('987654321012345');

    // Check sanitized template body parameters sent to Meta (no newlines & cleaned Bearer token)
    expect(global.fetch).toHaveBeenCalledTimes(1);
    const [fetchUrl, fetchOpts] = global.fetch.mock.calls[0];
    expect(fetchUrl).toContain('/987654321012345/messages');
    expect(fetchOpts.headers.Authorization).toBe('Bearer EAAGliveTestToken12345');
    const sentBody = JSON.parse(fetchOpts.body);
    expect(sentBody.template.components[0].parameters.map((p) => p.text)).toEqual([
      'Rohan Verma',
      '100',
      'Pizza 47',
      '100',
    ]);

    // Verify GET /api/v1/loyalty/notifications?status=failed exposes the failed notification
    const listRes = await request(app)
      .get('/api/v1/loyalty/notifications?status=failed')
      .set('Authorization', `Bearer ${authToken}`);
    expect(listRes.status).toBe(200);
    expect(listRes.body.data).toHaveLength(1);
    expect(listRes.body.data[0].orderNumber).toBe('ORD-WA-FAIL-1');
    expect(listRes.body.data[0].whatsappErrorCode).toBe('131056');
  });

  test('2. Saves accepted wamid, handles Meta webhook failure/delivery, and retries without double-crediting', async () => {
    process.env.NODE_ENV = 'development';
    global.fetch = jest.fn().mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({
        messaging_product: 'whatsapp',
        messages: [{ id: 'wamid.accepted_001' }],
      }),
    });

    const order = await Order.create({
      businessId,
      orderNumber: 'ORD-WA-HOOK-1',
      orderType: 'takeaway',
      customerName: 'Neha Singh',
      customerPhone: '9988776655',
      items: [{ name: 'Loaded Pizza', price: 800, quantity: 1 }],
      subtotal: 800,
      totalAmount: 800,
      status: 'completed',
      isPaid: true,
    });

    const earnRes = await loyaltyService.awardPointsForCompletedOrder(businessId, order);
    expect(earnRes.cashbackAwarded).toBe(80);
    expect(earnRes.whatsappNotification.status).toBe('accepted');
    expect(earnRes.whatsappNotification.messageId).toBe('wamid.accepted_001');

    // Re-running order award skips without double-crediting and reports existing WA status
    const repeatAward = await loyaltyService.awardPointsForCompletedOrder(businessId, order);
    expect(repeatAward.earned).toBe(false);
    expect(repeatAward.whatsappMessageId).toBe('wamid.accepted_001');

    // Simulate asynchronous Meta FAILED webhook callback (signed when appSecret is configured)
    const webhookBody = {
      entry: [
        {
          changes: [
            {
              value: {
                statuses: [
                  {
                    id: 'wamid.accepted_001',
                    status: 'failed',
                    recipient_id: '919988776655',
                    timestamp: String(Math.floor(Date.now() / 1000)),
                    errors: [
                      {
                        code: 131026,
                        title: 'Message undeliverable',
                        error_data: { details: 'Recipient number is not on WhatsApp' },
                      },
                    ],
                  },
                ],
              },
            },
          ],
        },
      ],
    };
    const rawWebhookBody = JSON.stringify(webhookBody);
    const webhookHeaders = { 'Content-Type': 'application/json' };
    if (whatsappService.appSecret) {
      webhookHeaders['x-hub-signature-256'] = `sha256=${crypto
        .createHmac('sha256', whatsappService.appSecret)
        .update(rawWebhookBody)
        .digest('hex')}`;
    }

    const hookRes = await request(app)
      .post('/api/v1/whatsapp/webhook')
      .set(webhookHeaders)
      .send(rawWebhookBody);
    expect(hookRes.status).toBe(200);

    let tx = await LoyaltyTransaction.findById(earnRes.transactionId);
    expect(tx.whatsappStatus).toBe('failed');
    expect(tx.whatsappErrorCode).toBe('131026');
    expect(tx.whatsappError).toContain('Recipient number is not on WhatsApp');
    expect(tx.whatsappError).toContain('131026');

    // Now retry the failed cashback notification via REST API
    global.fetch = jest.fn().mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({
        messaging_product: 'whatsapp',
        messages: [{ id: 'wamid.retry_002' }],
      }),
    });

    const retryRes = await request(app)
      .post(`/api/v1/loyalty/transactions/${earnRes.transactionId}/retry-notification`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({});

    expect(retryRes.status).toBe(200);
    expect(retryRes.body.success).toBe(true);
    expect(retryRes.body.data.retried).toBe(true);
    expect(retryRes.body.data.customerCreditedAgain).toBe(false);
    expect(retryRes.body.data.notification.status).toBe('accepted');
    expect(retryRes.body.data.notification.messageId).toBe('wamid.retry_002');
    expect(retryRes.body.data.notification.attempts).toBe(2);

    // Assert customer cashback balance was NEVER credited a second time (still ₹80)
    const loyaltyProfile = await CustomerLoyalty.findOne({
      businessId,
      customerPhone: '9988776655',
    });
    expect(loyaltyProfile.cashbackBalance).toBe(80);
    expect(loyaltyProfile.totalCashbackEarned).toBe(80);

    // Simulate Meta DELIVERED webhook for the retried wamid
    await loyaltyService.processWebhookStatusUpdate({
      messageId: 'wamid.retry_002',
      status: 'delivered',
      timestamp: new Date(),
    });

    tx = await LoyaltyTransaction.findById(earnRes.transactionId);
    expect(tx.whatsappStatus).toBe('delivered');
    expect(tx.whatsappError).toBe('');
    expect(tx.whatsappErrorCode).toBe('');
    expect(tx.whatsappDeliveredAt).not.toBeNull();

    // Calling retry again without force skips cleanly
    const secondRetryRes = await request(app)
      .post(`/api/v1/loyalty/transactions/${earnRes.transactionId}/retry-notification`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({});
    expect(secondRetryRes.status).toBe(200);
    expect(secondRetryRes.body.data.retried).toBe(false);
    expect(secondRetryRes.body.data.alreadySent).toBe(true);
    expect(secondRetryRes.body.data.customerCreditedAgain).toBe(false);

    // Performance recentActivity also surfaces whatsappStatus
    const perfRes = await request(app)
      .get('/api/v1/loyalty/performance?dateRange=All%20Time&programId=prog_cashback_wa')
      .set('Authorization', `Bearer ${authToken}`);
    expect(perfRes.status).toBe(200);
    const activity = perfRes.body.data.recentActivity || [];
    const matchedRow = activity.find((a) => a.orderNumber === 'ORD-WA-HOOK-1');
    expect(matchedRow).toBeDefined();
    expect(matchedRow.whatsappStatus).toBe('delivered');
    expect(matchedRow.whatsappMessageId).toBe('wamid.retry_002');
  });

  test('3. Retries historical untracked cashback transaction without crediting twice & preserves template error over 24h fallback error', async () => {
    process.env.NODE_ENV = 'development';
    await CustomerLoyalty.create({
      businessId,
      customerPhone: '9123456789',
      customerName: 'Amit Kumar',
      cashbackBalance: 55,
      totalCashbackEarned: 55,
    });

    // Historical transaction created before WhatsApp tracking existed
    const legacyTx = await LoyaltyTransaction.create({
      businessId,
      customerPhone: '9123456789',
      orderNumber: 'ORD-NOV27-01',
      type: 'earn',
      programId: 'prog_cashback_wa',
      points: 55,
      discountAmount: 55,
      balanceAfter: 0,
      message: '[APNA POS] Congratulations! You earned ₹55 cashback.',
    });

    // First retry: all templates return 132000 (param mismatch), direct text returns 131047 (24h window)
    global.fetch = jest.fn().mockImplementation(async (_url, opts) => {
      const payload = JSON.parse(opts.body);
      if (payload.type === 'template') {
        return {
          ok: false,
          status: 400,
          json: async () => ({
            error: {
              message: 'Number of parameters does not match the expected number of params',
              code: 132000,
            },
          }),
        };
      }
      return {
        ok: false,
        status: 400,
        json: async () => ({
          error: {
            message: 'Re-engagement message: more than 24 hours have passed since customer last replied',
            code: 131047,
          },
        }),
      };
    });

    const failRetryRes = await request(app)
      .post(`/api/v1/loyalty/transactions/${legacyTx._id}/retry-notification`)
      .set('Authorization', `Bearer ${authToken}`)
      .send({});

    expect(failRetryRes.status).toBe(200);
    expect(failRetryRes.body.success).toBe(false);
    expect(failRetryRes.body.data.customerCreditedAgain).toBe(false);
    // Template error 132000 must be surfaced cleanly rather than being overwritten by 24h text 131047
    expect(failRetryRes.body.data.notification.errorCode).toBe('132000');

    const refreshedCustomer = await CustomerLoyalty.findOne({ businessId, customerPhone: '9123456789' });
    expect(refreshedCustomer.cashbackBalance).toBe(55);
    expect(refreshedCustomer.totalCashbackEarned).toBe(55);
  });

  test('4. Concurrent awardPointsForCompletedOrder calls credit cashback once and send only one WhatsApp message', async () => {
    process.env.NODE_ENV = 'development';
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({
        messaging_product: 'whatsapp',
        messages: [{ id: 'wamid.concurrent_single_001' }],
      }),
    });

    const order = await Order.create({
      businessId,
      orderNumber: 'ORD-CONCURRENT-1',
      orderType: 'dineIn',
      customerName: 'Chandan',
      customerPhone: '9709593705',
      items: [{ name: 'Farmhouse Pizza', price: 1000, quantity: 1 }],
      subtotal: 1000,
      totalAmount: 1000,
      status: 'completed',
      isPaid: true,
    });

    const [res1, res2] = await Promise.all([
      loyaltyService.awardPointsForCompletedOrder(businessId, order),
      loyaltyService.awardPointsForCompletedOrder(businessId, order),
    ]);

    const earnedCount = [res1, res2].filter((r) => r.earned === true).length;
    expect(earnedCount).toBe(1);
    expect(global.fetch).toHaveBeenCalledTimes(1);

    const earnTxs = await LoyaltyTransaction.find({ businessId, orderId: order._id, type: 'earn' });
    expect(earnTxs).toHaveLength(1);
    expect(earnTxs[0].discountAmount).toBe(100);

    const profile = await CustomerLoyalty.findOne({ businessId, customerPhone: '9709593705' });
    expect(profile.cashbackBalance).toBe(100);
    expect(profile.totalCashbackEarned).toBe(100);
  });

  test('5. Meta webhook 130429 schedules automatic cashback retry without double-crediting', async () => {
    process.env.NODE_ENV = 'development';
    global.fetch = jest.fn().mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({
        messaging_product: 'whatsapp',
        messages: [{ id: 'wamid.rate_130429_1' }],
      }),
    });

    const order = await Order.create({
      businessId,
      orderNumber: 'ORD-RATE-LIMIT-1',
      orderType: 'dineIn',
      customerName: 'Chandan',
      customerPhone: '9709593705',
      items: [{ name: 'Farmhouse Pizza', price: 500, quantity: 1 }],
      subtotal: 500,
      totalAmount: 500,
      status: 'completed',
      isPaid: true,
    });

    const earnRes = await loyaltyService.awardPointsForCompletedOrder(businessId, order);
    expect(earnRes.whatsappNotification.messageId).toBe('wamid.rate_130429_1');

    await loyaltyService.processWebhookStatusUpdate({
      messageId: 'wamid.rate_130429_1',
      status: 'failed',
      timestamp: new Date(),
      errors: [
        {
          code: 130429,
          title: 'Rate limit hit',
          error_data: {
            details: 'Message failed to send because there were too many messages sent from this phone number in a short period of time.',
          },
        },
      ],
    });

    let tx = await LoyaltyTransaction.findById(earnRes.transactionId);
    expect(tx.whatsappStatus).toBe('failed');
    expect(tx.whatsappErrorCode).toBe('130429');
    expect(tx.whatsappMetadata.nextRetryAt).toBeTruthy();
    expect(tx.whatsappMetadata.autoRetryCount).toBe(1);

    global.fetch = jest.fn().mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({
        messaging_product: 'whatsapp',
        messages: [{ id: 'wamid.rate_130429_retry_ok' }],
      }),
    });

    const processed = await loyaltyService.processPendingCashbackRetries(new Date(Date.now() + 6 * 60 * 1000));
    expect(processed).toBe(1);

    tx = await LoyaltyTransaction.findById(earnRes.transactionId);
    expect(tx.whatsappStatus).toBe('accepted');
    expect(tx.whatsappMessageId).toBe('wamid.rate_130429_retry_ok');

    const profile = await CustomerLoyalty.findOne({ businessId, customerPhone: '9709593705' });
    expect(profile.cashbackBalance).toBe(50);
  });

  test('6. sendLoyaltyRedemptionOtp never exposes OTP in message or otpDebug outside test env', async () => {
    await CustomerLoyalty.create({
      businessId,
      customerPhone: '9876501234',
      customerName: 'Customer',
      cashbackBalance: 200,
      totalCashbackEarned: 200,
    });

    process.env.NODE_ENV = 'production';
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ messages: [{ id: 'wamid.otp_1' }] }),
    });

    const res = await loyaltyService.sendLoyaltyRedemptionOtp(businessId, '9876501234', {
      stageId: 'cashback_custom',
      pointsToRedeem: 50,
      amountToRedeem: 50,
    });

    expect(res.success).toBe(true);
    expect(res.otpDebug).toBeUndefined();
    expect(res.message).not.toMatch(/OTP generated:/i);
    expect(res.message).not.toMatch(/\b\d{4}\b/);
  });
});
