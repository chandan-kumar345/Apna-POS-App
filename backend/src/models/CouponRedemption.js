const mongoose = require('mongoose');
const tenantIsolationPlugin = require('../plugins/tenantIsolationPlugin');

const couponRedemptionSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    couponId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Coupon',
      required: true,
      index: true,
    },
    campaignId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Campaign',
      default: null,
      index: true,
    },
    couponCode: {
      type: String,
      required: true,
      uppercase: true,
      trim: true,
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
      default: '',
      trim: true,
    },
    customerPhone: {
      type: String,
      default: '',
      trim: true,
      index: true,
    },
    customerName: {
      type: String,
      default: '',
      trim: true,
    },
    orderSubtotal: {
      type: Number,
      default: 0,
    },
    discountAmount: {
      type: Number,
      required: true,
      min: 0,
    },
    finalOrderAmount: {
      type: Number,
      default: 0,
    },
    redeemedAt: {
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

couponRedemptionSchema.index({ businessId: 1, couponCode: 1, customerPhone: 1 });
couponRedemptionSchema.index({ businessId: 1, campaignId: 1, customerPhone: 1 });
couponRedemptionSchema.index({ businessId: 1, redeemedAt: -1 });
couponRedemptionSchema.plugin(tenantIsolationPlugin);

const CouponRedemption = mongoose.model('CouponRedemption', couponRedemptionSchema);

module.exports = CouponRedemption;
