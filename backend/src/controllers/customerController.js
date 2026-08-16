const customerService = require('../services/customerService');
const ApiResponse = require('../utils/ApiResponse');

class CustomerController {
  async getCustomers(req, res, next) {
    try {
      const result = await customerService.getCustomers(req.businessId, req.query);
      return ApiResponse.success(res, result, 'Customers fetched');
    } catch (error) {
      next(error);
    }
  }

  async createOrUpdate(req, res, next) {
    try {
      const customer = await customerService.createOrUpdateCustomer(req.businessId, req.body);
      return ApiResponse.success(res, { customer }, 'Customer profile saved');
    } catch (error) {
      next(error);
    }
  }

  async getByPhone(req, res, next) {
    try {
      const customer = await customerService.getCustomerByPhone(req.businessId, req.params.phone);
      return ApiResponse.success(res, { customer });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new CustomerController();
