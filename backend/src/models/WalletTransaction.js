const mongoose = require('mongoose');
const tenantIsolationPlugin = require('../plugins/tenantIsolationPlugin');

const walletTransactionSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    walletId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Wallet',
      required: true,
      index: true,
    },
    type: {
      type: String,
      enum: ['DEBIT', 'CREDIT'],
      required: true,
    },
    category: {
      type: String,
      enum: ['EBILL', 'RECHARGE', 'REFUND', 'ADJUSTMENT'],
      default: 'EBILL',
      index: true,
    },
    amount: {
      type: Number,
      required: true,
      min: 0,
    },
    currency: {
      type: String,
      default: 'INR',
    },
    referenceType: {
      type: String,
      enum: ['EBILL', 'ORDER', 'RECHARGE', 'MANUAL'],
      default: 'EBILL',
    },
    referenceId: {
      type: String,
      default: '',
      index: true,
    },
    idempotencyKey: {
      type: String,
      index: true,
      sparse: true,
    },
    status: {
      type: String,
      enum: ['SUCCESS', 'FAILED', 'PENDING', 'REVERSED'],
      default: 'SUCCESS',
      index: true,
    },
    description: {
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

walletTransactionSchema.index({ businessId: 1, idempotencyKey: 1 }, { unique: true, sparse: true });
walletTransactionSchema.index({ businessId: 1, createdAt: -1 });

walletTransactionSchema.plugin(tenantIsolationPlugin);

const WalletTransaction = mongoose.model('WalletTransaction', walletTransactionSchema);

module.exports = WalletTransaction;
