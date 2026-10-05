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

  describe('GET & POST /api/v1/subscription/status & activate', () => {
    it('should return subscription status with UPI pay url and amount 300', async () => {
      const res = await request(app).get('/api/v1/subscription/status');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.upiId).toBe('9709593705@ybl');
      expect(res.body.data.amount).toBe(300);
      expect(res.body.data.upiPayUrl).toContain('pa=9709593705@ybl');
      expect(res.body.data.upiPayUrl).toContain('am=300');
    });

    it('should unlock and activate subscription on POST /api/v1/subscription/activate', async () => {
      const res = await request(app)
        .post('/api/v1/subscription/activate')
        .send({
          paymentRef: 'UPI_TEST_UTR_123456',
          amount: 300,
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.isActive).toBe(true);
      expect(res.body.data.status).toBe('active');
      expect(res.body.data.upiId).toBe('9709593705@ybl');
      expect(res.body.data.paymentRef).toBe('UPI_TEST_UTR_123456');
    });

    it('should list all subscriptions from the new subscriptions collection', async () => {
      const res = await request(app).get('/api/v1/subscription/all');
      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(Array.isArray(res.body.data)).toBe(true);
    });

    it('should create and assign staff subscription on POST /api/v1/subscription/staff', async () => {
      const res = await request(app)
        .post('/api/v1/subscription/staff')
        .send({
          userId: '6abe430203f46a99a8b7654c',
          plan: 'standard',
          amount: 300,
          isActive: true,
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.isActive).toBe(true);
      expect(res.body.data.targetType).toBe('staff');
    });
  });
});
