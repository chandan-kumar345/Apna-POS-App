const mongoose = require('mongoose');

const printLogItemSchema = new mongoose.Schema(
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
      default: 'veg',
    },
    note: {
      type: String,
      default: '',
    },
    totalPrice: {
      type: Number,
      default: 0,
    },
  },
  { _id: false }
);

const printLogSchema = new mongoose.Schema(
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
      index: true,
    },
    orderNumber: {
      type: String,
      required: true,
      index: true,
    },
    printNumber: {
      type: Number,
      default: 1,
    },
    printType: {
      type: String,
      enum: ['save_and_print', 'bill', 'receipt', 'reprint', 'kot'],
      default: 'save_and_print',
      index: true,
    },
    orderStatus: {
      type: String,
      default: 'pending',
      index: true,
    },
    paymentStatus: {
      type: String,
      enum: ['pending', 'paid', 'unpaid', 'refunded'],
      default: 'pending',
      index: true,
    },
    paymentMethod: {
      type: String,
      default: 'unpaid',
    },
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
    taxAmount: {
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
    tipAmount: {
      type: Number,
      default: 0,
      min: 0,
    },
    deliveryCharge: {
      type: Number,
      default: 0,
      min: 0,
    },
    roundOff: {
      type: Number,
      default: 0,
    },
    totalAmount: {
      type: Number,
      required: true,
      min: 0,
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
    deliveryAddress: {
      type: String,
      default: '',
      trim: true,
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
    items: [printLogItemSchema],
    qrPayload: {
      type: String,
      default: '',
    },
    qrImageUrl: {
      type: String,
      default: '',
    },
    invoiceNumber: {
      type: String,
      default: '',
      trim: true,
    },
    isReprint: {
      type: Boolean,
      default: false,
    },
    originalPrintLogId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'PrintLog',
      default: null,
    },
    printedBy: {
      type: String,
      default: '',
      trim: true,
    },
    notes: {
      type: String,
      default: '',
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

printLogSchema.index({ businessId: 1, createdAt: -1 });
printLogSchema.index({ businessId: 1, orderId: 1, createdAt: -1 });
printLogSchema.index({ businessId: 1, orderNumber: 1 });
printLogSchema.index({ businessId: 1, paymentStatus: 1 });
printLogSchema.index({ businessId: 1, printType: 1 });

const PrintLog = mongoose.model('PrintLog', printLogSchema);

module.exports = PrintLog;
