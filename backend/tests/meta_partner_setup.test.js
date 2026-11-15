jest.mock('../src/models/Business', () => ({
  findById: jest.fn(), findByIdAndUpdate: jest.fn(), findOne: jest.fn(), updateOne: jest.fn(),
}));
jest.mock('../src/models/User', () => ({ findByIdAndUpdate: jest.fn() }));
jest.mock('../src/models/WhatsAppMessage', () => ({ aggregate: jest.fn(), findOne: jest.fn() }));
jest.mock('../src/models/WhatsAppChat', () => ({ countDocuments: jest.fn() }));
jest.mock('../src/models/MetaSignupSession', () => ({ create: jest.fn(), findOneAndUpdate: jest.fn(), updateOne: jest.fn() }));
const Business = require('../src/models/Business');
const Message = require('../src/models/WhatsAppMessage');
const Chat = require('../src/models/WhatsAppChat');
const Signup = require('../src/models/MetaSignupSession');
const service = require('../src/services/metaPartnerService');
const tenant = '507f1f77bcf86cd799439011';
const channel = { channelId: 'line-1', phoneNumberId: '555001', wabaId: '444001', pinRegistered: false, webhookSubscribed: false };
const business = (extra = {}) => ({ _id: tenant, name: 'Test cafe', whatsappSettings: {}, metaPartnerSettings: {}, ...extra });
const response = (data, ok = true, status = 200) => ({ ok, status, json: async () => data });
beforeEach(() => {
  jest.clearAllMocks();
  global.fetch = jest.fn();
  Business.findById.mockReturnValue({ lean: async () => business() });
  Business.findOne.mockReturnValue({ lean: async () => null });
  Business.findByIdAndUpdate.mockResolvedValue(business());
  delete process.env.WHATSAPP_ACCESS_TOKEN;
  delete process.env.META_APP_ID;
  delete process.env.META_APP_SECRET;
});
test('an unconfigured business has no fabricated channel or verified metrics', async () => {
  const result = await service.getChannels(tenant);
  expect(result.channels).toEqual([]);
  const status = await service.getPartnerStatus(tenant);
  expect(status.partnerStatus).toBe('NOT_CONFIGURED');
  expect(status.qualityRating).toBe('UNKNOWN');
  expect(status.metaPartnerVerified).toBe(false);
});
test('register failure does not mark the phone as registered', async () => {
  Business.findById.mockReturnValue({ lean: async () => business({
    whatsappSettings: { accessToken: 'tenant-token', phoneNumberId: channel.phoneNumberId },
    metaPartnerSettings: { channels: [channel] },
  }) });
  fetch.mockResolvedValue(response({ error: { code: 100, message: 'Invalid PIN' } }, false, 400));
  await expect(service.registerChannelPin(tenant, { channelId: 'line-1', pin: '111111' })).rejects.toThrow();
  expect(Business.updateOne).not.toHaveBeenCalled();
});
test('registration cannot target a different tenant or missing channel', async () => {
  await expect(service.registerChannelPin(tenant, { channelId: 'other-line', pin: '123456' })).rejects.toThrow();
  expect(fetch).not.toHaveBeenCalled();
});
test('PIN must have exactly six digits and has no default', async () => {
  await expect(service.registerChannelPin(tenant, { channelId: 'line-1', pin: '12' })).rejects.toThrow();
  expect(fetch).not.toHaveBeenCalled();
});
test('webhook subscription failure is visible and never saved as success', async () => {
  Business.findById.mockReturnValue({ lean: async () => business({
    whatsappSettings: { accessToken: 'tenant-token', phoneNumberId: channel.phoneNumberId },
    metaPartnerSettings: { channels: [channel] },
  }) });
  fetch.mockResolvedValue(response({ error: { message: 'Permission denied' } }, false, 403));
  await expect(service.subscribeChannelWebhook(tenant, { channelId: 'line-1' })).rejects.toThrow();
  expect(Business.updateOne).not.toHaveBeenCalled();
});
test('test message cannot fall back to platform-wide credentials', async () => {
  process.env.WHATSAPP_ACCESS_TOKEN = 'platform-token';
  await expect(service.sendTestMessage(tenant, { recipientPhone: '+919876543210' })).rejects.toThrow();
  expect(fetch).not.toHaveBeenCalled();
});
test('default template suggestions are drafts until Meta approves them', async () => {
  const result = await service.getTemplates(tenant);
  expect(result.templates.length).toBeGreaterThan(0);
  expect(result.templates.every(t => t.status === 'NOT_SUBMITTED' && !t.isLiveSynced)).toBe(true);
});
test('analytics are measured from tenant messages rather than demo numbers', async () => {
  Message.aggregate.mockResolvedValue([]);
  Chat.countDocuments.mockResolvedValue(0);
  const result = await service.getMessagingAnalytics(tenant);
  expect(result.sentToday).toBe(0);
  expect(result.failedCount).toBe(0);
  expect(result.deliveredRate).toBe('—');
  expect(result.customerServiceWindowStatus).toBe('PER_CUSTOMER');
});

test('OAuth performs an actual code exchange and verifies the selected WABA phone', async () => {
  process.env.META_APP_ID = 'app-id'; process.env.META_APP_SECRET = 'app-secret';
  fetch.mockResolvedValueOnce(response({ access_token: 'exchanged-token' }))
    .mockResolvedValueOnce(response({ data: [{ id: '555001', display_phone_number: '+919876543210', verified_name: 'Test cafe' }] }));
  const result = await service.exchangeEmbeddedSignupOAuth(tenant, { code: 'one-time-code', wabaId: '444001', phoneNumberId: '555001' });
  expect(fetch).toHaveBeenCalledTimes(2);
  expect(fetch.mock.calls[0][1].body).toContain('code=one-time-code');
  expect(fetch.mock.calls[1][0]).toContain('/444001/phone_numbers');
  expect(result.channel.phoneNumberId).toBe('555001');
  expect(result.channel.isActive).toBe(false);
  expect(JSON.stringify(result)).not.toContain('exchanged-token');
});
test('an invalid OAuth code never saves any connection', async () => {
  process.env.META_APP_ID = 'app-id'; process.env.META_APP_SECRET = 'app-secret';
  fetch.mockResolvedValue(response({ error: { code: 100 } }, false, 400));
  await expect(service.exchangeEmbeddedSignupOAuth(tenant, { code: 'invalid', wabaId: '444001', phoneNumberId: '555001' })).rejects.toThrow();
  expect(Business.findByIdAndUpdate).not.toHaveBeenCalled();
});
test('a phone outside the selected WABA cannot be linked', async () => {
  fetch.mockResolvedValue(response({ data: [{ id: 'other-phone' }] }));
  await expect(service.connectPartnerWaba(tenant, { wabaId: '444001', phoneNumberId: '555001', accessToken: 'token' })).rejects.toThrow('does not belong');
  expect(Business.findByIdAndUpdate).not.toHaveBeenCalled();
});
test('missing server configuration blocks signup instead of connecting a shared demo account', async () => {
  await expect(service.startEmbeddedSignup(tenant, { userId: tenant })).rejects.toThrow('not configured');
  expect(Signup.create).not.toHaveBeenCalled();
});
test('a used or expired browser session cannot exchange another code', async () => {
  Signup.findOneAndUpdate.mockResolvedValue(null);
  await expect(service.completeEmbeddedSignup({ sessionToken: 'a'.repeat(64), code: 'code', wabaId: '444001', phoneNumberId: '555001' })).rejects.toThrow('expired or was already used');
  expect(fetch).not.toHaveBeenCalled();
  expect(Signup.findOneAndUpdate.mock.calls[0][0].status).toBe('PENDING');
  expect(Signup.findOneAndUpdate.mock.calls[0][0].expiresAt.$gt).toBeInstanceOf(Date);
});
test('Meta token expiry requests reconnect without logging the POS user out', async () => {
  Business.findById.mockReturnValue({ lean: async () => business({ whatsappSettings: {
    accessToken: 'tenant-token', phoneNumberId: '555001', wabaId: '444001',
  } }) });
  fetch.mockResolvedValue(response({ error: { code: 190 } }, false, 401));
  const status = await service.getPartnerStatus(tenant);
  expect(status.partnerStatus).toBe('RECONNECT_REQUIRED');
  expect(status.canSend).toBe(false);
  await expect(service._graph('555001', 'token')).rejects.toMatchObject({ statusCode: 409 });
});
test('a valid registration alone does not enable messaging', async () => {
  Business.findById.mockReturnValue({ lean: async () => business({ whatsappSettings: {
    accessToken: 'tenant-token', phoneNumberId: '555001', wabaId: '444001',
  }, metaPartnerSettings: { channels: [channel] } }) });
  fetch.mockResolvedValue(response({ success: true }));
  Business.updateOne.mockResolvedValue({ matchedCount: 0 });
  await expect(service.registerChannelPin(tenant, { channelId: 'line-1', pin: '123456' })).rejects.toThrow('connection changed');
});
