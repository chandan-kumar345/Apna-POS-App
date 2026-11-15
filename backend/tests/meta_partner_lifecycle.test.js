require('./setup');
const mongoose = require('mongoose');
const crypto = require('crypto');
const Business = require('../src/models/Business');
const Signup = require('../src/models/MetaSignupSession');
const service = require('../src/services/metaPartnerService');
const chatService = require('../src/services/whatsappChatService');
const User = require('../src/models/User');
const Chat = require('../src/models/WhatsAppChat');
const whatsappService = require('../src/services/whatsappService');
let business, ownerId;
const response = data => ({ ok: true, status: 200, json: async () => data });
beforeEach(async () => {
  ownerId = new mongoose.Types.ObjectId();
  business = await Business.create({ ownerId, name: 'Test Cafe', profile: { companyName: 'Test Cafe' } });
  process.env.META_APP_ID = 'test-app'; process.env.META_APP_SECRET = 'test-secret';
  process.env.META_EMBEDDED_SIGNUP_CONFIG_ID = 'test-config'; process.env.META_PUBLIC_BASE_URL = 'https://example.test';
  global.fetch = jest.fn(async (url) => {
    if (url.includes('/oauth/access_token')) return response({ access_token: 'tenant-token' });
    if (url.includes('/phone_numbers')) return response({ data: [{ id: '555001', display_phone_number: '+919876543210', verified_name: 'Test Cafe' }] });
    if (url.includes('/register') || url.includes('/subscribed_apps')) return response({ success: true });
    return response({ id: '555001', display_phone_number: '+919876543210', quality_rating: 'GREEN' });
  });
});

async function connect() {
  return service.connectPartnerWaba(business.id, { wabaId: '444001', phoneNumberId: '555001', accessToken: 'tenant-token' });
}

test('registration and subscription complete concurrently without losing either flag', async () => {
  const result = await connect();
  expect((await Business.findById(business.id)).whatsappSettings.enabled).toBe(false);
  await Promise.all([
    service.registerChannelPin(business.id, { channelId: result.channel.channelId, pin: '987654' }),
    service.subscribeChannelWebhook(business.id, { channelId: result.channel.channelId }),
  ]);
  const stored = await Business.findById(business.id);
  expect(stored.metaPartnerSettings.channels[0].pinRegistered).toBe(true);
  expect(stored.metaPartnerSettings.channels[0].webhookSubscribed).toBe(true);
  expect(stored.whatsappSettings.enabled).toBe(true);
  const status = await service.getPartnerStatus(business.id);
  expect(status.canSend).toBe(true);
  expect(status.partnerStatus).toBe('ACTIVE');
});

test('disconnect clears credentials and chat status stays disconnected', async () => {
  await connect();
  await service.disconnectPartner(business.id);
  const stored = await Business.findById(business.id);
  expect(stored.whatsappSettings.accessToken).toBe('');
  expect(stored.whatsappSettings.phoneNumberId).toBe('');
  const status = await chatService.getConnectionStatus(business.id, ownerId);
  expect(status.connected).toBe(false);
  expect(status.accessToken).toBeUndefined();
});

test('browser signup is business-bound, single use and stores only a hash of the session capability', async () => {
  const session = await service.startEmbeddedSignup(business.id, { userId: ownerId });
  const token = new URLSearchParams(new URL(session.url).hash.slice(1)).get('session');
  const stored = await Signup.findOne({ businessId: business.id });
  expect(stored.tokenHash).toBe(crypto.createHash('sha256').update(token).digest('hex'));
  expect(JSON.stringify(stored)).not.toContain(token);
  await service.completeEmbeddedSignup({ sessionToken: token, code: 'test-code', wabaId: '444001', phoneNumberId: '555001' });
  expect((await Signup.findById(stored.id)).status).toBe('COMPLETED');
  const count = fetch.mock.calls.length;
  await expect(service.completeEmbeddedSignup({ sessionToken: token, code: 'test-code', wabaId: '444001', phoneNumberId: '555001' })).rejects.toThrow('already used');
  expect(fetch.mock.calls.length).toBe(count);
  expect((await Business.findById(business.id)).whatsappSettings.phoneNumberId).toBe('555001');
});

test('a linked phone cannot be reused by another business', async () => {
  await connect();
  const other = await Business.create({ ownerId: new mongoose.Types.ObjectId(), profile: { companyName: 'Other Cafe' } });
  await expect(service.connectPartnerWaba(other.id, { wabaId: '444001', phoneNumberId: '555001', accessToken: 'tenant-token' })).rejects.toThrow('another business');
  expect((await Business.findById(other.id)).whatsappSettings.enabled).toBe(false);
});

test('an expired signup cannot change the stored account', async () => {
  const token = 'a'.repeat(64);
  await Signup.create({ tokenHash: crypto.createHash('sha256').update(token).digest('hex'), businessId: business.id,
    userId: ownerId, expiresAt: new Date(Date.now() - 1000) });
  await expect(service.completeEmbeddedSignup({ sessionToken: token, code: 'code', wabaId: '444001', phoneNumberId: '555001' })).rejects.toThrow('expired');
  expect(fetch).not.toHaveBeenCalled();
});

test('freeform test messages require this customer’s current reply window', async () => {
  const linked = await connect();
  await service.registerChannelPin(business.id, { channelId: linked.channel.channelId, pin: '987654' });
  await service.subscribeChannelWebhook(business.id, { channelId: linked.channel.channelId });
  const count = fetch.mock.calls.length;
  await expect(service.sendTestMessage(business.id, { recipientPhone: '+919999999999' })).rejects.toThrow('message you first');
  expect(fetch.mock.calls.length).toBe(count);
});

test('disconnected chat cannot send with old user or global credentials', async () => {
  await User.create({ _id: ownerId, businessId: business.id, name: 'Owner', email: 'test@example.test', passwordHash: 'test-only', role: 'owner',
    whatsappSettings: { enabled: true, phoneNumberId: 'old-phone', accessToken: 'old-token' } });
  const chat = await Chat.create({ businessId: business.id, customerPhone: '919999999999' });
  const send = jest.spyOn(whatsappService, 'sendChatMessage');
  await expect(chatService.sendMessage(business.id, chat.id, { text: 'test', userId: ownerId })).rejects.toThrow('Connect and enable');
  expect(send).not.toHaveBeenCalled();
  send.mockRestore();
});
