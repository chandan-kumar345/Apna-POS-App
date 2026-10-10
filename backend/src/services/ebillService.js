const mongoose = require('mongoose');
const EBill = require('../models/EBill');
const Order = require('../models/Order');
const Customer = require('../models/Customer');
const Business = require('../models/Business');
const walletService = require('./walletService');
const whatsappService = require('./whatsappService');
const ApiError = require('../utils/ApiError');

class EbillService {
  /**
   * Find order/bill by ID, orderNumber, or clientSyncId within business scope
   */
  async findOrder(businessId, billId) {
    if (!billId) return null;
    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;

    const queryConditions = [{ businessId: bId }];
    const idStr = billId.toString().trim();

    if (mongoose.Types.ObjectId.isValid(idStr)) {
      queryConditions.push({
        $or: [
          { _id: new mongoose.Types.ObjectId(idStr) },
          { orderNumber: idStr },
          { clientSyncId: idStr },
          { idempotencyKey: idStr },
        ],
      });
    } else {
      queryConditions.push({
        $or: [
          { orderNumber: idStr },
          { clientSyncId: idStr },
          { idempotencyKey: idStr },
        ],
      });
    }

    return Order.findOne({ $and: queryConditions });
  }

  /**
   * Check eBill eligibility for a bill & business
   */
  async checkEligibility(businessId, billId) {
    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;

    const walletEligibility = await walletService.checkEligibility(bId);
    const order = await this.findOrder(bId, billId);

    if (!order) {
      return {
        success: true,
        eligible: false,
        customerPhonePresent: false,
        walletBalance: walletEligibility.balance,
        ebillCharge: walletEligibility.ebillCharge,
        currency: walletEligibility.currency,
        reason: 'BILL_NOT_FOUND',
      };
    }

    // Resolve customer phone
    let customerPhone = (order.customerPhone || '').toString().trim();
    let customerName = (order.customerName || '').toString().trim();

    if (!customerPhone && order.customerId) {
      const customer = await Customer.findOne({ _id: order.customerId, businessId: bId });
      if (customer) {
        customerPhone = (customer.phone || '').toString().trim();
        if (!customerName) customerName = customer.name || '';
      }
    }

    const hasValidPhone = Boolean(customerPhone && whatsappService.isValidPhoneNumber(customerPhone));

    if (!hasValidPhone) {
      return {
        success: true,
        eligible: false,
        customerPhonePresent: false,
        walletBalance: walletEligibility.balance,
        ebillCharge: walletEligibility.ebillCharge,
        currency: walletEligibility.currency,
        reason: 'CUSTOMER_PHONE_REQUIRED',
      };
    }

    if (!walletEligibility.eligible) {
      return {
        success: true,
        eligible: false,
        customerPhonePresent: true,
        customerPhone,
        customerName,
        walletBalance: walletEligibility.balance,
        ebillCharge: walletEligibility.ebillCharge,
        currency: walletEligibility.currency,
        reason: 'INSUFFICIENT_WALLET_BALANCE',
      };
    }

    return {
      success: true,
      eligible: true,
      customerPhonePresent: true,
      customerPhone,
      customerName,
      walletBalance: walletEligibility.balance,
      ebillCharge: walletEligibility.ebillCharge,
      currency: walletEligibility.currency,
      remainingAfterSend: walletEligibility.remainingAfterSend,
      reason: null,
    };
  }

  /**
   * Format digital receipt text representation from final persisted bill
   */
  generateReceiptText(order, business) {
    const restName = business?.profile?.companyName || business?.profile?.name || 'Apna POS Store';
    const restPhone = business?.profile?.phone || '';
    const restAddress = business?.address?.addressLine || business?.address?.city || '';
    const gstNo = business?.orderSettings?.tax?.gstNumber || '';

    const lines = [];
    lines.push(`================================`);
    lines.push(`       ${restName.toUpperCase()}       `);
    if (restAddress) lines.push(restAddress);
    if (restPhone) lines.push(`Ph: ${restPhone}`);
    if (gstNo) lines.push(`GST: ${gstNo}`);
    lines.push(`================================`);
    lines.push(`Bill No: #${order.orderNumber}`);
    lines.push(`Date: ${order.createdAt ? new Date(order.createdAt).toLocaleString('en-IN') : new Date().toLocaleString('en-IN')}`);
    if (order.customerName) lines.push(`Customer: ${order.customerName}`);
    if (order.tableNumber) lines.push(`Table: ${order.tableNumber}`);
    lines.push(`--------------------------------`);
    lines.push(`ITEMS:`);
    for (const item of (order.items || [])) {
      lines.push(`${item.name} x ${item.quantity} = ₹${(Number(item.price || 0) * Number(item.quantity || 1)).toFixed(2)}`);
    }
    lines.push(`--------------------------------`);
    lines.push(`Subtotal: ₹${Number(order.subtotal || 0).toFixed(2)}`);
    if (order.discountAmount > 0) lines.push(`Discount: -₹${Number(order.discountAmount).toFixed(2)}`);
    if (order.taxAmount > 0) lines.push(`Taxes (GST): +₹${Number(order.taxAmount).toFixed(2)}`);
    if (order.roundOff) lines.push(`Round Off: ₹${Number(order.roundOff).toFixed(2)}`);
    lines.push(`GRAND TOTAL: ₹${Number(order.totalAmount || 0).toFixed(2)}`);
    lines.push(`Payment: ${order.paymentMethod || 'Paid'}`);
    lines.push(`================================`);
    lines.push(`Thank you! Visit again.`);
    lines.push(`Powered by Apna POS`);

    return lines.join('\n');
  }

  /**
   * Send eBill to customer via WhatsApp with atomic wallet deduction and idempotency
   */
  async sendEbill({
    businessId,
    billId,
    customerId = null,
    idempotencyKey = '',
    customerPhoneOverride = null,
  }) {
    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;

    // 1. Authoritative Bill Retrieval
    const order = await this.findOrder(bId, billId);
    if (!order) {
      throw ApiError.notFound('Bill not found in your business records', 'BILL_NOT_FOUND');
    }

    // 2. Authoritative Customer Phone Resolution
    let phone = customerPhoneOverride || order.customerPhone || '';
    let name = order.customerName || '';

    if (!phone && (customerId || order.customerId)) {
      const cId = customerId || order.customerId;
      const customer = await Customer.findOne({ _id: cId, businessId: bId });
      if (customer) {
        phone = customer.phone || '';
        if (!name) name = customer.name || '';
      }
    }

    if (!phone || !whatsappService.isValidPhoneNumber(phone)) {
      throw ApiError.badRequest(
        "Customer's valid mobile phone number is required to send eBill through WhatsApp",
        null,
        'CUSTOMER_PHONE_REQUIRED'
      );
    }


    const normalizedPhone = whatsappService.normalizePhoneNumber(phone);

    // 3. Inspect existing eBill record for this bill
    let existingEbill = await EBill.findOne({
      businessId: bId,
      billId: order._id,
    });

    // If eBill was already successfully SENT or DELIVERED, return it to prevent duplicate send/charge
    if (existingEbill && (existingEbill.status === 'SENT' || existingEbill.status === 'DELIVERED')) {
      const currentWallet = await walletService.getOrCreateWallet(bId);
      return {
        success: true,
        message: 'eBill already sent for this bill',
        data: {
          ebillId: existingEbill._id,
          billId: order._id,
          status: existingEbill.status,
          deliveryStatus: existingEbill.deliveryStatus,
          whatsappMessageId: existingEbill.whatsappMessageId,
          amountCharged: existingEbill.amountCharged,
          currency: existingEbill.currency,
          walletBalance: currentWallet.balance,
          isDuplicate: true,
        },
      };
    }

    // 4. Resolve eBill Fee
    const ebillFee = await walletService.getEbillFee(bId);
    const txIdempotencyKey = idempotencyKey || `ebill_${bId}_${order._id}`;

    // 5. Wallet Deduction Safety
    let walletTx = null;
    let wallet = null;

    // Check if this eBill was already charged in a prior attempt (retry safety)
    const alreadyCharged = Boolean(existingEbill && existingEbill.walletTransactionId);

    if (!alreadyCharged) {
      // Deduct atomically from business wallet
      const deductResult = await walletService.deductWalletAtomic({
        businessId: bId,
        amount: ebillFee,
        category: 'EBILL',
        referenceType: 'EBILL',
        referenceId: order._id,
        idempotencyKey: txIdempotencyKey,
        description: `WhatsApp eBill for Bill #${order.orderNumber}`,
      });
      walletTx = deductResult.transaction;
      wallet = deductResult.wallet;
    } else {
      wallet = await walletService.getOrCreateWallet(bId);
    }

    // 6. Create or update EBill operation record
    if (!existingEbill) {
      existingEbill = await EBill.create({
        businessId: bId,
        billId: order._id,
        customerId: order.customerId || null,
        customerPhone: normalizedPhone,
        customerName: name,
        walletTransactionId: walletTx ? walletTx._id : null,
        amountCharged: alreadyCharged ? (existingEbill?.amountCharged || 0) : ebillFee,
        currency: wallet.currency || 'INR',
        whatsappPhoneNumberId: whatsappService.phoneNumberId,
        status: 'PROCESSING',
        deliveryStatus: 'PENDING',
        retryCount: 0,
      });
    } else {
      existingEbill.status = 'PROCESSING';
      existingEbill.retryCount = (existingEbill.retryCount || 0) + 1;
      if (walletTx && !existingEbill.walletTransactionId) {
        existingEbill.walletTransactionId = walletTx._id;
        existingEbill.amountCharged = ebillFee;
      }
      await existingEbill.save();
    }

    // 7. Load business details for receipt rendering
    const business = await Business.findById(bId);
    const receiptText = this.generateReceiptText(order, business);
    existingEbill.receiptText = receiptText;

    // 8. Submit to WhatsApp Cloud API
    try {
      const waResult = await whatsappService.sendEbillReceipt({
        to: normalizedPhone,
        customerName: name || 'Customer',
        businessName: business?.profile?.companyName || business?.profile?.name || 'Apna POS Store',
        billNumber: order.orderNumber,
        totalAmount: order.totalAmount,
        currency: order.currency || 'INR',
        receiptText,
        documentUrl: existingEbill.documentUrl,
      });

      // 9. Update eBill on WhatsApp acceptance
      existingEbill.whatsappMessageId = waResult.messageId;
      existingEbill.status = 'SENT';
      existingEbill.deliveryStatus = 'SENT';
      existingEbill.lastError = null;
      await existingEbill.save();

      // 10. Update Bill / Order eBill metadata
      await Order.updateOne(
        { _id: order._id },
        {
          ebill: {
            enabled: true,
            latestEbillId: existingEbill._id,
            lastSentAt: new Date(),
          },
        }
      );

      const refreshedWallet = await walletService.getOrCreateWallet(bId);

      return {
        success: true,
        message: 'eBill sent successfully via WhatsApp',
        data: {
          ebillId: existingEbill._id,
          billId: order._id,
          orderNumber: order.orderNumber,
          customerPhone: normalizedPhone,
          status: 'SENT',
          deliveryStatus: 'SENT',
          whatsappMessageId: waResult.messageId,
          amountCharged: existingEbill.amountCharged,
          currency: existingEbill.currency,
          walletBalance: refreshedWallet.balance,
        },
      };
    } catch (sendError) {
      // 11. WhatsApp Delivery Failure Handling
      console.error('[EbillService] WhatsApp sending error:', sendError.message);
      existingEbill.status = 'FAILED';
      existingEbill.deliveryStatus = 'FAILED';
      existingEbill.lastError = sendError.message || 'WhatsApp sending failed';
      await existingEbill.save();

      // Note: The bill remains completely saved! We do NOT delete the order.
      const currentWallet = await walletService.getOrCreateWallet(bId);
      throw ApiError.badRequest(
        `Bill saved, but WhatsApp delivery failed: ${sendError.message}. You can retry without extra charge.`,
        'WHATSAPP_SEND_FAILED'
      );
    }
  }

  /**
   * Get eBill status
   */
  async getEbillStatus(businessId, ebillId) {
    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;

    const ebill = await EBill.findOne({ _id: ebillId, businessId: bId });
    if (!ebill) {
      throw ApiError.notFound('eBill record not found', 'EBILL_NOT_FOUND');
    }

    return {
      ebillId: ebill._id,
      billId: ebill.billId,
      status: ebill.status,
      deliveryStatus: ebill.deliveryStatus,
      whatsappMessageId: ebill.whatsappMessageId,
      customerPhone: ebill.customerPhone,
      amountCharged: ebill.amountCharged,
      retryCount: ebill.retryCount,
      lastError: ebill.lastError,
      updatedAt: ebill.updatedAt,
    };
  }

  /**
   * Process Meta Webhook status update
   */
  async processWebhookStatusUpdate(update) {
    const { messageId, status, errors } = update;
    if (!messageId) return null;

    // Use query options with bypass since webhook is an unauthenticated callback from Meta
    const ebill = await EBill.findOne({ whatsappMessageId: messageId }, null, {
      _bypassTenantCheck: true,
    });

    if (!ebill) {
      return null;
    }

    ebill.deliveryStatus = status; // e.g. SENT, DELIVERED, READ, FAILED
    if (status === 'DELIVERED') {
      ebill.status = 'DELIVERED';
    } else if (status === 'FAILED') {
      ebill.status = 'FAILED';
      if (errors) ebill.lastError = errors;
    }
    await ebill.save();

    return ebill;
  }
}

module.exports = new EbillService();
