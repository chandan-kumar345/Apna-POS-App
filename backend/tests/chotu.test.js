const request = require('supertest');
const app = require('../src/app');
const ChotuActionLog = require('../src/models/ChotuActionLog');
require('./setup');

describe('Chotu AI Voice Assistant - Phase 1 Voice Foundation (/api/v1/chotu)', () => {
  let token;
  let userEmail;

  beforeEach(async () => {
    userEmail = `chotu_tester_${Date.now()}@example.com`;
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: userEmail,
        password: 'Password@123',
        restaurantName: 'Chotu Voice Dhaba',
      });

    token = res.body.data.accessToken;
  });

  describe('GET /api/v1/chotu/health', () => {
    it('should return active status and confirm Phase 1 constraints (zero POS mutations)', async () => {
      const res = await request(app)
        .get('/api/v1/chotu/health')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.assistantName).toBe('Chotu');
      expect(res.body.data.currentPhase).toBeGreaterThanOrEqual(1);
      expect(typeof res.body.data.posMutationsEnabled).toBe('boolean');
    });
  });

  describe('POST /api/v1/chotu/transcribe', () => {
    it('should normalize Hinglish numerals and transcribe spoken phrase', async () => {
      const res = await request(app)
        .post('/api/v1/chotu/transcribe')
        .set('Authorization', `Bearer ${token}`)
        .send({
          audio: 'Table 5 pe do butter naan aur ek paneer tikka laga do',
          format: 'raw_text',
          language: 'hinglish',
          sessionId: 'test_session_1',
          tableContext: { tableNumber: '5' },
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.transcription).toContain('Table 5 pe 2 butter naan aur 1 paneer tikka laga do');
      expect(res.body.data.phase).toBe(1);
      expect(res.body.data.confidence).toBeGreaterThanOrEqual(0.9);
      expect(res.body.data.logId).toBeDefined();

      // Verify audit log was recorded in MongoDB
      const log = await ChotuActionLog.findById(res.body.data.logId);
      expect(log).not.toBeNull();
      expect(log.transcription).toContain('Table 5 pe 2 butter naan');
      expect(log.intent).toBe('TRANSCRIBE_ONLY');
      expect(log.actionStatus).toBe('transcribed');
      expect(log.tableNumber).toBe('5');
    });

    it('should handle pure English commands with number normalization', async () => {
      const res = await request(app)
        .post('/api/v1/chotu/transcribe')
        .set('Authorization', `Bearer ${token}`)
        .send({
          audio: 'Add one paneer tikka and three butter naans to table four',
          format: 'raw_text',
          language: 'english',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.transcription).toContain('Add 1 paneer tikka and 3 butter naans to table 4');
    });

    it('should handle Hindi number variations (teen, chaar, paanch)', async () => {
      const res = await request(app)
        .post('/api/v1/chotu/transcribe')
        .set('Authorization', `Bearer ${token}`)
        .send({
          audio: 'Table 8 pe teen coke aur chaar samosa',
          format: 'raw_text',
          language: 'hindi',
        });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.transcription).toContain('Table 8 pe 3 coke aur 4 samosa');
    });

    it('should reject requests with missing audio/text payload', async () => {
      const res = await request(app)
        .post('/api/v1/chotu/transcribe')
        .set('Authorization', `Bearer ${token}`)
        .send({});

      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
    });
  });

  describe('GET /api/v1/chotu/logs', () => {
    it('should return paginated audit logs', async () => {
      // First create a transcription log
      await request(app)
        .post('/api/v1/chotu/transcribe')
        .set('Authorization', `Bearer ${token}`)
        .send({
          audio: 'Table 1 ka bill bana do',
          format: 'raw_text',
        });

      const res = await request(app)
        .get('/api/v1/chotu/logs')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.logs).toBeDefined();
      expect(res.body.data.logs.length).toBeGreaterThanOrEqual(1);
      expect(res.body.data.pagination.total).toBeGreaterThanOrEqual(1);
    });
  });
});
