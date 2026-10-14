const express = require('express');
const router = express.Router();
const couponController = require('../controllers/couponController');
const authMiddleware = require('../middleware/authMiddleware');

router.use(authMiddleware);

router.post('/', (req, res, next) => couponController.createCoupon(req, res, next));
router.get('/', (req, res, next) => couponController.getCoupons(req, res, next));
router.post('/validate', (req, res, next) => couponController.validateCoupon(req, res, next));
router.get('/reports/redemptions', (req, res, next) => couponController.getRedemptions(req, res, next));
router.get('/:id', (req, res, next) => couponController.getCouponById(req, res, next));
router.put('/:id', (req, res, next) => couponController.updateCoupon(req, res, next));
router.patch('/:id/toggle', (req, res, next) => couponController.toggleCoupon(req, res, next));
router.delete('/:id', (req, res, next) => couponController.deleteCoupon(req, res, next));

module.exports = router;
