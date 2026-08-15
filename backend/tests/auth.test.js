const request = require('supertest');
const app = require('../src/app');
require('./setup');

describe('Authentication APIs (/api/v1/auth)', () => {
  const validUser = {
    email: 'restaurant_owner@example.com',
    password: 'SecurePassword@123',
  };

  describe('POST /api/v1/auth/register', () => {
    it('should register a new user successfully and return access & refresh tokens', async () => {
      const res = await request(app)
        .post('/api/v1/auth/register')
        .send(validUser);

      expect(res.status).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.data.user).toBeDefined();
      expect(res.body.data.user.email).toBe(validUser.email);
      expect(res.body.data.user.onboardingCompleted).toBe(false);
      expect(res.body.data.user.onboardingStep).toBe(0);
      expect(res.body.data.user.passwordHash).toBeUndefined();
      expect(res.body.data.accessToken).toBeDefined();
      expect(res.body.data.refreshToken).toBeDefined();
    });

    it('should reject duplicate email registration with 409 Conflict', async () => {
      await request(app).post('/api/v1/auth/register').send(validUser);

      const res = await request(app)
        .post('/api/v1/auth/register')
        .send(validUser);

      expect(res.status).toBe(409);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('EMAIL_ALREADY_EXISTS');
    });

    it('should reject invalid email formats with 422 Validation Error', async () => {
      const res = await request(app)
        .post('/api/v1/auth/register')
        .send({
          email: 'not-an-email',
          password: 'SecurePassword@123',
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.fields.email).toBeDefined();
    });

    it('should reject weak passwords with 422 Validation Error', async () => {
      const res = await request(app)
        .post('/api/v1/auth/register')
        .send({
          email: 'test@example.com',
          password: 'weak',
        });

      expect(res.status).toBe(422);
      expect(res.body.success).toBe(false);
      expect(res.body.error.fields.password).toBeDefined();
    });
  });

  describe('POST /api/v1/auth/login', () => {
    beforeEach(async () => {
      await request(app).post('/api/v1/auth/register').send(validUser);
    });

    it('should log in successfully with correct credentials', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send(validUser);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.accessToken).toBeDefined();
      expect(res.body.data.refreshToken).toBeDefined();
      expect(res.body.data.user.email).toBe(validUser.email);
      expect(res.body.data.user.passwordHash).toBeUndefined();
    });

    it('should reject login with wrong password', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: validUser.email,
          password: 'WrongPassword@999',
        });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('INVALID_CREDENTIALS');
    });

    it('should reject login for nonexistent user', async () => {
      const res = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: 'unknown@example.com',
          password: 'SecurePassword@123',
        });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
    });
  });

  describe('POST /api/v1/auth/refresh & POST /api/v1/auth/logout', () => {
    it('should refresh access token using valid refresh token and rotate refresh token', async () => {
      const registerRes = await request(app)
        .post('/api/v1/auth/register')
        .send(validUser);

      const refreshToken = registerRes.body.data.refreshToken;

      const refreshRes = await request(app)
        .post('/api/v1/auth/refresh')
        .send({ refreshToken });

      expect(refreshRes.status).toBe(200);
      expect(refreshRes.body.success).toBe(true);
      expect(refreshRes.body.data.accessToken).toBeDefined();
      expect(refreshRes.body.data.refreshToken).toBeDefined();

      // Old refresh token must now be revoked
      const reuseRes = await request(app)
        .post('/api/v1/auth/refresh')
        .send({ refreshToken });

      expect(reuseRes.status).toBe(401);
      expect(reuseRes.body.error.code).toBe('REVOKED_REFRESH_TOKEN');
    });

    it('should revoke refresh token on logout', async () => {
      const registerRes = await request(app)
        .post('/api/v1/auth/register')
        .send(validUser);

      const refreshToken = registerRes.body.data.refreshToken;

      const logoutRes = await request(app)
        .post('/api/v1/auth/logout')
        .send({ refreshToken });

      expect(logoutRes.status).toBe(200);

      // Attempting to refresh with logged-out token should fail
      const refreshRes = await request(app)
        .post('/api/v1/auth/refresh')
        .send({ refreshToken });

      expect(refreshRes.status).toBe(401);
    });
  });

  describe('GET /api/v1/auth/me', () => {
    it('should return current user information when authenticated', async () => {
      const registerRes = await request(app)
        .post('/api/v1/auth/register')
        .send(validUser);

      const token = registerRes.body.data.accessToken;

      const meRes = await request(app)
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${token}`);

      expect(meRes.status).toBe(200);
      expect(meRes.body.success).toBe(true);
      expect(meRes.body.data.user.email).toBe(validUser.email);
      expect(meRes.body.data.business).toBeDefined();
    });

    it('should reject unauthorized requests without token', async () => {
      const meRes = await request(app).get('/api/v1/auth/me');
      expect(meRes.status).toBe(401);
      expect(meRes.body.success).toBe(false);
    });
  });

  describe('POST /api/v1/auth/reset-password', () => {
    it('should reset password successfully and allow login with new password', async () => {
      await request(app)
        .post('/api/v1/auth/register')
        .send(validUser);

      const resetRes = await request(app)
        .post('/api/v1/auth/reset-password')
        .send({
          email: validUser.email,
          newPassword: 'BrandNewPassword@2026',
        });

      expect(resetRes.status).toBe(200);
      expect(resetRes.body.success).toBe(true);

      // Old password should fail
      const oldLoginRes = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: validUser.email,
          password: validUser.password,
        });
      expect(oldLoginRes.status).toBe(401);

      // New password should succeed
      const newLoginRes = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: validUser.email,
          password: 'BrandNewPassword@2026',
        });
      expect(newLoginRes.status).toBe(200);
      expect(newLoginRes.body.data.accessToken).toBeDefined();
    });

    it('should reject reset password for nonexistent user', async () => {
      const resetRes = await request(app)
        .post('/api/v1/auth/reset-password')
        .send({
          email: 'unknown_user_999@test.com',
          newPassword: 'BrandNewPassword@2026',
        });

      expect(resetRes.status).toBe(404);
      expect(resetRes.body.success).toBe(false);
    });
  });
});

