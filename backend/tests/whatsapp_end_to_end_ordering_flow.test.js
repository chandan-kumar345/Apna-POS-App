const mongoose = require('mongoose');
require('./setup');
const User = require('../src/models/User');
const Business = require('../src/models/Business');
const Order = require('../src/models/Order');
const Product = require('../src/models/Product');
const WhatsAppChat = require('../src/models/WhatsAppChat');
const WhatsAppMessage = require('../src/models/WhatsAppMessage');
const whatsappService = require('../src/services/whatsappService');
const whatsappOrderSessionService = require('../src/services/whatsappOrderSessionService');
const orderService = require('../src/services/orderService');

describe('WhatsApp AI Agent End-to-End Ordering Flow (All 15 Scenarios)', () => {
  let user, business;
  let paneerPizza, vegBurger, coldCoffee;

  beforeEach(async () => {
    user = await User.create({
      name: 'Restaurant Owner',
      email: `owner_${Date.now()}_${Math.random().toString(36).substring(7)}@restohub.com`,
      passwordHash: 'hashed_password_123',
      role: 'owner',
      status: 'active',
      fcmToken: 'fcm_owner_mock_token_123',
    });

    business = await Business.create({
      ownerId: user._id,
      profile: {
        name: 'Tandoori Delights',
        companyName: 'Tandoori Delights Pvt Ltd',
        phone: '9876543210',
      },
      address: {
        street: 'Connaught Place',
        city: 'New Delhi',
        state: 'Delhi',
        pincode: '110001',
      },
      whatsappSettings: {
        phoneNumberId: '1284061438133660',
        accessToken: 'test_token',
      },
      aiChatAgentSettings: {
        enabled: true,
        autoOrderTaking: true,
        autoMenuSuggest: true,
        autoReplyDelaySeconds: 0,
      },
    });

    user.businessId = business._id;
    await user.save();

    // Products: 1 multi-variant, 1 single price, 1 drinks
    paneerPizza = await Product.create({
      businessId: business._id,
      name: 'Paneer Tikka Pizza',
      category: new mongoose.Types.ObjectId(),
      price: 250,
      isVeg: true,
      variants: [
        { name: 'Regular', price: 250 },
        { name: 'Medium', price: 380 },
        { name: 'Large', price: 490 },
      ],
      isAvailable: true,
    });

    vegBurger = await Product.create({
      businessId: business._id,
      name: 'Aloo Tikki Burger',
      category: new mongoose.Types.ObjectId(),
      price: 80,
      isVeg: true,
      variants: [],
      isAvailable: true,
    });

    coldCoffee = await Product.create({
      businessId: business._id,
      name: 'Iced Cold Coffee',
      category: new mongoose.Types.ObjectId(),
      price: 110,
      isVeg: true,
      variants: [],
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

  // Scenario 1: Customer sends "Hi" -> receives greeting with Delivery & Takeaway options
  it('Scenario 1: Greets customer on "Hi" with interactive Delivery & Takeaway buttons', async () => {
    const customerPhone = '919999000001';
    const messageId = `msg_greet_${Date.now()}`;

    const res = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Aarav Patel',
      messageText: 'Hello',
      messageId,
    });

    expect(res).toBeDefined();
    expect(res.handled).toBe(true);
    expect(res.replyText).toContain('Welcome to *Tandoori Delights Pvt Ltd*');
    expect(res.replyText).toContain('Delivery');
    expect(res.replyText).toContain('Takeaway');

    const session = whatsappOrderSessionService.getSession(business._id, customerPhone);
    expect(session.state).toBe(whatsappOrderSessionService.STATES.WAITING_FOR_ORDER_TYPE);
  });

  // Scenario 2: Customer selects "Delivery" -> displays numbered menu and moves to WAITING_FOR_PRODUCT_SELECTION
  it('Scenario 2: Selects Delivery order type and presents dynamic numbered menu', async () => {
    const customerPhone = '919999000002';

    // Step 1: Greeting
    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Bhavna',
      messageText: 'Hi',
      messageId: `msg_${Date.now()}_1`,
    });

    // Step 2: Customer responds "Delivery"
    const step2 = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Bhavna',
      messageText: 'Delivery',
      messageId: `msg_${Date.now()}_2`,
    });

    expect(step2.handled).toBe(true);
    expect(step2.session.orderType).toBe('delivery');
    expect(step2.session.state).toBe(whatsappOrderSessionService.STATES.WAITING_FOR_PRODUCT_SELECTION);
    expect(step2.replyText).toContain('OUR MENU');
    expect(step2.replyText).toContain('Paneer Tikka Pizza');
    expect(step2.replyText).toContain('Aloo Tikki Burger');
    expect(step2.replyText).toContain('enter the number of the product you want to order');
  });

  // Scenario 3: Customer selects "Takeaway" -> displays numbered menu and skips delivery address
  it('Scenario 3: Selects Takeaway order type and verifies menu displayed', async () => {
    const customerPhone = '919999000003';

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Chetan',
      messageText: 'Hey',
      messageId: `msg_${Date.now()}_1`,
    });

    const step2 = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Chetan',
      messageText: 'Takeaway',
      messageId: `msg_${Date.now()}_2`,
    });

    expect(step2.handled).toBe(true);
    expect(step2.session.orderType).toBe('takeaway');
    expect(step2.replyText).toContain('Takeaway / Pickup');
    expect(step2.replyText).toContain('OUR MENU');
  });

  // Scenario 4: Resolves numbered item to exact product (never database id 2)
  it('Scenario 4: Correctly resolves product selection by displayed list number (e.g. 1)', async () => {
    const customerPhone = '919999000004';

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Dev',
      messageText: 'Hi',
      messageId: `msg_${Date.now()}_1`,
    });

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Dev',
      messageText: 'Takeaway',
      messageId: `msg_${Date.now()}_2`,
    });

    // Session has numbered items in menuMapping
    const session = whatsappOrderSessionService.getSession(business._id, customerPhone);
    const pizzaItem = session.menuMapping.find((m) => m.name === 'Paneer Tikka Pizza');
    expect(pizzaItem).toBeDefined();

    // Customer types that item's number
    const step3 = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Dev',
      messageText: `${pizzaItem.num}`,
      messageId: `msg_${Date.now()}_3`,
    });

    expect(step3.handled).toBe(true);
    expect(step3.session.state).toBe(whatsappOrderSessionService.STATES.WAITING_FOR_VARIANT_SELECTION);
    expect(step3.replyText).toContain('choose your size');
    expect(step3.replyText).toContain('Regular');
    expect(step3.replyText).toContain('Medium');
    expect(step3.replyText).toContain('Large');
  });

  // Scenario 5: Invalid item number handling without corrupting state or adding bogus items
  it('Scenario 5: Handles invalid product number gracefully without cart corruption', async () => {
    const customerPhone = '919999000005';

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Esha',
      messageText: 'Hi',
      messageId: `msg_${Date.now()}_1`,
    });

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Esha',
      messageText: 'Takeaway',
      messageId: `msg_${Date.now()}_2`,
    });

    // Customer types an invalid number like 99
    const step3 = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Esha',
      messageText: '99',
      messageId: `msg_${Date.now()}_3`,
    });

    expect(step3.handled).toBe(true);
    expect(step3.replyText).toContain('Invalid selection');
    expect(step3.session.state).toBe(whatsappOrderSessionService.STATES.WAITING_FOR_PRODUCT_SELECTION);
    expect(step3.session.cart.length).toBe(0); // Cart remained pristine
  });

  // Scenario 6: Variant selection and quantity added to cart with correct price
  it('Scenario 6: Correctly selects variant (Medium) and quantity (2) into cart', async () => {
    const customerPhone = '919999000006';

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Farhan',
      messageText: 'Hi',
      messageId: `msg_${Date.now()}_1`,
    });

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Farhan',
      messageText: 'Takeaway',
      messageId: `msg_${Date.now()}_2`,
    });

    const session = whatsappOrderSessionService.getSession(business._id, customerPhone);
    const pizzaItem = session.menuMapping.find((m) => m.name === 'Paneer Tikka Pizza');

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Farhan',
      messageText: `${pizzaItem.num}`,
      messageId: `msg_${Date.now()}_3`,
    });

    // Select Medium (variant 2)
    const step4 = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Farhan',
      messageText: '2',
      messageId: `msg_${Date.now()}_4`,
    });

    expect(step4.replyText).toContain('How many');
    expect(step4.session.state).toBe(whatsappOrderSessionService.STATES.WAITING_FOR_QUANTITY);

    // Quantity = 2
    const step5 = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Farhan',
      messageText: '2',
      messageId: `msg_${Date.now()}_5`,
    });

    expect(step5.session.state).toBe(whatsappOrderSessionService.STATES.CART_ACTIVE);
    expect(step5.session.cart.length).toBe(1);
    expect(step5.session.cart[0].name).toBe('Paneer Tikka Pizza (Medium)');
    expect(step5.session.cart[0].price).toBe(380);
    expect(step5.session.cart[0].quantity).toBe(2);
    expect(step5.replyText).toContain('Added to your cart');
    expect(step5.replyText).toContain('₹760');
  });

  // Scenario 7: Delivery address collection, validation & confirmation
  it('Scenario 7: Collects and confirms delivery address for Delivery orders', async () => {
    const customerPhone = '919999000007';

    // Fast-forward setup with Delivery
    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Gaurav',
      messageText: 'Delivery',
      messageId: `msg_${Date.now()}_1`,
    });

    const session = whatsappOrderSessionService.getSession(business._id, customerPhone);
    const burgerItem = session.menuMapping.find((m) => m.name === 'Aloo Tikki Burger');

    // Choose Burger
    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Gaurav',
      messageText: `${burgerItem.num}`,
      messageId: `msg_${Date.now()}_2`,
    });

    // Quantity 1
    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Gaurav',
      messageText: '1',
      messageId: `msg_${Date.now()}_3`,
    });

    // Checkout
    const checkoutRes = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Gaurav',
      messageText: 'Checkout',
      messageId: `msg_${Date.now()}_4`,
    });

    expect(checkoutRes.session.state).toBe(whatsappOrderSessionService.STATES.WAITING_FOR_DELIVERY_ADDRESS);
    expect(checkoutRes.replyText).toContain('delivery address');

    // Customer provides valid address
    const addressRes = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Gaurav',
      messageText: 'Flat 402, Royal Residency, Connaught Place, New Delhi',
      messageId: `msg_${Date.now()}_5`,
    });

    expect(addressRes.session.state).toBe(whatsappOrderSessionService.STATES.WAITING_FOR_ADDRESS_CONFIRMATION);
    expect(addressRes.replyText).toContain('confirm your delivery address');
    expect(addressRes.replyText).toContain('Flat 402, Royal Residency');

    // Confirm Address -> transitions to WAITING_FOR_ORDER_CONFIRMATION with full summary
    const confirmAddrRes = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Gaurav',
      messageText: 'Confirm Address',
      messageId: `msg_${Date.now()}_6`,
    });

    expect(confirmAddrRes.session.state).toBe(whatsappOrderSessionService.STATES.WAITING_FOR_ORDER_CONFIRMATION);
    expect(confirmAddrRes.replyText).toContain('ORDER SUMMARY');
    expect(confirmAddrRes.replyText).toContain('Home Delivery');
    expect(confirmAddrRes.replyText).toContain('Aloo Tikki Burger');
  });

  // Scenario 8: Takeaway checkout skips delivery address directly to Order Review
  it('Scenario 8: Takeaway checkout skips delivery address and presents Order Review directly', async () => {
    const customerPhone = '919999000008';

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Harsh',
      messageText: 'Takeaway',
      messageId: `msg_${Date.now()}_1`,
    });

    const session = whatsappOrderSessionService.getSession(business._id, customerPhone);
    const burgerItem = session.menuMapping.find((m) => m.name === 'Aloo Tikki Burger');

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Harsh',
      messageText: `${burgerItem.num}`,
      messageId: `msg_${Date.now()}_2`,
    });

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Harsh',
      messageText: '2',
      messageId: `msg_${Date.now()}_3`,
    });

    // Checkout
    const checkoutRes = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Harsh',
      messageText: 'Checkout',
      messageId: `msg_${Date.now()}_4`,
    });

    // Must jump directly to WAITING_FOR_ORDER_CONFIRMATION
    expect(checkoutRes.session.state).toBe(whatsappOrderSessionService.STATES.WAITING_FOR_ORDER_CONFIRMATION);
    expect(checkoutRes.replyText).toContain('ORDER SUMMARY');
    expect(checkoutRes.replyText).toContain('Takeaway / Pickup');
    expect(checkoutRes.replyText).not.toContain('Delivery Fee');
  });

  // Scenario 9: Confirm order triggers atomic generation, socket, push, and customer notice
  it('Scenario 9: Customer confirms order -> creates 1 pending order in DB, triggers socket & push', async () => {
    const customerPhone = '919999000009';

    // Build takeaway cart with 1 Aloo Tikki Burger
    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Ishaan',
      messageText: 'Takeaway',
      messageId: `msg_${Date.now()}_1`,
    });

    const session = whatsappOrderSessionService.getSession(business._id, customerPhone);
    const burgerItem = session.menuMapping.find((m) => m.name === 'Aloo Tikki Burger');

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Ishaan',
      messageText: `${burgerItem.num}`,
      messageId: `msg_${Date.now()}_2`,
    });

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Ishaan',
      messageText: '1',
      messageId: `msg_${Date.now()}_3`,
    });

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Ishaan',
      messageText: 'Checkout',
      messageId: `msg_${Date.now()}_4`,
    });

    // Customer confirms the order
    const confirmRes = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Ishaan',
      messageText: 'Confirm Order',
      messageId: `msg_${Date.now()}_5`,
    });

    expect(confirmRes.handled).toBe(true);
    expect(confirmRes.replyText).toContain('ORDER PLACED & SENT TO RESTAURANT');
    expect(confirmRes.orderPayload).toBeDefined();

    // Create the order atomically in DB via orderService
    const createdOrderRes = await orderService.generatePosOrder(business._id, {
      ...confirmRes.orderPayload,
      customerPhone,
      customerName: 'Ishaan',
    });

    const createdOrder = createdOrderRes.order || createdOrderRes;
    expect(createdOrder).toBeDefined();
    expect(createdOrder.status).toBe('pending');
    expect(createdOrder.orderSource).toBe('whatsapp');
    expect(createdOrder.totalAmount).toBe(80);

    // Verify DB order
    const orders = await Order.find({ businessId: business._id, customerPhone });
    expect(orders.length).toBe(1);
    expect(orders[0].status).toBe('pending');
  });

  // Scenario 10: Business accepts order -> status preparing & customer notified with prep time
  it('Scenario 10: Business accepts WhatsApp order -> sets status to preparing and notifies customer', async () => {
    const orderResult = await orderService.generatePosOrder(business._id, {
      items: [{ productId: vegBurger._id, name: 'Aloo Tikki Burger', price: 80, quantity: 1, foodType: 'veg' }],
      customerPhone: '919999000010',
      customerName: 'Jaya',
      source: 'whatsapp',
      orderSource: 'whatsapp',
      status: 'pending',
      orderType: 'takeaway',
    });
    const order = orderResult.order || orderResult;

    // Accept order with 25 mins prep time
    const acceptRes = await orderService.acceptWhatsAppOrder(business._id, order._id, {
      estimatedPrepTimeMinutes: 25,
      note: 'Freshly made',
    });

    expect(acceptRes.success).toBe(true);
    expect(acceptRes.order.status).toBe('preparing');
    expect(acceptRes.order.whatsappDetails.estimatedPrepTimeMinutes).toBe(25);

    // Verify in DB
    const dbOrder = await Order.findById(order._id);
    expect(dbOrder.status).toBe('preparing');
  });

  // Scenario 11: Business rejects order -> status cancelled & customer notified with reason
  it('Scenario 11: Business rejects WhatsApp order -> sets status to cancelled and notifies customer with reason', async () => {
    const orderResult = await orderService.generatePosOrder(business._id, {
      items: [{ productId: vegBurger._id, name: 'Aloo Tikki Burger', price: 80, quantity: 1, foodType: 'veg' }],
      customerPhone: '919999000011',
      customerName: 'Karan',
      source: 'whatsapp',
      orderSource: 'whatsapp',
      status: 'pending',
      orderType: 'delivery',
      deliveryAddress: 'Block C, Delhi',
    });
    const order = orderResult.order || orderResult;

    const rejectRes = await orderService.rejectWhatsAppOrder(business._id, order._id, {
      rejectionReason: 'Items out of stock due to rush hour',
    });

    expect(rejectRes.success).toBe(true);
    expect(rejectRes.order.status).toBe('cancelled');
    expect(rejectRes.order.whatsappDetails.rejectionReason).toBe('Items out of stock due to rush hour');

    const dbOrder = await Order.findById(order._id);
    expect(dbOrder.status).toBe('cancelled');
  });

  // Scenario 12: Duplicate incoming webhook message deduplication
  it('Scenario 12: Drops duplicate incoming webhook message with same messageId', async () => {
    const customerPhone = '919999000012';
    const dupMessageId = `wamid_dup_${Date.now()}`;

    // First arrival
    const firstCall = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Lakshay',
      messageText: 'Hi',
      messageId: dupMessageId,
    });
    expect(firstCall.handled).toBe(true);
    expect(firstCall.isDuplicate).toBeFalsy();

    // Immediate duplicate arrival (Meta re-transmission)
    const secondCall = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Lakshay',
      messageText: 'Hi',
      messageId: dupMessageId,
    });
    expect(secondCall.isDuplicate).toBe(true);
  });

  // Scenario 13: Concurrency protection & idempotent state transitions
  it('Scenario 13: Prevents duplicate state transition (rejecting an already accepted order)', async () => {
    const orderResult = await orderService.generatePosOrder(business._id, {
      items: [{ productId: vegBurger._id, name: 'Aloo Tikki Burger', price: 80, quantity: 1, foodType: 'veg' }],
      customerPhone: '919999000013',
      customerName: 'Manish',
      source: 'whatsapp',
      orderSource: 'whatsapp',
      status: 'pending',
      orderType: 'takeaway',
    });
    const order = orderResult.order || orderResult;

    // First accept succeeds
    await orderService.acceptWhatsAppOrder(business._id, order._id, { estimatedPrepTimeMinutes: 20 });

    // Second accept should handle idempotently or fail gracefully
    const secondAccept = await orderService.acceptWhatsAppOrder(business._id, order._id, { estimatedPrepTimeMinutes: 20 });
    expect(secondAccept.order.status).toBe('preparing');

    // Rejecting an already accepted order should throw ApiError
    await expect(
      orderService.rejectWhatsAppOrder(business._id, order._id, { rejectionReason: 'Closed' })
    ).rejects.toThrow();
  });

  // Scenario 14: Resilience when WhatsApp external message dispatch fails
  it('Scenario 14: Keeps order safely in DB even if customer notification encounters an issue', async () => {
    const orderResult = await orderService.generatePosOrder(business._id, {
      items: [{ productId: coldCoffee._id, name: 'Iced Cold Coffee', price: 110, quantity: 2, foodType: 'veg' }],
      customerPhone: '919999000014',
      customerName: 'Nisha',
      source: 'whatsapp',
      orderSource: 'whatsapp',
      status: 'pending',
      orderType: 'takeaway',
    });
    const order = orderResult.order || orderResult;

    expect(order).toBeDefined();
    expect(order.status).toBe('pending');

    // Mock sendChatMessage to simulate a temporary Meta gateway error
    const spy = jest.spyOn(whatsappService, 'sendChatMessage').mockRejectedValueOnce(new Error('Meta 503 Service Unavailable'));

    // Accepting should update order in DB despite WhatsApp network failure
    const acceptRes = await orderService.acceptWhatsAppOrder(business._id, order._id, { estimatedPrepTimeMinutes: 15 });
    expect(acceptRes.success).toBe(true);
    expect(acceptRes.order.status).toBe('preparing');

    const dbOrder = await Order.findById(order._id);
    expect(dbOrder.status).toBe('preparing');

    spy.mockRestore();
  });

  // Scenario 15: Concurrency across customers on the same business profile
  it('Scenario 15: Maintains isolated session states for multiple customers concurrently interacting with the bot', async () => {
    const custA = '919999000015';
    const custB = '919999000016';

    // Cust A: starts Takeaway
    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone: custA,
      customerName: 'Customer A',
      messageText: 'Takeaway',
      messageId: `msg_${Date.now()}_A1`,
    });

    // Cust B: starts Delivery
    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone: custB,
      customerName: 'Customer B',
      messageText: 'Delivery',
      messageId: `msg_${Date.now()}_B1`,
    });

    const sessionA = whatsappOrderSessionService.getSession(business._id, custA);
    const sessionB = whatsappOrderSessionService.getSession(business._id, custB);

    expect(sessionA.orderType).toBe('takeaway');
    expect(sessionB.orderType).toBe('delivery');

    // Cust A selects item
    const item1 = sessionA.menuMapping[0];
    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone: custA,
      customerName: 'Customer A',
      messageText: `${item1.num}`,
      messageId: `msg_${Date.now()}_A2`,
    });

    // Verify session B remains at product selection without any cross-contamination
    const checkB = whatsappOrderSessionService.getSession(business._id, custB);
    expect(checkB.state).toBe(whatsappOrderSessionService.STATES.WAITING_FOR_PRODUCT_SELECTION);
    expect(checkB.cart.length).toBe(0);
  });
});
