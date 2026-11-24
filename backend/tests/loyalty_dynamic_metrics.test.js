const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../src/app');
const Order = require('../src/models/Order');
const loyaltyService = require('../src/services/loyaltyService');
const grantBusinessAccess = require('./helpers/grantBusinessAccess');
require('./setup');

describe('Loyalty Landing Dynamic Metrics & Per-Program Stats', () => {
  let authToken;
  let businessId;

  beforeEach(async () => {
    const regRes = await request(app).post('/api/v1/auth/register').send({
      name: 'Loyalty Metrics Owner',
      email: 'loyalty_metrics@apnapos.com',
      password: 'SecurePassword@123',
      phone: '9811112222',
      companyName: 'Pizza 47',
    });
    authToken = regRes.body.data.accessToken;
    await grantBusinessAccess(authToken);

    const meRes = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${authToken}`);
    businessId = meRes.body.data.business._id || meRes.body.data.business.id;
  });

  test('GET /api/v1/loyalty/programs returns live members, cashback, redemptions, revenue, growth %, and program membersCount', async () => {
    // 1. Create active cashback program
    const progRes = await request(app)
      .post('/api/v1/loyalty/programs')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        id: 'prog_cashback_live',
        type: 'cashback',
        title: 'Cashback on Every Order',
        description: 'Give cashback to customers on their orders.',
        cashbackType: 'percentage',
        cashbackPercentage: 10,
        minimumOrder: 200,
        maximumCashback: 200,
        validity: '01 Oct 2026 – 23 Nov 2026',
        isActive: true,
        status: 'active',
      });
    expect(progRes.status).toBe(200);

    const now = Date.now();
    const prevDate = new Date(now - 40 * 24 * 60 * 60 * 1000); // 40 days ago (prior 30d window)
    const currDate = new Date(now - 2 * 24 * 60 * 60 * 1000);  // 2 days ago (current 30d window)

    // 2. Historical order (40 days ago): ₹1000 by customer A -> ₹100 cashback
    const orderPrev = await Order.create({
      businessId,
      orderNumber: 'ORD-PREV-1',
      orderType: 'dineIn',
      customerName: 'Alice',
      customerPhone: '9900000001',
      items: [{ name: 'Margherita', price: 1000, quantity: 1 }],
      subtotal: 1000,
      totalAmount: 1000,
      status: 'completed',
      isPaid: true,
      completedAt: prevDate,
      createdAt: prevDate,
    });
    await loyaltyService.awardPointsForCompletedOrder(businessId, orderPrev);

    // 3. Recent order (2 days ago): ₹1500 by customer B -> ₹150 cashback
    const orderCurr = await Order.create({
      businessId,
      orderNumber: 'ORD-CURR-1',
      orderType: 'takeaway',
      customerName: 'Bob',
      customerPhone: '9900000002',
      items: [{ name: 'Farmhouse', price: 1500, quantity: 1 }],
      subtotal: 1500,
      totalAmount: 1500,
      status: 'completed',
      isPaid: true,
      completedAt: currDate,
      createdAt: currDate,
    });
    await loyaltyService.awardPointsForCompletedOrder(businessId, orderCurr);

    // 4. Anonymous non-loyalty walk-in order (should NOT count in loyalty revenue)
    await Order.create({
      businessId,
      orderNumber: 'ORD-ANON-1',
      orderType: 'takeaway',
      customerName: '',
      customerPhone: '',
      items: [{ name: 'Soda', price: 500, quantity: 1 }],
      subtotal: 500,
      totalAmount: 500,
      status: 'completed',
      isPaid: true,
      completedAt: currDate,
      createdAt: currDate,
    });

    // 5. Redeem ₹40 for Alice (smaller than total cashback earned ₹250!)
    await loyaltyService.redeemLoyaltyPoints(
      businessId,
      '9900000001',
      orderPrev._id.toString(),
      'cashback_custom',
      40,
      40,
      'ORD-PREV-1'
    );

    // 6. Query dynamic dashboard endpoint
    const res = await request(app)
      .get('/api/v1/loyalty/programs')
      .set('Authorization', `Bearer ${authToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    const data = res.body.data;
    const metrics = data.dashboardMetrics;

    expect(metrics.members).toBe(2);
    // Earned 100 + 150 = 250 (not overwritten by 40 redemption!)
    expect(metrics.totalCashback).toBe(250);
    expect(metrics.redemptions).toBe(1);
    // Revenue: 1000 + 1500 = 2500 (anonymous 500 excluded)
    expect(metrics.revenue).toBe(2500);
    // Growth: (1500 - 1000) / 1000 = +50%
    expect(metrics.revenueGrowthPercent).toBe(50);

    const prog = data.programs.find((p) => p.id === 'prog_cashback_live');
    expect(prog).toBeDefined();
    expect(prog.membersCount).toBe(2);
    expect(prog.ordersCount).toBe(2);
    expect(prog.cashbackGiven).toBe(250);
  });
});
