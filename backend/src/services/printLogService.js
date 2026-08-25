const mongoose = require('mongoose');
const PrintLog = require('../models/PrintLog');
const Order = require('../models/Order');
const ApiError = require('../utils/ApiError');

class PrintLogService {
  /**
   * Helper to resolve date range filters
   */
  _resolveDateRange({ period, startDate, endDate, from, to } = {}) {
    const now = new Date();
    const effectiveFrom = from || startDate;
    const effectiveTo = to || endDate;

    if (effectiveFrom && effectiveTo) {
      let start = new Date(effectiveFrom);
      let end = new Date(effectiveTo);

      if (isNaN(start.getTime())) {
        start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
      } else if (typeof effectiveFrom === 'string' && !effectiveFrom.includes('T') && !effectiveFrom.includes(':')) {
        start.setHours(0, 0, 0, 0);
      }

      if (isNaN(end.getTime())) {
        end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
      } else if (typeof effectiveTo === 'string' && !effectiveTo.includes('T') && !effectiveTo.includes(':')) {
        end.setHours(23, 59, 59, 999);
      }
      return { start, end };
    }

    const p = (period || 'allTime').toLowerCase().trim();

    let start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
    let end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);

    if (p === 'today') {
      start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
      end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
    } else if (p === 'yesterday') {
      start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 0, 0, 0, 0);
      end = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 23, 59, 59, 999);
    } else if (p === 'thisweek' || p === 'week' || p === 'this week') {
      const day = now.getDay();
      const diffToMonday = (day === 0 ? -6 : 1) - day;
      start = new Date(now.getFullYear(), now.getMonth(), now.getDate() + diffToMonday, 0, 0, 0, 0);
      if (start > now) {
        start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        start.setHours(0, 0, 0, 0);
      }
      end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
    } else if (p === 'thismonth' || p === 'month' || p === 'this month') {
      start = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
      end = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
    } else if (p === 'thisyear' || p === 'year' || p === 'this year') {
      start = new Date(now.getFullYear(), 0, 1, 0, 0, 0, 0);
      end = new Date(now.getFullYear(), 11, 31, 23, 59, 59, 999);
    } else if (p === 'alltime' || p === 'all time' || p === 'all') {
      start = new Date(0);
      end = new Date(now.getFullYear() + 1, 11, 31, 23, 59, 59, 999);
    }

    return { start, end };
  }

  /**
   * Fetch all print logs with filtering and pagination
   */
  async getPrintLogs(businessId, {
    page = 1,
    limit = 50,
    period,
    startDate,
    endDate,
    orderNumber,
    paymentStatus,
    orderStatus,
    printType,
    search,
  } = {}) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;
    const query = { businessId: bId };

    if (startDate || endDate || (period && period !== 'allTime' && period !== 'all')) {
      const { start, end } = this._resolveDateRange({ period, startDate, endDate });
      query.createdAt = { $gte: start, $lte: end };
    }

    if (orderNumber && orderNumber.trim()) {
      query.orderNumber = new RegExp(orderNumber.trim(), 'i');
    }

    if (paymentStatus && paymentStatus !== 'All' && paymentStatus !== 'all') {
      query.paymentStatus = paymentStatus.toLowerCase();
    }

    if (orderStatus && orderStatus !== 'All' && orderStatus !== 'all') {
      query.orderStatus = orderStatus.toLowerCase();
    }

    if (printType && printType !== 'All' && printType !== 'all') {
      query.printType = printType.toLowerCase();
    }

    if (search && search.trim()) {
      const regex = new RegExp(search.trim(), 'i');
      query.$or = [
        { orderNumber: regex },
        { customerName: regex },
        { customerPhone: regex },
        { tableNumber: regex },
        { invoiceNumber: regex },
      ];
    }

    const parsedPage = Math.max(1, parseInt(page, 10) || 1);
    const parsedLimit = Math.max(1, parseInt(limit, 10) || 50);
    const skip = (parsedPage - 1) * parsedLimit;

    const [printLogs, total] = await Promise.all([
      PrintLog.find(query).sort({ createdAt: -1 }).skip(skip).limit(parsedLimit).lean(),
      PrintLog.countDocuments(query),
    ]);

    const formatted = printLogs.map((p) => ({
      id: p._id.toString(),
      orderId: p.orderId ? p.orderId.toString() : '',
      orderNumber: p.orderNumber,
      printNumber: p.printNumber || 1,
      printType: p.printType,
      orderStatus: p.orderStatus,
      paymentStatus: p.paymentStatus,
      paymentMethod: p.paymentMethod,
      subtotal: p.subtotal,
      discountAmount: p.discountAmount,
      taxAmount: p.taxAmount,
      cgst: p.cgst,
      sgst: p.sgst,
      igst: p.igst,
      tipAmount: p.tipAmount,
      deliveryCharge: p.deliveryCharge,
      roundOff: p.roundOff,
      totalAmount: p.totalAmount,
      orderType: p.orderType,
      tableNumber: p.tableNumber,
      deliveryAddress: p.deliveryAddress,
      customerName: p.customerName,
      customerPhone: p.customerPhone,
      items: p.items || [],
      qrPayload: p.qrPayload,
      qrImageUrl: p.qrImageUrl,
      invoiceNumber: p.invoiceNumber,
      isReprint: p.isReprint,
      printedBy: p.printedBy,
      notes: p.notes,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
    }));

    return {
      printLogs: formatted,
      pagination: {
        total,
        page: parsedPage,
        limit: parsedLimit,
        totalPages: Math.ceil(total / parsedLimit),
      },
    };
  }

  /**
   * Get single print log by ID
   */
  async getPrintLogById(businessId, id) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;
    const printLog = await PrintLog.findOne({ _id: id, businessId: bId }).lean();
    if (!printLog) {
      throw ApiError.notFound('Print log not found');
    }
    return {
      ...printLog,
      id: printLog._id.toString(),
    };
  }

  /**
   * Create a new immutable PrintLog snapshot
   */
  async createPrintLog(businessId, printLogData) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;
    return await PrintLog.create({
      ...printLogData,
      businessId: bId,
    });
  }

  /**
   * Log a reprint event for an existing print log snapshot
   */
  async reprintLog(businessId, id, { printedBy = '' } = {}) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;
    const originalLog = await PrintLog.findOne({ _id: id, businessId: bId }).lean();
    if (!originalLog) {
      throw ApiError.notFound('Print log snapshot not found for reprinting');
    }

    // Count reprints for this order
    const nextPrintNum = (await PrintLog.countDocuments({ businessId: bId, orderId: originalLog.orderId })) + 1;

    // Create a new reprint record referring to the original
    const reprintDoc = await PrintLog.create({
      businessId: bId,
      orderId: originalLog.orderId,
      orderNumber: originalLog.orderNumber,
      printNumber: nextPrintNum,
      printType: 'reprint',
      orderStatus: originalLog.orderStatus,
      paymentStatus: originalLog.paymentStatus,
      paymentMethod: originalLog.paymentMethod,
      subtotal: originalLog.subtotal,
      discountAmount: originalLog.discountAmount,
      taxAmount: originalLog.taxAmount,
      cgst: originalLog.cgst,
      sgst: originalLog.sgst,
      igst: originalLog.igst,
      tipAmount: originalLog.tipAmount,
      deliveryCharge: originalLog.deliveryCharge,
      roundOff: originalLog.roundOff,
      totalAmount: originalLog.totalAmount,
      orderType: originalLog.orderType,
      tableNumber: originalLog.tableNumber,
      deliveryAddress: originalLog.deliveryAddress,
      customerName: originalLog.customerName,
      customerPhone: originalLog.customerPhone,
      items: originalLog.items,
      qrPayload: originalLog.qrPayload,
      qrImageUrl: originalLog.qrImageUrl,
      invoiceNumber: originalLog.invoiceNumber,
      isReprint: true,
      originalPrintLogId: originalLog._id,
      printedBy: printedBy || originalLog.printedBy || '',
      notes: `Reprint of version #${originalLog.printNumber}`,
    });

    // Update order printCount
    await Order.findByIdAndUpdate(originalLog.orderId, { $inc: { printCount: 1 } });

    return reprintDoc;
  }
}

module.exports = new PrintLogService();
