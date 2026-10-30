const request = require('supertest');
const app = require('../src/app');
require('./setup');

describe('Coupons Management & Validation APIs (/api/v1/coupons)', () => {
  let token;

  beforeEach(async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: `coupon_owner_${Date.now()}@example.com`,
        password: 'Password@123',
        restaurantName: 'Coupon Test Bistro',
      });

    token = res.body.data.accessToken;
  });

  it('POST /api/v1/coupons - should create a new percentage coupon', async () => {
    const res = await request(app)
      .post('/api/v1/coupons')
      .set('Authorization', `Bearer ${token}`)
      .send({
        code: 'WELCOME20',
        title: '20% Off Welcome Deal',
        discountType: 'percentage',
        discountValue: 20,
        minCartAmount: 200,
        maxDiscountAmount: 100,
        orderTypes: ['dineIn', 'takeaway', 'delivery'],
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.code).toBe('WELCOME20');
    expect(res.body.data.discountValue).toBe(20);
  });

  it('GET /api/v1/coupons - should list created coupons', async () => {
    // Create first
    await request(app)
      .post('/api/v1/coupons')
      .set('Authorization', `Bearer ${token}`)
      .send({
        code: 'LISTTEST10',
        discountType: 'percentage',
        discountValue: 10,
      });

    const res = await request(app)
      .get('/api/v1/coupons')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.coupons.length).toBeGreaterThanOrEqual(1);
    expect(res.body.data.coupons[0].code).toBe('LISTTEST10');
  });

  it('POST /api/v1/coupons/validate - should fail if below minCartAmount', async () => {
    await request(app)
      .post('/api/v1/coupons')
      .set('Authorization', `Bearer ${token}`)
      .send({
        code: 'MINCHECK',
        discountType: 'flat',
        discountValue: 50,
        minCartAmount: 300,
      });

    const res = await request(app)
      .post('/api/v1/coupons/validate')
      .set('Authorization', `Bearer ${token}`)
      .send({
        code: 'MINCHECK',
        subtotal: 150,
        orderType: 'dineIn',
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(false);
    expect(res.body.message).toContain('Add products worth');
  });

  it('POST /api/v1/coupons/validate - should calculate percentage discount correctly with cap', async () => {
    await request(app)
      .post('/api/v1/coupons')
      .set('Authorization', `Bearer ${token}`)
      .send({
        code: 'CAPCHECK',
        discountType: 'percentage',
        discountValue: 20,
        minCartAmount: 200,
        maxDiscountAmount: 100,
      });

    const res = await request(app)
      .post('/api/v1/coupons/validate')
      .set('Authorization', `Bearer ${token}`)
      .send({
        code: 'CAPCHECK',
        subtotal: 600, // 20% of 600 is 120, capped at maxDiscount 100
        orderType: 'dineIn',
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.discountAmount).toBe(100);
    expect(res.body.data.valid).toBe(true);
  });

  it('POST /api/v1/coupons - create flat discount coupon and validate', async () => {
    const createRes = await request(app)
      .post('/api/v1/coupons')
      .set('Authorization', `Bearer ${token}`)
      .send({
        code: 'FLAT50',
        title: 'Flat 50 Off',
        discountType: 'flat',
        discountValue: 50,
        minCartAmount: 100,
      });

    expect(createRes.status).toBe(201);

    const valRes = await request(app)
      .post('/api/v1/coupons/validate')
      .set('Authorization', `Bearer ${token}`)
      .send({
        code: 'FLAT50',
        subtotal: 250,
        orderType: 'takeaway',
      });

    expect(valRes.status).toBe(200);
    expect(valRes.body.success).toBe(true);
    expect(valRes.body.data.discountAmount).toBe(50);
  });
});
