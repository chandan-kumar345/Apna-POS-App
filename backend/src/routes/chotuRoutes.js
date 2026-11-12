const express = require('express');
const chotuController = require('../controllers/chotuController');
const authMiddleware = require('../middleware/authMiddleware');
const { requirePermission } = require('../middleware/permissionMiddleware');
const tokenService = require('../services/tokenService');
const User = require('../models/User');
const ApiError = require('../utils/ApiError');

const router = express.Router();

// The general POS middleware permits terminal/business-session fallbacks.
// An order agent requires an actual verified actor, including in single-store mode.
router.use('/agent', async (req, res, next) => {
  try {
    const match = (req.headers.authorization || '').match(/^Bearer\s+(\S+)$/);
    if (!match) throw ApiError.unauthorized('A valid Bearer token is required for Chotu automation.');
    const decoded = tokenService.verifyAccessToken(match[1]);
    if (!decoded.sub || !await User.exists({ _id: decoded.sub })) throw ApiError.unauthorized('Authenticated user no longer exists.');
    req.chotuVerifiedSubject = String(decoded.sub);
    next();
  } catch (error) {
    next(error);
  }
});

// All Chotu routes require POS authentication
router.use(authMiddleware);
router.use('/agent', (req, res, next) => {
  if (String(req.user?._id) !== req.chotuVerifiedSubject) return next(ApiError.unauthorized('Verified actor does not match the POS session.'));
  next();
});

// Chotu Subsystem Health
router.get('/health', (req, res, next) => chotuController.health(req, res, next));

// Stateful Python order agent. Existing parse/execute endpoints stay compatible.
router.post('/agent/turn', requirePermission('pos'), (req, res, next) => chotuController.agentTurn(req, res, next));
router.get('/agent/sessions/:sessionId', requirePermission('pos'), (req, res, next) => chotuController.agentSession(req, res, next));

// Speech-To-Text Transcription (Phase 1)
router.post('/transcribe', (req, res, next) => chotuController.transcribe(req, res, next));

// Natural Voice Command Parsing & NLU (Phase 2 & 3)
router.post('/parse', (req, res, next) => chotuController.parse(req, res, next));

// Structured Command Execution via POS Services (Phase 3)
router.post('/execute', (req, res, next) => chotuController.execute(req, res, next));

// Product Alias Management
router.put('/products/:id/aliases', (req, res, next) => chotuController.updateProductAliases(req, res, next));

// Audit Logs
router.get('/logs', (req, res, next) => chotuController.getLogs(req, res, next));

module.exports = router;
