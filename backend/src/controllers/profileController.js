const Business = require('../models/Business');
const ApiResponse = require('../utils/ApiResponse');
const ApiError = require('../utils/ApiError');

class ProfileController {
  async getProfile(req, res, next) {
    try {
      const business = await Business.findOne({ ownerId: req.user._id });
      return ApiResponse.success(
        res,
        {
          user: req.user,
          business: business || null,
        },
        'Profile retrieved'
      );
    } catch (error) {
      next(error);
    }
  }

  async updatePosSettings(req, res, next) {
    try {
      const { posViewMode } = req.body;
      if (posViewMode && !['with_image', 'without_image'].includes(posViewMode)) {
        throw ApiError.badRequest("posViewMode must be either 'with_image' or 'without_image'");
      }

      const business = await Business.findOneAndUpdate(
        { ownerId: req.user._id },
        { $set: { 'orderSettings.posViewMode': posViewMode } },
        { new: true, upsert: true }
      );

      return ApiResponse.success(res, { business }, 'POS view setting updated successfully');
    } catch (error) {
      next(error);
    }
  }

  async updateSettings(req, res, next) {
    try {
      const allowedUpdates = {};
      if (req.body.name) allowedUpdates['profile.companyName'] = req.body.name;
      if (req.body.tagline) allowedUpdates['profile.tagline'] = req.body.tagline;
      if (req.body.phone) allowedUpdates['profile.phone'] = req.body.phone;
      if (req.body.address) allowedUpdates['address.addressLine'] = req.body.address;
      if (req.body.taxRate !== undefined) allowedUpdates['orderSettings.tax.percentage'] = req.body.taxRate;
      if (req.body.upiId) allowedUpdates['orderSettings.upiId'] = req.body.upiId;
      if (req.body.posViewMode) {
        if (!['with_image', 'without_image'].includes(req.body.posViewMode)) {
          throw ApiError.badRequest("posViewMode must be either 'with_image' or 'without_image'");
        }
        allowedUpdates['orderSettings.posViewMode'] = req.body.posViewMode;
      }

      const business = await Business.findOneAndUpdate(
        { ownerId: req.user._id },
        { $set: allowedUpdates },
        { new: true, upsert: true }
      );

      return ApiResponse.success(res, { business }, 'Settings updated successfully');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new ProfileController();
