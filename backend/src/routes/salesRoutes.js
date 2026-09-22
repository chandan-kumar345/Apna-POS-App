const express = require('express');
const salesController = require('../controllers/salesController');
const authMiddleware = require('../middleware/authMiddleware');
const { requirePermission } = require('../middleware/permissionMiddleware');

const router = express.Router();

router.use(authMiddleware);
router.use(requirePermission('reports', 'reports_daily_sales', 'reports_financial'));

router.get('/', (req, res, next) => salesController.getSales(req, res, next));
router.get('/summary', (req, res, next) => salesController.getSummary(req, res, next));
router.get('/report', (req, res, next) => salesController.getReport(req, res, next));
router.get('/top-products', (req, res, next) => salesController.getTopProducts(req, res, next));

module.exports = router;
