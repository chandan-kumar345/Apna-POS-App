const orderService = require('../services/orderService');
const ApiResponse = require('../utils/ApiResponse');

class OrderController {
  async createOrder(req, res, next) {
    try {
      const order = await orderService.createOrder(req.businessId, req.body);
      return ApiResponse.created(res, { order }, 'Order created successfully');
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
      const order = await orderService.updateOrderStatus(req.businessId, req.params.id, req.body.status);
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
