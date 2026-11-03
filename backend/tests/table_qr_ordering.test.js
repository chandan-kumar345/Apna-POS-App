require('./setup');
const mongoose = require('mongoose');
const tableService = require('../src/services/tableService');
const Business = require('../src/models/Business');
const Table = require('../src/models/Table');
const Order = require('../src/models/Order');
const storefrontController = require('../src/controllers/storefrontController');

describe('Table QR Ordering System Tests', () => {
  let businessId;
  const mockSlug = 'pizza-47';

  beforeEach(async () => {
    businessId = new mongoose.Types.ObjectId();
    const ownerId = new mongoose.Types.ObjectId();

    // Create mock business
    await Business.create({
      _id: businessId,
      ownerId,
      name: 'Pizza 47',
      slug: mockSlug,
      restaurantCode: 'R1',
      profile: {
        companyName: 'Pizza 47',
        slug: mockSlug,
        phone: '+91 9876543210',
      },
      orderSettings: {
        tableCount: 4,
      },
    });

    // Create 4 tables
    const tables = [
      { businessId, tableNumber: 1, name: 'Table 01', position: 1, floor: 'Ground Floor', capacity: 4, status: 'free' },
      { businessId, tableNumber: 2, name: 'Table 02', position: 2, floor: 'Ground Floor', capacity: 4, status: 'free' },
      { businessId, tableNumber: 3, name: 'Table 03', position: 3, floor: '1st Floor', capacity: 6, status: 'free' },
      { businessId, tableNumber: 4, name: 'Table 04', position: 4, floor: 'Terrace', capacity: 2, status: 'free' },
    ];
    await Table.insertMany(tables);
  });

  test('getTableQrs generates correct URL format apnaposs.vercel.app/company-name/R=R1&T=T01', async () => {
    const result = await tableService.getTableQrs(businessId);

    expect(result).toBeDefined();
    expect(result.slug).toBe('pizza-47');
    expect(result.restaurantCode).toBe('R1');
    expect(result.baseUrl).toBe('https://apnaposs.vercel.app/pizza-47');
    expect(result.tables.length).toBeGreaterThanOrEqual(4);

    // Verify Table 1 QR URL
    const table1 = result.tables.find((t) => t.tableNumber === 1);
    expect(table1).toBeDefined();
    expect(table1.tableCode).toBe('T01');
    expect(table1.directUrl).toBe('https://apnaposs.vercel.app/pizza-47/R=R1&T=T01');
    expect(table1.queryUrl).toBe('https://apnaposs.vercel.app/pizza-47?R=R1&T=T01');
    expect(table1.displayUrl).toBe('apnaposs.vercel.app/pizza-47/R=R1&T=T01');
  });

  test('Storefront controller parses table parameters and creates dine-in table order', async () => {
    // 1. Test getStorefront with ?R=R1&T=T01
    const reqGet = {
      params: { slug: 'pizza-47' },
      query: { R: 'R1', T: 'T01' },
    };
    let jsonResult = null;
    const resGet = {
      status: () => resGet,
      json: (data) => { jsonResult = data; },
    };

    await storefrontController.getStorefront(reqGet, resGet, (err) => { if (err) throw err; });

    expect(jsonResult).toBeDefined();
    expect(jsonResult.data.table).toBeDefined();
    expect(jsonResult.data.table.tableCode).toBe('T01');
    expect(jsonResult.data.table.isTableOrdering).toBe(true);

    // 2. Test createStorefrontOrder for table 1
    const reqOrder = {
      params: { slug: 'pizza-47' },
      body: {
        tableNumber: 'T01',
        orderType: 'dineIn',
        customerName: 'Aarav Patel',
        customerPhone: '+91 99999 11111',
        subtotal: 550,
        taxAmount: 27.5,
        deliveryCharge: 0,
        totalAmount: 577.5,
        paymentMethod: 'UPI',
        items: [
          { name: 'Margherita Pizza', price: 350, quantity: 1, foodType: 'veg' },
          { name: 'Garlic Bread', price: 200, quantity: 1, foodType: 'veg' },
        ],
      },
    };
    let orderResult = null;
    const resOrder = {
      status: () => resOrder,
      json: (data) => { orderResult = data; },
    };

    await storefrontController.createStorefrontOrder(reqOrder, resOrder, (err) => { if (err) throw err; });

    expect(orderResult).toBeDefined();
    expect(orderResult.data.orderId).toBeDefined();

    // Verify order was saved with tableNumber and dineIn
    const savedOrder = await Order.findById(orderResult.data.orderId);
    expect(savedOrder).toBeDefined();
    expect(savedOrder.tableNumber).toBe('T01');
    expect(savedOrder.orderType).toBe('dineIn');
    expect(savedOrder.orderSource).toBe('storefront');
    expect(savedOrder.totalAmount).toBe(577.5);
  });
});
