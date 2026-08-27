const mongoose = require('mongoose');

const loyaltyTransactionSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    customerPhone: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    orderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Order',
      default: null,
      index: true,
    },
    orderNumber: {
      type: String,
      default: '',
    },
    type: {
      type: String,
      enum: ['earn', 'redeem', 'adjustment'],
      required: true,
    },
    points: {
      type: Number,
      required: true,
    },
    balanceAfter: {
      type: Number,
      required: true,
    },
    stageId: {
      type: String,
      default: '',
    },
    discountAmount: {
      type: Number,
      default: 0,
    },
    messageHeader: {
      type: String,
      default: 'APNA POS',
    },
    message: {
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

const LoyaltyTransaction = mongoose.model('LoyaltyTransaction', loyaltyTransactionSchema);

module.exports = LoyaltyTransaction;
