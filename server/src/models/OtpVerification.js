const mongoose = require('mongoose');

const otpVerificationSchema = new mongoose.Schema(
  {
    phone: {
      type: String,
      required: true,
      index: true,
    },
    otpHash: {
      type: String,
      required: true,
    },
    purpose: {
      type: String,
      enum: ['login', 'register', 'reset_password'],
      default: 'login',
    },
    attempts: {
      type: Number,
      default: 0,
    },
    expiresAt: {
      type: Date,
      required: true,
      index: { expires: 0 }, // TTL index to auto-delete after expiration (5-10 minutes)
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('OtpVerification', otpVerificationSchema);
