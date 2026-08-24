const salesService = require('../services/salesService');
const ApiResponse = require('../utils/ApiResponse');

class SalesController {
  async getSales(req, res, next) {
    try {
      const result = await salesService.getSales(req.businessId, req.query);
      return ApiResponse.success(res, result, 'Sales history fetched');
    } catch (error) {
      next(error);
    }
  }

  async getSummary(req, res, next) {
    try {
      const summary = await salesService.getSalesSummary(req.businessId, req.query);
      return ApiResponse.success(res, { summary });
    } catch (error) {
      next(error);
    }
  }

  async getReport(req, res, next) {
    try {
      const report = await salesService.getSalesReport(req.businessId, req.query);
      return ApiResponse.success(res, report, 'Sales report fetched successfully');
    } catch (error) {
      next(error);
    }
  }

  async getTopProducts(req, res, next) {
    try {
      const topProducts = await salesService.getTopSellingProducts(req.businessId, req.query);
      return ApiResponse.success(res, { topProducts });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new SalesController();
