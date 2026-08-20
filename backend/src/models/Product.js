const mongoose = require('mongoose');

const variantSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Variant name is required'],
      trim: true,
    },
    price: {
      type: Number,
      required: [true, 'Variant price is required'],
      min: [0, 'Variant price cannot be negative'],
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
    salePrice: {
      type: Number,
      default: 0,
      min: 0,
    },
    stock: {
      type: Number,
      default: -1,
    },
  },
  { _id: false }
);

const productSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    productId: {
      type: String,
      trim: true,
      index: true,
    },
    name: {
      type: String,
      required: [true, 'Product name is required'],
      trim: true,
      index: true,
    },
    description: {
      type: String,
      default: '',
      trim: true,
    },
    category: {
      type: String,
      required: [true, 'Category is required'],
      trim: true,
      index: true,
    },
    price: {
      type: Number,
      required: [true, 'Price is required'],
      min: [0, 'Price must be greater than or equal to 0'],
    },
    salePrice: {
      type: Number,
      default: 0,
      min: [0, 'Sale price cannot be negative'],
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
    image: {
      type: String,
      default: '',
    },
    images: {
      type: [String],
      default: [],
    },
    foodType: {
      type: String,
      enum: ['veg', 'non_veg', 'egg', 'beverage'],
      default: 'veg',
      index: true,
    },
    variants: {
      type: [variantSchema],
      default: [],
    },
    isAvailable: {
      type: Boolean,
      default: true,
      index: true,
    },
    stock: {
      type: Number,
      default: 50, // -1 represents unlimited
    },
    trackInventory: {
      type: Boolean,
      default: true,
    },
    sku: {
      type: String,
      default: '',
      trim: true,
    },
    taxPercentage: {
      type: Number,
      default: 5,
    },
  },
  {
    timestamps: true,
    toJSON: {
      transform(doc, ret) {
        ret.id = ret._id ? ret._id.toString() : ret.id;
        if (!ret.productId) {
          ret.productId = ret.id;
        }
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

productSchema.index({ businessId: 1, productId: 1 });
productSchema.index({ businessId: 1, category: 1 });
productSchema.index({ businessId: 1, isAvailable: 1, category: 1 });
productSchema.index({ businessId: 1, sku: 1 });
productSchema.index({ businessId: 1, createdAt: -1 });
productSchema.index({ businessId: 1, name: 'text', description: 'text' });

const Product = mongoose.model('Product', productSchema);

module.exports = Product;

