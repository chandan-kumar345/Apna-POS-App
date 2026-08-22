const request = require('supertest');
const app = require('../src/app');
require('./setup');

describe('Customer APIs (/api/v1/customers)', () => {
  let token;
  let businessId;

  beforeEach(async () => {
    // Register and login a business user
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: `owner_${Date.now()}@example.com`,
        password: 'Password@123',
        restaurantName: 'Test Bistro',
      });

    token = res.body.data.accessToken;
    businessId = res.body.data.user.businessId;
  });

  describe('POST /api/v1/customers', () => {
    it('should save a new customer profile successfully', async () => {
      const res = await request(app)
        .post('/api/v1/customers')
        .set('Authorization', `Bearer ${token}`)
        .send({
          name: 'Chandan Kumar',
          phone: '9876543210',
          email: 'chandan@example.com',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.customer).toBeDefined();
      expect(res.body.data.customer.name).toBe('Chandan Kumar');
      expect(res.body.data.customer.phone).toBe('9876543210');
    });

    it('should update an existing customer if same phone number is sent', async () => {
      await request(app)
        .post('/api/v1/customers')
        .set('Authorization', `Bearer ${token}`)
        .send({
          name: 'Chandan Kumar',
          phone: '9876543210',
        });

      const updateRes = await request(app)
        .post('/api/v1/customers')
        .set('Authorization', `Bearer ${token}`)
        .send({
          name: 'Chandan K.',
          phone: '9876543210',
        });

      expect(updateRes.status).toBe(200);
      expect(updateRes.body.data.customer.name).toBe('Chandan K.');
    });
  });

  describe('GET /api/v1/customers/suggest', () => {
    beforeEach(async () => {
      await request(app)
        .post('/api/v1/customers')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Rahul Sharma', phone: '9871112233' });

      await request(app)
        .post('/api/v1/customers')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Priya Patel', phone: '9874445566' });

      await request(app)
        .post('/api/v1/customers')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Amit Singh', phone: '8881234567' });
    });

    it('should return matching suggestions when typing 2-3 starting numbers (e.g. "987")', async () => {
      const res = await request(app)
        .get('/api/v1/customers/suggest?q=987')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.customers).toBeDefined();
      expect(res.body.data.customers.length).toBe(2);

      const phones = res.body.data.customers.map((c) => c.phone);
      expect(phones).toContain('9871112233');
      expect(phones).toContain('9874445566');
      expect(phones).not.toContain('8881234567');
    });

    it('should return matching suggestions when typing partial name', async () => {
      const res = await request(app)
        .get('/api/v1/customers/suggest?q=Amit')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.data.customers.length).toBe(1);
      expect(res.body.data.customers[0].name).toBe('Amit Singh');
    });
  });

  describe('GET /api/v1/customers/phone/:phone', () => {
    it('should fetch customer by phone', async () => {
      await request(app)
        .post('/api/v1/customers')
        .set('Authorization', `Bearer ${token}`)
        .send({ name: 'Neha Gupta', phone: '9123456789' });

      const res = await request(app)
        .get('/api/v1/customers/phone/9123456789')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.data.customer).toBeDefined();
      expect(res.body.data.customer.name).toBe('Neha Gupta');
    });
  });
});
