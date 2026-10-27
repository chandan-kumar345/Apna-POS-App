const mongoose = require('mongoose');
const tenantIsolationPlugin = require('../plugins/tenantIsolationPlugin');

const autoCampaignSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    trigger: {
      type: String,
      enum: [
        'birthday',
        'new_customer',
        'inactive_x_days',
        'post_purchase',
        'loyalty_points',
        'custom_date',
      ],
      required: true,
      index: true,
    },
    conditions: {
      customerType: { type: String, default: 'All Customers' },
      orderCountCondition: { type: String, default: 'greater_than' },
      orderCountValue: { type: Number, default: 0 },
      lastOrderCondition: { type: String, default: 'more_than' },
      lastOrderDays: { type: Number, default: 30 },
      customerGroup: { type: String, default: 'VIP Customers' },
      sendOnlyOnce: { type: Boolean, default: true },
      extraRules: [{ type: mongoose.Schema.Types.Mixed }],
    },
    channel: {
      channelType: { type: String, default: 'business_whatsapp' },
      name: { type: String, default: 'My Business WhatsApp' },
      phoneNumber: { type: String, default: '' },
    },
    template: {
      templateId: { type: String, default: '' },
      name: { type: String, required: true },
      category: { type: String, default: 'MARKETING' },
      language: { type: String, default: 'en' },
      body: { type: String, default: '' },
    },
    sendTiming: {
      type: String,
      default: '10:00 AM',
    },
    isActive: {
      type: Boolean,
      default: true,
      index: true,
    },
    stats: {
      triggeredCount: { type: Number, default: 0 },
      messagesSent: { type: Number, default: 0 },
      delivered: { type: Number, default: 0 },
      failed: { type: Number, default: 0 },
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

autoCampaignSchema.index({ businessId: 1, trigger: 1 });
autoCampaignSchema.index({ businessId: 1, isActive: 1 });

autoCampaignSchema.plugin(tenantIsolationPlugin);

const AutoCampaign = mongoose.model('AutoCampaign', autoCampaignSchema);

module.exports = AutoCampaign;
