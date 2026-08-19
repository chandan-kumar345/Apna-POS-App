const mongoose = require('mongoose');
const env = require('./env');

const dns = require('dns');

// Set public DNS fallback for Windows environments where local DNS servers refuse SRV lookups
try {
  dns.setServers(['8.8.8.8', '1.1.1.1', '8.8.4.4']);
} catch (e) {
  // Ignore if custom DNS servers cannot be set
}

const connectDB = async (uriOverride) => {
  const primaryUri = uriOverride || env.MONGODB_URI;
  const fallbackUri = 'mongodb://127.0.0.1:27017/apna_pos';

  try {
    const conn = await mongoose.connect(primaryUri, {
      autoIndex: true,
      serverSelectionTimeoutMS: 5000,
    });
    if (env.NODE_ENV !== 'test') {
      console.log(`[MongoDB] Connected successfully: ${conn.connection.host}/${conn.connection.name}`);
    }
    return conn;
  } catch (primaryError) {
    console.error(`[MongoDB Connection Warning] Primary URI connection failed (${primaryError.message}).`);

    if (primaryUri !== fallbackUri) {
      try {
        console.log(`[MongoDB] Attempting fallback to local database (${fallbackUri})...`);
        const conn = await mongoose.connect(fallbackUri, {
          autoIndex: true,
          serverSelectionTimeoutMS: 3000,
        });
        console.log(`[MongoDB] Connected successfully to fallback DB: ${conn.connection.host}/${conn.connection.name}`);
        return conn;
      } catch (fallbackError) {
        console.error(`[MongoDB Connection Error] Local fallback also failed: ${fallbackError.message}`);
      }
    }

    if (env.NODE_ENV !== 'test') {
      console.warn(`[MongoDB Warning] Server will start without active DB connection. Retrying in background...`);
      setTimeout(() => connectDB(primaryUri).catch(() => {}), 10000);
    }
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
