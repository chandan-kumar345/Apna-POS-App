const express = require('express');
const profileController = require('../controllers/profileController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.use(authMiddleware);

router.get('/', (req, res, next) => profileController.getProfile(req, res, next));
router.patch('/pos-settings', (req, res, next) => profileController.updatePosSettings(req, res, next));
router.patch('/settings', (req, res, next) => profileController.updateSettings(req, res, next));

module.exports = router;
