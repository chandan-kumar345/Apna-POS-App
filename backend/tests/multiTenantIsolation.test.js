const mongoose = require('mongoose');
require('./setup');
const Order = require('../src/models/Order');
const Product = require('../src/models/Product');
const Customer = require('../src/models/Customer');
const Table = require('../src/models/Table');
const authMiddleware = require('../src/middleware/authMiddleware');
const tokenService = require('../src/services/tokenService');
const User = require('../src/models/User');
const Business = require('../src/models/Business');

describe('Multi-Tenant Data Isolation Test Suite', () => {
  let tenantABusiness, tenantBBusiness;
  let tenantAUser, tenantBUser;
  let tenantAToken, tenantBToken;

  beforeEach(async () => {
    // 1. Create Tenant A
    tenantAUser = await User.create({
      name: 'Owner A',
      email: 'ownerA@apnapos.com',
      passwordHash: 'hashed_pw_A',
      role: 'owner',
      status: 'active',
    });
    tenantABusiness = await Business.create({
      ownerId: tenantAUser._id,
      profile: { name: 'Restaurant A', companyName: 'Restaurant A Ltd' },
    });
    tenantAUser.businessId = tenantABusiness._id;
    await tenantAUser.save();
    tenantAToken = tokenService.generateAccessToken(tenantAUser);

    // 2. Create Tenant B
    tenantBUser = await User.create({
      name: 'Owner B',
      email: 'ownerB@apnapos.com',
      passwordHash: 'hashed_pw_B',
      role: 'owner',
      status: 'active',
    });
    tenantBBusiness = await Business.create({
      ownerId: tenantBUser._id,
      profile: { name: 'Restaurant B', companyName: 'Restaurant B Ltd' },
    });
    tenantBUser.businessId = tenantBBusiness._id;
    await tenantBUser.save();
    tenantBToken = tokenService.generateAccessToken(tenantBUser);
  });

  describe('1. Inbound Request & Tenant Header Guard', () => {
    test('TC-MTH-01: Permitted when X-Business-ID matches authenticated businessId', async () => {
      const req = {
        headers: {
          authorization: `Bearer ${tenantAToken}`,
          'x-business-id': tenantABusiness._id.toString(),
        },
      };
      const res = {};
      let nextCalled = false;
      let nextError = null;

      await authMiddleware(req, res, (err) => {
        nextCalled = true;
        nextError = err;
      });

      expect(nextCalled).toBe(true);
      expect(nextError).toBeUndefined();
      expect(req.businessId.toString()).toBe(tenantABusiness._id.toString());
      expect(req.tenantOptions._tenantId.toString()).toBe(tenantABusiness._id.toString());
    });

    test('TC-MTH-02: REJECTED with 403 when X-Business-ID is spoofed (Tenant Mismatch)', async () => {
      // Attacker uses Tenant A token but attempts to pass Tenant B's businessId in X-Business-ID
      const req = {
        headers: {
          authorization: `Bearer ${tenantAToken}`,
          'x-business-id': tenantBBusiness._id.toString(),
        },
      };
      const res = {};
      let nextError = null;

      await authMiddleware(req, res, (err) => {
        nextError = err;
      });

      expect(nextError).toBeDefined();
      expect(nextError.statusCode).toBe(403);
      expect(nextError.code).toBe('TENANT_MISMATCH_FORBIDDEN');
    });
  });

  describe('2. Mongoose Plugin Tenant Isolation & Immutability', () => {
    test('TC-MTH-03: Cannot save new document without valid businessId', async () => {
      const invalidProduct = new Product({
        name: 'Ghost Burger',
        price: 99,
        category: 'Fast Food',
        // Missing businessId
      });

      await expect(invalidProduct.save()).rejects.toThrow(/businessId/i);
    });

    test('TC-MTH-04: Tenant Hijacking Prevention - Cannot mutate businessId on existing document', async () => {
      const productA = await Product.create({
        businessId: tenantABusiness._id,
        productId: 'PRD-A-001',
        name: 'Paneer Tikka',
        price: 250,
        category: 'Starters',
      });

      // Attempt to reassign productA to Tenant B
      productA.businessId = tenantBBusiness._id;
      await expect(productA.save()).rejects.toThrow(/Mutating businessId on existing Product is strictly forbidden/);
    });

    test('TC-MTH-05: Query Trap Guard - Rejects queries containing null/undefined businessId', async () => {
      await expect(
        Product.find({ businessId: null })
      ).rejects.toThrow(/Query executed with null\/undefined businessId/);
    });
  });

  describe('3. Cross-Tenant Data Isolation Partitioning', () => {
    test('TC-MTH-06: Tenant B queries do not see Tenant A orders', async () => {
      // Create Order for Tenant A
      await Order.create({
        businessId: tenantABusiness._id,
        orderNumber: 'ORD-A-101',
        orderType: 'dineIn',
        subtotal: 500,
        totalAmount: 500,
        items: [{ name: 'Pizza', price: 500, quantity: 1 }],
      });

      // Create Order for Tenant B
      await Order.create({
        businessId: tenantBBusiness._id,
        orderNumber: 'ORD-B-201',
        orderType: 'takeaway',
        subtotal: 150,
        totalAmount: 150,
        items: [{ name: 'Chai', price: 150, quantity: 1 }],
      });

      // Query as Tenant A
      const ordersA = await Order.find({ businessId: tenantABusiness._id });
      expect(ordersA.length).toBe(1);
      expect(ordersA[0].orderNumber).toBe('ORD-A-101');

      // Query as Tenant B
      const ordersB = await Order.find({ businessId: tenantBBusiness._id });
      expect(ordersB.length).toBe(1);
      expect(ordersB[0].orderNumber).toBe('ORD-B-201');
    });

    test('TC-MTH-07: Customer PII Isolation - Autocomplete does not leak across tenants', async () => {
      // Tenant A regular customer
      await Customer.create({
        businessId: tenantABusiness._id,
        phone: '9876543210',
        name: 'VIP Client A',
      });

      // Tenant B searches for that phone number
      const customerForB = await Customer.findOne({
        businessId: tenantBBusiness._id,
        phone: '9876543210',
      });

      expect(customerForB).toBeNull();
    });

    test('TC-MTH-08: WhatsApp Integration Isolation - Credentials never leak into unintegrated tenant', async () => {
      const whatsappChatService = require('../src/services/whatsappChatService');

      // Tenant A connects custom Meta WhatsApp integration
      tenantABusiness.whatsappSettings = {
        enabled: true,
        phoneNumberId: '999000111222',
        phoneNumber: '+919990001112',
        wabaId: '888000111222',
        accessToken: 'EAAG_TenantA_Secure_Token',
        appSecret: 'secret_A',
      };
      await tenantABusiness.save();

      // Tenant B has NOT connected WhatsApp
      const statusA = await whatsappChatService.getConnectionStatus(tenantABusiness._id);
      expect(statusA.connected).toBe(true);
      expect(statusA.phoneNumberId).toBe('999000111222');
      expect(statusA.accessToken).toBe('EAAG_TenantA_Secure_Token');

      const statusB = await whatsappChatService.getConnectionStatus(tenantBBusiness._id);
      expect(statusB.connected).toBe(false);
      expect(statusB.phoneNumberId).toBe('');
      expect(statusB.accessToken).toBe('');
    });

    test('TC-MTH-09: Dine-in Table Order KOT printing does not dispatch incoming WhatsApp order accept push notifications', async () => {
      const orderService = require('../src/services/orderService');
      const pushNotificationService = require('../src/services/pushNotificationService');
      const pushSpy = jest.spyOn(pushNotificationService, 'sendPushNotificationToBusiness').mockResolvedValue([]);

      // 1. In-store Dine-in table order with KOT printed (status: preparing)
      const dineInOrderResult = await orderService.generatePosOrder(tenantABusiness._id, {
        orderType: 'dine_in',
        tableNumber: 'T-5',
        orderSource: 'pos',
        status: 'preparing',
        paymentMethod: 'KOT Pending',
        items: [{ name: 'Margherita Pizza', price: 299, quantity: 1 }],
      });

      expect(['dine_in', 'dineIn']).toContain(dineInOrderResult.order.orderType);
      expect(pushSpy).not.toHaveBeenCalled();

      // 2. Incoming external WhatsApp delivery order
      await orderService.generatePosOrder(tenantABusiness._id, {
        orderType: 'delivery',
        orderSource: 'whatsapp',
        status: 'pending',
        customerName: 'WhatsApp Customer',
        customerPhone: '+919876543210',
        items: [{ name: 'Farmhouse Pizza', price: 399, quantity: 1 }],
      });

      expect(pushSpy).toHaveBeenCalled();
      const pushCall = pushSpy.mock.calls[0][0];
      expect(pushCall.data.type).toBe('whatsapp_order_request');
      expect(pushCall.data.orderSource).toBe('whatsapp');

      pushSpy.mockRestore();
    });
  });
});
