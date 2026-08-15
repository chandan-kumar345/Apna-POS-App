const mongoose = require('mongoose');
const env = require('./env');

const connectDB = async (uriOverride) => {
  try {
    const mongoUri = uriOverride || env.MONGODB_URI;
    const conn = await mongoose.connect(mongoUri, {
      autoIndex: true,
    });
    if (env.NODE_ENV !== 'test') {
      console.log(`[MongoDB] Connected successfully: ${conn.connection.host}/${conn.connection.name}`);
    }
    return conn;
  } catch (error) {
    console.error(`[MongoDB Connection Error] ${error.message}`);
    if (env.NODE_ENV !== 'test') {
      process.exit(1);
    }
    throw error;
  }
};

const disconnectDB = async () => {
  try {
    await mongoose.disconnect();
    if (env.NODE_ENV !== 'test') {
      console.log('[MongoDB] Disconnected');
    }
  } catch (error) {
    console.error(`[MongoDB Disconnect Error] ${error.message}`);
  }
};

module.exports = { connectDB, disconnectDB };
