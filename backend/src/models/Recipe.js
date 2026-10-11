const mongoose = require('mongoose');
const tenantIsolationPlugin = require('../plugins/tenantIsolationPlugin');

const recipeIngredientSchema = new mongoose.Schema(
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
    // Input quantity as entered by the chef/owner (e.g., 200)
    quantity: {
      type: Number,
      required: true,
      min: [0.0001, 'Quantity must be greater than zero'],
    },
    // Input unit (e.g., 'g', 'kg', 'ml', 'L', 'pcs')
    unit: {
      type: String,
      required: true,
      trim: true,
    },
    // Standardized quantity in material's canonical base unit ('g', 'ml', 'pcs')
    quantityBaseUnits: {
      type: Number,
      required: true,
      min: [0.0001, 'Base unit quantity must be greater than zero'],
    },
    // Preparation loss percentage (e.g. 5% peeling, trimming, cooking loss)
    preparationLossPercent: {
      type: Number,
      default: 0,
      min: 0,
      max: 100,
    },
    // Final effective consumption quantity in base units: quantityBaseUnits * (1 + loss% / 100)
    effectiveQuantityBaseUnits: {
      type: Number,
      required: true,
      min: [0.0001, 'Effective base quantity must be greater than zero'],
    },
    // Cost per base unit at recipe calculation time
    unitCost: {
      type: Number,
      default: 0,
      min: 0,
    },
    // Total cost for this ingredient: effectiveQuantityBaseUnits * unitCost
    totalCost: {
      type: Number,
      default: 0,
      min: 0,
    },
  },
  { _id: false }
);

const recipeSchema = new mongoose.Schema(
  {
    businessId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Business',
      required: true,
      index: true,
    },
    productId: {
      type: mongoose.Schema.Types.Mixed,
      required: [true, 'Product ID is required'],
      index: true,
    },
    productName: {
      type: String,
      required: [true, 'Product name is required'],
      trim: true,
      index: true,
    },
    recipeName: {
      type: String,
      trim: true,
    },
    variantId: {
      type: String,
      default: '',
      trim: true,
    },
    variantName: {
      type: String,
      default: '',
      trim: true,
    },
    servingSize: {
      type: Number,
      default: 1,
      min: [0.1, 'Serving size must be greater than 0'],
    },
    version: {
      type: String,
      default: 'v1.0',
      trim: true,
    },
    ingredients: {
      type: [recipeIngredientSchema],
      default: [],
      validate: [
        (val) => Array.isArray(val) && val.length > 0,
        'A recipe must have at least one ingredient',
      ],
    },
    // Total raw material cost per recipe batch / serving
    totalFoodCost: {
      type: Number,
      default: 0,
      min: 0,
    },
    // Menu selling price (from POS product)
    sellingPrice: {
      type: Number,
      default: 0,
      min: 0,
    },
    // Food cost percentage: (totalFoodCost / sellingPrice) * 100
    foodCostPercentage: {
      type: Number,
      default: 0,
      min: 0,
    },
    isActive: {
      type: Boolean,
      default: true,
      index: true,
    },
    instructions: {
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

recipeSchema.index({ businessId: 1, productId: 1, variantId: 1 });
recipeSchema.index({ businessId: 1, isActive: 1 });

recipeSchema.plugin(tenantIsolationPlugin);

const Recipe = mongoose.model('Recipe', recipeSchema);

module.exports = Recipe;
