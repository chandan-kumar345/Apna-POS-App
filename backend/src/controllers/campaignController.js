const campaignService = require('../services/campaignService');
const ApiResponse = require('../utils/ApiResponse');

class CampaignController {
  async getDashboardStats(req, res, next) {
    try {
      const stats = await campaignService.getDashboardStats(req.businessId);
      return ApiResponse.success(res, stats, 'Campaign dashboard metrics retrieved');
    } catch (error) {
      next(error);
    }
  }

  async getCampaigns(req, res, next) {
    try {
      const { type, status, search, page, limit } = req.query;
      const result = await campaignService.getCampaigns(req.businessId, {
        type,
        status,
        search,
        page: page ? parseInt(page, 10) : 1,
        limit: limit ? parseInt(limit, 10) : 50,
      });
      return ApiResponse.success(res, result, 'Campaigns retrieved');
    } catch (error) {
      next(error);
    }
  }

  async getCampaignById(req, res, next) {
    try {
      const { id } = req.params;
      const campaign = await campaignService.getCampaignById(req.businessId, id);
      return ApiResponse.success(res, campaign, 'Campaign details retrieved');
    } catch (error) {
      next(error);
    }
  }

  async createCampaign(req, res, next) {
    try {
      const userId = req.user?._id || req.user?.id;
      const campaign = await campaignService.createCampaign(req.businessId, req.body, userId);
      return ApiResponse.created(res, campaign, 'Campaign created and scheduled successfully');
    } catch (error) {
      next(error);
    }
  }

  async pauseCampaign(req, res, next) {
    try {
      const { id } = req.params;
      const campaign = await campaignService.pauseCampaign(req.businessId, id);
      return ApiResponse.success(res, campaign, 'Campaign paused');
    } catch (error) {
      next(error);
    }
  }

  async resumeCampaign(req, res, next) {
    try {
      const { id } = req.params;
      const campaign = await campaignService.resumeCampaign(req.businessId, id);
      return ApiResponse.success(res, campaign, 'Campaign resumed');
    } catch (error) {
      next(error);
    }
  }

  async getTemplates(req, res, next) {
    try {
      const templates = await campaignService.getTemplates(req.businessId);
      return ApiResponse.success(res, templates, 'Campaign templates retrieved');
    } catch (error) {
      next(error);
    }
  }

  async getChannels(req, res, next) {
    try {
      const channels = await campaignService.getChannels(req.businessId);
      return ApiResponse.success(res, channels, 'Campaign sending channels retrieved');
    } catch (error) {
      next(error);
    }
  }

  async getAudienceGroups(req, res, next) {
    try {
      const groups = await campaignService.getAudienceGroups(req.businessId);
      return ApiResponse.success(res, groups, 'Audience customer groups retrieved');
    } catch (error) {
      next(error);
    }
  }

  async getAutoCampaigns(req, res, next) {
    try {
      const list = await campaignService.getAutoCampaigns(req.businessId);
      return ApiResponse.success(res, list, 'Auto campaigns retrieved');
    } catch (error) {
      next(error);
    }
  }

  async createAutoCampaign(req, res, next) {
    try {
      const autoCamp = await campaignService.createAutoCampaign(req.businessId, req.body);
      return ApiResponse.created(res, autoCamp, 'Auto campaign activated successfully');
    } catch (error) {
      next(error);
    }
  }

  async toggleAutoCampaign(req, res, next) {
    try {
      const { id } = req.params;
      const autoCamp = await campaignService.toggleAutoCampaign(req.businessId, id);
      return ApiResponse.success(res, autoCamp, 'Auto campaign status updated');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new CampaignController();
