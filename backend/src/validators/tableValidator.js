const Joi = require('joi');

const createTableSchema = Joi.object({
  tableNumber: Joi.number().integer().min(1).optional(),
  name: Joi.string().trim().min(1).max(50).optional().allow(''),
  floor: Joi.string().trim().default('Ground Floor').allow(''),
  capacity: Joi.number().integer().min(1).default(4),
  count: Joi.number().integer().min(1).max(100).default(1),
});

const updateTableSchema = Joi.object({
  name: Joi.string().trim().min(1).max(50),
  floor: Joi.string().trim(),
  capacity: Joi.number().integer().min(1),
  status: Joi.string().valid('free', 'occupied', 'runningKot', 'running_kot', 'billed', 'reserved'),
}).min(1);

const updateTableStatusSchema = Joi.object({
  status: Joi.string().valid('free', 'occupied', 'runningKot', 'running_kot', 'billed', 'reserved').required(),
  currentOrderId: Joi.string().allow(null, '').optional(),
});

module.exports = {
  createTableSchema,
  updateTableSchema,
  updateTableStatusSchema,
};
