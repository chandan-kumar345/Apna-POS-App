const mongoose = require('mongoose');
const Sale = require('../models/Sale');

class SalesService {
  async getSales(businessId, { page = 1, limit = 50, paymentMethod, startDate, endDate, search } = {}) {
    const query = { businessId: new mongoose.Types.ObjectId(businessId) };

    if (paymentMethod && paymentMethod !== 'All') {
      query.paymentMethod = paymentMethod.toLowerCase();
    }

    if (startDate || endDate) {
      query.saleDate = {};
      if (startDate) query.saleDate.$gte = new Date(startDate);
      if (endDate) query.saleDate.$lte = new Date(endDate);
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

    const [sales, total] = await Promise.all([
      Sale.find(query).sort({ saleDate: -1 }).skip(skip).limit(parsedLimit),
      Sale.countDocuments(query),
    ]);

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

  async getSalesSummary(businessId, { startDate, endDate } = {}) {
    const match = { businessId: new mongoose.Types.ObjectId(businessId) };

    if (startDate || endDate) {
      match.saleDate = {};
      if (startDate) match.saleDate.$gte = new Date(startDate);
      if (endDate) match.saleDate.$lte = new Date(endDate);
    }

    const [summary] = await Sale.aggregate([
      { $match: match },
      {
        $group: {
          _id: null,
          totalRevenue: { $sum: '$totalAmount' },
          totalSubtotal: { $sum: '$subtotal' },
          totalTax: { $sum: '$taxAmount' },
          totalDiscount: { $sum: '$discountAmount' },
          totalOrders: { $sum: 1 },
          cashSales: {
            $sum: { $cond: [{ $eq: ['$paymentMethod', 'cash'] }, '$totalAmount', 0] },
          },
          upiSales: {
            $sum: { $cond: [{ $eq: ['$paymentMethod', 'upi'] }, '$totalAmount', 0] },
          },
          cardSales: {
            $sum: { $cond: [{ $eq: ['$paymentMethod', 'card'] }, '$totalAmount', 0] },
          },
        },
      },
    ]);

    return (
      summary || {
        totalRevenue: 0,
        totalSubtotal: 0,
        totalTax: 0,
        totalDiscount: 0,
        totalOrders: 0,
        cashSales: 0,
        upiSales: 0,
        cardSales: 0,
      }
    );
  }

  async getTopSellingProducts(businessId, { limit = 10, startDate, endDate } = {}) {
    const match = { businessId: new mongoose.Types.ObjectId(businessId) };

    if (startDate || endDate) {
      match.saleDate = {};
      if (startDate) match.saleDate.$gte = new Date(startDate);
      if (endDate) match.saleDate.$lte = new Date(endDate);
    }

    const topProducts = await Sale.aggregate([
      { $match: match },
      { $unwind: '$items' },
      {
        $group: {
          _id: '$items.name',
          totalQuantity: { $sum: '$items.quantity' },
          totalRevenue: { $sum: { $multiply: ['$items.price', '$items.quantity'] } },
          foodType: { $first: '$items.foodType' },
        },
      },
      { $sort: { totalQuantity: -1 } },
      { $limit: parseInt(limit, 10) || 10 },
      {
        $project: {
          name: '$_id',
          totalQuantity: 1,
          totalRevenue: 1,
          foodType: 1,
          _id: 0,
        },
      },
    ]);

    return topProducts;
  }
}

module.exports = new SalesService();
