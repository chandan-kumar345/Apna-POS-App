const mongoose = require('mongoose');
const crypto = require('crypto');
const Business = require('../models/Business');
const Message = require('../models/WhatsAppMessage');
const Chat = require('../models/WhatsAppChat');
const ApiError = require('../utils/ApiError');
const Signup = require('../models/MetaSignupSession');
const graphVersion = () => process.env.META_GRAPH_VERSION || 'v23.0';
const catalog = [
  { name: 'order_confirmation', category: 'UTILITY', displayName: 'Order confirmation', description: 'Your order has been accepted. We will let you know when it is ready.' },
  { name: 'ebill_receipt', category: 'UTILITY', displayName: 'Bill receipt', description: 'Thank you for your visit. Reply to this message to request a copy of your bill.' },
  { name: 'loyalty_cashback_earned', category: 'UTILITY', displayName: 'Loyalty Cashback Earned', description: 'Congratulations! You earned cashback on your order. Use your cashback balance on your next order.' },
  { name: 'loyalty_redemption_otp', category: 'UTILITY', displayName: 'Loyalty Redemption OTP', description: 'Your OTP to redeem your loyalty cashback on your order.' },
];

class MetaPartnerService {
  async _business(id) {
    if (!id) throw new ApiError(403, 'A business account is required.');
    const business = await Business.findById(id).lean();
    if (!business) throw new ApiError(404, 'Business not found.');
    return business;
  }

  async _graph(path, token, { method = 'GET', body } = {}) {
    if (!token) throw new ApiError(409, 'Connect this business to WhatsApp first.');
    try {
      const url = new URL(`https://graph.facebook.com/${graphVersion()}/${path}`);
      const secret = process.env.META_APP_SECRET || process.env.WHATSAPP_APP_SECRET;
      if (secret) url.searchParams.set('appsecret_proof', crypto.createHmac('sha256', secret).update(token).digest('hex'));
      const response = await fetch(url.toString(), {
        method, signal: AbortSignal.timeout(10000),
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        ...(body ? { body: JSON.stringify(body) } : {}),
      });
      const data = await response.json();
      if (!response.ok || data.error) {
        const error = new ApiError(data.error?.code === 190 ? 409 : 502,
          `Meta could not complete this request${data.error?.code ? ` (code ${data.error.code})` : ''}. ${data.error?.code === 190 ? 'Reconnect your WhatsApp account.' : 'Check account permissions and try again.'}`);
        error.metaCode = data.error?.code;
        throw error;
      }
      return data;
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError(503, 'Meta is unavailable or the request timed out. Try again.');
    }
  }

  _channels(business) {
    const settings = business.metaPartnerSettings || {};
    if (settings.channels?.length) return settings.channels;
    const wa = business.whatsappSettings || {};
    if (!wa.phoneNumberId || !wa.wabaId) return [];
    return [{ channelId: 'primary_default_channel', name: settings.verifiedName || business.name || 'WhatsApp',
      phoneNumber: wa.phoneNumber || '', phoneNumberId: wa.phoneNumberId, wabaId: wa.wabaId,
      isActive: !!wa.enabled, status: 'SETUP_REQUIRED', pinRegistered: false, webhookSubscribed: false,
      integrationStatus: 'Verify registration and webhooks' }];
  }

  async _channel(businessId, channelId) {
    const business = await this._business(businessId);
    const channel = this._channels(business).find(item => item.channelId === channelId);
    if (!channel) throw new ApiError(404, 'WhatsApp channel not found in this business.');
    const wa = business.whatsappSettings || {};
    if (!channel.phoneNumberId || !channel.wabaId || !wa.accessToken) throw new ApiError(409, 'Complete Meta connection for this number first.');
    if (wa.phoneNumberId !== channel.phoneNumberId) throw new ApiError(409, 'Reconnect this line before making it the primary sender.');
    return { business, channel, wa };
  }

  async getPartnerStatus(businessId) {
    const business = await this._business(businessId);
    const wa = business.whatsappSettings || {};
    const settings = business.metaPartnerSettings || {};
    const primary = this._channels(business).find(c => c.phoneNumberId === wa.phoneNumberId);
    const configured = !!(wa.accessToken && wa.phoneNumberId && wa.wabaId);
    const ready = !!(configured && primary?.pinRegistered && primary?.webhookSubscribed && primary?.isActive && wa.enabled);
    const result = {
      isPartnerManaged: !!settings.isPartnerManaged, partnerAdminEmail: '',
      partnerStatus: ready ? 'ACTIVE' : configured ? 'SETUP_REQUIRED' : 'NOT_CONFIGURED',
      onboardingType: settings.onboardingType || 'embedded_signup', coManagementStatus: settings.coManagementStatus || 'none',
      businessPortfolioId: settings.businessPortfolioId || '', wabaId: wa.wabaId || '',
      phoneNumberId: wa.phoneNumberId || '', phoneNumber: wa.phoneNumber || '',
      qualityRating: 'UNKNOWN', messagingTier: 'UNKNOWN', displayNameStatus: 'UNKNOWN',
      verifiedName: settings.verifiedName || '', aboutBio: settings.aboutBio || '', address: settings.address || '',
      email: settings.email || '', website: settings.website || '', connectedAt: settings.connectedAt || null,
      metaPartnerVerified: false, canSend: false, pinRegistered: !!primary?.pinRegistered,
      webhookSubscribed: !!primary?.webhookSubscribed,
      signupAvailable: !!(process.env.META_APP_ID && process.env.META_APP_SECRET && process.env.META_EMBEDDED_SIGNUP_CONFIG_ID && process.env.META_PUBLIC_BASE_URL),
    };
    if (configured) {
      try {
        const phone = await this._graph(`${wa.phoneNumberId}?fields=id,display_phone_number,verified_name,quality_rating,code_verification_status`, wa.accessToken);
        result.phoneNumber = phone.display_phone_number || result.phoneNumber;
        result.verifiedName = phone.verified_name || result.verifiedName;
        result.qualityRating = phone.quality_rating || 'UNKNOWN';
        result.metaPartnerVerified = true;
        result.canSend = ready;
      } catch (error) {
        result.partnerStatus = error.metaCode === 190 ? 'RECONNECT_REQUIRED' : 'CHECK_FAILED';
        result.healthMessage = error.message;
      }
    }
    return result;
  }

  async connectPartnerWaba(businessId, { wabaId = '', phoneNumberId = '', accessToken = '', businessPortfolioId = '', onboardingType = 'direct' }) {
    await this._business(businessId);
    const id = String(phoneNumberId).trim(), waba = String(wabaId).trim(), token = String(accessToken).trim();
    if (!/^\d+$/.test(id) || !/^\d+$/.test(waba) || !token) throw new ApiError(400, 'WABA ID, Phone Number ID and access token are required.');
    const other = await Business.findOne({ _id: { $ne: businessId }, $or: [
      { 'whatsappSettings.phoneNumberId': id }, { 'metaPartnerSettings.channels.phoneNumberId': id },
    ] }).lean();
    if (other) throw new ApiError(409, 'This WhatsApp number is linked to another business.');
    const numbers = await this._graph(`${waba}/phone_numbers?fields=id,display_phone_number,verified_name&limit=100`, token);
    const phone = (numbers.data || []).find(p => String(p.id) === id);
    if (!phone) throw new ApiError(400, 'The selected phone does not belong to this WhatsApp Business Account.');
    const business = await this._business(businessId);
    const channels = this._channels(business).map(c => ({ ...c, isActive: false }));
    const previous = channels.find(c => c.phoneNumberId === id);
    const channel = { channelId: previous?.channelId || new mongoose.Types.ObjectId().toString(),
      name: phone.verified_name || 'WhatsApp Business', phoneNumber: phone.display_phone_number || '',
      phoneNumberId: id, wabaId: waba, isActive: false, status: 'SETUP_REQUIRED',
      integrationStatus: 'Complete registration and webhook subscription', pinRegistered: false, webhookSubscribed: false, createdAt: new Date() };
    const next = channels.filter(c => c.phoneNumberId !== id).concat(channel);
    await Business.findByIdAndUpdate(businessId, { $set: {
      'whatsappSettings.phoneNumberId': id, 'whatsappSettings.wabaId': waba, 'whatsappSettings.phoneNumber': channel.phoneNumber,
      'whatsappSettings.accessToken': token, 'whatsappSettings.enabled': false, 'whatsappSettings.connectedAt': new Date(),
      'metaPartnerSettings.isPartnerManaged': true, 'metaPartnerSettings.onboardingType': onboardingType,
      'metaPartnerSettings.businessPortfolioId': String(businessPortfolioId).trim(),
      'metaPartnerSettings.verifiedName': channel.name, 'metaPartnerSettings.connectedAt': new Date(),
      'metaPartnerSettings.channels': next,
    } });
    return { success: true, channel, partnerStatus: 'SETUP_REQUIRED' };
  }
  async updatePartnerProfile(businessId, { aboutBio, address, email, website }) {
    const business = await this._business(businessId), wa = business.whatsappSettings || {};
    if (!wa.phoneNumberId) throw new ApiError(409, 'Connect WhatsApp first.');
    const body = { messaging_product: 'whatsapp' }, fields = {};
    for (const [key, value] of Object.entries({ aboutBio, address, email, website })) {
      if (value === undefined) continue;
      const clean = String(value).trim();
      fields[`metaPartnerSettings.${key}`] = clean;
      body[key === 'aboutBio' ? 'about' : key === 'website' ? 'websites' : key] = key === 'website' ? (clean ? [clean] : []) : clean;
    }
    if (!Object.keys(fields).length) throw new ApiError(400, 'No profile changes provided.');
    const result = await this._graph(`${wa.phoneNumberId}/whatsapp_business_profile`, wa.accessToken, { method: 'POST', body });
    if (result.success !== true) throw new ApiError(502, 'Meta did not confirm the profile update.');
    await Business.findByIdAndUpdate(businessId, { $set: fields });
    return { success: true };
  }

  async inviteCoManagement() {
    throw new ApiError(501, 'Agency co-management is not available. Connect with Meta Embedded Signup instead.');
  }

  async disconnectPartner(businessId) {
    const business = await this._business(businessId);
    await Business.findByIdAndUpdate(businessId, { $set: {
      'whatsappSettings.enabled': false, 'whatsappSettings.accessToken': '', 'whatsappSettings.appSecret': '',
      'whatsappSettings.phoneNumberId': '', 'whatsappSettings.wabaId': '', 'whatsappSettings.phoneNumber': '',
      'metaPartnerSettings.isPartnerManaged': false, 'metaPartnerSettings.connectedAt': null,
      'metaPartnerSettings.channels': this._channels(business).map(c => ({ ...c, isActive: false, status: 'DISCONNECTED', pinRegistered: false, webhookSubscribed: false })),
    } });
    return { success: true };
  }

  async getChannels(businessId) {
    const channels = this._channels(await this._business(businessId));
    return { success: true, channels, totalCount: channels.length };
  }

  async createChannel(businessId, { name, phoneNumber }) {
    await this._business(businessId);
    if (!String(name || '').trim() || !/^\+?[1-9]\d{7,14}$/.test(String(phoneNumber || '').replace(/\s/g, ''))) {
      throw new ApiError(400, 'Enter a channel name and an international phone number.');
    }
    const channel = { channelId: new mongoose.Types.ObjectId().toString(), name: String(name).trim(), phoneNumber: String(phoneNumber).trim(),
      phoneNumberId: '', wabaId: '', isActive: false, status: 'PENDING', integrationStatus: 'Not connected to Meta', pinRegistered: false, webhookSubscribed: false, createdAt: new Date() };
    await Business.findByIdAndUpdate(businessId, { $push: { 'metaPartnerSettings.channels': channel } });
    return { success: true, channel };
  }

  async _saveStep(businessId, business, channel, patch) {
    if (!business.metaPartnerSettings?.channels?.length) {
      await Business.updateOne({ _id: businessId, 'metaPartnerSettings.channels.0': { $exists: false } },
        { $set: { 'metaPartnerSettings.channels': this._channels(business) } });
    }
    const fields = Object.fromEntries(Object.entries(patch).map(([key, value]) => [`metaPartnerSettings.channels.$.${key}`, value]));
    const saved = await Business.updateOne({ _id: businessId, 'whatsappSettings.phoneNumberId': channel.phoneNumberId,
      'metaPartnerSettings.channels.channelId': channel.channelId }, { $set: fields });
    if (saved?.matchedCount === 0) throw new ApiError(409, 'This connection changed. Refresh and try again.');
    // Separate atomic field updates avoid losing a concurrent registration/subscription.
    const enabled = await Business.updateOne({ _id: businessId, 'whatsappSettings.phoneNumberId': channel.phoneNumberId,
      'metaPartnerSettings.channels': { $elemMatch: { channelId: channel.channelId, pinRegistered: true, webhookSubscribed: true } } },
    { $set: { 'metaPartnerSettings.channels.$.isActive': true, 'metaPartnerSettings.channels.$.status': 'ACTIVE',
      'metaPartnerSettings.channels.$.integrationStatus': 'Connected to WhatsApp Cloud API', 'whatsappSettings.enabled': true } });
    return { success: true, channelId: channel.channelId, ready: enabled?.matchedCount === 1 };
  }

  async registerChannelPin(businessId, { channelId, pin }) {
    if (!/^\d{6}$/.test(String(pin || ''))) throw new ApiError(400, 'Enter your six-digit two-step verification PIN.');
    const { business, channel, wa } = await this._channel(businessId, channelId);
    const result = await this._graph(`${channel.phoneNumberId}/register`, wa.accessToken,
      { method: 'POST', body: { messaging_product: 'whatsapp', pin: String(pin) } });
    if (result.success !== true) throw new ApiError(502, 'Meta did not confirm phone registration.');
    return this._saveStep(businessId, business, channel, { pinRegistered: true });
  }

  async subscribeChannelWebhook(businessId, { channelId }) {
    const { business, channel, wa } = await this._channel(businessId, channelId);
    const result = await this._graph(`${channel.wabaId}/subscribed_apps`, wa.accessToken, { method: 'POST' });
    if (result.success !== true) throw new ApiError(502, 'Meta did not confirm webhook subscription.');
    return this._saveStep(businessId, business, channel, { webhookSubscribed: true });
  }

  async toggleChannelActive(businessId, { channelId, isActive }) {
    if (typeof isActive !== 'boolean') throw new ApiError(400, 'isActive must be a boolean.');
    const { business, channel } = await this._channel(businessId, channelId);
    if (isActive && (!channel.pinRegistered || !channel.webhookSubscribed)) throw new ApiError(409, 'Finish registration and webhook setup before enabling this number.');
    const channels = this._channels(business).map(c => ({ ...c, isActive: c.channelId === channelId && isActive }));
    await Business.findByIdAndUpdate(businessId, { $set: { 'metaPartnerSettings.channels': channels, 'whatsappSettings.enabled': isActive } });
    return { success: true, isActive };
  }

  async deleteChannel(businessId, { channelId }) {
    const business = await this._business(businessId);
    const channel = this._channels(business).find(c => c.channelId === channelId);
    if (!channel) throw new ApiError(404, 'WhatsApp channel not found.');
    if (channel.phoneNumberId && channel.phoneNumberId === business.whatsappSettings?.phoneNumberId) throw new ApiError(409, 'Disconnect the primary number before removing it.');
    await Business.updateOne({ _id: businessId }, { $pull: { 'metaPartnerSettings.channels': { channelId } } });
    return { success: true };
  }

  async getTemplates(businessId) {
    const business = await this._business(businessId), wa = business.whatsappSettings || {};
    const live = wa.wabaId && wa.accessToken ? await this._graph(`${wa.wabaId}/message_templates?fields=name,status,category,language,components&limit=100`, wa.accessToken) : { data: [] };
    const templates = (live.data || []).map(t => ({ ...t, displayName: t.name.replace(/_/g, ' '), description: '', isLiveSynced: true }));
    for (const item of catalog) if (!templates.some(t => t.name === item.name && t.language === 'en_US')) templates.push({ ...item, language: 'en_US', status: 'NOT_SUBMITTED', isLiveSynced: false });
    return { success: true, templates, totalCount: templates.length, hasMore: !!live.paging?.next };
  }

  async syncDefaultTemplates(businessId) {
    const business = await this._business(businessId), wa = business.whatsappSettings || {};
    if (!wa.wabaId) throw new ApiError(409, 'Connect WhatsApp first.');
    const current = await this.getTemplates(businessId);
    const results = [];
    for (const item of catalog) {
      if (current.templates.some(t => t.name === item.name && t.language === 'en_US' && t.isLiveSynced)) continue;
      const result = await this._graph(`${wa.wabaId}/message_templates`, wa.accessToken, { method: 'POST', body: {
        name: item.name, language: 'en_US', category: item.category, components: [{ type: 'BODY', text: item.description }],
      } });
      if (!result.id) throw new ApiError(502, 'Meta did not confirm template submission. Refresh before retrying.');
      results.push({ name: item.name, status: result.status || 'PENDING', id: result.id });
    }
    return { success: true, submittedCount: results.length, results, message: 'Submitted for Meta review. Approval is required before use.' };
  }

  async sendTestMessage(businessId, { recipientPhone, message, templateName, language = 'en_US' }) {
    const business = await this._business(businessId), wa = business.whatsappSettings || {};
    if (!wa.enabled || !wa.accessToken || !wa.phoneNumberId) throw new ApiError(409, 'Complete WhatsApp connection and registration first.');
    const to = String(recipientPhone || '').replace(/[\s+()-]/g, '');
    if (!/^[1-9]\d{7,14}$/.test(to)) throw new ApiError(400, 'Use an international recipient number, including country code.');
    let payload;
    if (templateName) {
      const templates = await this.getTemplates(businessId);
      const template = templates.templates.find(t => t.name === templateName && t.language === language && t.status === 'APPROVED' && t.isLiveSynced);
      if (!template) throw new ApiError(409, 'Choose an approved template in this account.');
      if ((template.components || []).some(c => /\{\{/.test(JSON.stringify(c)) || (c.type === 'HEADER' && c.format !== 'TEXT'))) throw new ApiError(400, 'This test supports templates without variables or media.');
      payload = { type: 'template', template: { name: templateName, language: { code: language } } };
    } else {
      const chat = await Chat.findOne({ businessId, customerPhone: { $in: [to, `+${to}`] }, lastIncomingAt: { $gte: new Date(Date.now() - 86400000) } }).lean();
      if (!chat) throw new ApiError(409, 'Ask this customer to message you first, or choose an approved template.');
      payload = { type: 'text', text: { body: String(message || 'Apna POS connection test.').slice(0, 4096) } };
    }
    const result = await this._graph(`${wa.phoneNumberId}/messages`, wa.accessToken,
      { method: 'POST', body: { messaging_product: 'whatsapp', to, ...payload } });
    if (!result.messages?.[0]?.id) throw new ApiError(502, 'Meta did not return a message ID.');
    return { success: true, messageId: result.messages[0].id, recipient: `+${to}`, status: 'ACCEPTED', message: 'Accepted by Meta. Delivery is confirmed by webhook.' };
  }

  async getMessagingAnalytics(businessId) {
    await this._business(businessId);
    const id = new mongoose.Types.ObjectId(businessId);
    const start = new Date(Math.floor((Date.now() + 19800000) / 86400000) * 86400000 - 19800000);
    const [counts, activeConversations] = await Promise.all([
      Message.aggregate([{ $match: { businessId: id, direction: 'OUTGOING', timestamp: { $gte: start } } }, { $group: { _id: '$status', count: { $sum: 1 } } }]),
      Chat.countDocuments({ businessId, lastIncomingAt: { $gte: new Date(Date.now() - 86400000) } }),
    ]);
    const statuses = Object.fromEntries(counts.map(c => [c._id, c.count]));
    const sent = (statuses.SENT || 0) + (statuses.DELIVERED || 0) + (statuses.READ || 0);
    const rate = count => sent ? `${(count * 100 / sent).toFixed(1)}%` : '—';
    return { success: true, sentToday: sent, deliveredRate: rate((statuses.DELIVERED || 0) + (statuses.READ || 0)),
      readRate: rate(statuses.READ || 0), failedCount: statuses.FAILED || 0, activeConversations,
      dailyLimit: null, qualityRating: 'UNKNOWN', messagingTier: 'UNKNOWN', customerServiceWindowStatus: 'PER_CUSTOMER',
      source: 'Stored chat messages; excludes sends outside this message store', timezone: 'Asia/Kolkata', lastHealthCheck: new Date() };
  }
  async startEmbeddedSignup(businessId, { userId }) {
    await this._business(businessId);
    const { META_APP_ID, META_APP_SECRET, META_EMBEDDED_SIGNUP_CONFIG_ID, META_PUBLIC_BASE_URL } = process.env;
    if (!META_APP_ID || !META_APP_SECRET || !META_EMBEDDED_SIGNUP_CONFIG_ID || !META_PUBLIC_BASE_URL) throw new ApiError(503, 'Meta signup is not configured on the server. Ask your administrator to configure the app and signup configuration.');
    const base = new URL(META_PUBLIC_BASE_URL);
    if (base.protocol !== 'https:' && process.env.NODE_ENV !== 'test') throw new ApiError(503, 'Meta signup requires a public HTTPS backend URL.');
    const sessionToken = crypto.randomBytes(32).toString('hex');
    await Signup.create({ tokenHash: crypto.createHash('sha256').update(sessionToken).digest('hex'), businessId, userId,
      expiresAt: new Date(Date.now() + 10 * 60000), status: 'PENDING' });
    return { url: `${base.origin}/api/v1/meta-partner/onboarding#session=${sessionToken}`, expiresIn: 600 };
  }

  async completeEmbeddedSignup({ sessionToken, code, wabaId, phoneNumberId }) {
    if (!/^[a-f0-9]{64}$/.test(sessionToken || '')) throw new ApiError(400, 'Invalid signup session.');
    if (!code || !/^\d+$/.test(String(wabaId)) || !/^\d+$/.test(String(phoneNumberId))) throw new ApiError(400, 'Meta signup must return a code, WABA and phone number.');
    const session = await Signup.findOneAndUpdate({ tokenHash: crypto.createHash('sha256').update(sessionToken).digest('hex'),
      expiresAt: { $gt: new Date() }, status: 'PENDING' }, { $set: { status: 'PROCESSING' } }, { new: true });
    if (!session) throw new ApiError(409, 'This signup session has expired or was already used. Start again in Apna POS.');
    try {
      const result = await this.exchangeEmbeddedSignupOAuth(session.businessId, { code, wabaId, phoneNumberId });
      await Signup.updateOne({ _id: session._id }, { $set: { status: 'COMPLETED' } });
      return result;
    } catch (error) {
      await Signup.updateOne({ _id: session._id }, { $set: { status: 'FAILED' } });
      throw error;
    }
  }

  async exchangeEmbeddedSignupOAuth(businessId, { code, wabaId, phoneNumberId }) {
    if (!code || !wabaId || !phoneNumberId) throw new ApiError(400, 'Meta code and selected account IDs are required.');
    const appId = process.env.META_APP_ID, secret = process.env.META_APP_SECRET;
    if (!appId || !secret) throw new ApiError(503, 'Meta app credentials are not configured on the server.');
    const params = new URLSearchParams({ client_id: appId, client_secret: secret, code });
    let data;
    try {
      const response = await fetch(`https://graph.facebook.com/${graphVersion()}/oauth/access_token`, {
        method: 'POST', signal: AbortSignal.timeout(10000), headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: params.toString(),
      });
      data = await response.json();
      if (!response.ok || !data.access_token) throw new Error('exchange rejected');
    } catch (_) { throw new ApiError(502, 'Meta could not exchange this signup code. Restart signup and try again.'); }
    return this.connectPartnerWaba(businessId, { wabaId, phoneNumberId, accessToken: data.access_token, onboardingType: 'embedded_signup' });
  }
}
module.exports = new MetaPartnerService();
