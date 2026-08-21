const mongoose = require('mongoose');

const orderItemSchema = new mongoose.Schema(
  {
    productId: {
      type: mongoose.Schema.Types.Mixed,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    price: {
      type: Number,
      required: true,
      min: 0,
    },
    quantity: {
      type: Number,
      required: true,
      min: 1,
    },
    foodType: {
      type: String,
      enum: ['veg', 'non_veg', 'egg', 'beverage'],
      default: 'veg',
    },
    note: {
      type: String,
      default: '',
    },
  },
  { _id: true }
);

const orderSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    orderNumber: {
      type: String,
      required: true,
      index: true,
    },
    orderType: {
      type: String,
      enum: ['dineIn', 'takeaway', 'delivery'],
      default: 'dineIn',
      index: true,
    },
    tableNumber: {
      type: String,
      default: '',
      index: true,
    },
    customerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Customer',
      index: true,
    },
    customerName: {
      type: String,
      default: '',
      trim: true,
    },
    customerPhone: {
      type: String,
      default: '',
      trim: true,
    },
    status: {
      type: String,
      enum: ['pending', 'preparing', 'ready', 'completed', 'cancelled'],
      default: 'pending',
      index: true,
    },
    items: [orderItemSchema],
    subtotal: {
      type: Number,
      required: true,
      min: 0,
    },
    discountAmount: {
      type: Number,
      default: 0,
      min: 0,
    },
    cgst: {
      type: Number,
      default: 0,
      min: 0,
    },
    sgst: {
      type: Number,
      default: 0,
      min: 0,
    },
    igst: {
      type: Number,
      default: 0,
      min: 0,
    },
    taxAmount: {
      type: Number,
      default: 0,
      min: 0,
    },
    tipAmount: {
      type: Number,
      default: 0,
      min: 0,
    },
    totalAmount: {
      type: Number,
      required: true,
      min: 0,
    },
    paymentMethod: {
      type: String,
      default: 'unpaid',
      index: true,
    },
    paymentStatus: {
      type: String,
      enum: ['pending', 'paid', 'refunded'],
      default: 'pending',
      index: true,
    },
    kotStatus: {
      type: String,
      enum: ['not_sent', 'sent', 'printed'],
      default: 'not_sent',
    },
    kotNumber: {
      type: Number,
      default: 0,
    },
    notes: {
      type: String,
      default: '',
    },
    cancellationReason: {
      type: String,
      default: '',
    },
    cancelledAt: {
      type: Date,
    },
    completedAt: {
      type: Date,
    },
    idempotencyKey: {
      type: String,
      default: '',
      trim: true,
      index: true,
      sparse: true,
    },
    cartId: {
      type: String,
      default: '',
      trim: true,
    },
    venderUserId: {
      type: String,
      default: '',
      trim: true,
    },
    venderCardId: {
      type: String,
      default: '',
      trim: true,
    },
    createdByUserId: {
      type: String,
      default: '',
      trim: true,
    },
    createdByCardId: {
      type: String,
      default: '',
      trim: true,
    },
    isKOT: {
      type: Boolean,
      default: false,
    },
    paymentDetails: [
      {
        paymentType: { type: String, default: 'CASH' },
        paymentName: { type: String, default: 'CASH' },
        amount: { type: Number, default: 0 },
        paymentMethod: { type: String, default: 'CASH' },
        ncReason: { type: String, default: '' },
      },
    ],
    ncReason: {
      type: String,
      default: '',
    },
    paymentMode: {
      type: String,
      default: 'CASH',
    },
    orderDevice: {
      type: String,
      default: 'web',
    },
    isPaid: {
      type: Boolean,
      default: false,
    },
    isDineIn: {
      type: Boolean,
      default: false,
    },
    tableCode: {
      type: String,
      default: '',
    },
    restaurantCode: {
      type: String,
      default: '',
    },
    reason: {
      type: String,
      default: '',
    },
    remarks: {
      type: String,
      default: '',
    },
    clientSyncId: {
      type: String,
      default: '',
      trim: true,
      index: true,
      sparse: true,
    },
    syncId: {
      type: String,
      default: '',
      trim: true,
    },
    localOrderId: {
      type: String,
      default: '',
      trim: true,
    },
    tokenNo: {
      type: String,
      default: '',
      trim: true,
    },
    invoiceNumber: {
      type: String,
      default: '',
      trim: true,
    },
    invoiceGenerated: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
    toJSON: {
      transform(doc, ret) {
        ret.id = ret._id;
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

orderSchema.index({ businessId: 1, createdAt: -1 });
orderSchema.index({ businessId: 1, status: 1, createdAt: -1 });
orderSchema.index({ businessId: 1, orderType: 1, createdAt: -1 });
orderSchema.index({ businessId: 1, paymentMethod: 1, createdAt: -1 });
orderSchema.index({ businessId: 1, customerId: 1 });
orderSchema.index({ businessId: 1, tableNumber: 1 });
orderSchema.index({ businessId: 1, idempotencyKey: 1 });
orderSchema.index({ businessId: 1, clientSyncId: 1 });

const Order = mongoose.model('Order', orderSchema);

module.exports = Order;
