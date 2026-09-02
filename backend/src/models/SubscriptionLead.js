const mongoose = require('mongoose');

const subscriptionLeadSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      index: true,
      default: null,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      index: true,
      default: null,
    },
    restaurantName: {
      type: String,
      required: true,
      trim: true,
    },
    contactPerson: {
      type: String,
      required: true,
      trim: true,
    },
    phone: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    email: {
      type: String,
      trim: true,
      lowercase: true,
      default: '',
    },
    selectedPlan: {
      type: String,
      required: true,
      trim: true,
      default: 'Growth / Pro Plan',
    },
    billingCycle: {
      type: String,
      enum: ['monthly', 'annual', 'lifetime', 'custom'],
      default: 'annual',
    },
    price: {
      type: Number,
      default: 0,
    },
    sourceFeature: {
      type: String,
      enum: ['subscription_screen', 'inventory', 'loyalty', 'campaign', 'pos', 'dashboard', 'settings', 'other'],
      default: 'subscription_screen',
      index: true,
    },
    interestedFeatures: {
      type: [String],
      default: [],
    },
    notes: {
      type: String,
      trim: true,
      default: '',
    },
    status: {
      type: String,
      enum: ['new', 'contacted', 'demo_scheduled', 'converted', 'cancelled'],
      default: 'new',
      index: true,
    },
    emailNotificationSent: {
      type: Boolean,
      default: false,
    },
    emailNotificationRecipient: {
      type: String,
      default: 'sooftcode@gmail.com',
    },
    emailNotificationError: {
      type: String,
      default: null,
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
  },
  {
    timestamps: true,
  }
);

subscriptionLeadSchema.index({ businessId: 1, createdAt: -1 });
subscriptionLeadSchema.index({ createdAt: -1 });

const SubscriptionLead = mongoose.model('SubscriptionLead', subscriptionLeadSchema);

module.exports = {
  SubscriptionLead,
};
