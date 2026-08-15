const ApiError = require('../utils/ApiError');

const validate = (schema) => (req, res, next) => {
  const { error, value } = schema.validate(req.body, {
    abortEarly: false,
    allowUnknown: true,
    stripUnknown: false,
  });

  if (error) {
    const fields = {};
    error.details.forEach((detail) => {
      const fieldName = detail.path.join('.');
      fields[fieldName] = detail.message.replace(/['"]/g, '');
    });
    return next(ApiError.validationError('Validation error', fields));
  }

  req.body = value;
  return next();
};

module.exports = validate;
