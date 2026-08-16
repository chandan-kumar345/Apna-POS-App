const Joi = require('joi');

const createProductSchema = Joi.object({
  name: Joi.string().trim().min(2).max(100).required().messages({
    'string.empty': 'Product name cannot be empty',
    'any.required': 'Product name is required',
  }),
  description: Joi.string().trim().max(500).allow('').default(''),
  category: Joi.string().trim().min(2).max(50).required().messages({
    'string.empty': 'Category cannot be empty',
    'any.required': 'Category is required',
  }),
  price: Joi.number().min(0).required().messages({
    'number.min': 'Price cannot be negative',
    'any.required': 'Price is required',
  }),
  salePrice: Joi.number().min(0).default(0),
  image: Joi.string().trim().allow('').default(''),
  foodType: Joi.string().valid('veg', 'non_veg', 'egg').default('veg'),
  isAvailable: Joi.boolean().default(true),
  stock: Joi.number().default(-1),
  sku: Joi.string().trim().allow('').default(''),
  taxPercentage: Joi.number().min(0).max(100).default(5),
});

const updateProductSchema = Joi.object({
  name: Joi.string().trim().min(2).max(100),
  description: Joi.string().trim().max(500).allow(''),
  category: Joi.string().trim().min(2).max(50),
  price: Joi.number().min(0),
  salePrice: Joi.number().min(0),
  image: Joi.string().trim().allow(''),
  foodType: Joi.string().valid('veg', 'non_veg', 'egg'),
  isAvailable: Joi.boolean(),
  stock: Joi.number(),
  sku: Joi.string().trim().allow(''),
  taxPercentage: Joi.number().min(0).max(100),
}).min(1);

const categorySchema = Joi.object({
  name: Joi.string().trim().min(2).max(50).required(),
  icon: Joi.string().trim().allow('').default(''),
  color: Joi.string().trim().allow('').default(''),
  sortOrder: Joi.number().default(0),
});

module.exports = {
  createProductSchema,
  updateProductSchema,
  categorySchema,
};
