const express = require('express');
const chotuController = require('../controllers/chotuController');
const authMiddleware = require('../middleware/authMiddleware');
const { requirePermission } = require('../middleware/permissionMiddleware');

const router = express.Router();

// All Chotu routes require POS authentication
router.use(authMiddleware);
router.use(requirePermission('pos'));
router.use(require('../middleware/entitlementMiddleware').chotu);

// Chotu Subsystem Health
router.get('/health', (req, res, next) => chotuController.health(req, res, next));

// Stateful Python order agent. Existing parse/execute endpoints stay compatible.
router.post('/agent/turn', (req, res, next) => chotuController.agentTurn(req, res, next));
router.get('/agent/sessions/:sessionId', (req, res, next) => chotuController.agentSession(req, res, next));

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
