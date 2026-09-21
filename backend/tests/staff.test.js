const request = require('supertest');
const app = require('../src/app');
require('./setup');

describe('Staff Management & Authentication APIs', () => {
  let ownerToken;
  let businessId;

  const ownerCredentials = {
    email: 'store_owner_staff_test@example.com',
    password: 'OwnerPassword@123',
  };

  beforeEach(async () => {
    // Register owner
    const regRes = await request(app)
      .post('/api/v1/auth/register')
      .send(ownerCredentials);

    ownerToken = regRes.body.data.accessToken;

    // Get owner business profile
    const meRes = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${ownerToken}`);

    businessId = (meRes.body.data.business.id || meRes.body.data.business._id).toString();
  });

  describe('Staff Creation & Login Flow', () => {
    it('should create a staff member and allow staff to log in with their email and password', async () => {
      const newStaffPayload = {
        name: 'Rahul Cashier',
        employeeId: 'EMP001',
        email: 'rahul.cashier@example.com',
        phone: '9876543210',
        role: 'Cashier',
        department: 'Billing / Counter',
        workLocation: 'Main Store',
        reportingTo: 'Store Owner / Admin',
        password: 'StaffPassword@123',
        status: 'Active',
        permissions: ['pos', 'tables', 'orders', 'discounts'],
      };

      // 1. Admin creates staff member
      const createRes = await request(app)
        .post('/api/v1/staff')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send(newStaffPayload);

      expect(createRes.status).toBe(201);
      expect(createRes.body.success).toBe(true);
      expect(createRes.body.data.name).toBe('Rahul Cashier');
      expect(createRes.body.data.email).toBe('rahul.cashier@example.com');
      expect(createRes.body.data.role).toBe('Cashier');
      expect(createRes.body.data.userId).toBeDefined();

      // 2. Staff logs in with created credentials
      const loginRes = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: 'rahul.cashier@example.com',
          password: 'StaffPassword@123',
        });

      expect(loginRes.status).toBe(200);
      expect(loginRes.body.success).toBe(true);
      expect(loginRes.body.data.accessToken).toBeDefined();
      expect(loginRes.body.data.user.email).toBe('rahul.cashier@example.com');
      expect(loginRes.body.data.user.name).toBe('Rahul Cashier');
      expect(loginRes.body.data.user.role).toBe('Cashier');
      expect(loginRes.body.data.user.onboardingCompleted).toBe(true);
      expect(loginRes.body.data.user.permissions).toContain('pos');

      const staffToken = loginRes.body.data.accessToken;

      // 3. Staff accesses protected routes scoped to employer's business
      const staffMeRes = await request(app)
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${staffToken}`);

      expect(staffMeRes.status).toBe(200);
      const returnedBizId = (staffMeRes.body.data.business.id || staffMeRes.body.data.business._id).toString();
      expect(returnedBizId).toBe(businessId);
    });

    it('should reject login if staff member is marked Inactive', async () => {
      const staffPayload = {
        name: 'Inactive Staff Member',
        email: 'inactive.staff@example.com',
        role: 'Sales',
        password: 'SecretPassword@123',
        status: 'Inactive',
      };

      // 1. Create inactive staff
      const createRes = await request(app)
        .post('/api/v1/staff')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send(staffPayload);

      expect(createRes.status).toBe(201);

      // 2. Attempt login
      const loginRes = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: 'inactive.staff@example.com',
          password: 'SecretPassword@123',
        });

      expect(loginRes.status).toBe(403);
      expect(loginRes.body.success).toBe(false);
      expect(loginRes.body.error.code).toBe('ACCOUNT_INACTIVE');
    });

    it('should allow updating staff details and password', async () => {
      const staffPayload = {
        name: 'Sneha Verma',
        email: 'sneha.verma@example.com',
        role: 'Manager',
        password: 'OriginalPassword@123',
        status: 'Active',
      };

      const createRes = await request(app)
        .post('/api/v1/staff')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send(staffPayload);

      const staffId = createRes.body.data._id || createRes.body.data.id;

      // Update password
      const updateRes = await request(app)
        .put(`/api/v1/staff/${staffId}`)
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          role: 'Admin',
          password: 'NewUpdatedPassword@123',
        });

      expect(updateRes.status).toBe(200);
      expect(updateRes.body.data.role).toBe('Admin');

      // Login with old password should fail
      const oldLoginRes = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: 'sneha.verma@example.com',
          password: 'OriginalPassword@123',
        });
      expect(oldLoginRes.status).toBe(401);

      // Login with new password should succeed
      const newLoginRes = await request(app)
        .post('/api/v1/auth/login')
        .send({
          email: 'sneha.verma@example.com',
          password: 'NewUpdatedPassword@123',
        });
      expect(newLoginRes.status).toBe(200);
      expect(newLoginRes.body.data.user.role).toBe('Admin');
    });
  });
});
