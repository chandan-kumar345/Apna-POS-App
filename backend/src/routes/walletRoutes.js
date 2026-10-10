const express = require('express');
const walletController = require('../controllers/walletController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

// All wallet endpoints require authenticated business session
router.use(authMiddleware);

// Get wallet balance and eBill fee
router.get('/balance', (req, res, next) => walletController.getBalance(req, res, next));

// Recharge wallet balance
router.post('/recharge', (req, res, next) => walletController.recharge(req, res, next));

// Transaction ledger
router.get('/transactions', (req, res, next) => walletController.getTransactions(req, res, next));

module.exports = router;
