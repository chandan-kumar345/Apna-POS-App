const mongoose = require('mongoose');
const Intent = require('../models/SubscriptionPaymentIntent');
const Business = require('../models/Business');
const gateway = require('./razorpayService');
const access = require('./entitlementService');
const ApiError = require('../utils/ApiError');

async function create(businessId) {
  await access.read(businessId);
  const client = gateway.getRazorpayClient();
  if (!client) throw new ApiError(503, 'Subscription payment gateway is not configured', 'PAYMENT_GATEWAY_UNAVAILABLE');
  // Existing legacy subscription unlock price: INR 300 for 30 days. Neither
  // price, period nor business identity is accepted from the checkout client.
  const order = await client.orders.create({ amount: 30000, currency: 'INR',
    notes: { purpose: 'apna_pos_subscription', businessId: String(businessId) } });
  await Intent.create({ businessId, providerOrderId: order.id, amount: 30000, currency: 'INR', days: 30 });
  return { orderId: order.id, amount: 30000, currency: 'INR', days: 30 };
}

async function verify(businessId, data) {
  if (typeof data.razorpay_payment_id !== 'string' || typeof data.razorpay_order_id !== 'string') {
    throw ApiError.badRequest('Verified gateway payment and order IDs are required; a UTR alone cannot activate access.', null, 'PAYMENT_VERIFICATION_REQUIRED');
  }
  const intent = await Intent.findOne({ businessId, providerOrderId: data.razorpay_order_id }).lean();
  if (!intent) throw ApiError.notFound('Subscription checkout not found for this business');
  const client = gateway.getRazorpayClient();
  if (!client) throw new ApiError(503, 'Subscription payment gateway is not configured');
  const payment = await client.payments.fetch(data.razorpay_payment_id);
  if (payment.id !== data.razorpay_payment_id || payment.order_id !== intent.providerOrderId || payment.status !== 'captured'
    || payment.amount !== intent.amount || payment.currency !== intent.currency || (payment.amount_refunded || 0) !== 0) {
    throw ApiError.badRequest('Payment is not a matching captured subscription payment', null, 'PAYMENT_NOT_VERIFIED');
  }
  const now = new Date();
  // Receipt identity and expiry extension commit in the same business write.
  // Replayed HTTP/webhook requests cannot extend again. Manual flags are never
  // touched, including a deliberately disabled subscription or Chotu feature.
  await Business.collection.updateOne({ _id: new mongoose.Types.ObjectId(String(businessId)), subscriptionRenewalOrderIds: { $ne: intent.providerOrderId } }, [{
    $set: {
      subscriptionExpiresAt: { $add: [{ $cond: [
        { $and: [{ $eq: [{ $type: '$subscriptionExpiresAt' }, 'date'] }, { $gt: ['$subscriptionExpiresAt', now] }] },
        '$subscriptionExpiresAt', now,
      ] }, intent.days * 86400000] },
      subscriptionRenewalOrderIds: { $concatArrays: [{ $ifNull: ['$subscriptionRenewalOrderIds', []] }, [intent.providerOrderId]] },
    },
  }]);
  const result = await access.status(businessId);
  require('./socketService').emitSubscriptionUpdated(businessId, result);
  return { ...result, paymentRef: payment.id, paymentVerified: true };
}

async function webhook(payload) {
  if (payload?.event !== 'payment.captured') return null;
  const payment = payload.payload?.payment?.entity;
  if (!payment?.order_id) return null;
  const intent = await Intent.findOne({ providerOrderId: payment.order_id }).lean();
  if (!intent) return null; // Ordinary restaurant-order payments retain their existing flow.
  return verify(intent.businessId, { razorpay_payment_id: payment.id, razorpay_order_id: payment.order_id });
}

module.exports = { create, verify, webhook };
