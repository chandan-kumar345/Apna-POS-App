const jwt = require('jsonwebtoken');

const getAccessSecret = () => process.env.JWT_ACCESS_SECRET || 'apna_pos_jwt_access_secret_key_2026_super_secure_987654321';
const getRefreshSecret = () => process.env.JWT_REFRESH_SECRET || 'apna_pos_jwt_refresh_secret_key_2026_super_secure_123456789';

const generateAccessToken = (user) => {
  return jwt.sign(
    {
      id: user._id || user.id,
      email: user.email,
      phone: user.phone,
      role: user.role,
    },
    getAccessSecret(),
    {
      expiresIn: process.env.JWT_ACCESS_EXPIRE || '15m',
    }
  );
};

const generateRefreshToken = (user, deviceId) => {
  return jwt.sign(
    {
      id: user._id || user.id,
      deviceId: deviceId,
    },
    getRefreshSecret(),
    {
      expiresIn: process.env.JWT_REFRESH_EXPIRE || '30d',
    }
  );
};

const verifyAccessToken = (token) => {
  try {
    return jwt.verify(token, getAccessSecret());
  } catch (error) {
    return null;
  }
};

const verifyRefreshToken = (token) => {
  try {
    return jwt.verify(token, getRefreshSecret());
  } catch (error) {
    return null;
  }
};

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
};
