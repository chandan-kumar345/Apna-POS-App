const mongoose = require('mongoose');
require('./setup');
const User = require('../src/models/User');
const Business = require('../src/models/Business');
const Order = require('../src/models/Order');
const Product = require('../src/models/Product');
const WhatsAppChat = require('../src/models/WhatsAppChat');
const WhatsAppMessage = require('../src/models/WhatsAppMessage');
const whatsappService = require('../src/services/whatsappService');
const whatsappChatService = require('../src/services/whatsappChatService');
const whatsappOrderSessionService = require('../src/services/whatsappOrderSessionService');
const aiAgentService = require('../src/services/aiAgentService');

describe('WhatsApp Concurrent Ordering, Takeaway, Delivery & Menu Delivery Flow', () => {
  let user, business;
  let pizzaProduct, burgerProduct;

  beforeEach(async () => {
    user = await User.create({
      name: 'Restaurant Owner',
      email: 'owner@concurrentpizza.com',
      passwordHash: 'hashed_password_123',
      role: 'owner',
      status: 'active',
    });

    business = await Business.create({
      ownerId: user._id,
      profile: { name: 'Pizza & Burger Hub', companyName: 'Pizza & Burger Hub', phone: '9876543210' },
      address: { street: 'Main Market', city: 'Delhi', state: 'Delhi', pincode: '110001' },
      whatsappSettings: {
        phoneNumberId: '1284061438133660',
        accessToken: 'test_token',
      },
      aiChatAgentSettings: {
        enabled: true,
        autoOrderTaking: true,
        autoMenuSuggest: true,
        autoReplyDelaySeconds: 1,
      },
    });

    user.businessId = business._id;
    await user.save();

    pizzaProduct = await Product.create({
      businessId: business._id,
      name: 'Margherita Pizza',
      category: new mongoose.Types.ObjectId(),
      price: 200,
      isVeg: true,
      variants: [
        { name: 'Regular', price: 200 },
        { name: 'Medium', price: 300 },
        { name: 'Large', price: 400 },
      ],
      isAvailable: true,
    });

    burgerProduct = await Product.create({
      businessId: business._id,
      name: 'Crispy Veg Burger',
      category: new mongoose.Types.ObjectId(),
      price: 120,
      isVeg: true,
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

  it('1. Generates and safely delivers Menu to customer on WhatsApp without length rejection', async () => {
    const reply = await aiAgentService.generateReply({
      business,
      chatId: null,
      customerPhone: '919888811111',
      customerName: 'Aarav',
      messageText: 'Menu please',
    });

    expect(reply).toBeDefined();
    expect(reply.replyText).toContain('MENU & SPECIALTIES');
    expect(reply.replyText).toContain('Margherita Pizza');
    expect(reply.replyText).toContain('Crispy Veg Burger');

    // Test WhatsApp send
    const sendRes = await whatsappService.sendChatMessage({
      to: '919888811111',
      text: reply.replyText,
      phoneNumberId: business.whatsappSettings.phoneNumberId,
      accessToken: business.whatsappSettings.accessToken,
    });

    expect(sendRes).toBeDefined();
    expect(sendRes.success).toBe(true);
  });

  it('2. Automatically chunks text messages exceeding 3800 chars into safe parts', async () => {
    const hugeText = '• Item line: ₹100\n'.repeat(300); // ~5,400 chars
    const chunks = whatsappService.splitTextIntoSafeChunks(hugeText, 3500);

    expect(chunks.length).toBeGreaterThanOrEqual(2);
    chunks.forEach((c) => {
      expect(c.length).toBeLessThanOrEqual(3500);
    });

    const sendRes = await whatsappService.sendChatMessage({
      to: '919888811111',
      text: hugeText,
      phoneNumberId: business.whatsappSettings.phoneNumberId,
      accessToken: business.whatsappSettings.accessToken,
    });

    expect(sendRes).toBeDefined();
    expect(sendRes.success).toBe(true);
  });

  it('3. Places Takeaway order and correctly sets orderType to takeaway', async () => {
    const reply = await aiAgentService.generateReply({
      business,
      chatId: null,
      customerPhone: '919888822222',
      customerName: 'Priya',
      messageText: 'pack 2 Crispy Veg Burger for takeaway',
    });

    expect(reply.orderPayload).toBeDefined();
    expect(reply.orderPayload.orderType).toBe('takeaway');
    expect(reply.orderPayload.items.length).toBe(1);
    expect(reply.orderPayload.items[0].name).toBe('Crispy Veg Burger');
    expect(reply.orderPayload.items[0].quantity).toBe(2);
    expect(reply.orderPayload.subtotal).toBe(240);
    expect(reply.orderPayload.totalAmount).toBe(252);
    expect(reply.replyText).toContain('Takeaway / Pickup');
  });

  it('4. Places Delivery order with extracted address and sets orderType to delivery', async () => {
    const reply = await aiAgentService.generateReply({
      business,
      chatId: null,
      customerPhone: '919888833333',
      customerName: 'Rohan',
      messageText: 'deliver 1 Margherita Pizza to Flat 502, Lotus Apartments, Sector 14',
    });

    expect(reply.orderPayload).toBeDefined();
    expect(reply.orderPayload.orderType).toBe('delivery');
    expect(reply.orderPayload.deliveryAddress).toContain('Lotus Apartments');
    expect(reply.replyText).toContain('Home Delivery');
    expect(reply.replyText).toContain('Lotus Apartments');
  });

  it('5. Handles multi-turn address update for active pending order', async () => {
    const orderService = require('../src/services/orderService');
    const orderResult = await orderService.generatePosOrder(business._id, {
      items: [
        {
          productId: pizzaProduct._id,
          name: pizzaProduct.name,
          price: pizzaProduct.price,
          quantity: 1,
          foodType: 'veg',
        },
      ],
      customerPhone: '919888844444',
      customerName: 'Sunita',
      source: 'whatsapp',
      orderSource: 'whatsapp',
      status: 'pending',
      orderType: 'takeaway',
    });

    const order = orderResult.order || orderResult;
    whatsappOrderSessionService.recordOrder(business._id, '919888844444', order);

    // Customer sends their address as the follow-up message
    const updateResult = await whatsappOrderSessionService.handleAddressOrTypeUpdate({
      businessId: business._id,
      customerPhone: '919888844444',
      messageText: 'my address is House 42, Green Avenue, Delhi',
      chat: { _id: new mongoose.Types.ObjectId() },
    });

    expect(updateResult).toBeDefined();
    expect(updateResult.isHandled).toBe(true);
    expect(updateResult.replyText).toContain('DELIVERY ADDRESS RECORDED');

    // Verify order in DB was updated to delivery with the address
    const updatedOrder = await Order.findById(order._id);
    expect(updatedOrder.orderType).toBe('delivery');
    expect(updatedOrder.deliveryAddress).toBe('House 42, Green Avenue, Delhi');
  });

  it('6. Concurrently processes multiple customers ordering at the same time on the same profile without cross-talk', async () => {
    const customer1Phone = '919888855551';
    const customer2Phone = '919888855552';
    const customer3Phone = '919888855553';

    // Simulate 3 customers messaging simultaneously
    const [res1, res2, res3] = await Promise.all([
      whatsappOrderSessionService.enqueue(business._id, customer1Phone, async () => {
        return await aiAgentService.generateReply({
          business,
          customerPhone: customer1Phone,
          customerName: 'Customer One',
          messageText: 'takeaway 2 Crispy Veg Burger',
        });
      }),
      whatsappOrderSessionService.enqueue(business._id, customer2Phone, async () => {
        return await aiAgentService.generateReply({
          business,
          customerPhone: customer2Phone,
          customerName: 'Customer Two',
          messageText: 'deliver 1 Margherita Pizza to Room 102, Blue Star Hotel',
        });
      }),
      whatsappOrderSessionService.enqueue(business._id, customer3Phone, async () => {
        return await aiAgentService.generateReply({
          business,
          customerPhone: customer3Phone,
          customerName: 'Customer Three',
          messageText: 'show menu',
        });
      }),
    ]);

    // Customer 1: Takeaway Burger
    expect(res1.orderPayload).toBeDefined();
    expect(res1.orderPayload.orderType).toBe('takeaway');
    expect(res1.orderPayload.items[0].name).toBe('Crispy Veg Burger');
    expect(res1.orderPayload.items[0].quantity).toBe(2);

    // Customer 2: Delivery Pizza
    expect(res2.orderPayload).toBeDefined();
    expect(res2.orderPayload.orderType).toBe('delivery');
    expect(res2.orderPayload.deliveryAddress).toContain('Blue Star Hotel');
    expect(res2.orderPayload.items[0].name).toContain('Margherita Pizza');

    // Customer 3: Menu inquiry
    expect(res3.orderPayload).toBeNull();
    expect(res3.replyText).toContain('MENU & SPECIALTIES');

    // Verify independent sessions
    const session1 = whatsappOrderSessionService.getSession(business._id, customer1Phone);
    const session2 = whatsappOrderSessionService.getSession(business._id, customer2Phone);
    expect(session1.customerPhone).toBe('919888855551');
    expect(session2.customerPhone).toBe('919888855552');
  });
});
