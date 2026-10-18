const authService = require('../services/authService');
const ApiResponse = require('../utils/ApiResponse');

class AuthController {
  // Check if user already exists
  async checkUserExists(req, res, next) {
    try {
      const { email, phone } = req.body;
      const result = await authService.checkUserExists({ email, phone });
      return ApiResponse.success(res, result, result.message);
    } catch (error) {
      next(error);
    }
  }

  // Register
  async register(req, res, next) {
    try {
      const { email, password, phone } = req.body;
      const result = await authService.register(email, password, { phone });
      return ApiResponse.created(res, result, 'User registered successfully');
    } catch (error) {
      next(error);
    }
  }

  // Login
  async login(req, res, next) {
    try {
      const identifier = req.body.email || req.body.identifier || req.body.phone || req.body.employeeId;
      const { password, pin } = req.body;
      const result = await authService.login(identifier, password, { pin });
      return ApiResponse.success(res, result, 'Login successful');
    } catch (error) {
      next(error);
    }
  }

  // Dedicated Staff Login
  async staffLogin(req, res, next) {
    try {
      const result = await authService.staffLogin(req.body);
      return ApiResponse.success(res, result, 'Staff login successful');
    } catch (error) {
      next(error);
    }
  }

  // Refresh token
  async refreshToken(req, res, next) {
    try {
      const { refreshToken } = req.body;
      const result = await authService.refreshToken(refreshToken);
      return ApiResponse.success(res, result, 'Token refreshed successfully');
    } catch (error) {
      next(error);
    }
  }

  // Logout
  async logout(req, res, next) {
    try {
      const { refreshToken } = req.body;
      await authService.logout(refreshToken);
      return ApiResponse.success(res, null, 'Logged out successfully');
    } catch (error) {
      next(error);
    }
  }

  // Current authenticated user (GET /api/v1/auth/me)
  async getMe(req, res, next) {
    try {
      const result = await authService.getMe(req.user._id);
      return ApiResponse.success(res, result, 'Current user profile fetched successfully');
    } catch (error) {
      next(error);
    }
  }

  // Reset password
  async resetPassword(req, res, next) {
    try {
      const { email, newPassword } = req.body;
      const result = await authService.resetPassword(email, newPassword);
      return ApiResponse.success(res, result, 'Password reset successfully');
    } catch (error) {
      next(error);
    }
  }

  // Send WhatsApp OTP (dispatched from Apna POS WhatsApp number)
  async sendWhatsappOtp(req, res, next) {
    try {
      const { phone } = req.body;
      const result = await authService.sendWhatsappOtp(phone);
      if (!result.success) {
        return res.status(400).json({
          success: false,
          isRegistered: result.isRegistered || false,
          whatsappSent: false,
          message: result.message,
        });
      }
      return ApiResponse.success(res, result, result.message);
    } catch (error) {
      next(error);
    }
  }

  // Verify WhatsApp OTP and login
  async verifyWhatsappOtp(req, res, next) {
    try {
      const { phone, otp } = req.body;
      const result = await authService.verifyWhatsappOtp(phone, otp);
      return ApiResponse.success(res, result, 'WhatsApp OTP verified successfully');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AuthController();


