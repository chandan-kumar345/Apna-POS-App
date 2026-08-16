const dashboardService = require('../services/dashboardService');
const ApiResponse = require('../utils/ApiResponse');

class DashboardController {
  async getSummary(req, res, next) {
    try {
      const summary = await dashboardService.getSummary(req.businessId, req.query);
      return ApiResponse.success(res, { summary }, 'Dashboard summary fetched');
    } catch (error) {
      next(error);
    }
  }

  async getChart(req, res, next) {
    try {
      const chartPoints = await dashboardService.getChartData(req.businessId, req.query);
      return ApiResponse.success(res, { chartPoints }, 'Chart data fetched');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new DashboardController();
