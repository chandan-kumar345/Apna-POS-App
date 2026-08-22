const mongoose = require('mongoose');

const extraSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: [true, 'Extra/benefit name is required'],
      trim: true,
    },
    code: {
      type: String,
      default: '',
      trim: true,
      uppercase: true,
      index: true,
    },
    description: {
      type: String,
      default: '',
      trim: true,
    },
    type: {
      type: String,
      enum: ['coupon', 'discount', 'addon', 'charge', 'tip'],
      default: 'coupon',
      index: true,
    },
    discountType: {
      type: String,
      enum: ['percent', 'flat'],
      default: 'percent',
    },
    value: {
      type: Number,
      default: 0,
      min: 0,
    },
    minOrderAmount: {
      type: Number,
      default: 0,
      min: 0,
    },
    maxDiscount: {
      type: Number,
      default: 0,
      min: 0,
    },
    price: {
      type: Number,
      default: 0,
      min: 0,
    },
    quantity: {
      type: Number,
      default: 1,
      min: 1,
    },
    isAvailable: {
      type: Boolean,
      default: true,
      index: true,
    },
    status: {
      type: String,
      enum: ['active', 'inactive'],
      default: 'active',
      index: true,
    },
    productId: {
      type: String,
      default: '',
      trim: true,
    },
    variantId: {
      type: String,
      default: '',
      trim: true,
    },
    categoryId: {
      type: String,
      default: '',
      trim: true,
    },
  },
  {
    timestamps: true,
    toJSON: {
      transform(doc, ret) {
        ret.id = ret._id ? ret._id.toString() : ret.id;
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

extraSchema.index({ businessId: 1, code: 1 });
extraSchema.index({ businessId: 1, type: 1, status: 1 });

const Extra = mongoose.model('Extra', extraSchema);

module.exports = Extra;
