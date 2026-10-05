const mongoose = require('mongoose');

const subscriptionSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      index: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      index: true,
    },
    staffId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Staff',
      index: true,
    },
    targetType: {
      type: String,
      enum: ['business', 'user', 'staff'],
      default: 'business',
      index: true,
    },
    userEmail: {
      type: String,
      trim: true,
      lowercase: true,
      index: true,
      default: '',
    },
    userName: {
      type: String,
      trim: true,
      default: '',
    },
    phone: {
      type: String,
      trim: true,
      default: '',
    },
    businessName: {
      type: String,
      trim: true,
      default: '',
    },
    plan: {
      type: String,
      enum: ['starter', 'standard', 'growth', 'pro', 'enterprise'],
      default: 'standard',
    },
    billingCycle: {
      type: String,
      enum: ['monthly', 'annual', 'lifetime', 'custom'],
      default: 'monthly',
    },
    amount: {
      type: Number,
      default: 300,
    },
    currency: {
      type: String,
      default: 'INR',
    },
    isActive: {
      type: Boolean,
      default: true,
      index: true,
    },
    status: {
      type: String,
      enum: ['active', 'inactive', 'expired', 'trial', 'cancelled', 'pending'],
      default: 'active',
      index: true,
    },
    upiId: {
      type: String,
      default: '9709593705@ybl',
    },
    paymentRef: {
      type: String,
      trim: true,
      default: '',
    },
    paymentMethod: {
      type: String,
      enum: ['upi', 'cash', 'card', 'netbanking', 'admin_grant', 'other'],
      default: 'upi',
    },
    activatedAt: {
      type: Date,
      default: Date.now,
    },
    expiresAt: {
      type: Date,
      index: true,
    },
    features: {
      type: [String],
      default: ['pos', 'tables', 'orders', 'reports', 'inventory', 'loyalty', 'campaign', 'staff'],
    },
    allowedStaffCount: {
      type: Number,
      default: 10,
    },
    notes: {
      type: String,
      default: '',
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    updatedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
  },
  {
    timestamps: true,
  }
);

// Indexes for ultra-fast queries and compass editing
subscriptionSchema.index({ businessId: 1, isActive: 1 });
subscriptionSchema.index({ userId: 1, isActive: 1 });
subscriptionSchema.index({ staffId: 1, isActive: 1 });
subscriptionSchema.index({ userEmail: 1, isActive: 1 });
subscriptionSchema.index({ targetType: 1, isActive: 1 });

const Subscription = mongoose.model('Subscription', subscriptionSchema);

module.exports = Subscription;
