const express = require('express');
const loyaltyController = require('../controllers/loyaltyController');
const auth = require('../middleware/auth');
const attachBusinessId = require('../middleware/attachBusinessId');

const router = express.Router();

// Apply auth and attachBusinessId middleware for all loyalty endpoints
router.use(auth);
router.use(attachBusinessId);

router.get('/programs', (req, res, next) => loyaltyController.getPrograms(req, res, next));
router.get('/performance', (req, res, next) => loyaltyController.getPerformance(req, res, next));
router.post('/programs', (req, res, next) => loyaltyController.updateProgram(req, res, next));
router.put('/programs/:id', (req, res, next) => loyaltyController.updateProgram(req, res, next));

module.exports = router;
