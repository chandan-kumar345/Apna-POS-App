const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');
const mongoose = require('mongoose');
const WhatsAppChat = require('../models/WhatsAppChat');
const Customer = require('../models/Customer');
const User = require('../models/User');
const whatsappService = require('./whatsappService');
const storageService = require('../utils/storageService');

class WhatsAppProfilePicService {
  constructor() {
    this.avatarDir = path.join(__dirname, '../../public/uploads/avatars');
    if (!fs.existsSync(this.avatarDir)) {
      try {
        fs.mkdirSync(this.avatarDir, { recursive: true });
      } catch (err) {
        console.warn('[WhatsAppProfilePicService] Could not create avatar dir:', err.message);
      }
    }
  }

  /**
   * Normalize phone number to standard 12-digit Indian format or clean digits
   */
  normalizePhone(phone) {
    if (!phone) return '';
    return whatsappService.normalizePhoneNumber(phone);
  }

  /**
   * Get relative avatar URL for a normalized phone number
   */
  getAvatarLocalUrl(normalizedPhone) {
    return `/uploads/avatars/${normalizedPhone}.jpg`;
  }

  /**
   * Check if a cached avatar image file exists on local disk
   */
  hasCachedLocalAvatar(normalizedPhone) {
    if (!normalizedPhone) return false;
    const extensions = ['.jpg', '.jpeg', '.png', '.webp'];
    for (const ext of extensions) {
      const filePath = path.join(this.avatarDir, `${normalizedPhone}${ext}`);
      if (fs.existsSync(filePath)) {
        return `/uploads/avatars/${normalizedPhone}${ext}`;
      }
    }
    return null;
  }

  /**
   * Download a remote image URL and save it to disk permanently
   * WhatsApp CDN (pps.whatsapp.net) links expire in 24-48 hours, so local caching is mandatory
   */
  downloadAndCacheImage(url, normalizedPhone) {
    return new Promise((resolve) => {
      if (!url || !url.startsWith('http')) return resolve(null);

      const client = url.startsWith('https') ? https : http;
      const targetExt = url.includes('.png') ? '.png' : (url.includes('.webp') ? '.webp' : '.jpg');
      const targetFile = path.join(this.avatarDir, `${normalizedPhone}${targetExt}`);

      const req = client.get(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        },
        timeout: 5000,
      }, (res) => {
        if (res.statusCode !== 200) {
          return resolve(null);
        }

        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', async () => {
          try {
            const buffer = Buffer.concat(chunks);
            if (buffer.length < 100) return resolve(null); // Too small to be a real image

            fs.writeFileSync(targetFile, buffer);
            const localUrl = `/uploads/avatars/${normalizedPhone}${targetExt}`;

            // Also upload to Cloudflare R2 if configured
            if (storageService.isConfigured) {
              try {
                const r2Url = await storageService.uploadImage(
                  buffer,
                  `${normalizedPhone}${targetExt}`,
                  res.headers['content-type'] || 'image/jpeg',
                  'avatars'
                );
                return resolve(r2Url);
              } catch (_) {}
            }

            resolve(localUrl);
          } catch (e) {
            console.warn('[WhatsAppProfilePicService] Write file error:', e.message);
            resolve(null);
          }
        });
      });

      req.on('error', () => resolve(null));
      req.on('timeout', () => {
        req.destroy();
        resolve(null);
      });
    });
  }

  /**
   * Resolve WhatsApp profile picture across all available sources:
   * 1. Local cached image file in public/uploads/avatars/
   * 2. MongoDB Customer model (avatarUrl or profileImage)
   * 3. MongoDB User model (profilePhotoPath)
   * 4. Configured WhatsApp DP lookup endpoints (RapidAPI, Whapi, Green-API, or public resolver)
   */
  async resolveProfilePic({ phone, businessId = null, chatId = null, forceRefresh = false } = {}) {
    if (!phone) return null;

    const normalizedPhone = this.normalizePhone(phone);
    if (!normalizedPhone) return null;

    const last10 = normalizedPhone.slice(-10);

    // 1. Check local file cache if not forcing refresh
    if (!forceRefresh) {
      const cached = this.hasCachedLocalAvatar(normalizedPhone);
      if (cached) {
        await this._persistAvatarToModels(normalizedPhone, cached, businessId, chatId);
        return cached;
      }
    }

    // 2. Check Customer record in database
    const customerFilter = {
      phone: { $in: [normalizedPhone, last10, `+91${last10}`, `91${last10}`, `+${normalizedPhone}`] },
    };
    if (businessId && mongoose.Types.ObjectId.isValid(businessId)) {
      customerFilter.businessId = new mongoose.Types.ObjectId(businessId);
    }

    const customer = await Customer.findOne(customerFilter).lean();
    if (customer && (customer.avatarUrl || customer.profileImage)) {
      const custAvatar = (customer.avatarUrl || customer.profileImage).trim();
      if (custAvatar && custAvatar !== 'assets/images/logo.png') {
        // If it's a remote URL from WhatsApp, try downloading it for longevity
        if (custAvatar.includes('pps.whatsapp.net')) {
          const cached = await this.downloadAndCacheImage(custAvatar, normalizedPhone);
          const finalUrl = cached || custAvatar;
          await this._persistAvatarToModels(normalizedPhone, finalUrl, businessId, chatId);
          return finalUrl;
        }
        await this._persistAvatarToModels(normalizedPhone, custAvatar, businessId, chatId);
        return custAvatar;
      }
    }

    // 3. Check User record in database (for merchants / internal staff)
    const user = await User.findOne({
      phone: { $in: [normalizedPhone, last10, `+91${last10}`, `91${last10}`, `+${normalizedPhone}`] },
    }).lean();
    if (user && user.profilePhotoPath && user.profilePhotoPath.trim() !== 'assets/images/logo.png') {
      const userAvatar = user.profilePhotoPath.trim();
      await this._persistAvatarToModels(normalizedPhone, userAvatar, businessId, chatId);
      return userAvatar;
    }

    // 4. Check external WhatsApp profile picture providers if configured
    const externalUrl = await this._queryExternalResolver(normalizedPhone);
    if (externalUrl) {
      const cached = await this.downloadAndCacheImage(externalUrl, normalizedPhone);
      const finalUrl = cached || externalUrl;
      await this._persistAvatarToModels(normalizedPhone, finalUrl, businessId, chatId);
      return finalUrl;
    }

    // 5. If forceRefresh and local file already existed, return it as fallback
    const fallbackLocal = this.hasCachedLocalAvatar(normalizedPhone);
    if (fallbackLocal) {
      return fallbackLocal;
    }

    return null;
  }

  /**
   * Helper to query external WhatsApp profile picture resolvers
   */
  async _queryExternalResolver(normalizedPhone) {
    // A. Check custom endpoint if specified in env
    const customEndpoint = process.env.WHATSAPP_DP_API_URL;
    if (customEndpoint) {
      try {
        const fetchUrl = customEndpoint.replace('{phone}', normalizedPhone);
        const res = await this._fetchJson(fetchUrl, { timeout: 3500 });
        if (res && (res.picture || res.profilePic || res.avatarUrl || res.url)) {
          return res.picture || res.profilePic || res.avatarUrl || res.url;
        }
      } catch (_) {}
    }

    // B. Check RapidAPI if API key is present
    const rapidApiKey = process.env.RAPIDAPI_KEY || process.env.WHATSAPP_RAPIDAPI_KEY;
    if (rapidApiKey) {
      try {
        const rapidUrl = `https://whatsapp-profile-pic.p.rapidapi.com/wspic/url?phone=${normalizedPhone}`;
        const res = await this._fetchJson(rapidUrl, {
          headers: {
            'X-RapidAPI-Key': rapidApiKey,
            'X-RapidAPI-Host': 'whatsapp-profile-pic.p.rapidapi.com',
          },
          timeout: 4000,
        });
        if (res && res.url) {
          return res.url;
        }
      } catch (_) {}
    }

    return null;
  }

  /**
   * Helper to fetch JSON with timeout
   */
  _fetchJson(url, { headers = {}, timeout = 3000 } = {}) {
    return new Promise((resolve, reject) => {
      const client = url.startsWith('https') ? https : http;
      const req = client.get(url, { headers, timeout }, (res) => {
        let body = '';
        res.on('data', chunk => body += chunk);
        res.on('end', () => {
          try {
            resolve(JSON.parse(body));
          } catch (_) {
            resolve(null);
          }
        });
      });
      req.on('error', reject);
      req.on('timeout', () => {
        req.destroy();
        resolve(null);
      });
    });
  }

  /**
   * Persist the resolved avatar URL into WhatsAppChat and Customer models, then emit socket
   */
  async _persistAvatarToModels(normalizedPhone, avatarUrl, businessId = null, chatId = null) {
    if (!avatarUrl || !normalizedPhone) return;

    try {
      const last10 = normalizedPhone.slice(-10);

      // Update WhatsAppChat
      const chatQuery = chatId
        ? { _id: chatId }
        : { customerPhone: { $in: [normalizedPhone, last10, `+91${last10}`, `91${last10}`] } };

      const chat = await WhatsAppChat.findOneAndUpdate(
        chatQuery,
        { $set: { avatarUrl } },
        { new: true }
      );

      // Update Customer
      const custQuery = {
        phone: { $in: [normalizedPhone, last10, `+91${last10}`, `91${last10}`, `+${normalizedPhone}`] },
      };
      if (businessId && mongoose.Types.ObjectId.isValid(businessId)) {
        custQuery.businessId = new mongoose.Types.ObjectId(businessId);
      }
      await Customer.updateMany(
        custQuery,
        { $set: { avatarUrl, profileImage: avatarUrl } }
      );

      // Emit socket event so Flutter app updates avatar in real-time
      if (chat) {
        try {
          const socketService = require('./socketService');
          socketService.emitWhatsAppChatUpdated(chat.businessId || businessId, { chat });
        } catch (_) {}
      }
    } catch (err) {
      console.warn('[WhatsAppProfilePicService] Error persisting avatar:', err.message);
    }
  }

  /**
   * Explicitly synchronize DP for a chat
   */
  async syncChatDp(businessId, chatId) {
    const chat = await WhatsAppChat.findOne({ _id: chatId });
    if (!chat) {
      throw new Error('Chat not found');
    }

    const resolvedUrl = await this.resolveProfilePic({
      phone: chat.customerPhone,
      businessId,
      chatId: chat._id,
      forceRefresh: true,
    });

    return {
      success: true,
      avatarUrl: resolvedUrl || chat.avatarUrl || null,
      customerPhone: chat.customerPhone,
    };
  }

  /**
   * Save a custom avatar (e.g. merchant uploaded photo for a customer)
   */
  async saveCustomAvatar(businessId, chatId, avatarUrl) {
    const chat = await WhatsAppChat.findOne({ _id: chatId });
    if (!chat) {
      throw new Error('Chat not found');
    }

    chat.avatarUrl = avatarUrl;
    await chat.save();

    await this._persistAvatarToModels(chat.customerPhone, avatarUrl, businessId, chat._id);

    return {
      success: true,
      chat,
    };
  }
}

module.exports = new WhatsAppProfilePicService();
