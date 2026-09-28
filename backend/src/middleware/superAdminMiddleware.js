const tokenService = require('../services/tokenService');
const User = require('../models/User');
const ApiError = require('../utils/ApiError');

const SUPERADMIN_EMAIL = 'chandanyaduvanshi190@gmail.com';

/**
 * Super Admin Middleware
 * Restricts access strictly to the owner (chandanyaduvanshi190@gmail.com)
 */
const superAdminMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw ApiError.unauthorized('Super Admin access requires a Bearer token in Authorization header', 'TOKEN_MISSING');
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

    const normalizedEmail = (user.email || '').trim().toLowerCase();
    const isOwnerSuperAdmin =
      normalizedEmail === SUPERADMIN_EMAIL.toLowerCase() ||
      user.isSuperAdmin === true ||
      user.role === 'superadmin';

    if (!isOwnerSuperAdmin) {
      throw ApiError.forbidden(
        'Access Denied. Only the platform owner (chandanyaduvanshi190@gmail.com) can access this Super Admin dashboard.',
        'SUPERADMIN_ONLY'
      );
    }

    req.user = user;
    req.isSuperAdmin = true;
    next();
  } catch (error) {
    next(error);
  }
};

module.exports = superAdminMiddleware;
