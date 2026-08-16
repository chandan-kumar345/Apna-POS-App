const Joi = require('joi');

const createInventorySchema = Joi.object({
  itemName: Joi.string().trim().min(2).max(100).required(),
  category: Joi.string().trim().default('General'),
  quantity: Joi.number().min(0).required(),
  unit: Joi.string().trim().default('kg'),
  minThreshold: Joi.number().min(0).default(5),
  costPerUnit: Joi.number().min(0).default(0),
  supplier: Joi.string().trim().allow('').default(''),
});

const updateInventorySchema = Joi.object({
  itemName: Joi.string().trim().min(2).max(100),
  category: Joi.string().trim(),
  quantity: Joi.number().min(0),
  unit: Joi.string().trim(),
  minThreshold: Joi.number().min(0),
  costPerUnit: Joi.number().min(0),
  supplier: Joi.string().trim().allow(''),
}).min(1);

module.exports = {
  createInventorySchema,
  updateInventorySchema,
};
