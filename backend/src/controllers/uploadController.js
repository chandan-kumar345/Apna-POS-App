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

      const imageUrl = await storageService.uploadImage(
        req.file.buffer,
        req.file.originalname,
        req.file.mimetype,
        targetFolder
      );

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
}

module.exports = new UploadController();
