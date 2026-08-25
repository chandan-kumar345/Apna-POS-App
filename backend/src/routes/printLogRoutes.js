const express = require('express');
const printLogController = require('../controllers/printLogController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.use(authMiddleware);

router.get('/', (req, res, next) => printLogController.getPrintLogs(req, res, next));
router.get('/:id', (req, res, next) => printLogController.getPrintLogById(req, res, next));
router.post('/:id/reprint', (req, res, next) => printLogController.reprintLog(req, res, next));

module.exports = router;
