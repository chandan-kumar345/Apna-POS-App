const express = require('express');
const crmController = require('../controllers/crmController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.use(authMiddleware);

router.get('/leads', (req, res, next) => crmController.getLeads(req, res, next));
router.get('/stats', (req, res, next) => crmController.getStats(req, res, next));
router.get('/export', (req, res, next) => crmController.exportLeads(req, res, next));
router.post('/import', (req, res, next) => crmController.importLeads(req, res, next));

router.get('/leads/:id', (req, res, next) => crmController.getLeadById(req, res, next));
router.post('/leads', (req, res, next) => crmController.createLead(req, res, next));
router.patch('/leads/:id', (req, res, next) => crmController.updateLead(req, res, next));
router.put('/leads/:id', (req, res, next) => crmController.updateLead(req, res, next));

router.post('/leads/:id/stage', (req, res, next) => crmController.updateStage(req, res, next));
router.post('/leads/:id/followup', (req, res, next) => crmController.setFollowup(req, res, next));
router.post('/leads/:id/like', (req, res, next) => crmController.toggleLike(req, res, next));
router.post('/leads/:id/star', (req, res, next) => crmController.toggleStar(req, res, next));

module.exports = router;
