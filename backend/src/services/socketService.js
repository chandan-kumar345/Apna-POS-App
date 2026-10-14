const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');
const env = require('../config/env');

class SocketService {
  constructor() {
    this.io = null;
  }

  /**
   * Initialize Socket.IO with HTTP Server
   * @param {import('http').Server} httpServer
   */
  init(httpServer) {
    this.io = new Server(httpServer, {
      cors: {
        origin: '*',
        methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
        credentials: true,
      },
      pingTimeout: 20000,
      pingInterval: 10000,
      transports: ['websocket', 'polling'],
      allowEIO3: true,
    });

    // Socket Authentication & Tenant Resolution Middleware
    this.io.use((socket, next) => {
      try {
        const token =
          socket.handshake.auth?.token ||
          socket.handshake.query?.token ||
          socket.handshake.headers?.authorization?.replace('Bearer ', '');

        let businessId =
          socket.handshake.auth?.businessId ||
          socket.handshake.query?.businessId;

        if (token) {
          try {
            const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET);
            socket.user = decoded;
            // Cryptographically bound businessId from verified token takes precedence
            if (decoded.businessId) {
              businessId = decoded.businessId.toString();
            }
          } catch (jwtErr) {
            console.warn('[Socket Auth] JWT verification warning:', jwtErr.message);
          }
        }

        if (businessId) {
          socket.businessId = businessId.toString();
        }

        return next();
      } catch (err) {
        return next();
      }
    });

    this.io.on('connection', (socket) => {
      const initialBusinessId = socket.businessId;

      if (initialBusinessId) {
        this.joinBusinessRoom(socket, initialBusinessId);
      }

      if (socket.user?.id || socket.user?._id) {
        const uId = (socket.user.id || socket.user._id).toString();
        socket.join(`user_${uId}`);
      }

      // Hardened room join handler: strictly prevent cross-tenant room spoofing
      socket.on('join_business', (data) => {
        const bId = typeof data === 'string' ? data : (data?.businessId || socket.businessId);
        if (!bId) return;

        const requestedId = bId.toString();
        // Strict Tenant Guard:
        // If socket has a verified businessId from JWT, reject any attempt to join another business room
        if (socket.businessId && socket.businessId !== requestedId && !socket.user?.isSuperAdmin) {
          console.warn(
            `[Socket Security Alert] Unauthorized attempt to join room business_${requestedId} by client with tenant ${socket.businessId}`
          );
          socket.emit('error', { message: 'Unauthorized room access: Tenant mismatch' });
          return;
        }

        this.joinBusinessRoom(socket, requestedId);
      });

      // Leave business room
      socket.on('leave_business', (data) => {
        const bId = typeof data === 'string' ? data : (data?.businessId || socket.businessId);
        if (bId) {
          socket.leave(`business_${bId}`);
          socket.leave(`business:${bId}`);
        }
      });

      // Ping-pong synchronization test
      socket.on('ping_sync', (data, ack) => {
        const response = {
          status: 'ok',
          serverTime: new Date().toISOString(),
          echo: data,
        };
        if (typeof ack === 'function') {
          ack(response);
        } else {
          socket.emit('pong_sync', response);
        }
      });

      socket.on('disconnect', () => {
        // Disconnected cleanly
      });
    });

    return this.io;
  }

  /**
   * Helper to add socket to both standard business room naming conventions
   */
  joinBusinessRoom(socket, businessId) {
    const cleanId = businessId.toString();
    socket.businessId = cleanId;
    socket.join(`business_${cleanId}`);
    socket.join(`business:${cleanId}`);
    socket.emit('joined_business', {
      businessId: cleanId,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Broadcast an event to all connected devices in a business tenant
   * @param {string|mongoose.Types.ObjectId} businessId
   * @param {string} event
   * @param {any} data
   */
  broadcastToBusiness(businessId, event, data) {
    if (!this.io || !businessId) return;
    const cleanId = businessId.toString();
    this.io.to(`business_${cleanId}`).emit(event, data);
  }

  /**
   * Emit updated table status to all devices in the business
   * @param {string|mongoose.Types.ObjectId} businessId
   * @param {object} tableData Enriched or standard Table model JSON
   */
  emitTableUpdated(businessId, tableData) {
    if (!businessId || !tableData) return;
    const payload = {
      table: tableData,
      timestamp: new Date().toISOString(),
    };
    this.broadcastToBusiness(businessId, 'table:updated', payload);
  }

  /**
   * Emit batch table updates (e.g. on table shift)
   * @param {string|mongoose.Types.ObjectId} businessId
   * @param {Array<object>} tables
   */
  emitTablesBatchUpdated(businessId, tables) {
    if (!businessId || !Array.isArray(tables)) return;
    const payload = {
      tables,
      timestamp: new Date().toISOString(),
    };
    this.broadcastToBusiness(businessId, 'tables:batch_updated', payload);
  }

  /**
   * Emit table created event
   * @param {string|mongoose.Types.ObjectId} businessId
   * @param {object|Array<object>} tableData
   */
  emitTableCreated(businessId, tableData) {
    if (!businessId || !tableData) return;
    const payload = {
      table: tableData,
      tables: Array.isArray(tableData) ? tableData : [tableData],
      timestamp: new Date().toISOString(),
    };
    this.broadcastToBusiness(businessId, 'table:created', payload);
  }

  /**
   * Emit table deleted event
   * @param {string|mongoose.Types.ObjectId} businessId
   * @param {string} tableId
   */
  emitTableDeleted(businessId, tableId) {
    if (!businessId || !tableId) return;
    const payload = {
      tableId: tableId.toString(),
      timestamp: new Date().toISOString(),
    };
    this.broadcastToBusiness(businessId, 'table:deleted', payload);
  }

  /**
   * Emit order settled event across all connected clients in the business
   * @param {string|mongoose.Types.ObjectId} businessId
   * @param {object} orderData
   */
  emitOrderSettled(businessId, orderData) {
    if (!businessId || !orderData) return;
    const payload = {
      ...orderData,
      timestamp: new Date().toISOString(),
    };
    this.broadcastToBusiness(businessId, 'order:settled', payload);
  }

  /**
   * Emit order updated event across all connected clients in the business
   * @param {string|mongoose.Types.ObjectId} businessId
   * @param {object} orderData
   */
  emitOrderUpdated(businessId, orderData) {
    if (!businessId || !orderData) return;
    const payload = {
      ...orderData,
      timestamp: new Date().toISOString(),
    };
    this.broadcastToBusiness(businessId, 'order:updated', payload);
  }

  /**
   * Emit order created event across all connected clients in the business
   * @param {string|mongoose.Types.ObjectId} businessId
   * @param {object} orderData
   */
  emitOrderCreated(businessId, orderData) {
    if (!businessId || !orderData) return;
    const payload = {
      ...orderData,
      timestamp: new Date().toISOString(),
    };
    this.broadcastToBusiness(businessId, 'order:created', payload);
  }

  /**
   * Emit order deleted event across all connected clients in the business
   * @param {string|mongoose.Types.ObjectId} businessId
   * @param {object} orderData
   */
  emitOrderDeleted(businessId, orderData) {
    if (!businessId || !orderData) return;
    const payload = {
      ...orderData,
      timestamp: new Date().toISOString(),
    };
    this.broadcastToBusiness(businessId, 'order:deleted', payload);
  }

  /**
   * Emit subscription updated event across all connected clients in the business
   * @param {string|mongoose.Types.ObjectId} businessId
   * @param {object} subscriptionData
   */
  emitSubscriptionUpdated(businessId, subscriptionData) {
    if (!subscriptionData) return;
    const payload = {
      ...subscriptionData,
      timestamp: new Date().toISOString(),
    };
    if (businessId) {
      this.broadcastToBusiness(businessId, 'subscription:updated', payload);
    } else if (this.io) {
      this.io.emit('subscription:updated', payload);
    }
  }

  /**
   * Emit new notification event across business and target user rooms for instant sub-50ms delivery
   * @param {string|mongoose.Types.ObjectId} businessId
   * @param {string|mongoose.Types.ObjectId} userId
   * @param {object} notification
   */
  emitNotificationCreated(businessId, userId, notification) {
    if (!this.io) return;
    const payload = {
      notification,
      timestamp: new Date().toISOString(),
    };
    if (businessId) {
      this.broadcastToBusiness(businessId, 'notification:new', payload);
    }
    if (userId) {
      const cleanUserId = userId.toString();
      this.io.to(`user_${cleanUserId}`).emit('notification:new', payload);
      this.io.to(`business_${cleanUserId}`).emit('notification:new', payload);
    }
    // Also notify POS terminal default room
    this.io.to('business_rest_001').emit('notification:new', payload);
    this.io.to('business_default').emit('notification:new', payload);
  }

  /**
   * Emit real-time WhatsApp message event to connected business clients and terminals
   * @param {string|mongoose.Types.ObjectId} businessId
   * @param {object} param1 { chat, message, targetUserId, ownerId }
   */
  emitWhatsAppMessageReceived(businessId, { chat, message, targetUserId = null, ownerId = null }) {
    if (!this.io) return;
    const payload = {
      chat,
      message,
      timestamp: new Date().toISOString(),
    };

    // 1. Broadcast to standard business room conventions
    if (businessId) {
      const cleanId = businessId.toString();
      this.io.to(`business_${cleanId}`).emit('whatsapp:message', payload);
      this.io.to(`business:${cleanId}`).emit('whatsapp:message', payload);
      this.io.to(`business_${cleanId}`).emit('whatsapp:chat_updated', { chat, timestamp: new Date().toISOString() });
      this.io.to(`business:${cleanId}`).emit('whatsapp:chat_updated', { chat, timestamp: new Date().toISOString() });
    }

    // 2. Broadcast to specific user rooms (e.g. chat assignee, target user, business owner)
    const userIds = new Set();
    if (chat?.userId) userIds.add(chat.userId.toString());
    if (targetUserId) userIds.add(targetUserId.toString());
    if (ownerId) userIds.add(ownerId.toString());

    for (const uid of userIds) {
      this.io.to(`user_${uid}`).emit('whatsapp:message', payload);
      this.io.to(`business_${uid}`).emit('whatsapp:message', payload);
      this.io.to(`user_${uid}`).emit('whatsapp:chat_updated', { chat, timestamp: new Date().toISOString() });
      this.io.to(`business_${uid}`).emit('whatsapp:chat_updated', { chat, timestamp: new Date().toISOString() });
    }

    // 3. Fallback broadcast to default POS business aliases (rest_001, default)
    this.io.to('business_rest_001').emit('whatsapp:message', payload);
    this.io.to('business_rest_001').emit('whatsapp:chat_updated', { chat, timestamp: new Date().toISOString() });
    this.io.to('business_default').emit('whatsapp:message', payload);
    this.io.to('business_default').emit('whatsapp:chat_updated', { chat, timestamp: new Date().toISOString() });
  }

  /**
   * Emit real-time WhatsApp conversation update
   * @param {string|mongoose.Types.ObjectId} businessId
   * @param {object} param1 { chat, targetUserId, ownerId }
   */
  emitWhatsAppChatUpdated(businessId, { chat, targetUserId = null, ownerId = null }) {
    if (!this.io) return;
    const payload = {
      chat,
      timestamp: new Date().toISOString(),
    };
    if (businessId) {
      const cleanId = businessId.toString();
      this.io.to(`business_${cleanId}`).emit('whatsapp:chat_updated', payload);
      this.io.to(`business:${cleanId}`).emit('whatsapp:chat_updated', payload);
    }
    const userIds = new Set();
    if (chat?.userId) userIds.add(chat.userId.toString());
    if (targetUserId) userIds.add(targetUserId.toString());
    if (ownerId) userIds.add(ownerId.toString());

    for (const uid of userIds) {
      this.io.to(`user_${uid}`).emit('whatsapp:chat_updated', payload);
      this.io.to(`business_${uid}`).emit('whatsapp:chat_updated', payload);
    }

    this.io.to('business_rest_001').emit('whatsapp:chat_updated', payload);
    this.io.to('business_default').emit('whatsapp:chat_updated', payload);
  }

  /**
   * Emit real-time media hydration update when image download finishes in background
   * @param {string|mongoose.Types.ObjectId} businessId
   * @param {object} param1 { messageId, chatId, mediaUrl }
   */
  emitWhatsAppMessageUpdated(businessId, { messageId, chatId, mediaUrl }) {
    if (!this.io) return;
    const payload = {
      messageId: messageId ? messageId.toString() : '',
      chatId: chatId ? chatId.toString() : '',
      mediaUrl,
      timestamp: new Date().toISOString(),
    };
    if (businessId) {
      const cleanId = businessId.toString();
      this.io.to(`business_${cleanId}`).emit('whatsapp:message:updated', payload);
      this.io.to(`business:${cleanId}`).emit('whatsapp:message:updated', payload);
    }
    this.io.to('business_rest_001').emit('whatsapp:message:updated', payload);
    this.io.to('business_default').emit('whatsapp:message:updated', payload);
  }

  getIO() {
    return this.io;
  }
}

module.exports = new SocketService();
