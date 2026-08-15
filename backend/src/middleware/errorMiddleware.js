const ApiError = require('../utils/ApiError');
const env = require('../config/env');

// Not Found 404 Handler
const notFoundHandler = (req, res, next) => {
  next(ApiError.notFound(`Route not found: ${req.method} ${req.originalUrl}`));
};

// Global Error Handler
const errorHandler = (err, req, res, next) => {
  let error = err;

  // Handle Mongoose / MongoDB Duplicate Key Error (11000)
  if (err.code === 11000) {
    const field = Object.keys(err.keyValue || {})[0] || 'field';
    error = ApiError.conflict(`An account with this ${field} already exists.`, 'DUPLICATE_KEY');
  }

  // Handle Mongoose CastError (Invalid ObjectId)
  if (err.name === 'CastError') {
    error = ApiError.badRequest(`Invalid ID format: ${err.value}`, null, 'INVALID_ID');
  }

  // Handle Mongoose ValidationError
  if (err.name === 'ValidationError') {
    const fields = {};
    Object.keys(err.errors || {}).forEach((key) => {
      fields[key] = err.errors[key].message;
    });
    error = ApiError.validationError('Validation failed', fields);
  }

  // Handle JWT Errors
  if (err.name === 'JsonWebTokenError') {
    error = ApiError.unauthorized('Invalid authentication token', 'INVALID_TOKEN');
  }
  if (err.name === 'TokenExpiredError') {
    error = ApiError.unauthorized('Authentication token has expired', 'TOKEN_EXPIRED');
  }

  // Fallback to 500 Internal Error if not an instance of ApiError
  const statusCode = error.statusCode || 500;
  const errorCode = error.code || 'INTERNAL_SERVER_ERROR';
  const message = error.message || 'An unexpected internal error occurred';
  const fields = error.fields || undefined;

  if (statusCode === 500 && env.NODE_ENV !== 'test') {
    console.error('[UNHANDLED ERROR]', err);
  }

  const responseBody = {
    success: false,
    error: {
      code: errorCode,
      message,
      ...(fields ? { fields } : {}),
      ...(env.NODE_ENV === 'development' && statusCode === 500 ? { stack: err.stack } : {}),
    },
  };

  return res.status(statusCode).json(responseBody);
};

module.exports = { notFoundHandler, errorHandler };
