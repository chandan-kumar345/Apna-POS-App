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

// 2. CORS Configuration (Full support for browser web clients e.g. Vercel, localhost, Android & Windows)
const allowedCorsHeaders = [
  'Content-Type',
  'Authorization',
  'X-Device-ID',
  'x-device-id',
  'X-Business-ID',
  'x-business-id',
  'X-Request-Timestamp',
  'x-request-timestamp',
  'Bypass-Tunnel-Reminder',
  'bypass-tunnel-reminder',
  'Accept',
  'Origin',
  'X-Requested-With',
  'Access-Control-Request-Method',
  'Access-Control-Request-Headers',
];

const corsOptions = {
  origin: (origin, callback) => {
    // Reflect caller origin so credentials (cookies/Bearer tokens) succeed across browsers without wildcard rejection
    callback(null, true);
  },
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: allowedCorsHeaders,
  exposedHeaders: ['Content-Range', 'X-Content-Range'],
  credentials: true,
  maxAge: 86400, // Cache preflight for 24h
};

app.use(cors(corsOptions));
app.options('*', cors(corsOptions));

// 3. Rate Limiting for production security
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20000, // Limit each IP to 20000 requests per windowMs
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
  skip: (req) => {
    if (req.method === 'OPTIONS') return true;
    if (env.NODE_ENV === 'test' || env.NODE_ENV === 'development') return true;
    const ip = req.ip || req.connection?.remoteAddress || '';
    return (
      ip.includes('127.0.0.1') ||
      ip.includes('::1') ||
      ip.startsWith('172.') ||
      ip.startsWith('192.168.') ||
      ip.startsWith('10.') ||
      ip.includes('::ffff:172.') ||
      ip.includes('::ffff:192.168.') ||
      ip.includes('::ffff:10.')
    );
  },
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

// 6b. Serve Super Admin Web Dashboard
const adminPublicPath = path.join(__dirname, '../public/admin');
app.use('/admin', express.static(adminPublicPath));
app.use('/dashboard', express.static(adminPublicPath));

// Route /admin and /dashboard requests to index.html
app.get(['/admin', '/admin/*', '/dashboard', '/dashboard/*'], (req, res) => {
  res.sendFile(path.join(adminPublicPath, 'index.html'));
});

// 7. Mount Versioned APIs under /api/v1 and /api
app.use('/api/v1', routes);
app.use('/api', routes);

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
