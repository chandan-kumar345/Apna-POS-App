const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const env = require('./config/env');
const routes = require('./routes');
const { notFoundHandler, errorHandler } = require('./middleware/errorMiddleware');

const app = express();

// Trust proxy for tunnels / cloud load balancers
app.set('trust proxy', 1);

// 1. Security Headers (allow cross-origin media rendering)
app.use(
  helmet({
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  })
);

// 2. CORS Configuration
app.use(
  cors({
    origin: env.CLIENT_URL === '*' ? '*' : env.CLIENT_URL.split(','),
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Device-ID', 'X-Request-Timestamp', 'Bypass-Tunnel-Reminder'],
    credentials: true,
  })
);

// 3. Rate Limiting for production security
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // Limit each IP to 1000 requests per windowMs
  standardHeaders: true,
  legacyHeaders: false,
  validate: { xForwardedForHeader: false },
  message: {
    success: false,
    error: {
      code: 'TOO_MANY_REQUESTS',
      message: 'Too many requests from this IP, please try again after 15 minutes',
    },
  },
  skip: (req) => env.NODE_ENV === 'test' || env.NODE_ENV === 'development' || req.ip === '127.0.0.1' || req.ip === '::1' || req.ip === '::ffff:127.0.0.1',
});
app.use(limiter);

// 4. Request Logging
if (env.NODE_ENV !== 'test') {
  app.use(morgan('dev'));
}

const path = require('path');

// 5. Body Parsers (preserve rawBody for HMAC webhook verification)
app.use(
  express.json({
    limit: '10mb',
    verify: (req, res, buf) => {
      req.rawBody = buf;
    },
  })
);
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// 6. Serve static uploads (local fallback with cross-origin headers)
app.use(
  '/uploads',
  express.static(path.join(__dirname, '../public/uploads'), {
    setHeaders: (res) => {
      res.set('Access-Control-Allow-Origin', '*');
      res.set('Cross-Origin-Resource-Policy', 'cross-origin');
    },
  })
);

// 7. Mount Versioned APIs under /api/v1
app.use('/api/v1', routes);

// 7. Root ping
app.get('/', (req, res) => {
  res.json({
    name: 'Apna POS Backend API',
    version: '1.0.0',
    status: 'running',
    apiDocs: '/api/v1/health',
  });
});

// 8. 404 and Global Error Handling
app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
