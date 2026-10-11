const mongoose = require('mongoose');
const tenantIsolationPlugin = require('../plugins/tenantIsolationPlugin');

const inventoryMovementSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    materialId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'RawMaterial',
      required: true,
      index: true,
    },
    materialName: {
      type: String,
      required: true,
      trim: true,
    },
    movementType: {
      type: String,
      enum: [
        'sale_consumption',
        'purchase_receipt',
        'stock_out',
        'opening_stock',
        'inventory_adjustment',
        'wastage',
        'return',
      ],
      required: true,
      index: true,
    },
    // Signed delta in base units (+ for additions/purchases/surplus, - for sales/wastage/deficits)
    quantityDeltaBaseUnits: {
      type: Number,
      required: true,
    },
    balanceBeforeBaseUnits: {
      type: Number,
      default: 0,
    },
    balanceAfterBaseUnits: {
      type: Number,
      required: true,
    },
    unitCost: {
      type: Number,
      default: 0,
      min: 0,
    },
    totalCost: {
      type: Number,
      default: 0,
    },
    sourceType: {
      type: String,
      enum: [
        'order',
        'purchase_receipt',
        'manual_adjustment',
        'stock_count',
        'manual_issue',
        'opening',
      ],
      default: 'manual_adjustment',
      index: true,
    },
    sourceId: {
      type: String,
      default: '',
      index: true,
    },
    idempotencyKey: {
      type: String,
      trim: true,
    },
    reason: {
      type: String,
      default: '',
      trim: true,
    },
    createdBy: {
      type: String,
      default: 'System',
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

inventoryMovementSchema.index({ businessId: 1, materialId: 1, createdAt: -1 });
inventoryMovementSchema.index({ businessId: 1, movementType: 1, createdAt: -1 });
inventoryMovementSchema.index({ businessId: 1, sourceId: 1 });
inventoryMovementSchema.index(
  { businessId: 1, idempotencyKey: 1 },
  { unique: true, partialFilterExpression: { idempotencyKey: { $type: 'string' } } }
);

inventoryMovementSchema.plugin(tenantIsolationPlugin);

const InventoryMovement = mongoose.model('InventoryMovement', inventoryMovementSchema);

module.exports = InventoryMovement;
