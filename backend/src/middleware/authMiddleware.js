const tokenService = require('../services/tokenService');
const User = require('../models/User');
const Staff = require('../models/Staff');
const Business = require('../models/Business');
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

    // Resolve or find linked staff details
    let staff = null;
    if (user.staffId) {
      staff = await Staff.findById(user.staffId);
    } else if (user.businessId) {
      staff = await Staff.findOne({ userId: user._id, businessId: user.businessId });
    }

    if (staff) {
      if (staff.status === 'Inactive') {
        throw ApiError.forbidden('Your staff account is currently inactive. Please contact your administrator.', 'ACCOUNT_INACTIVE');
      }
    }

    // Resolve or find linked business for multi-tenant data scoping
    let business = null;
    if (user.businessId) {
      business = await Business.findById(user.businessId);
    }
    if (!business) {
      business = await Business.findOne({ ownerId: user._id });
    }
    if (!business && user.role === 'owner') {
      business = await Business.create({
        ownerId: user._id,
        profile: { name: user.email.split('@')[0], companyName: 'Apna POS Store' },
      });
    }

    if (!business) {
      throw ApiError.unauthorized('No active business account associated with this user', 'BUSINESS_NOT_FOUND');
    }

    // Attach permissions
    let permissions = [];
    if (user.role && user.role.toLowerCase() === 'owner') {
      permissions = ['*'];
    } else if (staff?.role && staff.role.toLowerCase() === 'admin') {
      permissions = ['*'];
    } else if (staff?.permissions && Array.isArray(staff.permissions)) {
      permissions = staff.permissions;
    }

    req.user = user;
    req.staff = staff;
    req.permissions = permissions;
    req.business = business;
    req.businessId = business._id;
    next();
  } catch (error) {
    next(error);
  }
};

module.exports = authMiddleware;
