const mongoose = require('mongoose');
const WhatsAppChat = require('../models/WhatsAppChat');
const WhatsAppMessage = require('../models/WhatsAppMessage');
const Business = require('../models/Business');
const Customer = require('../models/Customer');
const whatsappService = require('./whatsappService');
const storageService = require('../utils/storageService');
const ApiError = require('../utils/ApiError');

class WhatsAppChatService {
  /**
   * Get all active customer chat conversations for a business
   */
  async getChats(businessId, { search = '', page = 1, limit = 50 } = {}) {
    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;

    const query = { businessId: bId };

    if (search && search.trim()) {
      const term = search.trim();
      query.$or = [
        { customerName: { $regex: term, $options: 'i' } },
        { customerPhone: { $regex: term, $options: 'i' } },
        { lastMessage: { $regex: term, $options: 'i' } },
      ];
    }

    const skip = (Math.max(1, Number(page)) - 1) * Math.max(1, Number(limit));
    const [chats, total] = await Promise.all([
      WhatsAppChat.find(query)
        .sort({ lastMessageAt: -1 })
        .skip(skip)
        .limit(Math.max(1, Number(limit)))
        .lean(),
      WhatsAppChat.countDocuments(query),
    ]);

    return {
      chats,
      total,
      page: Number(page),
      limit: Number(limit),
    };
  }

  /**
   * Get message history for a specific chat conversation and mark as read
   */
  async getChatMessages(businessId, chatId, { limit = 100 } = {}) {
    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;
    const cId = mongoose.Types.ObjectId.isValid(chatId)
      ? new mongoose.Types.ObjectId(chatId)
      : chatId;

    const chat = await WhatsAppChat.findOne({ _id: cId, businessId: bId });
    if (!chat) {
      throw ApiError.notFound('WhatsApp conversation not found', 'CHAT_NOT_FOUND');
    }

    // Reset unread count when opening conversation
    if (chat.unreadCount > 0) {
      chat.unreadCount = 0;
      await chat.save();
    }

    const messages = await WhatsAppMessage.find({ chatId: cId, businessId: bId })
      .sort({ timestamp: 1 })
      .limit(Math.max(1, Number(limit)))
      .lean();

    return {
      chat,
      messages,
    };
  }

  /**
   * Send a reply message from business to customer in an existing chat
   */
  async sendMessage(businessId, chatId, { text = '', messageType = 'text', mediaUrl = '' }) {
    const isImage = messageType === 'image' || Boolean(mediaUrl);
    if (!isImage && (!text || !text.trim())) {
      throw ApiError.badRequest('Message text cannot be empty', null, 'EMPTY_MESSAGE');
    }

    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;
    const cId = mongoose.Types.ObjectId.isValid(chatId)
      ? new mongoose.Types.ObjectId(chatId)
      : chatId;

    const chat = await WhatsAppChat.findOne({ _id: cId, businessId: bId });
    if (!chat) {
      throw ApiError.notFound('WhatsApp conversation not found', 'CHAT_NOT_FOUND');
    }

    const business = await Business.findById(bId);
    const phoneNumberId = business?.whatsappSettings?.phoneNumberId || whatsappService.phoneNumberId;
    const accessToken = business?.whatsappSettings?.accessToken || whatsappService.accessToken;

    // Send via Meta WhatsApp Cloud API
    const waResult = await whatsappService.sendChatMessage({
      to: chat.customerPhone,
      text: (text || '').trim(),
      messageType: isImage ? 'image' : 'text',
      mediaUrl: mediaUrl || '',
      phoneNumberId,
      accessToken,
    });

    // Create Outgoing Message log
    const message = await WhatsAppMessage.create({
      businessId: bId,
      chatId: chat._id,
      customerPhone: chat.customerPhone,
      direction: 'OUTGOING',
      messageType: isImage ? 'image' : 'text',
      mediaUrl: mediaUrl || '',
      text: (text || '').trim(),
      whatsappMessageId: waResult.messageId,
      status: 'SENT',
      timestamp: new Date(),
    });

    // Update conversation summary
    chat.lastMessage = isImage ? (text ? `📷 ${text.trim()}` : '📷 Image') : text.trim();
    chat.lastMessageAt = message.timestamp;
    chat.lastMessageDirection = 'OUTGOING';
    await chat.save();

    return {
      chat,
      message,
    };
  }

  /**
   * Start or locate a new chat with a phone number
   */
  async startNewChat(businessId, { customerPhone, customerName = '', initialMessage = '' }) {
    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;

    if (!customerPhone) {
      throw ApiError.badRequest('Customer phone number is required', null, 'PHONE_REQUIRED');
    }

    const normalizedPhone = whatsappService.normalizePhoneNumber(customerPhone);
    if (!whatsappService.isValidPhoneNumber(normalizedPhone)) {
      throw ApiError.badRequest('Invalid customer phone number format', null, 'INVALID_PHONE');
    }

    let chat = await WhatsAppChat.findOne({
      businessId: bId,
      customerPhone: normalizedPhone,
    });

    let resolvedName = customerName || '';
    if (!resolvedName) {
      const customer = await Customer.findOne({
        businessId: bId,
        phone: { $in: [normalizedPhone, normalizedPhone.slice(-10), `+${normalizedPhone}`, `91${normalizedPhone.slice(-10)}`] },
      }).lean();
      if (customer?.name) resolvedName = customer.name;
    }

    if (!chat) {
      const business = await Business.findById(bId);
      const phoneNumberId = business?.whatsappSettings?.phoneNumberId || whatsappService.phoneNumberId;

      chat = await WhatsAppChat.create({
        businessId: bId,
        phoneNumberId: phoneNumberId || '',
        customerPhone: normalizedPhone,
        customerName: resolvedName || `Customer ${normalizedPhone.slice(-4)}`,
        lastMessage: initialMessage || 'Conversation started',
        lastMessageAt: new Date(),
        lastMessageDirection: initialMessage ? 'OUTGOING' : 'INCOMING',
        unreadCount: 0,
        status: 'ACTIVE',
      });
    } else if (resolvedName && (!chat.customerName || chat.customerName.startsWith('Customer '))) {
      chat.customerName = resolvedName;
      await chat.save();
    }

    let sentMessage = null;
    if (initialMessage && initialMessage.trim()) {
      const sendRes = await this.sendMessage(bId, chat._id, { text: initialMessage });
      sentMessage = sendRes.message;
      chat = sendRes.chat;
    }

    return {
      chat,
      message: sentMessage,
    };
  }

  /**
   * Save and connect Meta WhatsApp Phone Number credentials for a business
   */
  async saveConnection(businessId, { phoneNumberId, phoneNumber, wabaId = '', accessToken = '' }) {
    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;

    const business = await Business.findById(bId);
    if (!business) {
      throw ApiError.notFound('Business not found', 'BUSINESS_NOT_FOUND');
    }

    if (!phoneNumberId || !phoneNumberId.trim()) {
      throw ApiError.badRequest('Meta WhatsApp Phone Number ID is required', null, 'PHONE_ID_REQUIRED');
    }

    business.whatsappSettings = {
      enabled: true,
      phoneNumberId: phoneNumberId.trim(),
      phoneNumber: (phoneNumber || '').trim(),
      wabaId: (wabaId || '').trim(),
      accessToken: (accessToken || '').trim(),
      webhookVerifyToken: business.whatsappSettings?.webhookVerifyToken || 'softcode_whatsapp_webhook_verify_2026',
      connectedAt: new Date(),
    };

    await business.save();

    return {
      connected: true,
      phoneNumberId: business.whatsappSettings.phoneNumberId,
      phoneNumber: business.whatsappSettings.phoneNumber,
      connectedAt: business.whatsappSettings.connectedAt,
    };
  }

  /**
   * Get connection info for the business
   */
  async getConnectionStatus(businessId) {
    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;

    const business = await Business.findById(bId);
    const settings = business?.whatsappSettings || {};

    const activePhoneNumberId = settings.phoneNumberId || whatsappService.phoneNumberId || '';
    const isConnected = Boolean(settings.enabled || activePhoneNumberId);

    return {
      connected: isConnected,
      phoneNumberId: activePhoneNumberId,
      phoneNumber: settings.phoneNumber || '',
      wabaId: settings.wabaId || '',
      hasCustomToken: Boolean(settings.accessToken),
      connectedAt: settings.connectedAt || null,
    };
  }

  /**
   * Mark all messages in a chat as read
   */
  async markRead(businessId, chatId) {
    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;
    const cId = mongoose.Types.ObjectId.isValid(chatId)
      ? new mongoose.Types.ObjectId(chatId)
      : chatId;

    await WhatsAppChat.updateOne(
      { _id: cId, businessId: bId },
      { $set: { unreadCount: 0 } }
    );

    return { success: true };
  }

  /**
   * Process incoming customer messages received via Meta Webhook
   */
  async processIncomingWebhookMessage(incomingMsg) {
    if (!incomingMsg || !incomingMsg.from) return;

    const normalizedPhone = whatsappService.normalizePhoneNumber(incomingMsg.from);
    const phoneNumberId = incomingMsg.phoneNumberId ? String(incomingMsg.phoneNumberId).trim() : '';
    const displayPhoneNumber = incomingMsg.displayPhoneNumber ? String(incomingMsg.displayPhoneNumber).trim() : '';

    // Match business by configured phone number ID, display phone, or active WhatsApp business
    let business = null;
    if (phoneNumberId) {
      business = await Business.findOne({
        $or: [
          { 'whatsappSettings.phoneNumberId': phoneNumberId },
          { 'whatsappSettings.phoneNumber': phoneNumberId },
        ],
      });
    }

    if (!business && displayPhoneNumber) {
      const cleanDisplay = whatsappService.normalizePhoneNumber(displayPhoneNumber);
      business = await Business.findOne({
        $or: [
          { 'whatsappSettings.phoneNumber': cleanDisplay },
          { 'whatsappSettings.phoneNumber': displayPhoneNumber },
          { 'profile.phone': { $regex: cleanDisplay.slice(-10) } },
        ],
      });
    }

    if (!business) {
      // Find business that has WhatsApp actively configured
      business = await Business.findOne({
        $or: [
          { 'whatsappSettings.enabled': true },
          { 'whatsappSettings.phoneNumberId': { $ne: '' } },
        ],
      }).sort({ updatedAt: -1 });
    }

    if (!business) {
      business = await Business.findOne().sort({ updatedAt: -1 });
    }

    if (!business) {
      console.warn('[WhatsAppChatService] ⚠️ No business found to attach incoming webhook message.');
      return;
    }

    const bId = business._id;

    // Locate existing conversation (supports 10-digit, 12-digit, or + prefixes)
    let chat = await WhatsAppChat.findOne({
      businessId: bId,
      customerPhone: { $in: [normalizedPhone, normalizedPhone.slice(-10), `+${normalizedPhone}`, `91${normalizedPhone.slice(-10)}`] },
    });

    let customerName = incomingMsg.customerName || '';
    if (!customerName) {
      const customerRecord = await Customer.findOne({
        businessId: bId,
        phone: { $in: [normalizedPhone, normalizedPhone.slice(-10), `+${normalizedPhone}`, `91${normalizedPhone.slice(-10)}`] },
      }).lean();
      if (customerRecord?.name) {
        customerName = customerRecord.name;
      }
    }

    // Handle incoming media (Image, Document, Video, Audio)
    let mediaUrl = incomingMsg.mediaUrl || '';
    if (!mediaUrl && incomingMsg.mediaId) {
      try {
        const token = business.whatsappSettings?.accessToken || whatsappService.accessToken;
        const downloaded = await whatsappService.downloadMediaFromMeta(incomingMsg.mediaId, token);
        if (downloaded && downloaded.buffer) {
          const ext = downloaded.mimeType?.includes('png')
            ? '.png'
            : (downloaded.mimeType?.includes('webp') ? '.webp' : '.jpg');
          const cleanFileName = `wa_in_${Date.now()}_${Math.random().toString(36).slice(2, 7)}${ext}`;
          const uploadedUrl = await storageService.uploadImage(
            downloaded.buffer,
            cleanFileName,
            downloaded.mimeType || 'image/jpeg',
            'whatsapp'
          );
          if (uploadedUrl) {
            mediaUrl = uploadedUrl;
          }
        }
      } catch (err) {
        console.error('[WhatsAppChatService] Error downloading incoming media from Meta:', err.message);
      }
    }

    const isImage = incomingMsg.type === 'image' || Boolean(mediaUrl);
    const lastMsgDisplay = isImage
      ? (incomingMsg.body && incomingMsg.body !== '[Photo]' ? `📷 ${incomingMsg.body}` : '📷 Photo')
      : (incomingMsg.body || '[Message]');

    if (!chat) {
      chat = await WhatsAppChat.create({
        businessId: bId,
        phoneNumberId: phoneNumberId || business.whatsappSettings?.phoneNumberId || '',
        customerPhone: normalizedPhone,
        customerName: customerName || `Customer ${normalizedPhone.slice(-4)}`,
        lastMessage: lastMsgDisplay,
        lastMessageAt: incomingMsg.timestamp || new Date(),
        lastMessageDirection: 'INCOMING',
        unreadCount: 1,
        status: 'ACTIVE',
      });
    } else {
      if (customerName && (!chat.customerName || chat.customerName.startsWith('Customer '))) {
        chat.customerName = customerName;
      }
      chat.lastMessage = lastMsgDisplay;
      chat.lastMessageAt = incomingMsg.timestamp || new Date();
      chat.lastMessageDirection = 'INCOMING';
      chat.unreadCount = (chat.unreadCount || 0) + 1;
      await chat.save();
    }

    // Create incoming Message record
    await WhatsAppMessage.create({
      businessId: bId,
      chatId: chat._id,
      customerPhone: normalizedPhone,
      direction: 'INCOMING',
      messageType: isImage ? 'image' : (incomingMsg.type || 'text'),
      text: incomingMsg.body || '',
      mediaUrl: mediaUrl || '',
      whatsappMessageId: incomingMsg.messageId || '',
      status: 'DELIVERED',
      timestamp: incomingMsg.timestamp || new Date(),
    });

    console.log(`[WhatsAppChatService] 📩 Received incoming WhatsApp message from ${normalizedPhone} (${customerName || 'Customer'}): "${lastMsgDisplay}" with media "${mediaUrl || 'none'}" for Business ${business.profile?.name || business._id}`);

    // Create WhatsApp Message Notification & trigger push notification
    try {
      const notificationService = require('./notificationService');
      const senderDisplay = customerName && !customerName.startsWith('Customer ')
        ? customerName
        : (normalizedPhone.startsWith('91') && normalizedPhone.length === 12
            ? `+91 ${normalizedPhone.substring(2, 7)} ${normalizedPhone.substring(7)}`
            : normalizedPhone);

      const notifBody = isImage
        ? (incomingMsg.body && incomingMsg.body !== '[Photo]' ? `📷 ${incomingMsg.body}` : '📷 Photo')
        : (incomingMsg.body || 'New message');

      await notificationService.createNotification({
        businessId: bId,
        type: 'whatsapp_message',
        title: `WhatsApp: ${senderDisplay}`,
        message: notifBody,
        entityType: 'whatsapp_chat',
        entityId: chat._id.toString(),
        metadata: {
          chatId: chat._id.toString(),
          customerPhone: normalizedPhone,
          customerName: customerName || '',
          mediaUrl: mediaUrl || '',
          messageType: isImage ? 'image' : (incomingMsg.type || 'text'),
        },
        sendPush: true,
        idempotencyKey: incomingMsg.messageId ? `wa_notif_${incomingMsg.messageId}` : undefined,
      });
      console.log(`[WhatsAppChatService] 🔔 Created push notification for WhatsApp message from ${senderDisplay}`);
    } catch (notifErr) {
      console.warn('[WhatsAppChatService] Non-blocking notification creation error:', notifErr.message);
    }
  }

  /**
   * Process webhook message delivery status update (SENT, DELIVERED, READ)
   */
  async processWebhookStatusUpdate(update) {
    if (!update || !update.messageId) return;

    const message = await WhatsAppMessage.findOne({ whatsappMessageId: update.messageId });
    if (!message) return; // Might be an eBill or unlogged message

    message.status = update.status;
    if (update.errors && Array.isArray(update.errors) && update.errors.length > 0) {
      message.error = update.errors[0]?.message || 'Delivery error';
    }
    await message.save();
  }
}

module.exports = new WhatsAppChatService();
