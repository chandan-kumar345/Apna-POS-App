const express = require('express');
const metaPartnerController = require('../controllers/metaPartnerController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.use(authMiddleware);

// GET /api/v1/meta-partner/status
router.get('/status', (req, res, next) => metaPartnerController.getStatus(req, res, next));

// POST /api/v1/meta-partner/connect
router.post('/connect', (req, res, next) => metaPartnerController.connect(req, res, next));

// PUT /api/v1/meta-partner/profile
router.put('/profile', (req, res, next) => metaPartnerController.updateProfile(req, res, next));

// POST /api/v1/meta-partner/co-manage
router.post('/co-manage', (req, res, next) => metaPartnerController.inviteCoManagement(req, res, next));

// POST /api/v1/meta-partner/disconnect
router.post('/disconnect', (req, res, next) => metaPartnerController.disconnect(req, res, next));

// POST /api/v1/meta-partner/test-message
router.post('/test-message', (req, res, next) => metaPartnerController.sendTestMessage(req, res, next));

// GET /api/v1/meta-partner/templates
router.get('/templates', (req, res, next) => metaPartnerController.getTemplates(req, res, next));

// POST /api/v1/meta-partner/templates/sync
router.post('/templates/sync', (req, res, next) => metaPartnerController.syncTemplates(req, res, next));

// GET /api/v1/meta-partner/analytics
router.get('/analytics', (req, res, next) => metaPartnerController.getAnalytics(req, res, next));

// POST /api/v1/meta-partner/oauth/exchange
router.post('/oauth/exchange', (req, res, next) => metaPartnerController.exchangeOAuth(req, res, next));

// Channels Fleet Management Routes
router.get('/channels', (req, res, next) => metaPartnerController.getChannels(req, res, next));
router.post('/channels', (req, res, next) => metaPartnerController.createChannel(req, res, next));
router.post('/channels/:id/register-pin', (req, res, next) => metaPartnerController.registerPin(req, res, next));
router.post('/channels/:id/subscribe-webhook', (req, res, next) => metaPartnerController.subscribeWebhook(req, res, next));
router.patch('/channels/:id/toggle-active', (req, res, next) => metaPartnerController.toggleActive(req, res, next));
router.delete('/channels/:id', (req, res, next) => metaPartnerController.deleteChannel(req, res, next));

module.exports = router;
