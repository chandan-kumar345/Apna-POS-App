const storageService = require('../utils/storageService');
const ApiResponse = require('../utils/ApiResponse');
const ApiError = require('../utils/ApiError');

class UploadController {
  async uploadImage(req, res, next) {
    try {
      if (!req.file) {
        throw ApiError.badRequest('Please upload an image file');
      }

      const folder = req.query.folder || 'products';
      const allowedFolders = ['products', 'profiles', 'outlets', 'receipts'];
      const targetFolder = allowedFolders.includes(folder) ? folder : 'products';

      let imageUrl = await storageService.uploadImage(
        req.file.buffer,
        req.file.originalname,
        req.file.mimetype,
        targetFolder
      );

      if (imageUrl && imageUrl.startsWith('/')) {
        const host = req.get('host');
        const proto = (req.headers['x-forwarded-proto'] || req.protocol || 'http').split(',')[0].trim();
        imageUrl = `${proto}://${host}${imageUrl}`;
      }

      return ApiResponse.success(
        res,
        { imageUrl, folder: targetFolder, fileName: req.file.originalname },
        'Image uploaded successfully',
        201
      );
    } catch (error) {
      next(error);
    }
  }

  async uploadVideo(req, res, next) {
    try {
      if (!req.file) {
        throw ApiError.badRequest('Please upload a video file');
      }

      const folder = req.query.folder || 'products/videos';
      let videoUrl = await storageService.uploadMedia(
        req.file.buffer,
        req.file.originalname,
        req.file.mimetype,
        folder
      );

      if (videoUrl && videoUrl.startsWith('/')) {
        const host = req.get('host');
        const proto = (req.headers['x-forwarded-proto'] || req.protocol || 'http').split(',')[0].trim();
        videoUrl = `${proto}://${host}${videoUrl}`;
      }

      return ApiResponse.success(
        res,
        { videoUrl, folder, fileName: req.file.originalname },
        'Video uploaded successfully',
        201
      );
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new UploadController();
