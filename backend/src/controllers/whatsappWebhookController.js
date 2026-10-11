const whatsappService = require('../services/whatsappService');
const ebillService = require('../services/ebillService');
const whatsappChatService = require('../services/whatsappChatService');

class WhatsAppWebhookController {
  /**
   * GET /api/v1/whatsapp/webhook or /api/whatsapp/webhook
   * Meta Webhook Verification
   */
  async verifyWebhook(req, res) {
    try {
      const challenge = whatsappService.verifyWebhookChallenge(req.query);
      if (challenge) {
        console.log('[WhatsAppWebhook] Verification challenge accepted');
        return res.status(200).send(challenge);
      }
      console.warn('[WhatsAppWebhook] Verification token mismatch or invalid mode');
      return res.status(403).send('Forbidden');
    } catch (err) {
      console.error('[WhatsAppWebhook] Error during verification:', err);
      return res.status(500).send('Error');
    }
  }

  /**
   * POST /api/v1/whatsapp/webhook or /api/whatsapp/webhook
   * Meta Delivery Status, Customer Inbound Messages & Failure Events
   */
  async handleWebhook(req, res) {
    try {
      // 1. Validate signature if app secret is configured
      const signatureHeader = req.headers['x-hub-signature-256'];
      if (!whatsappService.verifyWebhookSignature(signatureHeader, req.rawBody)) {
        console.warn('[WhatsAppWebhook] Invalid signature received from webhook caller');
        return res.status(401).json({ error: 'Invalid webhook signature' });
      }

      // 2. Extract delivery status updates
      const statusUpdates = whatsappService.extractStatusesFromPayload(req.body);

      // 3. Update eBills and live chat message statuses
      for (const update of statusUpdates) {
        try {
          await ebillService.processWebhookStatusUpdate(update);
          await whatsappChatService.processWebhookStatusUpdate(update);
        } catch (updateErr) {
          console.error('[WhatsAppWebhook] Error updating status for message:', update.messageId, updateErr);
        }
      }

      // 4. Extract incoming customer replies / messages
      const incomingMessages = whatsappService.extractMessagesFromPayload(req.body);
      if (incomingMessages.length > 0 || statusUpdates.length > 0) {
        console.log(`[WhatsAppWebhook] 📬 Received webhook event: ${incomingMessages.length} inbound message(s), ${statusUpdates.length} status update(s)`);
      }

      for (const msg of incomingMessages) {
        try {
          await whatsappChatService.processIncomingWebhookMessage(msg);
        } catch (msgErr) {
          console.error('[WhatsAppWebhook] ❌ Error processing incoming customer chat message:', msgErr);
        }
      }

      // Always return 200 OK immediately to Meta
      return res.status(200).json({
        success: true,
        processedStatuses: statusUpdates.length,
        processedMessages: incomingMessages.length,
      });
    } catch (err) {
      console.error('[WhatsAppWebhook] Error processing webhook:', err);
      // Return 200 to acknowledge webhook so Meta does not repeatedly retry corrupt payloads
      return res.status(200).json({ success: false, error: err.message });
    }
  }
}

module.exports = new WhatsAppWebhookController();
