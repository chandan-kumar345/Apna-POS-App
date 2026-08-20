const mongoose = require('mongoose');

const orderItemSchema = new mongoose.Schema(
  {
    productId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Product',
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
      enum: ['veg', 'non_veg', 'egg'],
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

const Order = mongoose.model('Order', orderSchema);

module.exports = Order;
