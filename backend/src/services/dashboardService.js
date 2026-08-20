const mongoose = require('mongoose');
const Order = require('../models/Order');
const Customer = require('../models/Customer');
const Product = require('../models/Product');
const Table = require('../models/Table');

class DashboardService {
  /**
   * Helper to resolve flexible date filters (period / from-to / startDate-endDate)
   */
  _resolveDateRange({ period, startDate, endDate, from, to } = {}) {
    const now = new Date();
    const effectiveFrom = from || startDate;
    const effectiveTo = to || endDate;

    if (effectiveFrom && effectiveTo) {
      let start = new Date(effectiveFrom);
      if (isNaN(start.getTime())) {
        start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
      } else {
        start.setHours(0, 0, 0, 0);
      }

      let end = new Date(effectiveTo);
      if (isNaN(end.getTime())) {
        end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
      } else {
        end.setHours(23, 59, 59, 999);
      }
      return { start, end };
    }

    const p = (period || 'Today').toLowerCase().trim();

    let start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
    let end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);

    if (p === 'yesterday') {
      start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 0, 0, 0, 0);
      end = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 23, 59, 59, 999);
    } else if (p === 'week' || p === 'this week') {
      const day = now.getDay();
      const diffToMonday = (day === 0 ? -6 : 1) - day;
      start = new Date(now.getFullYear(), now.getMonth(), now.getDate() + diffToMonday, 0, 0, 0, 0);
      if (start > now) {
        start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        start.setHours(0, 0, 0, 0);
      }
      end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
    } else if (p === 'month' || p === 'this month') {
      start = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
      end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
    } else if (p === 'year' || p === 'this year') {
      start = new Date(now.getFullYear(), 0, 1, 0, 0, 0, 0);
      end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
    } else if (p === 'all time' || p === 'all') {
      start = new Date(0);
      end = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
    }

    return { start, end };
  }

  _getCompletedOrderMatch(bId, start, end, extraMatch = {}) {
    return {
      businessId: bId,
      createdAt: { $gte: start, $lte: end },
      status: { $ne: 'cancelled' },
      $or: [
        { status: { $in: ['completed', 'paid'] } },
        { paymentStatus: 'paid' },
      ],
      ...extraMatch,
    };
  }

  // 1. Order Summary (Total Orders & Total Revenue for completed/paid orders)
  async getSummary(businessId, query = {}) {
    const bId = new mongoose.Types.ObjectId(businessId);
    const { start, end } = this._resolveDateRange(query);

    const matchStage = this._getCompletedOrderMatch(bId, start, end);

    const result = await Order.aggregate([
      { $match: matchStage },
      {
        $group: {
          _id: null,
          totalOrders: { $sum: 1 },
          totalRevenue: { $sum: '$totalAmount' },
        },
      },
    ]);

    const activeOrdersCount = await Order.countDocuments({
      businessId: bId,
      status: { $in: ['pending', 'preparing', 'ready'] },
    });

    const totalProductsCount = await Product.countDocuments({ businessId: bId });

    const summary = result[0] || { totalOrders: 0, totalRevenue: 0 };

    return {
      totalOrders: summary.totalOrders,
      totalRevenue: Number(summary.totalRevenue.toFixed(2)),
      activeOrdersCount,
      totalProductsCount,
      startDate: start.toISOString(),
      endDate: end.toISOString(),
    };
  }

  // 2. Order Type Breakdown (Dine-In, Delivery, Takeaway, and Total)
  async getOrderTypes(businessId, query = {}) {
    const bId = new mongoose.Types.ObjectId(businessId);
    const { start, end } = this._resolveDateRange(query);

    const matchStage = this._getCompletedOrderMatch(bId, start, end);

    const result = await Order.aggregate([
      { $match: matchStage },
      {
        $group: {
          _id: '$orderType',
          count: { $sum: 1 },
          amount: { $sum: '$totalAmount' },
        },
      },
    ]);

    const stats = {
      dineIn: { count: 0, amount: 0 },
      delivery: { count: 0, amount: 0 },
      takeaway: { count: 0, amount: 0 },
      total: { count: 0, amount: 0 },
    };

    result.forEach((item) => {
      const typeLower = (item._id || '').toLowerCase().replace(/[-_]/g, '');
      let key = null;
      if (typeLower === 'dinein') key = 'dineIn';
      else if (typeLower === 'delivery') key = 'delivery';
      else if (typeLower === 'takeaway') key = 'takeaway';

      if (key) {
        stats[key].count = item.count;
        stats[key].amount = Number(item.amount.toFixed(2));
      }
      stats.total.count += item.count;
      stats.total.amount += item.amount;
    });

    stats.total.amount = Number(stats.total.amount.toFixed(2));

    return stats;
  }

  // 3. Item / Product Sales Report (Historical Transaction snapshot from Order.items)
  async getProductSales(businessId, query = {}) {
    const bId = new mongoose.Types.ObjectId(businessId);
    const { start, end } = this._resolveDateRange(query);

    const extra = {};
    if (query.orderType && query.orderType !== 'All' && query.orderType !== 'ALL') {
      extra.orderType = query.orderType.toLowerCase();
    }

    const matchStage = this._getCompletedOrderMatch(bId, start, end, extra);

    const items = await Order.aggregate([
      { $match: matchStage },
      { $unwind: '$items' },
      {
        $group: {
          _id: {
            productId: '$items.productId',
            name: '$items.name',
            price: '$items.price',
          },
          quantity: { $sum: '$items.quantity' },
          totalAmount: { $sum: { $multiply: ['$items.price', '$items.quantity'] } },
        },
      },
      { $sort: { quantity: -1, totalAmount: -1 } },
    ]);

    const formatted = items.map((item, index) => ({
      srNo: index + 1,
      productId: item._id.productId ? item._id.productId.toString() : '',
      productName: item._id.name || 'Unnamed Item',
      price: Number(item._id.price.toFixed(2)),
      quantity: item.quantity,
      totalAmount: Number(item.totalAmount.toFixed(2)),
    }));

    return { items: formatted };
  }

  // 4. Customer Analytics (New vs Returning based on Lifetime History)
  async getCustomers(businessId, query = {}) {
    const bId = new mongoose.Types.ObjectId(businessId);
    const { start, end } = this._resolveDateRange(query);

    // Get all orders in this date range that have customer details
    const ordersInRange = await Order.find({
      businessId: bId,
      createdAt: { $gte: start, $lte: end },
      status: { $ne: 'cancelled' },
      $or: [
        { customerPhone: { $exists: true, $ne: '' } },
        { customerName: { $exists: true, $ne: '' } },
      ],
    })
      .select('customerName customerPhone createdAt')
      .lean();

    // Map unique customers by phone or name
    const customerMap = new Map();
    for (const ord of ordersInRange) {
      const phone = (ord.customerPhone || '').trim();
      const name = (ord.customerName || '').trim();
      const key = phone || name;
      if (!key) continue;

      if (!customerMap.has(key)) {
        customerMap.set(key, { name: name || 'Customer', phone });
      }
    }

    // Also include any customers in Customer model touched in [start, end]
    const directCustomers = await Customer.find({
      businessId: bId,
      $or: [
        { firstVisit: { $gte: start, $lte: end } },
        { createdAt: { $gte: start, $lte: end } },
        { lastVisit: { $gte: start, $lte: end } },
      ],
    })
      .select('name phone totalOrders firstVisit createdAt')
      .lean();

    for (const c of directCustomers) {
      const phone = (c.phone || '').trim();
      const name = (c.name || '').trim();
      const key = phone || name;
      if (key && !customerMap.has(key)) {
        customerMap.set(key, { name: name || 'Customer', phone });
      }
    }

    const newCustomers = [];
    const returningCustomers = [];

    // For each customer, check all-time history
    for (const [key, info] of customerMap.entries()) {
      const phone = info.phone;
      const name = info.name;

      const queryConds = [];
      if (phone) queryConds.push({ customerPhone: phone });
      if (name && name !== 'Customer') queryConds.push({ customerName: name });

      let earliestDate = null;
      let totalVisits = 1;

      // Check Customer CRM record first
      if (phone) {
        const customerDoc = await Customer.findOne({
          businessId: bId,
          phone,
        }).select('firstVisit createdAt totalOrders').lean();

        if (customerDoc) {
          if (customerDoc.firstVisit) earliestDate = customerDoc.firstVisit;
          else if (customerDoc.createdAt) earliestDate = customerDoc.createdAt;
          if (customerDoc.totalOrders) totalVisits = customerDoc.totalOrders;
        }
      }

      // If no Customer CRM firstVisit, check earliest Order in Order collection
      if (!earliestDate && queryConds.length > 0) {
        const earliestOrder = await Order.findOne({
          businessId: bId,
          $or: queryConds,
        })
          .sort({ createdAt: 1 })
          .select('createdAt')
          .lean();

        if (earliestOrder) {
          earliestDate = earliestOrder.createdAt;
        }
      }

      if (queryConds.length > 0) {
        const orderCount = await Order.countDocuments({
          businessId: bId,
          $or: queryConds,
          status: { $ne: 'cancelled' },
        });
        totalVisits = Math.max(totalVisits, orderCount);
      }

      const effectiveEarliest = earliestDate || start;
      const isNew = effectiveEarliest >= start && effectiveEarliest <= end;

      const customerObj = {
        name: name || 'Customer',
        phone: phone || '',
        visitCount: Math.max(1, totalVisits),
      };

      if (isNew) {
        newCustomers.push(customerObj);
      } else {
        returningCustomers.push(customerObj);
      }
    }

    return {
      newCustomers,
      returningCustomers,
    };
  }

  // 5. Payment Methods Sales Breakdown
  async getPaymentMethods(businessId, query = {}) {
    const bId = new mongoose.Types.ObjectId(businessId);
    const { start, end } = this._resolveDateRange(query);

    const matchStage = this._getCompletedOrderMatch(bId, start, end);

    const result = await Order.aggregate([
      { $match: matchStage },
      {
        $group: {
          _id: { $toUpper: '$paymentMethod' },
          count: { $sum: 1 },
          amount: { $sum: '$totalAmount' },
        },
      },
      { $sort: { amount: -1 } },
    ]);

    let totalAmount = 0;
    const payments = result.map((item) => {
      let methodStr = item._id || 'OTHER';
      if (methodStr.startsWith('CASH')) methodStr = 'CASH';
      else if (methodStr.startsWith('CARD')) methodStr = 'CARD';
      else if (methodStr.startsWith('UPI')) methodStr = 'UPI';
      else if (methodStr.startsWith('SPLIT')) methodStr = 'SPLIT';

      const amt = Number(item.amount.toFixed(2));
      totalAmount += amt;
      return {
        method: methodStr,
        count: item.count,
        amount: amt,
      };
    });

    return {
      payments,
      totalAmount: Number(totalAmount.toFixed(2)),
    };
  }

  // 6. Tax / GST Reporting from historical transaction data
  async getTaxes(businessId, query = {}) {
    const bId = new mongoose.Types.ObjectId(businessId);
    const { start, end } = this._resolveDateRange(query);

    const matchStage = this._getCompletedOrderMatch(bId, start, end);

    const result = await Order.aggregate([
      { $match: matchStage },
      {
        $group: {
          _id: null,
          cgst: { $sum: '$cgst' },
          sgst: { $sum: '$sgst' },
          igst: { $sum: '$igst' },
          totalGST: { $sum: '$taxAmount' },
        },
      },
    ]);

    const taxData = result[0] || { cgst: 0, sgst: 0, igst: 0, totalGST: 0 };

    return {
      cgst: Number((taxData.cgst || 0).toFixed(2)),
      sgst: Number((taxData.sgst || 0).toFixed(2)),
      igst: Number((taxData.igst || 0).toFixed(2)),
      totalGST: Number((taxData.totalGST || 0).toFixed(2)),
    };
  }

  // 7. Order Status Statistics (Successful vs Cancelled vs Total)
  async getOrderStats(businessId, query = {}) {
    const bId = new mongoose.Types.ObjectId(businessId);
    const { start, end } = this._resolveDateRange(query);

    const result = await Order.aggregate([
      {
        $match: {
          businessId: bId,
          createdAt: { $gte: start, $lte: end },
        },
      },
      {
        $group: {
          _id: '$status',
          count: { $sum: 1 },
        },
      },
    ]);

    let successfulOrders = 0;
    let cancelledOrders = 0;
    let otherOrders = 0;

    result.forEach((item) => {
      if (item._id === 'completed' || item._id === 'paid') successfulOrders += item.count;
      else if (item._id === 'cancelled') cancelledOrders += item.count;
      else otherOrders += item.count;
    });

    return {
      successfulOrders,
      cancelledOrders,
      otherOrders,
      totalOrders: successfulOrders + cancelledOrders + otherOrders,
    };
  }

  // 8. Time Series Chart Data Points
  async getChartData(businessId, { filter = 'Week' } = {}) {
    const bId = new mongoose.Types.ObjectId(businessId);
    const now = new Date();
    let startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    let dateFormat = '%Y-%m-%d';

    if (filter === 'Today') {
      startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
      dateFormat = '%H:00';
    } else if (filter === 'Month') {
      startDate = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0);
      dateFormat = '%d %b';
    } else if (filter === 'Year') {
      startDate = new Date(now.getFullYear(), 0, 1, 0, 0, 0);
      dateFormat = '%b';
    }

    const matchStage = this._getCompletedOrderMatch(bId, startDate, now);

    const chartPoints = await Order.aggregate([
      { $match: matchStage },
      {
        $group: {
          _id: { $dateToString: { format: dateFormat, date: '$createdAt', timezone: 'Asia/Kolkata' } },
          revenue: { $sum: '$totalAmount' },
          orders: { $sum: 1 },
        },
      },
      { $sort: { _id: 1 } },
      {
        $project: {
          label: '$_id',
          revenue: 1,
          orders: 1,
          _id: 0,
        },
      },
    ]);

    return chartPoints;
  }
}

module.exports = new DashboardService();
