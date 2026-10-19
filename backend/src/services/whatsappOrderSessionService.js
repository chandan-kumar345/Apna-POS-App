const mongoose = require('mongoose');
const Order = require('../models/Order');

class WhatsAppOrderSessionService {
  constructor() {
    // Map of sessionKey (`${businessId}:${customerPhone}`) -> Session Object
    this._sessions = new Map();
    // Map of sessionKey -> Promise chain for sequential execution per customer
    this._queues = new Map();
    // Cleanup stale sessions every 10 minutes (TTL: 30 minutes)
    const cleanupTimer = setInterval(() => this._cleanupStaleSessions(), 10 * 60 * 1000);
    if (cleanupTimer.unref) cleanupTimer.unref();
  }

  /**
   * Build unique isolation key per business profile and customer phone
   */
  _buildKey(businessId, customerPhone) {
    const bId = (businessId?._id || businessId || '').toString().trim();
    const cleanPhone = (customerPhone || '').replace(/\D/g, '').slice(-10);
    return `${bId}:${cleanPhone}`;
  }

  /**
   * Enqueue a task for a specific customer to guarantee strict message sequence
   * while allowing multiple different customers to process fully in parallel.
   */
  async enqueue(businessId, customerPhone, taskFn) {
    const key = this._buildKey(businessId, customerPhone);
    const previousPromise = this._queues.get(key) || Promise.resolve();

    const currentPromise = (async () => {
      try {
        await previousPromise;
      } catch (_) {
        // Ignore previous errors so subsequent messages are not blocked
      }
      return await taskFn();
    })();

    // Store chain and clean up when complete
    this._queues.set(key, currentPromise);
    currentPromise.finally(() => {
      if (this._queues.get(key) === currentPromise) {
        this._queues.delete(key);
      }
    });

    return currentPromise;
  }

  /**
   * Get or initialize session state for a customer
   */
  getSession(businessId, customerPhone) {
    const key = this._buildKey(businessId, customerPhone);
    let session = this._sessions.get(key);
    if (!session) {
      session = {
        businessId: (businessId?._id || businessId).toString(),
        customerPhone: (customerPhone || '').replace(/\D/g, ''),
        recentOrderId: null,
        recentOrderNumber: null,
        orderType: null,
        deliveryAddress: '',
        lastIntent: null,
        lastActiveAt: new Date(),
      };
      this._sessions.set(key, session);
    } else {
      session.lastActiveAt = new Date();
    }
    return session;
  }

  /**
   * Update active customer session state
   */
  updateSession(businessId, customerPhone, updates = {}) {
    const session = this.getSession(businessId, customerPhone);
    Object.assign(session, updates, { lastActiveAt: new Date() });
    return session;
  }

  /**
   * Record a newly placed order in the customer's session
   */
  recordOrder(businessId, customerPhone, order) {
    if (!order) return;
    const session = this.getSession(businessId, customerPhone);
    session.recentOrderId = order._id ? order._id.toString() : order.id;
    session.recentOrderNumber = order.orderNumber;
    session.orderType = order.orderType || 'takeaway';
    session.deliveryAddress = order.deliveryAddress || '';
    session.lastIntent = order.orderType === 'delivery' && !order.deliveryAddress ? 'awaiting_address' : 'order_placed';
    session.lastActiveAt = new Date();
    return session;
  }

  /**
   * Check if customer message is providing a delivery address or updating order type
   * for an active recent pending order (placed within the last 20 minutes)
   */
  async handleAddressOrTypeUpdate({
    businessId,
    customerPhone,
    messageText,
    chat,
    targetUserId,
  }) {
    if (!messageText || !messageText.trim()) return null;
    const raw = messageText.trim();
    const rawLower = raw.toLowerCase();

    const session = this.getSession(businessId, customerPhone);

    // Look for recent pending order in session OR directly in DB
    let activeOrder = null;
    if (session.recentOrderId) {
      activeOrder = await Order.findOne({
        _id: session.recentOrderId,
        status: { $in: ['pending', 'preparing'] },
      });
    }

    if (!activeOrder) {
      // Find latest pending order placed by this customer in the last 25 minutes
      const twentyFiveMinsAgo = new Date(Date.now() - 25 * 60 * 1000);
      const cleanPhone = (customerPhone || '').replace(/\D/g, '');
      const last10 = cleanPhone.slice(-10);

      activeOrder = await Order.findOne({
        businessId: businessId?._id || businessId,
        customerPhone: { $in: [cleanPhone, last10, `+91${last10}`, `91${last10}`] },
        status: 'pending',
        createdAt: { $gte: twentyFiveMinsAgo },
      }).sort({ createdAt: -1 });
    }

    if (!activeOrder) return null;

    // 1. Detect Takeaway intent
    const isTakeawayRequest =
      /\b(takeaway|take\s*away|parcel|pack\s*kar\s*do|parcel\s*kar\s*do|pickup|pick\s*up|le\s*jaana\s*hai)\b/i.test(rawLower);

    if (isTakeawayRequest) {
      activeOrder.orderType = 'takeaway';
      activeOrder.deliveryAddress = '';
      await activeOrder.save();

      this.updateSession(businessId, customerPhone, {
        recentOrderId: activeOrder._id.toString(),
        recentOrderNumber: activeOrder.orderNumber,
        orderType: 'takeaway',
        deliveryAddress: '',
        lastIntent: 'takeaway_confirmed',
      });

      // Broadcast update to POS terminals
      this._emitOrderUpdateToPOS(businessId, activeOrder, chat, targetUserId);

      return {
        isHandled: true,
        replyText: `🛍️ *ORDER UPDATED TO TAKEAWAY — #${activeOrder.orderNumber}* 🛍️\n━━━━━━━━━━━━━━━━━━━━\n📦 *Order Type*: *Takeaway / Pickup*\n💰 *Total Amount*: *₹${activeOrder.totalAmount}*\n⏳ *Status*: 🕒 *Awaiting Restaurant Confirmation*\n━━━━━━━━━━━━━━━━━━━━\n🙏 _Your order will be packed fresh and ready for pickup at our counter!_ 🚀`,
      };
    }

    // 2. Detect Delivery Address or Delivery Intent
    const isExplicitDelivery = /\b(delivery|deliver|ghar\s*pe|ghar\s*par|home\s*delivery)\b/i.test(rawLower);
    const hasAddressPatterns =
      /(?:flat|room|house|h\.no|block|plot|sector|colony|apartment|society|nagar|road|street|gali|lane|floor|building|tower|near|behind|opp|opposite|pincode|\d{6})/i.test(rawLower);
    const isLikelyAddressText =
      hasAddressPatterns ||
      (session.lastIntent === 'awaiting_address' && raw.length >= 8 && !rawLower.includes('menu'));

    if (isExplicitDelivery || isLikelyAddressText) {
      let cleanAddress = raw;
      // Strip out leading prefixes like "deliver to", "my address is", "address:"
      cleanAddress = cleanAddress
        .replace(/^(?:please\s+)?(?:deliver\s+(?:to|at)|delivery\s+(?:to|at)|(?:my\s+)?address\s*(?:is|:)?|home\s+delivery\s+(?:to|at)?|send\s+(?:to|at)|ship\s+(?:to|at))\s*/i, '')
        .trim();

      if (cleanAddress.length < 5 && isExplicitDelivery) {
        // Asked for delivery but didn't provide address text
        activeOrder.orderType = 'delivery';
        await activeOrder.save();

        this.updateSession(businessId, customerPhone, {
          recentOrderId: activeOrder._id.toString(),
          recentOrderNumber: activeOrder.orderNumber,
          orderType: 'delivery',
          lastIntent: 'awaiting_address',
        });

        this._emitOrderUpdateToPOS(businessId, activeOrder, chat, targetUserId);

        return {
          isHandled: true,
          replyText: `🛵 *HOME DELIVERY REQUESTED — #${activeOrder.orderNumber}* 🛵\n━━━━━━━━━━━━━━━━━━━━\n💰 *Total Amount*: *₹${activeOrder.totalAmount}*\n\n📍 *Please share your complete delivery address:*\n_(House/Flat No, Landmark, Area/Sector, Road)_\n━━━━━━━━━━━━━━━━━━━━\n🛵 _Once you send your address, we will dispatch our delivery partner immediately!_`,
        };
      }

      if (cleanAddress.length >= 5) {
        activeOrder.orderType = 'delivery';
        activeOrder.deliveryAddress = cleanAddress;
        await activeOrder.save();

        this.updateSession(businessId, customerPhone, {
          recentOrderId: activeOrder._id.toString(),
          recentOrderNumber: activeOrder.orderNumber,
          orderType: 'delivery',
          deliveryAddress: cleanAddress,
          lastIntent: 'address_confirmed',
        });

        // Broadcast update to POS terminals
        this._emitOrderUpdateToPOS(businessId, activeOrder, chat, targetUserId);

        return {
          isHandled: true,
          replyText: `🛵 *DELIVERY ADDRESS RECORDED — #${activeOrder.orderNumber}* 🛵\n━━━━━━━━━━━━━━━━━━━━\n📍 *Deliver To*: *${cleanAddress}*\n💰 *Total Amount*: *₹${activeOrder.totalAmount}*\n🛵 *Type*: *Home Delivery*\n⏳ *Status*: 🕒 *Awaiting Restaurant Confirmation*\n━━━━━━━━━━━━━━━━━━━━\n🙏 _The kitchen and delivery desk have received your address! We will notify you once your order is accepted and out for delivery._ 🚀`,
        };
      }
    }

    return null;
  }

  /**
   * Helper to broadcast updated order to POS terminals in real time
   */
  _emitOrderUpdateToPOS(businessId, order, chat, targetUserId) {
    try {
      const bId = (businessId?._id || businessId).toString();
      const socketService = require('./socketService');
      socketService.emitWhatsAppOrderRequest(bId, {
        order: order.toJSON ? order.toJSON() : order,
        chat,
        customerPhone: order.customerPhone,
        customerName: order.customerName,
        targetUserId,
      });
    } catch (err) {
      console.warn('[WhatsAppOrderSessionService] Error emitting order update to socket:', err.message);
    }

    try {
      const pushNotificationService = require('./pushNotificationService');
      const bId = (businessId?._id || businessId).toString();
      pushNotificationService.sendPushNotificationToBusiness({
        businessId: bId,
        title: `🛵 Order Updated: #${order.orderNumber}`,
        message: `${order.orderType === 'delivery' ? 'Delivery Address Added' : 'Updated to Takeaway'}: ${order.deliveryAddress || 'Counter Pickup'}`,
        data: {
          type: 'whatsapp_order_request',
          orderId: order._id.toString(),
          orderNumber: order.orderNumber,
          customerPhone: order.customerPhone || '',
          customerName: order.customerName || '',
          totalAmount: String(order.totalAmount || 0),
          orderType: order.orderType,
          deliveryAddress: order.deliveryAddress || '',
          items: JSON.stringify(order.items || []),
          createdAt: (order.createdAt || new Date()).toISOString(),
        },
      }).catch((e) => console.warn('[WhatsAppOrderSessionService] Push dispatch notice:', e.message));
    } catch (_) {}
  }

  /**
   * Periodically remove sessions inactive for > 30 minutes to conserve memory
   */
  _cleanupStaleSessions() {
    const cutoff = Date.now() - 30 * 60 * 1000;
    for (const [key, session] of this._sessions.entries()) {
      if (session.lastActiveAt && session.lastActiveAt.getTime() < cutoff) {
        this._sessions.delete(key);
      }
    }
  }
}

module.exports = new WhatsAppOrderSessionService();
