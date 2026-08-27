const crmService = require('../services/crmService');
const ApiResponse = require('../utils/ApiResponse');

class CrmController {
  async getLeads(req, res, next) {
    try {
      const data = await crmService.getLeads(req.businessId, req.query);
      return ApiResponse.success(res, data, 'Leads fetched successfully');
    } catch (err) {
      next(err);
    }
  }

  async getStats(req, res, next) {
    try {
      const stats = await crmService.getLeadStats(req.businessId);
      return ApiResponse.success(res, stats, 'Lead statistics fetched successfully');
    } catch (err) {
      next(err);
    }
  }

  async getLeadById(req, res, next) {
    try {
      const data = await crmService.getLeadById(req.businessId, req.params.id);
      return ApiResponse.success(res, data, 'Lead details fetched successfully');
    } catch (err) {
      next(err);
    }
  }

  async createLead(req, res, next) {
    try {
      const lead = await crmService.createLead(req.businessId, req.body);
      return ApiResponse.created(res, lead, 'Lead created successfully');
    } catch (err) {
      next(err);
    }
  }

  async updateLead(req, res, next) {
    try {
      const lead = await crmService.updateLead(req.businessId, req.params.id, req.body);
      return ApiResponse.success(res, lead, 'Lead updated successfully');
    } catch (err) {
      next(err);
    }
  }

  async updateStage(req, res, next) {
    try {
      const { stage } = req.body;
      const lead = await crmService.updateLeadStage(req.businessId, req.params.id, stage);
      return ApiResponse.success(res, lead, 'Lead stage updated successfully');
    } catch (err) {
      next(err);
    }
  }

  async setFollowup(req, res, next) {
    try {
      const lead = await crmService.setFollowup(req.businessId, req.params.id, req.body);
      return ApiResponse.success(res, lead, 'Follow-up set successfully');
    } catch (err) {
      next(err);
    }
  }

  async toggleLike(req, res, next) {
    try {
      const lead = await crmService.toggleLike(req.businessId, req.params.id);
      return ApiResponse.success(res, lead, 'Like toggled successfully');
    } catch (err) {
      next(err);
    }
  }

  async toggleStar(req, res, next) {
    try {
      const lead = await crmService.toggleStar(req.businessId, req.params.id);
      return ApiResponse.success(res, lead, 'Star toggled successfully');
    } catch (err) {
      next(err);
    }
  }

  async importLeads(req, res, next) {
    try {
      const result = await crmService.importLeads(req.businessId, req.body.leads || req.body);
      return ApiResponse.success(res, result, 'Leads imported successfully');
    } catch (err) {
      next(err);
    }
  }

  async exportLeads(req, res, next) {
    try {
      const result = await crmService.exportLeads(req.businessId);
      return ApiResponse.success(res, result, 'Leads exported successfully');
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new CrmController();
