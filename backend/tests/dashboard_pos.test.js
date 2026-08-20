const request = require('supertest');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const app = require('../src/app');
const Business = require('../src/models/Business');
const User = require('../src/models/User');
const Product = require('../src/models/Product');
const Order = require('../src/models/Order');
const Customer = require('../src/models/Customer');
const tokenService = require('../src/services/tokenService');
require('./setup');

describe('Production POS & Dashboard API Tests', () => {
  let token;
  let businessId;
  let userId;

  beforeEach(async () => {
    const dummyUserId = new mongoose.Types.ObjectId();
    const business = await Business.create({
      ownerId: dummyUserId,
      profile: { name: 'Test POS Diner', phone: '9999988888' },
    });
    businessId = business._id.toString();

    const user = await User.create({
      _id: dummyUserId,
      email: 'owner@testpos.com',
      passwordHash: 'hashedpassword',
      role: 'owner',
      businessId: business._id,
      onboardingCompleted: true,
    });
    userId = user._id.toString();

    token = tokenService.generateAccessToken(user);
  });

  describe('GET /api/v1/products/pos (Optimized POS Product Loading)', () => {
    beforeEach(async () => {
      await Product.create([
        {
          businessId,
          productId: 'PRD-101',
          name: 'Masala Dosa',
          price: 150,
          category: 'South Indian',
          isAvailable: true,
          stock: 50,
        },
        {
          businessId,
          productId: 'PRD-102',
          name: 'Idli Sambar',
          price: 80,
          category: 'South Indian',
          isAvailable: true,
          stock: 40,
        },
        {
          businessId,
          productId: 'PRD-103',
          name: 'Paneer Butter Masala',
          price: 260,
          category: 'North Indian',
          isAvailable: true,
          stock: 30,
        },
        {
          businessId,
          productId: 'PRD-104',
          name: 'Sold Out Drink',
          price: 50,
          category: 'Beverages',
          isAvailable: false, // Inactive
          stock: 0,
        },
      ]);
    });

    it('should fetch only available products with lean projection', async () => {
      const res = await request(app)
        .get('/api/v1/products/pos')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.products.length).toBe(3); // Inactive excluded
      expect(res.body.data.products[0]).toHaveProperty('name');
      expect(res.body.data.products[0]).toHaveProperty('price');
      expect(res.body.data.products[0]).toHaveProperty('category');
    });

    it('should filter by category and search keyword', async () => {
      const res = await request(app)
        .get('/api/v1/products/pos?category=South Indian&search=Dosa')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.products.length).toBe(1);
      expect(res.body.data.products[0].name).toBe('Masala Dosa');
    });
  });

  describe('Dashboard Analytics & Historical Data Integrity', () => {
    beforeEach(async () => {
      // 1. Create a customer with past visit
      const pastDate = new Date(Date.now() - 10 * 24 * 60 * 60 * 1000);
      const existingCustomer = await Customer.create({
        businessId,
        name: 'Priya Sharma',
        phone: '9876543210',
        totalOrders: 3,
        totalSpent: 1200,
        firstVisit: pastDate,
        lastVisit: pastDate,
      });

      // 2. Create Completed Orders
      await Order.create([
        {
          businessId,
          orderNumber: 'ORD-001',
          orderType: 'dineIn',
          status: 'completed',
          items: [
            { name: 'Masala Dosa', price: 150, quantity: 2, totalAmount: 300 },
            { name: 'Filter Coffee', price: 50, quantity: 1, totalAmount: 50 },
          ],
          subtotal: 350,
          taxAmount: 17.5,
          cgst: 8.75,
          sgst: 8.75,
          totalAmount: 367.5,
          paymentMethod: 'cash',
          paymentStatus: 'paid',
          customerName: 'Priya Sharma',
          customerPhone: '9876543210',
          customerId: existingCustomer._id,
          createdAt: new Date(),
        },
        {
          businessId,
          orderNumber: 'ORD-002',
          orderType: 'takeaway',
          status: 'completed',
          items: [
            { name: 'Paneer Butter Masala', price: 260, quantity: 1, totalAmount: 260 },
          ],
          subtotal: 260,
          taxAmount: 13,
          cgst: 6.5,
          sgst: 6.5,
          totalAmount: 273,
          paymentMethod: 'upi',
          paymentStatus: 'paid',
          customerName: 'New Guest',
          customerPhone: '9123456789',
          createdAt: new Date(),
        },
        // Cancelled order (should NOT count towards revenue or product sales)
        {
          businessId,
          orderNumber: 'ORD-003',
          orderType: 'delivery',
          status: 'cancelled',
          items: [
            { name: 'Big Feast Pizza', price: 800, quantity: 1, totalAmount: 800 },
          ],
          subtotal: 800,
          taxAmount: 40,
          totalAmount: 840,
          paymentMethod: 'card',
          createdAt: new Date(),
        },
      ]);

      // Create new customer record for 9123456789 created today
      await Customer.create({
        businessId,
        name: 'New Guest',
        phone: '9123456789',
        totalOrders: 1,
        totalSpent: 273,
        firstVisit: new Date(),
        lastVisit: new Date(),
      });
    });

    it('GET /api/v1/dashboard/summary should calculate totalOrders and revenue excluding cancelled orders', async () => {
      const res = await request(app)
        .get('/api/v1/dashboard/summary?period=Today')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.summary.totalOrders).toBe(2);
      expect(res.body.data.summary.totalRevenue).toBe(640.5); // 367.5 + 273
    });

    it('GET /api/v1/dashboard/order-types should return order type breakdown', async () => {
      const res = await request(app)
        .get('/api/v1/dashboard/order-types?period=Today')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.dineIn.count).toBe(1);
      expect(res.body.data.dineIn.amount).toBe(367.5);
      expect(res.body.data.takeaway.count).toBe(1);
      expect(res.body.data.takeaway.amount).toBe(273);
      expect(res.body.data.total.count).toBe(2);
    });

    it('GET /api/v1/dashboard/product-sales should aggregate items from historical snapshot', async () => {
      const res = await request(app)
        .get('/api/v1/dashboard/product-sales?period=Today')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      const items = res.body.data.items;
      expect(items.length).toBe(3); // Masala Dosa, Filter Coffee, Paneer Butter Masala (Pizza excluded because cancelled)
      const dosa = items.find((i) => i.productName === 'Masala Dosa');
      expect(dosa.quantity).toBe(2);
      expect(dosa.price).toBe(150);
      expect(dosa.totalAmount).toBe(300);
    });

    it('GET /api/v1/dashboard/customers should separate new vs returning customers accurately', async () => {
      const res = await request(app)
        .get('/api/v1/dashboard/customers?period=Today')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.newCustomers.length).toBe(1);
      expect(res.body.data.newCustomers[0].phone).toBe('9123456789');

      expect(res.body.data.returningCustomers.length).toBe(1);
      expect(res.body.data.returningCustomers[0].phone).toBe('9876543210');
    });

    it('GET /api/v1/dashboard/taxes should return GST, CGST, SGST breakdown from transaction data', async () => {
      const res = await request(app)
        .get('/api/v1/dashboard/taxes?period=Today')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.totalGST).toBe(30.5); // 17.5 + 13
      expect(res.body.data.cgst).toBe(15.25);
      expect(res.body.data.sgst).toBe(15.25);
    });

    it('GET /api/v1/dashboard/order-stats should count successful and cancelled orders', async () => {
      const res = await request(app)
        .get('/api/v1/dashboard/order-stats?period=Today')
        .set('Authorization', `Bearer ${token}`)
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.successfulOrders).toBe(2);
      expect(res.body.data.cancelledOrders).toBe(1);
      expect(res.body.data.totalOrders).toBe(3);
    });
  });
});
