const mongoose = require('mongoose');
const tenantIsolationPlugin = require('../plugins/tenantIsolationPlugin');

const walletSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      unique: true,
      index: true,
    },
    balance: {
      type: Number,
      default: 100.0, // Default promotional / starting balance for business
      min: 0,
    },
    currency: {
      type: String,
      default: 'INR',
      trim: true,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    ebillCharge: {
      type: Number,
      default: null, // If set, overrides platform default eBill fee for this business
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

walletSchema.plugin(tenantIsolationPlugin);

const Wallet = mongoose.model('Wallet', walletSchema);

module.exports = Wallet;
