const authService = require('../services/authService');
const ApiResponse = require('../utils/ApiResponse');

class AuthController {
  // Register
  async register(req, res, next) {
    try {
      const { email, password } = req.body;
      const result = await authService.register(email, password);
      return ApiResponse.created(res, result, 'User registered successfully');
    } catch (error) {
      next(error);
    }
  }

  // Login
  async login(req, res, next) {
    try {
      const { email, password } = req.body;
      const result = await authService.login(email, password);
      return ApiResponse.success(res, result, 'Login successful');
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
}

module.exports = new AuthController();


