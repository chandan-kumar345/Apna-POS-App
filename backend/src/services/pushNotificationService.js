const User = require('../models/User');

class PushNotificationService {
  constructor() {
    this.deviceTokens = new Map(); // Local in-memory registry fallback
    this.userTokenCache = new Map(); // userId -> { token, platform, timestamp }
    this.businessTokensCache = new Map(); // businessId -> { users: [...], timestamp }
    this.CACHE_TTL_MS = 60000; // 60 seconds TTL for token cache
  }

  /**
   * Register device push token for a user
   */
  async registerDeviceToken(userId, token, platform = 'android') {
    try {
      if (!userId || !token) return;
      const uid = userId.toString();
      this.deviceTokens.set(uid, token);
      this.userTokenCache.set(uid, { token, platform, timestamp: Date.now() });
      this.businessTokensCache.clear(); // Invalidate business cache

      // Persist to user model if field exists
      await User.findByIdAndUpdate(userId, {
        $set: {
          pushToken: token,
          pushPlatform: platform,
          lastActiveAt: new Date(),
        },
      }).catch(() => {});
    } catch (error) {
      console.warn(`[PushNotificationService] Error registering token: ${error.message}`);
    }
  }

  /**
   * Remove device push token upon logout
   */
  async removeDeviceToken(userId) {
    try {
      if (!userId) return;
      const uid = userId.toString();
      this.deviceTokens.delete(uid);
      this.userTokenCache.delete(uid);
      this.businessTokensCache.clear();
      await User.findByIdAndUpdate(userId, {
        $unset: { pushToken: 1, pushPlatform: 1 },
      }).catch(() => {});
    } catch (error) {
      console.warn(`[PushNotificationService] Error removing token: ${error.message}`);
    }
  }

  /**
   * Send push notification asynchronously (non-blocking)
   */
  async sendPushNotification({ userId, token: explicitToken, platform: explicitPlatform, title, message, data = {} }) {
    try {
      const uid = userId ? userId.toString() : null;
      let token = explicitToken || (uid ? this.deviceTokens.get(uid) : null);
      let platform = explicitPlatform || 'android';

      if (!token && uid) {
        const cached = this.userTokenCache.get(uid);
        if (cached && Date.now() - cached.timestamp < this.CACHE_TTL_MS) {
          token = cached.token;
          platform = cached.platform || platform;
        } else {
          const user = await User.findById(uid).select('pushToken pushPlatform').lean();
          if (user && user.pushToken) {
            token = user.pushToken;
            platform = user.pushPlatform || 'android';
            this.deviceTokens.set(uid, token);
            this.userTokenCache.set(uid, { token, platform, timestamp: Date.now() });
          }
        }
      }

      if (!token) {
        if (process.env.NODE_ENV !== 'test') {
          console.log(`[PushNotificationService] Push skipped (no device token for ${userId}): "${title}"`);
        }
        return;
      }

      const isOrderRequest = data.type === 'whatsapp_order_request' || data.type === 'whatsapp_new_order' || data.type === 'whatsapp_order';
      const isWhatsApp = data.type === 'whatsapp_message' || data.type === 'whatsappMessage';
      const channelId = isOrderRequest
        ? 'apna_pos_whatsapp_orders_v1'
        : (isWhatsApp ? 'apna_pos_whatsapp_messages_v1' : 'apna_pos_general_v2');

      // Sanitize all data entries into strings (FCM requirement for data payload)
      const sanitizedData = {};
      for (const [key, val] of Object.entries({ title, message, ...data })) {
        if (val !== undefined && val !== null) {
          sanitizedData[key] = typeof val === 'object' ? JSON.stringify(val) : String(val);
        }
      }
      sanitizedData['click_action'] = 'FLUTTER_NOTIFICATION_CLICK';

      // FCM High-Priority Payload
      // For urgent orders on Android: sending data-only ensures Android OS wakes up the device,
      // invokes firebaseMessagingBackgroundHandler immediately, which displays the local notification
      // with fullScreenIntent: true to wake up screen & open accept/reject UI over lock screen!
      const fcmPayload = {
        to: token,
        priority: 'high',
        time_to_live: 0, // Zero TTL ensures immediate delivery without Doze delay
        content_available: true,
        data: sanitizedData,
      };

      // For standard messages or iOS, include the notification block
      if (!isOrderRequest || platform === 'ios') {
        fcmPayload.notification = {
          title,
          body: message,
          sound: 'notification_sound',
          android_channel_id: channelId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        };
        fcmPayload.android = {
          priority: 'high',
          ttl: '0s',
          notification: {
            channel_id: channelId,
            sound: 'notification_sound',
            priority: 'max',
            visibility: 'public',
            default_vibrate_timings: true,
            default_light_settings: true,
          },
        };
      }

      // If Firebase Server Key or Service Account credentials exist, dispatch to FCM
      const fcmServerKey = process.env.FCM_SERVER_KEY || process.env.FIREBASE_SERVER_KEY;
      if (fcmServerKey) {
        await fetch('https://fcm.googleapis.com/fcm/send', {
          method: 'POST',
          headers: {
            'Authorization': `key=${fcmServerKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(fcmPayload),
        }).catch((err) => console.warn('[PushNotificationService] FCM error:', err.message));
        console.log(`[PushNotificationService] 🚀 FCM dispatched to ${userId || token}: "${title}"`);
      } else {
        if (process.env.NODE_ENV !== 'test') {
          console.log(`[PushNotificationService] 📱 Push active for ${userId || 'device'} (${token.substring(0, 15)}...): "${title}"`);
        }
      }
    } catch (error) {
      // Never throw or fail main business flow if push delivery fails
      console.warn(`[PushNotificationService] Push delivery notice: ${error.message}`);
    }
  }

  /**
   * Broadcast high-priority push notification to all logged-in devices/users of a business
   * (Owner, cashiers, kitchen staff terminals) with sub-10ms in-memory cache lookup
   */
  async sendPushNotificationToBusiness({ businessId, title, message, data = {} }) {
    try {
      if (!businessId) return;
      const bKey = businessId.toString();

      // Check cache first
      let cachedBiz = this.businessTokensCache.get(bKey);
      let targetDevices = [];

      if (cachedBiz && Date.now() - cachedBiz.timestamp < this.CACHE_TTL_MS) {
        targetDevices = cachedBiz.devices;
      } else {
        const Business = require('../models/Business');

        // Fetch users and owner in parallel
        const [users, biz] = await Promise.all([
          User.find({
            businessId,
            pushToken: { $exists: true, $ne: null },
          }).select('_id pushToken pushPlatform').lean().catch(() => []),
          Business.findById(businessId).select('ownerId').lean().catch(() => null),
        ]);

        const deviceMap = new Map();
        for (const u of users) {
          if (u.pushToken) {
            deviceMap.set(u.pushToken, {
              userId: u._id.toString(),
              token: u.pushToken,
              platform: u.pushPlatform || 'android',
            });
          }
        }

        if (biz?.ownerId) {
          const ownerUser = await User.findById(biz.ownerId).select('_id pushToken pushPlatform').lean().catch(() => null);
          if (ownerUser?.pushToken) {
            deviceMap.set(ownerUser.pushToken, {
              userId: ownerUser._id.toString(),
              token: ownerUser.pushToken,
              platform: ownerUser.pushPlatform || 'android',
            });
          }
        }

        targetDevices = Array.from(deviceMap.values());
        this.businessTokensCache.set(bKey, { devices: targetDevices, timestamp: Date.now() });
      }

      // Dispatch in parallel across all business terminal devices
      const dispatchPromises = targetDevices.map((dev) =>
        this.sendPushNotification({
          userId: dev.userId,
          token: dev.token,
          platform: dev.platform,
          title,
          message,
          data,
        })
      );

      await Promise.allSettled(dispatchPromises);
    } catch (err) {
      console.warn('[PushNotificationService] Error broadcasting to business:', err.message);
    }
  }
}

module.exports = new PushNotificationService();
