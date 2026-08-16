const express = require('express');
const salesController = require('../controllers/salesController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.use(authMiddleware);

router.get('/', (req, res, next) => salesController.getSales(req, res, next));
router.get('/summary', (req, res, next) => salesController.getSummary(req, res, next));
router.get('/top-products', (req, res, next) => salesController.getTopProducts(req, res, next));

module.exports = router;
