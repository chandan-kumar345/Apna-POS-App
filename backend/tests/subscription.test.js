const request = require('supertest');
const app = require('../src/app');
const { SubscriptionLead } = require('../src/models/SubscriptionLead');
require('./setup');

describe('Subscription & Lead Generation API', () => {
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
});
