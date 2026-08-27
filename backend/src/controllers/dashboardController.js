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

  async getOrderTypes(req, res, next) {
    try {
      const orderTypes = await dashboardService.getOrderTypes(req.businessId, req.query);
      return ApiResponse.success(res, orderTypes, 'Order types statistics fetched');
    } catch (error) {
      next(error);
    }
  }

  async getProductSales(req, res, next) {
    try {
      const sales = await dashboardService.getProductSales(req.businessId, req.query);
      return ApiResponse.success(res, sales, 'Product sales report fetched');
    } catch (error) {
      next(error);
    }
  }

  async getCustomers(req, res, next) {
    try {
      const customers = await dashboardService.getCustomers(req.businessId, req.query);
      return ApiResponse.success(res, customers, 'Customer analytics fetched');
    } catch (error) {
      next(error);
    }
  }

  async getPaymentMethods(req, res, next) {
    try {
      const payments = await dashboardService.getPaymentMethods(req.businessId, req.query);
      return ApiResponse.success(res, payments, 'Payment methods report fetched');
    } catch (error) {
      next(error);
    }
  }

  async getTaxes(req, res, next) {
    try {
      const taxes = await dashboardService.getTaxes(req.businessId, req.query);
      return ApiResponse.success(res, taxes, 'Tax report fetched');
    } catch (error) {
      next(error);
    }
  }

  async getOrderStats(req, res, next) {
    try {
      const stats = await dashboardService.getOrderStats(req.businessId, req.query);
      return ApiResponse.success(res, stats, 'Order status statistics fetched');
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

  async getOverview(req, res, next) {
    try {
      const overview = await dashboardService.getOverview(req.businessId, req.query);
      return ApiResponse.success(res, overview, 'Dashboard overview fetched');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new DashboardController();
