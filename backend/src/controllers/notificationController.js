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
      const { token, platform, businessId } = req.body;
      const userId = req.user._id;

      await pushNotificationService.registerDeviceToken(
        userId,
        token,
        platform,
        businessId || req.user.businessId || req.business?._id
      );
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

  // GET /api/v1/notifications/settings
  async getSettings(req, res, next) {
    try {
      const userId = req.user._id;
      let businessId = req.business ? req.business._id : req.user.businessId;
      if (!businessId) {
        const biz = await Business.findOne({ ownerId: userId }).select('_id').lean();
        if (biz) businessId = biz._id;
      }

      const NotificationSetting = require('../models/NotificationSetting');
      let setting = null;
      if (businessId) {
        setting = await NotificationSetting.findOne({ businessId, userId }).lean();
      }

      if (!setting) {
        setting = {
          businessId: businessId || null,
          userId,
          notificationSound: 'default',
          notificationSoundName: 'Default Apna POS (Chime)',
          notificationSoundUrl: 'sounds/Notification_sound.mp3',
          notificationSoundType: 'default',
          orderRingtone: 'default',
          orderRingtoneName: 'Default Apna POS (Looping Alarm)',
          orderRingtoneUrl: 'sounds/order_recieve_ringtone.mp3',
          orderRingtoneType: 'default',
          soundEnabled: true,
          orderVolume: 1.0,
          notificationVolume: 1.0,
          vibrationEnabled: true,
          autoOpenOrderScreen: true,
          customRingtones: [],
        };
      }

      return ApiResponse.success(res, setting, 'Notification settings retrieved successfully');
    } catch (error) {
      next(error);
    }
  }

  // PUT /api/v1/notifications/settings
  async updateSettings(req, res, next) {
    try {
      const userId = req.user._id;
      let businessId = req.business ? req.business._id : (req.user.businessId || req.body.businessId);
      if (!businessId) {
        const biz = await Business.findOne({ ownerId: userId }).select('_id').lean();
        if (biz) businessId = biz._id;
      }

      if (!businessId) {
        return ApiResponse.error(res, 'Business ID is required to save notification settings', 400);
      }

      const NotificationSetting = require('../models/NotificationSetting');
      const updateData = {};
      const allowedFields = [
        'notificationSound',
        'notificationSoundName',
        'notificationSoundUrl',
        'notificationSoundType',
        'orderRingtone',
        'orderRingtoneName',
        'orderRingtoneUrl',
        'orderRingtoneType',
        'soundEnabled',
        'orderVolume',
        'notificationVolume',
        'vibrationEnabled',
        'autoOpenOrderScreen',
      ];

      for (const field of allowedFields) {
        if (req.body[field] !== undefined) {
          updateData[field] = req.body[field];
        }
      }

      const setting = await NotificationSetting.findOneAndUpdate(
        { businessId, userId },
        {
          $set: updateData,
          $setOnInsert: { businessId, userId },
        },
        { upsert: true, new: true, runValidators: true }
      );

      return ApiResponse.success(res, setting, 'Notification settings updated successfully');
    } catch (error) {
      next(error);
    }
  }

  // POST /api/v1/notifications/upload-ringtone
  async uploadRingtone(req, res, next) {
    try {
      if (!req.file) {
        return ApiResponse.error(res, 'Please upload an audio file (MP3, WAV, M4A, OGG, AAC)', 400);
      }

      const userId = req.user._id;
      let businessId = req.business ? req.business._id : req.user.businessId;
      if (!businessId) {
        const biz = await Business.findOne({ ownerId: userId }).select('_id').lean();
        if (biz) businessId = biz._id;
      }

      const type = req.body.type === 'notification' ? 'notification' : 'order';
      const ringtoneName = (req.body.name || req.file.originalname.replace(/\.[^/.]+$/, '')).trim();

      const storageService = require('../utils/storageService');
      let audioUrl = await storageService.uploadMedia(
        req.file.buffer,
        req.file.originalname,
        req.file.mimetype,
        'ringtones'
      );

      if (audioUrl && audioUrl.startsWith('/')) {
        const host = req.get('host');
        const proto = (req.headers['x-forwarded-proto'] || req.protocol || 'http').split(',')[0].trim();
        audioUrl = `${proto}://${host}${audioUrl}`;
      }

      const ringtoneItem = {
        id: `rt_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
        name: ringtoneName,
        url: audioUrl,
        type,
        sizeBytes: req.file.size || req.file.buffer.length,
        createdAt: new Date(),
      };

      if (businessId) {
        const NotificationSetting = require('../models/NotificationSetting');
        await NotificationSetting.findOneAndUpdate(
          { businessId, userId },
          {
            $push: { customRingtones: ringtoneItem },
            $setOnInsert: { businessId, userId },
          },
          { upsert: true }
        );
      }

      return ApiResponse.success(
        res,
        {
          ringtone: ringtoneItem,
          url: audioUrl,
          name: ringtoneName,
          type,
        },
        'Ringtone uploaded and saved successfully',
        201
      );
    } catch (error) {
      next(error);
    }
  }

  // DELETE /api/v1/notifications/custom-ringtone/:id
  async deleteCustomRingtone(req, res, next) {
    try {
      const { id } = req.params;
      const userId = req.user._id;
      let businessId = req.business ? req.business._id : req.user.businessId;
      if (!businessId) {
        const biz = await Business.findOne({ ownerId: userId }).select('_id').lean();
        if (biz) businessId = biz._id;
      }

      if (!businessId) {
        return ApiResponse.error(res, 'Business ID is required', 400);
      }

      const NotificationSetting = require('../models/NotificationSetting');
      const setting = await NotificationSetting.findOneAndUpdate(
        { businessId, userId },
        {
          $pull: { customRingtones: { id } },
        },
        { new: true }
      );

      return ApiResponse.success(res, setting, 'Custom ringtone deleted successfully');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new NotificationController();
