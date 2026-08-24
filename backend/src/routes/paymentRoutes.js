const express = require('express');
const paymentController = require('../controllers/paymentController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

// Public Webhook endpoint (Razorpay calls this directly)
router.post('/webhook', (req, res, next) =>
  paymentController.handleWebhook(req, res, next)
);

// Authenticated POS Endpoints
router.post('/create-qr', authMiddleware, (req, res, next) =>
  paymentController.createUpiQr(req, res, next)
);

router.get('/status/:orderId', authMiddleware, (req, res, next) =>
  paymentController.getPaymentStatus(req, res, next)
);

module.exports = router;
