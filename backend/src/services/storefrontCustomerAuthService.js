const crypto = require('crypto');
const Business = require('../models/Business');
const Customer = require('../models/Customer');
const Order = require('../models/Order');
const { Challenge, Session } = require('../models/StorefrontCustomerAuth');
const env = require('../config/env');
const transport = require('./storefrontOtpTransport');
const ApiError = require('../utils/ApiError');
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const digest = (id, phone, code) => crypto.createHmac('sha256', env.JWT_ACCESS_SECRET).update(`${id}:${phone}:${code}`).digest('hex');
const publicCustomer = c => ({ id: String(c._id), name: c.name || 'Valued Customer', phone: `+91${phoneNumber(c.phone)}`, createdAt: c.createdAt, lastLoginAt: c.lastLoginAt });
function phoneNumber(value) {
  const phone = String(value || '').replace(/[\s()+-]/g, '').replace(/^91(?=\d{10}$)/, '');
  if (!/^[6-9]\d{9}$/.test(phone)) throw ApiError.badRequest('Enter a valid 10-digit Indian mobile number.');
  return phone;
}
async function business(slug) {
  const raw = String(slug || '').trim().toLowerCase();
  let found;
  if (/^[a-f0-9]{24}$/.test(raw)) found = await Business.findById(raw);
  else {
    const name = raw.replace(/-/g, ' ').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    found = await Business.findOne({ $or: [{ 'profile.slug': raw }, { slug: raw }, { 'storefront.slug': raw },
      { 'profile.name': new RegExp(`^${name}$`, 'i') }, { 'profile.companyName': new RegExp(`^${name}$`, 'i') }] });
  }
  if (!found) throw ApiError.notFound('Restaurant not found.');
  return found;
}
async function getCustomer(businessId, phone) {
  let customer = await Customer.findOne({ businessId, phone: { $in: [phone, `91${phone}`, `+91${phone}`, `+91 ${phone}`] } });
  if (!customer) {
    try {
      customer = await Customer.findOneAndUpdate({ businessId, phone }, {
        $setOnInsert: { businessId, phone, name: 'Valued Customer', source: 'Table QR' },
      }, { upsert: true, new: true, setDefaultsOnInsert: true });
    } catch (error) {
      if (error.code !== 11000) throw error;
      customer = await Customer.findOne({ businessId, phone });
    }
  }
  return customer;
}
async function send(slug, input) {
  const owner = await business(slug), phone = phoneNumber(input.phone);
  const now = new Date(), challengeId = crypto.randomUUID(), code = String(crypto.randomInt(100000, 1000000));
  const data = { challengeId, codeHash: digest(challengeId, phone, code), expiresAt: new Date(+now + 300000), resendAt: new Date(+now + 60000),
    attempts: 0, delivered: false, consumedAt: null };
  let challenge;
  try {
    challenge = await Challenge.findOneAndUpdate({ businessId: owner._id, phone, resendAt: { $lte: now } },
      { $set: data, $setOnInsert: { businessId: owner._id, phone } }, { upsert: true, new: true });
  } catch (error) {
    if (error.code === 11000) throw new ApiError(429, 'Please wait one minute before requesting another code.', 'OTP_COOLDOWN');
    throw error;
  }
  try { await transport.send(phone, code); }
  catch (error) {
    await Challenge.deleteOne({ _id: challenge._id, challengeId });
    throw error.isOperational ? error : new ApiError(503, 'WhatsApp verification is unavailable. Please try later.', 'OTP_UNAVAILABLE');
  }
  await getCustomer(owner._id, phone);
  await Challenge.updateOne({ _id: challenge._id, challengeId }, { $set: { delivered: true } });
  return { challengeId, expiresIn: 300, resendAfter: 60, channel: 'whatsapp' };
}
async function verify(slug, input) {
  const owner = await business(slug), phone = phoneNumber(input.phone);
  if (!/^\d{6}$/.test(input.code || '') || typeof input.challengeId !== 'string') throw ApiError.badRequest('Enter the six-digit WhatsApp code.');
  if (input.name != null && (typeof input.name !== 'string' || input.name.trim().length > 80)) throw ApiError.badRequest('Name must be at most 80 characters.');
  const challenge = await Challenge.findOneAndUpdate({ businessId: owner._id, phone, challengeId: input.challengeId,
    delivered: true, consumedAt: null, expiresAt: { $gt: new Date() }, attempts: { $lt: 5 } }, { $inc: { attempts: 1 } }, { new: true }).select('+codeHash');
  const invalid = () => ApiError.unauthorized('Code is incorrect or expired. Request a new code if needed.', 'INVALID_OTP');
  if (!challenge) throw invalid();
  const supplied = digest(input.challengeId, phone, input.code);
  if (!crypto.timingSafeEqual(Buffer.from(challenge.codeHash, 'hex'), Buffer.from(supplied, 'hex'))) throw invalid();
  const consumed = await Challenge.findOneAndUpdate({ _id: challenge._id, consumedAt: null, delivered: true }, { $set: { consumedAt: new Date() } });
  if (!consumed) throw invalid();
  const customer = await getCustomer(owner._id, phone);
  customer.name = input.name?.trim() || customer.name?.trim() || 'Valued Customer';
  customer.phoneVerifiedAt = new Date(); customer.lastLoginAt = new Date();
  await customer.save();
  const token = crypto.randomBytes(32).toString('hex');
  await Session.create({ businessId: owner._id, customerId: customer._id, phone, tokenHash: hash(token), expiresAt: new Date(Date.now() + 30 * 86400000) });
  return { token, customer: publicCustomer(customer) };
}
async function authenticate(businessId, token) {
  if (typeof token !== 'string' || !/^[a-f0-9]{64}$/.test(token)) throw ApiError.unauthorized('Please sign in with your WhatsApp code.');
  const session = await Session.findOne({ businessId, tokenHash: hash(token), expiresAt: { $gt: new Date() } });
  if (!session) throw ApiError.unauthorized('Customer session expired. Please sign in again.');
  const customer = await Customer.findOne({ businessId, _id: session.customerId });
  if (!customer) throw ApiError.unauthorized('Customer session is unavailable.');
  return { session, customer };
}
async function me(slug, token) {
  const owner = await business(slug);
  return publicCustomer((await authenticate(owner._id, token)).customer);
}
async function orders(slug, token) {
  const owner = await business(slug), { session, customer } = await authenticate(owner._id, token);
  const phone = session.phone;
  const found = await Order.find({ businessId: owner._id, $or: [{ customerId: customer._id },
    { customerPhone: { $in: [phone, `91${phone}`, `+91${phone}`, `+91 ${phone}`] } }] }).sort({ createdAt: -1 }).limit(100).lean();
  return found.map(o => ({ orderId: String(o._id), orderNumber: o.orderNumber, restaurantId: String(owner._id),
    restaurantName: owner.profile?.name || owner.profile?.companyName || '', status: o.status, currentStepIndex: ({pending: 0, preparing: 1, ready: 2, completed: 3})[o.status] || 0,
    items: o.items.map(i => ({ name: i.name, quantity: i.quantity, price: i.price, size: i.variantName || '' })),
    subtotal: o.subtotal, tax: o.taxAmount, deliveryFee: o.deliveryCharge || 0, discount: o.discountAmount || 0,
    grandTotal: o.totalAmount, paymentMethod: o.paymentMethod, paymentStatus: o.paymentStatus, createdAt: o.createdAt,
    deliveryAddress: o.tableNumber ? `Table ${o.tableNumber}` : o.deliveryAddress || '', customerName: o.customerName,
  }));
}
module.exports = { send, verify, me, orders, business, authenticate, phoneNumber };
