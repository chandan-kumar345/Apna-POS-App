const Joi = require('joi');

const variantSchema = Joi.object({
  name: Joi.string().trim().required(),
  price: Joi.number().min(0).required(),
  hasDiscount: Joi.boolean().default(false),
  discountPercent: Joi.number().min(0).max(100).default(0),
  salePrice: Joi.number().min(0).default(0),
  stock: Joi.number().default(-1),
});

const createProductSchema = Joi.object({
  name: Joi.string().trim().min(1).max(150),
  title: Joi.string().trim().min(1).max(150),
  productId: Joi.string().trim().allow('', null),
  id: Joi.string().trim().allow('', null),
  description: Joi.string().trim().max(1000).allow('', null).default(''),
  category: Joi.string().trim().min(1).max(100).required().messages({
    'string.empty': 'Category is required',
    'any.required': 'Category is required',
  }),
  price: Joi.number().min(0).required().messages({
    'number.base': 'Price must be a valid number',
    'any.required': 'Price is required',
  }),
  salePrice: Joi.number().min(0).allow(null).default(0),
  hasDiscount: Joi.boolean().default(false),
  discount: Joi.number().min(0).max(100).allow(null),
  discountPercent: Joi.number().min(0).max(100).allow(null).default(0),
  image: Joi.string().trim().allow('', null).default(''),
  imageUrl: Joi.string().trim().allow('', null),
  images: Joi.array().items(Joi.string().trim().allow('')).default([]),
  foodType: Joi.string().valid('veg', 'non_veg', 'non-veg', 'egg', 'beverage', 'Veg', 'Non-Veg', 'Egg', 'Beverage').default('veg'),
  foodtype: Joi.string().valid('veg', 'non_veg', 'non-veg', 'egg', 'beverage', 'Veg', 'Non-Veg', 'Egg', 'Beverage'),
  itemType: Joi.string().allow('', null),
  variants: Joi.array().items(variantSchema).default([]),
  isAvailable: Joi.boolean().default(true),
  stock: Joi.number().allow(null).default(50),
  stockQuantity: Joi.number().allow(null),
  inventory: Joi.number().allow(null),
  trackInventory: Joi.boolean().default(true),
  sku: Joi.string().trim().allow('', null).default(''),
  gst: Joi.number().min(0).max(100).allow(null),
  gstPercent: Joi.number().min(0).max(100).allow(null),
  taxPercentage: Joi.number().min(0).max(100).allow(null).default(5),
}).or('name', 'title').messages({
  'object.missing': 'Product title is required',
});

const updateProductSchema = Joi.object({
  name: Joi.string().trim().min(1).max(150),
  title: Joi.string().trim().min(1).max(150),
  productId: Joi.string().trim().allow('', null),
  description: Joi.string().trim().max(1000).allow('', null),
  category: Joi.string().trim().min(1).max(100),
  price: Joi.number().min(0),
  salePrice: Joi.number().min(0).allow(null),
  hasDiscount: Joi.boolean(),
  discount: Joi.number().min(0).max(100).allow(null),
  discountPercent: Joi.number().min(0).max(100).allow(null),
  image: Joi.string().trim().allow('', null),
  imageUrl: Joi.string().trim().allow('', null),
  images: Joi.array().items(Joi.string().trim().allow('')),
  foodType: Joi.string().valid('veg', 'non_veg', 'non-veg', 'egg', 'beverage', 'Veg', 'Non-Veg', 'Egg', 'Beverage'),
  foodtype: Joi.string().valid('veg', 'non_veg', 'non-veg', 'egg', 'beverage', 'Veg', 'Non-Veg', 'Egg', 'Beverage'),
  itemType: Joi.string().allow('', null),
  variants: Joi.array().items(variantSchema),
  isAvailable: Joi.boolean(),
  stock: Joi.number().allow(null),
  stockQuantity: Joi.number().allow(null),
  inventory: Joi.number().allow(null),
  trackInventory: Joi.boolean(),
  sku: Joi.string().trim().allow('', null),
  gst: Joi.number().min(0).max(100).allow(null),
  gstPercent: Joi.number().min(0).max(100).allow(null),
  taxPercentage: Joi.number().min(0).max(100).allow(null),
}).min(1);

const categorySchema = Joi.object({
  name: Joi.string().trim().min(1).max(100).required(),
  icon: Joi.string().trim().allow('').default(''),
  color: Joi.string().trim().allow('').default(''),
  sortOrder: Joi.number().default(0),
});

const updateCategorySchema = Joi.object({
  name: Joi.string().trim().min(1).max(100),
  icon: Joi.string().trim().allow(''),
  color: Joi.string().trim().allow(''),
  sortOrder: Joi.number(),
}).min(1);

module.exports = {
  createProductSchema,
  updateProductSchema,
  categorySchema,
  updateCategorySchema,
};

