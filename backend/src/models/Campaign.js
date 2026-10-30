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
      enum: ['marketing', 'utility', 'promotional'],
      default: 'marketing',
      index: true,
    },
    status: {
      type: String,
      enum: ['draft', 'scheduled', 'processing', 'running', 'paused', 'completed', 'sent', 'failed', 'cancelled'],
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
      headerType: {
        type: String,
        enum: ['IMAGE', 'TEXT', 'VIDEO', 'DOCUMENT', 'NONE'],
        default: 'IMAGE',
      },
      headerMediaUrl: { type: String, default: '' },
      headerText: { type: String, default: '' },
      footerText: { type: String, default: '' },
      metaStatus: {
        type: String,
        enum: ['APPROVED', 'PENDING', 'REJECTED', 'DRAFT'],
        default: 'PENDING',
      },
      displayName: { type: String, default: '' },
      interactiveType: { type: String, default: 'CTA_URL' },
      buttonText: { type: String, default: 'Offer details' },
      buttonUrl: { type: String, default: '' },
      buttons: [{ type: String }],
      parameters: [{ type: String }],
    },
    schedule: {
      mode: {
        type: String,
        enum: ['now', 'later', 'recurring'],
        default: 'now',
      },
      scheduledAt: { type: Date, default: null },
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
    rewardDetails: {
      rewardType: {
        type: String,
        enum: ['flat_discount', 'flat_cash', 'percent_discount', 'percentage', 'free_gift', 'bogo', 'cashback'],
        default: 'flat_discount',
      },
      discountAmount: { type: Number, default: 0 },
      discountScope: {
        type: String,
        enum: ['whole_bill', 'chosen_products'],
        default: 'whole_bill',
      },
      chosenProducts: [
        {
          productId: { type: String, default: '' },
          productName: { type: String, default: '' },
          price: { type: Number, default: 0 },
        },
      ],
      freeGiftProductId: { type: String, default: '' },
      freeGiftProductName: { type: String, default: '' },
      freeGiftProductPrice: { type: Number, default: 0 },
      hasMinSpend: { type: Boolean, default: false },
      minSpendAmount: { type: Number, default: 0 },
      maxCashbackCap: { type: Number, default: 0 },
      comboOfferTitle: { type: String, default: '' },
      campaignTitle: { type: String, default: '' },
      description: { type: String, default: '' },
      bannerImageUrl: { type: String, default: '' },
      logoUrl: { type: String, default: '' },
      themeColor: { type: String, default: '#E91E63' },
      textColor: { type: String, default: '#FFFFFF' },
      restaurantName: { type: String, default: '' },
      termsAndConditions: [{ type: String }],
    },
    couponSettings: {
      useCustomCouponCode: { type: Boolean, default: false },
      customCouponCode: { type: String, default: '', trim: true, uppercase: true },
      couponCode: { type: String, default: '', trim: true, uppercase: true },
      hasSendSchedule: { type: Boolean, default: false },
      sendDate: { type: Date, default: null },
      sendTime: { type: String, default: '' },
      scheduledAt: { type: Date, default: null, index: true },
      hasExpiryDate: { type: Boolean, default: true },
      expiryDate: { type: Date, default: null, index: true },
      redemptionPerCustomer: {
        type: String,
        enum: ['only_once', 'multiple_times'],
        default: 'only_once',
      },
      maxRedemptionsPerCustomer: { type: Number, default: 1, min: 1 },
      displayCouponInProfile: { type: Boolean, default: false },
    },
    couponId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Coupon',
      default: null,
      index: true,
    },
    executionLogs: [
      {
        timestamp: { type: Date, default: Date.now },
        status: { type: String, default: '' },
        message: { type: String, default: '' },
        executedBy: { type: String, default: 'system' },
      },
    ],
    orderTypes: {
      type: [String],
      enum: ['delivery', 'takeaway', 'dine_in'],
      default: ['delivery', 'takeaway', 'dine_in'],
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
campaignSchema.index({ status: 1, 'couponSettings.scheduledAt': 1 });
campaignSchema.index({ businessId: 1, 'couponSettings.couponCode': 1 });

campaignSchema.plugin(tenantIsolationPlugin);

const Campaign = mongoose.model('Campaign', campaignSchema);

module.exports = Campaign;
