const request = require('supertest');
const app = require('../src/app');
const Business = require('../src/models/Business');
require('./setup');

describe('Onboarding APIs (/api/v1/onboarding)', () => {
  let authToken;
  let userId;

  const validUser = {
    email: 'test_diner@example.com',
    password: 'SecurePassword@123',
  };

  beforeEach(async () => {
    const regRes = await request(app)
      .post('/api/v1/auth/register')
      .send(validUser);

    authToken = regRes.body.data.accessToken;
    userId = regRes.body.data.user.id;
  });

  describe('Step 1: PATCH /api/v1/onboarding/profile', () => {
    it('should save user profile and update onboardingStep to 1', async () => {
      const res = await request(app)
        .patch('/api/v1/onboarding/profile')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          name: 'Chandan Kumar',
          phone: '+91 9876543210',
          companyName: 'Apna POS Grand Diner',
          website: 'https://apnapos.com',
          referralCode: 'REF123',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.onboardingStep).toBe(1);
      expect(res.body.data.profile.companyName).toBe('Apna POS Grand Diner');

      // Verify idempotency: only 1 business document exists
      const count = await Business.countDocuments({ ownerId: userId });
      expect(count).toBe(1);
    });

    it('should reject profile save with missing required fields', async () => {
      const res = await request(app)
        .patch('/api/v1/onboarding/profile')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          name: '',
          phone: '',
          companyName: '',
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.fields.name).toBeDefined();
    });
  });

  describe('Step 2: PATCH /api/v1/onboarding/business', () => {
    it('should save business configuration and update onboardingStep to 2', async () => {
      const res = await request(app)
        .patch('/api/v1/onboarding/business')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          country: 'IN',
          currency: 'INR',
          timezone: 'Asia/Kolkata',
          businessType: 'Cafe & Restaurant',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.onboardingStep).toBe(2);
      expect(res.body.data.businessDetails.currency).toBe('INR');
    });
  });

  describe('Step 3: PATCH /api/v1/onboarding/address', () => {
    it('should save address with GeoJSON coordinates and update onboardingStep to 3', async () => {
      const res = await request(app)
        .patch('/api/v1/onboarding/address')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          addressLine: 'Connaught Place',
          building: 'Flat 12-A',
          landmark: 'Near Rajiv Chowk Metro',
          placeType: 'work',
          city: 'New Delhi',
          state: 'Delhi',
          country: 'IN',
          postalCode: '110001',
          latitude: 28.6315,
          longitude: 77.2167,
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.onboardingStep).toBe(3);
      expect(res.body.data.address.location.type).toBe('Point');
      expect(res.body.data.address.location.coordinates).toEqual([77.2167, 28.6315]);
    });
  });

  describe('Step 4: PATCH /api/v1/onboarding/order-settings', () => {
    it('should save order settings with GST and update onboardingStep to 4', async () => {
      const res = await request(app)
        .patch('/api/v1/onboarding/order-settings')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          services: {
            dineIn: true,
            takeaway: true,
            delivery: false,
          },
          tax: {
            type: 'gst',
            gstNumber: '07AAAAA0000A1Z5',
            percentage: 5,
          },
          restaurantType: 'both',
          paymentMethods: {
            cash: true,
            upi: true,
            card: true,
          },
          upiId: 'apnapos@upi',
          tableCount: 12,
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.onboardingStep).toBe(4);
      expect(res.body.data.orderSettings.tableCount).toBe(12);
    });

    it('should require GST number and percentage when GST is selected', async () => {
      const res = await request(app)
        .patch('/api/v1/onboarding/order-settings')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          services: { dineIn: true },
          tax: {
            type: 'gst',
            gstNumber: '',
            percentage: null,
          },
          restaurantType: 'pure_veg',
          paymentMethods: { cash: true, upi: false },
          tableCount: 10,
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
    });

    it('should reject negative table count', async () => {
      const res = await request(app)
        .patch('/api/v1/onboarding/order-settings')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          services: { dineIn: true },
          tax: { type: 'no_gst' },
          restaurantType: 'both',
          tableCount: -5,
        });

      expect(res.status).toBe(422);
    });
  });

  describe('GET /api/v1/onboarding/status & POST /api/v1/onboarding/complete', () => {
    it('should return onboarding status accurately', async () => {
      const statusRes = await request(app)
        .get('/api/v1/onboarding/status')
        .set('Authorization', `Bearer ${authToken}`);

      expect(statusRes.status).toBe(200);
      expect(statusRes.body.data.completed).toBe(false);
      expect(statusRes.body.data.currentStep).toBe(0);
      expect(statusRes.body.data.nextStep).toBe(1);
    });

    it('should reject onboarding completion if required steps are missing', async () => {
      const completeRes = await request(app)
        .post('/api/v1/onboarding/complete')
        .set('Authorization', `Bearer ${authToken}`);

      expect(completeRes.status).toBe(400);
      expect(completeRes.body.error.code).toBe('ONBOARDING_INCOMPLETE');
    });

    it('should successfully complete onboarding when all 4 steps are provided', async () => {
      // Step 1
      await request(app)
        .patch('/api/v1/onboarding/profile')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          name: 'Chandan Kumar',
          phone: '+91 9876543210',
          companyName: 'Apna POS Grand Diner',
        });

      // Step 2
      await request(app)
        .patch('/api/v1/onboarding/business')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          country: 'IN',
          currency: 'INR',
          timezone: 'Asia/Kolkata',
          businessType: 'Restaurant',
        });

      // Step 3
      await request(app)
        .patch('/api/v1/onboarding/address')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          city: 'New Delhi',
          addressLine: 'Connaught Place',
        });

      // Step 4
      await request(app)
        .patch('/api/v1/onboarding/order-settings')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          services: { dineIn: true },
          tax: { type: 'gst', gstNumber: '07AAAAA0000A1Z5', percentage: 5 },
          restaurantType: 'both',
          paymentMethods: { cash: true, upi: true },
          upiId: 'apnapos@upi',
          tableCount: 15,
        });

      // Complete
      const completeRes = await request(app)
        .post('/api/v1/onboarding/complete')
        .set('Authorization', `Bearer ${authToken}`);

      expect(completeRes.status).toBe(200);
      expect(completeRes.body.success).toBe(true);
      expect(completeRes.body.data.onboardingCompleted).toBe(true);

      // Verify status now shows completed
      const statusRes = await request(app)
        .get('/api/v1/onboarding/status')
        .set('Authorization', `Bearer ${authToken}`);

      expect(statusRes.body.data.completed).toBe(true);
      expect(statusRes.body.data.nextStep).toBeNull();
    });
  });
});
