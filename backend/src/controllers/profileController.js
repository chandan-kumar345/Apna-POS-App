const Business = require('../models/Business');
const ApiResponse = require('../utils/ApiResponse');

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
}

module.exports = new ProfileController();
