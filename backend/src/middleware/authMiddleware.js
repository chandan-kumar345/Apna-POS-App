const tokenService = require('../services/tokenService');
const User = require('../models/User');
const ApiError = require('../utils/ApiError');

const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw ApiError.unauthorized('Authorization header with Bearer token is required', 'TOKEN_MISSING');
    }

    const token = authHeader.split(' ')[1];
    if (!token) {
      throw ApiError.unauthorized('Bearer token is missing', 'TOKEN_MISSING');
    }

    const decoded = tokenService.verifyAccessToken(token);
    const user = await User.findById(decoded.sub);

    if (!user) {
      throw ApiError.unauthorized('The user belonging to this token no longer exists', 'USER_NOT_FOUND');
    }

    req.user = user;
    next();
  } catch (error) {
    next(error);
  }
};

module.exports = authMiddleware;
