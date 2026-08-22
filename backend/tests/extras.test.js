const request = require('supertest');
const app = require('../src/app');
require('./setup');

describe('Extras APIs (/api/v1/extras)', () => {
  let token;

  beforeEach(async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: `extra_owner_${Date.now()}@example.com`,
        password: 'Password@123',
        restaurantName: 'Extra Test Bistro',
      });

    token = res.body.data.accessToken;
  });

  describe('GET /api/v1/extras', () => {
    it('should return default seeded extras/coupons on first fetch', async () => {
      const res = await request(app)
        .get('/api/v1/extras')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.extras).toBeDefined();
      expect(res.body.data.extras.length).toBeGreaterThanOrEqual(3);

      const codes = res.body.data.extras.map((e) => e.code);
      expect(codes).toContain('SAVE50');
      expect(codes).toContain('FLAT100');
      expect(codes).toContain('WELCOME10');
    });
  });

  describe('POST /api/v1/extras/validate-coupon', () => {
    it('should validate percent discount coupon (SAVE50)', async () => {
      const res = await request(app)
        .post('/api/v1/extras/validate-coupon')
        .set('Authorization', `Bearer ${token}`)
        .send({
          code: 'SAVE50',
          subtotal: 400,
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.isValid).toBe(true);
      expect(res.body.data.discountAmount).toBe(200);
    });

    it('should check minOrderAmount on flat discount coupon (FLAT100)', async () => {
      // Subtotal below minOrderAmount (499)
      const resBelow = await request(app)
        .post('/api/v1/extras/validate-coupon')
        .set('Authorization', `Bearer ${token}`)
        .send({
          code: 'FLAT100',
          subtotal: 300,
        });

      expect(resBelow.status).toBe(200);
      expect(resBelow.body.data.isValid).toBe(false);

      // Subtotal above minOrderAmount
      const resAbove = await request(app)
        .post('/api/v1/extras/validate-coupon')
        .set('Authorization', `Bearer ${token}`)
        .send({
          code: 'FLAT100',
          subtotal: 600,
        });

      expect(resAbove.status).toBe(200);
      expect(resAbove.body.data.isValid).toBe(true);
      expect(resAbove.body.data.discountAmount).toBe(100);
    });
  });

  describe('POST & DELETE /api/v1/extras', () => {
    it('should create a custom extra and delete it', async () => {
      const createRes = await request(app)
        .post('/api/v1/extras')
        .set('Authorization', `Bearer ${token}`)
        .send({
          name: 'Special Diwali Offer',
          code: 'DIWALI25',
          type: 'coupon',
          discountType: 'percent',
          value: 25,
        });

      expect(createRes.status).toBe(201);
      expect(createRes.body.data.extra).toBeDefined();
      const extraId = createRes.body.data.extra.id || createRes.body.data.extra._id;

      const deleteRes = await request(app)
        .delete(`/api/v1/extras/${extraId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(deleteRes.status).toBe(200);
      expect(deleteRes.body.success).toBe(true);
    });
  });
});
