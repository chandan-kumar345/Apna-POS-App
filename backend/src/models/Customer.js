const mongoose = require('mongoose');

const customerSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    name: {
      type: String,
      default: '',
      trim: true,
    },
    phone: {
      type: String,
      required: [true, 'Customer phone number is required'],
      trim: true,
      index: true,
    },
    email: {
      type: String,
      default: '',
      trim: true,
      lowercase: true,
    },
    address: {
      type: String,
      default: '',
      trim: true,
    },
    gender: {
      type: String,
      default: '',
      trim: true,
    },
    birthday: {
      type: Date,
      default: null,
    },
    anniversary: {
      type: Date,
      default: null,
    },
    bonusPointsAwarded: {
      type: Boolean,
      default: false,
    },
    totalOrders: {
      type: Number,
      default: 0,
    },
    totalSpent: {
      type: Number,
      default: 0,
    },
    firstVisit: {
      type: Date,
      default: Date.now,
      index: true,
    },
    lastVisit: {
      type: Date,
      default: Date.now,
      index: true,
    },
    stage: {
      type: String,
      enum: ['New Lead', 'Prospect', 'Deal', 'Won', 'Lost', 'Lead'],
      default: 'New Lead',
      index: true,
    },
    status: {
      type: String,
      default: 'New Lead',
      trim: true,
    },
    source: {
      type: String,
      default: 'Dine In',
      trim: true,
    },
    tags: {
      type: [String],
      default: ['New Lead'],
    },
    isLiked: {
      type: Boolean,
      default: false,
    },
    isStarred: {
      type: Boolean,
      default: false,
    },
    followupDate: {
      type: Date,
      default: null,
    },
    followupNotes: {
      type: String,
      default: '',
      trim: true,
    },
    followupStatus: {
      type: String,
      enum: ['none', 'pending', 'completed', 'cancelled'],
      default: 'none',
    },
    notes: {
      type: String,
      default: '',
      trim: true,
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

customerSchema.index({ businessId: 1, phone: 1 }, { unique: true });
customerSchema.index({ businessId: 1, firstVisit: 1 });
customerSchema.index({ businessId: 1, lastVisit: -1 });

const Customer = mongoose.model('Customer', customerSchema);

module.exports = Customer;
