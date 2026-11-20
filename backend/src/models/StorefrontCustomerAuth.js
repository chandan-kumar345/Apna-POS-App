const mongoose = require('mongoose');

const challenge = new mongoose.Schema({
  businessId: { type: mongoose.Schema.Types.ObjectId, required: true },
  phone: { type: String, required: true },
  challengeId: { type: String, required: true, unique: true },
  codeHash: { type: String, required: true, select: false },
  expiresAt: { type: Date, required: true },
  resendAt: { type: Date, required: true },
  attempts: { type: Number, default: 0 },
  delivered: { type: Boolean, default: false },
  consumedAt: { type: Date, default: null },
}, { timestamps: true });
challenge.index({ businessId: 1, phone: 1 }, { unique: true });
challenge.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

const session = new mongoose.Schema({
  businessId: { type: mongoose.Schema.Types.ObjectId, required: true },
  customerId: { type: mongoose.Schema.Types.ObjectId, required: true, ref: 'Customer' },
  phone: { type: String, required: true },
  tokenHash: { type: String, required: true, unique: true, select: false },
  expiresAt: { type: Date, required: true },
}, { timestamps: true });
session.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
module.exports = {
  Challenge: mongoose.model('StorefrontCustomerChallenge', challenge),
  Session: mongoose.model('StorefrontCustomerSession', session),
};
