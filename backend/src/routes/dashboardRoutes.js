const express = require('express');
const dashboardController = require('../controllers/dashboardController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.use(authMiddleware);

router.get('/summary', (req, res, next) => dashboardController.getSummary(req, res, next));
router.get('/chart', (req, res, next) => dashboardController.getChart(req, res, next));

module.exports = router;
