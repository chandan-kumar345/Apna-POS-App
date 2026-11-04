const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const Business = require('../src/models/Business');
const Product = require('../src/models/Product');
const whatsappOrderSessionService = require('../src/services/whatsappOrderSessionService');
const whatsappService = require('../src/services/whatsappService');

describe('WhatsApp Bot Product Image on Selection', () => {
  let mongoServer;
  let business;
  let pizzaWithImage;
  let burgerWithImageNoVariants;
  let drinkWithoutImage;

  beforeAll(async () => {
    mongoServer = await MongoMemoryServer.create();
    await mongoose.connect(mongoServer.getUri());

    business = await Business.create({
      ownerId: new mongoose.Types.ObjectId(),
      name: 'Pizza & Burger Point',
      companyName: 'Pizza & Burger Point',
      phone: '919876543210',
      whatsappSettings: {
        phoneNumberId: 'phone_id_test',
        accessToken: 'mock_token',
      },
    });

    pizzaWithImage = await Product.create({
      businessId: business._id,
      name: 'Double Cheese Pizza',
      category: new mongoose.Types.ObjectId(),
      price: 269,
      image: 'https://pub-885e2df0fc0347e7ad9b84025e7ae9fc.r2.dev/products/double_cheese.jpg',
      images: ['https://pub-885e2df0fc0347e7ad9b84025e7ae9fc.r2.dev/products/double_cheese.jpg'],
      isVeg: true,
      variants: [
        { name: 'Regular', price: 269 },
        { name: 'Medium', price: 369 },
        { name: 'Large', price: 469 },
      ],
      isAvailable: true,
    });

    burgerWithImageNoVariants = await Product.create({
      businessId: business._id,
      name: 'Crispy Veg Burger',
      category: new mongoose.Types.ObjectId(),
      price: 129,
      image: 'https://pub-885e2df0fc0347e7ad9b84025e7ae9fc.r2.dev/products/crispy_burger.jpg',
      images: ['https://pub-885e2df0fc0347e7ad9b84025e7ae9fc.r2.dev/products/crispy_burger.jpg'],
      isVeg: true,
      variants: [],
      isAvailable: true,
    });

    drinkWithoutImage = await Product.create({
      businessId: business._id,
      name: 'Fresh Lime Soda',
      category: new mongoose.Types.ObjectId(),
      price: 60,
      image: '',
      images: [],
      isVeg: true,
      variants: [],
      isAvailable: true,
    });
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongoServer.stop();
  });

  it('1. Shows product image and variant buttons when selecting a product with image and variants', async () => {
    const customerPhone = '919111222333';

    // Step 1: Start chat & choose Takeaway to get numbered menu
    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Rohit',
      messageText: 'Hi',
      messageId: 'msg_hi_1',
    });

    const menuRes = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Rohit',
      messageText: 'Takeaway',
      messageId: 'msg_takeaway_1',
    });

    const session = whatsappOrderSessionService.getSession(business._id, customerPhone);
    const matchedPizza = session.menuMapping.find((m) => m.name === 'Double Cheese Pizza');
    expect(matchedPizza).toBeDefined();
    expect(matchedPizza.image).toBe(pizzaWithImage.image);

    // Step 2: Customer selects pizza by number
    const selectionRes = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Rohit',
      messageText: `${matchedPizza.num}`,
      messageId: 'msg_select_pizza',
    });

    expect(selectionRes.handled).toBe(true);
    expect(selectionRes.session.state).toBe(whatsappOrderSessionService.STATES.WAITING_FOR_VARIANT_SELECTION);
    expect(selectionRes.replyText).toContain('You selected *Double Cheese Pizza*');
    expect(selectionRes.replyText).toContain('Regular');
    expect(selectionRes.replyText).toContain('Medium');
    expect(selectionRes.replyText).toContain('Large');
    expect(selectionRes.buttons).toBeDefined();
    expect(selectionRes.buttons.length).toBe(3);

    // CRITICAL: verify mediaUrl and messageType are returned for image presentation!
    expect(selectionRes.mediaUrl).toBe(pizzaWithImage.image);
    expect(selectionRes.messageType).toBe('image');

    // Step 3: Verify whatsappService simulates dispatch with mediaUrl and buttons
    const sendResult = await whatsappService.sendChatMessage({
      to: customerPhone,
      text: selectionRes.replyText,
      buttons: selectionRes.buttons,
      mediaUrl: selectionRes.mediaUrl,
      messageType: selectionRes.messageType,
      phoneNumberId: 'phone_id_test',
      accessToken: 'mock_token',
    });

    expect(sendResult.success).toBe(true);
    expect(sendResult.mediaUrl).toBe(pizzaWithImage.image);
    expect(sendResult.buttonsSent.length).toBe(3);
  });

  it('2. Shows product image and asks quantity when selecting a product with image and NO variants', async () => {
    const customerPhone = '919444555666';

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Simran',
      messageText: 'Hi',
      messageId: 'msg_hi_2',
    });

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Simran',
      messageText: 'Takeaway',
      messageId: 'msg_takeaway_2',
    });

    const session = whatsappOrderSessionService.getSession(business._id, customerPhone);
    const matchedBurger = session.menuMapping.find((m) => m.name === 'Crispy Veg Burger');
    expect(matchedBurger).toBeDefined();
    expect(matchedBurger.image).toBe(burgerWithImageNoVariants.image);

    // Customer selects burger
    const selectionRes = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Simran',
      messageText: `${matchedBurger.num}`,
      messageId: 'msg_select_burger',
    });

    expect(selectionRes.handled).toBe(true);
    expect(selectionRes.session.state).toBe(whatsappOrderSessionService.STATES.WAITING_FOR_QUANTITY);
    expect(selectionRes.replyText).toContain('You selected *Crispy Veg Burger*');
    expect(selectionRes.replyText).toContain('How many');
    expect(selectionRes.buttons).toBeNull();

    // Verify mediaUrl is returned for burger image
    expect(selectionRes.mediaUrl).toBe(burgerWithImageNoVariants.image);
    expect(selectionRes.messageType).toBe('image');
  });

  it('3. Safely falls back to text when product has no image', async () => {
    const customerPhone = '919777888999';

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Amit',
      messageText: 'Hi',
      messageId: 'msg_hi_3',
    });

    await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Amit',
      messageText: 'Takeaway',
      messageId: 'msg_takeaway_3',
    });

    const session = whatsappOrderSessionService.getSession(business._id, customerPhone);
    const matchedDrink = session.menuMapping.find((m) => m.name === 'Fresh Lime Soda');
    expect(matchedDrink).toBeDefined();

    const selectionRes = await whatsappOrderSessionService.processConversationMessage({
      business,
      customerPhone,
      customerName: 'Amit',
      messageText: `${matchedDrink.num}`,
      messageId: 'msg_select_drink',
    });

    expect(selectionRes.handled).toBe(true);
    expect(selectionRes.mediaUrl).toBeNull();
    expect(selectionRes.messageType).toBe('text');
  });
});
