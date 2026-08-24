const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../../.env') });

// Determine Razorpay Mode ('test' or 'live')
const rawMode = (process.env.RAZORPAY_MODE || (process.env.NODE_ENV === 'production' ? 'live' : 'test')).toLowerCase();
const isLiveMode = rawMode === 'live' || rawMode === 'production' || rawMode === 'prod';
const activeMode = isLiveMode ? 'live' : 'test';

// Dynamically resolve active keys based on active mode
const activeKeyId = isLiveMode
  ? (process.env.RAZORPAY_LIVE_KEY_ID || process.env.RAZORPAY_KEY_ID || '')
  : (process.env.RAZORPAY_TEST_KEY_ID || process.env.RAZORPAY_KEY_ID || '');

const activeKeySecret = isLiveMode
  ? (process.env.RAZORPAY_LIVE_KEY_SECRET || process.env.RAZORPAY_KEY_SECRET || '')
  : (process.env.RAZORPAY_TEST_KEY_SECRET || process.env.RAZORPAY_KEY_SECRET || '');

const activeWebhookSecret = isLiveMode
  ? (process.env.RAZORPAY_LIVE_WEBHOOK_SECRET || process.env.RAZORPAY_WEBHOOK_SECRET || '')
  : (process.env.RAZORPAY_TEST_WEBHOOK_SECRET || process.env.RAZORPAY_WEBHOOK_SECRET || '');

module.exports = {
  NODE_ENV: process.env.NODE_ENV || 'development',
  PORT: process.env.PORT || 5000,
  MONGODB_URI: process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/apna_pos',
  JWT_ACCESS_SECRET: process.env.JWT_ACCESS_SECRET || 'default_jwt_access_secret_for_development_mode_only',
  JWT_REFRESH_SECRET: process.env.JWT_REFRESH_SECRET || 'default_jwt_refresh_secret_for_development_mode_only',
  JWT_ACCESS_EXPIRES_IN: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
  JWT_REFRESH_EXPIRES_IN: process.env.JWT_REFRESH_EXPIRES_IN || '7d',
  CLIENT_URL: process.env.CLIENT_URL || '*',

  // Razorpay Active Mode & Resolved Keys
  RAZORPAY_MODE: activeMode,
  RAZORPAY_KEY_ID: activeKeyId,
  RAZORPAY_KEY_SECRET: activeKeySecret,
  RAZORPAY_WEBHOOK_SECRET: activeWebhookSecret,

  // Test Mode Credentials
  RAZORPAY_TEST_KEY_ID: process.env.RAZORPAY_TEST_KEY_ID || '',
  RAZORPAY_TEST_KEY_SECRET: process.env.RAZORPAY_TEST_KEY_SECRET || '',
  RAZORPAY_TEST_WEBHOOK_SECRET: process.env.RAZORPAY_TEST_WEBHOOK_SECRET || '',

  // Live / Production Credentials
  RAZORPAY_LIVE_KEY_ID: process.env.RAZORPAY_LIVE_KEY_ID || '',
  RAZORPAY_LIVE_KEY_SECRET: process.env.RAZORPAY_LIVE_KEY_SECRET || '',
  RAZORPAY_LIVE_WEBHOOK_SECRET: process.env.RAZORPAY_LIVE_WEBHOOK_SECRET || '',
};
