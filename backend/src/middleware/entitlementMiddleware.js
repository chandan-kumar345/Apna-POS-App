const access = require('../services/entitlementService');
const ApiError = require('../utils/ApiError');

const subscription = async (req, res, next) => {
  try { await access.requireSubscription(req.businessId); next(); } catch (error) { next(error); }
};
const chotu = async (req, res, next) => {
  try { await access.requireChotu(req.businessId); next(); } catch (error) { next(error); }
};
const rejectControlUpdates = (req, res, next) => {
  const forbidden = new Set(['isSubscription', 'subscriptionExpiresAt', 'isChotuAiActive', 'subscriptionRenewalOrderIds', 'subscription', 'isSubscriptionActive', 'isSubscribed']);
  function contains(value) {
    return value && typeof value === 'object' && Object.entries(value).some(([key, child]) =>
      key.split('.').some((part) => forbidden.has(part)) || contains(child));
  }
  if (contains(req.body)) return next(ApiError.forbidden('Subscription and AI controls can only be changed by a platform administrator.', 'ENTITLEMENT_UPDATE_FORBIDDEN'));
  next();
};
module.exports = { subscription, chotu, rejectControlUpdates };
