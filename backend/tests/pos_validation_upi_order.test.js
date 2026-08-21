const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../src/app');
const Business = require('../src/models/Business');
const User = require('../src/models/User');
const Product = require('../src/models/Product');
const Order = require('../src/models/Order');
const Sale = require('../src/models/Sale');
const Cart = require('../src/models/Cart');
const tokenService = require('../src/services/tokenService');
require('./setup');

describe('POS Product Validation, Idempotent Order & UPI Generation Tests', () => {
  let token1;
  let token2;
  let businessId1;
  let businessId2;
  let userId1;
  let userId2;

  beforeEach(async () => {
    // 1. Setup Business & User 1
    const dummyUserId1 = new mongoose.Types.ObjectId();
    const business1 = await Business.create({
      ownerId: dummyUserId1,
      profile: { name: 'Main Cafe & Diner', phone: '9876500001' },
    });
    businessId1 = business1._id.toString();

    const user1 = await User.create({
      _id: dummyUserId1,
      email: 'merchant1@apnapos.com',
      passwordHash: 'hashedpwd1',
      role: 'owner',
      businessId: business1._id,
      onboardingCompleted: true,
    });
    userId1 = user1._id.toString();
    token1 = tokenService.generateAccessToken(user1);

    // 2. Setup Business & User 2 (For multi-tenant isolation checks)
    const dummyUserId2 = new mongoose.Types.ObjectId();
    const business2 = await Business.create({
      ownerId: dummyUserId2,
      profile: { name: 'Second Store', phone: '9876500002' },
    });
    businessId2 = business2._id.toString();

    const user2 = await User.create({
      _id: dummyUserId2,
      email: 'merchant2@apnapos.com',
      passwordHash: 'hashedpwd2',
      role: 'owner',
      businessId: business2._id,
      onboardingCompleted: true,
    });
    userId2 = user2._id.toString();
    token2 = tokenService.generateAccessToken(user2);
  });

  describe('1. Product Name Validation (Case-Insensitive & Business Scoped)', () => {
    it('should create a product with unique name successfully', async () => {
      const res = await request(app)
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          name: 'Paneer Tikka',
          price: 250,
          category: 'Starters',
          foodType: 'veg',
        })
        .expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.data.product.name).toBe('Paneer Tikka');
    });

    it('should reject exact duplicate product name for the same business', async () => {
      // First creation
      await request(app)
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          name: 'Paneer Tikka',
          price: 250,
          category: 'Starters',
        })
        .expect(201);

      // Duplicate creation attempt
      const res = await request(app)
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          name: 'Paneer Tikka',
          price: 260,
          category: 'Starters',
        })
        .expect(409);

      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('DUPLICATE_PRODUCT_NAME');
      expect(res.body.error.message).toContain('already exists');
    });

    it('should reject case-insensitive variations (e.g. paneer tikka, PANEER TIKKA)', async () => {
      // First creation
      await request(app)
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          name: 'Paneer Tikka',
          price: 250,
          category: 'Starters',
        })
        .expect(201);

      // lowercase variant
      const resLower = await request(app)
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          name: 'paneer tikka',
          price: 270,
          category: 'Starters',
        })
        .expect(409);

      expect(resLower.body.success).toBe(false);
      expect(resLower.body.error.code).toBe('DUPLICATE_PRODUCT_NAME');

      // UPPERCASE variant
      const resUpper = await request(app)
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          name: 'PANEER TIKKA',
          price: 280,
          category: 'Starters',
        })
        .expect(409);

      expect(resUpper.body.success).toBe(false);
      expect(resUpper.body.error.code).toBe('DUPLICATE_PRODUCT_NAME');
    });

    it('should allow the same product name for a different vendor/business', async () => {
      // Business 1 creates Paneer Tikka
      await request(app)
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${token1}`)
        .send({
          name: 'Paneer Tikka',
          price: 250,
          category: 'Starters',
        })
        .expect(201);

      // Business 2 creates Paneer Tikka (isolated multi-tenant scope)
      const res = await request(app)
        .post('/api/v1/products')
        .set('Authorization', `Bearer ${token2}`)
        .send({
          name: 'Paneer Tikka',
          price: 290,
          category: 'Starters',
        })
        .expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.data.product.name).toBe('Paneer Tikka');
    });

    it('should prevent updating a product to an already existing name', async () => {
      const p1 = await Product.create({
        businessId: businessId1,
        name: 'Veg Burger',
        price: 100,
        category: 'Fast Food',
      });

      const p2 = await Product.create({
        businessId: businessId1,
        name: 'Cheese Burger',
        price: 150,
        category: 'Fast Food',
      });

      // Attempt to rename Cheese Burger -> veg burger (conflict!)
      const res = await request(app)
        .put(`/api/v1/products/${p2._id}`)
        .set('Authorization', `Bearer ${token1}`)
        .send({
          name: 'veg burger',
        })
        .expect(409);

      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('DUPLICATE_PRODUCT_NAME');
    });

    it('should allow updating other product fields without changing the name', async () => {
      const p1 = await Product.create({
        businessId: businessId1,
        name: 'Veg Burger',
        price: 100,
        category: 'Fast Food',
      });

      const res = await request(app)
        .put(`/api/v1/products/${p1._id}`)
        .set('Authorization', `Bearer ${token1}`)
        .send({
          name: 'Veg Burger',
          price: 120,
          description: 'Delicious crispy patty',
        })
        .expect(200);

      expect(res.body.success).toBe(true);
      expect(res.body.data.product.price).toBe(120);
    });
  });

  describe('2. Generate POS Order API & Idempotency Protection', () => {
    it('should generate a POS order with the full requested payload structure', async () => {
      const payload = {
        VenderUserId: userId1,
        VenderCardId: '69df52b9c6eec3174cc3b0c4',
        CreatedByUserId: userId1,
        CreatedByCardId: '69df52b9c6eec3174cc3b0c4',
        isKOT: false,
        items: [
          {
            name: 'Masala Dosa',
            price: 99,
            quantity: 1,
            foodType: 'veg',
          },
        ],
        subtotal: 99,
        totalAmount: 99,
        paymentDetails: [
          {
            paymentType: 'CASH',
            paymentName: 'CASH',
            amount: 99,
            paymentMethod: 'CASH',
            ncReason: '',
          },
        ],
        ncReason: '',
        paymentMode: 'CASH',
        orderDevice: 'web',
        isPaid: true,
        isDineIn: false,
        R: 'R1',
        T: 'T01',
        reason: 'Not Specified',
        remarks: 'Not Specified',
        clientSyncId: '6a8829f55ae58ba3205cbbbe',
        syncId: '6a8829f55ae58ba3205cbbbe',
        localOrderId: '6a8829f55ae58ba3205cbbbe',
        _id: '6a8829f55ae58ba3205cbbbe',
        orderNo: '6a8829f55ae58ba3205cbbbe',
        orderNO: '6a8829f55ae58ba3205cbbbe',
        orderNumber: '6a8829f55ae58ba3205cbbbe',
        TokenNo: '6a8829f55ae58ba3205cbbbe',
        tokenNo: '6a8829f55ae58ba3205cbbbe',
        orderId: '6a8829f55ae58ba3205cbbbe',
        idempotencyKey: 'pos:generatePosOrder:6a8829f55ae58ba3205cbbbe',
      };

      const res = await request(app)
        .post('/api/v1/orders/generateposorder')
        .set('Authorization', `Bearer ${token1}`)
        .send(payload)
        .expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.data.order).toBeDefined();
      expect(res.body.data.order.orderNumber).toBe('6a8829f55ae58ba3205cbbbe');
      expect(res.body.data.order.totalAmount).toBe(99);
      expect(res.body.data.order.status).toBe('completed');
      expect(res.body.data.order.paymentStatus).toBe('paid');
      expect(res.body.data.order.idempotencyKey).toBe('pos:generatePosOrder:6a8829f55ae58ba3205cbbbe');
      expect(res.body.data.invoice).toBeDefined();
      expect(res.body.data.invoice.invoiceNumber).toBe('INV-6a8829f55ae58ba3205cbbbe');

      // Verify Sale record was created
      const sale = await Sale.findOne({ businessId: businessId1, orderId: res.body.data.order.id });
      expect(sale).not.toBeNull();
      expect(sale.totalAmount).toBe(99);
    });

    it('should be idempotent: duplicate request with same idempotencyKey returns existing order without creating duplicate orders or sales', async () => {
      const idempotencyKey = 'pos:generatePosOrder:TEST_IDEMPOTENT_KEY_999';
      const payload = {
        idempotencyKey,
        items: [
          {
            name: 'Paneer Butter Masala',
            price: 200,
            quantity: 1,
            foodType: 'veg',
          },
        ],
        subtotal: 200,
        totalAmount: 200,
        isPaid: true,
        paymentMode: 'UPI',
        paymentDetails: [
          {
            paymentType: 'UPI',
            paymentName: 'UPI',
            amount: 200,
            paymentMethod: 'UPI',
          },
        ],
      };

      // 1st invocation
      const res1 = await request(app)
        .post('/api/v1/orders/generateposorder')
        .set('Authorization', `Bearer ${token1}`)
        .send(payload)
        .expect(201);

      const order1Id = res1.body.data.order.id;

      // 2nd invocation with same idempotency key (simulating duplicate callback or double click)
      const res2 = await request(app)
        .post('/api/v1/orders/generateposorder')
        .set('Authorization', `Bearer ${token1}`)
        .send(payload)
        .expect(200);

      expect(res2.body.success).toBe(true);
      expect(res2.body.data.isExisting).toBe(true);
      expect(res2.body.data.order.id).toBe(order1Id);

      // Verify only 1 Order and 1 Sale document exist
      const orderCount = await Order.countDocuments({ businessId: businessId1, idempotencyKey });
      expect(orderCount).toBe(1);

      const saleCount = await Sale.countDocuments({ businessId: businessId1, orderNumber: res1.body.data.order.orderNumber });
      expect(saleCount).toBe(1);
    });

    it('should validate payment amount against order total when isPaid is true', async () => {
      const payload = {
        items: [{ name: 'Thali', price: 150, quantity: 1 }],
        subtotal: 150,
        totalAmount: 150,
        isPaid: true,
        paymentDetails: [
          {
            paymentType: 'CASH',
            amount: 50, // Short by 100!
          },
        ],
      };

      const res = await request(app)
        .post('/api/v1/orders/generateposorder')
        .set('Authorization', `Bearer ${token1}`)
        .send(payload)
        .expect(400);

      expect(res.body.success).toBe(false);
      expect(res.body.error.message).toContain('Payment amount (50) does not match or cover total order amount (150)');
    });

    it('should resolve items from Cart when cartId is passed', async () => {
      // 1. Create a Cart in DB
      const cart = await Cart.create({
        businessId: businessId1,
        tableNumber: 'T5',
        orderType: 'dineIn',
        items: [
          {
            productId: 'PRD-101',
            name: 'Cold Coffee',
            price: 80,
            effectivePrice: 80,
            quantity: 2,
            foodType: 'beverage',
          },
        ],
        subtotal: 160,
        itemCount: 2,
      });

      // 2. Generate POS Order using cartId
      const payload = {
        cartId: cart._id.toString(),
        isPaid: true,
        paymentMode: 'UPI',
        paymentDetails: [{ paymentType: 'UPI', amount: 160 }],
        idempotencyKey: `pos:cart:${cart._id}`,
      };

      const res = await request(app)
        .post('/api/v1/orders/generateposorder')
        .set('Authorization', `Bearer ${token1}`)
        .send(payload)
        .expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.data.order.items.length).toBe(1);
      expect(res.body.data.order.items[0].name).toBe('Cold Coffee');
      expect(res.body.data.order.totalAmount).toBe(160);
      expect(res.body.data.order.status).toBe('completed');
    });

    it('should support direct root alias /api/v1/generateposorder', async () => {
      const payload = {
        items: [{ name: 'Gulab Jamun', price: 60, quantity: 2 }],
        subtotal: 120,
        totalAmount: 120,
        isPaid: true,
        paymentMode: 'CASH',
      };

      const res = await request(app)
        .post('/api/v1/generateposorder')
        .set('Authorization', `Bearer ${token1}`)
        .send(payload)
        .expect(201);

      expect(res.body.success).toBe(true);
      expect(res.body.data.order.totalAmount).toBe(120);
    });
  });
});
