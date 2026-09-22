const ApiError = require('../utils/ApiError');

/**
 * Normalizes permission key for broad/category matching
 * e.g., 'inventory_view' matches category 'inventory'
 * e.g., 'reports_daily_sales' matches category 'reports'
 */
function matchesPermission(userPermissions = [], requiredPerms = []) {
  if (userPermissions.includes('*') || userPermissions.includes('all')) {
    return true;
  }

  for (const required of requiredPerms) {
    const reqLower = required.toLowerCase().trim();
    if (userPermissions.some((p) => p.toLowerCase().trim() === reqLower)) {
      return true;
    }

    // Category matching (e.g., user has 'inventory', required is 'inventory_view')
    // or user has 'inventory_view', required is 'inventory'
    for (const p of userPermissions) {
      const pLower = p.toLowerCase().trim();
      if (pLower === reqLower) return true;
      if (reqLower.startsWith(pLower) || pLower.startsWith(reqLower)) return true;
      if (reqLower === 'pos' && (pLower.startsWith('pos_') || pLower === 'orders' || pLower === 'tables')) return true;
      if (reqLower === 'staff' && (pLower === 'settings_staff' || pLower === 'settings')) return true;
      if (reqLower === 'settings' && pLower.startsWith('settings_')) return true;
      if (reqLower === 'reports' && pLower.startsWith('reports_')) return true;
      if (reqLower === 'crm' && (pLower.startsWith('customers_') || pLower === 'customers')) return true;
      if (reqLower === 'menu' && (pLower.startsWith('products_') || pLower === 'products')) return true;
    }
  }

  return false;
}

/**
 * Middleware to require one or more permissions
 */
function requirePermission(...requiredPermissions) {
  return (req, res, next) => {
    try {
      const user = req.user;
      if (!user) {
        throw ApiError.unauthorized('Authentication required', 'UNAUTHORIZED');
      }

      // Owner always has full bypass
      if (user.role && user.role.toLowerCase() === 'owner') {
        return next();
      }

      // Admin role has full bypass
      const effectiveRole = (req.staff?.role || user.role || '').toLowerCase();
      if (effectiveRole === 'admin') {
        return next();
      }

      const permissions = req.permissions || req.staff?.permissions || [];
      if (matchesPermission(permissions, requiredPermissions)) {
        return next();
      }

      throw ApiError.forbidden(
        `Access denied. You do not have permission to access this resource (${requiredPermissions.join(', ')}).`,
        'INSUFFICIENT_PERMISSIONS'
      );
    } catch (err) {
      next(err);
    }
  };
}

/**
 * Middleware to require one or more roles
 */
function requireRole(...allowedRoles) {
  const normalized = allowedRoles.map((r) => r.toLowerCase().trim());
  return (req, res, next) => {
    try {
      const user = req.user;
      if (!user) {
        throw ApiError.unauthorized('Authentication required', 'UNAUTHORIZED');
      }

      // Owner always has bypass
      if (user.role && user.role.toLowerCase() === 'owner') {
        return next();
      }

      const effectiveRole = (req.staff?.role || user.role || '').toLowerCase();
      if (normalized.includes(effectiveRole)) {
        return next();
      }

      throw ApiError.forbidden(
        `Access denied. Requires one of the following roles: ${allowedRoles.join(', ')}.`,
        'INSUFFICIENT_ROLE'
      );
    } catch (err) {
      next(err);
    }
  };
}

module.exports = {
  requirePermission,
  requireRole,
  matchesPermission,
};
