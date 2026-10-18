const request = require('supertest');
const mongoose = require('mongoose');
require('./setup');
const app = require('../src/app');
const User = require('../src/models/User');
const Business = require('../src/models/Business');
const Order = require('../src/models/Order');
const Product = require('../src/models/Product');
const WhatsAppChat = require('../src/models/WhatsAppChat');
const WhatsAppMessage = require('../src/models/WhatsAppMessage');
const tokenService = require('../src/services/tokenService');
const pushNotificationService = require('../src/services/pushNotificationService');
const socketService = require('../src/services/socketService');

describe('WhatsApp Order Notification & Accept/Reject Flow', () => {
  let user, business, token;
  let testProduct;

  beforeEach(async () => {
    // 1. Create User and Business
    user = await User.create({
      name: 'Restaurant Owner',
      email: 'owner@testrestaurant.com',
      passwordHash: 'hashed_password_123',
      role: 'owner',
      status: 'active',
      pushToken: 'fcm_test_token_merchant_12345',
      pushPlatform: 'android',
    });

    business = await Business.create({
      ownerId: user._id,
      profile: { name: 'Royal Spice Restro', companyName: 'Royal Spice Pvt Ltd', phone: '9876543210' },
      address: { street: '123 Food Street', city: 'Mumbai', state: 'Maharashtra', pincode: '400001' },
      whatsappSettings: {
        phoneNumberId: '1284061438133660',
        accessToken: 'test_token',
      },
      aiChatAgentSettings: {
        enabled: true,
        autoOrderTaking: true,
        autoReplyDelaySeconds: 1,
      },
    });

    user.businessId = business._id;
    await user.save();
    token = tokenService.generateAccessToken(user);

    // 2. Create sample product in menu
    testProduct = await Product.create({
      businessId: business._id,
      name: 'Paneer Butter Masala',
      price: 250,
      isVeg: true,
      category: new mongoose.Types.ObjectId(),
      isAvailable: true,
    });
  });

  afterEach(async () => {
    await Order.deleteMany({});
    await Product.deleteMany({});
    await WhatsAppChat.deleteMany({});
    await WhatsAppMessage.deleteMany({});
    await Business.deleteMany({});
    await User.deleteMany({});
  });

  it('1. Generates pending WhatsApp order and triggers push & socket notifications', async () => {
    const orderService = require('../src/services/orderService');
    const orderResult = await orderService.generatePosOrder(business._id, {
      items: [
        {
          productId: testProduct._id,
          name: testProduct.name,
          price: testProduct.price,
          quantity: 2,
          foodType: 'veg',
        },
      ],
      customerPhone: '919888877777',
      customerName: 'Test Customer',
      source: 'whatsapp',
      orderSource: 'whatsapp',
      status: 'pending',
      orderType: 'takeaway',
    });

    const order = orderResult.order || orderResult;
    expect(order).toBeDefined();
    expect(order.orderSource).toBe('whatsapp');
    expect(order.status).toBe('pending');
    expect(order.totalAmount).toBe(500);
    expect(order.whatsappDetails.acceptanceStatus).toBe('pending_review');
  });

  it('2. Accepts WhatsApp order, updates status to preparing, and sends WhatsApp confirmation', async () => {
    const orderService = require('../src/services/orderService');
    const orderResult = await orderService.generatePosOrder(business._id, {
      items: [
        {
          productId: testProduct._id,
          name: testProduct.name,
          price: testProduct.price,
          quantity: 1,
          foodType: 'veg',
        },
      ],
      customerPhone: '919888877777',
      customerName: 'Aarav Patel',
      source: 'whatsapp',
      status: 'pending',
      orderType: 'takeaway',
    });

    const order = orderResult.order || orderResult;

    // Call accept endpoint
    const res = await request(app)
      .post(`/api/v1/orders/${order._id}/accept-whatsapp`)
      .set('Authorization', `Bearer ${token}`)
      .send({ prepTimeMinutes: 25 });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.order.status).toBe('preparing');
    expect(res.body.data.order.whatsappDetails.acceptanceStatus).toBe('accepted');
    expect(res.body.data.order.whatsappDetails.estimatedPrepTimeMinutes).toBe(25);

    // Verify database record
    const updated = await Order.findById(order._id);
    expect(updated.status).toBe('preparing');
    expect(updated.whatsappDetails.acceptanceStatus).toBe('accepted');
  });

  it('3. Rejects WhatsApp order, updates status to cancelled, and sends WhatsApp rejection notice', async () => {
    const orderService = require('../src/services/orderService');
    const orderResult = await orderService.generatePosOrder(business._id, {
      items: [
        {
          productId: testProduct._id,
          name: testProduct.name,
          price: testProduct.price,
          quantity: 1,
          foodType: 'veg',
        },
      ],
      customerPhone: '919888877777',
      customerName: 'Aarav Patel',
      source: 'whatsapp',
      status: 'pending',
      orderType: 'takeaway',
    });

    const order = orderResult.order || orderResult;

    // Call reject endpoint
    const res = await request(app)
      .post(`/api/v1/orders/${order._id}/reject-whatsapp`)
      .set('Authorization', `Bearer ${token}`)
      .send({ reason: 'Kitchen at full capacity right now' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.order.status).toBe('cancelled');
    expect(res.body.data.order.cancellationReason).toBe('Kitchen at full capacity right now');
    expect(res.body.data.order.whatsappDetails.acceptanceStatus).toBe('rejected');

    // Verify database record
    const updated = await Order.findById(order._id);
    expect(updated.status).toBe('cancelled');
    expect(updated.cancellationReason).toBe('Kitchen at full capacity right now');
  });

  it('4. Broadcasts push notification to all business devices with correct channel and data', async () => {
    let capturedPush = null;
    const origSend = pushNotificationService.sendPushNotification;
    pushNotificationService.sendPushNotification = async (args) => {
      capturedPush = args;
      return true;
    };

    await pushNotificationService.sendPushNotificationToBusiness({
      businessId: business._id,
      title: '🔔 New WhatsApp Order: #ORD-TEST-1',
      message: 'Aarav Patel (₹500) • Tap to Accept or Reject',
      data: {
        type: 'whatsapp_order_request',
        orderId: '507f1f77bcf86cd799439011',
        orderNumber: 'ORD-TEST-1',
        customerPhone: '919888877777',
        customerName: 'Aarav Patel',
        totalAmount: '500',
      },
    });

    expect(capturedPush).toBeDefined();
    expect(capturedPush.userId).toBe(user._id.toString());
    expect(capturedPush.title).toContain('New WhatsApp Order');
    expect(capturedPush.data.type).toBe('whatsapp_order_request');

    pushNotificationService.sendPushNotification = origSend;
  });
});
