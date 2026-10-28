const mongoose = require('mongoose');
const Campaign = require('../src/models/Campaign');
const campaignService = require('../src/services/campaignService');

describe('Campaign Dynamic Builder & Model Persistence Tests', () => {
  const dummyBusinessId = new mongoose.Types.ObjectId();
  const dummyCampaignId = 'CMP-20261029-TEST';

  test('1. Campaign model successfully validates rewardDetails, couponSettings, and orderTypes', () => {
    const campaignDoc = new Campaign({
      businessId: dummyBusinessId,
      campaignId: dummyCampaignId,
      name: 'New Year Special - Flat ₹300 OFF',
      type: 'marketing',
      status: 'draft',
      orderTypes: ['delivery', 'takeaway', 'dine_in'],
      rewardDetails: {
        rewardType: 'flat_discount',
        discountAmount: 300,
        discountScope: 'whole_bill',
        hasMinSpend: true,
        minSpendAmount: 500,
        maxCashbackCap: 200,
        comboOfferTitle: 'Festive Delight',
        campaignTitle: 'New Year Special - Flat ₹300 OFF',
        description: 'Get a flat ₹300 OFF on your entire festive meal.',
        termsAndConditions: [
          'Minimum purchase of ₹500 required.',
          '2 offers cannot be clubbed.',
          'Valid on Delivery, Take Away, Dine In',
        ],
      },
      couponSettings: {
        useCustomCouponCode: true,
        customCouponCode: 'FESTIVE300',
        hasSendSchedule: true,
        sendDate: new Date('2026-10-29T08:00:00.000Z'),
        sendTime: '8:00 AM',
        hasExpiryDate: true,
        expiryDate: new Date('2026-11-28T23:59:59.000Z'),
        redemptionPerCustomer: 'only_once',
        displayCouponInProfile: true,
      },
      audience: {
        source: 'group',
        groupName: 'All Customers',
        recipientCount: 320,
      },
      channel: {
        channelType: 'business_whatsapp',
        phoneNumber: '+919876543210',
      },
      template: {
        templateId: 'festive_offer_tpl',
        name: 'Festive Offer',
      },
      schedule: {
        mode: 'later',
        scheduledAt: new Date('2026-10-29T08:00:00.000Z'),
      },
    });

    const validationError = campaignDoc.validateSync();
    expect(validationError).toBeUndefined();
    expect(campaignDoc.orderTypes).toContain('delivery');
    expect(campaignDoc.rewardDetails.discountAmount).toBe(300);
    expect(campaignDoc.couponSettings.customCouponCode).toBe('FESTIVE300');
    expect(campaignDoc.couponSettings.displayCouponInProfile).toBe(true);
  });

  test('2. updateCampaign handles payload and updates campaign document with draft data', async () => {
    const mockCampaign = {
      _id: new mongoose.Types.ObjectId(),
      businessId: dummyBusinessId,
      campaignId: dummyCampaignId,
      name: 'Old Name',
      status: 'draft',
      orderTypes: ['delivery'],
      rewardDetails: {
        toObject: () => ({ rewardType: 'flat_discount', discountAmount: 100 }),
      },
      couponSettings: {
        toObject: () => ({ useCustomCouponCode: false }),
      },
      save: jest.fn().mockResolvedValue(true),
    };

    const spyGetById = jest.spyOn(campaignService, 'getCampaignById').mockResolvedValue(mockCampaign);

    const result = await campaignService.updateCampaign(dummyBusinessId.toString(), dummyCampaignId, {
      name: 'Updated Festive Draft',
      status: 'draft',
      orderTypes: ['delivery', 'dine_in'],
      rewardDetails: {
        rewardType: 'percentage',
        discountAmount: 20,
        discountScope: 'whole_bill',
      },
      couponSettings: {
        useCustomCouponCode: true,
        customCouponCode: 'DIWALI20',
      },
    });

    expect(spyGetById).toHaveBeenCalledWith(dummyBusinessId.toString(), dummyCampaignId);
    expect(mockCampaign.name).toBe('Updated Festive Draft');
    expect(mockCampaign.orderTypes).toEqual(['delivery', 'dine_in']);
    expect(mockCampaign.rewardDetails.discountAmount).toBe(20);
    expect(mockCampaign.couponSettings.customCouponCode).toBe('DIWALI20');
    expect(mockCampaign.save).toHaveBeenCalled();

    spyGetById.mockRestore();
  });
});
