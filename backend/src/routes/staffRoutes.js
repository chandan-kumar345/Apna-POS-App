const express = require('express');
const staffController = require('../controllers/staffController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.use(authMiddleware);

router.get('/', (req, res, next) => staffController.getStaff(req, res, next));
router.get('/stats', (req, res, next) => staffController.getStats(req, res, next));
router.get('/:id', (req, res, next) => staffController.getStaffById(req, res, next));
router.post('/', (req, res, next) => staffController.createStaff(req, res, next));
router.put('/:id', (req, res, next) => staffController.updateStaff(req, res, next));
router.patch('/:id', (req, res, next) => staffController.updateStaff(req, res, next));
router.patch('/:id/status', (req, res, next) => staffController.toggleStatus(req, res, next));
router.delete('/:id', (req, res, next) => staffController.deleteStaff(req, res, next));

module.exports = router;
