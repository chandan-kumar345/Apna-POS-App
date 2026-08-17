const mongoose = require('mongoose');

const cartItemSchema = new mongoose.Schema(
  {
    productId: {
      type: String,
      required: true,
      index: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    price: {
      type: Number,
      required: true,
      min: 0,
    },
    salePrice: {
      type: Number,
      default: null,
      min: 0,
    },
    effectivePrice: {
      type: Number,
      required: true,
      min: 0,
    },
    hasDiscount: {
      type: Boolean,
      default: false,
    },
    discountPercent: {
      type: Number,
      default: 0,
      min: 0,
      max: 100,
    },
    variantName: {
      type: String,
      default: '',
    },
    quantity: {
      type: Number,
      required: true,
      min: 1,
      default: 1,
    },
    foodType: {
      type: String,
      enum: ['veg', 'non_veg', 'egg', 'beverage'],
      default: 'veg',
    },
    imageUrl: {
      type: String,
      default: '',
    },
  },
  { _id: true }
);

const cartSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    tableNumber: {
      type: String,
      default: '',
      trim: true,
      index: true,
    },
    orderType: {
      type: String,
      enum: ['dineIn', 'takeaway', 'delivery'],
      default: 'dineIn',
      index: true,
    },
    items: [cartItemSchema],
    subtotal: {
      type: Number,
      default: 0,
      min: 0,
    },
    totalDiscount: {
      type: Number,
      default: 0,
      min: 0,
    },
    itemCount: {
      type: Number,
      default: 0,
      min: 0,
    },
    updatedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { timestamps: true }
);

// Compound index for instant active cart lookup per business, table, and order type
cartSchema.index({ businessId: 1, tableNumber: 1, orderType: 1 }, { unique: true });

// Auto-recalculate summary values before save
cartSchema.methods.recalculateTotals = function () {
  let sub = 0;
  let disc = 0;
  let count = 0;

  for (const item of this.items) {
    const itemSub = (item.effectivePrice != null && item.effectivePrice > 0 ? item.effectivePrice : item.price) * item.quantity;
    const origSub = item.price * item.quantity;
    sub += itemSub;
    if (item.hasDiscount && item.discountPercent > 0) {
      disc += Math.max(0, origSub - itemSub);
    }
    count += item.quantity;
  }

  this.subtotal = Math.round(sub * 100) / 100;
  this.totalDiscount = Math.round(disc * 100) / 100;
  this.itemCount = count;
  this.updatedAt = new Date();
};

module.exports = mongoose.model('Cart', cartSchema);
