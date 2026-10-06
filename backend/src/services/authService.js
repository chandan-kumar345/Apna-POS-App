const User = require('../models/User');
const Business = require('../models/Business');
const Staff = require('../models/Staff');
const tokenService = require('./tokenService');
const notificationService = require('./notificationService');
const ApiError = require('../utils/ApiError');

class AuthService {
  // Register a new user
  async register(email, password, options = {}) {
    const normalizedEmail = email.trim().toLowerCase();

    // Check if user already exists
    const existingUser = await User.findOne({ email: normalizedEmail });
    if (existingUser) {
      throw ApiError.conflict('An account with this email already exists', 'EMAIL_ALREADY_EXISTS');
    }

    // Hash password
    const passwordHash = await User.hashPassword(password);

    // Create user
    const user = await User.create({
      email: normalizedEmail,
      phone: options.phone ? options.phone.trim() : undefined,
      passwordHash,
      onboardingCompleted: false,
      onboardingStep: 0,
      role: options.role || 'owner',
    });

    // Create initial Business document linked to ownerId
    let business = await Business.findOne({ ownerId: user._id });
    if (!business) {
      business = await Business.create({
        ownerId: user._id,
      });
    }

    // Trigger Welcome Notification with idempotency
    try {
      const userName = options.name || business?.profile?.name || user.email.split('@')[0] || 'User';
      await notificationService.createNotification({
        userId: user._id,
        businessId: business?._id,
        type: 'welcome',
        title: 'Welcome to Apna POS 🎉',
        message: `Hi ${userName}, welcome to Apna POS! Your all-in-one POS partner is here to help you manage your sales, orders, customers, payments, and business operations with ease. Let’s make your business smarter, faster, and simpler.`,
        entityType: 'user',
        entityId: user._id.toString(),
        metadata: { userName },
        idempotencyKey: `welcome_${user._id.toString()}`,
      });
    } catch (err) {
      console.warn(`[Welcome Notification Notice] ${err.message}`);
    }

    // Generate tokens
    const tokens = await tokenService.generateAuthTokens(user);

    return {
      user: {
        id: user._id,
        email: user.email,
        phone: user.phone || business?.profile?.phone || '',
        name: business?.profile?.name || '',
        companyName: business?.profile?.companyName || '',
        profilePhotoPath: business?.profile?.profileImage || '',
        role: user.role,
        permissions: ['*'],
        onboardingCompleted: user.onboardingCompleted,
        onboardingStep: user.onboardingStep,
      },
      ...tokens,
    };
  }

  // Login with email, phone, or employeeId and password/PIN
  async login(identifier, password, options = {}) {
    if (!identifier || (!password && !options.pin)) {
      throw ApiError.badRequest('Identifier and password or PIN are required', 'MISSING_CREDENTIALS');
    }

    const cleanId = identifier.trim().toLowerCase();
    const rawId = identifier.trim();
    const pin = options.pin ? options.pin.trim() : null;

    // 1. Try finding user directly by email or phone
    let user = await User.findOne({
      $or: [
        { email: cleanId },
        { phone: cleanId },
        { phone: rawId },
        { phone: rawId.replace(/\s+/g, '') },
      ],
    }).select('+passwordHash');

    let staff = null;

    // 2. If user not found, try searching in Staff collection by employeeId, email, or phone
    if (!user) {
      staff = await Staff.findOne({
        $or: [
          { employeeId: new RegExp(`^${rawId}$`, 'i') },
          { email: cleanId },
          { phone: rawId },
          { phone: rawId.replace(/\s+/g, '') },
        ],
      });

      if (staff) {
        if (staff.userId) {
          user = await User.findById(staff.userId).select('+passwordHash');
        }
      }
    } else {
      // If user was found directly, check if linked to staff
      if (user.staffId) {
        staff = await Staff.findById(user.staffId);
      } else if (user.businessId) {
        staff = await Staff.findOne({ userId: user._id, businessId: user.businessId });
      }
    }

    // 3. If neither user nor staff found
    if (!user && !staff) {
      throw ApiError.unauthorized('No account found with these credentials. Please check and try again.', 'USER_NOT_FOUND');
    }

    // 4. Check staff active status
    if (staff && staff.status === 'Inactive') {
      throw ApiError.forbidden('Your staff account is currently inactive. Please contact your administrator.', 'ACCOUNT_INACTIVE');
    }

    // 5. Verify credentials (password or PIN)
    let isAuthValid = false;

    if (user && user.passwordHash && password) {
      isAuthValid = await user.comparePassword(password);
    }

    // Also allow PIN check if staff exists and PIN matches
    if (!isAuthValid && staff) {
      if (pin && staff.pin === pin) {
        isAuthValid = true;
      } else if (password && staff.pin === password) {
        isAuthValid = true;
      }
    }

    if (!isAuthValid) {
      throw ApiError.unauthorized('Incorrect password or PIN. Please check and try again.', 'INVALID_CREDENTIALS');
    }

    // Check user active status (Owner / SuperAdmin exempted)
    const isSuperAdminEmail = (user?.email || '').toLowerCase() === 'chandanyaduvanshi190@gmail.com';
    if (user && user.status && user.status !== 'active' && !user.isSuperAdmin && !isSuperAdminEmail) {
      throw ApiError.forbidden(
        'Your account is currently inactive or suspended. Please contact Apna POS Owner/Support.',
        'ACCOUNT_INACTIVE'
      );
    }

    // 6. Ensure user record exists for token generation
    if (!user && staff) {
      const emailPlaceholder = staff.email ? staff.email.toLowerCase() : `${staff.employeeId.toLowerCase()}@apnapos.internal`;
      user = await User.findOne({ email: emailPlaceholder }).select('+passwordHash');
      if (!user) {
        const dummyHash = await User.hashPassword(password || 'Staff@123');
        user = await User.create({
          email: emailPlaceholder,
          phone: staff.phone || undefined,
          passwordHash: dummyHash,
          role: (staff.role || 'cashier').toLowerCase(),
          businessId: staff.businessId,
          staffId: staff._id,
          onboardingCompleted: true,
          onboardingStep: 4,
        });
        staff.userId = user._id;
        await staff.save();
      }
    }

    // 7. Resolve business
    let business = null;
    if (user.businessId) {
      business = await Business.findById(user.businessId).lean();
    } else if (staff?.businessId) {
      business = await Business.findById(staff.businessId).lean();
    } else {
      business = await Business.findOne({ ownerId: user._id }).lean();
    }

    // 8. Generate tokens
    const tokens = await tokenService.generateAuthTokens(user);

    const isStaffUser = !!(user.businessId || user.staffId || (staff && user.role !== 'owner'));

    let permissions = [];
    if (user.role && user.role.toLowerCase() === 'owner') {
      permissions = ['*'];
    } else if (staff?.role && staff.role.toLowerCase() === 'admin') {
      permissions = ['*'];
    } else if (staff?.permissions && Array.isArray(staff.permissions)) {
      permissions = staff.permissions;
    } else {
      permissions = ['pos', 'tables', 'orders'];
    }

    // Update staff last login
    if (staff) {
      try {
        await Staff.findByIdAndUpdate(staff._id || staff.id, {
          lastLogin: new Date(),
        });
      } catch (_) {}
    }

    return {
      user: {
        id: user._id,
        email: user.email,
        phone: staff?.phone || user.phone || business?.profile?.phone || '',
        name: staff?.name || business?.profile?.name || '',
        companyName: business?.profile?.companyName || '',
        profilePhotoPath: staff?.avatarUrl || business?.profile?.profileImage || '',
        role: staff?.role || user.role,
        employeeId: staff?.employeeId || '',
        permissions,
        onboardingCompleted: isStaffUser ? true : user.onboardingCompleted,
        onboardingStep: isStaffUser ? 4 : user.onboardingStep,
        business: business || null,
      },
      ...tokens,
    };
  }

  // Dedicated staff login method
  async staffLogin(data) {
    const identifier = data.employeeId || data.identifier || data.email || data.phone || '';
    const password = data.password || '';
    const pin = data.pin || '';

    return this.login(identifier, password, { pin });
  }

  // Refresh token
  async refreshToken(refreshToken) {
    return tokenService.refreshAuthTokens(refreshToken);
  }

  // Logout
  async logout(refreshToken) {
    if (refreshToken) {
      await tokenService.revokeRefreshToken(refreshToken);
    }
  }

  // Get current user profile and business
  async getMe(userId) {
    const user = await User.findById(userId);
    if (!user) {
      throw ApiError.notFound('User not found', 'USER_NOT_FOUND');
    }

    let staff = null;
    if (user.staffId) {
      staff = await Staff.findById(user.staffId).lean();
    } else if (user.businessId) {
      staff = await Staff.findOne({ userId: user._id, businessId: user.businessId }).lean();
    }

    let business = null;
    if (user.businessId) {
      business = await Business.findById(user.businessId);
    } else if (staff?.businessId) {
      business = await Business.findById(staff.businessId);
    } else {
      business = await Business.findOne({ ownerId: user._id });
      if (!business) {
        business = await Business.create({ ownerId: user._id });
      }
    }

    const isStaffUser = !!(user.businessId || user.staffId || (staff && user.role !== 'owner'));

    let permissions = [];
    if (user.role && user.role.toLowerCase() === 'owner') {
      permissions = ['*'];
    } else if (staff?.role && staff.role.toLowerCase() === 'admin') {
      permissions = ['*'];
    } else if (staff?.permissions && Array.isArray(staff.permissions)) {
      permissions = staff.permissions;
    } else {
      permissions = ['pos', 'tables', 'orders'];
    }

    const Subscription = require('../models/Subscription');
    let subDoc = null;
    try {
      if (business?._id) {
        subDoc = await Subscription.findOne({ businessId: business._id }).sort({ createdAt: -1 });
      }
      if (!subDoc && user?._id) {
        subDoc = await Subscription.findOne({ userId: user._id }).sort({ createdAt: -1 });
      }
    } catch (_) {}

    const bizSub = business?.subscription || {};
    const userSub = user?.subscription || {};

    let isSubActive = false;
    if (subDoc) {
      if (subDoc.isSubscriptionActive !== undefined && subDoc.isSubscriptionActive !== null) {
        isSubActive = Boolean(subDoc.isSubscriptionActive);
      } else if (subDoc.isActive !== undefined && subDoc.isActive !== null) {
        isSubActive = Boolean(subDoc.isActive);
      } else if (subDoc.isSubscribed !== undefined && subDoc.isSubscribed !== null) {
        isSubActive = Boolean(subDoc.isSubscribed);
      } else if (subDoc.status !== undefined && subDoc.status !== null) {
        isSubActive = subDoc.status === 'active';
      }
    } else {
      if (bizSub.isSubscriptionActive !== undefined && bizSub.isSubscriptionActive !== null) {
        isSubActive = Boolean(bizSub.isSubscriptionActive);
      } else if (bizSub.isActive !== undefined && bizSub.isActive !== null) {
        isSubActive = Boolean(bizSub.isActive);
      } else if (bizSub.status !== undefined && bizSub.status !== null) {
        isSubActive = bizSub.status === 'active';
      } else if (userSub.isSubscriptionActive !== undefined && userSub.isSubscriptionActive !== null) {
        isSubActive = Boolean(userSub.isSubscriptionActive);
      } else if (userSub.isActive !== undefined && userSub.isActive !== null) {
        isSubActive = Boolean(userSub.isActive);
      } else if (userSub.status !== undefined && userSub.status !== null) {
        isSubActive = userSub.status === 'active';
      }
    }

    const subPayload = {
      isSubscriptionActive: isSubActive,
      isActive: isSubActive,
      isSubscribed: isSubActive,
      status: isSubActive ? 'active' : 'inactive',
      plan: subDoc?.plan || bizSub.plan || userSub.plan || 'standard',
      amount: subDoc?.amount || bizSub.amount || 300,
      upiId: subDoc?.upiId || '9709593705@ybl',
      activatedAt: subDoc?.activatedAt || bizSub.activatedAt || userSub.startDate || null,
      expiresAt: subDoc?.expiresAt || bizSub.expiresAt || userSub.expiresAt || null,
      paymentRef: subDoc?.paymentRef || bizSub.paymentRef || userSub.paymentRef || '',
    };

    return {
      user: {
        id: user._id,
        email: user.email,
        phone: staff?.phone || user.phone || business?.profile?.phone || '',
        name: staff?.name || business?.profile?.name || '',
        companyName: business?.profile?.companyName || '',
        profilePhotoPath: staff?.avatarUrl || business?.profile?.profileImage || '',
        role: staff?.role || user.role,
        employeeId: staff?.employeeId || '',
        permissions,
        emailVerified: user.emailVerified,
        phoneVerified: user.phoneVerified,
        onboardingCompleted: isStaffUser ? true : user.onboardingCompleted,
        onboardingStep: isStaffUser ? 4 : user.onboardingStep,
        subscription: subPayload,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      business: business ? {
        ...business.toObject(),
        subscription: subPayload,
      } : null,
    };
  }

  // Reset password
  async resetPassword(email, newPassword) {
    const normalizedEmail = email.trim().toLowerCase();

    const user = await User.findOne({ email: normalizedEmail }).select('+passwordHash');
    if (!user) {
      throw ApiError.notFound('No user found with this email address', 'USER_NOT_FOUND');
    }

    // Hash new password
    const passwordHash = await User.hashPassword(newPassword);
    user.passwordHash = passwordHash;
    await user.save();

    // Revoke all existing refresh tokens for security
    await tokenService.revokeAllUserTokens(user._id);

    return {
      success: true,
      message: 'Password has been reset successfully. Please log in with your new password.',
    };
  }
}

module.exports = new AuthService();
