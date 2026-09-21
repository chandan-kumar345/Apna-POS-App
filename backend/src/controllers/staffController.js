const staffService = require('../services/staffService');
const ApiResponse = require('../utils/ApiResponse');

class StaffController {
  async getStaff(req, res, next) {
    try {
      const data = await staffService.getStaff(req.businessId, req.query);
      return ApiResponse.success(res, data, 'Staff members fetched successfully');
    } catch (err) {
      next(err);
    }
  }

  async getStats(req, res, next) {
    try {
      const stats = await staffService.getStaffStats(req.businessId);
      return ApiResponse.success(res, stats, 'Staff statistics fetched successfully');
    } catch (err) {
      next(err);
    }
  }

  async getStaffById(req, res, next) {
    try {
      const data = await staffService.getStaffById(req.businessId, req.params.id);
      return ApiResponse.success(res, data, 'Staff details fetched successfully');
    } catch (err) {
      next(err);
    }
  }

  async createStaff(req, res, next) {
    try {
      const staff = await staffService.createStaff(req.businessId, req.body);
      return ApiResponse.created(res, staff, 'Staff member created successfully');
    } catch (err) {
      next(err);
    }
  }

  async updateStaff(req, res, next) {
    try {
      const staff = await staffService.updateStaff(req.businessId, req.params.id, req.body);
      return ApiResponse.success(res, staff, 'Staff member updated successfully');
    } catch (err) {
      next(err);
    }
  }

  async toggleStatus(req, res, next) {
    try {
      const staff = await staffService.toggleStaffStatus(req.businessId, req.params.id);
      return ApiResponse.success(res, staff, 'Staff status toggled successfully');
    } catch (err) {
      next(err);
    }
  }

  async deleteStaff(req, res, next) {
    try {
      const result = await staffService.deleteStaff(req.businessId, req.params.id);
      return ApiResponse.success(res, result, 'Staff member deleted successfully');
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new StaffController();
