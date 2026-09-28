const superadminService = require('../services/superadminService');
const ApiResponse = require('../utils/ApiResponse');

class SuperadminController {
  // Owner Login
  async login(req, res, next) {
    try {
      const { email, password } = req.body;
      const result = await superadminService.login(email, password);
      res.json(new ApiResponse(true, result, 'Super Admin login successful'));
    } catch (error) {
      next(error);
    }
  }

  // Current Owner Profile
  async getMe(req, res, next) {
    try {
      const user = req.user;
      res.json(
        new ApiResponse(
          true,
          {
            id: user._id,
            email: user.email,
            role: user.role,
            isSuperAdmin: true,
            status: user.status,
          },
          'Owner profile retrieved'
        )
      );
    } catch (error) {
      next(error);
    }
  }

  // Platform Dashboard Metrics
  async getStats(req, res, next) {
    try {
      const stats = await superadminService.getPlatformStats();
      res.json(new ApiResponse(true, stats, 'Platform stats retrieved successfully'));
    } catch (error) {
      next(error);
    }
  }

  // Get Users List
  async getUsers(req, res, next) {
    try {
      const { search, status, plan, role, page, limit } = req.query;
      const result = await superadminService.getUsers({
        search,
        status,
        plan,
        role,
        page,
        limit,
      });
      res.json(new ApiResponse(true, result, 'Users retrieved successfully'));
    } catch (error) {
      next(error);
    }
  }

  // Create User & Store
  async createUser(req, res, next) {
    try {
      const result = await superadminService.createUser(req.body);
      res.status(201).json(new ApiResponse(true, result, 'User & Store created successfully'));
    } catch (error) {
      next(error);
    }
  }

  // Get User Details by ID
  async getUserById(req, res, next) {
    try {
      const result = await superadminService.getUserById(req.params.id);
      res.json(new ApiResponse(true, result, 'User details retrieved successfully'));
    } catch (error) {
      next(error);
    }
  }

  // Update User & Store
  async updateUser(req, res, next) {
    try {
      const result = await superadminService.updateUser(req.params.id, req.body);
      res.json(new ApiResponse(true, result, 'User updated successfully'));
    } catch (error) {
      next(error);
    }
  }

  // Toggle/Set User Active/Inactive/Suspended Status
  async updateUserStatus(req, res, next) {
    try {
      const { status } = req.body;
      const result = await superadminService.updateUserStatus(req.params.id, status);
      res.json(new ApiResponse(true, result, `User status updated to ${status}`));
    } catch (error) {
      next(error);
    }
  }

  // Update Subscription Details
  async updateUserSubscription(req, res, next) {
    try {
      const result = await superadminService.updateUserSubscription(req.params.id, req.body);
      res.json(new ApiResponse(true, result, 'Subscription updated successfully'));
    } catch (error) {
      next(error);
    }
  }

  // Admin Reset User Password
  async resetUserPassword(req, res, next) {
    try {
      const { password } = req.body;
      const result = await superadminService.resetUserPassword(req.params.id, password);
      res.json(new ApiResponse(true, result, result.message));
    } catch (error) {
      next(error);
    }
  }

  // Delete User and Associated Store Data
  async deleteUser(req, res, next) {
    try {
      const result = await superadminService.deleteUser(req.params.id);
      res.json(new ApiResponse(true, result, result.message));
    } catch (error) {
      next(error);
    }
  }

  // Database Overview
  async getDatabaseOverview(req, res, next) {
    try {
      const overview = await superadminService.getDatabaseOverview();
      res.json(new ApiResponse(true, overview, 'Database overview retrieved successfully'));
    } catch (error) {
      next(error);
    }
  }

  // Inspect Collection Documents
  async getCollectionDocuments(req, res, next) {
    try {
      const { collectionName } = req.params;
      const { page, limit, search } = req.query;
      const result = await superadminService.getCollectionDocuments(collectionName, { page, limit, search });
      res.json(new ApiResponse(true, result, `Collection ${collectionName} documents retrieved`));
    } catch (error) {
      next(error);
    }
  }

  // Get Subscription Leads
  async getLeads(req, res, next) {
    try {
      const { status, page, limit, search } = req.query;
      const result = await superadminService.getLeads({ status, page, limit, search });
      res.json(new ApiResponse(true, result, 'Subscription leads retrieved successfully'));
    } catch (error) {
      next(error);
    }
  }

  // Update Subscription Lead
  async updateLead(req, res, next) {
    try {
      const result = await superadminService.updateLead(req.params.id, req.body);
      res.json(new ApiResponse(true, result, 'Lead updated successfully'));
    } catch (error) {
      next(error);
    }
  }

  // Delete Lead
  async deleteLead(req, res, next) {
    try {
      const result = await superadminService.deleteLead(req.params.id);
      res.json(new ApiResponse(true, result, 'Lead deleted successfully'));
    } catch (error) {
      next(error);
    }
  }

  // Get Store / User Sales Report with Staff Segregation
  async getUserSales(req, res, next) {
    try {
      const result = await superadminService.getUserSalesReport(req.params.id, req.query);
      res.json(new ApiResponse(true, result, 'Store sales report with staff segregation retrieved successfully'));
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new SuperadminController();
