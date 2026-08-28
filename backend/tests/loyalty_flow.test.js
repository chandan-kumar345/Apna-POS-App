const request = require('supertest');
const mongoose = require('mongoose');
const app = require('../src/app');
const User = require('../src/models/User');
const Business = require('../src/models/Business');
const LoyaltyProgram = require('../src/models/LoyaltyProgram');
const CustomerLoyalty = require('../src/models/CustomerLoyalty');
const LoyaltyTransaction = require('../src/models/LoyaltyTransaction');
const Order = require('../src/models/Order');
const loyaltyService = require('../src/services/loyaltyService');
require('./setup');

describe('End-to-End Loyalty Program & OTP Redemption Flow', () => {
  let authToken;
  let businessId;
  let userId;
  const testPhone = '9876543210';
  const testCustomerName = 'Rahul Sharma';

  beforeEach(async () => {
    const regRes = await request(app).post('/api/v1/auth/register').send({
      name: 'Loyalty Owner',
      email: 'loyalty_test_user@apnapos.com',
      password: 'SecurePassword@123',
      phone: '9876543210',
      companyName: 'THE ROYAL GARDENIA',
    });

    authToken = regRes.body.data.accessToken;
    userId = regRes.body.data.user.id;

    const meRes = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${authToken}`);
    businessId = meRes.body.data.business._id || meRes.body.data.business.id;
  });

  test('1. Save & Fetch Visit Made Loyalty Configuration via REST API', async () => {
    const configPayload = {
      programName: 'THE ROYAL GARDENIA',
      slogan: 'Get rewarded on every purchase',
      orderType: 'Delivery, Take-Away, Dine-In',
      bannerImageUrl: 'https://images.unsplash.com/photo-test',
      logoUrl: 'https://images.unsplash.com/logo-test',
      bgGradientStart: '#4A082F',
      bgGradientEnd: '#8E1449',
      rewardColorStart: '#4A082F',
      rewardColorEnd: '#8E1449',
      pointsName: 'Cookie',
      pointsPerVisit: 10,
      minimumPurchase: 100,
      rewardStages: [
        {
          id: 'stage_1',
          visitCount: 300,
          rewardType: '₹ Discount',
          rewardValue: 100,
          minimumPurchase: 100,
          freeItemName: 'Cheers ! Rs 100 off on your purchase.',
        },
        {
          id: 'stage_2',
          visitCount: 500,
          rewardType: '₹ Discount',
          rewardValue: 200,
          minimumPurchase: 100,
          freeItemName: 'Cheers ! Rs 200 off on your purchase.',
        },
        {
          id: 'stage_3',
          visitCount: 800,
          rewardType: '₹ Discount',
          rewardValue: 300,
          minimumPurchase: 100,
          freeItemName: 'Cheers ! Rs 300 off on your purchase.',
        },
      ],
    };

    const saveRes = await request(app)
      .post('/api/v1/loyalty/config')
      .set('Authorization', `Bearer ${authToken}`)
      .send(configPayload);

    expect(saveRes.status).toBe(200);
    expect(saveRes.body.success).toBe(true);
    expect(saveRes.body.data.programName).toBe('THE ROYAL GARDENIA');
    expect(saveRes.body.data.rewardStages).toHaveLength(3);

    // Fetch config
    const getRes = await request(app)
      .get('/api/v1/loyalty/config')
      .set('Authorization', `Bearer ${authToken}`);

    expect(getRes.status).toBe(200);
    expect(getRes.body.data.programName).toBe('THE ROYAL GARDENIA');
    expect(getRes.body.data.pointsName).toBe('Cookie');
    expect(getRes.body.data.pointsPerVisit).toBe(10);
  });

  test('2. Award Points on Completed Order with APNA POS Message', async () => {
    // Initialize program config
    await loyaltyService.getLoyaltyPrograms(businessId);

    const mockOrder = {
      _id: new mongoose.Types.ObjectId(),
      orderNumber: 'ORD-TEST-001',
      orderType: 'dineIn',
      totalAmount: 450,
      subtotal: 450,
      customerName: testCustomerName,
      customerPhone: testPhone,
      status: 'completed',
    };

    const earnResult = await loyaltyService.awardPointsForCompletedOrder(businessId, mockOrder);

    expect(earnResult.earned).toBe(true);
    expect(earnResult.pointsAwarded).toBe(10);
    expect(earnResult.newBalance).toBe(10);
    expect(earnResult.totalVisits).toBe(1);
    expect(earnResult.message).toContain('[APNA POS]');

    // Verify transaction recorded in ledger
    const tx = await LoyaltyTransaction.findOne({ businessId, customerPhone: testPhone, type: 'earn' });
    expect(tx).not.toBeNull();
    expect(tx.messageHeader).toBe('APNA POS');
    expect(tx.points).toBe(10);
  });

  test('3. Query Customer Loyalty Profile via REST API', async () => {
    // Initialize profile and top up to 350 to unlock Stage 1 (300 Cookie)
    await CustomerLoyalty.create({
      businessId,
      customerPhone: testPhone,
      customerName: testCustomerName,
      pointsBalance: 350,
      totalPointsEarned: 350,
      totalVisits: 35,
    });

    const res = await request(app)
      .get(`/api/v1/loyalty/customer/${testPhone}`)
      .set('Authorization', `Bearer ${authToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.pointsBalance).toBe(350);
    expect(res.body.data.unlockedStages).toContain('stage_1');
    expect(res.body.data.availableStages[0].isUnlocked).toBe(true);
    expect(res.body.data.availableStages[1].isUnlocked).toBe(false); // 500 Cookie stage still locked
  });

  test('4. Generate & Send OTP for Unlocked Stage Redemption', async () => {
    await CustomerLoyalty.create({
      businessId,
      customerPhone: testPhone,
      customerName: testCustomerName,
      pointsBalance: 350,
      totalPointsEarned: 350,
      totalVisits: 35,
    });

    const otpRes = await request(app)
      .post('/api/v1/loyalty/send-otp')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        phone: testPhone,
        stageId: 'stage_1',
      });

    expect(otpRes.status).toBe(200);
    expect(otpRes.body.success).toBe(true);
    expect(otpRes.body.data.stageId).toBe('stage_1');
    expect(otpRes.body.data.discountValue).toBe(100);
    expect(otpRes.body.data.pointsToRedeem).toBe(300);

    const otpDebug = otpRes.body.data.otpDebug;
    expect(otpDebug).toBeDefined();
    expect(otpDebug).toHaveLength(4);

    // Test Invalid OTP rejection
    const invalidVerifyRes = await request(app)
      .post('/api/v1/loyalty/verify-otp')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        phone: testPhone,
        otp: '0000',
      });

    expect(invalidVerifyRes.status).toBe(400);

    // Test Valid OTP verification
    const validVerifyRes = await request(app)
      .post('/api/v1/loyalty/verify-otp')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        phone: testPhone,
        otp: otpDebug,
      });

    expect(validVerifyRes.status).toBe(200);
    expect(validVerifyRes.body.success).toBe(true);
    expect(validVerifyRes.body.data.verified).toBe(true);
    expect(validVerifyRes.body.data.discountAmount).toBe(100);
    expect(validVerifyRes.body.data.pointsToRedeem).toBe(300);
  });

  test('5. Settle Loyalty Redemption & Deduct Points', async () => {
    await CustomerLoyalty.create({
      businessId,
      customerPhone: testPhone,
      customerName: testCustomerName,
      pointsBalance: 350,
      totalPointsEarned: 350,
      totalVisits: 35,
    });

    const redeemRes = await request(app)
      .post('/api/v1/loyalty/redeem')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        phone: testPhone,
        stageId: 'stage_1',
        discountAmount: 100,
        pointsToRedeem: 300,
        orderNumber: 'ORD-TEST-002',
      });

    expect(redeemRes.status).toBe(200);
    expect(redeemRes.body.success).toBe(true);
    expect(redeemRes.body.data.pointsRedeemed).toBe(300);
    expect(redeemRes.body.data.remainingBalance).toBe(50); // 350 - 300 = 50

    // Verify CustomerLoyalty state in DB
    const custLoyalty = await CustomerLoyalty.findOne({ businessId, customerPhone: testPhone });
    expect(custLoyalty.pointsBalance).toBe(50);
    expect(custLoyalty.totalPointsRedeemed).toBe(300);
    expect(custLoyalty.activeOtp).toBeNull();

    // Verify Loyalty Ledger Transaction
    const redeemTx = await LoyaltyTransaction.findOne({
      businessId,
      customerPhone: testPhone,
      type: 'redeem',
    });
    expect(redeemTx).not.toBeNull();
    expect(redeemTx.points).toBe(-300);
    expect(redeemTx.balanceAfter).toBe(50);
    expect(redeemTx.messageHeader).toBe('APNA POS');
    expect(redeemTx.message).toContain('₹100 discount applied');
  });

  test('6. Minimum Spend Condition, Point Earning Gap, and Max Cashback Limit Enforcement', async () => {
    // Configure Points Conditions
    await request(app)
      .post('/api/v1/loyalty/config')
      .set('Authorization', `Bearer ${authToken}`)
      .send({
        programName: 'THE ROYAL GARDENIA',
        minSpendConditionEnabled: true,
        minSpendCondition: 500,
        pointEarningGapEnabled: true,
        pointEarningGap: 24,
        maxCashbackLimitEnabled: true,
        maxCashbackLimit: 50,
        pointsPerVisit: 100,
      });

    // Case 1: Order total ₹300 is below min spend condition of ₹500
    const failOrder = {
      id: new mongoose.Types.ObjectId().toString(),
      orderNumber: 'ORD-LOW-01',
      customerPhone: '9123456780',
      totalAmount: 300,
      orderType: 'Dine-In',
    };
    const res1 = await loyaltyService.awardPointsForCompletedOrder(businessId, failOrder);
    expect(res1.earned).toBe(false);
    expect(res1.reason).toContain('below minimum spend condition');

    // Case 2: Order total ₹600 qualifies, points capped at max limit of 50 (instead of 100)
    const successOrder = {
      id: new mongoose.Types.ObjectId().toString(),
      orderNumber: 'ORD-HIGH-01',
      customerPhone: '9123456780',
      totalAmount: 600,
      orderType: 'Dine-In',
    };
    const res2 = await loyaltyService.awardPointsForCompletedOrder(businessId, successOrder);
    expect(res2.earned).toBe(true);
    expect(res2.pointsAwarded).toBe(50); // Capped at 50

    // Case 3: Immediate next order triggers 24h point earning gap cooldown
    const secondOrder = {
      id: new mongoose.Types.ObjectId().toString(),
      orderNumber: 'ORD-HIGH-02',
      customerPhone: '9123456780',
      totalAmount: 700,
      orderType: 'Dine-In',
    };
    const res3 = await loyaltyService.awardPointsForCompletedOrder(businessId, secondOrder);
    expect(res3.earned).toBe(false);
    expect(res3.reason).toContain('Point earning gap active');
  });
});
