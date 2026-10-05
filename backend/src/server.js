// Apna POS Server Entrypoint
const http = require('http');
const app = require('./app');
const env = require('./config/env');
const { connectDB } = require('./config/db');
const cronService = require('./services/cronService');
const socketService = require('./services/socketService');

const superadminService = require('./services/superadminService');
const dbWatcherService = require('./services/dbWatcherService');

const startServer = async () => {
  try {
    const server = http.createServer(app);

    // Initialize Socket.IO with the HTTP Server
    socketService.init(server);

    server.listen(env.PORT, '0.0.0.0', () => {
      console.log(`================================================`);
      console.log(` Apna POS Backend Server Running (with Socket.IO)`);
      console.log(` Environment: ${env.NODE_ENV}`);
      console.log(` Port:        ${env.PORT}`);
      console.log(` Web Admin:   http://localhost:${env.PORT}/admin`);
      console.log(` Local:       http://localhost:${env.PORT}/api/v1/health`);
      console.log(` Network:     http://0.0.0.0:${env.PORT}/api/v1/health`);
      console.log(`================================================`);
    });

    // Connect to Database asynchronously
    connectDB()
      .then(async () => {
        // Ensure Master SuperAdmin user is seeded and active
        await superadminService.seedSuperAdmin();

        // Initialize daily summary cron jobs after DB is connected
        cronService.initSchedulers();

        // Initialize Realtime MongoDB Change Stream Watchers for Compass Updates
        dbWatcherService.init();
      })
      .catch((err) => {
        console.error(`[MongoDB Connection Error] ${err.message}`);
      });

    server.on('error', (err) => {
      if (err.code === 'EADDRINUSE') {
        console.error(`[Server Error] Port ${env.PORT} is already in use.`);
        console.error(`Please terminate any other node instances or terminals using port ${env.PORT}.`);
      } else {
        console.error(`[Server Error] ${err.message}`);
      }
    });

    // Graceful Shutdown
    const exitHandler = () => {
      cronService.stopSchedulers();
      if (server) {
        server.close(() => {
          console.log('[Server] Process closed gracefully');
          process.exit(0);
        });
      } else {
        process.exit(0);
      }
    };

    process.on('SIGTERM', exitHandler);
    process.on('SIGINT', exitHandler);
  } catch (error) {
    console.error(`[Server Start Error] ${error.message}`);
    process.exit(1);
  }
};

startServer();
