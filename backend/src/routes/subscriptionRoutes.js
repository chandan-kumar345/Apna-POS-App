const express = require('express');
const subscriptionController = require('../controllers/subscriptionController');
const tokenService = require('../services/tokenService');
const User = require('../models/User');
const Business = require('../models/Business');
const authMiddleware = require('../middleware/authMiddleware');
const superadmin = require('../middleware/superAdminMiddleware');

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
router.get('/test-email', superadmin, (req, res, next) => subscriptionController.testEmail(req, res, next));

// 5. Get Current Business Subscription Status
router.get('/status', authMiddleware, (req, res, next) => subscriptionController.getStatus(req, res, next));
router.post('/verify', authMiddleware, (req, res, next) => subscriptionController.getStatus(req, res, next));

// 6. Unlock / Activate Subscription via UPI Payment
router.post('/payment-order', authMiddleware, async (req, res, next) => {
  try { res.json({ success: true, data: await require('../services/subscriptionRenewalService').create(req.businessId) }); }
  catch (error) { next(error); }
});
router.post('/activate', authMiddleware, (req, res, next) => subscriptionController.activateSubscription(req, res, next));
router.post('/unlock', authMiddleware, (req, res, next) => subscriptionController.activateSubscription(req, res, next));

// 7. Update Subscription Status directly (e.g. from Compass, SuperAdmin, or API toggle)
router.patch('/status', authMiddleware, superadmin, (req, res, next) => subscriptionController.updateStatus(req, res, next));

// 8. Assign/Activate Subscription for specific staff
router.post('/staff', authMiddleware, superadmin, (req, res, next) => subscriptionController.assignStaffSubscription(req, res, next));

// 9. Get All Subscriptions (for Admin / SuperAdmin)
router.get('/all', superadmin, (req, res, next) => subscriptionController.getAllSubscriptions(req, res, next));

module.exports = router;
