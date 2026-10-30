const mongoose = require('mongoose');
require('./setup');
const Campaign = require('../src/models/Campaign');
const Coupon = require('../src/models/Coupon');
const CouponRedemption = require('../src/models/CouponRedemption');
const couponService = require('../src/services/couponService');
const campaignService = require('../src/services/campaignService');
const cronService = require('../src/services/cronService');

describe('Campaign Management & Redemption Engine Enhancements (Phases 1-15)', () => {
  const businessAId = new mongoose.Types.ObjectId();
  const businessBId = new mongoose.Types.ObjectId();
  const customer1Phone = '9876543210';
  const customer2Phone = '9123456789';

  const productPizzaId = new mongoose.Types.ObjectId();
  const productBurgerId = new mongoose.Types.ObjectId();
  const productSaladId = new mongoose.Types.ObjectId();

  afterEach(async () => {
    await Campaign.deleteMany({});
    await Coupon.deleteMany({});
    await CouponRedemption.deleteMany({});
  });

  describe('PHASE 2 & 12: Reward Types & Scope Calculation', () => {
    test('Flat Cash Discount: correctly deducts flat amount from whole bill', async () => {
      await Coupon.create({
        businessId: businessAId,
        code: 'FLAT100',
        discountType: 'flat',
        discountValue: 100,
        rewardScope: 'whole_bill',
        isActive: true,
      });

      const result = await couponService.validateCoupon(businessAId.toString(), {
        code: 'FLAT100',
        subtotal: 600,
        customerPhone: customer1Phone,
      });

      expect(result.valid).toBe(true);
      expect(result.discountAmount).toBe(100);
      expect(result.finalPayableAmount).toBe(500);
    });

    test('Percentage Discount: accurately calculates percentage of whole bill', async () => {
      await Coupon.create({
        businessId: businessAId,
        code: 'SAVE20',
        discountType: 'percentage',
        discountValue: 20,
        rewardScope: 'whole_bill',
        isActive: true,
      });

      const result = await couponService.validateCoupon(businessAId.toString(), {
        code: 'SAVE20',
        subtotal: 1000,
        customerPhone: customer1Phone,
      });

      expect(result.valid).toBe(true);
      expect(result.discountAmount).toBe(200);
      expect(result.finalPayableAmount).toBe(800);
    });

    test('Chosen Products Scope: applies discount ONLY to eligible items in cart', async () => {
      await Coupon.create({
        businessId: businessAId,
        code: 'PIZZA25',
        discountType: 'percentage',
        discountValue: 25,
        rewardScope: 'chosen_products',
        applicableProducts: [productPizzaId],
        isActive: true,
      });

      // Cart with Pizza (eligible: ₹400) and Salad (ineligible: ₹200) = Total ₹600
      const cartItems = [
        { productId: productPizzaId.toString(), price: 400, quantity: 1 },
        { productId: productSaladId.toString(), price: 200, quantity: 1 },
      ];

      const result = await couponService.validateCoupon(businessAId.toString(), {
        code: 'PIZZA25',
        subtotal: 600,
        cartItems,
        customerPhone: customer1Phone,
      });

      expect(result.valid).toBe(true);
      // 25% of eligible ₹400 = ₹100 (NOT 25% of ₹600 = ₹150)
      expect(result.discountAmount).toBe(100);
      expect(result.finalPayableAmount).toBe(500);
    });

    test('Chosen Products Scope: rejects if cart has no eligible items', async () => {
      await Coupon.create({
        businessId: businessAId,
        code: 'PIZZA25',
        discountType: 'percentage',
        discountValue: 25,
        rewardScope: 'chosen_products',
        applicableProducts: [productPizzaId],
        isActive: true,
      });

      // Cart with only Burger and Salad
      const cartItems = [
        { productId: productBurgerId.toString(), price: 300, quantity: 1 },
        { productId: productSaladId.toString(), price: 150, quantity: 1 },
      ];

      const result = await couponService.validateCoupon(businessAId.toString(), {
        code: 'PIZZA25',
        subtotal: 450,
        cartItems,
        customerPhone: customer1Phone,
      });

      expect(result.valid).toBe(false);
      expect(result.message).toContain('applies only to selected products');
    });
  });

  describe('PHASE 4: Minimum Spend & Maximum Cashback Cap', () => {
    test('Minimum Spend: rejects when cart subtotal is below minimum spend requirement', async () => {
      await Coupon.create({
        businessId: businessAId,
        code: 'MIN500OFF',
        discountType: 'flat',
        discountValue: 100,
        minCartAmount: 500,
        isActive: true,
      });

      const rejected = await couponService.validateCoupon(businessAId.toString(), {
        code: 'MIN500OFF',
        subtotal: 450,
        customerPhone: customer1Phone,
      });

      expect(rejected.valid).toBe(false);
      expect(rejected.message).toBe('Add products worth ₹500 or more to redeem this coupon.');

      const accepted = await couponService.validateCoupon(businessAId.toString(), {
        code: 'MIN500OFF',
        subtotal: 500,
        customerPhone: customer1Phone,
      });

      expect(accepted.valid).toBe(true);
      expect(accepted.discountAmount).toBe(100);
    });

    test('Maximum Cashback Cap: cashback never exceeds configured maximum limit', async () => {
      // 10% Cashback with Maximum Cap of ₹100
      await Coupon.create({
        businessId: businessAId,
        code: 'CASHBACK10',
        discountType: 'cashback',
        discountValue: 10,
        maxDiscountAmount: 100,
        isActive: true,
      });

      // Case 1: Subtotal ₹500 -> 10% = ₹50 (below cap)
      const res1 = await couponService.validateCoupon(businessAId.toString(), {
        code: 'CASHBACK10',
        subtotal: 500,
        customerPhone: customer1Phone,
      });
      expect(res1.valid).toBe(true);
      expect(res1.discountAmount).toBe(50);

      // Case 2: Subtotal ₹1,500 -> 10% = ₹150 -> CAPPED to ₹100
      const res2 = await couponService.validateCoupon(businessAId.toString(), {
        code: 'CASHBACK10',
        subtotal: 1500,
        customerPhone: customer1Phone,
      });
      expect(res2.valid).toBe(true);
      expect(res2.discountAmount).toBe(100);

      // Case 3: Subtotal ₹2,000 -> 10% = ₹200 -> CAPPED to ₹100
      const res3 = await couponService.validateCoupon(businessAId.toString(), {
        code: 'CASHBACK10',
        subtotal: 2000,
        customerPhone: customer1Phone,
      });
      expect(res3.valid).toBe(true);
      expect(res3.discountAmount).toBe(100);
    });
  });

  describe('PHASE 7: Campaign Expiry Logic', () => {
    test('Rejects expired campaign coupon with exact required message', async () => {
      const pastDate = new Date(Date.now() - 24 * 60 * 60 * 1000); // 1 day in past

      await Coupon.create({
        businessId: businessAId,
        code: 'EXPIRED20',
        discountType: 'percentage',
        discountValue: 20,
        endDate: pastDate,
        isActive: true,
      });

      const result = await couponService.validateCoupon(businessAId.toString(), {
        code: 'EXPIRED20',
        subtotal: 500,
        customerPhone: customer1Phone,
      });

      expect(result.valid).toBe(false);
      expect(result.message).toBe('This campaign coupon has expired.');
    });
  });

  describe('PHASE 8: Customer-wise Redemption Limits', () => {
    test('Option 1: Only Once allows 1st redemption and rejects 2nd redemption by same customer', async () => {
      await Coupon.create({
        businessId: businessAId,
        code: 'ONCEONLY',
        discountType: 'flat',
        discountValue: 50,
        usageLimitPerCustomer: 1,
        isActive: true,
      });

      // 1st Attempt: Valid
      const check1 = await couponService.validateCoupon(businessAId.toString(), {
        code: 'ONCEONLY',
        subtotal: 300,
        customerPhone: customer1Phone,
      });
      expect(check1.valid).toBe(true);

      // Record 1st redemption
      await couponService.recordRedemption(businessAId.toString(), {
        couponCode: 'ONCEONLY',
        customerPhone: customer1Phone,
        orderId: new mongoose.Types.ObjectId().toString(),
        orderSubtotal: 300,
        discountAmount: 50,
        finalOrderAmount: 250,
      });

      // 2nd Attempt by same customer: REJECTED
      const check2 = await couponService.validateCoupon(businessAId.toString(), {
        code: 'ONCEONLY',
        subtotal: 300,
        customerPhone: customer1Phone,
      });
      expect(check2.valid).toBe(false);
      expect(check2.message).toBe('You have already redeemed this campaign coupon.');

      // Different customer can still redeem
      const checkOtherCustomer = await couponService.validateCoupon(businessAId.toString(), {
        code: 'ONCEONLY',
        subtotal: 300,
        customerPhone: customer2Phone,
      });
      expect(checkOtherCustomer.valid).toBe(true);
    });

    test('Option 2: Multiple Times allows up to limit and rejects subsequent redemptions', async () => {
      await Coupon.create({
        businessId: businessAId,
        code: 'THRICETREAT',
        discountType: 'flat',
        discountValue: 30,
        usageLimitPerCustomer: 3,
        isActive: true,
      });

      // Redemptions 1, 2, 3 succeed
      for (let i = 1; i <= 3; i++) {
        const check = await couponService.validateCoupon(businessAId.toString(), {
          code: 'THRICETREAT',
          subtotal: 200,
          customerPhone: customer1Phone,
        });
        expect(check.valid).toBe(true);

        await couponService.recordRedemption(businessAId.toString(), {
          couponCode: 'THRICETREAT',
          customerPhone: customer1Phone,
          orderId: new mongoose.Types.ObjectId().toString(),
          orderSubtotal: 200,
          discountAmount: 30,
          finalOrderAmount: 170,
        });
      }

      // 4th redemption attempt: REJECTED
      const check4 = await couponService.validateCoupon(businessAId.toString(), {
        code: 'THRICETREAT',
        subtotal: 200,
        customerPhone: customer1Phone,
      });
      expect(check4.valid).toBe(false);
      expect(check4.message).toBe('You have reached the maximum redemption limit for this coupon.');
    });
  });

  describe('PHASE 10: Strict Multi-Tenant Data Isolation', () => {
    test('Cross-business coupon redemption is strictly rejected', async () => {
      // Business A creates coupon
      await Coupon.create({
        businessId: businessAId,
        code: 'BIZ_A_SECRET',
        discountType: 'flat',
        discountValue: 100,
        isActive: true,
      });

      // Business B attempts to validate Business A's coupon
      const result = await couponService.validateCoupon(businessBId.toString(), {
        code: 'BIZ_A_SECRET',
        subtotal: 500,
        customerPhone: customer1Phone,
      });

      expect(result.valid).toBe(false);
      expect(result.message).toBe('Coupon not found or inactive for this business.');
    });

    test('Same coupon code can exist independently across different businesses without collision', async () => {
      // Business A checks uniqueness
      const isUniqueInA1 = await campaignService.isCouponCodeUnique(businessAId.toString(), 'WELCOME100');
      expect(isUniqueInA1).toBe(true);

      // Business A registers WELCOME100
      await Coupon.create({
        businessId: businessAId,
        code: 'WELCOME100',
        discountType: 'flat',
        discountValue: 100,
        isActive: true,
      });

      // Business A re-checks: now NOT unique in Business A
      const isUniqueInA2 = await campaignService.isCouponCodeUnique(businessAId.toString(), 'WELCOME100');
      expect(isUniqueInA2).toBe(false);

      // Business B checks WELCOME100: IS UNIQUE in Business B
      const isUniqueInB = await campaignService.isCouponCodeUnique(businessBId.toString(), 'WELCOME100');
      expect(isUniqueInB).toBe(true);
    });
  });

  describe('PHASE 6: Campaign Scheduling & Background Worker Engine', () => {
    test('Scheduled background worker atomically claims due campaigns and skips future ones', async () => {
      const now = new Date();
      const pastTime = new Date(now.getTime() - 10 * 60 * 1000); // 10 minutes ago
      const futureTime = new Date(now.getTime() + 60 * 60 * 1000); // 1 hour in future

      // 1. Due Campaign
      const dueCampaign = await Campaign.create({
        businessId: businessAId,
        campaignId: 'CMP-DUE-101',
        name: 'Due Flash Sale',
        type: 'marketing',
        status: 'scheduled',
        couponSettings: {
          hasSendSchedule: true,
          scheduledAt: pastTime,
        },
        channel: { channelType: 'business_whatsapp', phoneNumber: '+919999999999' },
        template: { templateId: 'flash_sale_tpl', name: 'Flash Sale' },
      });

      // 2. Future Campaign
      const futureCampaign = await Campaign.create({
        businessId: businessAId,
        campaignId: 'CMP-FUTURE-102',
        name: 'Future Mega Sale',
        type: 'marketing',
        status: 'scheduled',
        couponSettings: {
          hasSendSchedule: true,
          scheduledAt: futureTime,
        },
        channel: { channelType: 'business_whatsapp', phoneNumber: '+919999999999' },
        template: { templateId: 'future_sale_tpl', name: 'Future Sale' },
      });

      // Mock executeScheduledCampaign to verify execution
      const spyExecute = jest.spyOn(campaignService, 'executeScheduledCampaign').mockResolvedValue({
        success: true,
        sentCount: 50,
      });

      // Run background worker job
      await cronService.processScheduledCampaignsJob();

      expect(spyExecute).toHaveBeenCalledWith(dueCampaign._id);
      expect(spyExecute).not.toHaveBeenCalledWith(futureCampaign._id);

      // Verify future campaign is still in 'scheduled' status
      const refetchedFuture = await Campaign.findById(futureCampaign._id);
      expect(refetchedFuture.status).toBe('scheduled');

      spyExecute.mockRestore();
    });

    test('Stuck processing campaigns are automatically recovered after timeout', async () => {
      const stuckTime = new Date(Date.now() - 40 * 60 * 1000); // 40 mins ago (> 15 mins)

      const stuckCampaign = await Campaign.create({
        businessId: businessAId,
        campaignId: 'CMP-STUCK-103',
        name: 'Stuck Campaign',
        status: 'processing',
        couponSettings: { hasSendSchedule: true },
        channel: { channelType: 'business_whatsapp', phoneNumber: '+919999999999' },
        template: { templateId: 'tpl_stuck', name: 'Stuck Template' },
      });

      // Explicitly backdate updatedAt bypassing automatic timestamp hook
      await Campaign.collection.updateOne(
        { _id: stuckCampaign._id },
        { $set: { updatedAt: stuckTime } }
      );

      await cronService.recoverStuckCampaignsJob();

      const recovered = await Campaign.findById(stuckCampaign._id);
      expect(recovered.status).toBe('scheduled');
      expect(recovered.executionLogs.length).toBeGreaterThan(0);
      expect(recovered.executionLogs[0].message).toContain('stuck processing state');
    });
  });
});
