const crypto = require('crypto');

/**
 * Generate a 6-digit OTP string
 */
const generateOtp = () => {
  // Generates a random 6 digit number between 100000 and 999999
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  return otp;
};

/**
 * Hash OTP before storing in DB
 */
const hashOtp = (otp) => {
  return crypto.createHash('sha256').update(otp).digest('hex');
};

/**
 * Verify OTP string against stored hash
 */
const verifyOtpHash = (otp, storedHash) => {
  const hash = hashOtp(otp);
  return hash === storedHash;
};

module.exports = {
  generateOtp,
  hashOtp,
  verifyOtpHash,
};
