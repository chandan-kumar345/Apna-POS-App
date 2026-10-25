const express = require('express');
const storefrontController = require('../controllers/storefrontController');

const router = express.Router();

// Public storefront routes (no auth required so customers can browse & order)
router.get('/:slug', (req, res, next) => storefrontController.getStorefront(req, res, next));
router.post('/:slug/order', (req, res, next) => storefrontController.createStorefrontOrder(req, res, next));

module.exports = router;
