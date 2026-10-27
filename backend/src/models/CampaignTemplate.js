const mongoose = require('mongoose');

const campaignTemplateSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      default: null, // null = Global system-wide template available to all tenants
      index: true,
    },
    templateId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    subtitle: {
      type: String,
      default: '',
    },
    category: {
      type: String,
      enum: [
        'Promotional',
        'Discount',
        'BOGO',
        'New Menu',
        'Free Gift',
        'Festival',
        'Re-engagement',
        'AI',
        'Utility',
      ],
      default: 'Promotional',
      index: true,
    },
    channel: {
      type: String,
      enum: ['whatsapp', 'sms', 'email'],
      default: 'whatsapp',
      index: true,
    },
    metaStatus: {
      type: String,
      enum: ['APPROVED', 'PENDING', 'REJECTED', 'DRAFT'],
      default: 'APPROVED',
      index: true,
    },
    metaTemplateName: {
      type: String,
      required: true,
      trim: true,
    },
    metaCategory: {
      type: String,
      enum: ['MARKETING', 'UTILITY', 'AUTHENTICATION'],
      default: 'MARKETING',
    },
    language: {
      type: String,
      default: 'en_US',
    },
    headerType: {
      type: String,
      enum: ['IMAGE', 'TEXT', 'VIDEO', 'DOCUMENT', 'NONE'],
      default: 'IMAGE',
    },
    headerImageUrl: {
      type: String,
      default: '',
    },
    body: {
      type: String,
      required: true,
    },
    footerText: {
      type: String,
      default: '',
    },
    buttons: [
      {
        type: { type: String, enum: ['QUICK_REPLY', 'URL', 'PHONE_NUMBER'], default: 'URL' },
        text: { type: String, default: 'Order Now' },
        url: { type: String, default: '' },
        phoneNumber: { type: String, default: '' },
      },
    ],
    sampleParameters: [{ type: String }],
    iconCode: {
      type: String,
      default: 'tag',
    },
    tagLabel: {
      type: String,
      default: 'Promotional',
    },
    tagColor: {
      type: String,
      default: '#10B981',
    },
    isMetaVerified: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
  }
);

campaignTemplateSchema.index({ businessId: 1, category: 1, channel: 1 });
campaignTemplateSchema.index({ businessId: 1, metaStatus: 1 });

const CampaignTemplate = mongoose.model('CampaignTemplate', campaignTemplateSchema);
module.exports = CampaignTemplate;
