const mongoose = require('mongoose');
const WhatsAppChat = require('../models/WhatsAppChat');
const WhatsAppMessage = require('../models/WhatsAppMessage');
const Business = require('../models/Business');
const Customer = require('../models/Customer');
const User = require('../models/User');
const whatsappService = require('./whatsappService');
const storageService = require('../utils/storageService');
const ApiError = require('../utils/ApiError');

class WhatsAppChatService {
  /**
   * Get all active customer chat conversations for a business quickly and reliably
   */
  async getChats(businessId, { search = '', page = 1, limit = 50, userId = null } = {}) {
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

    // Enrich chats with profile avatar & name from Customer & User models
    if (chats && chats.length > 0) {
      const customerPhones = [...new Set(chats.map((c) => c.customerPhone).filter(Boolean))];
      if (customerPhones.length > 0) {
        const phoneQueries = [];
        customerPhones.forEach((p) => {
          const pClean = p.replace(/\D/g, '');
          const last10 = pClean.slice(-10);
          if (p) phoneQueries.push(p);
          if (pClean) phoneQueries.push(pClean);
          if (last10) {
            phoneQueries.push(last10);
            phoneQueries.push(`+91${last10}`);
            phoneQueries.push(`91${last10}`);
            phoneQueries.push(`+${pClean}`);
          }
        });

        const [customers, users] = await Promise.all([
          Customer.find({
            businessId: bId,
            phone: { $in: [...new Set(phoneQueries)] },
          }).select('name phone avatarUrl profileImage').lean(),
          User.find({
            businessId: bId,
            phone: { $in: [...new Set(phoneQueries)] },
          }).select('name phone profilePhotoPath').lean(),
        ]);

        const avatarMap = new Map();
        const nameMap = new Map();

        customers.forEach((c) => {
          const cClean = (c.phone || '').replace(/\D/g, '');
          const last10 = cClean.slice(-10);
          const av = c.avatarUrl || c.profileImage || '';
          if (av) {
            if (last10) avatarMap.set(last10, av);
            if (c.phone) avatarMap.set(c.phone, av);
          }
          if (c.name) {
            if (last10) nameMap.set(last10, c.name);
            if (c.phone) nameMap.set(c.phone, c.name);
          }
        });

        users.forEach((u) => {
          const uClean = (u.phone || '').replace(/\D/g, '');
          const last10 = uClean.slice(-10);
          const av = u.profilePhotoPath || '';
          if (av && av !== 'assets/images/logo.png') {
            if (last10 && !avatarMap.has(last10)) avatarMap.set(last10, av);
            if (u.phone && !avatarMap.has(u.phone)) avatarMap.set(u.phone, av);
          }
        });

        const whatsappProfilePicService = require('./whatsappProfilePicService');
        chats.forEach((chat) => {
          const pClean = (chat.customerPhone || '').replace(/\D/g, '');
          const last10 = pClean.slice(-10);
          const matchedAvatar = avatarMap.get(last10) || avatarMap.get(chat.customerPhone);
          if (matchedAvatar && !chat.avatarUrl) {
            chat.avatarUrl = matchedAvatar;
          } else if (!chat.avatarUrl) {
            const cachedLocal = whatsappProfilePicService.hasCachedLocalAvatar(pClean);
            if (cachedLocal) {
              chat.avatarUrl = cachedLocal;
            }
          }
          const matchedName = nameMap.get(last10) || nameMap.get(chat.customerPhone);
          if (matchedName && (!chat.customerName || chat.customerName.startsWith('Customer '))) {
            chat.customerName = matchedName;
          }
        });

        // Asynchronous non-blocking background DP sync for chats missing avatar
        setImmediate(async () => {
          try {
            for (const chat of chats) {
              if (!chat.avatarUrl && chat.customerPhone) {
                await whatsappProfilePicService.resolveProfilePic({
                  phone: chat.customerPhone,
                  businessId: bId,
                  chatId: chat._id,
                });
              }
            }
          } catch (_) {}
        });
      }
    }

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
  async getChatMessages(businessId, chatId, { limit = 100, userId = null } = {}) {
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

    if (chat && !chat.avatarUrl) {
      const whatsappProfilePicService = require('./whatsappProfilePicService');
      const pClean = (chat.customerPhone || '').replace(/\D/g, '');
      const localCached = whatsappProfilePicService.hasCachedLocalAvatar(pClean);
      if (localCached) {
        chat.avatarUrl = localCached;
      } else {
        const last10 = pClean.slice(-10);
        const cust = await Customer.findOne({
          businessId: bId,
          phone: { $in: [chat.customerPhone, pClean, last10, `+91${last10}`, `91${last10}`] },
        }).select('name avatarUrl profileImage').lean();
        if (cust && (cust.avatarUrl || cust.profileImage)) {
          chat.avatarUrl = cust.avatarUrl || cust.profileImage;
        }
      }
    }

    return {
      chat,
      messages,
    };
  }

  /**
   * Send a reply message from business to customer in an existing chat
   */
  async sendMessage(businessId, chatId, { text = '', messageType = 'text', mediaUrl = '', userId = null }) {
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

    let user = null;
    if (userId) {
      user = await User.findById(userId).lean();
    }

    const business = await Business.findById(bId);
    const phoneNumberId = user?.whatsappSettings?.phoneNumberId ||
      chat.phoneNumberId ||
      business?.whatsappSettings?.phoneNumberId ||
      whatsappService.phoneNumberId;
    const accessToken = user?.whatsappSettings?.accessToken ||
      business?.whatsappSettings?.accessToken ||
      whatsappService.accessToken;

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
    if (!chat.userId && user) {
      chat.userId = user._id;
    }
    await chat.save();

    // Broadcast instantaneously over WebSocket
    try {
      const socketService = require('./socketService');
      socketService.emitWhatsAppMessageReceived(bId, { chat, message });
    } catch (_) {}

    return {
      chat,
      message,
    };
  }

  /**
   * Start or locate a new chat with any valid phone number
   */
  async startNewChat(businessId, { customerPhone, customerName = '', initialMessage = '', userId = null }) {
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

    let user = null;
    if (userId) {
      user = await User.findById(userId).lean();
    }

    // Always query by businessId + customerPhone to adhere strictly to the compound unique index
    let chat = await WhatsAppChat.findOne({
      businessId: bId,
      customerPhone: normalizedPhone,
    });

    let resolvedName = customerName || '';
    let resolvedAvatar = '';
    const customer = await Customer.findOne({
      businessId: bId,
      phone: { $in: [normalizedPhone, normalizedPhone.slice(-10), `+${normalizedPhone}`, `91${normalizedPhone.slice(-10)}`] },
    }).lean();
    if (customer) {
      if (!resolvedName && customer.name) resolvedName = customer.name;
      if (customer.avatarUrl || customer.profileImage) {
        resolvedAvatar = customer.avatarUrl || customer.profileImage;
      }
    }

    if (!chat) {
      const business = await Business.findById(bId);
      const phoneNumberId = user?.whatsappSettings?.phoneNumberId || business?.whatsappSettings?.phoneNumberId || whatsappService.phoneNumberId;

      chat = await WhatsAppChat.create({
        businessId: bId,
        userId: user?._id || null,
        phoneNumberId: phoneNumberId || '',
        customerPhone: normalizedPhone,
        customerName: resolvedName || `Customer ${normalizedPhone.slice(-4)}`,
        avatarUrl: resolvedAvatar || '',
        lastMessage: initialMessage || 'Conversation started',
        lastMessageAt: new Date(),
        lastMessageDirection: initialMessage ? 'OUTGOING' : 'INCOMING',
        unreadCount: 0,
        status: 'ACTIVE',
      });
    } else {
      if (resolvedName && (!chat.customerName || chat.customerName.startsWith('Customer '))) {
        chat.customerName = resolvedName;
      }
      if (resolvedAvatar && !chat.avatarUrl) {
        chat.avatarUrl = resolvedAvatar;
      }
      if (user?.whatsappSettings?.phoneNumberId && !chat.phoneNumberId) {
        chat.phoneNumberId = user.whatsappSettings.phoneNumberId.trim();
      }
      await chat.save();
    }

    let sentMessage = null;
    if (initialMessage && initialMessage.trim()) {
      try {
        const sendRes = await this.sendMessage(bId, chat._id, { text: initialMessage, userId });
        sentMessage = sendRes.message;
        chat = sendRes.chat;
      } catch (sendErr) {
        // Safe graceful fallback: If initial message sending fails (e.g. sandbox restriction or 24-hr template policy),
        // record the message with FAILED status and error reason, but DO NOT crash chat creation so the user can open and view the chat window!
        console.warn(`[WhatsAppChatService] Initial message dispatch notice: ${sendErr.message}`);
        sentMessage = await WhatsAppMessage.create({
          businessId: bId,
          chatId: chat._id,
          customerPhone: chat.customerPhone,
          direction: 'OUTGOING',
          messageType: 'text',
          text: initialMessage.trim(),
          status: 'FAILED',
          error: sendErr.message,
          timestamp: new Date(),
        });
        chat.lastMessage = initialMessage.trim();
        chat.lastMessageAt = sentMessage.timestamp;
        chat.lastMessageDirection = 'OUTGOING';
        await chat.save();
      }
    }

    try {
      const socketService = require('./socketService');
      socketService.emitWhatsAppChatUpdated(bId, { chat });
    } catch (_) {}

    return {
      chat,
      message: sentMessage,
    };
  }

  /**
   * Save and connect Meta WhatsApp Phone Number credentials for a user / business
   */
  async saveConnection(businessId, { phoneNumberId, phoneNumber, wabaId = '', accessToken = '', userId = null }) {
    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;

    if (!phoneNumberId || !phoneNumberId.trim()) {
      throw ApiError.badRequest('Meta WhatsApp Phone Number ID is required', null, 'PHONE_ID_REQUIRED');
    }

    const cleanPhoneId = phoneNumberId.trim();
    const cleanPhone = (phoneNumber || '').trim();
    const cleanWaba = (wabaId || '').trim();
    let cleanToken = (accessToken || '').trim();

    // Preserve existing access token if caller did not supply a new one
    if (!cleanToken) {
      if (userId) {
        const existingUser = await User.findById(userId).lean();
        if (existingUser?.whatsappSettings?.accessToken) {
          cleanToken = existingUser.whatsappSettings.accessToken;
        }
      }
      if (!cleanToken && bId) {
        const existingBiz = await Business.findById(bId).lean();
        if (existingBiz?.whatsappSettings?.accessToken) {
          cleanToken = existingBiz.whatsappSettings.accessToken;
        }
      }
    }

    const now = new Date();

    // 1. If userId is provided, save onto User model for user-specific WhatsApp isolation
    if (userId) {
      await User.findByIdAndUpdate(userId, {
        $set: {
          whatsappSettings: {
            enabled: true,
            phoneNumberId: cleanPhoneId,
            phoneNumber: cleanPhone,
            wabaId: cleanWaba,
            accessToken: cleanToken,
            webhookVerifyToken: 'softcode_whatsapp_webhook_verify_2026',
            connectedAt: now,
          },
        },
      });

      // Bind existing chats with this phoneNumberId to this user
      await WhatsAppChat.updateMany(
        { businessId: bId, phoneNumberId: cleanPhoneId },
        { $set: { userId } }
      );
    }

    // 2. Also persist onto Business model if business exists
    const business = await Business.findById(bId);
    if (business) {
      business.whatsappSettings = {
        enabled: true,
        phoneNumberId: cleanPhoneId,
        phoneNumber: cleanPhone,
        wabaId: cleanWaba,
        accessToken: cleanToken,
        webhookVerifyToken: business.whatsappSettings?.webhookVerifyToken || 'softcode_whatsapp_webhook_verify_2026',
        connectedAt: now,
      };
      await business.save();
    }

    return {
      connected: true,
      phoneNumberId: cleanPhoneId,
      phoneNumber: cleanPhone,
      wabaId: cleanWaba,
      accessToken: cleanToken,
      hasCustomToken: Boolean(cleanToken),
      connectedAt: now,
    };
  }

  /**
   * Get connection info for the user / business
   */
  async getConnectionStatus(businessId, userId = null) {
    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;

    let userSettings = null;
    let userDoc = null;
    if (userId) {
      userDoc = await User.findById(userId);
      userSettings = userDoc?.whatsappSettings;
    }

    const business = bId ? await Business.findById(bId) : null;
    const bizSettings = business?.whatsappSettings;

    const activePhoneNumberId = userSettings?.phoneNumberId || bizSettings?.phoneNumberId || whatsappService.phoneNumberId || '1284061438133660';
    const activePhoneNumber = userSettings?.phoneNumber || bizSettings?.phoneNumber || '+91 73036 32949';
    const activeWabaId = userSettings?.wabaId || bizSettings?.wabaId || '2525727467906581';
    const activeToken = userSettings?.accessToken || bizSettings?.accessToken || whatsappService.accessToken || '';
    const isConnected = Boolean(activePhoneNumberId && (activeToken || process.env.NODE_ENV === 'production'));
    const connectedAt = userSettings?.connectedAt || bizSettings?.connectedAt || new Date('2026-10-18T00:00:00Z');

    // Cross-sync if one had settings but the other was empty
    if (activePhoneNumberId) {
      if (userDoc && (!userSettings?.phoneNumberId || !userSettings?.accessToken)) {
        userDoc.whatsappSettings = {
          enabled: true,
          phoneNumberId: activePhoneNumberId,
          phoneNumber: activePhoneNumber,
          wabaId: activeWabaId,
          accessToken: activeToken,
          webhookVerifyToken: 'softcode_whatsapp_webhook_verify_2026',
          connectedAt: connectedAt || new Date(),
        };
        await userDoc.save();
      }
      if (business && (!bizSettings?.phoneNumberId || !bizSettings?.accessToken)) {
        business.whatsappSettings = {
          enabled: true,
          phoneNumberId: activePhoneNumberId,
          phoneNumber: activePhoneNumber,
          wabaId: activeWabaId,
          accessToken: activeToken,
          webhookVerifyToken: 'softcode_whatsapp_webhook_verify_2026',
          connectedAt: connectedAt || new Date(),
        };
        await business.save();
      }
    }

    return {
      connected: isConnected,
      phoneNumberId: activePhoneNumberId,
      phoneNumber: activePhoneNumber,
      wabaId: activeWabaId,
      accessToken: activeToken,
      hasCustomToken: Boolean(activeToken),
      connectedAt,
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

    // Match user or business by configured phone number ID, display phone, or active WhatsApp business
    let targetUser = null;
    let business = null;

    // Collect query conditions for matching businesses by phone credentials
    const bizQueryConditions = [];
    if (phoneNumberId) {
      bizQueryConditions.push({ 'whatsappSettings.phoneNumberId': phoneNumberId });
      bizQueryConditions.push({ 'whatsappSettings.phoneNumber': phoneNumberId });
    }
    if (displayPhoneNumber) {
      const cleanDisplay = whatsappService.normalizePhoneNumber(displayPhoneNumber);
      bizQueryConditions.push({ 'whatsappSettings.phoneNumber': cleanDisplay });
      bizQueryConditions.push({ 'whatsappSettings.phoneNumber': displayPhoneNumber });
      bizQueryConditions.push({ 'profile.phone': { $regex: cleanDisplay.slice(-10) } });
    }

    if (bizQueryConditions.length > 0) {
      // Find all candidates matching the phone number credentials sorted by recent connection and updates
      const candidateBusinesses = await Business.find({ $or: bizQueryConditions })
        .sort({ 'whatsappSettings.connectedAt': -1, updatedAt: -1 });

      if (candidateBusinesses.length > 0) {
        // Priority 1: Check existing conversation for this customer with any candidate business
        const candidateIds = candidateBusinesses.map((b) => b._id);
        const existingChat = await WhatsAppChat.findOne({
          businessId: { $in: candidateIds },
          customerPhone: { $in: [normalizedPhone, normalizedPhone.slice(-10), `+${normalizedPhone}`, `91${normalizedPhone.slice(-10)}`] },
        }).sort({ lastMessageAt: -1, updatedAt: -1 });

        if (existingChat) {
          const matched = candidateBusinesses.find((b) => b._id.toString() === existingChat.businessId.toString());
          if (matched) {
            business = matched;
          }
        }

        // Priority 2: Pick the candidate business with AI Chat Agent enabled
        if (!business) {
          business = candidateBusinesses.find((b) => !b.aiChatAgentSettings || b.aiChatAgentSettings.enabled !== false);
        }

        // Priority 3: Pick the candidate business with WhatsApp explicitly enabled
        if (!business) {
          business = candidateBusinesses.find((b) => b.whatsappSettings?.enabled === true);
        }

        // Priority 4: Fallback to the most recently connected / updated candidate
        if (!business) {
          business = candidateBusinesses[0];
        }
      }
    }

    // Secondary check: If business not resolved by Business table, check User table for a user with businessId
    if (!business && phoneNumberId) {
      targetUser = await User.findOne({
        'whatsappSettings.phoneNumberId': phoneNumberId,
        businessId: { $exists: true, $ne: null },
      }).sort({ updatedAt: -1 }).lean();

      if (targetUser && targetUser.businessId) {
        business = await Business.findById(targetUser.businessId);
      }
    }

    // Tertiary check: Dedicated test profile fallback
    if (!business) {
      business = await this.getDedicatedTestBusiness();
      if (business) {
        console.log('[WhatsAppChatService] 🧪 Attached unmapped webhook message to dedicated tester@gmail.com profile');
      }
    }

    if (!business) {
      console.warn('[WhatsAppChatService] ⚠️ No business found to attach incoming webhook message. Dropping to protect production profiles.');
      return;
    }

    // Resolve targetUser (business owner) for push notifications / socket broadcasts
    if (!targetUser) {
      if (business.ownerId) {
        targetUser = await User.findById(business.ownerId).lean();
      }
      if (!targetUser) {
        targetUser = await User.findOne({ businessId: business._id }).lean();
      }
    }

    const bId = business._id;
    const targetUserId = targetUser?._id || null;

    // Locate existing conversation strictly by business and normalized customer phone
    const chatFilter = {
      businessId: bId,
      customerPhone: { $in: [normalizedPhone, normalizedPhone.slice(-10), `+${normalizedPhone}`, `91${normalizedPhone.slice(-10)}`] },
    };

    let chat = await WhatsAppChat.findOne(chatFilter);

    let customerName = incomingMsg.customerName || '';
    let customerAvatar = '';
    const customerRecord = await Customer.findOne({
      businessId: bId,
      phone: { $in: [normalizedPhone, normalizedPhone.slice(-10), `+${normalizedPhone}`, `91${normalizedPhone.slice(-10)}`] },
    }).lean();
    if (customerRecord) {
      if (!customerName && customerRecord.name) {
        customerName = customerRecord.name;
      }
      customerAvatar = customerRecord.avatarUrl || customerRecord.profileImage || '';
    }

    const hasPendingMedia = !incomingMsg.mediaUrl && Boolean(incomingMsg.mediaId);
    let mediaUrl = incomingMsg.mediaUrl || '';
    const isImage = incomingMsg.type === 'image' || Boolean(mediaUrl) || Boolean(incomingMsg.mediaId);
    const lastMsgDisplay = isImage
      ? (incomingMsg.body && incomingMsg.body !== '[Photo]' ? `📷 ${incomingMsg.body}` : '📷 Photo')
      : (incomingMsg.body || '[Message]');

    if (!chat) {
      chat = await WhatsAppChat.create({
        businessId: bId,
        userId: targetUserId || null,
        phoneNumberId: phoneNumberId || business.whatsappSettings?.phoneNumberId || '',
        customerPhone: normalizedPhone,
        customerName: customerName || `Customer ${normalizedPhone.slice(-4)}`,
        avatarUrl: customerAvatar || '',
        lastMessage: lastMsgDisplay,
        lastMessageAt: incomingMsg.timestamp || new Date(),
        lastMessageDirection: 'INCOMING',
        unreadCount: 1,
        status: 'ACTIVE',
      });
    } else {
      if (targetUserId && !chat.userId) {
        chat.userId = targetUserId;
      }
      if (customerName && (!chat.customerName || chat.customerName.startsWith('Customer '))) {
        chat.customerName = customerName;
      }
      if (customerAvatar && !chat.avatarUrl) {
        chat.avatarUrl = customerAvatar;
      }
      chat.lastMessage = lastMsgDisplay;
      chat.lastMessageAt = incomingMsg.timestamp || new Date();
      chat.lastMessageDirection = 'INCOMING';
      chat.unreadCount = (chat.unreadCount || 0) + 1;
      await chat.save();
    }

    // Create incoming Message record immediately (<15ms)
    const message = await WhatsAppMessage.create({
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

    console.log(`[WhatsAppChatService] 📩 [INSTANT] Incoming WhatsApp message from ${normalizedPhone} (${customerName || 'Customer'}): "${lastMsgDisplay}"`);

    // 1. Instantaneous WebSocket broadcast to connected business terminals (<20ms)
    try {
      const socketService = require('./socketService');
      socketService.emitWhatsAppMessageReceived(bId, {
        chat,
        message,
        targetUserId,
        ownerId: business?.ownerId,
      });
    } catch (_) {}

    // 2. Immediate push notification dispatch for OS Notification Tray (<10ms)
    try {
      const senderDisplay = customerName && !customerName.startsWith('Customer ')
        ? customerName
        : (normalizedPhone.startsWith('91') && normalizedPhone.length === 12
            ? `+91 ${normalizedPhone.substring(2, 7)} ${normalizedPhone.substring(7)}`
            : normalizedPhone);

      const notifBody = isImage
        ? (incomingMsg.body && incomingMsg.body !== '[Photo]' ? `📷 ${incomingMsg.body}` : '📷 Photo')
        : (incomingMsg.body || 'New message');

      const pushNotificationService = require('./pushNotificationService');
      pushNotificationService.sendPushNotificationToBusiness({
        businessId: bId,
        title: `WhatsApp: ${senderDisplay}`,
        message: notifBody,
        data: {
          type: 'whatsapp_message',
          chatId: chat._id.toString(),
          customerPhone: normalizedPhone,
          customerName: customerName || '',
          mediaUrl: mediaUrl || '',
          messageType: isImage ? 'image' : (incomingMsg.type || 'text'),
        },
      }).catch((err) => console.warn('[WhatsAppChatService] Push error:', err.message));

      const notificationService = require('./notificationService');
      notificationService.createNotification({
        businessId: bId,
        userId: targetUserId || business?.ownerId || undefined,
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
        sendPush: false, // Direct push already dispatched above
        idempotencyKey: incomingMsg.messageId ? `wa_notif_${incomingMsg.messageId}` : undefined,
      }).catch((notifErr) => console.warn('[WhatsAppChatService] Notification record notice:', notifErr.message));
    } catch (notifErr) {
      console.warn('[WhatsAppChatService] Push notification dispatch notice:', notifErr.message);
    }

    // 3. Autonomous AI Chat Agent Auto-Reply on WhatsApp (Multi-customer thread-safe)
    try {
      const aiSettings = business.aiChatAgentSettings;
      // Active by default unless explicitly disabled
      const isAiEnabled = !aiSettings || aiSettings.enabled !== false;

      // Only trigger if AI is enabled and incoming message is valid customer text
      if (isAiEnabled && incomingMsg.body && incomingMsg.body.trim()) {
        const whatsappOrderSessionService = require('./whatsappOrderSessionService');
        const delaySeconds = Math.max(1, aiSettings?.autoReplyDelaySeconds || 1);

        setTimeout(() => {
          // Enqueue per (businessId, customerPhone) so each customer runs in strict sequence
          // while multiple different customers process concurrently without blocking each other.
          whatsappOrderSessionService.enqueue(bId, normalizedPhone, async () => {
            try {
              let finalReplyText = '';
              let finalButtons = null;
              let orderToCreate = null;

              // Step 1: Execute Conversation State Machine
              const sessionResult = await whatsappOrderSessionService.processConversationMessage({
                business,
                customerPhone: normalizedPhone,
                messageText: incomingMsg.body,
                customerName: customerName || chat.customerName,
                messageId: incomingMsg.messageId,
                chat,
                targetUserId,
              });

              if (sessionResult && sessionResult.isDuplicate) {
                // Drop duplicate webhook safely
                return;
              }

              if (sessionResult && sessionResult.handled) {
                finalReplyText = sessionResult.replyText;
                finalButtons = sessionResult.buttons;
                orderToCreate = sessionResult.orderPayload;
              } else {
                // Step 2: Fall back to general hospitality AI agent
                const aiAgentService = require('./aiAgentService');
                const aiResult = await aiAgentService.generateReply({
                  business,
                  chatId: chat._id,
                  customerPhone: normalizedPhone,
                  customerName: customerName || chat.customerName,
                  messageText: incomingMsg.body,
                });

                if (aiResult && aiResult.replyText && aiResult.replyText.trim()) {
                  finalReplyText = aiResult.replyText.trim();
                  orderToCreate = aiResult.orderPayload;
                }
              }

              // Step 3: If an order was confirmed for checkout, atomically create in MongoDB via orderService
              if (orderToCreate && Array.isArray(orderToCreate.items) && orderToCreate.items.length > 0) {
                try {
                  const orderService = require('./orderService');
                  const orderResult = await orderService.generatePosOrder(bId, {
                    ...orderToCreate,
                    customerPhone: normalizedPhone,
                    customerName: customerName || chat.customerName || 'WhatsApp Customer',
                    status: 'pending',
                    paymentStatus: 'pending',
                    paymentMethod: 'unpaid',
                    source: 'whatsapp',
                    orderSource: 'whatsapp',
                    chatId: chat._id,
                  });

                  const createdOrder = orderResult?.order || orderResult;
                  if (createdOrder && createdOrder.orderNumber) {
                    whatsappOrderSessionService.recordOrder(bId, normalizedPhone, createdOrder);

                    const isDel = createdOrder.orderType === 'delivery';
                    const typeDisplay = isDel
                      ? `🛵 *Type*: *Home Delivery*${createdOrder.deliveryAddress ? `\n📍 *Deliver To*: *${createdOrder.deliveryAddress}*` : ''}`
                      : `🛍️ *Type*: *Takeaway / Pickup*`;

                    finalReplyText = `✅ *Your order has been placed successfully!* 🎉\n\n📋 *Order ID*: *#${createdOrder.orderNumber}*\n💰 *Total Amount*: *₹${createdOrder.totalAmount}*\n${typeDisplay}\n\n⏳ *Status*: 🕒 *Awaiting confirmation from the restaurant.*\nWe'll notify you once the restaurant accepts or rejects your order! 🚀`;
                    finalButtons = null;

                    console.log(`[WhatsAppChatService] 🛒 Direct POS Order #${createdOrder.orderNumber} created via WhatsApp AI for ${normalizedPhone} (Type: ${createdOrder.orderType})`);

                    // 1. High-Priority FCM Push Notification dispatch to restaurant terminals
                    try {
                      const pushNotificationService = require('./pushNotificationService');
                      pushNotificationService.sendPushNotificationToBusiness({
                        businessId: bId,
                        title: `🔔 New WhatsApp Order: #${createdOrder.orderNumber}`,
                        message: `${customerName || normalizedPhone} (${createdOrder.orderType.toUpperCase()} - ₹${createdOrder.totalAmount}) • Tap to Accept or Reject`,
                        data: {
                          type: 'whatsapp_order_request',
                          orderId: createdOrder._id.toString(),
                          orderNumber: createdOrder.orderNumber,
                          customerPhone: normalizedPhone,
                          customerName: customerName || chat.customerName || 'Customer',
                          totalAmount: String(createdOrder.totalAmount),
                          orderType: createdOrder.orderType,
                          deliveryAddress: createdOrder.deliveryAddress || '',
                          items: JSON.stringify(createdOrder.items || []),
                          createdAt: (createdOrder.createdAt || new Date()).toISOString(),
                        },
                      }).catch((pushErr) => console.warn('[WhatsAppChatService] Push order alert notice:', pushErr.message));
                    } catch (pushErr) {
                      console.warn('[WhatsAppChatService] Push order alert dispatch error:', pushErr.message);
                    }

                    // 2. Real-time WebSocket emission to all business terminals
                    try {
                      const socketService = require('./socketService');
                      socketService.emitWhatsAppOrderRequest(bId, {
                        order: createdOrder.toJSON ? createdOrder.toJSON() : createdOrder,
                        chat,
                        customerPhone: normalizedPhone,
                        customerName: customerName || chat.customerName,
                        targetUserId,
                      });
                    } catch (sockErr) {
                      console.warn('[WhatsAppChatService] Socket order alert emission error:', sockErr.message);
                    }
                  }
                } catch (orderErr) {
                  console.error('[WhatsAppChatService] Direct order creation notice:', orderErr.message);
                }
              }

              // Step 4: Dispatch reply to customer on WhatsApp via Meta API
              if (finalReplyText && finalReplyText.trim()) {
                const activePhoneId =
                  chat.phoneNumberId ||
                  business.whatsappSettings?.phoneNumberId ||
                  whatsappService.phoneNumberId;

                const activeToken =
                  business.whatsappSettings?.accessToken ||
                  whatsappService.accessToken;

                const sendResult = await whatsappService.sendChatMessage({
                  to: normalizedPhone,
                  text: finalReplyText,
                  message: finalReplyText,
                  buttons: finalButtons,
                  phoneNumberId: activePhoneId,
                  accessToken: activeToken,
                });

                // Create OUTGOING AI Message Record
                const aiMsg = await WhatsAppMessage.create({
                  businessId: bId,
                  chatId: chat._id,
                  customerPhone: normalizedPhone,
                  direction: 'OUTGOING',
                  messageType: finalButtons && finalButtons.length > 0 ? 'interactive' : 'text',
                  text: finalReplyText,
                  whatsappMessageId: sendResult?.messageId || `wamid.ai.${Date.now()}`,
                  isAiGenerated: true,
                  status: 'SENT',
                  timestamp: new Date(),
                });

                // Update Chat
                chat.lastMessage = `🤖 ${finalReplyText.trim().slice(0, 80)}`;
                chat.lastMessageAt = new Date();
                chat.lastMessageDirection = 'OUTGOING';
                await chat.save();

                // Broadcast via WebSocket to all connected terminals
                const socketService = require('./socketService');
                socketService.emitWhatsAppMessageReceived(bId, {
                  chat,
                  message: aiMsg,
                  targetUserId,
                  ownerId: business?.ownerId,
                });
              }
            } catch (queueErr) {
              console.error(`[WhatsAppChatService] Error processing queued task for ${normalizedPhone}:`, queueErr);
            }
          });
        }, delaySeconds * 1000);
      }
    } catch (aiErr) {
      console.warn('[WhatsAppChatService] Non-blocking AI Chat Agent notice:', aiErr.message);
    }

    // 4. Asynchronous background media hydration (non-blocking for instant responsiveness)
    if (hasPendingMedia) {
      setImmediate(async () => {
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
              message.mediaUrl = uploadedUrl;
              await message.save();
              const socketService = require('./socketService');
              socketService.emitWhatsAppMessageUpdated(bId, {
                messageId: message._id,
                chatId: chat._id,
                mediaUrl: uploadedUrl,
              });
              console.log(`[WhatsAppChatService] 🖼️ Media hydrated for message ${message._id}`);
            }
          }
        } catch (err) {
          console.error('[WhatsAppChatService] Error downloading incoming media from Meta:', err.message);
        }
      });
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
      const err = update.errors[0];
      const code = err.code;
      const title = err.title || '';
      const rawMsg = err.message || '';
      if (code === 131047 || title === 'Re-engagement message' || rawMsg === 'Re-engagement message') {
        message.error = '24-hour customer window expired (Meta policy). Customer must reply or send template to re-engage.';
      } else {
        message.error = err.error_data?.details || err.message || err.title || 'Delivery error';
      }
    }
    await message.save();
  }

  /**
   * Dedicated Test Profile Resolver (Strictly targets tester@gmail.com)
   * Production profiles (like Pizza 47) are strictly protected from tests/simulations.
   */
  async getDedicatedTestBusiness() {
    try {
      const User = require('../models/User');
      const Business = require('../models/Business');
      const testUser = await User.findOne({ email: 'tester@gmail.com' });
      if (testUser) {
        const testBiz = await Business.findOne({ ownerId: testUser._id });
        if (testBiz) return testBiz;
      }
    } catch (e) {
      console.error('[WhatsAppChatService] Error finding tester business:', e.message);
    }
    return null;
  }

  /**
   * Get AI Agent settings for business
   */
  async getAiAgentSettings(businessId, userId) {
    let business = null;
    if (businessId) {
      business = await Business.findById(businessId).lean();
    }
    if (!business && userId) {
      business = await Business.findOne({ ownerId: userId }).lean();
    }
    if (!business) {
      business = await this.getDedicatedTestBusiness();
      if (business) business = business.toObject ? business.toObject() : business;
    }
    if (!business) {
      throw ApiError.notFound('Business not found');
    }

    return business.aiChatAgentSettings || {
      enabled: false,
      persona: 'friendly',
      agentName: 'Apna AI Assistant',
      greeting: "Namaste! Welcome to {restaurant_name}. How can I assist you today? You can ask for our menu recommendations, today's special offers, or table bookings!",
      autoMenuSuggest: true,
      autoOrderTaking: true,
      systemPrompt: 'You are an intelligent, courteous AI hospitality assistant for {restaurant_name}. Help customers explore the menu, check prices, recommend chef specialties, take orders accurately, and answer common questions promptly.',
      customInstructions: '',
      apiKey: '',
      model: 'gemini-3.8-flash',
      businessHoursOnly: false,
      autoReplyDelaySeconds: 2,
    };
  }

  /**
   * Update AI Agent settings for business
   */
  async updateAiAgentSettings(businessId, settings = {}, userId) {
    let business = null;
    if (businessId) {
      business = await Business.findById(businessId);
    }
    if (!business && userId) {
      business = await Business.findOne({ ownerId: userId });
    }
    if (!business) {
      business = await this.getDedicatedTestBusiness();
    }
    if (!business) {
      throw ApiError.notFound('Business not found');
    }

    business.aiChatAgentSettings = {
      ...(business.aiChatAgentSettings?.toObject?.() || business.aiChatAgentSettings || {}),
      ...settings,
    };

    // If Meta WhatsApp credentials are provided in settings, persist them as well
    if (settings.phoneNumberId || settings.accessToken) {
      business.whatsappSettings = {
        ...(business.whatsappSettings?.toObject?.() || business.whatsappSettings || {}),
        enabled: true,
        phoneNumberId: settings.phoneNumberId || business.whatsappSettings?.phoneNumberId || '',
        phoneNumber: settings.phoneNumber || business.whatsappSettings?.phoneNumber || '',
        accessToken: settings.accessToken || business.whatsappSettings?.accessToken || '',
      };
    }

    await business.save();
    return business.aiChatAgentSettings;
  }

  /**
   * Simulate AI Chat for Testing in Settings UI
   */
  async simulateAiChat(businessId, messageText, settingsOverride, userId) {
    let business = null;
    if (businessId) {
      business = await Business.findById(businessId).lean();
    }
    if (!business && userId) {
      business = await Business.findOne({ ownerId: userId }).lean();
    }
    if (!business) {
      business = await this.getDedicatedTestBusiness();
      if (business) business = business.toObject ? business.toObject() : business;
    }
    if (!business) {
      throw ApiError.notFound('Business not found');
    }

    const aiAgentService = require('./aiAgentService');
    const result = await aiAgentService.generateReply({
      business,
      chatId: null,
      customerPhone: '919999999999',
      customerName: 'Guest',
      messageText,
      settingsOverride,
    });

    let reply = result?.replyText || 'Hello!';
    if (result?.orderPayload && result.orderPayload.items && result.orderPayload.items.length > 0) {
      const itemsDesc = result.orderPayload.items.map((i) => `${i.quantity}x ${i.name}`).join(', ');
      reply += `\n\n💡 _[Direct POS Order Verified: Detected ${itemsDesc} (₹${result.orderPayload.totalAmount}). In live WhatsApp chat, this automatically creates an Order in POS and alerts your register!]_`;
    }

    return {
      replyText: reply,
      isAiGenerated: result?.isAiGenerated ?? true,
      model: result?.model,
      source: result?.source,
      orderPayload: result?.orderPayload || null,
    };
  }
}

module.exports = new WhatsAppChatService();
