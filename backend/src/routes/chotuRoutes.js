const express = require('express');
const chotuController = require('../controllers/chotuController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

// All Chotu routes require POS authentication
router.use(authMiddleware);

// Chotu Subsystem Health
router.get('/health', (req, res, next) => chotuController.health(req, res, next));

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
