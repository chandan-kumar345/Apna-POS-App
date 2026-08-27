const notificationService = require('../services/notificationService');
const pushNotificationService = require('../services/pushNotificationService');
const cronService = require('../services/cronService');
const Business = require('../models/Business');
const ApiResponse = require('../utils/ApiResponse');

class NotificationController {
  // GET /api/v1/notifications
  async getNotifications(req, res, next) {
    try {
      const { page, limit, isRead, type } = req.query;
      const userId = req.user._id;
      const businessId = req.business ? req.business._id : req.user.businessId;

      const result = await notificationService.getNotifications(businessId, userId, {
        page,
        limit,
        isRead,
        type,
      });

      return ApiResponse.success(res, result, 'Notifications retrieved successfully');
    } catch (error) {
      next(error);
    }
  }

  // GET /api/v1/notifications/unread-count
  async getUnreadCount(req, res, next) {
    try {
      const userId = req.user._id;
      const businessId = req.business ? req.business._id : req.user.businessId;

      const result = await notificationService.getUnreadCount(businessId, userId);
      return ApiResponse.success(res, result, 'Unread count retrieved');
    } catch (error) {
      next(error);
    }
  }

  // PATCH /api/v1/notifications/:id/read
  async markAsRead(req, res, next) {
    try {
      const { id } = req.params;
      const userId = req.user._id;
      const businessId = req.business ? req.business._id : req.user.businessId;

      const result = await notificationService.markAsRead(id, businessId, userId);
      return ApiResponse.success(res, result, 'Notification marked as read');
    } catch (error) {
      next(error);
    }
  }

  // PATCH /api/v1/notifications/read-all
  async markAllAsRead(req, res, next) {
    try {
      const userId = req.user._id;
      const businessId = req.business ? req.business._id : req.user.businessId;

      const result = await notificationService.markAllAsRead(businessId, userId);
      return ApiResponse.success(res, result, 'All notifications marked as read');
    } catch (error) {
      next(error);
    }
  }

  // DELETE /api/v1/notifications/:id
  async deleteNotification(req, res, next) {
    try {
      const { id } = req.params;
      const userId = req.user._id;
      const businessId = req.business ? req.business._id : req.user.businessId;

      const result = await notificationService.deleteNotification(id, businessId, userId);
      return ApiResponse.success(res, result, 'Notification deleted');
    } catch (error) {
      next(error);
    }
  }

  // DELETE /api/v1/notifications/clear-all
  async clearAll(req, res, next) {
    try {
      const userId = req.user._id;
      const businessId = req.business ? req.business._id : req.user.businessId;

      const result = await notificationService.clearAll(businessId, userId);
      return ApiResponse.success(res, result, 'All notifications cleared');
    } catch (error) {
      next(error);
    }
  }

  // POST /api/v1/notifications/device-token
  async registerDeviceToken(req, res, next) {
    try {
      const { token, platform } = req.body;
      const userId = req.user._id;

      await pushNotificationService.registerDeviceToken(userId, token, platform);
      return ApiResponse.success(res, { registered: true }, 'Device token registered');
    } catch (error) {
      next(error);
    }
  }

  // POST /api/v1/notifications/trigger-daily-summary (Admin / Testing endpoint)
  async triggerDailySummary(req, res, next) {
    try {
      const { targetDate } = req.body;
      const userId = req.user._id;
      let business = req.business;
      if (!business) {
        business = await Business.findOne({ ownerId: userId });
      }

      if (!business) {
        return ApiResponse.error(res, 'No business found for current user', 404);
      }

      const notification = await cronService.generateDailySummaryForBusiness(business, targetDate);
      return ApiResponse.success(
        res,
        { notification },
        'Daily summary notification generated successfully'
      );
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new NotificationController();
