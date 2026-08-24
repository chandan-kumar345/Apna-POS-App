const razorpayService = require('../services/razorpayService');

class PaymentController {
  /**
   * POST /api/v1/payments/create-qr
   * Create dynamic UPI QR for an order
   */
  async createUpiQr(req, res, next) {
    try {
      const { orderId, orderNumber, amount, customerName, customerPhone, notes } = req.body;
      const businessId = req.businessId;

      if (!amount || Number(amount) <= 0) {
        return res.status(400).json({
          success: false,
          error: { code: 'INVALID_AMOUNT', message: 'Amount must be greater than 0' },
        });
      }

      const result = await razorpayService.createDynamicUpiQr({
        businessId,
        orderId,
        orderNumber,
        amount: Number(amount),
        customerName,
        customerPhone,
        notes,
      });

      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/v1/payments/status/:orderId
   * Check real-time payment status
   */
  async getPaymentStatus(req, res, next) {
    try {
      const { orderId } = req.params;
      const businessId = req.businessId;

      const result = await razorpayService.checkOrderPaymentStatus(orderId, businessId);

      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/payments/webhook
   * Public webhook endpoint for Razorpay payment notifications
   */
  async handleWebhook(req, res, next) {
    try {
      const signature = req.headers['x-razorpay-signature'];
      const rawBody = req.rawBody || JSON.stringify(req.body);

      // Verify signature
      const isValid = razorpayService.verifyWebhookSignature(rawBody, signature);
      if (!isValid) {
        console.warn('[PaymentController.handleWebhook] Invalid webhook signature');
        return res.status(400).json({
          success: false,
          error: { code: 'INVALID_SIGNATURE', message: 'Webhook signature verification failed' },
        });
      }

      const result = await razorpayService.handleWebhook(req.body);

      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (error) {
      console.error('[PaymentController.handleWebhook] Error processing webhook:', error);
      return res.status(500).json({
        success: false,
        error: { code: 'WEBHOOK_PROCESSING_ERROR', message: error.message },
      });
    }
  }
}

module.exports = new PaymentController();
