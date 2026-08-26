const loyaltyService = require('../services/loyaltyService');
const ApiResponse = require('../utils/ApiResponse');

class LoyaltyController {
  async getPrograms(req, res, next) {
    try {
      const data = await loyaltyService.getLoyaltyPrograms(req.businessId);
      return ApiResponse.success(res, data, 'Loyalty programs fetched successfully');
    } catch (error) {
      next(error);
    }
  }

  async getPerformance(req, res, next) {
    try {
      const data = await loyaltyService.getLoyaltyPerformance(req.businessId);
      return ApiResponse.success(res, data, 'Loyalty performance fetched successfully');
    } catch (error) {
      next(error);
    }
  }

  async updateProgram(req, res, next) {
    try {
      const programData = { ...req.body, id: req.params.id || req.body.id };
      const data = await loyaltyService.updateLoyaltyProgram(req.businessId, programData);
      return ApiResponse.success(res, data, 'Loyalty program updated successfully');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new LoyaltyController();
