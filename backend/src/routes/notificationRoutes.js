const express = require('express');
const notificationController = require('../controllers/notificationController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

// All notification routes are protected
router.use(authMiddleware);

router.get('/', (req, res, next) => notificationController.getNotifications(req, res, next));
router.get('/unread-count', (req, res, next) => notificationController.getUnreadCount(req, res, next));
router.patch('/read-all', (req, res, next) => notificationController.markAllAsRead(req, res, next));
router.patch('/:id/read', (req, res, next) => notificationController.markAsRead(req, res, next));
router.delete('/clear-all', (req, res, next) => notificationController.clearAll(req, res, next));
router.delete('/:id', (req, res, next) => notificationController.deleteNotification(req, res, next));
router.post('/device-token', (req, res, next) => notificationController.registerDeviceToken(req, res, next));
router.post('/trigger-daily-summary', (req, res, next) => notificationController.triggerDailySummary(req, res, next));

module.exports = router;
