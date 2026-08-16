const Order = require('../models/Order');
const Sale = require('../models/Sale');
const Table = require('../models/Table');
const Customer = require('../models/Customer');
const ApiError = require('../utils/ApiError');

class OrderService {
  _generateOrderNumber() {
    const random = Math.floor(1000 + Math.random() * 9000);
    const dateStr = new Date().toISOString().slice(2, 10).replace(/-/g, '');
    return `ORD-${dateStr}-${random}`;
  }

  async createOrder(businessId, orderData) {
    const orderNumber = orderData.orderNumber || this._generateOrderNumber();

    const order = await Order.create({
      ...orderData,
      businessId,
      orderNumber,
    });

    // If DineIn and table number provided, mark table as occupied
    if (order.orderType === 'dineIn' && order.tableNumber) {
      await Table.findOneAndUpdate(
        { businessId, name: order.tableNumber },
        {
          $set: {
            status: 'occupied',
            currentOrderId: order._id,
            occupiedSince: new Date(),
          },
        }
      );
    }

    // Update customer CRM if customer phone provided
    if (order.customerPhone && order.customerPhone.trim()) {
      await Customer.findOneAndUpdate(
        { businessId, phone: order.customerPhone.trim() },
        {
          $set: {
            name: order.customerName || 'Walk-in Guest',
            lastVisit: new Date(),
          },
          $inc: { totalOrders: 1 },
          $setOnInsert: { businessId, phone: order.customerPhone.trim() },
        },
        { upsert: true }
      );
    }

    return order;
  }

  async getOrders(businessId, { page = 1, limit = 50, status, orderType, search, startDate, endDate } = {}) {
    const query = { businessId };

    if (status && status !== 'All') {
      query.status = status.toLowerCase();
    }

    if (orderType && orderType !== 'All') {
      query.orderType = orderType.toLowerCase();
    }

    if (startDate || endDate) {
      query.createdAt = {};
      if (startDate) query.createdAt.$gte = new Date(startDate);
      if (endDate) query.createdAt.$lte = new Date(endDate);
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
      Order.find(query).sort({ createdAt: -1 }).skip(skip).limit(parsedLimit),
      Order.countDocuments(query),
    ]);

    return {
      orders,
      pagination: {
        total,
        page: parseInt(page, 10),
        limit: parsedLimit,
        totalPages: Math.ceil(total / parsedLimit),
      },
    };
  }

  async getOrderById(businessId, orderId) {
    const order = await Order.findOne({ _id: orderId, businessId });
    if (!order) {
      throw ApiError.notFound('Order not found or does not belong to this business');
    }
    return order;
  }

  async updateOrderStatus(businessId, orderId, status) {
    const order = await Order.findOne({ _id: orderId, businessId });
    if (!order) {
      throw ApiError.notFound('Order not found');
    }

    order.status = status;
    if (status === 'completed') {
      order.completedAt = new Date();
      // Free linked table
      if (order.tableNumber) {
        await Table.findOneAndUpdate(
          { businessId, name: order.tableNumber },
          { $set: { status: 'free', currentOrderId: null, occupiedSince: null } }
        );
      }
    } else if (status === 'cancelled') {
      // Free linked table
      if (order.tableNumber) {
        await Table.findOneAndUpdate(
          { businessId, name: order.tableNumber },
          { $set: { status: 'free', currentOrderId: null, occupiedSince: null } }
        );
      }
    }

    await order.save();
    return order;
  }

  async payOrder(businessId, orderId, { paymentMethod, amountPaid }) {
    const order = await Order.findOne({ _id: orderId, businessId });
    if (!order) {
      throw ApiError.notFound('Order not found');
    }

    order.paymentMethod = paymentMethod;
    order.paymentStatus = 'paid';
    order.status = 'completed';
    order.completedAt = new Date();
    await order.save();

    // Create Sale record
    const sale = await Sale.create({
      businessId,
      orderId: order._id,
      orderNumber: order.orderNumber,
      orderType: order.orderType,
      tableNumber: order.tableNumber || '',
      customerName: order.customerName || '',
      customerPhone: order.customerPhone || '',
      items: order.items.map((i) => ({
        name: i.name,
        price: i.price,
        quantity: i.quantity,
        foodType: i.foodType,
      })),
      subtotal: order.subtotal,
      discountAmount: order.discountAmount,
      taxAmount: order.taxAmount,
      tipAmount: order.tipAmount,
      totalAmount: order.totalAmount,
      paymentMethod,
      saleDate: new Date(),
    });

    // Free table if dineIn
    if (order.tableNumber) {
      await Table.findOneAndUpdate(
        { businessId, name: order.tableNumber },
        { $set: { status: 'free', currentOrderId: null, occupiedSince: null } }
      );
    }

    // Update customer lifetime spend
    if (order.customerPhone && order.customerPhone.trim()) {
      await Customer.findOneAndUpdate(
        { businessId, phone: order.customerPhone.trim() },
        {
          $inc: { totalSpent: order.totalAmount },
          $set: { lastVisit: new Date() },
        }
      );
    }

    return { order, sale };
  }

  async getActiveTableOrder(businessId, tableNumber) {
    const order = await Order.findOne({
      businessId,
      tableNumber,
      status: { $in: ['pending', 'preparing', 'ready'] },
    }).sort({ createdAt: -1 });

    return order;
  }
}

module.exports = new OrderService();
