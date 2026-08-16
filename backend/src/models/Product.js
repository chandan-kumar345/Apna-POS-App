const mongoose = require('mongoose');

const productSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
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
    image: {
      type: String,
      default: '',
    },
    foodType: {
      type: String,
      enum: ['veg', 'non_veg', 'egg'],
      default: 'veg',
      index: true,
    },
    isAvailable: {
      type: Boolean,
      default: true,
      index: true,
    },
    stock: {
      type: Number,
      default: -1, // -1 represents unlimited
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
        ret.id = ret._id;
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

productSchema.index({ businessId: 1, category: 1 });
productSchema.index({ businessId: 1, isAvailable: 1 });
productSchema.index({ businessId: 1, name: 'text', description: 'text' });

const Product = mongoose.model('Product', productSchema);

module.exports = Product;
