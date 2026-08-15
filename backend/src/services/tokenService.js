const jwt = require('jsonwebtoken');
const env = require('../config/env');
const RefreshToken = require('../models/RefreshToken');
const ApiError = require('../utils/ApiError');

class TokenService {
  // Generate Access Token (JWT)
  generateAccessToken(user) {
    const payload = {
      sub: user._id || user.id,
      email: user.email,
      role: user.role,
    };
    return jwt.sign(payload, env.JWT_ACCESS_SECRET, {
      expiresIn: env.JWT_ACCESS_EXPIRES_IN,
    });
  }

  // Generate Refresh Token & save to DB
  async generateRefreshToken(user) {
    const crypto = require('crypto');
    const payload = {
      sub: user._id || user.id,
      jti: crypto.randomUUID(),
    };
    const token = jwt.sign(payload, env.JWT_REFRESH_SECRET, {
      expiresIn: env.JWT_REFRESH_EXPIRES_IN,
    });


    // Decode to get expiration date
    const decoded = jwt.decode(token);
    const expiresAt = new Date(decoded.exp * 1000);

    const refreshTokenDoc = await RefreshToken.create({
      token,
      userId: user._id || user.id,
      expiresAt,
    });

    return refreshTokenDoc.token;
  }

  // Generate both Access & Refresh tokens
  async generateAuthTokens(user) {
    const accessToken = this.generateAccessToken(user);
    const refreshToken = await this.generateRefreshToken(user);

    return {
      accessToken,
      refreshToken,
      tokenType: 'Bearer',
      expiresIn: env.JWT_ACCESS_EXPIRES_IN,
    };
  }

  // Verify Access Token
  verifyAccessToken(token) {
    try {
      return jwt.verify(token, env.JWT_ACCESS_SECRET);
    } catch (error) {
      if (error.name === 'TokenExpiredError') {
        throw ApiError.unauthorized('Access token has expired', 'TOKEN_EXPIRED');
      }
      throw ApiError.unauthorized('Invalid access token', 'INVALID_TOKEN');
    }
  }

  // Verify Refresh Token and Rotate
  async refreshAuthTokens(rawRefreshToken) {
    if (!rawRefreshToken) {
      throw ApiError.badRequest('Refresh token is required', null, 'REFRESH_TOKEN_REQUIRED');
    }

    let payload;
    try {
      payload = jwt.verify(rawRefreshToken, env.JWT_REFRESH_SECRET);
    } catch (error) {
      if (error.name === 'TokenExpiredError') {
        throw ApiError.unauthorized('Refresh token has expired', 'REFRESH_TOKEN_EXPIRED');
      }
      throw ApiError.unauthorized('Invalid refresh token', 'INVALID_REFRESH_TOKEN');
    }

    const tokenDoc = await RefreshToken.findOne({ token: rawRefreshToken });

    if (!tokenDoc || tokenDoc.isRevoked) {
      throw ApiError.unauthorized('Refresh token is revoked or invalid', 'REVOKED_REFRESH_TOKEN');
    }

    // Revoke old token and issue new pair (Token Rotation)
    tokenDoc.isRevoked = true;
    await tokenDoc.save();

    const User = require('../models/User');
    const user = await User.findById(payload.sub);
    if (!user) {
      throw ApiError.unauthorized('User associated with token no longer exists', 'USER_NOT_FOUND');
    }

    const newAccessToken = this.generateAccessToken(user);
    const newRefreshToken = await this.generateRefreshToken(user);

    tokenDoc.replacedByToken = newRefreshToken;
    await tokenDoc.save();

    return {
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
      tokenType: 'Bearer',
      expiresIn: env.JWT_ACCESS_EXPIRES_IN,
    };
  }

  // Revoke token on logout
  async revokeRefreshToken(token) {
    if (!token) return;
    await RefreshToken.findOneAndUpdate(
      { token },
      { isRevoked: true }
    );
  }

  // Revoke all tokens for user (e.g. on password reset)
  async revokeAllUserTokens(userId) {
    if (!userId) return;
    await RefreshToken.updateMany(
      { userId, isRevoked: false },
      { isRevoked: true }
    );
  }
}

module.exports = new TokenService();

