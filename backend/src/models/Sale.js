const mongoose = require('mongoose');

const saleSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    orderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Order',
      required: true,
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
    },
    tableNumber: {
      type: String,
      default: '',
    },
    customerName: {
      type: String,
      default: '',
    },
    customerPhone: {
      type: String,
      default: '',
    },
    items: [
      {
        name: { type: String, required: true },
        price: { type: Number, required: true },
        quantity: { type: Number, required: true },
        foodType: { type: String, default: 'veg' },
      },
    ],
    subtotal: {
      type: Number,
      required: true,
      min: 0,
    },
    discountAmount: {
      type: Number,
      default: 0,
    },
    taxAmount: {
      type: Number,
      default: 0,
    },
    tipAmount: {
      type: Number,
      default: 0,
    },
    totalAmount: {
      type: Number,
      required: true,
      min: 0,
    },
    paymentMethod: {
      type: String,
      enum: ['cash', 'upi', 'card'],
      required: true,
      index: true,
    },
    saleDate: {
      type: Date,
      default: Date.now,
      index: true,
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

saleSchema.index({ businessId: 1, saleDate: -1 });
saleSchema.index({ businessId: 1, paymentMethod: 1 });

const Sale = mongoose.model('Sale', saleSchema);

module.exports = Sale;
