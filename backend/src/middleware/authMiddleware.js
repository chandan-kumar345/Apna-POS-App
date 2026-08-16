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

    // Resolve or find linked business for multi-tenant data scoping
    const Business = require('../models/Business');
    let business = await Business.findOne({ ownerId: user._id });
    if (!business) {
      business = await Business.create({
        ownerId: user._id,
        profile: { name: user.email.split('@')[0], companyName: 'Apna POS Store' },
      });
    }

    req.user = user;
    req.business = business;
    req.businessId = business._id;
    next();
  } catch (error) {
    next(error);
  }
};

module.exports = authMiddleware;
