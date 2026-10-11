const mongoose = require('mongoose');
const tenantIsolationPlugin = require('../plugins/tenantIsolationPlugin');

const stockCountItemSchema = new mongoose.Schema(
  {
    materialId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'RawMaterial',
      required: true,
    },
    materialName: {
      type: String,
      required: true,
      trim: true,
    },
    baseUnit: {
      type: String,
      required: true,
      trim: true,
    },
    expectedBaseUnits: {
      type: Number,
      required: true,
    },
    actualBaseUnits: {
      type: Number,
      required: true,
      min: 0,
    },
    // Signed variance: actualBaseUnits - expectedBaseUnits
    varianceBaseUnits: {
      type: Number,
      required: true,
    },
    unitCost: {
      type: Number,
      default: 0,
    },
    // varianceBaseUnits * unitCost
    varianceValue: {
      type: Number,
      default: 0,
    },
    reason: {
      type: String,
      default: 'Physical stock reconciliation',
      trim: true,
    },
  },
  { _id: false }
);

const stockCountSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    countNumber: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    countDate: {
      type: Date,
      default: Date.now,
      index: true,
    },
    status: {
      type: String,
      enum: ['draft', 'approved'],
      default: 'approved',
    },
    items: {
      type: [stockCountItemSchema],
      default: [],
      validate: [
        (val) => Array.isArray(val) && val.length > 0,
        'Stock count must contain at least one item',
      ],
    },
    totalVarianceValue: {
      type: Number,
      default: 0,
    },
    conductedBy: {
      type: String,
      default: 'Manager',
      trim: true,
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

stockCountSchema.index({ businessId: 1, countNumber: 1 });
stockCountSchema.index({ businessId: 1, countDate: -1 });

stockCountSchema.plugin(tenantIsolationPlugin);

const StockCount = mongoose.model('StockCount', stockCountSchema);

module.exports = StockCount;
