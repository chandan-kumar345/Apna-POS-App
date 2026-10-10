const env = require('./env');

module.exports = {
  phoneNumberId: env.WHATSAPP_PHONE_NUMBER_ID,
  accessToken: env.WHATSAPP_ACCESS_TOKEN,
  apiVersion: env.WHATSAPP_API_VERSION,
  webhookVerifyToken: env.WHATSAPP_WEBHOOK_VERIFY_TOKEN,
  appSecret: env.WHATSAPP_APP_SECRET,
  templateName: env.WHATSAPP_EBILL_TEMPLATE,
  defaultEbillCharge: env.EBILL_CHARGE_INR,
};
