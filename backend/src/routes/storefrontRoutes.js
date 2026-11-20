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
router.get('/:slug', (req, res, next) => storefrontController.getStorefront(req, res, next));
router.post('/:slug/order', (req, res, next) => storefrontController.createStorefrontOrder(req, res, next));
router.get('/:slug/order/:orderId/status', (req, res, next) => storefrontController.getOrderStatus(req, res, next));

module.exports = router;
