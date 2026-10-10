const mongoose = require('mongoose');
const tenantIsolationPlugin = require('../plugins/tenantIsolationPlugin');

const ebillSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    billId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Order',
      required: true,
      index: true,
    },
    customerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Customer',
      default: null,
    },
    customerPhone: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    customerName: {
      type: String,
      default: '',
      trim: true,
    },
    walletTransactionId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'WalletTransaction',
      default: null,
    },
    amountCharged: {
      type: Number,
      default: 0,
    },
    currency: {
      type: String,
      default: 'INR',
    },
    documentUrl: {
      type: String,
      default: null,
    },
    receiptText: {
      type: String,
      default: '',
    },
    whatsappPhoneNumberId: {
      type: String,
      default: '1391578214040423',
    },
    whatsappMessageId: {
      type: String,
      default: null,
      index: true,
    },
    status: {
      type: String,
      enum: ['PENDING', 'PROCESSING', 'SENT', 'DELIVERED', 'FAILED'],
      default: 'PENDING',
      index: true,
    },
    deliveryStatus: {
      type: String,
      enum: ['PENDING', 'SENT', 'DELIVERED', 'READ', 'FAILED'],
      default: 'PENDING',
      index: true,
    },
    retryCount: {
      type: Number,
      default: 0,
    },
    lastError: {
      type: mongoose.Schema.Types.Mixed,
      default: null,
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

ebillSchema.index({ businessId: 1, billId: 1 });
ebillSchema.index({ businessId: 1, createdAt: -1 });

ebillSchema.plugin(tenantIsolationPlugin);

const EBill = mongoose.model('EBill', ebillSchema);

module.exports = EBill;
