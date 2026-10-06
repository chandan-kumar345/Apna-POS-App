const ApiError = require('../utils/ApiError');

/**
 * Tenant Context Middleware
 * Enforces strict multi-tenant boundary verification on all protected routes.
 * Prevents cross-tenant spoofing and attaches tenant query context.
 */
const tenantContextMiddleware = (req, res, next) => {
  try {
    // 1. Ensure authMiddleware has successfully attached the business context
    if (!req.businessId) {
      throw ApiError.unauthorized(
        'No authenticated business tenant associated with this session',
        'TENANT_NOT_RESOLVED'
      );
    }

    const authenticatedTenantId = req.businessId.toString();

    // 2. Inspect optional client-supplied tenant header (X-Business-ID)
    const requestedTenantHeader = req.headers['x-business-id'];

    if (requestedTenantHeader && requestedTenantHeader.trim() !== '') {
      const cleanHeaderId = requestedTenantHeader.trim();

      // If client attempts to target a different tenant than their verified JWT, immediately reject
      if (cleanHeaderId !== authenticatedTenantId && !req.user?.isSuperAdmin) {
        console.warn(
          `[Tenant Security Alert] Cross-tenant spoofing detected! User ${req.user?._id} attempted to access tenant ${cleanHeaderId} using token for ${authenticatedTenantId}`
        );
        throw ApiError.forbidden(
          'Access denied: You do not have permission to access resources belonging to this business',
          'TENANT_MISMATCH_FORBIDDEN'
        );
      }
    }

    // 3. Attach scoped query options for Mongoose plugins & services
    req.tenantOptions = {
      _tenantId: req.businessId,
    };

    next();
  } catch (error) {
    next(error);
  }
};

module.exports = tenantContextMiddleware;
