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

module.exports = router;
