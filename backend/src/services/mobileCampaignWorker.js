const { randomUUID } = require('crypto');
const Campaign = require('../models/Campaign');
const Coupon = require('../models/Coupon');
const wallet = require('./walletService');
const transport = require('./mobileCampaignTransport');

function countStatuses(statuses) {
  return { $size: { $filter: { input: '$audience.recipients', as: 'r', cond: { $in: ['$$r.status', statuses] } } } };
}

// Recount inside Mongo so a webhook and worker completing together use current recipient states.
async function recount(filter) {
  await Campaign.updateOne(filter, [{ $set: {
    'stats.messagesSent': countStatuses(['sent', 'delivered', 'read']),
    'stats.delivered': countStatuses(['delivered', 'read']), 'stats.read': countStatuses(['read']),
    'stats.failed': countStatuses(['failed']),
  } }, { $set: { 'stats.deliveryRate': { $cond: [{ $gt: ['$stats.messagesSent', 0] },
    { $round: [{ $multiply: [{ $divide: ['$stats.delivered', '$stats.messagesSent'] }, 100] }, 1] }, 0] } } }]);
}

async function receipt(campaign, update) {
  const status = String(update.status || '').toLowerCase();
  const previous = { delivered: ['sent'], read: ['sent', 'delivered'], failed: ['sent'] }[status];
  if (!previous) return;
  const filter = { _id: campaign._id, businessId: campaign.businessId };
  const fields = { 'audience.recipients.$.status': status };
  if (status === 'failed') fields['audience.recipients.$.error'] = update.errors?.[0]?.message || 'Delivery failed';
  else fields['audience.recipients.$.deliveredAt'] = update.timestamp || new Date();
  await Campaign.updateOne({ ...filter, 'audience.recipients': { $elemMatch: { messageId: update.messageId, status: { $in: previous } } } }, { $set: fields });
  await recount(filter);
}

async function reserveCoupon(c) {
  const r = c.rewardDetails;
  if (r.rewardType === 'promotional') return null;
  const discountType = { percentage: 'percentage', flat_discount: 'flat', free_gift: 'free_gift', bogo: 'bogo' }[r.rewardType];
  try {
    return await Coupon.findOneAndUpdate({ businessId: c.businessId, campaignId: c._id, code: c.couponSettings.couponCode }, { $setOnInsert: {
      title: c.name, description: c.template.body, discountType, discountValue: r.discountAmount || 0,
      minCartAmount: r.minSpendAmount, maxDiscountAmount: r.maxCashbackCap || null,
      giftQuantity: r.giftQuantity, freeGiftProductId: r.freeGiftProductId, freeGiftProductName: r.freeGiftProductName,
      freeGiftProductPrice: r.freeGiftProductPrice, buyQuantity: r.buyQuantity, buyProductId: r.buyProductId,
      orderTypes: c.orderTypes.map(t => t === 'dine_in' ? 'dineIn' : t), isActive: false,
      startDate: c.schedule.scheduledAt || new Date(), endDate: c.couponSettings.expiryDate,
    } }, { upsert: true, new: true, runValidators: true });
  } catch (error) {
    if (error.code === 11000) throw new Error('Coupon code already in use.');
    throw error;
  }
}

// A review poll can only approve a draft or return it for editing. It never enters the delivery queue.
async function reviewDue(now) {
  const due = await Campaign.find({ status: 'in_review', 'mobileStudio.nextCheckAt': { $lte: now } })
    .select('_id businessId').sort({ 'mobileStudio.nextCheckAt': 1 }).limit(20).lean();
  await Promise.all(due.map(async entry => {
    const worker = randomUUID();
    const key = { _id: entry._id, businessId: entry.businessId, status: 'in_review' };
    const c = await Campaign.findOneAndUpdate({ ...key, 'mobileStudio.nextCheckAt': { $lte: now } },
      { $set: { 'mobileStudio.worker': worker, 'mobileStudio.nextCheckAt': new Date(Date.now() + 5 * 60000) } }, { new: true });
    if (!c) return;
    const finish = (status, metaStatus, note) => Campaign.updateOne({ ...key, 'mobileStudio.worker': worker },
      { $set: { status, 'template.metaStatus': metaStatus, 'mobileStudio.worker': null, 'mobileStudio.note': note,
        ...(status !== 'in_review' && { 'mobileStudio.nextCheckAt': null }) }, ...(status === 'draft' && { $unset: { 'mobileStudio.reservedCode': 1 } }) });
    try {
      await require('./entitlementService').requireSubscription(c.businessId);
      if (c.couponSettings.expiryDate <= new Date()) throw new Error('The campaign expired during review.');
      const result = await transport.approval(c, await transport.account(c));
      if (result === 'APPROVED') return await finish('approved', 'APPROVED', c.template.category === 'AUTHENTICATION'
        ? 'Approved by Meta for customer-requested verification codes.' : 'Approved by Meta. Ready to send.');
      if (['PENDING', 'IN_APPEAL'].includes(result)) return await finish('in_review', 'PENDING', 'Awaiting Meta approval');
      return await finish('draft', 'REJECTED', 'Meta declined this template. Edit the message and submit again.');
    } catch (error) {
      if (error.code === 'SUBSCRIPTION_REQUIRED' || error.transient || ['TypeError', 'TimeoutError'].includes(error.name)) {
        return await finish('in_review', c.template.metaStatus, 'Review will resume when the channel and subscription are available.');
      }
      return await finish('draft', 'DRAFT', error.message);
    }
  }));
}

async function run(campaign) {
  if (!campaign.mobileStudio?.sendAuthorizedAt) return;
  const base = { _id: campaign._id, businessId: campaign.businessId, status: 'processing' };
  const worker = randomUUID();
  const c = await Campaign.findOneAndUpdate({ ...base, 'mobileStudio.worker': null },
    { $set: { 'mobileStudio.worker': worker } }, { new: true });
  if (!c) return;
  const lock = { ...base, 'mobileStudio.worker': worker };
  const release = (status, note, values = {}) => Campaign.updateOne(lock, { $set: {
    status, 'mobileStudio.note': note, 'mobileStudio.worker': null, ...values,
  } });
  let dispatchStarted = c.cost.spentSoFar > 0 || c.audience.recipients.some(r => r.status !== 'pending');
  try {
    if (c.couponSettings.expiryDate <= new Date()) throw new Error('The offer has expired.');
    const credentials = await transport.account(c);
    const approval = await transport.approval(c, credentials, false);
    if (approval !== 'APPROVED') {
      return await release(dispatchStarted ? 'failed' : 'draft', 'Meta approval changed. Review the template again.',
        { 'template.metaStatus': 'REJECTED', 'mobileStudio.sendAuthorizedAt': null });
    }
    if (c.schedule.mode === 'later' && c.schedule.scheduledAt > new Date()) {
      return await release('scheduled', 'Scheduled', { 'template.metaStatus': 'APPROVED', 'mobileStudio.nextCheckAt': c.schedule.scheduledAt });
    }
    const coupon = await reserveCoupon(c);
    await wallet.getOrCreateWallet(c.businessId);
    await wallet.deductWalletAtomic({ businessId: c.businessId, amount: c.cost.totalAmount, category: 'CAMPAIGN_DISPATCH',
      referenceType: 'CAMPAIGN_DISPATCH', referenceId: c.campaignId, idempotencyKey: 'campaign_hold_' + c._id, description: c.name });
    dispatchStarted = true;
    await Campaign.updateOne(lock, { $set: { 'template.metaStatus': 'APPROVED', 'cost.spentSoFar': c.cost.totalAmount,
      'cost.remaining': 0, 'mobileStudio.note': 'Sending messages', couponId: coupon?._id || null } });
    if (coupon) await Coupon.updateOne({ businessId: c.businessId, _id: coupon._id }, { $set: { isActive: true } });

    for (const recipient of c.audience.recipients) {
      if (recipient.status !== 'pending') continue;
      if (c.couponSettings.expiryDate <= new Date()) break;
      // Claim before I/O. After a worker dies, an uncertain send is never repeated.
      const claim = await Campaign.updateOne({ ...lock, 'audience.recipients': { $elemMatch: { _id: recipient._id, status: 'pending' } } },
        { $set: { 'audience.recipients.$.status': 'sending' } });
      if (!claim.modifiedCount) continue;
      let fields;
      try {
        const messageId = await transport.send(c, credentials, recipient);
        fields = { 'audience.recipients.$.status': 'sent', 'audience.recipients.$.messageId': messageId, 'audience.recipients.$.sentAt': new Date() };
      } catch (err) {
        fields = { 'audience.recipients.$.status': 'failed', 'audience.recipients.$.error': err.message };
      }
      await Campaign.updateOne({ ...lock, 'audience.recipients._id': recipient._id }, { $set: fields });
    }
    await Campaign.updateOne(lock, { $set: { 'audience.recipients.$[r].status': 'failed',
      'audience.recipients.$[r].error': 'Delivery could not be confirmed before recovery or expiry.' } },
    { arrayFilters: [{ 'r.status': { $in: ['sending', 'pending'] } }] });
    await recount(lock);
    const final = await Campaign.findOne(lock).select('stats audience.recipients.error').lean();
    if (!final) return;
    if (!final.stats.messagesSent && coupon) {
      await Coupon.updateOne({ _id: coupon._id, businessId: c.businessId }, { $set: { isActive: false } });
    }
    return await release(final.stats.messagesSent ? 'completed' : 'failed',
      final.stats.failed ? (final.stats.messagesSent + ' sent · ' + final.stats.failed + ' failed. ' +
      (final.audience.recipients.find(r => r.error)?.error || '')) : 'Dispatch completed', { 'stats.completionRate': 100 });
  } catch (err) {
    if (!dispatchStarted && (err.transient || ['TypeError', 'TimeoutError'].includes(err.name))) {
      return await release('scheduled', 'Waiting to reconnect to WhatsApp', { 'mobileStudio.nextCheckAt': new Date(Date.now() + 5 * 60000) });
    }
    if (!dispatchStarted) {
      // A failed wallet check can leave an inactive reservation. A revised draft may use another code.
      await Coupon.deleteOne({ businessId: c.businessId, campaignId: c._id, isActive: false });
    }
    return await release(dispatchStarted ? 'failed' : 'approved', err.message,
      dispatchStarted ? {} : { 'mobileStudio.sendAuthorizedAt': null });
  }
}

module.exports = { run, receipt, reviewDue };
