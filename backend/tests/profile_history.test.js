const request = require('supertest');
const mongoose = require('mongoose');
require('./setup');
const app = require('../src/app');
const User = require('../src/models/User');
const Business = require('../src/models/Business');
const ProfileHistory = require('../src/models/ProfileHistory');
const tokenService = require('../src/services/tokenService');

describe('Business Profile Update & Audit History Tracking', () => {
  let user;
  let token;
  let business;

  beforeEach(async () => {
    user = await User.create({
      email: 'owner@apnapos.com',
      passwordHash: 'hashed_password_123',
      phone: '9876543210',
      role: 'owner',
    });

    business = await Business.create({
      ownerId: user._id,
      profile: {
        name: 'Initial Store Name',
        companyName: 'Initial Company Pvt Ltd',
        profileImage: 'https://example.com/logo1.png',
        phone: '9876543210',
      },
    });

    user.businessId = business._id;
    await user.save();

    token = tokenService.generateAccessToken(user);
  });

  test('should update profile name, company name, logo, phone and create history record', async () => {
    const res = await request(app)
      .patch('/api/v1/profile/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Apna POS Express Diner',
        companyName: 'Apna POS Technologies Ltd',
        profileLogo: 'https://example.com/new_logo.png',
        phone: '9988776655',
        changeReason: 'Rebranding outlet name & phone update',
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.business.profile.name).toBe('Apna POS Express Diner');
    expect(res.body.data.business.profile.companyName).toBe('Apna POS Technologies Ltd');
    expect(res.body.data.business.profile.profileImage).toBe('https://example.com/new_logo.png');
    expect(res.body.data.business.profile.phone).toBe('9988776655');

    // Verify in database
    const updatedBusiness = await Business.findById(business._id);
    expect(updatedBusiness.profile.name).toBe('Apna POS Express Diner');
    expect(updatedBusiness.profile.companyName).toBe('Apna POS Technologies Ltd');
    expect(updatedBusiness.profile.profileImage).toBe('https://example.com/new_logo.png');
    expect(updatedBusiness.profile.phone).toBe('9988776655');

    // Verify embedded history
    expect(updatedBusiness.profileHistory.length).toBe(1);
    const historyItem = updatedBusiness.profileHistory[0];
    expect(historyItem.previousProfile.name).toBe('Initial Store Name');
    expect(historyItem.updatedProfile.name).toBe('Apna POS Express Diner');
    expect(historyItem.previousProfile.phone).toBe('9876543210');
    expect(historyItem.updatedProfile.phone).toBe('9988776655');
    expect(historyItem.changedFields).toEqual(
      expect.arrayContaining(['name', 'companyName', 'profileLogo', 'phone'])
    );

    // Verify standalone ProfileHistory collection
    const standaloneHistory = await ProfileHistory.find({ businessId: business._id });
    expect(standaloneHistory.length).toBe(1);
    expect(standaloneHistory[0].updatedProfile.name).toBe('Apna POS Express Diner');
    expect(standaloneHistory[0].changeReason).toBe('Rebranding outlet name & phone update');
  });

  test('should append successive update history entries', async () => {
    // First update
    await request(app)
      .patch('/api/v1/profile/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Step 1 Name',
      });

    // Second update
    await request(app)
      .patch('/api/v1/profile/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Step 2 Name',
        phone: '1122334455',
      });

    const historyRes = await request(app)
      .get('/api/v1/profile/history')
      .set('Authorization', `Bearer ${token}`);

    expect(historyRes.status).toBe(200);
    expect(historyRes.body.success).toBe(true);
    expect(historyRes.body.data.history.length).toBe(2);
    expect(historyRes.body.data.history[0].updatedProfile.name).toBe('Step 2 Name');
    expect(historyRes.body.data.history[1].updatedProfile.name).toBe('Step 1 Name');
  });
});
