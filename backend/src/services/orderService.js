const mongoose = require('mongoose');
const Order = require('../models/Order');
const Sale = require('../models/Sale');
const Table = require('../models/Table');
const Customer = require('../models/Customer');
const Cart = require('../models/Cart');
const Product = require('../models/Product');
const Business = require('../models/Business');
const PrintLog = require('../models/PrintLog');
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
    const tableNumber = orderType === 'dineIn' ? (tableCode || rawData.tableNumber || '') : '';
    const deliveryAddress = orderType === 'delivery' ? (rawData.deliveryAddress || '').trim() : '';

    // 6. Update Customer CRM if phone provided
    let customerId = null;
    if (rawData.customerPhone && rawData.customerPhone.trim()) {
      const cleanPhone = rawData.customerPhone.trim();
      const customerSetFields = {
        name: rawData.customerName || 'Walk-in Guest',
        lastVisit: new Date(),
      };
      if (deliveryAddress) {
        customerSetFields.address = deliveryAddress;
      }

      const customer = await Customer.findOneAndUpdate(
        { businessId, phone: cleanPhone },
        {
          $set: customerSetFields,
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
      deliveryAddress,
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
    let order = null;
    if (mongoose.Types.ObjectId.isValid(orderId)) {
      order = await Order.findOne({ _id: orderId, businessId });
    }
    if (!order) {
      order = await Order.findOne({
        businessId,
        $or: [
          { clientSyncId: orderId },
          { localOrderId: orderId },
          { orderNumber: orderId },
          { orderNumber: (orderId || '').replace('ord_', '').replace('ORD-', '') },
        ],
      });
    }
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
    let order = null;
    if (mongoose.Types.ObjectId.isValid(orderId)) {
      order = await Order.findOne({ _id: orderId, businessId });
    }
    if (!order) {
      order = await Order.findOne({
        businessId,
        $or: [
          { clientSyncId: orderId },
          { localOrderId: orderId },
          { orderNumber: orderId },
          { orderNumber: (orderId || '').replace('ord_', '').replace('ORD-', '') },
        ],
      });
    }
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

  _buildUpiIntentUri(business, orderNumber, amount) {
    const upiId = (
      business?.orderSettings?.upiId ||
      business?.upiId ||
      business?.profile?.upiId ||
      'apnapos@upi'
    ).trim();
    const businessName = (
      business?.profile?.name ||
      business?.profile?.companyName ||
      business?.name ||
      'Apna POS Store'
    ).trim();

    const safeAmount = Number(amount || 0).toFixed(2);
    const encodedName = encodeURIComponent(businessName);
    const encodedNote = encodeURIComponent(`Bill ${orderNumber}`);

    return `upi://pay?pa=${upiId}&pn=${encodedName}&am=${safeAmount}&cu=INR&tr=${orderNumber}&tn=${encodedNote}`;
  }

  async saveAndPrintOrder(businessId, rawData) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;
    const business = await Business.findById(bId);

    // 1. Resolve existing running order if ID or orderNumber is provided
    const lookupOrderId = (rawData.orderId || rawData._id || rawData.id || '').toString().trim();
    const lookupOrderNumber = (rawData.orderNumber || rawData.orderNo || '').toString().trim();
    const lookupSyncId = (rawData.clientSyncId || rawData.syncId || rawData.localOrderId || rawData.idempotencyKey || '').toString().trim();

    let existingOrder = null;
    const searchConditions = [];
    if (mongoose.Types.ObjectId.isValid(lookupOrderId)) {
      searchConditions.push({ _id: lookupOrderId });
    }
    if (lookupOrderNumber) {
      searchConditions.push({ orderNumber: lookupOrderNumber });
    }
    if (lookupSyncId) {
      searchConditions.push({ clientSyncId: lookupSyncId });
      searchConditions.push({ localOrderId: lookupSyncId });
      searchConditions.push({ idempotencyKey: lookupSyncId });
    }

    if (searchConditions.length > 0) {
      existingOrder = await Order.findOne({
        businessId: bId,
        $or: searchConditions,
        status: { $nin: ['completed', 'cancelled'] },
      });
    }

    // 2. Parse Items & Financials
    let items = Array.isArray(rawData.items) && rawData.items.length > 0 ? rawData.items : [];
    if (items.length === 0 && rawData.cartId) {
      const isObjectId = /^[0-9a-fA-F]{24}$/.test(rawData.cartId);
      const cart = await Cart.findOne({
        businessId: bId,
        ...(isObjectId ? { _id: rawData.cartId } : { tableNumber: rawData.cartId }),
      });
      if (cart && Array.isArray(cart.items) && cart.items.length > 0) {
        items = cart.items.map((i) => ({
          productId: i.productId,
          name: i.name,
          price: i.effectivePrice != null ? i.effectivePrice : i.price,
          quantity: i.quantity,
          foodType: (i.foodType || 'veg').toString().toLowerCase().replace('-', '_'),
          note: i.note || '',
        }));
      }
    }

    if (items.length === 0) {
      throw ApiError.badRequest('Order must contain at least one item to Save & Print');
    }

    const computedSubtotal = items.reduce((sum, i) => sum + (Number(i.price) || 0) * (Number(i.quantity) || 1), 0);
    const subtotal = rawData.subtotal !== undefined ? Number(rawData.subtotal) : computedSubtotal;
    const discountAmount = Number(rawData.discountAmount) || 0;
    const taxAmount = Number(rawData.taxAmount) || 0;
    const cgst = rawData.cgst !== undefined ? Number(rawData.cgst) : Number((taxAmount / 2).toFixed(2));
    const sgst = rawData.sgst !== undefined ? Number(rawData.sgst) : Number((taxAmount / 2).toFixed(2));
    const igst = Number(rawData.igst) || 0;
    const tipAmount = Number(rawData.tipAmount) || 0;
    const deliveryCharge = Number(rawData.deliveryCharge) || 0;
    const roundOff = Number(rawData.roundOff) || 0;
    const totalAmount = rawData.totalAmount !== undefined
      ? Number(rawData.totalAmount)
      : Math.max(0, Number(((subtotal - discountAmount) + taxAmount + tipAmount + deliveryCharge + roundOff).toFixed(2)));

    const orderType = rawData.orderType || (rawData.tableNumber ? 'dineIn' : 'takeaway');
    const tableNumber = orderType === 'dineIn' ? (rawData.tableNumber || rawData.T || '') : '';
    const deliveryAddress = orderType === 'delivery' ? (rawData.deliveryAddress || '').trim() : '';
    const customerName = (rawData.customerName || '').trim();
    const customerPhone = (rawData.customerPhone || '').trim();
    const notes = (rawData.notes || rawData.remarks || '').trim();

    const formattedItems = items.map((i) => ({
      productId: i.productId && i.productId.length === 24 ? i.productId : undefined,
      name: i.name,
      price: Number(i.price) || 0,
      quantity: Number(i.quantity) || 1,
      foodType: (i.foodType || 'veg').toString().toLowerCase().replace('-', '_'),
      note: i.note || '',
    }));

    let order = existingOrder;
    let orderNumber = existingOrder ? existingOrder.orderNumber : (lookupOrderNumber || this._generateOrderNumber());

    // Generate Dynamic UPI QR
    const qrIntentUrl = this._buildUpiIntentUri(business, orderNumber, totalAmount);

    if (order) {
      // UPDATE EXISTING RUNNING ORDER
      order.items = formattedItems;
      order.subtotal = subtotal;
      order.discountAmount = discountAmount;
      order.taxAmount = taxAmount;
      order.cgst = cgst;
      order.sgst = sgst;
      order.igst = igst;
      order.tipAmount = tipAmount;
      order.totalAmount = totalAmount;
      order.orderType = orderType;
      order.tableNumber = tableNumber;
      order.deliveryAddress = deliveryAddress;
      if (customerName) order.customerName = customerName;
      if (customerPhone) order.customerPhone = customerPhone;
      if (notes) order.notes = notes;
      order.qrIntentUrl = qrIntentUrl;
      order.printCount = (order.printCount || 0) + 1;
      await order.save();
    } else {
      // CREATE NEW RUNNING ORDER
      const invoiceNumber = `INV-${orderNumber}`;
      order = await Order.create({
        businessId: bId,
        orderNumber,
        orderType,
        tableNumber,
        deliveryAddress,
        customerName,
        customerPhone,
        status: rawData.status || 'pending',
        paymentStatus: 'pending',
        paymentMethod: 'unpaid',
        items: formattedItems,
        subtotal,
        discountAmount,
        taxAmount,
        cgst,
        sgst,
        igst,
        tipAmount,
        totalAmount,
        notes,
        qrIntentUrl,
        invoiceNumber,
        printCount: 1,
        clientSyncId: lookupSyncId || undefined,
        localOrderId: lookupSyncId || undefined,
      });
    }

    // Keep table occupied if dineIn
    if (order.orderType === 'dineIn' && order.tableNumber) {
      await Table.findOneAndUpdate(
        { businessId: bId, name: order.tableNumber },
        {
          $set: {
            status: 'occupied',
            currentOrderId: order._id,
            occupiedSince: new Date(),
          },
        }
      );
    }

    // Determine printNumber sequence for this order
    const existingPrintsCount = await PrintLog.countDocuments({ businessId: bId, orderId: order._id });
    const printNumber = existingPrintsCount + 1;

    // Create immutable PrintLog snapshot
    const printLog = await PrintLog.create({
      businessId: bId,
      orderId: order._id,
      orderNumber: order.orderNumber,
      printNumber,
      printType: rawData.printType || 'save_and_print',
      orderStatus: order.status,
      paymentStatus: order.paymentStatus || 'pending',
      paymentMethod: order.paymentMethod || 'unpaid',
      subtotal: order.subtotal,
      discountAmount: order.discountAmount,
      taxAmount: order.taxAmount,
      cgst: order.cgst || cgst,
      sgst: order.sgst || sgst,
      igst: order.igst || igst,
      tipAmount: order.tipAmount || tipAmount,
      deliveryCharge,
      roundOff,
      totalAmount: order.totalAmount,
      orderType: order.orderType,
      tableNumber: order.tableNumber,
      deliveryAddress: order.deliveryAddress,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      items: order.items.map((i) => ({
        productId: i.productId ? i.productId.toString() : '',
        name: i.name,
        price: i.price,
        quantity: i.quantity,
        foodType: i.foodType,
        note: i.note,
        totalPrice: Number((i.price * i.quantity).toFixed(2)),
      })),
      qrPayload: qrIntentUrl,
      invoiceNumber: order.invoiceNumber || `INV-${order.orderNumber}`,
      isReprint: false,
      printedBy: (rawData.CreatedByUserId || rawData.createdByUserId || rawData.user || '').toString().trim(),
      notes: notes || `Bill Version #${printNumber}`,
    });

    return {
      order,
      invoice: {
        invoiceNumber: order.invoiceNumber || `INV-${order.orderNumber}`,
        invoiceDate: order.createdAt,
        totalAmount: order.totalAmount,
      },
      printLog,
      qrData: {
        qrIntentUrl,
        upiId: business?.orderSettings?.upiId || business?.upiId || 'apnapos@upi',
      },
      printNumber,
    };
  }

  async settleOrder(businessId, orderId, paymentData = {}) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;
    let order = null;
    if (mongoose.Types.ObjectId.isValid(orderId)) {
      order = await Order.findOne({ _id: orderId, businessId: bId });
    }
    if (!order) {
      order = await Order.findOne({
        businessId: bId,
        $or: [
          { clientSyncId: orderId },
          { localOrderId: orderId },
          { orderNumber: orderId },
          { orderNumber: (orderId || '').replace('ord_', '').replace('ORD-', '') },
        ],
      });
    }
    if (!order) {
      throw ApiError.notFound('Order not found for settlement');
    }

    // Idempotency: if already settled
    if (order.status === 'completed' && order.paymentStatus === 'paid' && order.isPaid) {
      const existingSale = await Sale.findOne({ businessId: bId, orderId: order._id });
      const lastPrintLog = await PrintLog.findOne({ businessId: bId, orderId: order._id, paymentStatus: 'paid' }).sort({ createdAt: -1 });
      return {
        order,
        sale: existingSale,
        invoice: {
          invoiceNumber: order.invoiceNumber || `INV-${order.orderNumber}`,
          invoiceDate: order.completedAt || order.createdAt,
          totalAmount: order.totalAmount,
        },
        printLog: lastPrintLog,
        isExisting: true,
        message: 'Order already settled',
      };
    }

    const paymentMethod = (paymentData.paymentMethod || paymentData.paymentMode || 'Cash').toString().trim();
    const paymentDetails = Array.isArray(paymentData.paymentDetails) && paymentData.paymentDetails.length > 0
      ? paymentData.paymentDetails
      : [
          {
            paymentType: paymentMethod,
            paymentName: paymentMethod,
            amount: paymentData.amountPaid !== undefined ? Number(paymentData.amountPaid) : order.totalAmount,
            paymentMethod,
            ncReason: paymentData.ncReason || '',
          },
        ];

    order.paymentMethod = paymentMethod;
    order.paymentMode = paymentMethod;
    order.paymentDetails = paymentDetails;
    order.paymentStatus = 'paid';
    order.isPaid = true;
    order.status = 'completed';
    order.completedAt = new Date();
    order.invoiceGenerated = true;
    if (paymentData.roundOff !== undefined) {
      order.roundOff = Number(paymentData.roundOff) || 0;
    }
    if (paymentData.totalAmount !== undefined) {
      order.totalAmount = Number(paymentData.totalAmount);
    }
    await order.save();

    // 1. Create or Upsert Sale record (ensures exactly 1 sale record per settled order!)
    const sale = await Sale.findOneAndUpdate(
      { businessId: bId, orderId: order._id },
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
          paymentMethod: paymentMethod.toLowerCase(),
          saleDate: order.completedAt || new Date(),
        },
        $setOnInsert: { businessId: bId, orderId: order._id },
      },
      { upsert: true, new: true }
    );

    // 2. Deduct Inventory for tracked items
    for (const item of order.items) {
      if (item.productId) {
        await Product.findOneAndUpdate(
          { _id: item.productId, businessId: bId, trackInventory: true, stock: { $gt: 0 } },
          { $inc: { stock: -item.quantity } }
        );
      }
    }

    // 3. Free Table if dineIn
    if (order.tableNumber) {
      const cleanNum = order.tableNumber.toString().replace(/[^0-9]/g, '');
      const orConditions = [
        { name: order.tableNumber },
        { name: new RegExp(`^${order.tableNumber}$`, 'i') },
      ];
      if (cleanNum) {
        orConditions.push({ tableNumber: Number(cleanNum) });
        orConditions.push({ name: `T${cleanNum}` });
        orConditions.push({ name: `Table ${cleanNum}` });
      }
      await Table.findOneAndUpdate(
        { businessId: bId, $or: orConditions },
        { $set: { status: 'free', currentOrderId: null, occupiedSince: null, activeOrderTotal: 0, activeItemCount: 0 } }
      );
    }

    // 4. Update Customer CRM metrics
    if (order.customerPhone && order.customerPhone.trim()) {
      await Customer.findOneAndUpdate(
        { businessId: bId, phone: order.customerPhone.trim() },
        {
          $inc: { totalSpent: order.totalAmount, totalOrders: 1 },
          $set: { lastVisit: new Date(), name: order.customerName || 'Walk-in Guest' },
        },
        { upsert: true }
      );
    }

    // 5. Create final paid receipt PrintLog
    const existingPrintsCount = await PrintLog.countDocuments({ businessId: bId, orderId: order._id });
    const printNumber = existingPrintsCount + 1;

    const printLog = await PrintLog.create({
      businessId: bId,
      orderId: order._id,
      orderNumber: order.orderNumber,
      printNumber,
      printType: 'receipt',
      orderStatus: 'completed',
      paymentStatus: 'paid',
      paymentMethod,
      subtotal: order.subtotal,
      discountAmount: order.discountAmount,
      taxAmount: order.taxAmount,
      cgst: order.cgst,
      sgst: order.sgst,
      igst: order.igst,
      tipAmount: order.tipAmount,
      totalAmount: order.totalAmount,
      orderType: order.orderType,
      tableNumber: order.tableNumber,
      deliveryAddress: order.deliveryAddress,
      customerName: order.customerName,
      customerPhone: order.customerPhone,
      items: order.items.map((i) => ({
        productId: i.productId ? i.productId.toString() : '',
        name: i.name,
        price: i.price,
        quantity: i.quantity,
        foodType: i.foodType,
        note: i.note,
        totalPrice: Number((i.price * i.quantity).toFixed(2)),
      })),
      invoiceNumber: order.invoiceNumber || `INV-${order.orderNumber}`,
      isReprint: false,
      printedBy: (paymentData.user || paymentData.CreatedByUserId || '').toString().trim(),
      notes: `Final Settlement Receipt #${printNumber}`,
    });

    return {
      success: true,
      order,
      sale,
      invoice: {
        invoiceNumber: order.invoiceNumber || `INV-${order.orderNumber}`,
        invoiceDate: order.completedAt,
        totalAmount: order.totalAmount,
      },
      printLog,
    };
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
