const express = require('express');
const whatsappWebhookController = require('../controllers/whatsappWebhookController');
const whatsappChatController = require('../controllers/whatsappChatController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

// ==========================================
// 1. PUBLIC META WEBHOOK ROUTES
// ==========================================
// Meta Webhook Verification (GET)
router.get('/webhook', (req, res) => whatsappWebhookController.verifyWebhook(req, res));

// Meta Inbound Messages & Delivery Status Events (POST)
router.post('/webhook', (req, res) => whatsappWebhookController.handleWebhook(req, res));

// ==========================================
// 2. AUTHENTICATED WHATSAPP LIVE CHAT ROUTES
// ==========================================
router.use('/chats', authMiddleware);

// Get WhatsApp chats list for business
router.get('/chats', (req, res, next) => whatsappChatController.getChats(req, res, next));

// Check connection status & active Phone Number ID
router.get('/chats/connection', (req, res, next) => whatsappChatController.getConnectionStatus(req, res, next));

// Connect Meta API credentials / Phone Number ID
router.post('/chats/connect', (req, res, next) => whatsappChatController.saveConnection(req, res, next));

// Start a new WhatsApp chat with a customer
router.post('/chats/new', (req, res, next) => whatsappChatController.startNewChat(req, res, next));

// Get messages for a specific conversation
router.get('/chats/:chatId/messages', (req, res, next) => whatsappChatController.getMessages(req, res, next));

// Send a reply message to customer via Meta Cloud API
router.post('/chats/:chatId/messages', (req, res, next) => whatsappChatController.sendMessage(req, res, next));

// Mark chat as read
router.put('/chats/:chatId/read', (req, res, next) => whatsappChatController.markRead(req, res, next));

module.exports = router;
