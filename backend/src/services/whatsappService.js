const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const whatsappConfig = require('../config/whatsapp.config');
const ApiError = require('../utils/ApiError');

class WhatsAppService {
  constructor() {
    this.phoneNumberId = whatsappConfig.phoneNumberId || '1284061438133660';
    this.accessToken = whatsappConfig.accessToken || 'EAAzxdmIpPWcBSrPyzIiQwMc6bPDWavABgK5maL2rzXtkd6EMLJKP8IRQB30wHqm1U0Ka3b8PmhUfghI87ZAk7dkDaZBLhWIYUvJZCLnE2UF9AhN0cZCAOuwKMJYzJft1NFDfyvNMk9sBm4M29CHGJjFsYxoRJpbjfc8f578s3YcZALdNz8z6h4bH4HK7WZBZB4NCAZDZD';
    this.apiVersion = whatsappConfig.apiVersion || 'v21.0';
    this.webhookVerifyToken = whatsappConfig.webhookVerifyToken || 'softcode_whatsapp_webhook_verify_2026';
    this.appSecret = whatsappConfig.appSecret || '';
    this.templateName = whatsappConfig.templateName || 'ebill_receipt';
  }

  /**
   * Normalize customer phone number to WhatsApp international standard (e.g. 919876543210)
   * Strips all non-digit characters, leading zeros, or '+'
   * If 10 digits (standard Indian mobile), automatically prepends '91'
   */
  normalizePhoneNumber(rawPhone) {
    if (!rawPhone) return '';
    let digits = rawPhone.toString().replace(/\D/g, '');
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0') && digits.length === 11) {
      digits = digits.substring(1);
    }
    // Handle case where phone was entered as 910XXXXXXXXXX (13 digits with unnecessary 0)
    if (digits.startsWith('910') && digits.length === 13) {
      digits = `91${digits.substring(3)}`;
    }
    // Standard Indian 10-digit mobile number check
    if (digits.length === 10) {
      digits = `91${digits}`;
    }
    return digits;
  }

  /**
   * Validate whether phone number format is supported
   */
  isValidPhoneNumber(phone) {
    const normalized = this.normalizePhoneNumber(phone);
    // WhatsApp international numbers are typically between 10 and 15 digits
    return normalized.length >= 10 && normalized.length <= 15;
  }

  /**
   * Send eBill receipt via Meta WhatsApp Cloud API
   * Supports both template message and text summary
   */
  /**
   * Internal helper to dispatch eBill message to Meta Cloud API
   */
  async _dispatchEbillToMeta({
    phoneNumberId,
    accessToken,
    normalizedPhone,
    customerName,
    businessName,
    billNumber,
    totalAmount,
    currency,
    receiptText,
  }) {
    const url = `https://graph.facebook.com/${this.apiVersion}/${phoneNumberId}/messages`;

    let payload;
    if (this.templateName && this.templateName !== 'none') {
      // Standard WhatsApp Business Template format
      payload = {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: normalizedPhone,
        type: 'template',
        template: {
          name: this.templateName,
          language: { code: 'en' },
          components: [
            {
              type: 'body',
              parameters: [
                { type: 'text', text: customerName || 'Valued Customer' },
                { type: 'text', text: businessName || 'Our Store' },
                { type: 'text', text: String(billNumber || '') },
                { type: 'text', text: `${currency} ${Number(totalAmount || 0).toFixed(2)}` },
              ],
            },
          ],
        },
      };
    } else {
      // Direct formatted text message (within 24-hr service window or dev sandbox)
      const bodyText = receiptText ||
        `*${businessName.toUpperCase()}*\nBill Receipt: #${billNumber}\nTotal Amount: ${currency} ${Number(totalAmount).toFixed(2)}\nThank you for your visit!`;
      payload = {
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: normalizedPhone,
        type: 'text',
        text: { preview_url: true, body: bodyText },
      };
    }

    let response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    let data = await response.json().catch(() => ({}));

    // If template was rejected because of translation or missing template, attempt en_US then text fallback
    if (!response.ok && payload.type === 'template') {
      const code = data?.error?.code;
      if (code === 132000 || code === 132001) {
        console.warn(`[WhatsAppService] Template '${this.templateName}' unavailable in en. Attempting fallback to en_US...`);
        payload.template.language = { code: 'en_US' };
        response = await fetch(url, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(payload),
        });
        data = await response.json().catch(() => ({}));

        if (!response.ok) {
          console.warn(`[WhatsAppService] Template '${this.templateName}' unavailable. Falling back to direct formatted receipt text...`);
          const bodyText = receiptText ||
            `*${businessName.toUpperCase()}*\nBill Receipt: #${billNumber}\nTotal Amount: ${currency} ${Number(totalAmount).toFixed(2)}\nThank you for your visit!`;
          const textPayload = {
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to: normalizedPhone,
            type: 'text',
            text: { preview_url: true, body: bodyText },
          };
          response = await fetch(url, {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify(textPayload),
          });
          data = await response.json().catch(() => ({}));
        }
      }
    }

    if (!response.ok) {
      let errorMsg = data?.error?.message || `WhatsApp API error: ${response.statusText}`;
      const errorCode = data?.error?.code || 'WHATSAPP_API_ERROR';
      if (errorCode === 131030) {
        errorMsg = `Meta WhatsApp Sandbox Restriction: Customer number (${normalizedPhone}) is not added to your Meta Developer Allowed Phone Numbers list. In Development Mode, messages can only be sent to numbers added in Meta Console. Switch the app to Live Mode or add this number to the test list.`;
      }
      console.error('[WhatsAppService] Send failed:', data?.error || data);
      throw ApiError.badRequest(errorMsg, null, errorCode);
    }

    return data;
  }

  /**
   * Send eBill receipt via Meta WhatsApp Cloud API
   * Supports custom WhatsApp credentials (if integrated) with graceful fallback to default WhatsApp
   */
  async sendEbillReceipt({
    to,
    customerName = 'Customer',
    businessName = 'Apna POS Store',
    billNumber,
    totalAmount,
    currency = 'INR',
    receiptText = '',
    documentUrl = null,
    customPhoneNumberId = null,
    customAccessToken = null,
  }) {
    const normalizedPhone = this.normalizePhoneNumber(to);
    if (!this.isValidPhoneNumber(normalizedPhone)) {
      throw ApiError.badRequest(
        `Invalid customer WhatsApp phone number: ${to}`,
        null,
        'INVALID_PHONE_NUMBER'
      );
    }

    // 1. Attempt sending via custom WhatsApp if user/business has integrated their WhatsApp API
    if (customPhoneNumberId && customAccessToken) {
      try {
        if (
          process.env.NODE_ENV === 'test' ||
          customAccessToken === 'mock_token' ||
          customAccessToken === 'test_token'
        ) {
          const mockMessageId = `wamid.HBg${Date.now()}${Math.floor(Math.random() * 1000000)}==`;
          return {
            success: true,
            messageId: mockMessageId,
            whatsappPhoneNumberId: customPhoneNumberId,
            recipient: normalizedPhone,
            isCustomApi: true,
            isSimulated: true,
          };
        }

        const data = await this._dispatchEbillToMeta({
          phoneNumberId: customPhoneNumberId,
          accessToken: customAccessToken,
          normalizedPhone,
          customerName,
          businessName,
          billNumber,
          totalAmount,
          currency,
          receiptText,
        });

        const messageId = data?.messages?.[0]?.id || `wamid.unknown.${Date.now()}`;
        return {
          success: true,
          messageId,
          whatsappPhoneNumberId: customPhoneNumberId,
          recipient: normalizedPhone,
          isCustomApi: true,
          isSimulated: false,
        };
      } catch (customErr) {
        console.warn(`[WhatsAppService] Custom WhatsApp dispatch failed (${customErr.message}). Falling back to default Apna POS WhatsApp channel.`);
        // Fall back to default WhatsApp below
      }
    }

    // 2. Default Apna POS WhatsApp
    if (
      process.env.NODE_ENV === 'test' ||
      !this.accessToken ||
      this.accessToken === 'mock_token' ||
      this.accessToken === 'test_token'
    ) {
      console.warn(`[WhatsAppService] ⚠️ SIMULATION MODE: WHATSAPP_ACCESS_TOKEN is not configured in .env. Real message was not sent to ${normalizedPhone}. Generated mock messageId.`);
      const mockMessageId = `wamid.HBg${Date.now()}${Math.floor(Math.random() * 1000000)}==`;
      return {
        success: true,
        messageId: mockMessageId,
        whatsappPhoneNumberId: this.phoneNumberId,
        recipient: normalizedPhone,
        isCustomApi: false,
        isSimulated: true,
      };
    }

    const data = await this._dispatchEbillToMeta({
      phoneNumberId: this.phoneNumberId,
      accessToken: this.accessToken,
      normalizedPhone,
      customerName,
      businessName,
      billNumber,
      totalAmount,
      currency,
      receiptText,
    });

    const messageId = data?.messages?.[0]?.id || `wamid.unknown.${Date.now()}`;
    return {
      success: true,
      messageId,
      whatsappPhoneNumberId: this.phoneNumberId,
      recipient: normalizedPhone,
      isCustomApi: false,
      isSimulated: false,
    };
  }

  /**
   * Verify Meta Webhook Verification Request (GET /api/whatsapp/webhook)
   */
  verifyWebhookChallenge(query) {
    const mode = query['hub.mode'];
    const token = query['hub.verify_token'];
    const challenge = query['hub.challenge'];

    if (mode === 'subscribe' && token === this.webhookVerifyToken) {
      return challenge;
    }
    return null;
  }

  /**
   * Verify HMAC signature for Meta Webhook events (POST /api/whatsapp/webhook)
   */
  verifyWebhookSignature(signatureHeader, rawBody) {
    if (!this.appSecret) return true; // Bypass if secret is not set
    if (!signatureHeader) return false;

    const parts = signatureHeader.split('=');
    if (parts.length !== 2 || parts[0] !== 'sha256') return false;

    const signature = parts[1];
    const expectedSignature = crypto
      .createHmac('sha256', this.appSecret)
      .update(rawBody || '')
      .digest('hex');

    return crypto.timingSafeEqual(Buffer.from(signature, 'hex'), Buffer.from(expectedSignature, 'hex'));
  }

  /**
   * Parse status updates from WhatsApp webhook payload
   */
  extractStatusesFromPayload(payload) {
    const updates = [];
    if (!payload?.entry || !Array.isArray(payload.entry)) return updates;

    for (const entry of payload.entry) {
      if (!entry.changes || !Array.isArray(entry.changes)) continue;
      for (const change of entry.changes) {
        if (change.value && Array.isArray(change.value.statuses)) {
          for (const statusObj of change.value.statuses) {
            updates.push({
              messageId: statusObj.id,
              status: (statusObj.status || '').toUpperCase(), // SENT, DELIVERED, READ, FAILED
              recipientId: statusObj.recipient_id,
              timestamp: statusObj.timestamp ? new Date(Number(statusObj.timestamp) * 1000) : new Date(),
              errors: statusObj.errors || null,
            });
          }
        }
      }
    }
    return updates;
  }

  /**
   * Send direct text reply message to customer via Meta WhatsApp Cloud API
   */
  async sendChatMessage({
    to,
    text,
    message,
    messageType = 'text',
    mediaUrl = '',
    phoneNumberId = null,
    accessToken = null,
  }) {
    const normalizedPhone = this.normalizePhoneNumber(to);
    if (!this.isValidPhoneNumber(normalizedPhone)) {
      throw ApiError.badRequest(
        `Invalid customer WhatsApp phone number: ${to}`,
        null,
        'INVALID_PHONE_NUMBER'
      );
    }

    const messageContent = (text !== undefined && text !== null ? text : message) || '';

    const activePhoneNumberId = phoneNumberId || this.phoneNumberId;
    const activeAccessToken = accessToken || this.accessToken;

    if (
      process.env.NODE_ENV === 'test' ||
      !activeAccessToken ||
      activeAccessToken === 'mock_token' ||
      activeAccessToken === 'test_token'
    ) {
      console.warn(`[WhatsAppService] ⚠️ SIMULATION MODE: Real chat message was not sent to ${normalizedPhone}. Generated mock messageId.`);
      const mockMessageId = `wamid.HBg${Date.now()}${Math.floor(Math.random() * 1000000)}==`;
      return {
        success: true,
        messageId: mockMessageId,
        whatsappPhoneNumberId: activePhoneNumberId,
        recipient: normalizedPhone,
        isSimulated: true,
      };
    }

    const url = `https://graph.facebook.com/${this.apiVersion}/${activePhoneNumberId}/messages`;
    const isImage = (messageType === 'image' || Boolean(mediaUrl)) && Boolean(mediaUrl);

    if (!isImage && !messageContent.toString().trim()) {
      throw ApiError.badRequest('WhatsApp text message body cannot be empty', null, 'EMPTY_MESSAGE_TEXT');
    }

    let imagePayload = null;
    if (isImage) {
      let isLocalOrPrivate = false;
      let localDiskPath = null;

      // Check if mediaUrl is a local disk file path
      if (fs.existsSync(mediaUrl)) {
        isLocalOrPrivate = true;
        localDiskPath = mediaUrl;
      } else if (typeof mediaUrl === 'string' && (mediaUrl.startsWith('/uploads/') || mediaUrl.includes('/uploads/'))) {
        const relPath = mediaUrl.substring(mediaUrl.indexOf('/uploads/'));
        const diskPath = path.join(__dirname, '../../public', relPath);
        if (fs.existsSync(diskPath)) {
          isLocalOrPrivate = true;
          localDiskPath = diskPath;
        }
      } else if (typeof mediaUrl === 'string' && /^(https?:\/\/)?(localhost|127\.0\.0\.1|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|10\.)/i.test(mediaUrl)) {
        isLocalOrPrivate = true;
      }

      if (isLocalOrPrivate) {
        try {
          let buffer = null;
          let mime = 'image/jpeg';
          let name = 'image.jpg';

          if (localDiskPath && fs.existsSync(localDiskPath)) {
            buffer = fs.readFileSync(localDiskPath);
            name = path.basename(localDiskPath);
            const ext = path.extname(name).toLowerCase();
            if (ext === '.png') mime = 'image/png';
            else if (ext === '.webp') mime = 'image/webp';
          } else if (typeof mediaUrl === 'string' && mediaUrl.startsWith('http')) {
            const res = await fetch(mediaUrl);
            const arrayBuf = await res.arrayBuffer();
            buffer = Buffer.from(arrayBuf);
          }

          if (buffer) {
            const metaMediaId = await this.uploadMediaToMeta({
              fileBuffer: buffer,
              mimeType: mime,
              fileName: name,
              phoneNumberId: activePhoneNumberId,
              accessToken: activeAccessToken,
            });
            imagePayload = { id: metaMediaId };
          }
        } catch (uploadErr) {
          console.warn('[WhatsAppService] Direct Meta media upload attempt failed, falling back to link:', uploadErr.message);
        }
      }

      if (!imagePayload) {
        imagePayload = { link: mediaUrl };
      }

      if (messageContent && messageContent.toString().trim()) {
        imagePayload.caption = messageContent.toString().trim();
      }
    }

    const payload = {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: normalizedPhone,
      type: isImage ? 'image' : 'text',
      ...(isImage
        ? { image: imagePayload }
        : { text: { preview_url: false, body: messageContent.toString() } }),
    };

    let response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${activeAccessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    let data = await response.json().catch(() => ({}));

    // If Meta failed on link download, attempt fallback via direct Meta Media API upload
    if (!response.ok && isImage && imagePayload?.link && !imagePayload?.id) {
      try {
        console.log('[WhatsAppService] Retrying image send via direct Meta Media API upload...');
        const fetchRes = await fetch(mediaUrl);
        if (fetchRes.ok) {
          const arrayBuf = await fetchRes.arrayBuffer();
          const buffer = Buffer.from(arrayBuf);
          const metaMediaId = await this.uploadMediaToMeta({
            fileBuffer: buffer,
            mimeType: fetchRes.headers.get('content-type') || 'image/jpeg',
            fileName: 'whatsapp_image.jpg',
            phoneNumberId: activePhoneNumberId,
            accessToken: activeAccessToken,
          });

          const retryPayload = {
            messaging_product: 'whatsapp',
            recipient_type: 'individual',
            to: normalizedPhone,
            type: 'image',
            image: {
              id: metaMediaId,
              ...(text && text.trim() ? { caption: text.trim() } : {}),
            },
          };

          const retryResponse = await fetch(url, {
            method: 'POST',
            headers: {
              'Authorization': `Bearer ${activeAccessToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify(retryPayload),
          });

          if (retryResponse.ok) {
            response = retryResponse;
            data = await retryResponse.json().catch(() => ({}));
          }
        }
      } catch (retryErr) {
        console.warn('[WhatsAppService] Media retry failed:', retryErr.message);
      }
    }

    if (!response.ok) {
      const errorCode = data?.error?.code || 'WHATSAPP_API_ERROR';
      let errorMsg = data?.error?.message || `WhatsApp API error: ${response.statusText}`;

      // 1. Error 131047: Customer is outside 24-hour customer service window
      // Attempt sending an approved Meta Template (e.g. pos_ebill_receipt or hello_world) to re-engage
      if (errorCode === 131047) {
        console.warn(`[WhatsAppService] Customer ${normalizedPhone} is outside the 24-hour window. Attempting re-engagement template dispatch...`);
        const templateCandidates = [this.templateName, 'hello_world'].filter(Boolean);
        for (const tName of templateCandidates) {
          try {
            const templatePayload = {
              messaging_product: 'whatsapp',
              recipient_type: 'individual',
              to: normalizedPhone,
              type: 'template',
              template: {
                name: tName,
                language: { code: 'en_US' },
              },
            };
            const templateRes = await fetch(url, {
              method: 'POST',
              headers: {
                'Authorization': `Bearer ${activeAccessToken}`,
                'Content-Type': 'application/json',
              },
              body: JSON.stringify(templatePayload),
            });
            const templateData = await templateRes.json().catch(() => ({}));
            if (templateRes.ok) {
              console.log(`[WhatsAppService] ✅ Re-engagement template '${tName}' sent successfully to ${normalizedPhone}`);
              const messageId = templateData?.messages?.[0]?.id || `wamid.template.${Date.now()}`;
              return {
                success: true,
                messageId,
                whatsappPhoneNumberId: activePhoneNumberId,
                recipient: normalizedPhone,
                isSimulated: false,
                isTemplateFallback: true,
              };
            }
          } catch (tErr) {
            console.warn(`[WhatsAppService] Template candidate '${tName}' dispatch notice:`, tErr.message);
          }
        }
        errorMsg = `Meta 24-Hour Policy Window: Customer (${normalizedPhone}) has not replied in the last 24 hours. Under Meta WhatsApp policies, a conversation must be re-opened with a Meta-approved template before sending free-form text.`;
      } else if (errorCode === 131030) {
        errorMsg = `Meta WhatsApp Sandbox Restriction: Customer number (${normalizedPhone}) is not added to your Meta Developer Allowed Phone Numbers list. In Development Mode, add this number in Meta Console (WhatsApp > API Setup > To), or switch the app to Live Mode to send to all customer numbers.`;
      }

      console.error('[WhatsAppService] Send chat message failed:', data?.error || data);
      throw ApiError.badRequest(errorMsg, null, errorCode);
    }

    const messageId = data?.messages?.[0]?.id || `wamid.unknown.${Date.now()}`;
    return {
      success: true,
      messageId,
      whatsappPhoneNumberId: activePhoneNumberId,
      recipient: normalizedPhone,
      isSimulated: false,
    };
  }

  /**
   * Send Authentication OTP via Meta WhatsApp Cloud API
   * Uses approved AUTHENTICATION template ('apna_pos_auth_otp')
   * with fallback to direct text message if 24-hr customer window is open
   */
  async sendOtpMessage({
    to,
    otpCode,
    phoneNumberId = null,
    accessToken = null,
  }) {
    const normalizedPhone = this.normalizePhoneNumber(to);
    if (!this.isValidPhoneNumber(normalizedPhone)) {
      throw ApiError.badRequest(
        `Invalid customer WhatsApp phone number: ${to}`,
        null,
        'INVALID_PHONE_NUMBER'
      );
    }

    const activePhoneNumberId = phoneNumberId || this.phoneNumberId;
    const activeAccessToken = accessToken || this.accessToken;

    // Check if the recipient is the same as the Apna POS sender phone number (e.g. 917303632949)
    if (normalizedPhone === '917303632949') {
      throw ApiError.badRequest(
        'Cannot send WhatsApp OTP to the Apna POS WhatsApp business number (+91 73036 32949). Meta WhatsApp API does not allow a business number to send messages to itself. Please test with a different phone number.',
        null,
        'SELF_MESSAGE_NOT_ALLOWED'
      );
    }

    if (
      process.env.NODE_ENV === 'test' ||
      !activeAccessToken ||
      activeAccessToken === 'mock_token' ||
      activeAccessToken === 'test_token'
    ) {
      console.warn(`[WhatsAppService] ⚠️ SIMULATION MODE: OTP ${otpCode} simulated for ${normalizedPhone}`);
      return {
        success: true,
        messageId: `wamid.HBg${Date.now()}${Math.floor(Math.random() * 1000000)}==`,
        recipient: normalizedPhone,
        isSimulated: true,
      };
    }

    const url = `https://graph.facebook.com/${this.apiVersion}/${activePhoneNumberId}/messages`;

    // 1. First attempt: Official Meta AUTHENTICATION Template ('apna_pos_auth_otp')
    const templateCandidates = [
      { name: 'apna_pos_auth_otp', lang: 'en_US' },
      { name: 'apna_pos_auth_otp', lang: 'en' },
    ];

    for (const t of templateCandidates) {
      try {
        const templatePayload = {
          messaging_product: 'whatsapp',
          recipient_type: 'individual',
          to: normalizedPhone,
          type: 'template',
          template: {
            name: t.name,
            language: { code: t.lang },
            components: [
              {
                type: 'body',
                parameters: [{ type: 'text', text: String(otpCode) }],
              },
              {
                type: 'button',
                sub_type: 'url',
                index: '0',
                parameters: [{ type: 'text', text: String(otpCode) }],
              },
            ],
          },
        };

        const res = await fetch(url, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${activeAccessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(templatePayload),
        });

        const data = await res.json().catch(() => ({}));
        if (res.ok && data?.messages?.[0]?.id) {
          console.log(`[WhatsAppService] ✅ OTP sent via template '${t.name}' (${t.lang}) to ${normalizedPhone}`);
          return {
            success: true,
            messageId: data.messages[0].id,
            recipient: normalizedPhone,
            viaTemplate: true,
          };
        } else {
          console.warn(`[WhatsAppService] Template '${t.name}' (${t.lang}) dispatch notice:`, data?.error?.message || data?.error);
        }
      } catch (err) {
        console.warn(`[WhatsAppService] Template dispatch error (${t.name}):`, err.message);
      }
    }

    // 2. Second attempt: Fall back to direct text message (works if customer sent a message in last 24h)
    const textBody = `*Apna POS Verification Code*\n\nYour login verification OTP is: *${otpCode}*\n\nThis OTP is valid for 5 minutes. Do not share this code with anyone.`;
    const textPayload = {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: normalizedPhone,
      type: 'text',
      text: { preview_url: false, body: textBody },
    };

    const textRes = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${activeAccessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(textPayload),
    });

    const textData = await textRes.json().catch(() => ({}));
    if (textRes.ok && textData?.messages?.[0]?.id) {
      console.log(`[WhatsAppService] ✅ OTP sent via direct text message to ${normalizedPhone}`);
      return {
        success: true,
        messageId: textData.messages[0].id,
        recipient: normalizedPhone,
        viaText: true,
      };
    }

    const errCode = textData?.error?.code;
    let errMsg = textData?.error?.message || 'Failed to dispatch WhatsApp OTP';
    if (errCode === 131047) {
      errMsg = `Meta WhatsApp 24-Hour Policy: To receive an OTP, please first send 'Hi' to +91 73036 32949 on WhatsApp, or wait for Meta to approve the authentication template.`;
    }
    throw ApiError.badRequest(errMsg, null, errCode || 'OTP_DISPATCH_FAILED');
  }

  /**
   * Upload image buffer directly to Meta WhatsApp Cloud API Media endpoint
   * POST https://graph.facebook.com/v21.0/{phone_number_id}/media
   */
  async uploadMediaToMeta({
    fileBuffer,
    mimeType = 'image/jpeg',
    fileName = 'image.jpg',
    phoneNumberId = null,
    accessToken = null,
  }) {
    const activePhoneNumberId = phoneNumberId || this.phoneNumberId;
    const activeAccessToken = accessToken || this.accessToken;

    const formData = new FormData();
    formData.append('messaging_product', 'whatsapp');
    formData.append('type', mimeType);
    const blob = new Blob([fileBuffer], { type: mimeType });
    formData.append('file', blob, fileName);

    const uploadUrl = `https://graph.facebook.com/${this.apiVersion}/${activePhoneNumberId}/media`;
    const res = await fetch(uploadUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${activeAccessToken}`,
      },
      body: formData,
    });

    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      console.error('[WhatsAppService] Meta media upload failed:', data);
      throw new Error(data?.error?.message || `Meta media upload failed: ${res.statusText}`);
    }

    return data.id;
  }

  /**
   * Download a media file (image/document/video) from Meta WhatsApp Cloud API using its mediaId
   * Step 1: GET https://graph.facebook.com/v21.0/{mediaId} to obtain the temporary direct download URL
   * Step 2: GET {directUrl} with Bearer token authorization to get raw binary buffer
   */
  async downloadMediaFromMeta(mediaId, accessToken = null) {
    const token = accessToken || this.accessToken;
    if (!mediaId || !token || token === 'mock_token' || token === 'test_token') {
      return null;
    }

    try {
      // Step 1: Query Meta Graph API for media object metadata
      const metaUrl = `https://graph.facebook.com/${this.apiVersion}/${mediaId}`;
      const metaRes = await fetch(metaUrl, {
        headers: {
          'Authorization': `Bearer ${token}`,
        },
      });

      if (!metaRes.ok) {
        const errText = await metaRes.text().catch(() => '');
        console.error(`[WhatsAppService] Failed to query media metadata for ${mediaId}:`, errText);
        return null;
      }

      const metaData = await metaRes.json();
      const directUrl = metaData.url;
      if (!directUrl) {
        console.error(`[WhatsAppService] No download URL returned for mediaId ${mediaId}`);
        return null;
      }

      // Step 2: Download raw binary bytes from Meta lookaside URL
      const downloadRes = await fetch(directUrl, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'User-Agent': 'curl/7.68.0',
        },
      });

      if (!downloadRes.ok) {
        console.error(`[WhatsAppService] Failed to download media binary for ${mediaId}:`, downloadRes.statusText);
        return null;
      }

      const arrayBuffer = await downloadRes.arrayBuffer();
      return {
        buffer: Buffer.from(arrayBuffer),
        mimeType: metaData.mime_type || 'image/jpeg',
        fileSize: metaData.file_size,
        mediaId,
      };
    } catch (err) {
      console.error(`[WhatsAppService] Exception in downloadMediaFromMeta:`, err.message);
      return null;
    }
  }

  /**
   * Parse incoming messages from WhatsApp webhook payload
   */
  extractMessagesFromPayload(payload) {
    const incomingMessages = [];
    if (!payload?.entry || !Array.isArray(payload.entry)) return incomingMessages;

    for (const entry of payload.entry) {
      if (!entry.changes || !Array.isArray(entry.changes)) continue;
      for (const change of entry.changes) {
        const val = change.value;
        if (!val) continue;

        const metadata = val.metadata || {};
        const phoneNumberId = metadata.phone_number_id || '';
        const displayPhoneNumber = metadata.display_phone_number || '';
        const contactsMap = {};
        if (Array.isArray(val.contacts)) {
          for (const c of val.contacts) {
            contactsMap[c.wa_id] = c.profile?.name || '';
          }
        }

        if (Array.isArray(val.messages)) {
          for (const msg of val.messages) {
            let bodyText = '';
            let mediaId = '';
            let mimeType = '';
            if (msg.type === 'text') {
              bodyText = msg.text?.body || '';
            } else if (msg.type === 'button') {
              bodyText = msg.button?.text || '';
            } else if (msg.type === 'interactive') {
              bodyText = msg.interactive?.button_reply?.title || msg.interactive?.list_reply?.title || '';
            } else if (msg.type === 'image') {
              bodyText = msg.image?.caption || '[Photo]';
              mediaId = msg.image?.id || '';
              mimeType = msg.image?.mime_type || 'image/jpeg';
            } else if (msg.type === 'document') {
              bodyText = msg.document?.caption || msg.document?.filename || '[Document]';
              mediaId = msg.document?.id || '';
              mimeType = msg.document?.mime_type || 'application/pdf';
            } else if (msg.type === 'audio' || msg.type === 'voice') {
              bodyText = '[Voice note]';
              mediaId = (msg.audio || msg.voice)?.id || '';
              mimeType = (msg.audio || msg.voice)?.mime_type || 'audio/ogg';
            } else if (msg.type === 'video') {
              bodyText = msg.video?.caption || '[Video]';
              mediaId = msg.video?.id || '';
              mimeType = msg.video?.mime_type || 'video/mp4';
            } else if (msg.type === 'location') {
              bodyText = `[Location: ${msg.location?.latitude}, ${msg.location?.longitude}]`;
            } else if (msg.type === 'reaction') {
              bodyText = msg.reaction?.emoji || '[Reaction]';
            } else {
              bodyText = `[${msg.type || 'Message'}]`;
            }

            incomingMessages.push({
              phoneNumberId,
              displayPhoneNumber,
              from: msg.from, // e.g. "919709593705"
              customerName: contactsMap[msg.from] || '',
              messageId: msg.id,
              timestamp: msg.timestamp ? new Date(Number(msg.timestamp) * 1000) : new Date(),
              type: msg.type || 'text',
              body: bodyText,
              mediaId,
              mimeType,
            });
          }
        }
      }
    }
    return incomingMessages;
  }
}

module.exports = new WhatsAppService();
