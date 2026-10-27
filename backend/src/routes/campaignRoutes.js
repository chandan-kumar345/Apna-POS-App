const express = require('express');
const campaignController = require('../controllers/campaignController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

// Strict multi-tenant isolation guard via authMiddleware
router.use(authMiddleware);

// Meta resources & KPIs
router.get('/stats', (req, res, next) => campaignController.getDashboardStats(req, res, next));
router.get('/templates', (req, res, next) => campaignController.getTemplates(req, res, next));
router.get('/channels', (req, res, next) => campaignController.getChannels(req, res, next));
router.get('/audience-groups', (req, res, next) => campaignController.getAudienceGroups(req, res, next));

// Auto campaigns
router.get('/auto', (req, res, next) => campaignController.getAutoCampaigns(req, res, next));
router.post('/auto', (req, res, next) => campaignController.createAutoCampaign(req, res, next));
router.put('/auto/:id/toggle', (req, res, next) => campaignController.toggleAutoCampaign(req, res, next));

// Standard Campaigns CRUD & Execution
router.get('/', (req, res, next) => campaignController.getCampaigns(req, res, next));
router.post('/', (req, res, next) => campaignController.createCampaign(req, res, next));
router.get('/:id', (req, res, next) => campaignController.getCampaignById(req, res, next));
router.put('/:id/pause', (req, res, next) => campaignController.pauseCampaign(req, res, next));
router.put('/:id/resume', (req, res, next) => campaignController.resumeCampaign(req, res, next));

module.exports = router;
