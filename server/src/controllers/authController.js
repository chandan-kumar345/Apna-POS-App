const User = require('../models/User');
const Session = require('../models/Session');
const OtpVerification = require('../models/OtpVerification');
const { getIsConnected } = require('../config/db');
const { MemoryUser, MemorySession, MemoryOtp } = require('../utils/memoryStore');
const { hashPassword, comparePassword, hashToken } = require('../utils/hashUtils');
const {
  generateAccessToken,
  generateRefreshToken,
  verifyRefreshToken,
} = require('../utils/tokenUtils');
const { generateOtp, hashOtp, verifyOtpHash } = require('../utils/otpUtils');

const getModels = () => {
  if (getIsConnected()) {
    return { UserModel: User, SessionModel: Session, OtpModel: OtpVerification };
  }
  return { UserModel: MemoryUser, SessionModel: MemorySession, OtpModel: MemoryOtp };
};

/**
 * Helper to create/update device session in DB
 */
const createOrUpdateSession = async ({ userId, deviceId, deviceName, refreshToken, ipAddress, userAgent }) => {
  const { SessionModel } = getModels();
  const refreshTokenHash = hashToken(refreshToken);
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days expiry

  const session = await SessionModel.findOneAndUpdate(
    { userId, deviceId: deviceId || 'default_device' },
    {
      userId,
      deviceId: deviceId || 'default_device',
      deviceName: deviceName || 'Unknown Device',
      refreshTokenHash,
      ipAddress: ipAddress || '',
      userAgent: userAgent || '',
      lastActiveAt: new Date(),
      expiresAt,
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

  return session;
};


// ==========================================
// 1. REGISTER
// ==========================================
exports.register = async (req, res, next) => {
  try {
    const { name, email, phone, password, deviceId, deviceName, businessName } = req.body;
    const { UserModel } = getModels();

    // Check existing user
    if (email) {
      const existingEmail = await UserModel.findOne({ email: email.toLowerCase() });
      if (existingEmail) {
        return res.status(400).json({
          success: false,
          message: 'An account with this email address already exists.',
        });
      }
    }

    if (phone) {
      const existingPhone = await UserModel.findOne({ phone });
      if (existingPhone) {
        return res.status(400).json({
          success: false,
          message: 'An account with this mobile number already exists.',
        });
      }
    }

    // Hash password
    const passwordHash = await hashPassword(password);

    // Create User
    const user = await UserModel.create({
      name,
      email: email ? email.toLowerCase() : undefined,
      phone: phone || undefined,
      passwordHash,
      businessName: businessName || '',
      isVerified: true,
    });

    // Generate tokens
    const clientDeviceId = deviceId || `device_${Date.now()}`;
    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user, clientDeviceId);

    // Create session
    await createOrUpdateSession({
      userId: user._id,
      deviceId: clientDeviceId,
      deviceName,
      refreshToken,
      ipAddress: req.ip,
      userAgent: req.get('user-agent'),
    });

    res.status(201).json({
      success: true,
      message: 'Account created successfully',
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        businessName: user.businessName,
        role: user.role,
      },
      accessToken,
      refreshToken,
      deviceId: clientDeviceId,
    });
  } catch (error) {
    next(error);
  }
};

// ==========================================
// 2. LOGIN (Email/Phone + Password)
// ==========================================
exports.login = async (req, res, next) => {
  try {
    const { identifier, email, phone, password, deviceId, deviceName } = req.body;
    const loginKey = identifier || email || phone;
    const { UserModel } = getModels();

    if (!loginKey || !password) {
      return res.status(400).json({
        success: false,
        message: 'Please provide email/phone and password.',
      });
    }

    // Find user by email or phone
    const user = await UserModel.findOne({
      $or: [
        { email: loginKey.toLowerCase() },
        { phone: loginKey },
      ],
    }).select('+passwordHash');

    if (!user || !user.passwordHash) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials. User not found or incorrect password.',
      });
    }

    // Compare password
    const isMatch = await comparePassword(password, user.passwordHash);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials. Password does not match.',
      });
    }

    const clientDeviceId = deviceId || `device_${Date.now()}`;
    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user, clientDeviceId);

    await createOrUpdateSession({
      userId: user._id,
      deviceId: clientDeviceId,
      deviceName,
      refreshToken,
      ipAddress: req.ip,
      userAgent: req.get('user-agent'),
    });

    res.status(200).json({
      success: true,
      message: 'Login successful',
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        businessName: user.businessName,
        role: user.role,
      },
      accessToken,
      refreshToken,
      deviceId: clientDeviceId,
    });
  } catch (error) {
    next(error);
  }
};

// ==========================================
// 3. SEND OTP
// ==========================================
exports.sendOtp = async (req, res, next) => {
  try {
    const { phone, purpose = 'login' } = req.body;
    const { OtpModel } = getModels();

    if (!phone) {
      return res.status(400).json({
        success: false,
        message: 'Mobile number is required to send OTP.',
      });
    }

    // Generate 6-digit OTP
    const otp = process.env.NODE_ENV === 'test' || process.env.NODE_ENV === 'development' ? '123456' : generateOtp();
    const otpHash = hashOtp(otp);
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes expiration

    // Remove existing OTP for this phone & purpose
    await OtpModel.deleteMany({ phone, purpose });

    await OtpModel.create({
      phone,
      otpHash,
      purpose,
      expiresAt,
    });

    console.log(`📱 [OTP SENT] Phone: ${phone} | Code: ${otp} | Expires: 5m`);

    res.status(200).json({
      success: true,
      message: 'OTP sent successfully to your mobile number.',
      devOtp: process.env.NODE_ENV !== 'production' ? otp : undefined,
    });
  } catch (error) {
    next(error);
  }
};

// ==========================================
// 4. VERIFY OTP & LOGIN/REGISTER
// ==========================================
exports.verifyOtp = async (req, res, next) => {
  try {
    const { phone, otp, name, deviceId, deviceName } = req.body;
    const { UserModel, OtpModel } = getModels();

    if (!phone || !otp) {
      return res.status(400).json({
        success: false,
        message: 'Phone number and OTP code are required.',
      });
    }

    const record = await OtpModel.findOne({ phone }).sort({ createdAt: -1 });
    if (!record) {
      return res.status(400).json({
        success: false,
        message: 'OTP expired or not found. Please request a new OTP.',
      });
    }

    if (record.attempts >= 5) {
      await OtpModel.deleteOne({ _id: record._id });
      return res.status(429).json({
        success: false,
        message: 'Too many failed attempts. Please request a new OTP.',
      });
    }

    const isValid = verifyOtpHash(otp, record.otpHash);
    if (!isValid) {
      record.attempts += 1;
      await record.save();
      return res.status(400).json({
        success: false,
        message: 'Invalid OTP code. Please try again.',
      });
    }

    // OTP is valid - delete record
    await OtpModel.deleteOne({ _id: record._id });

    // Find or create user
    let user = await UserModel.findOne({ phone });
    let isNewUser = false;

    if (!user) {
      user = await UserModel.create({
        name: name || `User ${phone.slice(-4)}`,
        phone,
        isVerified: true,
      });
      isNewUser = true;
    } else if (!user.isVerified) {
      user.isVerified = true;
      await user.save();
    }

    const clientDeviceId = deviceId || `device_${Date.now()}`;
    const accessToken = generateAccessToken(user);
    const refreshToken = generateRefreshToken(user, clientDeviceId);

    await createOrUpdateSession({
      userId: user._id,
      deviceId: clientDeviceId,
      deviceName,
      refreshToken,
      ipAddress: req.ip,
      userAgent: req.get('user-agent'),
    });

    res.status(200).json({
      success: true,
      message: isNewUser ? 'User registered and logged in with OTP' : 'Login successful',
      isNewUser,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        businessName: user.businessName,
        role: user.role,
      },
      accessToken,
      refreshToken,
      deviceId: clientDeviceId,
    });
  } catch (error) {
    next(error);
  }
};

// ==========================================
// 5. REFRESH ACCESS TOKEN
// ==========================================
exports.refreshToken = async (req, res, next) => {
  try {
    const { refreshToken, deviceId } = req.body;
    const { UserModel, SessionModel } = getModels();

    if (!refreshToken) {
      return res.status(400).json({
        success: false,
        message: 'Refresh token is required.',
      });
    }

    const decoded = verifyRefreshToken(refreshToken);
    if (!decoded) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired refresh token. Please login again.',
      });
    }

    const clientDeviceId = deviceId || decoded.deviceId;
    const incomingTokenHash = hashToken(refreshToken);

    // Verify active session in DB
    const session = await SessionModel.findOne({
      userId: decoded.id,
      deviceId: clientDeviceId,
    });

    if (!session || session.refreshTokenHash !== incomingTokenHash) {
      return res.status(401).json({
        success: false,
        message: 'Session revoked or invalid refresh token.',
      });
    }

    const user = await UserModel.findById(decoded.id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User account not found.',
      });
    }

    // Generate new Access Token
    const newAccessToken = generateAccessToken(user);
    
    // Optionally rotate refresh token
    const newRefreshToken = generateRefreshToken(user, clientDeviceId);
    session.refreshTokenHash = hashToken(newRefreshToken);
    session.lastActiveAt = new Date();
    await session.save();

    res.status(200).json({
      success: true,
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    });
  } catch (error) {
    next(error);
  }
};

// ==========================================
// 6. LOGOUT (CURRENT DEVICE)
// ==========================================
exports.logout = async (req, res, next) => {
  try {
    const { deviceId } = req.body;
    const { SessionModel } = getModels();
    const clientDeviceId = deviceId || req.user?.deviceId;

    if (req.userId && clientDeviceId) {
      await SessionModel.deleteOne({ userId: req.userId, deviceId: clientDeviceId });
    }

    res.status(200).json({
      success: true,
      message: 'Logged out successfully from this device.',
    });
  } catch (error) {
    next(error);
  }
};

// ==========================================
// 7. LOGOUT ALL DEVICES
// ==========================================
exports.logoutAll = async (req, res, next) => {
  try {
    const { SessionModel } = getModels();

    if (req.userId) {
      await SessionModel.deleteMany({ userId: req.userId });
    }

    res.status(200).json({
      success: true,
      message: 'Logged out from all devices successfully.',
    });
  } catch (error) {
    next(error);
  }
};

// ==========================================
// 8. GET CURRENT USER PROFILE
// ==========================================
exports.getMe = async (req, res, next) => {
  try {
    const { UserModel } = getModels();
    const user = await UserModel.findById(req.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User profile not found.',
      });
    }

    res.status(200).json({
      success: true,
      user,
    });
  } catch (error) {
    next(error);
  }
};

// ==========================================
// 9. GET ACTIVE DEVICES
// ==========================================
exports.getDevices = async (req, res, next) => {
  try {
    const { SessionModel } = getModels();
    const sessions = await SessionModel.find({ userId: req.userId });

    const devices = sessions.map((s) => ({
      deviceId: s.deviceId,
      deviceName: s.deviceName,
      ipAddress: s.ipAddress,
      lastActiveAt: s.lastActiveAt,
      createdAt: s.createdAt,
    }));

    res.status(200).json({
      success: true,
      count: devices.length,
      devices,
    });
  } catch (error) {
    next(error);
  }
};

// ==========================================
// 10. REVOKE SPECIFIC DEVICE
// ==========================================
exports.revokeDevice = async (req, res, next) => {
  try {
    const { deviceId } = req.params;
    const { SessionModel } = getModels();

    const result = await SessionModel.deleteOne({ userId: req.userId, deviceId });

    if (result.deletedCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Device session not found or already revoked.',
      });
    }

    res.status(200).json({
      success: true,
      message: `Device '${deviceId}' has been revoked successfully.`,
    });
  } catch (error) {
    next(error);
  }
};

