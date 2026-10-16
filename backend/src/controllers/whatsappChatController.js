const whatsappChatService = require('../services/whatsappChatService');
const ApiResponse = require('../utils/ApiResponse');

class WhatsAppChatController {
  /**
   * GET /api/v1/whatsapp/chats
   */
  async getChats(req, res, next) {
    try {
      const { search, page, limit } = req.query;
      const userId = req.user?._id || req.user?.id;
      const result = await whatsappChatService.getChats(req.businessId, {
        search,
        page,
        limit,
        userId,
      });
      return ApiResponse.success(res, result, 'WhatsApp conversations retrieved');
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/v1/whatsapp/chats/:chatId/messages
   */
  async getMessages(req, res, next) {
    try {
      const { chatId } = req.params;
      const { limit } = req.query;
      const userId = req.user?._id || req.user?.id;
      const result = await whatsappChatService.getChatMessages(req.businessId, chatId, { limit, userId });
      return ApiResponse.success(res, result, 'Chat messages retrieved');
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/whatsapp/chats/:chatId/messages
   */
  async sendMessage(req, res, next) {
    try {
      const { chatId } = req.params;
      const { text, messageType, mediaUrl } = req.body;
      const userId = req.user?._id || req.user?.id;
      const result = await whatsappChatService.sendMessage(req.businessId, chatId, {
        text,
        messageType,
        mediaUrl,
        userId,
      });
      return ApiResponse.success(res, result, 'WhatsApp message sent successfully');
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/whatsapp/chats/new
   */
  async startNewChat(req, res, next) {
    try {
      const { customerPhone, customerName, initialMessage } = req.body;
      const userId = req.user?._id || req.user?.id;
      const result = await whatsappChatService.startNewChat(req.businessId, {
        customerPhone,
        customerName,
        initialMessage,
        userId,
      });
      return ApiResponse.success(res, result, 'WhatsApp chat initialized');
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/whatsapp/chats/connect
   */
  async saveConnection(req, res, next) {
    try {
      const { phoneNumberId, phoneNumber, wabaId, accessToken } = req.body;
      const userId = req.user?._id || req.user?.id;
      const result = await whatsappChatService.saveConnection(req.businessId, {
        phoneNumberId,
        phoneNumber,
        wabaId,
        accessToken,
        userId,
      });
      return ApiResponse.success(res, result, 'Meta WhatsApp integration connected successfully');
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/v1/whatsapp/chats/connection
   */
  async getConnectionStatus(req, res, next) {
    try {
      const userId = req.user?._id || req.user?.id;
      const result = await whatsappChatService.getConnectionStatus(req.businessId, userId);
      return ApiResponse.success(res, result, 'WhatsApp connection status retrieved');
    } catch (error) {
      next(error);
    }
  }

  /**
   * PUT /api/v1/whatsapp/chats/:chatId/read
   */
  async markRead(req, res, next) {
    try {
      const { chatId } = req.params;
      const userId = req.user?._id || req.user?.id;
      const result = await whatsappChatService.markRead(req.businessId, chatId, userId);
      return ApiResponse.success(res, result, 'Conversation marked as read');
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/whatsapp/chats/:chatId/sync-dp
   */
  async syncChatDp(req, res, next) {
    try {
      const { chatId } = req.params;
      const whatsappProfilePicService = require('../services/whatsappProfilePicService');
      const result = await whatsappProfilePicService.syncChatDp(req.businessId, chatId);
      return ApiResponse.success(res, result, 'WhatsApp profile picture synced');
    } catch (error) {
      next(error);
    }
  }

  /**
   * PUT /api/v1/whatsapp/chats/:chatId/avatar
   */
  async updateChatAvatar(req, res, next) {
    try {
      const { chatId } = req.params;
      const { avatarUrl } = req.body;
      const whatsappProfilePicService = require('../services/whatsappProfilePicService');
      const result = await whatsappProfilePicService.saveCustomAvatar(req.businessId, chatId, avatarUrl);
      return ApiResponse.success(res, result, 'Contact avatar updated');
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/v1/whatsapp/chats/ai-agent
   */
  async getAiAgentSettings(req, res, next) {
    try {
      const userId = req.user?._id || req.user?.id;
      const result = await whatsappChatService.getAiAgentSettings(req.businessId, userId);
      return ApiResponse.success(res, result, 'AI Chat Agent settings retrieved');
    } catch (error) {
      next(error);
    }
  }

  /**
   * PUT /api/v1/whatsapp/chats/ai-agent
   */
  async updateAiAgentSettings(req, res, next) {
    try {
      const userId = req.user?._id || req.user?.id;
      const settings = req.body;
      const result = await whatsappChatService.updateAiAgentSettings(req.businessId, settings, userId);
      return ApiResponse.success(res, result, 'AI Chat Agent settings updated successfully');
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/whatsapp/chats/ai-agent/simulate
   */
  async simulateAiChat(req, res, next) {
    try {
      const userId = req.user?._id || req.user?.id;
      const { message, settings } = req.body;
      const result = await whatsappChatService.simulateAiChat(req.businessId, message, settings, userId);
      return ApiResponse.success(res, result, 'AI Simulation response generated');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new WhatsAppChatController();
