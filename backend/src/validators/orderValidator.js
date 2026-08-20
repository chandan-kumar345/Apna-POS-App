const Joi = require('joi');

const orderItemSchema = Joi.object({
  productId: Joi.string().allow('', null).optional(),
  name: Joi.string().trim().required(),
  price: Joi.number().min(0).required(),
  quantity: Joi.number().min(1).required(),
  foodType: Joi.string().allow('', null).default('veg'),
  note: Joi.string().trim().allow('', null).default(''),
});

const createOrderSchema = Joi.object({
  orderNumber: Joi.string().allow('', null).optional(),
  orderType: Joi.string().allow('', null).default('dineIn'),
  status: Joi.string().valid('pending', 'preparing', 'ready', 'completed', 'cancelled', 'paid').optional(),
  tableNumber: Joi.string().trim().allow('', null).default(''),
  customerName: Joi.string().trim().allow('', null).default(''),
  customerPhone: Joi.string().trim().allow('', null).default(''),
  items: Joi.array().items(orderItemSchema).min(1).required(),
  subtotal: Joi.number().min(0).required(),
  discountAmount: Joi.number().min(0).default(0),
  taxAmount: Joi.number().min(0).default(0),
  cgst: Joi.number().min(0).optional(),
  sgst: Joi.number().min(0).optional(),
  igst: Joi.number().min(0).optional(),
  tipAmount: Joi.number().min(0).default(0),
  totalAmount: Joi.number().min(0).required(),
  paymentMethod: Joi.string().allow('', null).default('unpaid'),
  paymentStatus: Joi.string().allow('', null).default('pending'),
  kotStatus: Joi.string().allow('', null).default('not_sent'),
  kotNumber: Joi.number().allow(null).default(0),
  notes: Joi.string().trim().allow('', null).default(''),
  createdAt: Joi.any().optional(),
});

const updateOrderStatusSchema = Joi.object({
  status: Joi.string().valid('pending', 'preparing', 'ready', 'completed', 'cancelled', 'paid').required(),
  reason: Joi.string().allow('', null).optional(),
});

const payOrderSchema = Joi.object({
  paymentMethod: Joi.string().allow('', null).default('cash'),
  amountPaid: Joi.number().min(0).optional(),
});

module.exports = {
  createOrderSchema,
  updateOrderStatusSchema,
  payOrderSchema,
};
