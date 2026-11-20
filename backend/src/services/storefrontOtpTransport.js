const env = require('../config/env');
const ApiError = require('../utils/ApiError');
const crypto = require('crypto');

const PHONE_ID = '1284061438133660';
const WABA_ID = '2525727467906581';
let readyKey = '', readyUntil = 0;

async function checkSender(accessToken, version, template, language) {
  const key = crypto.createHash('sha256').update(`${accessToken}|${version}|${template}|${language}`).digest('hex');
  if (readyKey === key && Date.now() < readyUntil) return;
  const read = async path => {
    const response = await fetch(`https://graph.facebook.com/${version}/${path}`, {
      headers: { Authorization: `Bearer ${accessToken}` }, signal: AbortSignal.timeout(10000),
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new ApiError(503, 'WhatsApp sender is unavailable. Please continue as a guest.', 'OTP_UNAVAILABLE');
    return data.data || [];
  };
  const numbers = await read(`${WABA_ID}/phone_numbers?fields=id&limit=100`);
  if (!numbers.some(row => row.id === PHONE_ID)) throw new ApiError(503, 'WhatsApp verification sender configuration is invalid.', 'OTP_UNAVAILABLE');
  const templates = await read(`${WABA_ID}/message_templates?name=${encodeURIComponent(template)}&fields=name,status,category,language&limit=100`);
  if (!templates.some(row => row.name === template && row.status === 'APPROVED' && row.category === 'AUTHENTICATION' && row.language === language)) {
    throw new ApiError(503, 'WhatsApp authentication template is not ready. Please continue as a guest.', 'OTP_TEMPLATE_UNAVAILABLE');
  }
  readyKey = key; readyUntil = Date.now() + 15 * 60000;
}

async function send(phone, code) {
  // No simulation, raw-text fallback, client OTP, or secret/OTP logging.
  const accessToken = process.env.STOREFRONT_OTP_ACCESS_TOKEN || process.env.WHATSAPP_ACCESS_TOKEN || env.WHATSAPP_ACCESS_TOKEN;
  if (!accessToken || ['mock_token', 'test_token'].includes(accessToken)) {
    throw new ApiError(503, 'WhatsApp verification is not configured. Please continue as a guest.', 'OTP_UNAVAILABLE');
  }
  const version = env.WHATSAPP_API_VERSION;
  const template = process.env.STOREFRONT_OTP_TEMPLATE || 'apna_pos_auth_otp';
  const language = process.env.STOREFRONT_OTP_LANGUAGE || 'en';
  await checkSender(accessToken, version, template, language);
  const response = await fetch(`https://graph.facebook.com/${version}/${PHONE_ID}/messages`, {
    method: 'POST', signal: AbortSignal.timeout(15000),
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ messaging_product: 'whatsapp', recipient_type: 'individual', to: `91${phone}`, type: 'template',
      template: { name: template, language: { code: language }, components: [
        { type: 'body', parameters: [{ type: 'text', text: code }] },
        { type: 'button', sub_type: 'url', index: '0', parameters: [{ type: 'text', text: code }] },
      ] },
    }),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok || !data.messages?.[0]?.id) {
    throw new ApiError(503, 'WhatsApp could not send the code. Please try later or continue as a guest.', 'OTP_DELIVERY_FAILED');
  }
  return { messageId: data.messages[0].id };
}
module.exports = { send, PHONE_ID, WABA_ID };
