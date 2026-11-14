const mongoose = require('mongoose');
const Business = require('../models/Business');
const Subscription = require('../models/Subscription');
const ApiError = require('../utils/ApiError');

// Access decisions deliberately read BSON values, bypassing schema defaults and
// casts (a manually stored string "true" or ISO string is not an entitlement).
function evaluate(business, now = new Date()) {
  const expiry = business?.subscriptionExpiresAt;
  const validDate = expiry instanceof Date && Number.isFinite(expiry.getTime());
  const active = business?.isSubscription === true && validDate && expiry.getTime() > now.getTime();
  return {
    isSubscription: business?.isSubscription === true,
    subscriptionExpiresAt: validDate ? expiry : null,
    isChotuAiActive: business?.isChotuAiActive === true,
    isSubscriptionActive: active, isActive: active, isSubscribed: active,
    chotuAiAccess: active && business?.isChotuAiActive === true,
    status: active ? 'active' : validDate && expiry <= now ? 'expired' : 'inactive',
    expiresAt: validDate ? expiry : null,
    hasLoyalty: active, hasCampaign: active, hasInventory: active,
  };
}

async function read(businessId) {
  if (!businessId || !mongoose.isValidObjectId(businessId)) throw ApiError.notFound('Business not found');
  const business = await Business.collection.findOne({ _id: new mongoose.Types.ObjectId(String(businessId)) });
  if (!business) throw ApiError.notFound('Business not found');
  return { business, ...evaluate(business) };
}

async function requireSubscription(businessId) {
  const access = await read(businessId);
  if (!access.isActive) throw ApiError.forbidden('An enabled subscription with a future expiry is required.', 'SUBSCRIPTION_REQUIRED');
  return access;
}

async function requireChotu(businessId) {
  const access = await requireSubscription(businessId);
  if (!access.isChotuAiActive) throw ApiError.forbidden('Chotu AI is disabled for this business.', 'CHOTU_AI_DISABLED');
  return access;
}

async function status(businessId, userId = null) {
  const access = await read(businessId);
  const metadata = await Subscription.findOne({ businessId, targetType: 'business' }).sort({ createdAt: -1 }).lean();
  const embedded = access.business.subscription || {};
  const amount = Number(metadata?.amount || embedded.amount) > 0 ? Number(metadata?.amount || embedded.amount) : 300;
  const upiId = metadata?.upiId || embedded.upiId || '9709593705@ybl';
  const { business, ...calculated } = access;
  return {
    ...calculated, plan: metadata?.plan || embedded.plan || 'starter', amount, upiId,
    upiPayUrl: `upi://pay?pa=${encodeURIComponent(upiId)}&pn=Apna%20POS&am=${amount}&cu=INR&tn=Apna%20POS%20Subscription%20Unlock`,
    activatedAt: metadata?.activatedAt || embedded.activatedAt || null,
    paymentRef: metadata?.paymentRef || embedded.paymentRef || '',
    features: calculated.isActive ? metadata?.features || ['pos', 'tables', 'orders', 'reports', 'inventory', 'loyalty', 'campaign', 'staff', 'crm'] : ['pos', 'tables', 'orders', 'reports'],
    targetType: 'business', businessId: business._id, userId, staffId: null,
    subscriptionId: metadata?._id || null,
  };
}

// Trusted administrative mutation only. No automatic expiry or flag grants.
async function updateControls(businessId, changes) {
  const set = {};
  for (const key of ['isSubscription', 'isChotuAiActive']) {
    if (changes[key] !== undefined) {
      if (typeof changes[key] !== 'boolean') throw ApiError.badRequest(`${key} must be a boolean`);
      set[key] = changes[key];
    }
  }
  if (changes.subscriptionExpiresAt !== undefined) {
    const value = changes.subscriptionExpiresAt;
    const date = value === null ? null : value instanceof Date ? value
      : typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T.*(?:Z|[+-]\d{2}:\d{2})$/.test(value) ? new Date(value) : new Date(NaN);
    if (date !== null && !Number.isFinite(date.getTime())) throw ApiError.badRequest('Expiry must be an ISO date with timezone or null');
    set.subscriptionExpiresAt = date;
  }
  if (!Object.keys(set).length) throw ApiError.badRequest('No entitlement controls supplied');
  const updated = await Business.findOneAndUpdate({ _id: businessId }, { $set: set }, { new: true, runValidators: true });
  if (!updated) throw ApiError.notFound('Business not found');
  return status(businessId);
}

module.exports = { evaluate, read, status, requireSubscription, requireChotu, updateControls };
