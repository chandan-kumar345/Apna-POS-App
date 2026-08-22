const Joi = require('joi');

const createCustomerSchema = Joi.object({
  name: Joi.string().trim().allow('', null).default('').optional(),
  phone: Joi.string().trim().min(3).max(20).required(),
  email: Joi.string().email().trim().allow('', null).default(''),
  address: Joi.string().trim().allow('', null).default(''),
});

const updateCustomerSchema = Joi.object({
  name: Joi.string().trim().allow('', null).optional(),
  phone: Joi.string().trim().min(3).max(20),
  email: Joi.string().email().trim().allow('', null),
  address: Joi.string().trim().allow('', null),
}).min(1);

module.exports = {
  createCustomerSchema,
  updateCustomerSchema,
};

