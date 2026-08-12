const mongoose = require('mongoose');

const sessionSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    deviceId: {
      type: String,
      required: true,
      index: true,
    },
    deviceName: {
      type: String,
      default: 'Unknown Device',
    },
    refreshTokenHash: {
      type: String,
      required: true,
    },
    ipAddress: {
      type: String,
      default: '',
    },
    userAgent: {
      type: String,
      default: '',
    },
    lastActiveAt: {
      type: Date,
      default: Date.now,
    },
    expiresAt: {
      type: Date,
      required: true,
      index: { expires: 0 }, // Auto remove expired session documents
    },
  },
  {
    timestamps: true,
  }
);

// Compound unique index so user can have 1 active session per deviceId
sessionSchema.index({ userId: 1, deviceId: 1 }, { unique: true });

module.exports = mongoose.model('Session', sessionSchema);
