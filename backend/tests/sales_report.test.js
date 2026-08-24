const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../src/app');
const Business = require('../src/models/Business');
const User = require('../src/models/User');
const Order = require('../src/models/Order');
const Product = require('../src/models/Product');
const tokenService = require('../src/services/tokenService');
require('./setup');

describe('Sales Report & Bulk Product Import APIs', () => {
  let token;
  let businessId;
  let userId;

  beforeEach(async () => {
    const dummyUserId = new mongoose.Types.ObjectId();
    const business = await Business.create({
      ownerId: dummyUserId,
      profile: { name: 'Sales Report Diner', phone: '9888877777' },
    });
    businessId = business._id.toString();

    const user = await User.create({
      _id: dummyUserId,
      email: 'owner@salesreport.com',
      passwordHash: 'hashedpassword',
      role: 'owner',
      businessId: business._id,
      onboardingCompleted: true,
    });
    userId = user._id.toString();

    token = tokenService.generateAccessToken(user);
  });

  describe('POST /api/v1/products/bulk (Bulk Import Products)', () => {
    it('should bulk import products in a single API batch and auto-create categories', async () => {
      const items = [
        {
          name: 'Paneer Butter Masala',
          category: 'Main Course',
          price: 280,
          foodType: 'veg',
          variants: [
            { name: 'Half', price: 150 },
            { name: 'Full', price: 280 },
          ],
        },
        {
          name: 'Chicken Biryani',
          category: 'Biryani',
          price: 320,
          foodType: 'non_veg',
        },
        {
          name: 'Cold Coffee',
          category: 'Beverages',
          price: 120,
          foodType: 'beverage',
        },
      ];

      const res = await request(app)
        .post('/api/v1/products/bulk')
        .set('Authorization', `Bearer ${token}`)
        .send({ items })
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.importedCount).toBe(3);
      expect(res.body.data.products.length).toBe(3);

      // Verify in DB
      const dbProducts = await Product.find({ businessId });
      expect(dbProducts.length).toBe(3);
    });

    it('should handle duplicate product names by upserting without throwing error', async () => {
      await Product.create({
        businessId,
        productId: 'PRD-EXISTING',
        name: 'Veg Burger',
        category: 'Fast Food',
        price: 99,
      });

      const items = [
        {
          name: 'Veg Burger',
          category: 'Fast Food',
          price: 119, // Updated price
        },
      ];

      const res = await request(app)
        .post('/api/v1/products/bulk')
        .set('Authorization', `Bearer ${token}`)
        .send({ items })
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.importedCount).toBe(1);

      const updated = await Product.findOne({ businessId, name: 'Veg Burger' });
      expect(updated.price).toBe(119);
    });
  });

  describe('GET /api/v1/sales/report (Authoritative Sales Report API)', () => {
    beforeEach(async () => {
      const now = new Date();
      const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);

      // 1. Completed Cash Order (Today, Dine-in)
      await Order.create({
        businessId,
        orderNumber: 'ORD-101',
        orderType: 'dineIn',
        tableNumber: 'T-01',
        customerName: 'Rahul',
        customerPhone: '9876543210',
        status: 'completed',
        paymentStatus: 'paid',
        paymentMethod: 'Cash',
        items: [
          { name: 'Paneer Butter Masala', price: 280, quantity: 2, foodType: 'veg' },
          { name: 'Butter Naan', price: 40, quantity: 4, foodType: 'veg' },
        ],
        subtotal: 720,
        discountAmount: 20,
        taxAmount: 35,
        cgst: 17.5,
        sgst: 17.5,
        igst: 0,
        totalAmount: 735,
        createdAt: now,
      });

      // 2. Completed UPI Order (Today, Takeaway)
      await Order.create({
        businessId,
        orderNumber: 'ORD-102',
        orderType: 'takeaway',
        customerName: 'Anjali',
        customerPhone: '9876543211',
        status: 'completed',
        paymentStatus: 'paid',
        paymentMethod: 'UPI',
        items: [
          { name: 'Chicken Biryani', price: 320, quantity: 1, foodType: 'non_veg' },
          { name: 'Cold Coffee', price: 120, quantity: 2, foodType: 'beverage' },
        ],
        subtotal: 560,
        discountAmount: 0,
        taxAmount: 28,
        cgst: 14,
        sgst: 14,
        igst: 0,
        totalAmount: 588,
        createdAt: now,
      });

      // 3. Completed Card Order (Yesterday, Delivery)
      await Order.create({
        businessId,
        orderNumber: 'ORD-103',
        orderType: 'delivery',
        customerName: 'Amit',
        customerPhone: '9876543212',
        status: 'completed',
        paymentStatus: 'paid',
        paymentMethod: 'Card',
        items: [
          { name: 'Veg Burger', price: 100, quantity: 3, foodType: 'veg' },
        ],
        subtotal: 300,
        discountAmount: 0,
        taxAmount: 15,
        cgst: 7.5,
        sgst: 7.5,
        igst: 0,
        totalAmount: 315,
        createdAt: yesterday,
      });

      // 4. Cancelled Order (should NOT be in report)
      await Order.create({
        businessId,
        orderNumber: 'ORD-104',
        orderType: 'dineIn',
        status: 'cancelled',
        paymentStatus: 'pending',
        paymentMethod: 'Cash',
        items: [{ name: 'Cancelled Item', price: 500, quantity: 1 }],
        subtotal: 500,
        totalAmount: 500,
        createdAt: now,
      });
    });

    it('should return complete all-time sales report with accurate summary and dynamic payment modes', async () => {
      const res = await request(app)
        .get('/api/v1/sales/report?period=allTime')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      const data = res.body.data;

      // Summary
      expect(data.summary.totalOrders).toBe(3);
      expect(data.summary.totalRevenue).toBe(1638); // 735 + 588 + 315
      expect(data.summary.grossSales).toBe(1580); // 720 + 560 + 300
      expect(data.summary.netSales).toBe(1560); // 1580 - 20
      expect(data.summary.totalDiscount).toBe(20);
      expect(data.summary.totalTax).toBe(78); // 35 + 28 + 15
      expect(data.summary.totalItems).toBe(12); // 6 + 3 + 3
      expect(data.summary.avgOrderValue).toBe(546); // 1638 / 3

      // Dynamic Payment Modes
      expect(data.paymentModes.length).toBe(3);
      const modes = data.paymentModes.map((p) => p.mode);
      expect(modes).toContain('Cash Payments');
      expect(modes).toContain('UPI / Digital QR');
      expect(modes).toContain('Cards (Debit/Credit)');

      // Order Types Breakdown
      expect(data.salesByOrderType.length).toBe(3);
      const types = data.salesByOrderType.map((t) => t.type);
      expect(types).toContain('Dine In');
      expect(types).toContain('Takeaway');
      expect(types).toContain('Delivery');

      // Top Products
      expect(data.topProducts.length).toBeGreaterThan(0);
      expect(data.topProducts[0]).toHaveProperty('name');
      expect(data.topProducts[0]).toHaveProperty('quantity');
      expect(data.topProducts[0]).toHaveProperty('revenue');

      // Orders list
      expect(data.orders.length).toBe(3);
      expect(data.orders[0]).toHaveProperty('orderNumber');
      expect(data.orders[0]).toHaveProperty('totalAmount');
    });

    it('should accurately filter by Today', async () => {
      const res = await request(app)
        .get('/api/v1/sales/report?period=today')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      const data = res.body.data;
      expect(data.summary.totalOrders).toBe(2);
      expect(data.summary.totalRevenue).toBe(1323); // 735 + 588
      expect(data.orders.length).toBe(2);
    });

    it('should accurately filter by Yesterday', async () => {
      const res = await request(app)
        .get('/api/v1/sales/report?period=yesterday')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      const data = res.body.data;
      expect(data.summary.totalOrders).toBe(1);
      expect(data.summary.totalRevenue).toBe(315);
      expect(data.orders.length).toBe(1);
      expect(data.orders[0].orderNumber).toBe('ORD-103');
    });

    it('should filter by custom date range', async () => {
      const now = new Date();
      const startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0).toISOString();
      const endDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59).toISOString();

      const res = await request(app)
        .get(`/api/v1/sales/report?startDate=${startDate}&endDate=${endDate}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.summary.totalOrders).toBe(2);
    });

    it('should return empty clean metrics when no sales exist in date range', async () => {
      const futureStart = new Date(2030, 0, 1).toISOString();
      const futureEnd = new Date(2030, 0, 2).toISOString();

      const res = await request(app)
        .get(`/api/v1/sales/report?startDate=${futureStart}&endDate=${futureEnd}`)
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      const data = res.body.data;
      expect(data.summary.totalOrders).toBe(0);
      expect(data.summary.totalRevenue).toBe(0);
      expect(data.paymentModes.length).toBe(0);
      expect(data.orders.length).toBe(0);
    });
  });
});
