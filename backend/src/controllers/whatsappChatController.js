const whatsappChatService = require('../services/whatsappChatService');
const ApiResponse = require('../utils/ApiResponse');

class WhatsAppChatController {
  /**
   * GET /api/v1/whatsapp/chats
   */
  async getChats(req, res, next) {
    try {
      const { search, page, limit } = req.query;
      const result = await whatsappChatService.getChats(req.businessId, {
        search,
        page,
        limit,
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
      const result = await whatsappChatService.getChatMessages(req.businessId, chatId, { limit });
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
      const result = await whatsappChatService.sendMessage(req.businessId, chatId, {
        text,
        messageType,
        mediaUrl,
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
      const result = await whatsappChatService.startNewChat(req.businessId, {
        customerPhone,
        customerName,
        initialMessage,
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
      const result = await whatsappChatService.saveConnection(req.businessId, {
        phoneNumberId,
        phoneNumber,
        wabaId,
        accessToken,
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
      const result = await whatsappChatService.getConnectionStatus(req.businessId);
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
      const result = await whatsappChatService.markRead(req.businessId, chatId);
      return ApiResponse.success(res, result, 'Conversation marked as read');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new WhatsAppChatController();
