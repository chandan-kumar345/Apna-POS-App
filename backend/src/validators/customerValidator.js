const Joi = require('joi');

const createCustomerSchema = Joi.object({
  name: Joi.string().trim().min(2).max(100).required(),
  phone: Joi.string().trim().min(6).max(20).required(),
  email: Joi.string().email().trim().allow('').default(''),
  address: Joi.string().trim().allow('').default(''),
});

const updateCustomerSchema = Joi.object({
  name: Joi.string().trim().min(2).max(100),
  phone: Joi.string().trim().min(6).max(20),
  email: Joi.string().email().trim().allow(''),
  address: Joi.string().trim().allow(''),
}).min(1);

module.exports = {
  createCustomerSchema,
  updateCustomerSchema,
};
