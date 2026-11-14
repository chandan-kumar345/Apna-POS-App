const tokenService = require('../services/tokenService');
const User = require('../models/User');
const ApiError = require('../utils/ApiError');

/**
 * Platform administration requires a role provisioned in the database.
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

    const isOwnerSuperAdmin =
      user.isSuperAdmin === true ||
      user.role === 'superadmin';
    if (user.status && user.status !== 'active') throw ApiError.forbidden('Administrator account is inactive', 'ACCOUNT_INACTIVE');

    if (!isOwnerSuperAdmin) {
      throw ApiError.forbidden(
        'Access denied. A platform administrator role is required.',
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
