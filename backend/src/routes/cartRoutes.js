const express = require('express');
const cartController = require('../controllers/cartController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

// Protect all cart routes with authenticated business session
router.use(authMiddleware);

router.get('/', (req, res, next) => cartController.getCart(req, res, next));
router.post('/add', (req, res, next) => cartController.addToCart(req, res, next));
router.post('/reduce', (req, res, next) => cartController.reduceProductFromCart(req, res, next));
router.post('/remove', (req, res, next) => cartController.removeItemFromCart(req, res, next));
router.post('/sync', (req, res, next) => cartController.syncCart(req, res, next));
router.post('/clear', (req, res, next) => cartController.clearCart(req, res, next));

module.exports = router;
