const mongoose = require('mongoose');
const tenantIsolationPlugin = require('../plugins/tenantIsolationPlugin');

const recipientSchema = new mongoose.Schema(
  {
    name: { type: String, default: 'Customer' },
    phone: { type: String, required: true },
    customerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Customer', default: null },
    status: {
      type: String,
      enum: ['pending', 'sent', 'delivered', 'read', 'failed'],
      default: 'pending',
    },
    messageId: { type: String, default: null },
    sentAt: { type: Date, default: null },
    deliveredAt: { type: Date, default: null },
    error: { type: String, default: null },
  },
  { _id: true }
);

const campaignSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    campaignId: {
      type: String,
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    type: {
      type: String,
      enum: ['marketing', 'utility'],
      default: 'marketing',
      index: true,
    },
    status: {
      type: String,
      enum: ['draft', 'scheduled', 'running', 'paused', 'completed', 'failed', 'cancelled'],
      default: 'draft',
      index: true,
    },
    audience: {
      source: {
        type: String,
        enum: ['all', 'group', 'segment', 'upload', 'manual'],
        default: 'group',
      },
      groupName: { type: String, default: 'All Customers' },
      segmentCriteria: { type: mongoose.Schema.Types.Mixed, default: {} },
      recipientCount: { type: Number, default: 0 },
      recipients: [recipientSchema],
    },
    channel: {
      channelType: {
        type: String,
        enum: ['business_whatsapp', 'softcode_shared'],
        default: 'business_whatsapp',
      },
      name: { type: String, default: 'My Business WhatsApp' },
      phoneNumber: { type: String, default: '' },
      phoneNumberId: { type: String, default: '' },
    },
    template: {
      templateId: { type: String, default: '' },
      name: { type: String, required: true },
      category: { type: String, default: 'MARKETING' },
      language: { type: String, default: 'en' },
      body: { type: String, default: '' },
      headerText: { type: String, default: '' },
      footerText: { type: String, default: '' },
      buttons: [{ type: String }],
      parameters: [{ type: String }],
    },
    schedule: {
      mode: {
        type: String,
        enum: ['now', 'later', 'recurring'],
        default: 'now',
      },
      scheduledAt: { type: Date, default: Date.now },
      estimatedSendingTime: { type: String, default: '' },
      recurringCron: { type: String, default: '' },
    },
    cost: {
      messages: { type: Number, default: 0 },
      ratePerMessage: { type: Number, default: 0.90 },
      subtotal: { type: Number, default: 0 },
      gst: { type: Number, default: 0 },
      totalAmount: { type: Number, default: 0 },
      spentSoFar: { type: Number, default: 0 },
      remaining: { type: Number, default: 0 },
    },
    stats: {
      totalRecipients: { type: Number, default: 0 },
      messagesSent: { type: Number, default: 0 },
      delivered: { type: Number, default: 0 },
      failed: { type: Number, default: 0 },
      read: { type: Number, default: 0 },
      deliveryRate: { type: Number, default: 0.0 }, // e.g. 92.4
      completionRate: { type: Number, default: 0.0 }, // e.g. 87.0
    },
    deliveryTimeline: [
      {
        time: { type: String, required: true },
        sent: { type: Number, default: 0 },
        delivered: { type: Number, default: 0 },
        failed: { type: Number, default: 0 },
      },
    ],
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

campaignSchema.index({ businessId: 1, status: 1 });
campaignSchema.index({ businessId: 1, createdAt: -1 });
campaignSchema.index({ businessId: 1, type: 1 });

campaignSchema.plugin(tenantIsolationPlugin);

const Campaign = mongoose.model('Campaign', campaignSchema);

module.exports = Campaign;
