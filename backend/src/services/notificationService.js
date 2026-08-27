const mongoose = require('mongoose');
const { Notification } = require('../models/Notification');
const pushNotificationService = require('./pushNotificationService');
const ApiError = require('../utils/ApiError');

class NotificationService {
  /**
   * Create a notification record with idempotency and asynchronous push notification trigger
   */
  async createNotification({
    userId,
    businessId,
    type,
    title,
    message,
    entityType = 'system',
    entityId = null,
    metadata = {},
    idempotencyKey = null,
    sendPush = true,
  }) {
    try {
      if (!title || !message || !type) {
        throw ApiError.badRequest('Notification title, message, and type are required');
      }

      // Check idempotency if key provided
      if (idempotencyKey) {
        const existing = await Notification.findOne({ idempotencyKey }).lean();
        if (existing) {
          return existing;
        }
      }

      const notification = await Notification.create({
        userId: userId ? new mongoose.Types.ObjectId(userId) : undefined,
        businessId: businessId ? new mongoose.Types.ObjectId(businessId) : undefined,
        type,
        title: title.trim(),
        message: message.trim(),
        entityType,
        entityId: entityId ? entityId.toString() : null,
        metadata: metadata || {},
        idempotencyKey: idempotencyKey || undefined,
        isRead: false,
      });

      // Dispatch push notification asynchronously without blocking response
      if (sendPush && userId) {
        setImmediate(() => {
          pushNotificationService.sendPushNotification({
            userId,
            title: notification.title,
            message: notification.message,
            data: {
              notificationId: notification._id.toString(),
              type: notification.type,
              entityType: notification.entityType,
              entityId: notification.entityId || '',
              ...notification.metadata,
            },
          });
        });
      }

      return notification;
    } catch (error) {
      // If duplicate key error due to race condition, return existing document
      if (error.code === 11000 && idempotencyKey) {
        return Notification.findOne({ idempotencyKey }).lean();
      }
      console.error(`[NotificationService] Error creating notification: ${error.message}`);
      throw error;
    }
  }

  /**
   * Get paginated notifications for a business / user
   */
  async getNotifications(businessId, userId, { page = 1, limit = 20, isRead, type } = {}) {
    const query = {};

    const bId = businessId && mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : null;
    const uId = userId && mongoose.Types.ObjectId.isValid(userId)
      ? new mongoose.Types.ObjectId(userId)
      : null;

    if (bId && uId) {
      query.$or = [{ businessId: bId }, { userId: uId }];
    } else if (bId) {
      query.businessId = bId;
    } else if (uId) {
      query.userId = uId;
    }

    if (isRead !== undefined && isRead !== null && isRead !== '') {
      query.isRead = isRead === true || isRead === 'true';
    }

    if (type && type !== 'All' && type !== 'all') {
      const typeLower = type.toString().toLowerCase();
      if (typeLower === 'orders' || typeLower === 'order') {
        query.type = 'new_order';
      } else if (typeLower === 'crm' || typeLower === 'leads' || typeLower === 'lead') {
        query.type = 'new_lead';
      } else if (typeLower === 'summary' || typeLower === 'daily' || typeLower === 'daily_sales_summary') {
        query.type = 'daily_sales_summary';
      } else if (typeLower === 'inventory' || typeLower === 'stock') {
        query.type = 'low_stock';
      } else {
        query.type = type;
      }
    }

    const parsedPage = Math.max(1, parseInt(page, 10) || 1);
    const parsedLimit = Math.max(1, Math.min(100, parseInt(limit, 10) || 20));
    const skip = (parsedPage - 1) * parsedLimit;

    const [notifications, total, unreadCount] = await Promise.all([
      Notification.find(query).sort({ createdAt: -1 }).skip(skip).limit(parsedLimit).lean(),
      Notification.countDocuments(query),
      Notification.countDocuments({ ...query, isRead: false }),
    ]);

    return {
      notifications: notifications.map((n) => ({
        ...n,
        id: n._id.toString(),
      })),
      pagination: {
        total,
        page: parsedPage,
        limit: parsedLimit,
        totalPages: Math.ceil(total / parsedLimit),
      },
      unreadCount,
    };
  }

  /**
   * Get unread notification count
   */
  async getUnreadCount(businessId, userId) {
    const query = { isRead: false };
    if (businessId) {
      query.businessId = businessId;
    } else if (userId) {
      query.userId = userId;
    }
    const count = await Notification.countDocuments(query);
    return { unreadCount: count };
  }

  /**
   * Mark a single notification as read
   */
  async markAsRead(notificationId, businessId, userId) {
    const notifId = mongoose.Types.ObjectId.isValid(notificationId)
      ? new mongoose.Types.ObjectId(notificationId)
      : notificationId;

    const query = { _id: notifId };
    if (businessId) query.businessId = businessId;

    const notification = await Notification.findOneAndUpdate(
      query,
      { $set: { isRead: true, readAt: new Date() } },
      { new: true }
    );

    if (!notification) {
      throw ApiError.notFound('Notification not found');
    }

    return {
      ...notification.toObject(),
      id: notification._id.toString(),
    };
  }

  /**
   * Mark all notifications as read for a business / user
   */
  async markAllAsRead(businessId, userId) {
    const query = { isRead: false };
    if (businessId) {
      query.businessId = businessId;
    } else if (userId) {
      query.userId = userId;
    }

    const result = await Notification.updateMany(query, {
      $set: { isRead: true, readAt: new Date() },
    });

    return {
      success: true,
      modifiedCount: result.modifiedCount,
      message: 'All notifications marked as read',
    };
  }

  /**
   * Delete a single notification
   */
  async deleteNotification(notificationId, businessId, userId) {
    const notifId = mongoose.Types.ObjectId.isValid(notificationId)
      ? new mongoose.Types.ObjectId(notificationId)
      : notificationId;

    const query = { _id: notifId };
    if (businessId) query.businessId = businessId;

    const deleted = await Notification.findOneAndDelete(query);
    if (!deleted) {
      throw ApiError.notFound('Notification not found');
    }

    return {
      success: true,
      message: 'Notification deleted successfully',
    };
  }

  /**
   * Clear all notifications for business / user
   */
  async clearAll(businessId, userId) {
    const query = {};
    if (businessId) {
      query.businessId = businessId;
    } else if (userId) {
      query.userId = userId;
    }

    const result = await Notification.deleteMany(query);
    return {
      success: true,
      deletedCount: result.deletedCount,
      message: 'All notifications cleared successfully',
    };
  }
}

module.exports = new NotificationService();
