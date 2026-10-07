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
    userCreatedAt: {
      type: Date,
      default: Date.now,
      index: true,
    },
    plan: {
      type: String,
      enum: ['starter', 'standard', 'growth', 'pro', 'enterprise'],
      default: 'starter',
    },
    billingCycle: {
      type: String,
      enum: ['monthly', 'annual', 'lifetime', 'custom'],
      default: 'monthly',
    },
    amount: {
      type: Number,
      default: 0,
    },
    currency: {
      type: String,
      default: 'INR',
    },
    isActive: {
      type: Boolean,
      default: false,
      index: true,
    },
    isSubscriptionActive: {
      type: Boolean,
      default: false,
      index: true,
    },
    isSubscribed: {
      type: Boolean,
      default: false,
      index: true,
    },
    status: {
      type: String,
      enum: ['active', 'inactive', 'expired', 'trial', 'cancelled', 'pending'],
      default: 'inactive',
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
      default: null,
    },
    expiresAt: {
      type: Date,
      index: true,
      default: null,
    },
    features: {
      type: [String],
      default: ['pos', 'tables', 'orders', 'reports', 'inventory', 'loyalty', 'campaign', 'staff', 'crm'],
    },
    hasLoyalty: {
      type: Boolean,
      default: false,
    },
    hasCampaign: {
      type: Boolean,
      default: false,
    },
    hasInventory: {
      type: Boolean,
      default: false,
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

// Keep isSubscriptionActive, isActive, isSubscribed, and status synchronized across all operations
subscriptionSchema.pre('save', function (next) {
  if (this.isModified('isSubscriptionActive')) {
    const val = Boolean(this.isSubscriptionActive);
    this.isActive = val;
    this.isSubscribed = val;
    if (val && this.status !== 'active') this.status = 'active';
    if (!val && this.status === 'active') this.status = 'inactive';
  } else if (this.isModified('isActive')) {
    const val = Boolean(this.isActive);
    this.isSubscriptionActive = val;
    this.isSubscribed = val;
    if (val && this.status !== 'active') this.status = 'active';
    if (!val && this.status === 'active') this.status = 'inactive';
  } else if (this.isModified('isSubscribed')) {
    const val = Boolean(this.isSubscribed);
    this.isActive = val;
    this.isSubscriptionActive = val;
    if (val && this.status !== 'active') this.status = 'active';
    if (!val && this.status === 'active') this.status = 'inactive';
  } else if (this.isModified('status')) {
    const val = this.status === 'active';
    this.isActive = val;
    this.isSubscriptionActive = val;
    this.isSubscribed = val;
  }
  next();
});

subscriptionSchema.pre('findOneAndUpdate', function (next) {
  const update = this.getUpdate();
  if (update) {
    const set = update.$set || update;
    if (set.isSubscriptionActive !== undefined) {
      const val = Boolean(set.isSubscriptionActive);
      set.isActive = val;
      set.isSubscribed = val;
      set.status = val ? 'active' : 'inactive';
    } else if (set.isActive !== undefined) {
      const val = Boolean(set.isActive);
      set.isSubscriptionActive = val;
      set.isSubscribed = val;
      set.status = val ? 'active' : 'inactive';
    } else if (set.isSubscribed !== undefined) {
      const val = Boolean(set.isSubscribed);
      set.isSubscriptionActive = val;
      set.isActive = val;
      set.status = val ? 'active' : 'inactive';
    } else if (set.status !== undefined) {
      const val = set.status === 'active';
      set.isActive = val;
      set.isSubscriptionActive = val;
      set.isSubscribed = val;
    }
  }
  next();
});

// Indexes for ultra-fast queries and compass editing
subscriptionSchema.index({ businessId: 1, isSubscriptionActive: 1 });
subscriptionSchema.index({ businessId: 1, isActive: 1 });
subscriptionSchema.index({ userId: 1, isSubscriptionActive: 1 });
subscriptionSchema.index({ userId: 1, isActive: 1 });
subscriptionSchema.index({ staffId: 1, isActive: 1 });
subscriptionSchema.index({ userEmail: 1, isSubscriptionActive: 1 });
subscriptionSchema.index({ userEmail: 1, isActive: 1 });
subscriptionSchema.index({ targetType: 1, isActive: 1 });

const Subscription = mongoose.model('Subscription', subscriptionSchema, 'premiumsubscriptions');
const PremiumSubscription = Subscription;

module.exports = Subscription;
module.exports.Subscription = Subscription;
module.exports.PremiumSubscription = PremiumSubscription;
