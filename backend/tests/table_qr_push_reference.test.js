require('./setup');
const mongoose = require('mongoose');
const Business = require('../src/models/Business');
const Product = require('../src/models/Product');
const Table = require('../src/models/Table');
const orderService = require('../src/services/orderService');
const pushes = require('../src/services/pushNotificationService');

test('Table 2 QR order retains its table reference in the closed-app push alert', async () => {
  const business = await Business.create({ ownerId: new mongoose.Types.ObjectId(),
    profile: { companyName: 'Test Cafe' }, orderSettings: { tableCount: 2 } });
  await Table.create({ businessId: business.id, tableNumber: 2, name: 'Table 2', floor: 'Ground', capacity: 4 });
  const product = await Product.create({ businessId: business.id, name: 'Achari Paneer Pizza', price: 309,
    category: new mongoose.Types.ObjectId(), isAvailable: true });
  const push = jest.spyOn(pushes, 'sendPushNotificationToBusiness').mockResolvedValue({ success: true });
  try {
    const result = await orderService.generatePosOrder(business.id, {
      orderType: 'dineIn', tableNumber: 'T02', orderSource: 'storefront', source: 'storefront', status: 'pending',
      customerName: 'Test guest', customerPhone: '919999999999',
      items: [{ productId: product.id, name: product.name, price: 309, quantity: 1, foodType: 'veg' }],
    });
    expect(result.order.tableNumber).toBe('T02');
    const alert = push.mock.calls.map(([args]) => args).find(args => args.data?.type === 'whatsapp_order_request');
    expect(alert).toBeDefined();
    expect(alert.data.tableNumber).toBe('T02');
    expect(alert.data.orderId).toBe(result.order.id);
  } finally { push.mockRestore(); }
});
