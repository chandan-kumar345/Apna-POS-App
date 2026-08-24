const request = require('supertest');
const mongoose = require('mongoose');
const crypto = require('crypto');
const app = require('../src/app');
const Business = require('../src/models/Business');
const User = require('../src/models/User');
const Order = require('../src/models/Order');
const tokenService = require('../src/services/tokenService');
const env = require('../src/config/env');
require('./setup');

describe('Razorpay Dynamic UPI QR & Webhook Verification API', () => {
  let token;
  let businessId;
  let userId;
  let testOrder;
  const webhookSecret = 'test_webhook_secret_key_123';

  beforeEach(async () => {
    process.env.RAZORPAY_WEBHOOK_SECRET = webhookSecret;

    const dummyUserId = new mongoose.Types.ObjectId();
    const business = await Business.create({
      ownerId: dummyUserId,
      profile: { name: 'Spice Garden POS', phone: '9888877777', upiId: 'spicegarden@icici' },
    });
    businessId = business._id.toString();

    const user = await User.create({
      _id: dummyUserId,
      email: 'manager.spice@example.com',
      passwordHash: 'hashedpassword',
      role: 'owner',
      businessId: business._id,
      onboardingCompleted: true,
    });
    userId = user._id.toString();

    token = tokenService.generateAccessToken(user);

    testOrder = await Order.create({
      businessId: business._id,
      orderNumber: 'ORD-TEST-' + Date.now() + '-' + Math.floor(Math.random() * 1000),
      orderType: 'dineIn',
      tableNumber: 'T-10',
      status: 'pending',
      subtotal: 500,
      totalAmount: 525,
      cgst: 12.5,
      sgst: 12.5,
      paymentStatus: 'pending',
      paymentMethod: 'unpaid',
      items: [
        {
          name: 'Butter Chicken',
          price: 250,
          quantity: 2,
          foodType: 'non_veg',
        },
      ],
    });
  });

  describe('POST /api/v1/payments/create-qr', () => {
    it('should generate a dynamic UPI QR intent string successfully', async () => {
      const res = await request(app)
        .post('/api/v1/payments/create-qr')
        .set('Authorization', 'Bearer ' + token)
        .send({
          orderId: testOrder._id.toString(),
          orderNumber: testOrder.orderNumber,
          amount: 525,
          customerName: 'Aarav Sharma',
          customerPhone: '9876543210',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.amount).toBe(525);
      expect(res.body.data.qrIntentUrl).toBeDefined();
      expect(res.body.data.qrIntentUrl).toContain('upi://pay');
      expect(res.body.data.orderNumber).toBe(testOrder.orderNumber);

      const updatedOrder = await Order.findById(testOrder._id);
      expect(updatedOrder.qrIntentUrl).toBeDefined();
    });

    it('should reject invalid or negative amount', async () => {
      const res = await request(app)
        .post('/api/v1/payments/create-qr')
        .set('Authorization', 'Bearer ' + token)
        .send({
          orderId: testOrder._id.toString(),
          amount: -50,
        });

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });

  describe('POST /api/v1/payments/webhook', () => {
    it('should process qr_code.credited webhook and mark order as PAID', async () => {
      const fakeQrId = 'qr_' + Date.now();
      testOrder.razorpayQrId = fakeQrId;
      await testOrder.save();

      const webhookPayload = {
        entity: 'event',
        event: 'qr_code.credited',
        payload: {
          qr_code: {
            entity: {
              id: fakeQrId,
              payment_amount: 52500,
              notes: {
                orderId: testOrder._id.toString(),
                orderNumber: testOrder.orderNumber,
              },
            },
          },
          payment: {
            entity: {
              id: 'pay_test_99887766',
              amount: 52500,
              vpa: 'customer@okhdfcbank',
              acquirer_data: {
                rrn: '123456789012',
                upi_transaction_id: 'UPI1234567890',
              },
            },
          },
        },
      };

      const payloadString = JSON.stringify(webhookPayload);
      const signature = crypto
        .createHmac('sha256', webhookSecret)
        .update(payloadString)
        .digest('hex');

      const res = await request(app)
        .post('/api/v1/payments/webhook')
        .set('x-razorpay-signature', signature)
        .set('Content-Type', 'application/json')
        .send(payloadString);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.isPaid).toBe(true);
      expect(res.body.data.utr).toBe('123456789012');

      const verifiedOrder = await Order.findById(testOrder._id);
      expect(verifiedOrder.status).toBe('completed');
      expect(verifiedOrder.paymentStatus).toBe('paid');
      expect(verifiedOrder.isPaid).toBe(true);
      expect(verifiedOrder.paymentMethod).toBe('UPI');
      expect(verifiedOrder.razorpayPaymentId).toBe('pay_test_99887766');
      expect(verifiedOrder.upiUtr).toBe('123456789012');
      expect(verifiedOrder.upiVpa).toBe('customer@okhdfcbank');
    });

    it('should process payment.captured event idempotently', async () => {
      const webhookPayload = {
        entity: 'event',
        event: 'payment.captured',
        payload: {
          payment: {
            entity: {
              id: 'pay_test_55443322',
              amount: 52500,
              vpa: 'buyer@okaxis',
              acquirer_data: {
                rrn: '987654321098',
              },
              notes: {
                orderId: testOrder._id.toString(),
                orderNumber: testOrder.orderNumber,
              },
            },
          },
        },
      };

      const payloadString = JSON.stringify(webhookPayload);
      const signature = crypto
        .createHmac('sha256', webhookSecret)
        .update(payloadString)
        .digest('hex');

      const res1 = await request(app)
        .post('/api/v1/payments/webhook')
        .set('x-razorpay-signature', signature)
        .set('Content-Type', 'application/json')
        .send(payloadString);

      expect(res1.status).toBe(200);
      expect(res1.body.data.isPaid).toBe(true);

      // Duplicate call
      const res2 = await request(app)
        .post('/api/v1/payments/webhook')
        .set('x-razorpay-signature', signature)
        .set('Content-Type', 'application/json')
        .send(payloadString);

      expect(res2.status).toBe(200);
      expect(res2.body.data.isPaid).toBe(true);
      expect(res2.body.data.idempotent).toBe(true);
    });

    it('should reject webhook with invalid signature', async () => {
      const webhookPayload = {
        entity: 'event',
        event: 'payment.captured',
      };

      const res = await request(app)
        .post('/api/v1/payments/webhook')
        .set('x-razorpay-signature', 'invalid_bogus_signature')
        .send(webhookPayload);

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('INVALID_SIGNATURE');
    });
  });

  describe('GET /api/v1/payments/status/:orderId', () => {
    it('should return real-time payment status of an order', async () => {
      testOrder.status = 'completed';
      testOrder.paymentStatus = 'paid';
      testOrder.isPaid = true;
      testOrder.upiUtr = 'UTR88990011';
      testOrder.razorpayPaymentId = 'pay_test_xyz';
      await testOrder.save();

      const res = await request(app)
        .get('/api/v1/payments/status/' + testOrder._id)
        .set('Authorization', 'Bearer ' + token);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.isPaid).toBe(true);
      expect(res.body.data.paymentStatus).toBe('paid');
      expect(res.body.data.utr).toBe('UTR88990011');
      expect(res.body.data.paymentId).toBe('pay_test_xyz');
    });
  });
});
