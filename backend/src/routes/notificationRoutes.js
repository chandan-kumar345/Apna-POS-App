const express = require('express');
const multer = require('multer');
const notificationController = require('../controllers/notificationController');
const authMiddleware = require('../middleware/authMiddleware');
const ApiError = require('../utils/ApiError');

const router = express.Router();

const audioUpload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 15 * 1024 * 1024, // 15MB max audio file size
  },
  fileFilter: (req, file, cb) => {
    if (
      file.mimetype.startsWith('audio/') ||
      file.originalname.match(/\.(mp3|wav|m4a|aac|ogg|opus|flac)$/i)
    ) {
      cb(null, true);
    } else {
      cb(new ApiError(400, 'Only audio files (MP3, WAV, M4A, AAC, OGG) are allowed!'), false);
    }
  },
});

// All notification routes are protected
router.use(authMiddleware);

// User-isolated & business-isolated notification & ringtone settings
router.get('/settings', (req, res, next) => notificationController.getSettings(req, res, next));
router.put('/settings', (req, res, next) => notificationController.updateSettings(req, res, next));
router.post('/upload-ringtone', audioUpload.single('audio'), (req, res, next) => notificationController.uploadRingtone(req, res, next));
router.delete('/custom-ringtone/:id', (req, res, next) => notificationController.deleteCustomRingtone(req, res, next));

router.get('/', (req, res, next) => notificationController.getNotifications(req, res, next));
router.get('/unread-count', (req, res, next) => notificationController.getUnreadCount(req, res, next));
router.patch('/read-all', (req, res, next) => notificationController.markAllAsRead(req, res, next));
router.patch('/:id/read', (req, res, next) => notificationController.markAsRead(req, res, next));
router.delete('/clear-all', (req, res, next) => notificationController.clearAll(req, res, next));
router.delete('/:id', (req, res, next) => notificationController.deleteNotification(req, res, next));
router.post('/device-token', (req, res, next) => notificationController.registerDeviceToken(req, res, next));
router.post('/trigger-daily-summary', (req, res, next) => notificationController.triggerDailySummary(req, res, next));

module.exports = router;
