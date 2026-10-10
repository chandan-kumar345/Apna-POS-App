const crypto = require('crypto');
const whatsappConfig = require('../config/whatsapp.config');
const ApiError = require('../utils/ApiError');

class WhatsAppService {
  constructor() {
    this.phoneNumberId = whatsappConfig.phoneNumberId;
    this.accessToken = whatsappConfig.accessToken;
    this.apiVersion = whatsappConfig.apiVersion;
    this.webhookVerifyToken = whatsappConfig.webhookVerifyToken;
    this.appSecret = whatsappConfig.appSecret;
    this.templateName = whatsappConfig.templateName;
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
    // Indian 10-digit mobile number check
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
  async sendEbillReceipt({
    to,
    customerName = 'Customer',
    businessName = 'Apna POS Store',
    billNumber,
    totalAmount,
    currency = 'INR',
    receiptText = '',
    documentUrl = null,
  }) {
    const normalizedPhone = this.normalizePhoneNumber(to);
    if (!this.isValidPhoneNumber(normalizedPhone)) {
      throw ApiError.badRequest(
        `Invalid customer WhatsApp phone number: ${to}`,
        null,
        'INVALID_PHONE_NUMBER'
      );
    }


    // In test environment or when access token is not configured, simulate successful API response
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
        isSimulated: true,
      };
    }

    const url = `https://graph.facebook.com/${this.apiVersion}/${this.phoneNumberId}/messages`;

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

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    const data = await response.json().catch(() => ({}));

    if (!response.ok) {
      const errorMsg = data?.error?.message || `WhatsApp API error: ${response.statusText}`;
      const errorCode = data?.error?.code || 'WHATSAPP_API_ERROR';
      console.error('[WhatsAppService] Send failed:', data?.error || data);
      throw ApiError.badRequest(errorMsg, null, errorCode);
    }


    const messageId = data?.messages?.[0]?.id || `wamid.unknown.${Date.now()}`;
    return {
      success: true,
      messageId,
      whatsappPhoneNumberId: this.phoneNumberId,
      recipient: normalizedPhone,
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
}

module.exports = new WhatsAppService();
