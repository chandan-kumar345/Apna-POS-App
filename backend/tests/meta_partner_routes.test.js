const express = require('express');
const request = require('supertest');
jest.mock('../src/services/metaPartnerService', () => ({
  startEmbeddedSignup: jest.fn(async () => ({ url: 'https://example.test/signup' })),
  completeEmbeddedSignup: jest.fn(async () => ({ partnerStatus: 'SETUP_REQUIRED' })),
  getPartnerStatus: jest.fn(async () => ({ partnerStatus: 'NOT_CONFIGURED' })),
}));
jest.mock('../src/middleware/authMiddleware', () => (req, res, next) => {
  if (!req.headers['test-role']) return res.status(401).json({ success: false });
  req.user = { _id: 'user-1', role: req.headers['test-role'] }; req.businessId = 'business-1'; next();
});
const service = require('../src/services/metaPartnerService');
const app = express();
app.use(express.json());
app.use('/meta-partner', require('../src/routes/metaPartnerRoutes'));
app.use((error, req, res, next) => res.status(error.statusCode || 500).json({ success: false, message: error.message }));
test('only an authenticated owner/admin can create a signup session', async () => {
  expect((await request(app).post('/meta-partner/onboarding/start')).status).toBe(401);
  expect((await request(app).post('/meta-partner/onboarding/start').set('test-role', 'cashier')).status).toBe(403);
  expect((await request(app).post('/meta-partner/onboarding/start').set('test-role', 'owner')).status).toBe(200);
  expect(service.startEmbeddedSignup).toHaveBeenCalledWith('business-1', { userId: 'user-1' });
});
test('browser bridge has no app secret and uses exact trusted origins and nonce CSP', async () => {
  process.env.META_APP_ID = 'test-app'; process.env.META_EMBEDDED_SIGNUP_CONFIG_ID = 'test-config';
  process.env.META_APP_SECRET = 'server-only-secret';
  const result = await request(app).get('/meta-partner/onboarding');
  expect(result.status).toBe(200);
  expect(result.headers['cache-control']).toBe('no-store');
  expect(result.headers['referrer-policy']).toBe('no-referrer');
  expect(result.headers['content-security-policy']).toContain("frame-ancestors 'none'");
  expect(result.headers['content-security-policy']).toContain("script-src 'nonce-");
  expect(result.text).not.toContain('server-only-secret');
  expect(result.text).toContain("['www.facebook.com','web.facebook.com','business.facebook.com'].includes(origin.hostname)");
  expect(result.text).toContain("history.replaceState(null,'',location.pathname)");
  expect(result.text).not.toContain('sessionInfoVersion');
  expect(result.text).toContain('extras:{setup:{}}');
});
