const couponService = require('../services/couponService');

class CouponController {
  async createCoupon(req, res, next) {
    try {
      const businessId = req.businessId || req.user?.businessId;
      const coupon = await couponService.createCoupon(businessId, req.body);
      return res.status(201).json({
        success: true,
        message: 'Coupon created successfully',
        data: coupon,
      });
    } catch (err) {
      next(err);
    }
  }

  async getCoupons(req, res, next) {
    try {
      const businessId = req.businessId || req.user?.businessId;
      const result = await couponService.getCoupons(businessId, req.query);
      return res.status(200).json({
        success: true,
        message: 'Coupons fetched successfully',
        data: result,
        coupons: result.coupons,
        pagination: result.pagination,
      });
    } catch (err) {
      next(err);
    }
  }

  async getCouponById(req, res, next) {
    try {
      const businessId = req.businessId || req.user?.businessId;
      const coupon = await couponService.getCouponById(businessId, req.params.id);
      return res.status(200).json({
        success: true,
        message: 'Coupon fetched successfully',
        data: coupon,
      });
    } catch (err) {
      next(err);
    }
  }

  async updateCoupon(req, res, next) {
    try {
      const businessId = req.businessId || req.user?.businessId;
      const coupon = await couponService.updateCoupon(businessId, req.params.id, req.body);
      return res.status(200).json({
        success: true,
        message: 'Coupon updated successfully',
        data: coupon,
      });
    } catch (err) {
      next(err);
    }
  }

  async toggleCoupon(req, res, next) {
    try {
      const businessId = req.businessId || req.user?.businessId;
      const coupon = await couponService.toggleCouponStatus(businessId, req.params.id);
      return res.status(200).json({
        success: true,
        message: `Coupon ${coupon.isActive ? 'activated' : 'deactivated'} successfully`,
        data: coupon,
      });
    } catch (err) {
      next(err);
    }
  }

  async deleteCoupon(req, res, next) {
    try {
      const businessId = req.businessId || req.user?.businessId;
      const result = await couponService.deleteCoupon(businessId, req.params.id);
      return res.status(200).json({
        success: true,
        message: 'Coupon deleted successfully',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async validateCoupon(req, res, next) {
    try {
      const businessId = req.businessId || req.user?.businessId;
      const result = await couponService.validateCoupon(businessId, req.body);
      return res.status(200).json({
        success: result.valid,
        message: result.message,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async getRedemptions(req, res, next) {
    try {
      const businessId = req.businessId || req.user?.businessId;
      const result = await couponService.getRedemptionReports(businessId, req.query);
      return res.status(200).json({
        success: true,
        message: 'Coupon redemptions fetched successfully',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new CouponController();
