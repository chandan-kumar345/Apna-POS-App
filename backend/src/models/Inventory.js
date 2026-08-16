const mongoose = require('mongoose');

const inventorySchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    itemName: {
      type: String,
      required: [true, 'Item name is required'],
      trim: true,
    },
    category: {
      type: String,
      default: 'General',
      trim: true,
    },
    quantity: {
      type: Number,
      default: 0,
      min: 0,
    },
    unit: {
      type: String,
      default: 'kg',
      trim: true,
    },
    minThreshold: {
      type: Number,
      default: 5,
      min: 0,
    },
    costPerUnit: {
      type: Number,
      default: 0,
      min: 0,
    },
    supplier: {
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

inventorySchema.index({ businessId: 1, itemName: 1 });

const Inventory = mongoose.model('Inventory', inventorySchema);

module.exports = Inventory;
