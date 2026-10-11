const mongoose = require('mongoose');
const tenantIsolationPlugin = require('../plugins/tenantIsolationPlugin');

const stockReceiptItemSchema = new mongoose.Schema(
  {
    materialId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'RawMaterial',
      required: true,
    },
    materialName: {
      type: String,
      required: true,
      trim: true,
    },
    purchaseQuantity: {
      type: Number,
      required: true,
      min: [0.0001, 'Quantity must be greater than zero'],
    },
    purchaseUnit: {
      type: String,
      required: true,
      trim: true,
    },
    conversionFactor: {
      type: Number,
      required: true,
      default: 1000,
    },
    baseUnitsReceived: {
      type: Number,
      required: true,
      min: [0.0001, 'Base units must be greater than zero'],
    },
    unitCost: {
      type: Number,
      required: true,
      min: [0, 'Cost cannot be negative'],
    },
    totalCost: {
      type: Number,
      required: true,
      min: [0, 'Total cost cannot be negative'],
    },
  },
  { _id: false }
);

const stockReceiptSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    receiptNumber: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    supplierName: {
      type: String,
      default: '',
      trim: true,
    },
    invoiceNumber: {
      type: String,
      default: '',
      trim: true,
    },
    purchaseDate: {
      type: Date,
      default: Date.now,
      index: true,
    },
    items: {
      type: [stockReceiptItemSchema],
      default: [],
      validate: [
        (val) => Array.isArray(val) && val.length > 0,
        'Stock receipt must contain at least one item',
      ],
    },
    totalAmount: {
      type: Number,
      default: 0,
      min: 0,
    },
    paymentStatus: {
      type: String,
      enum: ['paid', 'pending', 'partial'],
      default: 'paid',
    },
    notes: {
      type: String,
      default: '',
      trim: true,
    },
    receivedBy: {
      type: String,
      default: 'Owner',
      trim: true,
    },
  },
  {
    timestamps: true,
    toJSON: {
      transform(doc, ret) {
        ret.id = ret._id ? ret._id.toString() : ret.id;
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

stockReceiptSchema.index({ businessId: 1, receiptNumber: 1 });
stockReceiptSchema.index({ businessId: 1, purchaseDate: -1 });

stockReceiptSchema.plugin(tenantIsolationPlugin);

const StockReceipt = mongoose.model('StockReceipt', stockReceiptSchema);

module.exports = StockReceipt;
