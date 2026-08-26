const mongoose = require('mongoose');

const rewardMilestoneSchema = new mongoose.Schema(
  {
    id: { type: String, required: true },
    label: { type: String, required: true },
    value: { type: Number, required: true },
    iconName: { type: String, default: 'cookie' },
    rewardText: { type: String, default: '' },
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
    earningRule: { type: String, required: true },
    rewardCurrency: { type: String, default: 'Cookie' },
    milestones: [rewardMilestoneSchema],
    cashbackDetails: cashbackDetailsSchema,
    gradientColors: {
      type: [String],
      default: ['#580B3B', '#8E1449'],
    },
    isActive: { type: Boolean, default: true },
    orderIndex: { type: Number, default: 0 },
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
