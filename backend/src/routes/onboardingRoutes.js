const express = require('express');
const onboardingController = require('../controllers/onboardingController');
const authMiddleware = require('../middleware/authMiddleware');
const validate = require('../middleware/validationMiddleware');
const {
  profileSchema,
  businessSchema,
  addressSchema,
  orderSettingsSchema,
} = require('../validators/onboardingValidator');

const router = express.Router();

// All onboarding routes require authentication
router.use(authMiddleware);

// Step 1: Profile
router.patch('/profile', validate(profileSchema), (req, res, next) =>
  onboardingController.saveProfile(req, res, next)
);

// Step 2: Business
router.patch('/business', validate(businessSchema), (req, res, next) =>
  onboardingController.saveBusiness(req, res, next)
);

// Step 3: Address
router.patch('/address', validate(addressSchema), (req, res, next) =>
  onboardingController.saveAddress(req, res, next)
);

// Step 4: Order Settings
router.patch('/order-settings', validate(orderSettingsSchema), (req, res, next) =>
  onboardingController.saveOrderSettings(req, res, next)
);

// Status
router.get('/status', (req, res, next) =>
  onboardingController.getStatus(req, res, next)
);

// Complete Onboarding
router.post('/complete', (req, res, next) =>
  onboardingController.completeOnboarding(req, res, next)
);

module.exports = router;
