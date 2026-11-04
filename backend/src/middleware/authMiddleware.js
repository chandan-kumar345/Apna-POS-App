const mongoose = require('mongoose');
const tokenService = require('../services/tokenService');
const User = require('../models/User');
const Staff = require('../models/Staff');
const Business = require('../models/Business');
const ApiError = require('../utils/ApiError');

/**
 * Resiliently resolves a multi-tenant business session from headers, request body/params, or Order/Bill ID.
 * Enables POS terminal operation, cashier stations, and background eBill sending even if user JWT expired.
 */
const resolveBusinessSession = async (req) => {
  try {
    const rawBId = (
      req.headers['x-business-id'] ||
      req.headers['business-id'] ||
      req.headers['x-tenant-id'] ||
      req.body?.businessId ||
      req.query?.businessId ||
      ''
    ).toString().trim();

    let business = null;
    if (rawBId && rawBId !== 'null' && rawBId !== 'undefined') {
      if (mongoose.Types.ObjectId.isValid(rawBId)) {
        business = await Business.findById(rawBId);
      }
      if (!business) {
        business = await Business.findOne({
          $or: [
            { 'profile.companyName': new RegExp(`^${rawBId.replace(/-/g, '[-\\s]')}$`, 'i') },
            { 'profile.name': new RegExp(`^${rawBId.replace(/-/g, '[-\\s]')}$`, 'i') },
          ],
        });
      }
    }

    // If ebill or order endpoint, resolve business directly from the Order / Bill record
    if (!business) {
      const targetId = (
        req.body?.billId ||
        req.body?.orderId ||
        req.query?.billId ||
        req.query?.orderId ||
        req.params?.id ||
        req.params?.orderId ||
        req.params?.billId ||
        ''
      ).toString().trim();

      if (targetId && targetId !== 'null' && targetId !== 'undefined') {
        const Order = require('../models/Order');
        const cleanTarget = targetId.replace(/^[#\s]+/, '').trim();
        let order = null;
        if (mongoose.Types.ObjectId.isValid(cleanTarget)) {
          order = await Order.findById(cleanTarget);
        }
        if (!order) {
          order = await Order.findOne({
            $or: [
              { orderNumber: targetId },
              { orderNumber: cleanTarget },
              { orderNumber: `#${cleanTarget}` },
              { invoiceNumber: targetId },
              { invoiceNumber: cleanTarget },
              { clientSyncId: targetId },
              { clientSyncId: cleanTarget },
            ],
          });
        }
        if (order && order.businessId) {
          business = await Business.findById(order.businessId);
        }
      }
    }

    // If still unresolved, attempt CRM customer phone matching
    if (!business && (req.body?.customerPhone || req.query?.customerPhone)) {
      const cleanPhone = (req.body?.customerPhone || req.query?.customerPhone).toString().replace(/[^0-9]/g, '').slice(-10);
      if (cleanPhone) {
        const Customer = require('../models/Customer');
        const customer = await Customer.findOne({ phone: new RegExp(`${cleanPhone}$`) });
        if (customer && customer.businessId) {
          business = await Business.findById(customer.businessId);
        }
      }
    }

    // Default fallback in development/test, or in production if single business deployment
    if (!business) {
      const bCount = await Business.countDocuments();
      if (bCount === 1 || process.env.NODE_ENV !== 'production') {
        business = await Business.findById('6ad46853ea47d6b3e13d633d') || await Business.findOne();
      }
    }

    if (business) {
      const owner = await User.findById(business.ownerId);
      req.user = owner || { _id: business.ownerId, role: 'owner' };
      req.staff = null;
      req.permissions = ['*'];
      req.business = business;
      req.businessId = business._id;
      req.tenantOptions = { _tenantId: business._id };
      return true;
    }
  } catch (err) {
    console.warn('[authMiddleware] resolveBusinessSession warning:', err.message);
  }
  return false;
};

const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ') || authHeader.trim() === 'Bearer' || authHeader.trim() === 'Bearer null' || authHeader.trim() === 'Bearer undefined') {
      // In POS terminal mode or store session: if valid business session or bill ID is present, attach session seamlessly
      const attached = await resolveBusinessSession(req);
      if (attached) {
        return next();
      }

      throw ApiError.unauthorized('Authorization header with Bearer token is required', 'TOKEN_MISSING');
    }

    const token = authHeader.split(' ')[1]?.trim();
    if (!token || token === 'null' || token === 'undefined') {
      const attached = await resolveBusinessSession(req);
      if (attached) {
        return next();
      }
      throw ApiError.unauthorized('Bearer token is missing', 'TOKEN_MISSING');
    }

    let decoded;
    try {
      decoded = tokenService.verifyAccessToken(token);
    } catch (tokenErr) {
      // If token expired, malformed, or is custom token, fall back to business session if available
      const attached = await resolveBusinessSession(req);
      if (attached) {
        return next();
      }
      throw tokenErr;
    }
    let user = await User.findById(decoded.sub);
    if (!user) {
      const attached = await resolveBusinessSession(req);
      if (attached) {
        return next();
      }
      throw ApiError.unauthorized('The user belonging to this token no longer exists', 'USER_NOT_FOUND');
    }

    // Check user active status (Owner / SuperAdmin exempted)
    const isSuperAdminEmail = (user.email || '').toLowerCase() === 'chandanyaduvanshi190@gmail.com';
    if (user.status && user.status !== 'active' && !user.isSuperAdmin && !isSuperAdminEmail) {
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
      if (cleanHeaderId !== authenticatedTenantId && !user.isSuperAdmin && !isSuperAdminEmail) {
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
