const mongoose = require('mongoose');
const Sale = require('../models/Sale');
const Order = require('../models/Order');
const Table = require('../models/Table');
const Product = require('../models/Product');

class DashboardService {
  async getSummary(businessId, { period = 'Today', startDate, endDate } = {}) {
    const bId = new mongoose.Types.ObjectId(businessId);
    const now = new Date();

    let start = new Date(now.getFullYear(), now.month || now.getMonth(), now.getDate(), 0, 0, 0);
    let end = new Date(now.getFullYear(), now.month || now.getMonth(), now.getDate(), 23, 59, 59, 999);

    if (period === 'Yesterday') {
      start = new Date(start.getTime() - 24 * 60 * 60 * 1000);
      end = new Date(start.getTime() + 24 * 60 * 60 * 1000 - 1);
    } else if (period === 'Week') {
      start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      end = now;
    } else if (period === 'Month') {
      start = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0);
      end = now;
    } else if (period === 'Year') {
      start = new Date(now.getFullYear(), 0, 1, 0, 0, 0);
      end = now;
    } else if (period === 'Custom Date' && startDate && endDate) {
      start = new Date(startDate);
      end = new Date(endDate);
    } else if (period === 'All Time') {
      start = new Date(0);
      end = now;
    }

    const match = { businessId: bId, saleDate: { $gte: start, $lte: end } };

    const [salesStats, activeOrdersCount, tablesStats, totalProductsCount, topProducts] =
      await Promise.all([
        Sale.aggregate([
          { $match: match },
          {
            $group: {
              _id: null,
              totalRevenue: { $sum: '$totalAmount' },
              totalOrders: { $sum: 1 },
              dineInSales: {
                $sum: { $cond: [{ $eq: ['$orderType', 'dineIn'] }, '$totalAmount', 0] },
              },
              takeawaySales: {
                $sum: { $cond: [{ $eq: ['$orderType', 'takeaway'] }, '$totalAmount', 0] },
              },
              deliverySales: {
                $sum: { $cond: [{ $eq: ['$orderType', 'delivery'] }, '$totalAmount', 0] },
              },
              dineInOrders: {
                $sum: { $cond: [{ $eq: ['$orderType', 'dineIn'] }, 1, 0] },
              },
              takeawayOrders: {
                $sum: { $cond: [{ $eq: ['$orderType', 'takeaway'] }, 1, 0] },
              },
              deliveryOrders: {
                $sum: { $cond: [{ $eq: ['$orderType', 'delivery'] }, 1, 0] },
              },
            },
          },
        ]),
        Order.countDocuments({
          businessId: bId,
          status: { $in: ['pending', 'preparing', 'ready'] },
        }),
        Table.aggregate([
          { $match: { businessId: bId } },
          {
            $group: {
              _id: null,
              totalTables: { $sum: 1 },
              occupiedTables: {
                $sum: { $cond: [{ $eq: ['$status', 'occupied'] }, 1, 0] },
              },
              billedTables: {
                $sum: { $cond: [{ $eq: ['$status', 'billed'] }, 1, 0] },
              },
              freeTables: {
                $sum: { $cond: [{ $eq: ['$status', 'free'] }, 1, 0] },
              },
            },
          },
        ]),
        Product.countDocuments({ businessId: bId }),
        Sale.aggregate([
          { $match: match },
          { $unwind: '$items' },
          {
            $group: {
              _id: '$items.name',
              quantity: { $sum: '$items.quantity' },
              revenue: { $sum: { $multiply: ['$items.price', '$items.quantity'] } },
              foodType: { $first: '$items.foodType' },
            },
          },
          { $sort: { quantity: -1 } },
          { $limit: 5 },
          {
            $project: {
              name: '$_id',
              quantity: 1,
              revenue: 1,
              foodType: 1,
              _id: 0,
            },
          },
        ]),
      ]);

    const sales = salesStats[0] || {
      totalRevenue: 0,
      totalOrders: 0,
      dineInSales: 0,
      takeawaySales: 0,
      deliverySales: 0,
      dineInOrders: 0,
      takeawayOrders: 0,
      deliveryOrders: 0,
    };

    const tables = tablesStats[0] || {
      totalTables: 0,
      occupiedTables: 0,
      billedTables: 0,
      freeTables: 0,
    };

    return {
      period,
      revenue: sales.totalRevenue,
      totalOrders: sales.totalOrders,
      activeOrdersCount,
      totalProductsCount,
      orderTypes: {
        dineIn: { count: sales.dineInOrders, amount: sales.dineInSales },
        takeaway: { count: sales.takeawayOrders, amount: sales.takeawaySales },
        delivery: { count: sales.deliveryOrders, amount: sales.deliverySales },
      },
      tables,
      topProducts,
    };
  }

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

    const chartPoints = await Sale.aggregate([
      {
        $match: {
          businessId: bId,
          saleDate: { $gte: startDate, $lte: now },
        },
      },
      {
        $group: {
          _id: { $dateToString: { format: dateFormat, date: '$saleDate', timezone: 'Asia/Kolkata' } },
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
