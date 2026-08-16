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

router.use(authMiddleware);

router.post('/image', upload.single('image'), (req, res, next) =>
  uploadController.uploadImage(req, res, next)
);

module.exports = router;
