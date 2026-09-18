const mongoose = require('mongoose');
const Sale = require('../models/Sale');
const Order = require('../models/Order');

class SalesService {
  /**
   * Helper to resolve flexible date filters
   */
  _resolveDateRange({ period, startDate, endDate, from, to, fromDate, toDate } = {}) {
    const now = new Date();
    const effectiveFrom = fromDate || from || startDate;
    const effectiveTo = toDate || to || endDate;

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
      return { start, end, resolvedPeriod: 'custom' };
    }

    const p = (period || 'allTime').toLowerCase().trim();

    let start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
    let end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
    let resolvedPeriod = p;

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
      resolvedPeriod = 'allTime';
    }

    return { start, end, resolvedPeriod };
  }

  _getCompletedOrderMatch(bId, start, end, extraMatch = {}) {
    const bIdObj = mongoose.Types.ObjectId.isValid(bId) ? new mongoose.Types.ObjectId(bId) : bId;
    return {
      businessId: { $in: [bIdObj, bId.toString()] },
      status: { $nin: ['cancelled', 'void'] },
      $or: [
        { status: { $in: ['completed', 'paid'] } },
        { paymentStatus: 'paid' },
        { isPaid: true },
      ],
      $and: [
        {
          $or: [
            { completedAt: { $gte: start, $lte: end } },
            { createdAt: { $gte: start, $lte: end } },
            { saleDate: { $gte: start, $lte: end } },
          ],
        },
      ],
      ...extraMatch,
    };
  }

  async getSales(businessId, { page = 1, limit = 50, paymentMethod, startDate, endDate, search } = {}) {
    const bId = new mongoose.Types.ObjectId(businessId);
    const { start, end } = this._resolveDateRange({ startDate, endDate });
    const query = this._getCompletedOrderMatch(bId, start, end);

    if (paymentMethod && paymentMethod !== 'All') {
      query.paymentMethod = new RegExp(paymentMethod, 'i');
    }

    if (search && search.trim()) {
      const regex = new RegExp(search.trim(), 'i');
      query.$or = [
        { orderNumber: regex },
        { customerName: regex },
        { customerPhone: regex },
        { tableNumber: regex },
      ];
    }

    const skip = (Math.max(1, parseInt(page, 10)) - 1) * Math.max(1, parseInt(limit, 10));
    const parsedLimit = Math.max(1, parseInt(limit, 10));

    const [orders, total] = await Promise.all([
      Order.find(query).sort({ createdAt: -1 }).skip(skip).limit(parsedLimit).lean(),
      Order.countDocuments(query),
    ]);

    const sales = orders.map((o) => ({
      id: o._id.toString(),
      orderNumber: o.orderNumber,
      orderType: o.orderType || 'dineIn',
      tableNumber: o.tableNumber || '',
      customerName: o.customerName || '',
      customerPhone: o.customerPhone || '',
      items: o.items || [],
      subtotal: o.subtotal || 0,
      discountAmount: o.discountAmount || 0,
      taxAmount: o.taxAmount || 0,
      totalAmount: o.totalAmount || 0,
      paymentMethod: o.paymentMethod || 'cash',
      saleDate: o.createdAt,
      createdAt: o.createdAt,
    }));

    return {
      sales,
      pagination: {
        total,
        page: parseInt(page, 10),
        limit: parsedLimit,
        totalPages: Math.ceil(total / parsedLimit),
      },
    };
  }

  async getSalesSummary(businessId, query = {}) {
    const report = await this.getSalesReport(businessId, query);
    return report.summary;
  }

  /**
   * Unified authoritative Sales Report API
   */
  async getSalesReport(businessId, query = {}) {
    const bId = new mongoose.Types.ObjectId(businessId);
    const { start, end, resolvedPeriod } = this._resolveDateRange(query);
    const matchStage = this._getCompletedOrderMatch(bId, start, end);

    // 1. Summary Aggregation
    const summaryAgg = await Order.aggregate([
      { $match: matchStage },
      {
        $group: {
          _id: null,
          totalRevenue: { $sum: '$totalAmount' },
          grossSales: { $sum: '$subtotal' },
          totalDiscount: { $sum: '$discountAmount' },
          totalTax: { $sum: '$taxAmount' },
          cgst: { $sum: '$cgst' },
          sgst: { $sum: '$sgst' },
          igst: { $sum: '$igst' },
          totalOrders: { $sum: 1 },
        },
      },
    ]);

    const rawSummary = summaryAgg[0] || {
      totalRevenue: 0,
      grossSales: 0,
      totalDiscount: 0,
      totalTax: 0,
      cgst: 0,
      sgst: 0,
      igst: 0,
      totalOrders: 0,
    };

    const totalOrders = rawSummary.totalOrders;
    const totalRevenue = Number(rawSummary.totalRevenue.toFixed(2));
    const grossSales = Number(rawSummary.grossSales.toFixed(2));
    const totalDiscount = Number((rawSummary.totalDiscount || 0).toFixed(2));
    const totalTax = Number((rawSummary.totalTax || 0).toFixed(2));
    const cgst = Number((rawSummary.cgst || 0).toFixed(2));
    const sgst = Number((rawSummary.sgst || 0).toFixed(2));
    const igst = Number((rawSummary.igst || 0).toFixed(2));
    const netSales = Number((grossSales - totalDiscount).toFixed(2));
    const avgOrderValue = totalOrders > 0 ? Number((totalRevenue / totalOrders).toFixed(2)) : 0.0;

    // 2. Total Items Count Aggregation
    const totalItemsAgg = await Order.aggregate([
      { $match: matchStage },
      { $unwind: '$items' },
      {
        $group: {
          _id: null,
          totalItems: { $sum: '$items.quantity' },
        },
      },
    ]);
    const totalItems = totalItemsAgg[0] ? totalItemsAgg[0].totalItems : 0;

    // 3. Dynamic Payment Modes Aggregation into Canonical Buckets
    const paymentAgg = await Order.aggregate([
      { $match: matchStage },
      {
        $group: {
          _id: { $toUpper: { $ifNull: ['$paymentMethod', 'CASH'] } },
          count: { $sum: 1 },
          amount: { $sum: '$totalAmount' },
        },
      },
      { $sort: { amount: -1 } },
    ]);

    const paymentMap = {
      'Cash': { count: 0, amount: 0 },
      'UPI / Digital QR': { count: 0, amount: 0 },
      'Card (Debit/Credit)': { count: 0, amount: 0 },
      'Wallet': { count: 0, amount: 0 },
      'Other': { count: 0, amount: 0 },
    };

    for (const item of paymentAgg) {
      const rawMode = (item._id || 'CASH').toString().toUpperCase().trim();
      let key = 'Other';

      if (rawMode.startsWith('UPI') || rawMode.includes('ONLINE') || rawMode.includes('GPAY') || rawMode.includes('PHONEPE') || rawMode.includes('PAYTM') || rawMode.includes('QR')) {
        key = 'UPI / Digital QR';
      } else if (rawMode.startsWith('CARD') || rawMode.includes('DEBIT') || rawMode.includes('CREDIT')) {
        key = 'Card (Debit/Credit)';
      } else if (rawMode.startsWith('CASH') || !rawMode) {
        key = 'Cash';
      } else if (rawMode.startsWith('WALLET')) {
        key = 'Wallet';
      } else {
        key = 'Other';
      }

      paymentMap[key].count += item.count;
      paymentMap[key].amount += item.amount;
    }

    const paymentModes = Object.entries(paymentMap).map(([modeName, val]) => {
      const amt = Number(val.amount.toFixed(2));
      const pct = totalRevenue > 0 ? Number(((amt / totalRevenue) * 100).toFixed(1)) : 0.0;
      return {
        mode: modeName,
        rawMode: modeName.toLowerCase(),
        count: val.count,
        amount: amt,
        percentage: pct,
      };
    });

    // 4. Order Types Breakdown
    const orderTypeAgg = await Order.aggregate([
      { $match: matchStage },
      {
        $group: {
          _id: '$orderType',
          count: { $sum: 1 },
          amount: { $sum: '$totalAmount' },
        },
      },
    ]);

    const salesByOrderType = orderTypeAgg.map((item) => {
      const typeLower = (item._id || '').toLowerCase();
      let label = 'Dine In';
      if (typeLower.includes('takeaway')) label = 'Takeaway';
      else if (typeLower.includes('delivery')) label = 'Delivery';

      return {
        type: label,
        rawType: item._id,
        count: item.count,
        amount: Number(item.amount.toFixed(2)),
      };
    });

    // 5. Top Selling Products
    const topProductsAgg = await Order.aggregate([
      { $match: matchStage },
      { $unwind: '$items' },
      {
        $group: {
          _id: '$items.name',
          totalQuantity: { $sum: '$items.quantity' },
          totalRevenue: { $sum: { $multiply: ['$items.price', '$items.quantity'] } },
          foodType: { $first: '$items.foodType' },
        },
      },
      { $sort: { totalQuantity: -1, totalRevenue: -1 } },
      { $limit: 20 },
      {
        $project: {
          name: '$_id',
          quantity: '$totalQuantity',
          revenue: { $round: ['$totalRevenue', 2] },
          foodType: { $ifNull: ['$foodType', 'veg'] },
          _id: 0,
        },
      },
    ]);

    // 6. Orders / Bills List for the date range
    const limit = Math.min(parseInt(query.limit, 10) || 500, 1000);
    const rawOrders = await Order.find(matchStage)
      .sort({ createdAt: -1 })
      .limit(limit)
      .lean();

    const orders = rawOrders.map((o) => {
      const itemsCount = (o.items || []).reduce((sum, item) => sum + (item.quantity || 1), 0);
      return {
        id: o._id.toString(),
        orderNumber: o.orderNumber,
        createdAt: o.createdAt ? o.createdAt.toISOString() : new Date().toISOString(),
        orderType: o.orderType || 'dineIn',
        tableNumber: o.tableNumber || '',
        paymentMethod: o.paymentMethod || 'Cash',
        paymentStatus: o.paymentStatus || 'paid',
        status: o.status || 'completed',
        totalItems: itemsCount,
        subtotal: Number((o.subtotal || 0).toFixed(2)),
        taxAmount: Number((o.taxAmount || 0).toFixed(2)),
        cgst: Number((o.cgst || 0).toFixed(2)),
        sgst: Number((o.sgst || 0).toFixed(2)),
        igst: Number((o.igst || 0).toFixed(2)),
        discountAmount: Number((o.discountAmount || 0).toFixed(2)),
        totalAmount: Number((o.totalAmount || 0).toFixed(2)),
        customerName: o.customerName || '',
        customerPhone: o.customerPhone || '',
        items: (o.items || []).map((i) => ({
          productId: i.productId ? i.productId.toString() : '',
          name: i.name || '',
          price: Number((i.price || 0).toFixed(2)),
          quantity: i.quantity || 1,
          foodType: i.foodType || 'veg',
        })),
      };
    });

    // 7. Multi-resolution Dynamic Sales Trend Aggregation
    const trendPoints = [];
    const pLower = (resolvedPeriod || 'allTime').toLowerCase().trim();
    const isSingleDay = pLower === 'today' ||
      pLower === 'yesterday' ||
      (start.getFullYear() === end.getFullYear() &&
       start.getMonth() === end.getMonth() &&
       start.getDate() === end.getDate());

    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    if (isSingleDay) {
      const slots = [
        { label: '8 AM', startHour: 0, endHour: 9 },
        { label: '10 AM', startHour: 10, endHour: 11 },
        { label: '12 PM', startHour: 12, endHour: 13 },
        { label: '2 PM', startHour: 14, endHour: 15 },
        { label: '4 PM', startHour: 16, endHour: 17 },
        { label: '6 PM', startHour: 18, endHour: 19 },
        { label: '8 PM', startHour: 20, endHour: 21 },
        { label: '10 PM', startHour: 22, endHour: 23 },
      ];

      for (const slot of slots) {
        let slotAmount = 0;
        let slotOrders = 0;

        for (const o of rawOrders) {
          const oDate = new Date(o.createdAt || o.saleDate);
          if (!isNaN(oDate.getTime())) {
            const h = oDate.getHours();
            if (h >= slot.startHour && h <= slot.endHour) {
              slotAmount += (o.totalAmount || 0);
              slotOrders += 1;
            }
          }
        }

        const slotDate = new Date(start.getFullYear(), start.getMonth(), start.getDate(), slot.startHour, 0, 0);
        trendPoints.push({
          date: slotDate.toISOString(),
          dateLabel: slot.label,
          salesAmount: Number(slotAmount.toFixed(2)),
          orderCount: slotOrders,
        });
      }
    } else {
      const daysDiff = Math.max(1, Math.round((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)));
      if (daysDiff <= 31) {
        for (let d = 0; d < daysDiff; d++) {
          const currentDay = new Date(start.getFullYear(), start.getMonth(), start.getDate() + d);
          const dayFmt = `${currentDay.getDate()} ${monthNames[currentDay.getMonth()]}`;

          let dayAmount = 0;
          let dayOrders = 0;

          for (const o of rawOrders) {
            const oDate = new Date(o.createdAt || o.saleDate);
            if (!isNaN(oDate.getTime())) {
              if (
                oDate.getFullYear() === currentDay.getFullYear() &&
                oDate.getMonth() === currentDay.getMonth() &&
                oDate.getDate() === currentDay.getDate()
              ) {
                dayAmount += (o.totalAmount || 0);
                dayOrders += 1;
              }
            }
          }

          trendPoints.push({
            date: currentDay.toISOString(),
            dateLabel: dayFmt,
            salesAmount: Number(dayAmount.toFixed(2)),
            orderCount: dayOrders,
          });
        }
      } else {
        const now = new Date();
        let cursor = new Date(start.getFullYear() > 2000 ? start.getFullYear() : now.getFullYear(), start.getFullYear() > 2000 ? start.getMonth() : (now.getMonth() - 5), 1);
        const endLimit = new Date(end.getFullYear(), end.getMonth(), 1);

        let safety = 0;
        while (cursor <= endLimit && safety < 36) {
          safety++;
          const monthFmt = `${monthNames[cursor.getMonth()]} ${cursor.getFullYear().toString().slice(-2)}`;
          let monthAmount = 0;
          let monthOrders = 0;

          for (const o of rawOrders) {
            const oDate = new Date(o.createdAt || o.saleDate);
            if (!isNaN(oDate.getTime())) {
              if (oDate.getFullYear() === cursor.getFullYear() && oDate.getMonth() === cursor.getMonth()) {
                monthAmount += (o.totalAmount || 0);
                monthOrders += 1;
              }
            }
          }

          trendPoints.push({
            date: cursor.toISOString(),
            dateLabel: monthFmt,
            salesAmount: Number(monthAmount.toFixed(2)),
            orderCount: monthOrders,
          });

          cursor = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 1);
        }

        if (trendPoints.length < 6) {
          trendPoints.length = 0;
          for (let m = 5; m >= 0; m--) {
            const d = new Date(now.getFullYear(), now.getMonth() - m, 1);
            const monthFmt = `${monthNames[d.getMonth()]} ${d.getFullYear().toString().slice(-2)}`;
            let monthAmount = 0;
            let monthOrders = 0;

            for (const o of rawOrders) {
              const oDate = new Date(o.createdAt || o.saleDate);
              if (!isNaN(oDate.getTime())) {
                if (oDate.getFullYear() === d.getFullYear() && oDate.getMonth() === d.getMonth()) {
                  monthAmount += (o.totalAmount || 0);
                  monthOrders += 1;
                }
              }
            }

            trendPoints.push({
              date: d.toISOString(),
              dateLabel: monthFmt,
              salesAmount: Number(monthAmount.toFixed(2)),
              orderCount: monthOrders,
            });
          }
        }
      }
    }

    return {
      summary: {
        totalRevenue,
        grossSales,
        netSales,
        totalOrders,
        totalItems,
        totalDiscount,
        totalTax,
        cgst,
        sgst,
        igst,
        avgOrderValue,
      },
      paymentModes,
      salesByOrderType,
      topProducts: topProductsAgg,
      salesTrend: trendPoints,
      orders,
      startDate: start.toISOString(),
      endDate: end.toISOString(),
      period: resolvedPeriod,
    };
  }

  async getTopSellingProducts(businessId, query = {}) {
    const report = await this.getSalesReport(businessId, query);
    return report.topProducts;
  }
}

module.exports = new SalesService();
