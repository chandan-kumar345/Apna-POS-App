const User = require('../models/User');

class PushNotificationService {
  constructor() {
    this.deviceTokens = new Map(); // Local in-memory registry fallback
  }

  /**
   * Register device push token for a user
   */
  async registerDeviceToken(userId, token, platform = 'android') {
    try {
      if (!userId || !token) return;
      this.deviceTokens.set(userId.toString(), token);

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
      this.deviceTokens.delete(userId.toString());
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
  async sendPushNotification({ userId, title, message, data = {} }) {
    try {
      if (!userId) return;

      let token = this.deviceTokens.get(userId.toString());
      if (!token) {
        const user = await User.findById(userId).select('pushToken pushPlatform').lean();
        if (user && user.pushToken) {
          token = user.pushToken;
          this.deviceTokens.set(userId.toString(), token);
        }
      }

      if (!token) {
        if (process.env.NODE_ENV !== 'test') {
          console.log(`[PushNotificationService] Push skipped (no device token for ${userId}): "${title}"`);
        }
        return;
      }

      const isWhatsApp = data.type === 'whatsapp_message' || data.type === 'whatsappMessage';
      const channelId = isWhatsApp ? 'apna_pos_whatsapp_messages_v1' : 'apna_pos_general_v2';

      // FCM High-Priority Payload
      const fcmPayload = {
        to: token,
        priority: 'high',
        notification: {
          title,
          body: message,
          sound: 'notification_sound',
          android_channel_id: channelId,
        },
        data: {
          title,
          message,
          ...data,
        },
      };

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
        console.log(`[PushNotificationService] 🚀 FCM dispatched to ${userId}: "${title}"`);
      } else {
        if (process.env.NODE_ENV !== 'test') {
          console.log(`[PushNotificationService] 📱 Push active for ${userId} (${token.substring(0, 15)}...): "${title}"`);
        }
      }
    } catch (error) {
      // Never throw or fail main business flow if push delivery fails
      console.warn(`[PushNotificationService] Push delivery notice: ${error.message}`);
    }
  }
}

module.exports = new PushNotificationService();
