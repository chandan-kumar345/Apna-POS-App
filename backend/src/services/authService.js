const mongoose = require('mongoose');
const User = require('../models/User');
const Business = require('../models/Business');
const Staff = require('../models/Staff');
const Subscription = require('../models/Subscription');
const tokenService = require('./tokenService');
const notificationService = require('./notificationService');
const whatsappService = require('./whatsappService');
const ApiError = require('../utils/ApiError');

// In-memory store for active WhatsApp OTPs: Map<normalizedPhone, { otp: string, expiresAt: number, phone: string }>
const activeWhatsappOtps = new Map();

class AuthService {
  // Pre-check if an account already exists by email or phone
  async checkUserExists({ email, phone } = {}) {
    let emailExists = false;
    let phoneExists = false;

    if (email && typeof email === 'string' && email.trim()) {
      const normalizedEmail = email.trim().toLowerCase();
      const existingUser = await User.findOne({ email: normalizedEmail });
      if (existingUser) {
        emailExists = true;
      }
    }

    if (phone && phone.toString().trim()) {
      const existingPhone = await this.findRegisteredAccountByPhone(phone.toString().trim());
      if (existingPhone) {
        phoneExists = true;
      }
    }

    if (emailExists) {
      return {
        exists: true,
        reason: 'EMAIL_ALREADY_EXISTS',
        message: 'An account with this email address already exists. Please log in.',
      };
    }

    if (phoneExists) {
      return {
        exists: true,
        reason: 'PHONE_ALREADY_EXISTS',
        message: 'An account with this phone number already exists. Please log in.',
      };
    }

    return {
      exists: false,
      reason: null,
      message: 'Account does not exist. You may proceed with registration.',
    };
  }

  // Register a new user
  async register(email, password, options = {}) {
    const normalizedEmail = email.trim().toLowerCase();

    // Check if user already exists by email
    const existingUser = await User.findOne({ email: normalizedEmail });
    if (existingUser) {
      throw ApiError.conflict('An account with this email address already exists. Please log in.', 'EMAIL_ALREADY_EXISTS');
    }

    // Check if user already exists by phone (if provided)
    if (options.phone && options.phone.toString().trim()) {
      const existingPhone = await this.findRegisteredAccountByPhone(options.phone.toString().trim());
      if (existingPhone) {
        throw ApiError.conflict('An account with this phone number already exists. Please log in.', 'PHONE_ALREADY_EXISTS');
      }
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

    // Initialize Default False Subscription in unified premiumsubscriptions collection
    try {
      await Subscription.create({
        businessId: business._id,
        userId: user._id,
        targetType: 'business',
        userEmail: user.email,
        userName: options.name || user.email.split('@')[0],
        businessName: business?.profile?.companyName || 'My Restaurant',
        phone: user.phone || '',
        userCreatedAt: user.createdAt,
        plan: 'starter',
        isSubscriptionActive: false,
        isActive: false,
        isSubscribed: false,
        status: 'inactive',
        hasLoyalty: false,
        hasCampaign: false,
        hasInventory: false,
      });
    } catch (err) {
      console.warn(`[Default Subscription Init Warning] ${err.message}`);
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

    // Resolve active WhatsApp settings across User or Business
    const activeWaSettings = user.whatsappSettings?.phoneNumberId
      ? user.whatsappSettings
      : (business?.whatsappSettings?.phoneNumberId ? business.whatsappSettings : null);

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
        whatsappSettings: activeWaSettings,
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
        whatsappSettings: user.whatsappSettings?.phoneNumberId
          ? user.whatsappSettings
          : (business?.whatsappSettings?.phoneNumberId ? business.whatsappSettings : null),
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

  // Check if a phone number belongs to a registered customer / user / staff / business
  async findRegisteredAccountByPhone(phone) {
    if (!phone) return null;
    const raw = phone.toString().trim();
    const normalized = whatsappService.normalizePhoneNumber(raw);
    const digitsOnly = raw.replace(/\D/g, '');
    const last10 = digitsOnly.length >= 10 ? digitsOnly.slice(-10) : digitsOnly;

    const phoneCandidates = Array.from(new Set([
      raw,
      normalized,
      `+${normalized}`,
      digitsOnly,
      last10,
      `+91${last10}`,
      `91${last10}`,
      `+91 ${last10}`,
    ])).filter(Boolean);

    // Build conditions including regex to handle variable whitespace and country code prefixes
    const phoneConditions = [{ phone: { $in: phoneCandidates } }];
    const bizPhoneConditions = [{ 'profile.phone': { $in: phoneCandidates } }];
    const staffPhoneConditions = [{ phone: { $in: phoneCandidates } }];

    if (last10 && last10.length >= 7) {
      // Regex allowing spaces/hyphens between digits, anchored at end of string
      const regexPattern = new RegExp(last10.split('').join('[\\s\\-]*') + '$');
      phoneConditions.push({ phone: { $regex: regexPattern } });
      bizPhoneConditions.push({ 'profile.phone': { $regex: regexPattern } });
      staffPhoneConditions.push({ phone: { $regex: regexPattern } });
    }

    // 1. Search in User collection
    let user = await User.findOne({ $or: phoneConditions });
    if (user) {
      return { type: 'user', account: user, user };
    }

    // 2. Search in Staff collection
    let staff = await Staff.findOne({ $or: staffPhoneConditions });
    if (staff) {
      let linkedUser = null;
      if (staff.userId) {
        linkedUser = await User.findById(staff.userId);
      } else if (staff.email) {
        linkedUser = await User.findOne({ email: staff.email.toLowerCase() });
      }
      return { type: 'staff', account: staff, user: linkedUser };
    }

    // 3. Search in Business collection
    let business = await Business.findOne({ $or: bizPhoneConditions });
    if (business && business.ownerId) {
      let owner = await User.findById(business.ownerId);
      if (owner) {
        // Backfill user.phone if empty so future lookups match directly
        if (!owner.phone && business.profile?.phone) {
          try {
            owner.phone = business.profile.phone;
            await owner.save();
          } catch (_) {}
        }
        return { type: 'business', account: business, user: owner };
      }
    }

    return null;
  }

  // Generate & dispatch OTP via WhatsApp from Apna POS official WhatsApp number
  async sendWhatsappOtp(phone) {
    if (!phone) {
      throw ApiError.badRequest('Phone number is required');
    }

    const normalizedPhone = whatsappService.normalizePhoneNumber(phone);
    if (!normalizedPhone || !whatsappService.isValidPhoneNumber(normalizedPhone)) {
      throw ApiError.badRequest('Invalid mobile phone number format');
    }

    // Check whether the entered phone number is an existing registered user / staff / business
    const registered = await this.findRegisteredAccountByPhone(phone);
    if (!registered || !registered.user) {
      throw ApiError.notFound(
        'This phone number is not registered. Please create an account or verify your number.',
        'PHONE_NOT_REGISTERED'
      );
    }

    // Generate secure 4-digit OTP matching Apna POS PIN boxes
    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const expiresAt = Date.now() + 5 * 60 * 1000; // 5 minutes expiry

    // In-memory cache + persistent MongoDB store for multi-server production resilience
    activeWhatsappOtps.set(normalizedPhone, {
      otp,
      expiresAt,
      phone,
      userId: registered.user._id,
      registeredType: registered.type,
    });

    try {
      if (mongoose.connection?.readyState === 1) {
        await mongoose.connection.collection('whatsapp_otps').updateOne(
          { phone: normalizedPhone },
          {
            $set: {
              otp,
              expiresAt: new Date(expiresAt),
              phone: normalizedPhone,
              userId: registered.user._id,
              registeredType: registered.type,
              updatedAt: new Date(),
            },
          },
          { upsert: true }
        );
      }
    } catch (dbErr) {
      console.warn('[WhatsApp OTP] Note: Mongo OTP persistence notice:', dbErr.message);
    }

    console.log(`🔑 [Apna POS WhatsApp OTP Generated] Phone: ${normalizedPhone} | OTP Code: >>> ${otp} <<< (Valid 5 mins)`);

    try {
      const phoneNumberId = registered.user?.whatsappSettings?.phoneNumberId || registered.account?.whatsappSettings?.phoneNumberId;
      const accessToken = registered.user?.whatsappSettings?.accessToken || registered.account?.whatsappSettings?.accessToken;

      const waResult = await whatsappService.sendOtpMessage({
        to: normalizedPhone,
        otpCode: otp,
        phoneNumberId,
        accessToken,
      });

      console.log(`[WhatsApp OTP] Successfully dispatched OTP to ${normalizedPhone} (${waResult.viaTemplate ? 'Template' : (waResult.viaText ? 'Direct Text' : 'Simulated')})`);

      return {
        success: true,
        isRegistered: true,
        whatsappSent: true,
        message: 'Verification OTP sent to your WhatsApp number successfully.',
        phone: normalizedPhone,
        otpDebug: process.env.NODE_ENV !== 'production' ? otp : undefined,
      };
    } catch (err) {
      console.error(`[WhatsApp OTP Dispatch Error] ${err.message}`);
      return {
        success: false,
        isRegistered: true,
        whatsappSent: false,
        message: `Failed to dispatch WhatsApp OTP: ${err.message}`,
        phone: normalizedPhone,
        otpDebug: process.env.NODE_ENV !== 'production' ? otp : undefined,
      };
    }
  }

  // Verify WhatsApp OTP and generate authenticated session tokens
  async verifyWhatsappOtp(phone, enteredOtp) {
    if (!phone || !enteredOtp) {
      throw ApiError.badRequest('Phone number and OTP code are required');
    }

    const normalizedPhone = whatsappService.normalizePhoneNumber(phone);
    const cleanOtp = enteredOtp.toString().trim().replace(/\D/g, '');

    const isMasterTestPin = process.env.NODE_ENV !== 'production' && ['1234', '9999'].includes(cleanOtp);

    // 1. Check in-memory store first
    let record = activeWhatsappOtps.get(normalizedPhone);

    // 2. Fall back to MongoDB persistent store for server restart resilience
    if (!record) {
      try {
        if (mongoose.connection?.readyState === 1) {
          const dbRecord = await mongoose.connection.collection('whatsapp_otps').findOne({ phone: normalizedPhone });
          if (dbRecord) {
            record = {
              otp: dbRecord.otp,
              expiresAt: new Date(dbRecord.expiresAt).getTime(),
              userId: dbRecord.userId,
              registeredType: dbRecord.registeredType,
            };
          }
        }
      } catch (_) {}
    }

    if (!record && !isMasterTestPin) {
      throw ApiError.unauthorized('No active OTP found for this number or it has expired. Please request a new OTP.');
    }

    if (record && Date.now() > record.expiresAt && !isMasterTestPin) {
      activeWhatsappOtps.delete(normalizedPhone);
      try {
        await mongoose.connection.collection('whatsapp_otps').deleteOne({ phone: normalizedPhone });
      } catch (_) {}
      throw ApiError.unauthorized('Your OTP has expired. Please request a new OTP.');
    }

    if (record && record.otp !== cleanOtp && !isMasterTestPin) {
      throw ApiError.unauthorized('The OTP you entered is incorrect. Please check and try again.');
    }

    // OTP verified successfully - clear from both memory and MongoDB
    activeWhatsappOtps.delete(normalizedPhone);
    try {
      await mongoose.connection.collection('whatsapp_otps').deleteOne({ phone: normalizedPhone });
    } catch (_) {}

    // Look up real registered user
    let user = null;
    let staff = null;
    let business = null;

    if (record.userId) {
      user = await User.findById(record.userId);
    }

    if (!user) {
      const registered = await this.findRegisteredAccountByPhone(phone);
      user = registered?.user;
      if (registered?.type === 'staff') {
        staff = registered.account;
      } else if (registered?.type === 'business') {
        business = registered.account;
      }
    }

    if (!user) {
      throw ApiError.notFound('No registered account found for this phone number. Please register first.', 'USER_NOT_FOUND');
    }

    // Check user active status (Owner / SuperAdmin exempted)
    const isSuperAdminEmail = (user?.email || '').toLowerCase() === 'chandanyaduvanshi190@gmail.com';
    if (user && user.status && user.status !== 'active' && !user.isSuperAdmin && !isSuperAdminEmail) {
      throw ApiError.forbidden(
        'Your account is currently inactive or suspended. Please contact Apna POS Owner/Support.',
        'ACCOUNT_INACTIVE'
      );
    }

    // Resolve staff if linked
    if (!staff) {
      if (user.staffId) {
        staff = await Staff.findById(user.staffId);
      } else if (user.businessId) {
        staff = await Staff.findOne({ userId: user._id, businessId: user.businessId });
      }
    }

    // Resolve business
    if (!business) {
      if (user.businessId) {
        business = await Business.findById(user.businessId).lean();
      } else if (staff?.businessId) {
        business = await Business.findById(staff.businessId).lean();
      } else {
        business = await Business.findOne({ ownerId: user._id }).lean();
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

    if (staff) {
      try {
        await Staff.findByIdAndUpdate(staff._id || staff.id, { lastLogin: new Date() });
      } catch (_) {}
    }

    const tokens = await tokenService.generateAuthTokens(user);

    const activeWaSettings = user.whatsappSettings?.phoneNumberId
      ? user.whatsappSettings
      : (business?.whatsappSettings?.phoneNumberId ? business.whatsappSettings : null);

    return {
      success: true,
      user: {
        id: user._id,
        email: user.email,
        phone: staff?.phone || user.phone || business?.profile?.phone || normalizedPhone,
        name: staff?.name || business?.profile?.name || '',
        companyName: business?.profile?.companyName || '',
        profilePhotoPath: staff?.avatarUrl || business?.profile?.profileImage || '',
        role: staff?.role || user.role || 'owner',
        employeeId: staff?.employeeId || '',
        permissions,
        onboardingCompleted: isStaffUser ? true : (user.onboardingCompleted ?? false),
        onboardingStep: isStaffUser ? 4 : (user.onboardingStep ?? 0),
        whatsappSettings: activeWaSettings,
        business: business || null,
      },
      business: business || null,
      ...tokens,
    };
  }
}

module.exports = new AuthService();
