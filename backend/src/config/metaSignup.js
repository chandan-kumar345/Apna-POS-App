// These public identifiers are shared by the browser SDK and the code exchange.
module.exports = {
  get appId() { return process.env.META_APP_ID || '3643190475832679'; },
  get configId() { return process.env.META_EMBEDDED_SIGNUP_CONFIG_ID || '1659729462561672'; },
  get publicBaseUrl() { return process.env.META_PUBLIC_BASE_URL || process.env.RENDER_EXTERNAL_URL; },
};
