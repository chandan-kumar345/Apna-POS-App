jest.mock('../src/services/pushNotificationService', () => ({
  sendPushNotificationToBusiness: jest.fn(async () => ({ success: true })),
}));
jest.mock('../src/services/socketService', () => ({
  broadcastToBusiness: jest.fn(),
  emitOrderCreated: jest.fn(),
  emitWhatsAppOrderRequest: jest.fn(),
}));
require('./setup');
const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../src/app');
const Business = require('../src/models/Business');
const Table = require('../src/models/Table');
const Order = require('../src/models/Order');
const pushes = require('../src/services/pushNotificationService');
const sockets = require('../src/services/socketService');

describe('Public customer orders reach merchant acceptance', () => {
  let business;
  beforeEach(async () => {
    jest.clearAllMocks();
    business = await Business.create({ ownerId: new mongoose.Types.ObjectId(),
      profile: { companyName: 'Notify Cafe', slug: 'notify-cafe' }, orderSettings: { tableCount: 2 } });
    await Table.create({ businessId: business.id, tableNumber: 2, name: 'Table 2', floor: 'Ground', capacity: 4 });
  });
  const endpoint = '/api/v1/storefront/notify-cafe/order';
  const body = (type = 'delivery') => ({
    orderId: 'customer-order-1', orderNumber: '#ORD-CUSTOMER-1', orderType: type,
    items: [{ name: 'Medium Pizza', price: 479, quantity: 2, foodType: 'non_veg' }],
    subtotal: 958, totalAmount: 958, customerName: 'Guest', paymentMethod: 'UPI',
  });

  for (const type of ['delivery', 'takeaway', 'dineIn']) {
    test(`${type} persists pending and dispatches the acceptance notification`, async () => {
      const payload = body(type);
      if (type === 'dineIn') payload.tableNumber = 'T02';
      const response = await request(app).post(endpoint).send(payload);
      expect(response.status).toBe(201);
      const receipt = response.body.data;
      const saved = await Order.findById(receipt.orderId).lean();
      expect(saved.orderType).toBe(type);
      expect(saved.status).toBe('pending');
      expect(saved.orderSource).toBe('storefront');
      expect(saved.isPaid).toBe(false);
      expect(receipt.businessId).toBe(business.id);
      expect(receipt.orderNumber).toBe(payload.orderNumber);
      expect(sockets.emitWhatsAppOrderRequest).toHaveBeenCalledTimes(1);
      expect(pushes.sendPushNotificationToBusiness).toHaveBeenCalledWith(expect.objectContaining({
        businessId: business.id,
        data: expect.objectContaining({ type: 'whatsapp_order_request', orderSource: 'storefront',
          orderId: receipt.orderId, orderType: type, tableNumber: type === 'dineIn' ? 'T02' : '' }),
      }));
    });
  }

  test('legacy nested cart items survive the public API and reach the alert', async () => {
    const payload = body('takeaway');
    payload.items = [{ item: { id: 'pizza', name: 'Medium Pizza', price: 479,
      salePrice: 450, itemType: 'Non-Veg' }, quantity: 2, note: 'No onion' }];
    const response = await request(app).post(endpoint).send(payload);
    expect(response.status).toBe(201);
    const saved = await Order.findById(response.body.data.orderId).lean();
    expect(saved.items[0]).toMatchObject({ name: 'Medium Pizza', price: 450, quantity: 2,
      note: 'No onion', foodType: 'non_veg' });
    expect(pushes.sendPushNotificationToBusiness).toHaveBeenCalledTimes(1);
  });

  test('parallel retries return one receipt and one merchant alert', async () => {
    const results = await Promise.all([1, 2, 3].map(() => request(app).post(endpoint).send(body())));
    expect(results.map(r => r.status)).toEqual([201, 201, 201]);
    expect(new Set(results.map(r => r.body.data.orderId)).size).toBe(1);
    expect(await Order.countDocuments({ businessId: business.id })).toBe(1);
    expect(pushes.sendPushNotificationToBusiness).toHaveBeenCalledTimes(1);
    expect(sockets.emitWhatsAppOrderRequest).toHaveBeenCalledTimes(1);
  });

  test('invalid table and empty cart dispatch no acceptance alert', async () => {
    const invalid = body('dineIn');
    invalid.tableNumber = 'T99';
    expect((await request(app).post(endpoint).send(invalid)).status).toBe(400);
    expect((await request(app).post(endpoint).send({ ...body(), items: [] })).status).toBe(400);
    expect(pushes.sendPushNotificationToBusiness).not.toHaveBeenCalled();
  });
});
