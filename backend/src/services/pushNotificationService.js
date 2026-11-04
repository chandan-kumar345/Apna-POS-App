const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const User = require('../models/User');

class PushNotificationService {
  constructor() {
    this.deviceTokens = new Map(); // Local in-memory registry fallback
    this.userTokenCache = new Map(); // userId -> { token, platform, timestamp }
    this.businessTokensCache = new Map(); // businessId -> { users: [...], timestamp }
    this.CACHE_TTL_MS = 60000; // 60 seconds TTL for token cache
    this._cachedAccessToken = null;
    this._cachedTokenExpiry = 0;
  }

  _getServiceAccount() {
    if (this._serviceAccount !== undefined) return this._serviceAccount;
    try {
      const explicitPath = process.env.FIREBASE_SERVICE_ACCOUNT_KEY || process.env.GOOGLE_APPLICATION_CREDENTIALS;
      if (explicitPath && fs.existsSync(explicitPath)) {
        this._serviceAccount = JSON.parse(fs.readFileSync(explicitPath, 'utf8'));
        return this._serviceAccount;
      }
      const backendPath = path.join(__dirname, '../../serviceAccountKey.json');
      if (fs.existsSync(backendPath)) {
        this._serviceAccount = JSON.parse(fs.readFileSync(backendPath, 'utf8'));
        return this._serviceAccount;
      }
      const rootPath = path.join(__dirname, '../../../serviceAccountKey.json');
      if (fs.existsSync(rootPath)) {
        this._serviceAccount = JSON.parse(fs.readFileSync(rootPath, 'utf8'));
        return this._serviceAccount;
      }
      if (process.env.FIREBASE_SERVICE_ACCOUNT) {
        this._serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
        return this._serviceAccount;
      }
      try {
        const bundledConfig = require('../config/firebaseAdminConfig');
        if (bundledConfig && bundledConfig.project_id && bundledConfig.private_key) {
          this._serviceAccount = bundledConfig;
          return this._serviceAccount;
        }
      } catch (_) {}
    } catch (e) {
      console.warn('[PushNotificationService] Error reading serviceAccountKey.json:', e.message);
    }
    this._serviceAccount = null;
    return null;
  }

  async _getGoogleAccessToken(sa) {
    const now = Math.floor(Date.now() / 1000);
    if (this._cachedAccessToken && this._cachedTokenExpiry > now + 60) {
      return this._cachedAccessToken;
    }
    try {
      const header = { alg: 'RS256', typ: 'JWT' };
      const claimSet = {
        iss: sa.client_email,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: sa.token_uri || 'https://oauth2.googleapis.com/token',
        exp: now + 3600,
        iat: now,
      };

      const b64 = (obj) =>
        Buffer.from(JSON.stringify(obj))
          .toString('base64')
          .replace(/=/g, '')
          .replace(/\+/g, '-')
          .replace(/\//g, '_');

      const signInput = `${b64(header)}.${b64(claimSet)}`;
      const signer = crypto.createSign('RSA-SHA256');
      signer.update(signInput);
      const signature = signer
        .sign(sa.private_key, 'base64')
        .replace(/=/g, '')
        .replace(/\+/g, '-')
        .replace(/\//g, '_');

      const jwt = `${signInput}.${signature}`;
      const res = await fetch(sa.token_uri || 'https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
      });
      const data = await res.json();
      if (data.access_token) {
        this._cachedAccessToken = data.access_token;
        this._cachedTokenExpiry = now + 3500;
        return this._cachedAccessToken;
      }
      console.warn('[PushNotificationService] OAuth2 response error:', data);
    } catch (e) {
      console.warn('[PushNotificationService] OAuth2 access token error:', e.message);
    }
    return null;
  }

  /**
   * Register device push token for a user with instant in-memory cache pre-warming
   */
  async registerDeviceToken(userId, token, platform = 'android', explicitBusinessId = null) {
    try {
      if (!userId || !token) return;
      const uid = userId.toString();
      this.deviceTokens.set(uid, token);
      this.userTokenCache.set(uid, { token, platform, timestamp: Date.now() });

      // Persist to user model and retrieve businessId to pre-warm cache
      const updatedUser = await User.findByIdAndUpdate(userId, {
        $set: {
          pushToken: token,
          pushPlatform: platform,
          lastActiveAt: new Date(),
        },
      }, { new: true }).select('businessId').lean().catch(() => null);

      let bId = explicitBusinessId || updatedUser?.businessId;
      if (!bId) {
        const Business = require('../models/Business');
        const biz = await Business.findOne({ ownerId: userId }).select('_id').lean().catch(() => null);
        if (biz?._id) bId = biz._id;
      }

      // Pre-warm businessTokensCache in-memory for 0ms zero-latency order pushes!
      if (bId) {
        const bKey = bId.toString();
        let cached = this.businessTokensCache.get(bKey);
        const deviceEntry = { userId: uid, token, platform };
        if (cached && Array.isArray(cached.devices)) {
          const filtered = cached.devices.filter(d => d.userId !== uid);
          filtered.push(deviceEntry);
          this.businessTokensCache.set(bKey, { devices: filtered, timestamp: Date.now() });
        } else {
          this.businessTokensCache.set(bKey, { devices: [deviceEntry], timestamp: Date.now() });
        }
        console.log(`[PushNotificationService] 📱 Device token pre-warmed for business ${bKey} (User: ${uid})`);
      }
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
  async sendPushNotification({ userId, token: explicitToken, platform: explicitPlatform, title, message, data = {}, sentTokens = null }) {
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

      // Check if this token was already dispatched in the current batch
      if (sentTokens && sentTokens.has(token)) {
        console.log(`[PushNotificationService] Push skipped (duplicate token in batch for ${token.slice(0, 15)}...): "${title}"`);
        return;
      }
      if (sentTokens) {
        sentTokens.add(token);
      }

      // In-flight debounce: prevent identical message sent to the same device within 10s
      if (!this._recentPushDedupe) this._recentPushDedupe = new Map();
      const dedupeKey = `${token}::${title}::${message}`;
      const now = Date.now();
      const lastSent = this._recentPushDedupe.get(dedupeKey);
      if (lastSent && now - lastSent < 10000) {
        console.log(`[PushNotificationService] Push skipped (debounced duplicate within 10s): "${title}"`);
        return;
      }
      this._recentPushDedupe.set(dedupeKey, now);
      if (this._recentPushDedupe.size > 200) {
        for (const [k, ts] of this._recentPushDedupe.entries()) {
          if (now - ts > 30000) this._recentPushDedupe.delete(k);
        }
      }

      const isOrderRequest =
        data.type === 'whatsapp_order_request' ||
        data.type === 'whatsapp_new_order' ||
        data.type === 'whatsapp_order' ||
        data.type === 'new_order' ||
        data.type === 'newOrder' ||
        data.type === 'order_created' ||
        data.type === 'order' ||
        data.entityType === 'whatsapp_order' ||
        data.entityType === 'order' ||
        Boolean(data.orderId);

      const isWhatsApp = data.type === 'whatsapp_message' || data.type === 'whatsappMessage';
      const channelId = isOrderRequest
        ? 'apna_pos_whatsapp_orders_v2'
        : (isWhatsApp ? 'apna_pos_whatsapp_messages_v1' : 'apna_pos_general_v2');

      // Android notification tag to natively update/replace notifications in system shade
      let androidTag = null;
      if (data.type === 'daily_sales_summary' || data.entityType === 'sales_report') {
        androidTag = 'daily_sales_summary';
      } else if (isOrderRequest) {
        androidTag = `order_${data.orderId || data.orderNumber || 'incoming'}`;
      } else if (isWhatsApp) {
        androidTag = `chat_${data.chatId || data.customerPhone || 'msg'}`;
      }

      // Sanitize all data entries into strings (FCM requirement for data payload)
      const sanitizedData = {};
      for (const [key, val] of Object.entries({ title, message, ...data })) {
        if (val !== undefined && val !== null) {
          sanitizedData[key] = typeof val === 'object' ? JSON.stringify(val) : String(val);
        }
      }
      sanitizedData['click_action'] = 'FLUTTER_NOTIFICATION_CLICK';
      if (androidTag) {
        sanitizedData['notificationTag'] = androidTag;
      }

      // FCM High-Priority Payload
      const fcmPayload = {
        to: token,
        priority: 'high',
        collapse_key: androidTag || 'apna_pos_general',
        time_to_live: 0, // Zero TTL ensures immediate delivery without Doze delay
        content_available: true,
        android: {
          priority: 'high',
          ttl: '0s',
          collapse_key: androidTag || 'apna_pos_general',
        },
        notification: {
          title,
          body: message,
          sound: 'notification_sound',
          android_channel_id: channelId,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          ...(androidTag ? { tag: androidTag } : {}),
        },
        data: sanitizedData,
      };

      fcmPayload.android.notification = {
        channel_id: channelId,
        sound: 'notification_sound',
        priority: 'max',
        visibility: 'public',
        default_vibrate_timings: true,
        default_light_settings: true,
        ...(androidTag ? { tag: androidTag } : {}),
      };

      // 1. Try FCM HTTP v1 using Service Account JSON (recommended by Firebase)
      const serviceAccount = this._getServiceAccount();
      let dispatched = false;

      if (serviceAccount) {
        const accessToken = await this._getGoogleAccessToken(serviceAccount);
        if (accessToken) {
          try {
            const projectId = serviceAccount.project_id || 'apna-pos-55b95';
            const v1Payload = {
              message: {
                token: token,
                notification: {
                  title,
                  body: message,
                },
                android: {
                  priority: 'HIGH',
                  ttl: '0s',
                  direct_boot_ok: true,
                  collapse_key: androidTag || 'apna_pos_general',
                  notification: {
                    channel_id: channelId,
                    sound: 'notification_sound',
                    notification_priority: 'PRIORITY_MAX',
                    visibility: 'PUBLIC',
                    default_vibrate_timings: true,
                    default_light_settings: true,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                    ...(androidTag ? { tag: androidTag } : {}),
                  },
                },
                apns: {
                  headers: {
                    'apns-priority': '10',
                    'apns-push-type': 'alert',
                  },
                  payload: {
                    aps: {
                      'content-available': 1,
                      sound: 'notification_sound.mp3',
                    },
                  },
                },
                data: sanitizedData,
              },
            };

            const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${accessToken}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify(v1Payload),
            });
            const responseJson = await response.json().catch(() => ({}));
            if (response.ok) {
              dispatched = true;
              console.log(`[PushNotificationService] 🚀 FCM v1 dispatched to ${userId || token.substring(0, 10)}: "${title}"`);
            } else {
              console.warn(`[PushNotificationService] ⚠️ FCM v1 response (status ${response.status}):`, responseJson);
              const isUnregistered =
                response.status === 404 ||
                responseJson?.error?.details?.some((d) => d.errorCode === 'UNREGISTERED') ||
                responseJson?.error?.message === 'NotRegistered';
              if (isUnregistered) {
                console.log(`[PushNotificationService] 🗑️ Removing unregistered FCM push token for user ${userId || token.substring(0, 10)}`);
                if (userId) {
                  this.removeDeviceToken(userId);
                } else {
                  User.updateMany({ pushToken: token }, { $unset: { pushToken: 1, pushPlatform: 1 } }).catch(() => {});
                }
              }
            }
          } catch (v1Err) {
            console.warn('[PushNotificationService] FCM v1 fetch error:', v1Err.message);
          }
        }
      }

      // 2. Fallback to Legacy FCM HTTP if FCM_SERVER_KEY is configured
      if (!dispatched) {
        const fcmServerKey = process.env.FCM_SERVER_KEY || process.env.FIREBASE_SERVER_KEY;
        if (fcmServerKey) {
          try {
            const response = await fetch('https://fcm.googleapis.com/fcm/send', {
              method: 'POST',
              headers: {
                'Authorization': `key=${fcmServerKey}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify(fcmPayload),
            });
            const responseJson = await response.json().catch(() => ({}));
            if (response.ok && responseJson.success === 1) {
              dispatched = true;
              console.log(`[PushNotificationService] 🚀 FCM legacy dispatched to ${userId || token.substring(0, 10)}: "${title}"`);
            } else {
              console.warn(`[PushNotificationService] ⚠️ FCM legacy response (status ${response.status}):`, responseJson);
            }
          } catch (fetchErr) {
            console.warn('[PushNotificationService] FCM fetch error:', fetchErr.message);
          }
        }
      }

      if (!dispatched && process.env.NODE_ENV !== 'test') {
        console.warn(`[PushNotificationService] ⚠️ Background push skipped for "${title}". To enable notifications when the app is closed, either add serviceAccountKey.json to backend/ or set FCM_SERVER_KEY in backend/.env.`);
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

      // Fast path: In-memory cache hit (<0.1ms zero-latency lookup)
      if (cachedBiz && Date.now() - cachedBiz.timestamp < 300000) {
        targetDevices = cachedBiz.devices;
      } else {
        const Business = require('../models/Business');

        // Resolve business owner & staff devices in a single fast parallel query
        const biz = await Business.findById(businessId).select('ownerId').lean().catch(() => null);
        const queryOr = [{ businessId }];
        if (biz?.ownerId) queryOr.push({ _id: biz.ownerId });

        const users = await User.find({
          $or: queryOr,
          pushToken: { $exists: true, $ne: null },
        }).select('_id pushToken pushPlatform').lean().catch(() => []);

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
