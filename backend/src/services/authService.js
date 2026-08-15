const User = require('../models/User');
const Business = require('../models/Business');
const tokenService = require('./tokenService');
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
        onboardingCompleted: user.onboardingCompleted,
        onboardingStep: user.onboardingStep,
      },
      ...tokens,
    };
  }

  // Login with email or phone and password
  async login(identifier, password) {
    const cleanId = identifier.trim().toLowerCase();
    const rawId = identifier.trim();

    // Find user by email or phone
    const user = await User.findOne({
      $or: [
        { email: cleanId },
        { phone: cleanId },
        { phone: rawId },
        { phone: rawId.replace(/\s+/g, '') },
      ],
    }).select('+passwordHash');

    if (!user) {
      throw ApiError.unauthorized('No account found with this email or phone number. Please sign up first.', 'INVALID_CREDENTIALS');
    }

    // Verify password
    const isPasswordValid = await user.comparePassword(password);
    if (!isPasswordValid) {
      throw ApiError.unauthorized('Incorrect password. Please check your password and try again.', 'INVALID_CREDENTIALS');
    }

    // Generate tokens
    const tokens = await tokenService.generateAuthTokens(user);

    // Fetch associated business info
    const business = await Business.findOne({ ownerId: user._id });

    return {
      user: {
        id: user._id,
        email: user.email,
        phone: user.phone || business?.profile?.phone || '',
        name: business?.profile?.name || '',
        companyName: business?.profile?.companyName || '',
        profilePhotoPath: business?.profile?.profileImage || '',
        role: user.role,
        onboardingCompleted: user.onboardingCompleted,
        onboardingStep: user.onboardingStep,
        business: business || null,
      },
      ...tokens,
    };
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

    let business = await Business.findOne({ ownerId: user._id });
    if (!business) {
      business = await Business.create({ ownerId: user._id });
    }

    return {
      user: {
        id: user._id,
        email: user.email,
        phone: user.phone || business?.profile?.phone || '',
        name: business?.profile?.name || '',
        companyName: business?.profile?.companyName || '',
        profilePhotoPath: business?.profile?.profileImage || '',
        role: user.role,
        emailVerified: user.emailVerified,
        phoneVerified: user.phoneVerified,
        onboardingCompleted: user.onboardingCompleted,
        onboardingStep: user.onboardingStep,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      business,
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

