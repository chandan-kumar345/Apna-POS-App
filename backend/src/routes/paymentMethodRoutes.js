const express = require('express');
const authMiddleware = require('../middleware/authMiddleware');
const ApiResponse = require('../utils/ApiResponse');

const router = express.Router();

router.use(authMiddleware);

// Get available active payment methods
router.get('/', (req, res) => {
  const methods = [
    { id: 'cash', name: 'Cash', icon: 'money', isActive: true },
    { id: 'upi', name: 'UPI', icon: 'qr_code', isActive: true },
    { id: 'card', name: 'Card', icon: 'credit_card', isActive: true },
    { id: 'split', name: 'Split', icon: 'call_split', isActive: true },
  ];

  return ApiResponse.success(res, { paymentMethods: methods }, 'Payment methods fetched');
});

module.exports = router;
