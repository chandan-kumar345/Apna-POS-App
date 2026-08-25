const orderService = require('../services/orderService');
const ApiResponse = require('../utils/ApiResponse');

class OrderController {
  async createOrder(req, res, next) {
    try {
      const result = await orderService.generatePosOrder(req.businessId, req.body);
      const order = result.order || result;
      const statusCode = result.isExisting ? 200 : 201;
      return ApiResponse.success(
        res,
        { ...result, order },
        result.message || 'Order created successfully',
        statusCode
      );
    } catch (error) {
      next(error);
    }
  }

  async generatePosOrder(req, res, next) {
    try {
      const result = await orderService.generatePosOrder(req.businessId, req.body);
      const statusCode = result.isExisting ? 200 : 201;
      return ApiResponse.success(
        res,
        result,
        result.message || 'POS Order generated successfully',
        statusCode
      );
    } catch (error) {
      next(error);
    }
  }

  async getOrders(req, res, next) {
    try {
      const result = await orderService.getOrders(req.businessId, req.query);
      return ApiResponse.success(res, result, 'Orders fetched successfully');
    } catch (error) {
      next(error);
    }
  }

  async getOrderById(req, res, next) {
    try {
      const order = await orderService.getOrderById(req.businessId, req.params.id);
      return ApiResponse.success(res, { order });
    } catch (error) {
      next(error);
    }
  }

  async updateStatus(req, res, next) {
    try {
      const order = await orderService.updateOrderStatus(
        req.businessId,
        req.params.id,
        req.body.status,
        { reason: req.body.reason }
      );
      return ApiResponse.success(res, { order }, 'Order status updated');
    } catch (error) {
      next(error);
    }
  }

  async payOrder(req, res, next) {
    try {
      const result = await orderService.payOrder(req.businessId, req.params.id, req.body);
      return ApiResponse.success(res, result, 'Order settled and payment completed');
    } catch (error) {
      next(error);
    }
  }

  async saveAndPrint(req, res, next) {
    try {
      const result = await orderService.saveAndPrintOrder(req.businessId, req.body);
      return ApiResponse.success(
        res,
        result,
        'Order saved and invoice print snapshot generated successfully',
        200
      );
    } catch (error) {
      next(error);
    }
  }

  async settleOrder(req, res, next) {
    try {
      const result = await orderService.settleOrder(req.businessId, req.params.id, req.body);
      return ApiResponse.success(
        res,
        result,
        result.message || 'Order settled successfully',
        200
      );
    } catch (error) {
      next(error);
    }
  }

  async getTableOrder(req, res, next) {
    try {
      const order = await orderService.getActiveTableOrder(req.businessId, req.params.tableNumber);
      return ApiResponse.success(res, { order });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new OrderController();
