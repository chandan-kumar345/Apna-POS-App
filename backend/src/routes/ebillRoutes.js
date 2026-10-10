const express = require('express');
const ebillController = require('../controllers/ebillController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

// All eBill endpoints require authenticated business session
router.use(authMiddleware);

// Check eBill eligibility (wallet balance, fee, customer phone)
router.get('/eligibility', (req, res, next) => ebillController.getEligibility(req, res, next));

// Save & send eBill via WhatsApp Cloud API
router.post('/send', (req, res, next) => ebillController.sendEbill(req, res, next));

// Query eBill delivery status
router.get('/:ebillId/status', (req, res, next) => ebillController.getEbillStatus(req, res, next));

module.exports = router;
