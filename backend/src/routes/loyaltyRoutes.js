const express = require('express');
const loyaltyController = require('../controllers/loyaltyController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

// Apply auth middleware for all loyalty endpoints
router.use(authMiddleware);

// Configuration & programs
router.get('/programs', (req, res, next) => loyaltyController.getPrograms(req, res, next));
router.get('/config', (req, res, next) => loyaltyController.getVisitConfig(req, res, next));
router.post('/config', (req, res, next) => loyaltyController.saveVisitConfig(req, res, next));
router.post('/programs', (req, res, next) => loyaltyController.updateProgram(req, res, next));
router.put('/programs/:id', (req, res, next) => loyaltyController.updateProgram(req, res, next));
router.get('/performance', (req, res, next) => loyaltyController.getPerformance(req, res, next));

// Customer Loyalty & Point Accrual
router.get('/customer/:phone', (req, res, next) => loyaltyController.getCustomerLoyalty(req, res, next));
router.post('/earn', (req, res, next) => loyaltyController.awardPoints(req, res, next));

// OTP-Secured Redemption Flow
router.post('/send-otp', (req, res, next) => loyaltyController.sendOtp(req, res, next));
router.post('/verify-otp', (req, res, next) => loyaltyController.verifyOtp(req, res, next));
router.post('/redeem', (req, res, next) => loyaltyController.redeemPoints(req, res, next));

module.exports = router;
