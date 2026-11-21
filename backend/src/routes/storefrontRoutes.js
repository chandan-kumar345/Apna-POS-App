const express = require('express');
const storefrontController = require('../controllers/storefrontController');

const router = express.Router();
const customerAuth = require('../services/storefrontCustomerAuthService');
const ApiResponse = require('../utils/ApiResponse');
const rateLimit = require('express-rate-limit');
const otpLimit = rateLimit({ windowMs: 15 * 60 * 1000, max: 100, standardHeaders: true, legacyHeaders: false });
router.post('/:slug/customer/send-otp', otpLimit, async (req, res, next) => {
  try { return ApiResponse.success(res, await customerAuth.send(req.params.slug, req.body)); } catch (e) { next(e); }
});
router.post('/:slug/customer/verify-otp', otpLimit, async (req, res, next) => {
  try { res.set('Cache-Control', 'no-store'); return ApiResponse.success(res, await customerAuth.verify(req.params.slug, req.body)); } catch (e) { next(e); }
});
for (const action of ['me', 'orders']) router.get(`/:slug/customer/${action}`, async (req, res, next) => {
  try { res.set('Cache-Control', 'no-store'); return ApiResponse.success(res, await customerAuth[action](req.params.slug, req.get('x-storefront-session'))); } catch (e) { next(e); }
});

// Public storefront routes (no auth required so customers can browse & order)
const Coupon = require('../models/Coupon');
const Campaign = require('../models/Campaign');
router.get('/:businessId/coupons', async (req, res, next) => {
  try {
    const { businessId } = req.params;
    if (!/^[a-f\d]{24}$/i.test(businessId)) return ApiResponse.success(res, []);
    const visible = await Campaign.find({ businessId, 'couponSettings.displayCouponInProfile': true }).distinct('_id');
    const now = new Date();
    const coupons = await Coupon.find({ businessId, isActive: true, campaignId: { $in: [null, ...visible] },
      $and: [{ $or: [{ startDate: null }, { startDate: { $lte: now } }] },
        { $or: [{ endDate: null }, { endDate: { $gt: now } }] }] })
      .select('code title description discountType discountValue minCartAmount maxDiscountAmount isActive startDate endDate').limit(100).lean();
    return ApiResponse.success(res, coupons);
  } catch (error) { next(error); }
});
router.post('/:businessId/coupon-quote', async (req, res, next) => {
  try {
    if (!/^[a-f\d]{24}$/i.test(req.params.businessId)) throw require('../utils/ApiError').badRequest('Invalid restaurant.');
    const { code, subtotal, orderType, cartItems, customerPhone } = req.body;
    if (typeof code !== 'string' || !Array.isArray(cartItems) || cartItems.length > 500) {
      throw require('../utils/ApiError').badRequest('Invalid coupon request.');
    }
    const result = await require('../services/couponService').validateCoupon(req.params.businessId, { code, subtotal, orderType, cartItems, customerPhone });
    const fallback = !result.valid && ['WELCOME50','CHEF20','FESTIVE100'].includes(code.toUpperCase()) &&
      !await Coupon.exists({ businessId: req.params.businessId, code: code.toUpperCase() }) &&
      !await Campaign.exists({ businessId: req.params.businessId, 'couponSettings.couponCode': code.toUpperCase() });
    return ApiResponse.success(res, { valid: result.valid, allowDefaultOffer: fallback, message: result.message, discountAmount: result.discountAmount, code: result.coupon?.code });
  } catch (error) { next(error); }
});
router.get('/:slug', (req, res, next) => storefrontController.getStorefront(req, res, next));
router.post('/:slug/order', (req, res, next) => storefrontController.createStorefrontOrder(req, res, next));
router.get('/:slug/order/:orderId/status', (req, res, next) => storefrontController.getOrderStatus(req, res, next));

module.exports = router;
