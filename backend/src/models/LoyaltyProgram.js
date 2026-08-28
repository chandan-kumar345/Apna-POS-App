const mongoose = require('mongoose');

const rewardMilestoneSchema = new mongoose.Schema(
  {
    id: { type: String, required: true },
    label: { type: String, default: '' },
    value: { type: Number, default: 0 },
    visitCount: { type: Number, default: 0 },
    iconName: { type: String, default: 'cookie' },
    rewardText: { type: String, default: '' },
    rewardType: { type: String, default: 'Redeem cash discount' },
    rewardValue: { type: Number, default: 100 },
    minimumPurchase: { type: Number, default: 100 },
    freeItemName: { type: String, default: '' },
    discountScope: { type: String, default: 'Whole bill' },
    minSpendRedemptionEnabled: { type: Boolean, default: false },
    applicableProductIds: [{ type: String }],
  },
  { _id: false }
);

const cashbackDetailsSchema = new mongoose.Schema(
  {
    percentage: { type: Number, default: 10 },
    minSpend: { type: Number, default: 500 },
    headline: { type: String, default: '10% Cashback on sales' },
    subtext: { type: String, default: 'On min. spend of ₹500' },
    termsNote: {
      type: String,
      default: 'Cashback will be credited when another coupon or offer is already applied.',
    },
    billRewardText: { type: String, default: 'Rs 500+ bill earns 10% cashback' },
    slabTitle: { type: String, default: 'STARTER REWARD' },
    goal: { type: String, default: 'On min purchase of Rs 500' },
    reward: { type: String, default: '🎁 Earn 10% cashback' },
    progressPercent: { type: Number, default: 65 },
  },
  { _id: false }
);

const singleProgramSchema = new mongoose.Schema(
  {
    id: { type: String, required: true },
    type: {
      type: String,
      enum: ['visit_made', 'amount_spent', 'cashback'],
      required: true,
    },
    title: { type: String, required: true },
    description: { type: String, default: 'Get rewarded on every purchase' },
    earningRule: { type: String, default: '' },
    rewardCurrency: { type: String, default: 'Cookie' },
    milestones: [rewardMilestoneSchema],
    cashbackDetails: cashbackDetailsSchema,
    gradientColors: {
      type: [String],
      default: ['#4A082F', '#8E1449'],
    },
    isActive: { type: Boolean, default: true },
    orderIndex: { type: Number, default: 0 },
  },
  { _id: false }
);

const visitRewardConfigSchema = new mongoose.Schema(
  {
    programName: { type: String, default: 'THE ROYAL GARDENIA' },
    slogan: { type: String, default: 'Get rewarded on every purchase' },
    orderType: { type: String, default: 'Dine-In' },
    bannerImageUrl: { type: String, default: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=800' },
    logoUrl: { type: String, default: '' },
    bgGradientStart: { type: String, default: '#4A082F' },
    bgGradientEnd: { type: String, default: '#8E1449' },
    rewardColorStart: { type: String, default: '#4A082F' },
    rewardColorEnd: { type: String, default: '#8E1449' },
    pointsName: { type: String, default: 'Cookie' },
    pointsPerVisit: { type: Number, default: 10 },
    minimumPurchase: { type: Number, default: 100 },
    rewardStages: [rewardMilestoneSchema],
    termsNote: { type: String, default: 'Terms and conditions apply.\nMinimum purchase of ₹100 required.\n3 offers cannot be clubbed.' },
    minSpendConditionEnabled: { type: Boolean, default: false },
    minSpendCondition: { type: Number, default: 0 },
    pointEarningGapEnabled: { type: Boolean, default: false },
    pointEarningGap: { type: Number, default: 24 },
    maxCashbackLimitEnabled: { type: Boolean, default: false },
    maxCashbackLimit: { type: Number, default: 0 },
    bonusPointsEnabled: { type: Boolean, default: true },
    bonusPointsAmount: { type: Number, default: 100 },
    bonusRequiredFields: {
      type: [String],
      default: ['name', 'phone', 'gender', 'birthday', 'anniversary'],
    },
    isActive: { type: Boolean, default: true },
  },
  { _id: false }
);

const loyaltyProgramSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      unique: true,
      index: true,
    },
    companyName: { type: String, default: '' },
    companyLogo: { type: String, default: '' },
    visitConfig: { type: visitRewardConfigSchema, default: () => ({}) },
    programs: [singleProgramSchema],
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

const LoyaltyProgram = mongoose.model('LoyaltyProgram', loyaltyProgramSchema);

module.exports = LoyaltyProgram;
