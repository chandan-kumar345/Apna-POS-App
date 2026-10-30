const mongoose = require('mongoose');
const tenantIsolationPlugin = require('../plugins/tenantIsolationPlugin');

const couponSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    campaignId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Campaign',
      default: null,
      index: true,
    },
    code: {
      type: String,
      required: [true, 'Coupon code is required'],
      trim: true,
      uppercase: true,
    },
    title: {
      type: String,
      default: '',
      trim: true,
    },
    description: {
      type: String,
      default: '',
      trim: true,
    },
    discountType: {
      type: String,
      enum: ['percentage', 'flat', 'cashback', 'free_gift', 'bogo'],
      default: 'percentage',
      required: true,
    },
    rewardScope: {
      type: String,
      enum: ['whole_bill', 'chosen_products'],
      default: 'whole_bill',
    },
    freeGiftProductId: {
      type: String,
      default: '',
    },
    freeGiftProductName: {
      type: String,
      default: '',
    },
    freeGiftProductPrice: {
      type: Number,
      default: 0,
    },
    discountValue: {
      type: Number,
      required: [true, 'Discount value is required'],
      min: [0, 'Discount value cannot be negative'],
    },
    maxDiscountAmount: {
      type: Number,
      default: null,
      min: 0,
    },
    minCartAmount: {
      type: Number,
      default: 0,
      min: 0,
    },
    startDate: {
      type: Date,
      default: Date.now,
    },
    endDate: {
      type: Date,
      default: null,
    },
    isActive: {
      type: Boolean,
      default: true,
      index: true,
    },
    orderTypes: {
      type: [String],
      enum: ['dineIn', 'takeaway', 'delivery'],
      default: ['dineIn', 'takeaway', 'delivery'],
    },
    applicableCategories: {
      type: [String],
      default: [],
    },
    applicableProducts: {
      type: [String], // Array of productId or product names
      default: [],
    },
    excludedProducts: {
      type: [String],
      default: [],
    },
    customerEligibility: {
      type: String,
      enum: ['all', 'new', 'repeat', 'min_orders'],
      default: 'all',
    },
    customerMinOrders: {
      type: Number,
      default: 0,
      min: 0,
    },
    usageLimitPerCustomer: {
      type: Number,
      default: 1, // Default 1 per customer or 0 for unlimited
      min: 0,
    },
    totalUsageLimit: {
      type: Number,
      default: 0, // 0 means unlimited
      min: 0,
    },
    totalTimesUsed: {
      type: Number,
      default: 0,
      min: 0,
    },
    validDays: {
      type: [Number], // 0: Sunday, 1: Monday, ..., 6: Saturday
      default: [0, 1, 2, 3, 4, 5, 6],
    },
    timeSlots: [
      {
        startTime: { type: String, trim: true }, // e.g., "11:00"
        endTime: { type: String, trim: true },   // e.g., "15:00"
      },
    ],
    termsAndConditions: {
      type: [String],
      default: [],
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

couponSchema.index({ businessId: 1, code: 1 }, { unique: true });
couponSchema.index({ businessId: 1, isActive: 1, startDate: 1, endDate: 1 });
couponSchema.plugin(tenantIsolationPlugin);

const Coupon = mongoose.model('Coupon', couponSchema);

module.exports = Coupon;
