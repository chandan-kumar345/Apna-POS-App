const mongoose = require('mongoose');

const activeOtpSchema = new mongoose.Schema(
  {
    otp: { type: String, required: true },
    stageId: { type: String, required: true },
    discountValue: { type: Number, required: true },
    pointsToRedeem: { type: Number, required: true },
    expiresAt: { type: Date, required: true },
  },
  { _id: false }
);

const customerLoyaltySchema = new mongoose.Schema(
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
    customerName: {
      type: String,
      default: '',
      trim: true,
    },
    customerId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Customer',
      index: true,
    },
    pointsBalance: {
      type: Number,
      default: 0,
      min: 0,
    },
    totalPointsEarned: {
      type: Number,
      default: 0,
      min: 0,
    },
    totalPointsRedeemed: {
      type: Number,
      default: 0,
      min: 0,
    },
    totalVisits: {
      type: Number,
      default: 0,
      min: 0,
    },
    unlockedStages: {
      type: [String],
      default: [],
    },
    activeOtp: {
      type: activeOtpSchema,
      default: null,
    },
    lastEarningAt: {
      type: Date,
      default: null,
    },
    lastRedemptionAt: {
      type: Date,
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

customerLoyaltySchema.index({ businessId: 1, customerPhone: 1 }, { unique: true });

const CustomerLoyalty = mongoose.model('CustomerLoyalty', customerLoyaltySchema);

module.exports = CustomerLoyalty;
