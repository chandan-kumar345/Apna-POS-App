const crypto = require('crypto');
const Razorpay = require('razorpay');
const env = require('../config/env');
const Order = require('../models/Order');
const Business = require('../models/Business');

class RazorpayService {
  /**
   * Get Razorpay instance initialized with active credentials
   */
  getRazorpayClient(customKeyId, customKeySecret) {
    const keyId = customKeyId || env.RAZORPAY_KEY_ID;
    const keySecret = customKeySecret || env.RAZORPAY_KEY_SECRET;

    if (!keyId || !keySecret) {
      return null;
    }

    return new Razorpay({
      key_id: keyId,
      key_secret: keySecret,
    });
  }

  /**
   * Check if Razorpay Gateway credentials are configured
   */
  isConfigured(customKeyId, customKeySecret) {
    const keyId = customKeyId || env.RAZORPAY_KEY_ID;
    const keySecret = customKeySecret || env.RAZORPAY_KEY_SECRET;
    return Boolean(keyId && keySecret && keyId.trim().length > 0 && keySecret.trim().length > 0);
  }

  /**
   * Create a Dynamic single-use UPI QR code for a specific Order
   */
  async createDynamicUpiQr({
    businessId,
    orderId,
    orderNumber,
    amount,
    customerName = '',
    customerPhone = '',
    notes = {},
  }) {
    if (!amount || amount <= 0) {
      throw new Error('Order amount must be greater than 0');
    }

    // Verify order exists
    let order = null;
    if (orderId) {
      order = await Order.findOne({ _id: orderId, businessId });
    }

    // Fetch business details for UPI fallback
    const business = await Business.findById(businessId);
    const businessName = business?.name || 'Apna POS';
    const businessUpi = business?.upiId || business?.settings?.upiId || 'apnapos@razorpay';

    const amountInPaise = Math.round(Number(amount) * 100);
    const orderNum = orderNumber || order?.orderNumber || `ORD-${Date.now()}`;
    const cleanOrderId = order?._id?.toString() || orderId?.toString() || '';

    const razorpay = this.getRazorpayClient();

    // 1. If Razorpay is configured, create live Dynamic QR Code via Gateway API
    if (razorpay) {
      try {
        const qrPayload = {
          type: 'upi_qr',
          name: `Bill ${orderNum}`,
          usage: 'single_payment',
          fixed_amount: true,
          payment_amount: amountInPaise,
          description: `Payment for Order #${orderNum} at ${businessName}`.substring(0, 250),
          notes: {
            orderId: cleanOrderId,
            orderNumber: orderNum,
            businessId: businessId ? businessId.toString() : '',
            customerName: customerName || '',
            customerPhone: customerPhone || '',
            ...notes,
          },
        };

        const rzpQr = await razorpay.qrCode.create(qrPayload);

        const qrImageUrl = rzpQr.image_url || '';
        const qrIntentUrl = rzpQr.intent_url || rzpQr.image_url || '';
        const qrExpiresAt = rzpQr.close_by ? new Date(rzpQr.close_by * 1000) : new Date(Date.now() + 15 * 60 * 1000);

        // Update Order if orderId is provided
        if (order) {
          order.razorpayQrId = rzpQr.id;
          order.qrImageUrl = qrImageUrl;
          order.qrIntentUrl = qrIntentUrl;
          order.qrExpiresAt = qrExpiresAt;
          await order.save();
        }

        return {
          success: true,
          isDynamicGateway: true,
          gateway: 'razorpay',
          qrId: rzpQr.id,
          qrImageUrl: qrImageUrl,
          qrIntentUrl: qrIntentUrl,
          amount: Number(amount),
          orderNumber: orderNum,
          orderId: cleanOrderId,
          expiresAt: qrExpiresAt.toISOString(),
        };
      } catch (gatewayErr) {
        console.error('[RazorpayService.createDynamicUpiQr] Gateway API error, falling back to static UPI intent:', gatewayErr.message);
        // Fall through to fallback
      }
    }

    // 2. Offline / Fallback Standard UPI Intent URL
    const encodedBusinessName = encodeURIComponent(businessName);
    const encodedNote = encodeURIComponent(`Bill ${orderNum}`);
    const fallbackUpiIntent = `upi://pay?pa=${businessUpi}&pn=${encodedBusinessName}&am=${Number(amount).toFixed(2)}&cu=INR&tr=${orderNum}&tn=${encodedNote}`;

    if (order) {
      order.qrIntentUrl = fallbackUpiIntent;
      await order.save();
    }

    return {
      success: true,
      isDynamicGateway: false,
      gateway: 'standard_upi',
      qrId: `static_${Date.now()}`,
      qrImageUrl: '',
      qrIntentUrl: fallbackUpiIntent,
      amount: Number(amount),
      orderNumber: orderNum,
      orderId: cleanOrderId,
      expiresAt: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
    };
  }

  /**
   * Cryptographically verify Razorpay webhook signature (HMAC SHA-256)
   */
  verifyWebhookSignature(rawBody, signature, customSecret) {
    const candidateSecrets = [
      customSecret,
      process.env.RAZORPAY_WEBHOOK_SECRET,
      env.RAZORPAY_WEBHOOK_SECRET,
      process.env.RAZORPAY_LIVE_WEBHOOK_SECRET,
      process.env.RAZORPAY_TEST_WEBHOOK_SECRET,
    ].filter(Boolean);

    if (candidateSecrets.length === 0) {
      if (env.NODE_ENV === 'test' || env.NODE_ENV === 'development') {
        return true;
      }
      return false;
    }

    if (!signature) {
      return false;
    }

    const bodyString = typeof rawBody === 'string' ? rawBody : (rawBody ? rawBody.toString('utf8') : '');

    // Verify against configured secrets (supports both test and live)
    for (const secret of candidateSecrets) {
      try {
        const expectedSignature = crypto
          .createHmac('sha256', secret)
          .update(bodyString)
          .digest('hex');

        if (expectedSignature.length === signature.length) {
          const isMatch = crypto.timingSafeEqual(
            Buffer.from(expectedSignature, 'utf8'),
            Buffer.from(signature, 'utf8')
          );
          if (isMatch) return true;
        }
      } catch (_) {}
    }

    console.error('[RazorpayService.verifyWebhookSignature] Verification failed against configured webhook secrets');
    return false;
  }

  /**
   * Process Razorpay Webhook Events idempotently
   * Handles: 'qr_code.credited', 'payment.captured', 'payment_link.paid'
   */
  async handleWebhook(eventPayload) {
    if (!eventPayload || !eventPayload.event) {
      return { success: false, message: 'Invalid webhook payload structure' };
    }

    const eventType = eventPayload.event;
    console.log(`[RazorpayService.handleWebhook] Processing event: ${eventType}`);

    let qrId = null;
    let paymentId = null;
    let amount = 0;
    let utr = '';
    let vpa = '';
    let notes = {};

    if (eventType === 'qr_code.credited') {
      const qrEntity = eventPayload.payload?.qr_code?.entity;
      const paymentEntity = eventPayload.payload?.payment?.entity;

      qrId = qrEntity?.id;
      paymentId = paymentEntity?.id || eventPayload.payload?.qr_code?.payment_id;
      amount = paymentEntity?.amount ? paymentEntity.amount / 100 : (qrEntity?.payment_amount ? qrEntity.payment_amount / 100 : 0);
      utr = paymentEntity?.acquirer_data?.rrn || paymentEntity?.acquirer_data?.upi_transaction_id || paymentId || '';
      vpa = paymentEntity?.vpa || '';
      notes = qrEntity?.notes || paymentEntity?.notes || {};
    } else if (eventType === 'payment.captured') {
      const paymentEntity = eventPayload.payload?.payment?.entity;
      paymentId = paymentEntity?.id;
      amount = paymentEntity?.amount ? paymentEntity.amount / 100 : 0;
      utr = paymentEntity?.acquirer_data?.rrn || paymentEntity?.acquirer_data?.upi_transaction_id || paymentId || '';
      vpa = paymentEntity?.vpa || '';
      notes = paymentEntity?.notes || {};
      qrId = notes?.qrId || null;
    } else {
      return { success: true, ignored: true, event: eventType };
    }

    // Locate the matching Order
    let order = null;
    if (qrId) {
      order = await Order.findOne({ razorpayQrId: qrId });
    }

    if (!order && notes?.orderId) {
      order = await Order.findById(notes.orderId);
    }

    if (!order && notes?.orderNumber) {
      order = await Order.findOne({ orderNumber: notes.orderNumber });
    }

    if (!order) {
      console.warn(`[RazorpayService.handleWebhook] No matching order found for QR: ${qrId}, Payment: ${paymentId}`);
      return { success: true, matched: false, message: 'No matching order found' };
    }

    // Idempotency: If order is already completed and paid with this paymentId
    if (order.isPaid && order.paymentStatus === 'paid' && order.razorpayPaymentId === paymentId) {
      return { success: true, idempotent: true, orderId: order._id, isPaid: true };
    }

    // Update order status to paid
    order.status = 'completed';
    order.paymentStatus = 'paid';
    order.isPaid = true;
    order.paymentMethod = 'UPI';
    order.paymentMode = 'UPI';
    order.razorpayPaymentId = paymentId || order.razorpayPaymentId;
    order.upiUtr = utr || order.upiUtr;
    order.upiVpa = vpa || order.upiVpa;
    order.completedAt = new Date();

    // Ensure paymentDetails record exists
    if (!order.paymentDetails || order.paymentDetails.length === 0) {
      order.paymentDetails = [
        {
          paymentType: 'UPI',
          paymentName: 'Razorpay UPI QR',
          amount: amount > 0 ? amount : order.totalAmount,
          paymentMethod: 'UPI',
        },
      ];
    } else {
      const hasUpi = order.paymentDetails.some((p) => p.paymentMethod === 'UPI' || p.paymentType === 'UPI');
      if (!hasUpi) {
        order.paymentDetails.push({
          paymentType: 'UPI',
          paymentName: 'Razorpay UPI QR',
          amount: amount > 0 ? amount : order.totalAmount,
          paymentMethod: 'UPI',
        });
      }
    }

    await order.save();
    console.log(`[RazorpayService.handleWebhook] Order #${order.orderNumber} successfully marked as PAID (UTR: ${order.upiUtr})`);

    return {
      success: true,
      orderId: order._id,
      orderNumber: order.orderNumber,
      isPaid: true,
      paymentId: order.razorpayPaymentId,
      utr: order.upiUtr,
    };
  }

  /**
   * Real-time verification of an order's payment status
   */
  async checkOrderPaymentStatus(orderId, businessId) {
    const query = { _id: orderId };
    if (businessId) {
      query.businessId = businessId;
    }

    const order = await Order.findOne(query);
    if (!order) {
      return { isPaid: false, paymentStatus: 'not_found' };
    }

    // If order is already recorded as paid
    if (order.isPaid || order.paymentStatus === 'paid') {
      return {
        isPaid: true,
        paymentStatus: 'paid',
        orderId: order._id,
        orderNumber: order.orderNumber,
        totalAmount: order.totalAmount,
        paymentMethod: order.paymentMethod,
        utr: order.upiUtr || '',
        paymentId: order.razorpayPaymentId || '',
        completedAt: order.completedAt || order.updatedAt,
      };
    }

    // If not marked paid in DB, but has active Razorpay QR ID, verify live against Razorpay API
    if (order.razorpayQrId) {
      const razorpay = this.getRazorpayClient();
      if (razorpay) {
        try {
          const paymentsList = await razorpay.qrCode.fetchAllPayments(order.razorpayQrId);
          if (paymentsList && paymentsList.items && paymentsList.items.length > 0) {
            const capturedPayment = paymentsList.items.find(
              (p) => p.status === 'captured' || p.status === 'authorized'
            );

            if (capturedPayment) {
              order.status = 'completed';
              order.paymentStatus = 'paid';
              order.isPaid = true;
              order.paymentMethod = 'UPI';
              order.paymentMode = 'UPI';
              order.razorpayPaymentId = capturedPayment.id;
              order.upiUtr = capturedPayment.acquirer_data?.rrn || capturedPayment.acquirer_data?.upi_transaction_id || capturedPayment.id;
              order.upiVpa = capturedPayment.vpa || '';
              order.completedAt = new Date();
              await order.save();

              return {
                isPaid: true,
                paymentStatus: 'paid',
                orderId: order._id,
                orderNumber: order.orderNumber,
                totalAmount: order.totalAmount,
                paymentMethod: 'UPI',
                utr: order.upiUtr,
                paymentId: order.razorpayPaymentId,
                completedAt: order.completedAt,
              };
            }
          }
        } catch (apiErr) {
          console.error('[RazorpayService.checkOrderPaymentStatus] Live API status check error:', apiErr.message);
        }
      }
    }

    return {
      isPaid: false,
      paymentStatus: order.paymentStatus || 'pending',
      orderId: order._id,
      orderNumber: order.orderNumber,
      totalAmount: order.totalAmount,
    };
  }
}

module.exports = new RazorpayService();
