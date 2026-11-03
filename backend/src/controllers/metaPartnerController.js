const metaPartnerService = require('../services/metaPartnerService');
const ApiResponse = require('../utils/ApiResponse');

class MetaPartnerController {
  /**
   * GET /api/v1/meta-partner/status
   */
  async getStatus(req, res, next) {
    try {
      const businessId = req.businessId;
      const userId = req.user?._id || req.user?.id;
      const result = await metaPartnerService.getPartnerStatus(businessId, { userId });
      return ApiResponse.success(res, result, 'Meta Partner status retrieved');
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/meta-partner/connect
   */
  async connect(req, res, next) {
    try {
      const businessId = req.businessId;
      const userId = req.user?._id || req.user?.id;
      const {
        wabaId,
        phoneNumberId,
        phoneNumber,
        accessToken,
        appSecret,
        businessPortfolioId,
        onboardingType,
        verifiedName,
      } = req.body;

      const result = await metaPartnerService.connectPartnerWaba(businessId, {
        wabaId,
        phoneNumberId,
        phoneNumber,
        accessToken,
        appSecret,
        businessPortfolioId,
        onboardingType,
        verifiedName,
        userId,
      });

      return ApiResponse.success(res, result, 'Meta Partner Channel connected successfully');
    } catch (error) {
      next(error);
    }
  }

  /**
   * PUT /api/v1/meta-partner/profile
   */
  async updateProfile(req, res, next) {
    try {
      const businessId = req.businessId;
      const userId = req.user?._id || req.user?.id;
      const { verifiedName, aboutBio, address, email, website } = req.body;

      const result = await metaPartnerService.updatePartnerProfile(businessId, {
        verifiedName,
        aboutBio,
        address,
        email,
        website,
        userId,
      });

      return ApiResponse.success(res, result, 'WhatsApp Business Profile updated successfully');
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/meta-partner/co-manage
   */
  async inviteCoManagement(req, res, next) {
    try {
      const businessId = req.businessId;
      const userId = req.user?._id || req.user?.id;
      const { businessPortfolioId } = req.body;

      const result = await metaPartnerService.inviteCoManagement(businessId, {
        businessPortfolioId,
        userId,
      });

      return ApiResponse.success(res, result, 'Co-Management handshake initiated');
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/meta-partner/disconnect
   */
  async disconnect(req, res, next) {
    try {
      const businessId = req.businessId;
      const userId = req.user?._id || req.user?.id;
      const result = await metaPartnerService.disconnectPartner(businessId, { userId });
      return ApiResponse.success(res, result, 'Meta Partner Channel disconnected');
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/meta-partner/test-message
   */
  async sendTestMessage(req, res, next) {
    try {
      const businessId = req.businessId;
      const userId = req.user?._id || req.user?.id;
      const { recipientPhone, message, templateName } = req.body;

      const result = await metaPartnerService.sendTestMessage(businessId, {
        recipientPhone,
        message,
        templateName,
        userId,
      });

      return ApiResponse.success(res, result, 'Test WhatsApp message sent');
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/v1/meta-partner/templates
   */
  async getTemplates(req, res, next) {
    try {
      const businessId = req.businessId;
      const userId = req.user?._id || req.user?.id;
      const result = await metaPartnerService.getTemplates(businessId, { userId });
      return ApiResponse.success(res, result, 'Meta message templates retrieved');
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/meta-partner/templates/sync
   */
  async syncTemplates(req, res, next) {
    try {
      const businessId = req.businessId;
      const userId = req.user?._id || req.user?.id;
      const result = await metaPartnerService.syncDefaultTemplates(businessId, { userId });
      return ApiResponse.success(res, result, 'Default POS templates synced with Meta');
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/v1/meta-partner/analytics
   */
  async getAnalytics(req, res, next) {
    try {
      const businessId = req.businessId;
      const userId = req.user?._id || req.user?.id;
      const result = await metaPartnerService.getMessagingAnalytics(businessId, { userId });
      return ApiResponse.success(res, result, 'Messaging analytics retrieved');
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/meta-partner/oauth/exchange
   */
  async exchangeOAuth(req, res, next) {
    try {
      const businessId = req.businessId;
      const userId = req.user?._id || req.user?.id;
      const { code, businessPortfolioId } = req.body;

      const result = await metaPartnerService.exchangeEmbeddedSignupOAuth(businessId, {
        code,
        businessPortfolioId,
        userId,
      });

      return ApiResponse.success(res, result, 'Meta Embedded Signup completed');
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/v1/meta-partner/channels
   */
  async getChannels(req, res, next) {
    try {
      const businessId = req.businessId;
      const userId = req.user?._id || req.user?.id;
      const result = await metaPartnerService.getChannels(businessId, { userId });
      return ApiResponse.success(res, result, 'Meta channels retrieved');
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/meta-partner/channels
   */
  async createChannel(req, res, next) {
    try {
      const businessId = req.businessId;
      const userId = req.user?._id || req.user?.id;
      const { name, phoneNumber, isActive } = req.body;
      const result = await metaPartnerService.createChannel(businessId, { name, phoneNumber, isActive, userId });
      return ApiResponse.success(res, result, 'Meta channel created');
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/meta-partner/channels/:id/register-pin
   */
  async registerPin(req, res, next) {
    try {
      const businessId = req.businessId;
      const userId = req.user?._id || req.user?.id;
      const { pin } = req.body;
      const channelId = req.params.id;
      const result = await metaPartnerService.registerChannelPin(businessId, { channelId, pin, userId });
      return ApiResponse.success(res, result, '2-Step Verification PIN registered');
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/meta-partner/channels/:id/subscribe-webhook
   */
  async subscribeWebhook(req, res, next) {
    try {
      const businessId = req.businessId;
      const userId = req.user?._id || req.user?.id;
      const channelId = req.params.id;
      const result = await metaPartnerService.subscribeChannelWebhook(businessId, { channelId, userId });
      return ApiResponse.success(res, result, 'Webhook subscribed');
    } catch (error) {
      next(error);
    }
  }

  /**
   * PATCH /api/v1/meta-partner/channels/:id/toggle-active
   */
  async toggleActive(req, res, next) {
    try {
      const businessId = req.businessId;
      const userId = req.user?._id || req.user?.id;
      const channelId = req.params.id;
      const { isActive } = req.body;
      const result = await metaPartnerService.toggleChannelActive(businessId, { channelId, isActive, userId });
      return ApiResponse.success(res, result, 'Channel status updated');
    } catch (error) {
      next(error);
    }
  }

  /**
   * DELETE /api/v1/meta-partner/channels/:id
   */
  async deleteChannel(req, res, next) {
    try {
      const businessId = req.businessId;
      const userId = req.user?._id || req.user?.id;
      const channelId = req.params.id;
      const result = await metaPartnerService.deleteChannel(businessId, { channelId, userId });
      return ApiResponse.success(res, result, 'Channel deleted');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new MetaPartnerController();
