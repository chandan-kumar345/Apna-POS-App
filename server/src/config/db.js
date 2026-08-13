const mongoose = require('mongoose');
const dns = require('dns');

let isConnected = false;

const connectDB = async () => {
  try {
    // Override Node.js DNS servers to Google & Cloudflare DNS to reliably resolve MongoDB Atlas SRV records
    try {
      dns.setServers(['8.8.8.8', '1.1.1.1']);
    } catch (dnsErr) {
      console.warn('💡 DNS override warning:', dnsErr.message);
    }

    const rawConnStr = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/apna_pos';
    const maskedConnStr = rawConnStr.replace(/:([^@]+)@/, ':****@');
    console.log(`Connecting to MongoDB at ${maskedConnStr}...`);

    const conn = await mongoose.connect(rawConnStr, {
      serverSelectionTimeoutMS: 5000,
    });

    isConnected = true;
    console.log(`✅ MongoDB Connected successfully: ${conn.connection.host}/${conn.connection.name}`);
    return conn;
  } catch (error) {
    console.warn(`⚠️ MongoDB connection error (${error.message}).`);
    console.warn('💡 Enabling In-Memory Store Mode for instant development & testing without local MongoDB!');
    isConnected = false;
  }
};

const getIsConnected = () => isConnected;

module.exports = { connectDB, getIsConnected };


