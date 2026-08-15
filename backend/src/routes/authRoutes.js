const express = require('express');
const authController = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');
const validate = require('../middleware/validationMiddleware');
const {
  registerSchema,
  loginSchema,
  refreshSchema,
  resetPasswordSchema,
} = require('../validators/authValidator');

const router = express.Router();

// Public routes
router.post('/register', validate(registerSchema), (req, res, next) =>
  authController.register(req, res, next)
);

router.post('/login', validate(loginSchema), (req, res, next) =>
  authController.login(req, res, next)
);

router.post('/reset-password', validate(resetPasswordSchema), (req, res, next) =>
  authController.resetPassword(req, res, next)
);

router.post('/refresh', validate(refreshSchema), (req, res, next) =>
  authController.refreshToken(req, res, next)
);

router.post('/refresh-token', validate(refreshSchema), (req, res, next) =>
  authController.refreshToken(req, res, next)
);

router.post('/logout', (req, res, next) =>
  authController.logout(req, res, next)
);

// Protected routes
router.get('/me', authMiddleware, (req, res, next) =>
  authController.getMe(req, res, next)
);

module.exports = router;

