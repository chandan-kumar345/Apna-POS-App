const tokenService = require('../services/tokenService');
const User = require('../models/User');
const Staff = require('../models/Staff');
const Business = require('../models/Business');
const ApiError = require('../utils/ApiError');

const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ') || authHeader.trim() === 'Bearer' || authHeader.trim() === 'Bearer null' || authHeader.trim() === 'Bearer undefined') {

      throw ApiError.unauthorized('Authorization header with Bearer token is required', 'TOKEN_MISSING');
    }

    const token = authHeader.split(' ')[1]?.trim();
    if (!token || token === 'null' || token === 'undefined') {
      throw ApiError.unauthorized('Bearer token is missing', 'TOKEN_MISSING');
    }

    let decoded;
    try {
      decoded = tokenService.verifyAccessToken(token);
    } catch (tokenErr) {
      throw tokenErr;
    }
    let user = await User.findById(decoded.sub);
    if (!user) {
      throw ApiError.unauthorized('The user belonging to this token no longer exists', 'USER_NOT_FOUND');
    }

    // Account status applies to every authenticated user.
    if (user.status && user.status !== 'active') {
      throw ApiError.forbidden(
        'Your account is currently inactive or suspended. Please contact Apna POS Owner/Support.',
        'ACCOUNT_INACTIVE'
      );
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

    const ownsBusiness = String(business.ownerId) === String(user._id);
    const member = staff && String(staff.businessId) === String(business._id)
      && String(staff.userId) === String(user._id);
    if (!ownsBusiness && !member) throw ApiError.forbidden('Business membership is required', 'BUSINESS_MEMBERSHIP_REQUIRED');

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
    req.tenantOptions = { _tenantId: business._id };

    // Strict Tenant Boundary Verification: Prevent cross-tenant spoofing via X-Business-ID
    const requestedTenantHeader = req.headers['x-business-id'];
    if (requestedTenantHeader && requestedTenantHeader.trim() !== '') {
      const cleanHeaderId = requestedTenantHeader.trim();
      const authenticatedTenantId = business._id.toString();
      if (cleanHeaderId !== authenticatedTenantId) {
        console.warn(
          `[Tenant Security Alert] Cross-tenant spoofing detected! User ${user._id} attempted to access tenant ${cleanHeaderId} using token for ${authenticatedTenantId}`
        );
        throw ApiError.forbidden(
          'Access denied: You do not have permission to access resources belonging to this business',
          'TENANT_MISMATCH_FORBIDDEN'
        );
      }
    }

    next();
  } catch (error) {
    next(error);
  }
};

module.exports = authMiddleware;
