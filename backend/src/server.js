const app = require('./app');
const env = require('./config/env');
const { connectDB } = require('./config/db');

const startServer = async () => {
  try {
    await connectDB();

    const server = app.listen(env.PORT, '0.0.0.0', () => {
      console.log(`================================================`);
      console.log(` Apna POS Backend Server Running`);
      console.log(` Environment: ${env.NODE_ENV}`);
      console.log(` Port:        ${env.PORT}`);
      console.log(` Local:       http://localhost:${env.PORT}/api/v1/health`);
      console.log(` Network:     http://0.0.0.0:${env.PORT}/api/v1/health`);
      console.log(`================================================`);
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
