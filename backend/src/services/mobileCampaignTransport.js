const Business = require('../models/Business');
const whatsapp = require('./whatsappService');
const storage = require('../utils/storageService');
const ApiError = require('../utils/ApiError');

function validateImage(businessId, link) {
  const url = URL.canParse(link) ? new URL(link) : null;
  const r2 = storage.publicDomain || (storage.accountId ? 'https://' + storage.bucketName + '.' + storage.accountId + '.r2.cloudflarestorage.com' : '');
  const origins = [r2, process.env.META_PUBLIC_BASE_URL, process.env.RENDER_EXTERNAL_URL].filter(Boolean);
  for (const base of origins) {
    if (!url || !URL.canParse(base) || url.protocol !== 'https:' || url.username || url.password || url.search || url.hash) continue;
    const root = new URL(base);
    const prefix = base === r2 ? root.pathname.replace(/\/$/, '') : '/uploads';
    if (url.origin === root.origin && url.pathname.startsWith(prefix + '/campaigns/' + businessId + '/') &&
        /^\d+_[a-f\d]{8}\.(jpe?g|png)$/i.test(url.pathname.split('/').pop())) {
      return;
    }
  }
  throw ApiError.badRequest('Upload a JPEG or PNG campaign image using the connected media storage.');
}

async function account(c) {
  const channels = await require('./campaignService').getChannels(c.businessId);
  const selected = channels.find(v => v.id === c.channel.channelType && v.isConnected);
  if (!selected?.wabaId || !selected.phoneNumberId || selected.phoneNumberId !== c.channel.phoneNumberId) {
    throw new Error('Reconnect the WhatsApp channel selected for this campaign.');
  }
  const shared = selected.id === 'softcode_shared';
  const business = shared ? null : await Business.findById(c.businessId).select('whatsappSettings').lean();
  const own = business?.whatsappSettings || {};
  const platformSender = selected.phoneNumberId === whatsapp.phoneNumberId && (shared || String(c.businessId) === '6ad46853ea47d6b3e13d633d');
  const token = own.accessToken || (platformSender ? whatsapp.accessToken : '');
  if (!token) throw new Error('Connect a WhatsApp access token for the selected sender.');
  return { waba: selected.wabaId, phone: selected.phoneNumberId, token, secret: own.appSecret || (platformSender ? whatsapp.appSecret : '') };
}

async function graph(credentials, path, payload, queryParams) {
  const url = whatsapp.buildGraphUrl(path, { accessToken: credentials.token, appSecret: credentials.secret, queryParams });
  const response = await fetch(url, { method: payload ? 'POST' : 'GET', signal: AbortSignal.timeout(20000),
    headers: { Authorization: 'Bearer ' + credentials.token, 'Content-Type': 'application/json' },
    ...(payload && { body: JSON.stringify(payload) }) });
  const data = await response.json();
  if (!response.ok) {
    const err = new Error(whatsapp.formatMetaErrorMessage(data, 'WhatsApp request failed'));
    err.transient = response.status === 429 || response.status >= 500;
    throw err;
  }
  return data;
}

async function approval(c, credentials, allowSubmission = true) {
  const name = c.template.metaTemplateName;
  const category = c.template.category;
  const response = await graph(credentials, credentials.waba + '/message_templates', null,
    { name, fields: 'name,language,status,category', limit: 100 });
  const template = response.data?.find(t => t.name === name && t.language === 'en');
  if (template) return template.category === category ? template.status : 'REJECTED';
  if (!allowSubmission) return 'MISSING';
  // An accepted submission can take a moment to appear in Meta's list.
  if (c.template.metaStatus === 'PENDING') return 'PENDING';
  const components = [];
  if (c.template.headerMediaUrl) {
    validateImage(c.businessId, c.template.headerMediaUrl);
    const handle = await require('./campaignService')._getMetaHeaderHandle({
      accessToken: credentials.token, appSecret: credentials.secret, imageUrl: c.template.headerMediaUrl, uploadedCampaignImage: true,
    });
    if (!handle) throw new Error('Meta could not import the campaign image. Check the image and try again.');
    components.push({ type: 'HEADER', format: 'IMAGE', example: { header_handle: [handle] } });
  }
  const body = { type: 'BODY', text: c.template.body.replace(/\{\{name\}\}/g, '{{1}}') };
  if (body.text.includes('{{1}}')) body.example = { body_text: [['Rahul']] };
  components.push(body);
  const actions = c.template.actions || [];
  if (actions.length) components.push({ type: 'BUTTONS', buttons: actions.map(a => ({
    type: a.type, text: a.text, ...(a.type === 'URL' && { url: a.value }),
    ...(a.type === 'PHONE_NUMBER' && { phone_number: a.value }),
  })) });
  const submitted = category === 'AUTHENTICATION' ? [
    { type: 'BODY', add_security_recommendation: false },
    { type: 'BUTTONS', buttons: [{ type: 'OTP', otp_type: 'COPY_CODE', text: 'Copy code' }] },
  ] : components;
  const created = await graph(credentials, credentials.waba + '/message_templates', { name, category, language: 'en', components: submitted });
  if (!created.id) throw new Error('Meta did not accept the template submission.');
  return created.category && created.category !== category ? 'REJECTED' : (created.status || 'PENDING');
}

async function send(c, credentials, recipient) {
  if (c.template.category === 'AUTHENTICATION') throw new Error('Authentication templates require a customer-requested verification code.');
  const components = [];
  if (c.template.headerMediaUrl) components.push({ type: 'header', parameters: [{ type: 'image', image: { link: c.template.headerMediaUrl } }] });
  if (c.template.body.includes('{{name}}')) components.push({ type: 'body', parameters: [{ type: 'text', text: recipient.name || 'Customer' }] });
  for (const [index, action] of (c.template.actions || []).entries()) {
    if (action.type === 'QUICK_REPLY') components.push({ type: 'button', sub_type: 'quick_reply', index: String(index),
      parameters: [{ type: 'payload', payload: action.text }] });
  }
  const result = await graph(credentials, credentials.phone + '/messages', {
    messaging_product: 'whatsapp', to: recipient.phone, type: 'template',
    template: { name: c.template.metaTemplateName, language: { code: 'en' }, components },
  });
  const messageId = result.messages?.[0]?.id;
  if (!messageId) throw new Error('WhatsApp did not return a message ID.');
  return messageId;
}

module.exports = { validateImage, account, approval, send };
