const Joi = require('joi');

const createTableSchema = Joi.object({
  tableNumber: Joi.number().integer().min(1).required(),
  name: Joi.string().trim().min(1).max(50).required(),
  floor: Joi.string().trim().default('Ground Floor'),
  capacity: Joi.number().integer().min(1).default(4),
});

const updateTableSchema = Joi.object({
  name: Joi.string().trim().min(1).max(50),
  floor: Joi.string().trim(),
  capacity: Joi.number().integer().min(1),
  status: Joi.string().valid('free', 'occupied', 'billed', 'reserved'),
}).min(1);

const updateTableStatusSchema = Joi.object({
  status: Joi.string().valid('free', 'occupied', 'billed', 'reserved').required(),
  currentOrderId: Joi.string().hex().length(24).allow(null).optional(),
});

module.exports = {
  createTableSchema,
  updateTableSchema,
  updateTableStatusSchema,
};
