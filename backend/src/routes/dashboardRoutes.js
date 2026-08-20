const express = require('express');
const dashboardController = require('../controllers/dashboardController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.use(authMiddleware);

router.get('/summary', (req, res, next) => dashboardController.getSummary(req, res, next));
router.get('/order-types', (req, res, next) => dashboardController.getOrderTypes(req, res, next));
router.get('/product-sales', (req, res, next) => dashboardController.getProductSales(req, res, next));
router.get('/customers', (req, res, next) => dashboardController.getCustomers(req, res, next));
router.get('/payment-methods', (req, res, next) => dashboardController.getPaymentMethods(req, res, next));
router.get('/taxes', (req, res, next) => dashboardController.getTaxes(req, res, next));
router.get('/order-stats', (req, res, next) => dashboardController.getOrderStats(req, res, next));
router.get('/chart', (req, res, next) => dashboardController.getChart(req, res, next));

module.exports = router;
