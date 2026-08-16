const Joi = require('joi');

const orderItemSchema = Joi.object({
  productId: Joi.string().hex().length(24).optional(),
  name: Joi.string().trim().required(),
  price: Joi.number().min(0).required(),
  quantity: Joi.number().integer().min(1).required(),
  foodType: Joi.string().valid('veg', 'non_veg', 'egg').default('veg'),
  note: Joi.string().trim().allow('').default(''),
});

const createOrderSchema = Joi.object({
  orderType: Joi.string().valid('dineIn', 'takeaway', 'delivery').default('dineIn'),
  tableNumber: Joi.string().trim().allow('').default(''),
  customerName: Joi.string().trim().allow('').default(''),
  customerPhone: Joi.string().trim().allow('').default(''),
  items: Joi.array().items(orderItemSchema).min(1).required(),
  subtotal: Joi.number().min(0).required(),
  discountAmount: Joi.number().min(0).default(0),
  taxAmount: Joi.number().min(0).default(0),
  tipAmount: Joi.number().min(0).default(0),
  totalAmount: Joi.number().min(0).required(),
  paymentMethod: Joi.string().valid('cash', 'upi', 'card', 'unpaid').default('unpaid'),
  paymentStatus: Joi.string().valid('pending', 'paid', 'refunded').default('pending'),
  kotStatus: Joi.string().valid('not_sent', 'sent', 'printed').default('not_sent'),
  kotNumber: Joi.number().default(0),
  notes: Joi.string().trim().allow('').default(''),
});

const updateOrderStatusSchema = Joi.object({
  status: Joi.string().valid('pending', 'preparing', 'ready', 'completed', 'cancelled').required(),
});

const payOrderSchema = Joi.object({
  paymentMethod: Joi.string().valid('cash', 'upi', 'card').required(),
  amountPaid: Joi.number().min(0).optional(),
});

module.exports = {
  createOrderSchema,
  updateOrderStatusSchema,
  payOrderSchema,
};
