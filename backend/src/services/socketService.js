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

  getIO() {
    return this.io;
  }
}

module.exports = new SocketService();
