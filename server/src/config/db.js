const mongoose = require('mongoose');

let isConnected = false;

const connectDB = async () => {
  try {
    const connStr = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/apna_pos';
    console.log(`Connecting to MongoDB at ${connStr}...`);

    const conn = await mongoose.connect(connStr, {
      serverSelectionTimeoutMS: 2000,
    });

    isConnected = true;
    console.log(`MongoDB Connected: ${conn.connection.host}/${conn.connection.name}`);
    return conn;
  } catch (error) {
    console.warn(`⚠️ MongoDB service not detected (${error.message}).`);
    console.warn('💡 Enabling In-Memory Store Mode for instant development & testing without local MongoDB!');
    isConnected = false;
  }
};

const getIsConnected = () => isConnected;

module.exports = { connectDB, getIsConnected };

