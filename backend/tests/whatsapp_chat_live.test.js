const request = require('supertest');
const mongoose = require('mongoose');
require('./setup');
const app = require('../src/app');
const User = require('../src/models/User');
const Business = require('../src/models/Business');
const WhatsAppChat = require('../src/models/WhatsAppChat');
const WhatsAppMessage = require('../src/models/WhatsAppMessage');
const tokenService = require('../src/services/tokenService');

describe('WhatsApp Meta Live Chat System (/api/v1/whatsapp/chats & Webhook)', () => {
  let userA, businessA, tokenA;
  let userB, businessB, tokenB;

  beforeEach(async () => {
    // 1. Setup Business A
    userA = await User.create({
      name: 'Owner A',
      email: 'owner_a@apnapos.com',
      passwordHash: 'hashed_password_123',
      role: 'owner',
      status: 'active',
    });

    businessA = await Business.create({
      ownerId: userA._id,
      profile: { name: 'Store A', companyName: 'Store A Retail', phone: '9876543210' },
      address: { city: 'Mumbai', state: 'Maharashtra' },
    });

    userA.businessId = businessA._id;
    await userA.save();
    tokenA = tokenService.generateAccessToken(userA);

    // 2. Setup Business B
    userB = await User.create({
      name: 'Owner B',
      email: 'owner_b@apnapos.com',
      passwordHash: 'hashed_password_456',
      role: 'owner',
      status: 'active',
    });

    businessB = await Business.create({
      ownerId: userB._id,
      profile: { name: 'Store B', companyName: 'Store B Retail', phone: '9123456789' },
      address: { city: 'Delhi', state: 'Delhi' },
    });

    userB.businessId = businessB._id;
    await userB.save();
    tokenB = tokenService.generateAccessToken(userB);
  });

  afterEach(async () => {
    await WhatsAppChat.deleteMany({});
    await WhatsAppMessage.deleteMany({});
    await Business.deleteMany({});
    await User.deleteMany({});
  });

  it('1. Connects Meta WhatsApp Phone Number ID and persists settings', async () => {
    const res = await request(app)
      .post('/api/v1/whatsapp/chats/connect')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        phoneNumberId: '1391578214040423',
        phoneNumber: '+919709593705',
        wabaId: 'waba_999888',
        accessToken: 'EAAB_test_token',
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.phoneNumberId).toBe('1391578214040423');

    // Verify GET connection
    const statusRes = await request(app)
      .get('/api/v1/whatsapp/chats/connection')
      .set('Authorization', `Bearer ${tokenA}`);

    expect(statusRes.status).toBe(200);
    expect(statusRes.body.data.connected).toBe(true);
    expect(statusRes.body.data.phoneNumberId).toBe('1391578214040423');
  });

  it('2. Starts a new chat and sends an initial message', async () => {
    const res = await request(app)
      .post('/api/v1/whatsapp/chats/new')
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        customerPhone: '9709593705',
        customerName: 'Rahul Kumar',
        initialMessage: 'Hello Rahul! Welcome to Store A.',
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.chat).toBeDefined();
    expect(res.body.data.chat.customerPhone).toBe('919709593705');
    expect(res.body.data.message).toBeDefined();
    expect(res.body.data.message.text).toBe('Hello Rahul! Welcome to Store A.');
    expect(res.body.data.message.direction).toBe('OUTGOING');
  });

  it('3. Sends a reply in an existing conversation and retrieves history', async () => {
    // Create initial chat
    const chat = await WhatsAppChat.create({
      businessId: businessA._id,
      customerPhone: '919876543210',
      customerName: 'Anjali Sharma',
      lastMessage: 'Hi',
      lastMessageAt: new Date(),
      lastMessageDirection: 'INCOMING',
    });

    // Send reply
    const sendRes = await request(app)
      .post(`/api/v1/whatsapp/chats/${chat._id}/messages`)
      .set('Authorization', `Bearer ${tokenA}`)
      .send({
        text: 'Thank you for your order! It is being prepared.',
      });

    expect(sendRes.status).toBe(200);
    expect(sendRes.body.data.message.direction).toBe('OUTGOING');
    expect(sendRes.body.data.message.text).toBe('Thank you for your order! It is being prepared.');

    // Fetch messages
    const getRes = await request(app)
      .get(`/api/v1/whatsapp/chats/${chat._id}/messages`)
      .set('Authorization', `Bearer ${tokenA}`);

    expect(getRes.status).toBe(200);
    expect(getRes.body.data.messages.length).toBe(1);
    expect(getRes.body.data.messages[0].text).toBe('Thank you for your order! It is being prepared.');
  });

  it('4. Handles incoming customer message from Meta Webhook and adds to conversation', async () => {
    // Set phone number ID on business A
    businessA.whatsappSettings = {
      enabled: true,
      phoneNumberId: '1391578214040423',
    };
    await businessA.save();

    const webhookPayload = {
      object: 'whatsapp_business_account',
      entry: [
        {
          id: 'waba_123',
          changes: [
            {
              value: {
                messaging_product: 'whatsapp',
                metadata: {
                  display_phone_number: '919876543210',
                  phone_number_id: '1391578214040423',
                },
                contacts: [
                  {
                    profile: { name: 'Customer Priya' },
                    wa_id: '919899112233',
                  },
                ],
                messages: [
                  {
                    from: '919899112233',
                    id: 'wamid.HBg123456789==',
                    timestamp: '1728640000',
                    text: { body: 'Can I add extra cheese to my pizza?' },
                    type: 'text',
                  },
                ],
              },
              field: 'messages',
            },
          ],
        },
      ],
    };

    const hookRes = await request(app)
      .post('/api/v1/whatsapp/webhook')
      .send(webhookPayload);

    expect(hookRes.status).toBe(200);
    expect(hookRes.body.processedMessages).toBe(1);

    // Verify conversation was created
    const chat = await WhatsAppChat.findOne({
      businessId: businessA._id,
      customerPhone: '919899112233',
    });
    expect(chat).toBeDefined();
    expect(chat.customerName).toBe('Customer Priya');
    expect(chat.lastMessage).toBe('Can I add extra cheese to my pizza?');
    expect(chat.unreadCount).toBe(1);

    // Verify message was created
    const msg = await WhatsAppMessage.findOne({
      chatId: chat._id,
      direction: 'INCOMING',
    });
    expect(msg).toBeDefined();
    expect(msg.text).toBe('Can I add extra cheese to my pizza?');
  });

  it('5. Enforces multi-tenant isolation (Business B cannot view Business A chats)', async () => {
    const chatA = await WhatsAppChat.create({
      businessId: businessA._id,
      customerPhone: '919999999999',
      customerName: 'Tenant A VIP',
      lastMessage: 'Secret details',
    });

    const resB = await request(app)
      .get(`/api/v1/whatsapp/chats/${chatA._id}/messages`)
      .set('Authorization', `Bearer ${tokenB}`);

    expect(resB.status).toBe(404);
  });
});
