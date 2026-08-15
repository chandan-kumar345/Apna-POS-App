const Joi = require('joi');

const profileSchema = Joi.object({
  name: Joi.string().trim().min(2).max(100).required().messages({
    'string.empty': 'Full name is required',
    'any.required': 'Full name is required',
  }),
  phone: Joi.string().trim().min(6).max(20).required().messages({
    'string.empty': 'Phone number is required',
    'any.required': 'Phone number is required',
  }),
  companyName: Joi.string().trim().min(2).max(150).required().messages({
    'string.empty': 'Company / Restaurant name is required',
    'any.required': 'Company / Restaurant name is required',
  }),
  profileImage: Joi.string().allow('', null).optional(),
  website: Joi.string().allow('', null).optional(),
  referralCode: Joi.string().allow('', null).optional(),
});

const businessSchema = Joi.object({
  country: Joi.string().trim().required().messages({
    'string.empty': 'Country is required',
    'any.required': 'Country is required',
  }),
  currency: Joi.string().trim().required().messages({
    'string.empty': 'Currency is required',
    'any.required': 'Currency is required',
  }),
  timezone: Joi.string().trim().required().messages({
    'string.empty': 'Timezone is required',
    'any.required': 'Timezone is required',
  }),
  businessType: Joi.string().trim().required().messages({
    'string.empty': 'Business type / category is required',
    'any.required': 'Business type / category is required',
  }),
  phone: Joi.string().allow('', null).optional(),
});

const addressSchema = Joi.object({
  addressLine: Joi.string().allow('', null).optional(),
  address: Joi.string().allow('', null).optional(),
  building: Joi.string().allow('', null).optional(),
  landmark: Joi.string().allow('', null).optional(),
  placeType: Joi.string().valid('home', 'work', 'other').default('work'),
  city: Joi.string().trim().required().messages({
    'string.empty': 'City is required',
    'any.required': 'City is required',
  }),
  state: Joi.string().allow('', null).optional(),
  country: Joi.string().default('IN'),
  postalCode: Joi.string().allow('', null).optional(),
  latitude: Joi.number().min(-90).max(90).optional().default(0),
  longitude: Joi.number().min(-180).max(180).optional().default(0),
});

const orderSettingsSchema = Joi.object({
  services: Joi.object({
    dineIn: Joi.boolean().default(true),
    takeaway: Joi.boolean().default(false),
    delivery: Joi.boolean().default(false),
  }).default(),
  tax: Joi.object({
    type: Joi.string().valid('gst', 'no_gst').required().messages({
      'any.only': 'Tax type must be either gst or no_gst',
      'any.required': 'Tax type is required',
    }),
    gstNumber: Joi.when('type', {
      is: 'gst',
      then: Joi.string().trim().min(3).required().messages({
        'string.empty': 'GST number is required when GST is selected',
        'any.required': 'GST number is required when GST is selected',
      }),
      otherwise: Joi.string().allow('', null).optional(),
    }),
    percentage: Joi.when('type', {
      is: 'gst',
      then: Joi.number().min(0).max(100).required().messages({
        'number.base': 'GST percentage must be a number',
        'any.required': 'GST percentage is required when GST is selected',
      }),
      otherwise: Joi.number().allow(null).optional(),
    }),
  }).required(),
  restaurantType: Joi.string()
    .valid('pure_veg', 'non_veg', 'both')
    .required()
    .messages({
      'any.only': 'Restaurant type must be pure_veg, non_veg, or both',
      'any.required': 'Restaurant type is required',
    }),
  paymentMethods: Joi.object({
    cash: Joi.boolean().default(true),
    upi: Joi.boolean().default(true),
    card: Joi.boolean().default(false),
  }).default(),
  upiId: Joi.when('paymentMethods.upi', {
    is: true,
    then: Joi.string().trim().min(3).required().messages({
      'string.empty': 'UPI ID is required when UPI payments are enabled',
      'any.required': 'UPI ID is required when UPI payments are enabled',
    }),
    otherwise: Joi.string().allow('', null).optional(),
  }),
  tableCount: Joi.number().integer().min(0).required().messages({
    'number.base': 'Table count must be an integer',
    'number.min': 'Table count cannot be negative',
    'any.required': 'Table count is required',
  }),
});

module.exports = {
  profileSchema,
  businessSchema,
  addressSchema,
  orderSettingsSchema,
};
