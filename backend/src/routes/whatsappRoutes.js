const express = require('express');
const whatsappWebhookController = require('../controllers/whatsappWebhookController');

const router = express.Router();

// Meta Webhook Verification (GET)
router.get('/webhook', (req, res) => whatsappWebhookController.verifyWebhook(req, res));

// Meta Delivery Status & Failure Events (POST)
router.post('/webhook', (req, res) => whatsappWebhookController.handleWebhook(req, res));

module.exports = router;
