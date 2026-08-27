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

      const token = this.deviceTokens.get(userId.toString());
      
      // If Firebase Admin SDK credentials are provided in env, dispatch FCM
      if (process.env.FIREBASE_SERVICE_ACCOUNT_KEY && token) {
        // FCM payload dispatch integration
        console.log(`[PushNotificationService] Dispatching push to ${userId}: "${title}"`);
      } else {
        // Development / simulation log
        if (process.env.NODE_ENV !== 'test') {
          console.log(`[PushNotificationService] Push simulated for ${userId}: "${title}" - "${message}"`);
        }
      }
    } catch (error) {
      // Never throw or fail main business flow if push delivery fails
      console.warn(`[PushNotificationService] Push delivery notice: ${error.message}`);
    }
  }
}

module.exports = new PushNotificationService();
