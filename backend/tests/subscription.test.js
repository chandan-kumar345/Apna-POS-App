const request = require('supertest');
const app = require('../src/app');
const { SubscriptionLead } = require('../src/models/SubscriptionLead');
const emailService = require('../src/services/emailService');
require('./setup');

describe('Subscription & Lead Generation API', () => {
  beforeAll(() => {
    jest.spyOn(emailService, 'sendLeadNotificationEmail').mockResolvedValue({
      sent: true,
      messageId: '<test-mock-msg@gmail.com>',
      recipient: 'sooftcode@gmail.com',
    });
  });

  afterAll(() => {
    jest.restoreAllMocks();
  });
  describe('GET /api/v1/subscription/plans', () => {
    it('should return subscription plans with feature matrix', async () => {
      const res = await request(app).get('/api/v1/subscription/plans');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(Array.isArray(res.body.data.plans)).toBe(true);
      expect(res.body.data.plans.length).toBeGreaterThanOrEqual(3);
      expect(res.body.data.plans[1].name).toContain('Growth / Pro');
    });
  });

  describe('POST /api/v1/subscription/lead', () => {
    it('should reject lead without phone number', async () => {
      const res = await request(app).post('/api/v1/subscription/lead').send({
        restaurantName: 'Royal Gardenia',
        contactPerson: 'Chandan',
        phone: '',
      });
      expect(res.status).toBe(400);
    });

    it('should successfully create lead and dispatch notification to sooftcode@gmail.com', async () => {
      const payload = {
        restaurantName: 'The Royal Gardenia',
        contactPerson: 'Chandan Yaduvanshi',
        phone: '9876543210',
        email: 'chandan@example.com',
        selectedPlan: 'Growth / Pro All-in-One',
        billingCycle: 'annual',
        sourceFeature: 'inventory',
        notes: 'Interested in inventory and loyalty integration',
      };

      const res = await request(app).post('/api/v1/subscription/lead').send(payload);
      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.recipient).toBe('sooftcode@gmail.com');

      const savedLead = await SubscriptionLead.findOne({ phone: '9876543210' });
      expect(savedLead).not.toBeNull();
      expect(savedLead.restaurantName).toBe('The Royal Gardenia');
      expect(savedLead.sourceFeature).toBe('inventory');
      expect(savedLead.emailNotificationRecipient).toBe('sooftcode@gmail.com');
    });

    it('should handle lead from loyalty or campaign source', async () => {
      const payload = {
        restaurantName: 'Pizza Hub',
        contactPerson: 'Rahul Kumar',
        phone: '9123456789',
        selectedPlan: 'Loyalty & Cashback Suite',
        sourceFeature: 'loyalty',
      };

      const res = await request(app).post('/api/v1/subscription/lead').send(payload);
      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);

      const saved = await SubscriptionLead.findOne({ phone: '9123456789' });
      expect(saved.sourceFeature).toBe('loyalty');
    });
  });

  describe('Authenticated subscription status and renewal safety', () => {
    let token;
    beforeEach(async () => {
      const response = await request(app).post('/api/v1/auth/register')
        .send({ email: 'subscription-contract@example.com', password: 'Password@123' });
      token = response.body.data.accessToken;
    });
    it('keeps existing calculated response aliases and payment details', async () => {
      const response = await request(app).get('/api/v1/subscription/status').set('Authorization', 'Bearer ' + token);
      expect(response.status).toBe(200);
      expect(response.body.data).toMatchObject({ isSubscriptionActive: false, isActive: false, isSubscribed: false, amount: 300, upiId: '9709593705@ybl' });
    });
    it('does not accept an unverified UTR as a paid subscription', async () => {
      const response = await request(app).post('/api/v1/subscription/activate').set('Authorization', 'Bearer ' + token).send({ paymentRef: 'UNVERIFIED', amount: 300 });
      expect(response.status).toBe(400);
      expect(response.body.error.code).toBe('PAYMENT_VERIFICATION_REQUIRED');
    });
    it('requires authentication and platform authority for entitlement changes', async () => {
      expect((await request(app).get('/api/v1/subscription/status')).status).toBe(401);
      expect((await request(app).patch('/api/v1/subscription/status').set('Authorization', 'Bearer ' + token).send({ isSubscriptionActive: true })).status).toBe(403);
      expect((await request(app).get('/api/v1/subscription/all').set('Authorization', 'Bearer ' + token)).status).toBe(403);
      expect((await request(app).post('/api/v1/subscription/staff').set('Authorization', 'Bearer ' + token).send({ isActive: true })).status).toBe(403);
    });
  });
});
