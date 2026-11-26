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
    programId: {
      type: String,
      default: 'prog_visit_made',
      index: true,
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
    whatsappStatus: {
      type: String,
      enum: ['not_applicable', 'pending', 'accepted', 'sent', 'delivered', 'read', 'failed', 'simulated'],
      default: 'not_applicable',
      index: true,
    },
    whatsappMessageId: {
      type: String,
      default: null,
    },
    whatsappPhoneNumberId: {
      type: String,
      default: '',
    },
    whatsappTemplateName: {
      type: String,
      default: '',
    },
    whatsappVia: {
      type: String,
      enum: ['', 'template', 'text', 'simulated'],
      default: '',
    },
    whatsappError: {
      type: String,
      default: '',
    },
    whatsappErrorCode: {
      type: String,
      default: '',
    },
    whatsappAttempts: {
      type: Number,
      default: 0,
    },
    whatsappLastAttemptAt: {
      type: Date,
      default: null,
    },
    whatsappDeliveredAt: {
      type: Date,
      default: null,
    },
    whatsappMetadata: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
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

loyaltyTransactionSchema.index({ whatsappMessageId: 1 }, { sparse: true });

const LoyaltyTransaction = mongoose.model('LoyaltyTransaction', loyaltyTransactionSchema);

module.exports = LoyaltyTransaction;
