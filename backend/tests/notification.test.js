const request = require('supertest');
const app = require('../src/app');
const { Notification } = require('../src/models/Notification');
const notificationService = require('../src/services/notificationService');
const cronService = require('../src/services/cronService');
const Business = require('../src/models/Business');
require('./setup');

describe('Notification Center APIs & Services', () => {
  let authToken;
  let userId;
  let businessId;

  const testUser = {
    email: 'notif_owner@apnapos.com',
    password: 'SecurePassword@123',
    phone: '9876543210',
  };

  beforeEach(async () => {
    const regRes = await request(app).post('/api/v1/auth/register').send(testUser);
    authToken = regRes.body.data.accessToken;
    userId = regRes.body.data.user.id;

    const meRes = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${authToken}`);
    businessId = meRes.body.data.business._id;
  });

  describe('1. Welcome Notification on Signup', () => {
    it('should have created a welcome notification upon registration with idempotency', async () => {
      const notifications = await Notification.find({ userId, type: 'welcome' });
      expect(notifications.length).toBe(1);
      expect(notifications[0].title).toBe('Welcome to Apna POS 🎉');
      expect(notifications[0].message).toContain('welcome to Apna POS!');
      expect(notifications[0].isRead).toBe(false);

      // Verify idempotency: calling createNotification with same key will not duplicate
      await notificationService.createNotification({
        userId,
        businessId,
        type: 'welcome',
        title: 'Welcome to Apna POS 🎉',
        message: 'Duplicate attempt',
        idempotencyKey: `welcome_${userId}`,
      });

      const notifsAfter = await Notification.find({ userId, type: 'welcome' });
      expect(notifsAfter.length).toBe(1);
    });
  });

  describe('2. New Lead Notification Trigger', () => {
    it('should generate a new lead notification when a lead is created from any source', async () => {
      const leadData = {
        name: 'Sanjeev Sharma',
        phone: '9876543211',
        source: 'Dine In',
        stage: 'New Lead',
      };

      const res = await request(app)
        .post('/api/v1/crm/leads')
        .set('Authorization', `Bearer ${authToken}`)
        .send(leadData);

      expect(res.status).toBe(201);

      const leadNotifs = await Notification.find({ type: 'new_lead' });
      expect(leadNotifs.length).toBe(1);
      expect(leadNotifs[0].title).toBe('New Lead Generated');
      expect(leadNotifs[0].message).toContain('Sanjeev Sharma');
      expect(leadNotifs[0].message).toContain('Dine In');
      expect(leadNotifs[0].metadata.source).toBe('Dine In');
    });
  });

  describe('3. New Order Notification Trigger', () => {
    it('should generate a new order notification when an order is created', async () => {
      const orderPayload = {
        orderType: 'dineIn',
        tableNumber: 'T-01',
        customerName: 'Aarav Mehta',
        customerPhone: '9876500000',
        items: [
          { name: 'Paneer Butter Masala', price: 250, quantity: 2 },
          { name: 'Butter Naan', price: 40, quantity: 4 },
        ],
        subtotal: 660,
        totalAmount: 660,
        paymentMethod: 'cash',
        isPaid: true,
      };

      const res = await request(app)
        .post('/api/v1/orders/generatePosOrder')
        .set('Authorization', `Bearer ${authToken}`)
        .send(orderPayload);

      expect(res.status).toBe(201);

      const orderNotifs = await Notification.find({ type: 'new_order' });
      expect(orderNotifs.length).toBe(1);
      expect(orderNotifs[0].title).toBe('New Order Received 🛍️');
      expect(orderNotifs[0].message).toContain('Order #');
      expect(orderNotifs[0].metadata.totalAmount).toBe(660);
      expect(orderNotifs[0].metadata.itemsCount).toBe(2);
    });
  });

  describe('4. Daily Sales Summary Notification & Cron', () => {
    it('should generate daily sales summary notification with calculated totals', async () => {
      let business = await Business.findOne({ ownerId: userId });
      if (!business) {
        business = await Business.create({ ownerId: userId, business: { timezone: 'Asia/Kolkata' } });
      }
      const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);

      const notif = await cronService.generateDailySummaryForBusiness(business, yesterday);
      expect(notif).toBeDefined();
      expect(notif.type).toBe('daily_sales_summary');
      expect(notif.title).toBe('Your Daily Business Summary 📊');
      expect(notif.message).toContain('business summary');

      // Verify idempotency: running twice does not duplicate
      const notif2 = await cronService.generateDailySummaryForBusiness(business, yesterday);
      expect(notif2._id.toString()).toBe(notif._id.toString());
    });
  });

  describe('5. Notification REST Endpoints', () => {
    it('should fetch paginated notifications with unread count', async () => {
      const res = await request(app)
        .get('/api/v1/notifications?page=1&limit=10')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.notifications).toBeDefined();
      expect(res.body.data.pagination).toBeDefined();
      expect(res.body.data.unreadCount).toBeGreaterThan(0);
    });

    it('should mark a notification as read', async () => {
      const notif = await Notification.findOne({ userId });
      expect(notif).toBeDefined();

      const res = await request(app)
        .patch(`/api/v1/notifications/${notif._id}/read`)
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.isRead).toBe(true);
      expect(res.body.data.readAt).toBeDefined();
    });

    it('should mark all notifications as read', async () => {
      const res = await request(app)
        .patch('/api/v1/notifications/read-all')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.success).toBe(true);

      const unreadCountRes = await request(app)
        .get('/api/v1/notifications/unread-count')
        .set('Authorization', `Bearer ${authToken}`);

      expect(unreadCountRes.body.data.unreadCount).toBe(0);
    });
  });
});
