const env = require('./env');

module.exports = {
  get phoneNumberId() { return process.env.WHATSAPP_PHONE_NUMBER_ID || env.WHATSAPP_PHONE_NUMBER_ID || '1284061438133660'; },
  get accessToken() { return process.env.WHATSAPP_ACCESS_TOKEN || env.WHATSAPP_ACCESS_TOKEN || ''; },
  get apiVersion() { return process.env.WHATSAPP_API_VERSION || env.WHATSAPP_API_VERSION || 'v21.0'; },
  get webhookVerifyToken() { return process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN || env.WHATSAPP_WEBHOOK_VERIFY_TOKEN || 'softcode_whatsapp_webhook_verify_2026'; },
  get appSecret() { return process.env.WHATSAPP_APP_SECRET || env.WHATSAPP_APP_SECRET || ''; },
  get templateName() { return process.env.WHATSAPP_EBILL_TEMPLATE || env.WHATSAPP_EBILL_TEMPLATE || 'ebill_receipt'; },
  get defaultEbillCharge() { return env.EBILL_CHARGE_INR; },
};
