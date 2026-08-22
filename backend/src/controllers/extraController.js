const extraService = require('../services/extraService');

class ExtraController {
  async getExtras(req, res, next) {
    try {
      const businessId = req.businessId || req.user?.businessId;
      const { type, search } = req.query;
      const extras = await extraService.getExtras(businessId, { type, search });
      return res.status(200).json({
        success: true,
        data: {
          extras,
          count: extras.length,
        },
      });
    } catch (err) {
      next(err);
    }
  }

  async validateCoupon(req, res, next) {
    try {
      const businessId = req.businessId || req.user?.businessId;
      const { code, subtotal } = req.body;
      const result = await extraService.validateCoupon(businessId, { code, subtotal });
      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async createExtra(req, res, next) {
    try {
      const businessId = req.businessId || req.user?.businessId;
      const extra = await extraService.createExtra(businessId, req.body);
      return res.status(201).json({
        success: true,
        data: { extra },
      });
    } catch (err) {
      next(err);
    }
  }

  async updateExtra(req, res, next) {
    try {
      const businessId = req.businessId || req.user?.businessId;
      const extra = await extraService.updateExtra(businessId, req.params.id, req.body);
      return res.status(200).json({
        success: true,
        data: { extra },
      });
    } catch (err) {
      next(err);
    }
  }

  async deleteExtra(req, res, next) {
    try {
      const businessId = req.businessId || req.user?.businessId;
      const result = await extraService.deleteExtra(businessId, req.params.id);
      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new ExtraController();
