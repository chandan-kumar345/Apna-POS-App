const loyaltyService = require('../services/loyaltyService');

class LoyaltyController {
  _getBusinessId(req) {
    return req.businessId || req.business?._id || req.user?.businessId;
  }

  async getPrograms(req, res, next) {
    try {
      const businessId = this._getBusinessId(req);
      const data = await loyaltyService.getLoyaltyPrograms(businessId);
      res.json({
        success: true,
        data,
      });
    } catch (err) {
      next(err);
    }
  }

  async getVisitConfig(req, res, next) {
    try {
      const businessId = this._getBusinessId(req);
      const config = await loyaltyService.getVisitConfig(businessId);
      res.json({
        success: true,
        data: config,
      });
    } catch (err) {
      next(err);
    }
  }

  async saveVisitConfig(req, res, next) {
    try {
      const businessId = this._getBusinessId(req);
      const configData = req.body;
      const savedConfig = await loyaltyService.saveVisitConfig(businessId, configData);
      res.json({
        success: true,
        message: 'Loyalty configuration saved successfully',
        data: savedConfig,
      });
    } catch (err) {
      next(err);
    }
  }

  async getCustomerLoyalty(req, res, next) {
    try {
      const businessId = this._getBusinessId(req);
      const { phone } = req.params;
      const { name } = req.query;
      const data = await loyaltyService.getCustomerLoyalty(businessId, phone, name);
      res.json({
        success: true,
        data,
      });
    } catch (err) {
      next(err);
    }
  }

  async awardPoints(req, res, next) {
    try {
      const businessId = this._getBusinessId(req);
      const { order } = req.body;
      const result = await loyaltyService.awardPointsForCompletedOrder(businessId, order);
      res.json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async sendOtp(req, res, next) {
    try {
      const businessId = this._getBusinessId(req);
      const { phone, stageId } = req.body;
      const result = await loyaltyService.sendLoyaltyRedemptionOtp(businessId, phone, stageId);
      res.json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async verifyOtp(req, res, next) {
    try {
      const businessId = this._getBusinessId(req);
      const { phone, otp } = req.body;
      const result = await loyaltyService.verifyLoyaltyRedemptionOtp(businessId, phone, otp);
      res.json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async redeemPoints(req, res, next) {
    try {
      const businessId = this._getBusinessId(req);
      const { phone, orderId, stageId, discountAmount, pointsToRedeem, orderNumber } = req.body;
      const result = await loyaltyService.redeemLoyaltyPoints(
        businessId,
        phone,
        orderId,
        stageId,
        discountAmount,
        pointsToRedeem,
        orderNumber
      );
      res.json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async getPerformance(req, res, next) {
    try {
      const businessId = this._getBusinessId(req);
      const data = await loyaltyService.getLoyaltyPerformance(businessId);
      res.json({
        success: true,
        data,
      });
    } catch (err) {
      next(err);
    }
  }

  async updateProgram(req, res, next) {
    try {
      const businessId = this._getBusinessId(req);
      const programData = req.body;
      const result = await loyaltyService.updateLoyaltyProgram(businessId, programData);
      res.json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new LoyaltyController();
