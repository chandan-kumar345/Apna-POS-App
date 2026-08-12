const express = require('express');
const { body, param } = require('express-validator');
const router = express.Router();
const authController = require('../controllers/authController');
const { protect } = require('../middleware/authMiddleware');
const { validate } = require('../middleware/validateMiddleware');

// Public Auth Routes

// POST /api/auth/register
router.post(
  '/register',
  [
    body('name').notEmpty().withMessage('Name is required'),
    body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters long'),
    body('email').optional({ checkFalsy: true }).isEmail().withMessage('Please provide a valid email'),
    body('phone').optional({ checkFalsy: true }).isMobilePhone().withMessage('Please provide a valid mobile number'),
  ],
  validate,
  authController.register
);

// POST /api/auth/login
router.post(
  '/login',
  [
    body('password').notEmpty().withMessage('Password is required'),
  ],
  validate,
  authController.login
);

// POST /api/auth/send-otp
router.post(
  '/send-otp',
  [
    body('phone').notEmpty().withMessage('Mobile number is required'),
  ],
  validate,
  authController.sendOtp
);

// POST /api/auth/verify-otp
router.post(
  '/verify-otp',
  [
    body('phone').notEmpty().withMessage('Mobile number is required'),
    body('otp').isLength({ min: 4, max: 6 }).withMessage('OTP must be 4 to 6 digits'),
  ],
  validate,
  authController.verifyOtp
);

// POST /api/auth/refresh-token
router.post(
  '/refresh-token',
  [
    body('refreshToken').notEmpty().withMessage('Refresh token is required'),
  ],
  validate,
  authController.refreshToken
);

// Protected Auth Routes (Require Bearer Access Token)

// GET /api/auth/me
router.get('/me', protect, authController.getMe);

// POST /api/auth/logout
router.post('/logout', protect, authController.logout);

// POST /api/auth/logout-all
router.post('/logout-all', protect, authController.logoutAll);

// GET /api/auth/devices
router.get('/devices', protect, authController.getDevices);

// DELETE /api/auth/devices/:deviceId
router.delete(
  '/devices/:deviceId',
  [
    param('deviceId').notEmpty().withMessage('Device ID is required'),
  ],
  validate,
  protect,
  authController.revokeDevice
);

module.exports = router;
