const express = require('express');
const subscriptionController = require('../controllers/subscriptionController');
const tokenService = require('../services/tokenService');
const User = require('../models/User');
const Business = require('../models/Business');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

/**
 * Optional Auth Middleware: Extracts user/business if token is present, but doesn't throw if missing
 */
const optionalAuthMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      if (token) {
        const decoded = tokenService.verifyAccessToken(token);
        if (decoded && decoded.sub) {
          const user = await User.findById(decoded.sub);
          if (user) {
            req.user = user;
            const business = await Business.findOne({ ownerId: user._id });
            if (business) {
              req.business = business;
              req.businessId = business._id;
            }
          }
        }
      }
    }
  } catch (_) {
    // Non-blocking for optional auth
  }
  next();
};

// 1. Get Subscription Plans & Feature Comparison
router.get('/plans', (req, res, next) => subscriptionController.getPlans(req, res, next));

// 2. Submit Lead / "I'm Interested" Request (Sends Email to sooftcode@gmail.com)
router.post('/lead', optionalAuthMiddleware, (req, res, next) => subscriptionController.createLead(req, res, next));

// 3. Get Leads for Admin Review
router.get('/leads', authMiddleware, (req, res, next) => subscriptionController.getLeads(req, res, next));

// 4. Test SMTP / Email Connection Status
router.get('/test-email', (req, res, next) => subscriptionController.testEmail(req, res, next));

module.exports = router;
