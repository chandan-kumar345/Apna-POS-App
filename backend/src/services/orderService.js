const Order = require('../models/Order');
const Sale = require('../models/Sale');
const Table = require('../models/Table');
const Customer = require('../models/Customer');
const Cart = require('../models/Cart');
const Product = require('../models/Product');
const ApiError = require('../utils/ApiError');

class OrderService {
  _generateOrderNumber() {
    const random = Math.floor(1000 + Math.random() * 9000);
    const dateStr = new Date().toISOString().slice(2, 10).replace(/-/g, '');
    return `ORD-${dateStr}-${random}`;
  }

  async generatePosOrder(businessId, rawData) {
    // 1. Check Idempotency Key
    const idempotencyKey = (
      rawData.idempotencyKey ||
      rawData.syncId ||
      rawData.clientSyncId ||
      rawData.localOrderId ||
      ''
    ).toString().trim();

    if (idempotencyKey) {
      const existingOrder = await Order.findOne({
        businessId,
        $or: [
          { idempotencyKey },
          { clientSyncId: idempotencyKey },
          { localOrderId: idempotencyKey },
        ],
      });

      if (existingOrder) {
        const existingSale = await Sale.findOne({ businessId, orderId: existingOrder._id });
        return {
          order: existingOrder,
          sale: existingSale || null,
          invoice: {
            invoiceNumber: existingOrder.invoiceNumber || `INV-${existingOrder.orderNumber}`,
            invoiceDate: existingOrder.completedAt || existingOrder.createdAt,
            totalAmount: existingOrder.totalAmount,
          },
          isExisting: true,
          message: 'Order already processed (idempotent)',
        };
      }
    }

    // 2. Map Payload Keys & Defaults
    const venderUserId = (rawData.VenderUserId || rawData.venderUserId || rawData.vendorUserId || '').toString().trim();
    const venderCardId = (rawData.VenderCardId || rawData.venderCardId || '').toString().trim();
    const createdByUserId = (rawData.CreatedByUserId || rawData.createdByUserId || '').toString().trim();
    const createdByCardId = (rawData.CreatedByCardId || rawData.createdByCardId || '').toString().trim();
    const cartId = (rawData.cartId || '').toString().trim();
    const isKOT = Boolean(rawData.isKOT);
    const paymentDetails = Array.isArray(rawData.paymentDetails) ? rawData.paymentDetails : [];
    const ncReason = (rawData.ncReason || '').toString().trim();
    const paymentMode = (rawData.paymentMode || rawData.paymentMethod || '').toString().trim();
    const orderDevice = (rawData.orderDevice || 'web').toString().trim();
    const rawMethod = (rawData.paymentMethod || paymentMode || '').toLowerCase();
    const isKotOrder = isKOT ||
      rawMethod.includes('kot') ||
      rawMethod.includes('pending') ||
      rawMethod === 'unpaid' ||
      rawData.status === 'pending' ||
      rawData.status === 'preparing';
    const isPaid = !isKotOrder && (
      rawData.isPaid === true ||
      (rawData.paymentStatus === 'paid' && rawData.status === 'completed') ||
      rawData.status === 'completed'
    );
    const isDineIn = rawData.isDineIn !== undefined ? Boolean(rawData.isDineIn) : (rawData.orderType === 'dineIn' || Boolean(rawData.T || rawData.tableNumber));
    const restaurantCode = (rawData.R || '').toString().trim();
    const tableCode = (rawData.T || rawData.tableNumber || '').toString().trim();
    const reason = (rawData.reason || '').toString().trim();
    const remarks = (rawData.remarks || rawData.notes || '').toString().trim();
    const clientSyncId = (rawData.clientSyncId || rawData.syncId || rawData.localOrderId || rawData._id || rawData.orderId || '').toString().trim();
    const syncId = (rawData.syncId || '').toString().trim();
    const localOrderId = (rawData.localOrderId || rawData._id || rawData.orderId || '').toString().trim();
    const tokenNo = (rawData.TokenNo || rawData.tokenNo || '').toString().trim();
    const orderNumber = (rawData.orderNumber || rawData.orderNo || rawData.orderNO || rawData.orderId || '').toString().trim() || this._generateOrderNumber();

    // 3. Resolve Items & Cart
    let items = Array.isArray(rawData.items) && rawData.items.length > 0 ? rawData.items : [];
    let cartSubtotal = 0;
    let cartDiscount = 0;

    if (items.length === 0 && cartId) {
      const isObjectId = /^[0-9a-fA-F]{24}$/.test(cartId);
      const cart = await Cart.findOne({
        businessId,
        ...(isObjectId ? { _id: cartId } : { tableNumber: cartId }),
      });

      if (cart && Array.isArray(cart.items) && cart.items.length > 0) {
        items = cart.items.map((i) => ({
          productId: i.productId,
          name: i.name,
          price: i.effectivePrice != null ? i.effectivePrice : i.price,
          quantity: i.quantity,
          foodType: (i.foodType || 'veg').toString().toLowerCase().replace('-', '_'),
          note: '',
        }));
        cartSubtotal = cart.subtotal || 0;
        cartDiscount = cart.totalDiscount || 0;
      }
    }

    if (items.length === 0 && !ncReason) {
      throw ApiError.badRequest('Order items or a valid cartId containing items is required');
    }

    // 4. Calculate Financials
    const computedSubtotal = items.reduce((sum, i) => sum + (Number(i.price) || 0) * (Number(i.quantity) || 1), 0);
    const subtotal = rawData.subtotal !== undefined ? Number(rawData.subtotal) : (computedSubtotal || cartSubtotal);
    const discountAmount = rawData.discountAmount !== undefined ? Number(rawData.discountAmount) : cartDiscount;
    const taxAmount = Number(rawData.taxAmount) || 0;
    const cgst = rawData.cgst !== undefined ? Number(rawData.cgst) : Number((taxAmount / 2).toFixed(2));
    const sgst = rawData.sgst !== undefined ? Number(rawData.sgst) : Number((taxAmount / 2).toFixed(2));
    const igst = rawData.igst !== undefined ? Number(rawData.igst) : 0;
    const tipAmount = Number(rawData.tipAmount) || 0;
    const totalAmount = rawData.totalAmount !== undefined
      ? Number(rawData.totalAmount)
      : Math.max(0, Number(((subtotal - discountAmount) + taxAmount + tipAmount).toFixed(2)));

    // 5. Validate Payment Details & Amounts
    if (paymentDetails.length > 0) {
      const totalPaidAmount = paymentDetails.reduce((sum, p) => sum + (Number(p.amount) || 0), 0);
      if (isPaid && !ncReason && totalPaidAmount < totalAmount - 0.01) {
        throw ApiError.badRequest(
          `Payment amount (${totalPaidAmount}) does not match or cover total order amount (${totalAmount})`
        );
      }
    }

    // Determine normalized paymentMethod and status
    let paymentMethod = (rawData.paymentMethod || paymentMode || (isKotOrder ? 'kot pending' : 'cash')).toLowerCase();
    if (isPaid) {
      if (paymentDetails.length > 1) {
        paymentMethod = 'split';
      } else if (paymentDetails.length === 1 && paymentDetails[0].paymentMethod) {
        paymentMethod = paymentDetails[0].paymentMethod.toLowerCase();
      }
    } else {
      if (!paymentMethod.includes('kot') && isKotOrder) {
        paymentMethod = 'kot pending';
      }
    }

    const status = isPaid ? 'completed' : (rawData.status || 'pending');
    const paymentStatus = isPaid ? 'paid' : 'pending';
    const orderType = isDineIn ? 'dineIn' : (rawData.orderType || (tableCode ? 'dineIn' : 'takeaway'));
    const tableNumber = tableCode || rawData.tableNumber || '';

    // 6. Update Customer CRM if phone provided
    let customerId = null;
    if (rawData.customerPhone && rawData.customerPhone.trim()) {
      const cleanPhone = rawData.customerPhone.trim();
      const customer = await Customer.findOneAndUpdate(
        { businessId, phone: cleanPhone },
        {
          $set: {
            name: rawData.customerName || 'Walk-in Guest',
            lastVisit: new Date(),
          },
          $inc: {
            totalOrders: 1,
            totalSpent: status === 'completed' ? totalAmount : 0,
          },
          $setOnInsert: {
            businessId,
            phone: cleanPhone,
            firstVisit: new Date(),
          },
        },
        { upsert: true, new: true }
      );
      customerId = customer ? customer._id : null;
    }

    // 7. Create Order Document
    const invoiceNumber = `INV-${orderNumber}`;
    const order = await Order.create({
      businessId,
      orderNumber,
      orderType,
      tableNumber,
      customerId,
      customerName: rawData.customerName || '',
      customerPhone: rawData.customerPhone || '',
      status,
      items: items.map((i) => ({
        productId: i.productId && i.productId.length === 24 ? i.productId : undefined,
        name: i.name,
        price: Number(i.price) || 0,
        quantity: Number(i.quantity) || 1,
        foodType: (i.foodType || 'veg').toString().toLowerCase().replace('-', '_'),
        note: i.note || '',
      })),
      subtotal,
      discountAmount,
      taxAmount,
      cgst,
      sgst,
      igst,
      tipAmount,
      totalAmount,
      paymentMethod,
      paymentStatus,
      kotStatus: rawData.kotStatus || (isKOT ? 'sent' : 'not_sent'),
      kotNumber: rawData.kotNumber || (isKOT ? 1 : 0),
      notes: remarks,
      idempotencyKey,
      cartId,
      venderUserId,
      venderCardId,
      createdByUserId,
      createdByCardId,
      isKOT,
      paymentDetails,
      ncReason,
      paymentMode,
      orderDevice,
      isPaid,
      isDineIn,
      tableCode,
      restaurantCode,
      reason,
      remarks,
      clientSyncId,
      syncId,
      localOrderId,
      tokenNo,
      invoiceNumber,
      invoiceGenerated: status === 'completed',
    });

    // 8. Update Table status
    if (order.orderType === 'dineIn' && order.tableNumber) {
      if (status === 'completed') {
        await Table.findOneAndUpdate(
          { businessId, name: order.tableNumber },
          { $set: { status: 'free', currentOrderId: null, occupiedSince: null } }
        );
      } else {
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
    }

    // 9. Deduct Inventory & Create Sale/Invoice Record if completed
    let sale = null;
    if (status === 'completed') {
      sale = await Sale.findOneAndUpdate(
        { businessId, orderId: order._id },
        {
          $set: {
            orderNumber: order.orderNumber,
            orderType: order.orderType,
            tableNumber: order.tableNumber || '',
            customerName: order.customerName || '',
            customerPhone: order.customerPhone || '',
            items: (order.items || []).map((i) => ({
              name: i.name,
              price: i.price,
              quantity: i.quantity,
              foodType: i.foodType || 'veg',
            })),
            subtotal: order.subtotal,
            discountAmount: order.discountAmount || 0,
            taxAmount: order.taxAmount || 0,
            tipAmount: order.tipAmount || 0,
            totalAmount: order.totalAmount,
            paymentMethod: (order.paymentMethod || 'cash').toLowerCase(),
            saleDate: order.completedAt || order.createdAt || new Date(),
          },
          $setOnInsert: { businessId, orderId: order._id },
        },
        { upsert: true, new: true }
      );

      // Inventory deduction
      for (const item of order.items) {
        if (item.productId) {
          await Product.findOneAndUpdate(
            { _id: item.productId, businessId, trackInventory: true, stock: { $gt: 0 } },
            { $inc: { stock: -item.quantity } }
          );
        }
      }
    }

    return {
      order,
      sale,
      invoice: {
        invoiceNumber,
        invoiceDate: order.createdAt,
        totalAmount: order.totalAmount,
      },
    };
  }

  async createOrder(businessId, orderData) {
    const result = await this.generatePosOrder(businessId, orderData);
    return result.order || result;
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

  async updateOrderStatus(businessId, orderId, status, { reason } = {}) {
    const order = await Order.findOne({ _id: orderId, businessId });
    if (!order) {
      throw ApiError.notFound('Order not found');
    }

    order.status = status;
    if (status === 'completed') {
      order.completedAt = new Date();
      order.paymentStatus = 'paid';
      // Free linked table
      if (order.tableNumber) {
        await Table.findOneAndUpdate(
          { businessId, name: order.tableNumber },
          { $set: { status: 'free', currentOrderId: null, occupiedSince: null } }
        );
      }

      // Upsert Sale record
      await Sale.findOneAndUpdate(
        { businessId, orderId: order._id },
        {
          $set: {
            orderNumber: order.orderNumber,
            orderType: order.orderType,
            tableNumber: order.tableNumber || '',
            customerName: order.customerName || '',
            customerPhone: order.customerPhone || '',
            items: (order.items || []).map((i) => ({
              name: i.name,
              price: i.price,
              quantity: i.quantity,
              foodType: i.foodType || 'veg',
            })),
            subtotal: order.subtotal,
            discountAmount: order.discountAmount || 0,
            taxAmount: order.taxAmount || 0,
            tipAmount: order.tipAmount || 0,
            totalAmount: order.totalAmount,
            paymentMethod: (order.paymentMethod || 'cash').toLowerCase(),
            saleDate: order.completedAt || new Date(),
          },
          $setOnInsert: { businessId, orderId: order._id },
        },
        { upsert: true }
      );

      // Update customer CRM total spent
      if (order.customerPhone && order.customerPhone.trim()) {
        await Customer.findOneAndUpdate(
          { businessId, phone: order.customerPhone.trim() },
          {
            $inc: { totalSpent: order.totalAmount },
            $set: { lastVisit: new Date() },
          }
        );
      }
    } else if (status === 'cancelled') {
      order.cancelledAt = new Date();
      if (reason) order.cancellationReason = reason;

      // Free linked table
      if (order.tableNumber) {
        await Table.findOneAndUpdate(
          { businessId, name: order.tableNumber },
          { $set: { status: 'free', currentOrderId: null, occupiedSince: null } }
        );
      }

      // Remove any Sale record associated with cancelled order
      await Sale.findOneAndDelete({ businessId, orderId: order._id });
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
