const express = require('express');
const multer = require('multer');
const uploadController = require('../controllers/uploadController');
const authMiddleware = require('../middleware/authMiddleware');
const ApiError = require('../utils/ApiError');

const router = express.Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 5 * 1024 * 1024, // 5MB maximum image size
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new ApiError(400, 'Only image files (JPEG, PNG, WEBP, etc.) are allowed!'), false);
    }
  },
});

const uploadVideoMulter = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 100 * 1024 * 1024, // 100MB maximum video size
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('video/') || file.originalname.match(/\.(mp4|mov|webm|avi|mkv)$/i)) {
      cb(null, true);
    } else {
      cb(new ApiError(400, 'Only video files (MP4, WEBM, MOV, MKV, etc.) are allowed!'), false);
    }
  },
});

const uploadAudioMulter = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 15 * 1024 * 1024, // 15MB maximum audio size
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('audio/') || file.originalname.match(/\.(mp3|wav|m4a|aac|ogg|opus|flac)$/i)) {
      cb(null, true);
    } else {
      cb(new ApiError(400, 'Only audio files (MP3, WAV, M4A, AAC, OGG) are allowed!'), false);
    }
  },
});

const optionalAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authMiddleware(req, res, next);
  }
  next();
};

router.use(optionalAuth);

router.post('/image', upload.single('image'), (req, res, next) =>
  uploadController.uploadImage(req, res, next)
);

router.post('/video', uploadVideoMulter.single('video'), (req, res, next) =>
  uploadController.uploadVideo(req, res, next)
);

router.post('/audio', uploadAudioMulter.single('audio'), (req, res, next) =>
  uploadController.uploadAudio(req, res, next)
);

module.exports = router;
