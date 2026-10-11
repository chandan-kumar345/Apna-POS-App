const mongoose = require('mongoose');
const tenantIsolationPlugin = require('../plugins/tenantIsolationPlugin');

const rawMaterialSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    sku: {
      type: String,
      required: [true, 'SKU is required'],
      trim: true,
      uppercase: true,
    },
    name: {
      type: String,
      required: [true, 'Material name is required'],
      trim: true,
      index: true,
    },
    category: {
      type: String,
      default: 'General',
      trim: true,
      index: true,
    },
    // Canonical storage unit: 'g' (mass), 'ml' (volume), or 'pcs' (count)
    baseUnit: {
      type: String,
      enum: ['g', 'ml', 'pcs'],
      default: 'g',
      required: true,
    },
    // Default unit purchased from supplier: 'kg', 'L', 'pcs', 'box', 'bag', 'pack', etc.
    purchaseUnit: {
      type: String,
      default: 'kg',
      trim: true,
    },
    // Conversion rate: how many baseUnits in 1 purchaseUnit (e.g., 1000 for kg->g, 1000 for L->ml)
    conversionFactor: {
      type: Number,
      default: 1000,
      min: [0.00001, 'Conversion factor must be greater than zero'],
    },
    // Minimum stock alert threshold in baseUnits
    minimumStock: {
      type: Number,
      default: 0,
      min: 0,
    },
    // Current stock on hand in baseUnits
    currentStock: {
      type: Number,
      default: 0,
    },
    // Weighted average purchase cost per purchaseUnit (in INR)
    averageUnitCost: {
      type: Number,
      default: 0,
      min: 0,
    },
    // Calculated cost per baseUnit (averageUnitCost / conversionFactor)
    costPerBaseUnit: {
      type: Number,
      default: 0,
      min: 0,
    },
    preferredSupplier: {
      type: String,
      default: '',
      trim: true,
    },
    inventoryMode: {
      type: String,
      enum: ['automatic', 'manual'],
      default: 'automatic',
    },
    isActive: {
      type: Boolean,
      default: true,
      index: true,
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
        ret.id = ret._id ? ret._id.toString() : ret.id;
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

rawMaterialSchema.index({ businessId: 1, sku: 1 }, { unique: true });
rawMaterialSchema.index({ businessId: 1, name: 1 });
rawMaterialSchema.index({ businessId: 1, category: 1 });
rawMaterialSchema.index({ businessId: 1, isActive: 1 });

rawMaterialSchema.plugin(tenantIsolationPlugin);

const RawMaterial = mongoose.model('RawMaterial', rawMaterialSchema);

module.exports = RawMaterial;
