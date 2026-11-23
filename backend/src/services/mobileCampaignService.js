const mongoose = require('mongoose');
const Campaign = require('../models/Campaign');
const Product = require('../models/Product');
const AudienceGroup = require('../models/AudienceGroup');
const Business = require('../models/Business');
const campaignService = require('./campaignService');
const whatsapp = require('./whatsappService');
const ApiError = require('../utils/ApiError');
const transport = require('./mobileCampaignTransport');

const rewardTypes = ['percentage', 'flat_discount', 'free_gift', 'bogo', 'promotional'];
const orderTypes = ['dine_in', 'takeaway', 'delivery'];
const categories = ['MARKETING', 'UTILITY', 'AUTHENTICATION'];
const channels = ['business_whatsapp', 'softcode_shared'];
const actionTypes = ['URL', 'PHONE_NUMBER', 'QUICK_REPLY'];

function check(condition, message) {
  if (!condition) throw ApiError.badRequest(message);
}
function string(value, max) {
  check(value == null || typeof value === 'string', 'Expected text');
  const s = (value || '').trim();
  check(s.length <= max, 'Text exceeds ' + max + ' characters');
  return s;
}
function number(value, max, integer = false) {
  if (value == null || value === '') return 0;
  const n = Number(value);
  check(Number.isFinite(n) && n >= 0 && n <= max && (!integer || Number.isInteger(n)), 'Invalid reward value');
  return n;
}
function date(value) {
  if (!value) return null;
  const result = new Date(value);
  check(Number.isFinite(result.getTime()), 'Choose a valid date and time');
  return result;
}
function id(value) {
  check(typeof value === 'string' && /^[a-f\d]{24}$/i.test(value), 'Invalid record ID');
  return value;
}
function choice(value, choices) {
  check(choices.includes(value), 'Choose a valid option');
  return value;
}
function publicDoc(doc) {
  const value = doc.toJSON ? doc.toJSON() : { ...doc, id: doc._id };
  const { recipients, ...audience } = value.audience || {};
  const { executionLogs, ...result } = value;
  return { ...result, audience };
}
function recipientsFor(group) {
  const result = new Map();
  for (const member of group?.numbers || []) {
    const phone = whatsapp.normalizePhoneNumber(member.phone);
    if (whatsapp.isValidPhoneNumber(phone) && !result.has(phone)) {
      result.set(phone, { phone, name: member.name || 'Customer', status: 'pending' });
    }
  }
  return [...result.values()];
}
function estimate(category, count) {
  const rate = category === 'UTILITY' ? 0.21 : 0.90; // Existing campaign wallet rates.
  const subtotal = Math.round(count * rate * 100) / 100;
  const gst = Math.round(subtotal * 18) / 100;
  const totalAmount = Math.round((subtotal + gst) * 100) / 100;
  return { messages: count, ratePerMessage: rate, subtotal, gst, totalAmount, remaining: totalAmount };
}

async function options(businessId) {
  const [products, groups, channelList, business] = await Promise.all([
    Product.find({ businessId, isAvailable: { $ne: false } }).select('productId name price').sort({ name: 1 }).lean(),
    AudienceGroup.find({ businessId }).select('name numbers.phone').sort({ name: 1 }).lean(),
    campaignService.getChannels(businessId),
    Business.findById(businessId).select('name profile.companyName profile.name profile.logoUrl profile.profileImage').lean(),
  ]);
  return {
    businessName: business?.profile?.companyName || business?.profile?.name || business?.name || 'My business',
    logoUrl: business?.profile?.logoUrl || business?.profile?.profileImage || '',
    products: products.map(p => ({ id: p.productId || String(p._id), name: p.name })),
    groups: groups.map(g => ({ id: g._id, name: g.name, count: recipientsFor(g).length })),
    channels: channelList.map(c => ({ id: c.id, name: c.businessName, connected: c.isConnected })),
  };
}

async function dashboard(businessId, query) {
  const filter = { businessId };
  const term = string(query.search, 100);
  if (term) filter.name = { $regex: term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), $options: 'i' };
  if (query.status === 'completed') filter.status = { $in: ['completed', 'sent'] };
  if (query.status === 'scheduled') filter.status = 'scheduled';
  const page = Math.max(1, parseInt(query.page, 10) || 1);
  const [docs, total, stats] = await Promise.all([
    Campaign.find(filter).select('-audience.recipients -executionLogs -deliveryTimeline').sort({ createdAt: -1, _id: -1 }).skip((page - 1) * 30).limit(30).lean(),
    Campaign.countDocuments(filter),
    Campaign.aggregate([{ $match: { businessId: new mongoose.Types.ObjectId(businessId) } },
      { $group: { _id: null, sent: { $sum: '$stats.messagesSent' }, read: { $sum: '$stats.read' } } }]),
  ]);
  return { campaigns: docs.map(publicDoc), total, sent: stats[0]?.sent || 0, read: stats[0]?.read || 0 };
}

async function menuItem(businessId, key) {
  if (!key) return null;
  const clauses = [{ productId: key }];
  if (mongoose.isObjectIdOrHexString(key)) clauses.push({ _id: key });
  const product = await Product.findOne({ businessId, $or: clauses, isAvailable: { $ne: false } }).select('productId name price').lean();
  check(product, 'This menu item is no longer available. Choose another item.');
  return { id: product.productId || String(product._id), name: product.name, price: product.price };
}

async function draftFields(businessId, input) {
  const reward = input.rewardType ? choice(input.rewardType, rewardTypes) : null;
  check(Array.isArray(input.orderTypes || []), 'Select valid order types');
  const orders = [...new Set(input.orderTypes || [])];
  orders.forEach(t => choice(t, orderTypes));
  const category = choice(input.category || 'MARKETING', categories);
  const channelType = choice(input.channel || 'business_whatsapp', channels);
  const title = string(input.title, 100);
  const auth = category === 'AUTHENTICATION';
  const body = auth ? '{{1}} is your verification code.' : string(input.body, 1024);
  const image = auth ? '' : string(input.imageUrl, 2048);
  if (image) transport.validateImage(businessId, image);
  const groupId = input.groupId ? id(input.groupId) : null;
  const [gift, buy, group] = await Promise.all([
    menuItem(businessId, ['free_gift', 'bogo'].includes(reward) && string(input.giftItem, 150)),
    menuItem(businessId, reward === 'bogo' && string(input.buyItem, 150)),
    groupId ? AudienceGroup.findOne({ _id: groupId, businessId }).select('name numbers.phone').lean() : null,
  ]);
  check(!groupId || group, 'Choose an audience group from this business');
  const code = string(input.couponCode, 32).toUpperCase();
  check(!code || /^[A-Z0-9_-]+$/.test(code), 'Use letters, numbers, dashes or underscores for the coupon');
  check(Array.isArray(input.actions || []) && (input.actions || []).length <= 3, 'Add up to three actions');
  const actions = (auth ? [] : input.actions || []).map(a => ({
    type: choice(a.type, actionTypes), text: string(a.text, 25),
    value: a.type === 'QUICK_REPLY' ? '' : string(a.value, 1024),
  }));
  const details = {
    rewardType: reward, campaignTitle: title, description: body,
    discountAmount: ['percentage', 'flat_discount'].includes(reward) ? number(input.discountAmount, reward === 'percentage' ? 100 : 1e8) : 0,
    minSpendAmount: ['percentage', 'flat_discount', 'free_gift'].includes(reward) ? number(input.minimumOrder, 1e8) : 0,
    maxCashbackCap: reward === 'percentage' ? number(input.maximumDiscount, 1e8) : 0,
    freeGiftProductId: gift?.id || '', freeGiftProductName: gift?.name || '', freeGiftProductPrice: gift?.price || 0,
    giftQuantity: gift ? number(input.giftQty ?? 1, 999, true) : undefined,
    buyProductId: buy?.id || '', buyProductName: buy?.name || '',
    buyQuantity: buy ? number(input.buyQty ?? 1, 999, true) : undefined,
    promotionHeadline: reward === 'promotional' ? string(input.headline, 120) : '',
    offerDetails: reward === 'promotional' ? string(input.offerDetails, 800) : '',
    termsAndConditions: reward === 'promotional' && input.terms ? [string(input.terms, 500)] : [],
  };
  details.hasMinSpend = details.minSpendAmount > 0;
  const scheduledAt = input.scheduleMode === 'later' ? date(input.sendAt) : null;
  return {
    name: title || 'Untitled campaign', type: category.toLowerCase(), orderTypes: orders, rewardDetails: details,
    couponSettings: { couponCode: code, customCouponCode: code, useCustomCouponCode: !!code, hasExpiryDate: true, expiryDate: date(input.expiryAt) },
    template: { name: title || 'Campaign message', body, category, actions, buttons: actions.map(a => a.text),
      headerType: image ? 'IMAGE' : 'NONE', headerMediaUrl: image, metaStatus: 'DRAFT', language: 'en' },
    channel: { channelType }, audience: { source: 'group', groupName: group?.name || '', recipientCount: recipientsFor(group).length },
    schedule: { mode: input.scheduleMode === 'later' ? 'later' : 'now', scheduledAt },
    'mobileStudio.groupId': groupId, 'mobileStudio.note': '',
  };
}

async function save(businessId, key, input) {
  id(key);
  const revision = number(input.revision, Number.MAX_SAFE_INTEGER, true);
  const fields = await draftFields(businessId, input);
  const filter = { _id: key, businessId, status: 'draft', 'mobileStudio.revision': revision };
  try {
    const doc = await Campaign.findOneAndUpdate(filter, {
      $set: fields, $inc: { 'mobileStudio.revision': 1 },
      $setOnInsert: { businessId, campaignId: campaignService._generateCampaignId(), status: 'draft' },
    }, { upsert: revision === 0, new: true, runValidators: true });
    if (doc) return publicDoc(doc);
  } catch (error) {
    if (error.code !== 11000) throw error;
  }
  throw ApiError.conflict('This draft changed. Reopen it from Campaigns.');
}

function ready(c) {
  const r = c.rewardDetails;
  check(c.orderTypes.length && r.rewardType, 'Select order types and a reward');
  check(c.couponSettings.couponCode, 'Enter a coupon code');
  check(c.couponSettings.expiryDate > new Date(), 'Choose a future expiry');
  if (['percentage', 'flat_discount'].includes(r.rewardType)) check(r.discountAmount > 0, 'Enter a positive discount');
  if (['free_gift', 'bogo'].includes(r.rewardType)) check(r.freeGiftProductId && r.giftQuantity >= 1, 'Choose the gift and quantity');
  if (r.rewardType === 'bogo') check(r.buyProductId && r.buyQuantity >= 1, 'Choose the qualifying item and quantity');
  if (r.rewardType === 'promotional') check(r.promotionHeadline && r.offerDetails, 'Enter a promotion headline and offer details');
  check(r.campaignTitle && c.template.body, 'Enter the campaign title and message');
  if (c.template.category === 'AUTHENTICATION') return;
  check(!/[{}]/.test(c.template.body.replace(/\{\{name\}\}/g, '')), 'Use {{name}} for the customer name');
  for (const a of c.template.actions || []) {
    check(a.text, 'Enter button text for each action');
    if (a.type === 'URL') check(/^https?:\/\/[^\s{}]+$/i.test(a.value) && URL.canParse(a.value), 'Enter a valid website URL');
    if (a.type === 'PHONE_NUMBER') check(/^\+[1-9]\d{6,14}$/.test(a.value), 'Include the country code in the call button number');
  }
  check((c.template.actions || []).filter(a => a.type === 'PHONE_NUMBER').length <= 1, 'Use one call button per message');
}

async function submit(businessId, key, input) {
  const filter = { businessId, _id: id(key), 'mobileStudio.revision': number(input.revision, Number.MAX_SAFE_INTEGER, true) };
  const c = await Campaign.findOne(filter);
  if (!c) throw ApiError.conflict('Reopen the campaign to use the latest revision');
  if (c.status !== 'draft') return publicDoc(c);
  ready(c);
  const [available, unique] = await Promise.all([
    campaignService.getChannels(businessId),
    campaignService.isCouponCodeUnique(businessId, c.couponSettings.couponCode, c._id),
    menuItem(businessId, c.rewardDetails.freeGiftProductId),
    menuItem(businessId, c.rewardDetails.buyProductId),
  ]);
  check(unique, 'This coupon code is already in use');
  const channel = available.find(ch => ch.id === c.channel.channelType && ch.isConnected);
  check(channel?.phoneNumberId && channel?.wabaId, 'Connect the selected WhatsApp channel before sending');
  let updated;
  try {
    updated = await Campaign.findOneAndUpdate({ ...filter, status: 'draft' }, { $set: {
      status: 'in_review', 'mobileStudio.nextCheckAt': new Date(), 'mobileStudio.worker': null,
      'mobileStudio.reservedCode': c.couponSettings.couponCode, 'mobileStudio.note': 'Queued for Meta review',
      'channel.name': channel.businessName, 'channel.phoneNumberId': channel.phoneNumberId,
      'template.metaTemplateName': 'apna_' + key + '_' + c.mobileStudio.revision,
    } }, { new: true });
  } catch (error) {
    if (error.code === 11000) throw ApiError.conflict('This coupon code is already in use');
    throw error;
  }
  const current = updated || await Campaign.findOne(filter);
  if (!current) throw ApiError.conflict('The draft was edited. Review the latest version.');
  return publicDoc(current);
}

async function launch(businessId, key, input, userId) {
  const filter = { businessId, _id: id(key), 'mobileStudio.revision': number(input.revision, Number.MAX_SAFE_INTEGER, true) };
  const c = await Campaign.findOne(filter);
  if (!c) throw ApiError.notFound('Campaign not found');
  if (c.mobileStudio.sendAuthorizedAt) return publicDoc(c);
  if (c.status !== 'approved' || c.template.metaStatus !== 'APPROVED') throw ApiError.conflict('Wait for Meta approval before sending.');
  check(c.template.category !== 'AUTHENTICATION', 'Auth templates deliver customer-requested verification codes only.');
  ready(c);
  check(input.confirmedOptIn === true, 'Confirm that the selected contacts opted in');
  const phones = input.phones || [];
  check(Array.isArray(phones) && phones.length <= 1000, 'Enter up to 1,000 numbers at a time.');
  const manual = phones.map(phone => {
    check(typeof phone === 'string' && /^\+?[\d ()-]{7,32}$/.test(phone) && whatsapp.isValidPhoneNumber(phone), 'Check the phone numbers entered.');
    return { phone };
  });

  const groupId = (input.groupId && typeof input.groupId === 'string' && /^[a-f\d]{24}$/i.test(input.groupId)) ? input.groupId : null;
  const [group] = await Promise.all([
    groupId ? AudienceGroup.findOne({ _id: groupId, businessId }).lean() : null,
    menuItem(businessId, c.rewardDetails.freeGiftProductId), menuItem(businessId, c.rewardDetails.buyProductId),
  ]);
  const recipients = recipientsFor({ numbers: [...(group?.numbers || []), ...manual] });
  check(recipients.length, 'Choose an audience group or enter mobile numbers to send');
  check(recipients.length === input.confirmedCount, 'The audience size changed. Reopen the review before sending.');
  const now = new Date();
  const mode = choice(input.scheduleMode || 'now', ['now', 'later']);
  const sendAt = mode === 'later' ? date(input.sendAt) : now;
  check(mode === 'now' || (sendAt > now && sendAt < c.couponSettings.expiryDate), 'Schedule before expiry and after the current time');
  const updated = await Campaign.findOneAndUpdate({ ...filter, status: 'approved', 'mobileStudio.sendAuthorizedAt': null }, { $set: {
    status: 'scheduled', 'mobileStudio.nextCheckAt': sendAt, 'mobileStudio.consentConfirmedAt': now,
    'mobileStudio.sendAuthorizedAt': now, 'mobileStudio.confirmedBy': userId,
    'mobileStudio.groupId': groupId, 'mobileStudio.note': mode === 'later' ? 'Scheduled' : 'Queued for sending',
    schedule: { mode, scheduledAt: sendAt }, 'audience.recipientCount': recipients.length,
    'audience.recipients': recipients, 'audience.groupName': group?.name || 'Custom Audience',
    'stats.totalRecipients': recipients.length, cost: estimate(c.template.category, recipients.length),
  } }, { new: true });
  const result = updated || await Campaign.findOne(filter);
  if (!result) throw ApiError.conflict('The draft was edited. Review the latest version.');
  return publicDoc(result);
}

async function performance(businessId, key) {
  const campaign = await campaignService.getCampaignById(businessId, key);
  const data = campaign.toJSON();
  const code = data.couponSettings?.couponCode || data.couponSettings?.customCouponCode;
  const [totals] = code ? await require('../models/Order').aggregate([
    { $match: { businessId: campaign.businessId, couponCode: code, status: { $ne: 'cancelled' },
      paymentStatus: { $ne: 'refunded' }, 'whatsappDetails.acceptanceStatus': { $ne: 'rejected' } } },
    { $group: { _id: null, couponOrders: { $sum: 1 }, couponRevenue: { $sum: '$totalAmount' } } },
  ]) : [];
  data.stats = { ...data.stats, couponOrders: totals?.couponOrders || 0, couponRevenue: totals?.couponRevenue || 0 };
  return data;
}

async function followUp(businessId, key, input, userId) {
  const c = await campaignService.getCampaignById(businessId, key);
  const mode = choice(input.mode, ['new', 'failed', 'all']);
  const batchKey = id(input.requestId);
  if (c.mobileStudio?.batchKey === batchKey) return publicDoc(c);
  check(c.mobileStudio?.sendAuthorizedAt && ['completed', 'failed'].includes(c.status) &&
    c.template.metaStatus === 'APPROVED' && c.template.category !== 'AUTHENTICATION',
    'Choose a finished campaign with an approved customer message.');
  check(c.couponSettings.expiryDate > new Date(), 'This campaign has expired.');
  check(input.confirmedOptIn === true, 'Confirm that these customers opted in.');
  const history = new Map(c.audience.recipients.map(r => [whatsapp.normalizePhoneNumber(r.phone), r]));
  let members;
  if (mode === 'new') {
    const phones = input.phones || [];
    check(Array.isArray(phones) && phones.length <= 1000, 'Enter up to 1,000 numbers at a time.');
    const manual = phones.map(phone => {
      check(typeof phone === 'string' && /^\+?[\d ()-]{7,32}$/.test(phone) && whatsapp.isValidPhoneNumber(phone), 'Check the phone numbers entered.');
      return { phone };
    });
    const group = input.groupId ? await AudienceGroup.findOne({ _id: id(input.groupId), businessId }).lean() : null;
    check(!input.groupId || group, 'Choose a group from this business.');
    members = recipientsFor({ numbers: [...(group?.numbers || []), ...manual] }).filter(r => !history.has(r.phone));
  } else {
    members = recipientsFor({ numbers: [...history.values()].filter(r => mode === 'all' || r.status === 'failed') });
  }
  check(members.length, 'There are no eligible contacts for this send.');
  const now = new Date();
  const cost = estimate(c.template.category, members.length);
  if (input.preview === true) return { count: members.length, totalAmount: cost.totalAmount };
  check(input.confirmedCount === members.length, 'Audience changed. Check the audience again.');
  const start = c.audience.recipients.length;
  const updated = await Campaign.findOneAndUpdate({ _id: c._id, businessId, status: c.status,
    'mobileStudio.batchKey': c.mobileStudio.batchKey || null }, {
    $push: { 'audience.recipients': { $each: members } },
    $set: { status: 'scheduled', 'mobileStudio.batchKey': batchKey, 'mobileStudio.batchStart': start,
      'mobileStudio.batchPriorSpend': c.cost.spentSoFar || 0, 'mobileStudio.sendAuthorizedAt': now,
      'mobileStudio.confirmedBy': userId, 'mobileStudio.consentConfirmedAt': now, 'mobileStudio.nextCheckAt': now,
      'mobileStudio.note': 'Queued for sending', schedule: { mode: 'now', scheduledAt: now },
      'stats.totalRecipients': start + members.length, 'audience.recipientCount': start + members.length,
      cost: { ...cost, spentSoFar: c.cost.spentSoFar || 0 } },
  }, { new: true });
  if (!updated) throw ApiError.conflict('Campaign changed. Refresh before sending again.');
  return publicDoc(updated);
}

module.exports = { options, dashboard, save, submit, launch, performance, followUp };
