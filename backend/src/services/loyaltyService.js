const mongoose = require('mongoose');
const LoyaltyProgram = require('../models/LoyaltyProgram');
const CustomerLoyalty = require('../models/CustomerLoyalty');
const LoyaltyTransaction = require('../models/LoyaltyTransaction');
const Business = require('../models/Business');
const Order = require('../models/Order');
const Customer = require('../models/Customer');
const Notification = require('../models/Notification');
const ApiError = require('../utils/ApiError');

class LoyaltyService {
  /**
   * Default visit reward stages
   */
  getDefaultRewardStages() {
    return [
      {
        id: 'stage_1',
        label: '300 Cookie',
        value: 300,
        visitCount: 300,
        iconName: 'cookie',
        rewardType: '₹ Discount',
        rewardValue: 100,
        minimumPurchase: 100,
        freeItemName: 'Cheers ! Rs 100 off on your purchase.',
      },
      {
        id: 'stage_2',
        label: '500 Cookie',
        value: 500,
        visitCount: 500,
        iconName: 'cookie',
        rewardType: '₹ Discount',
        rewardValue: 200,
        minimumPurchase: 100,
        freeItemName: 'Cheers ! Rs 200 off on your purchase.',
      },
      {
        id: 'stage_3',
        label: '800 Cookie',
        value: 800,
        visitCount: 800,
        iconName: 'cookie',
        rewardType: '₹ Discount',
        rewardValue: 300,
        minimumPurchase: 100,
        freeItemName: 'Cheers ! Rs 300 off on your purchase.',
      },
    ];
  }

  /**
   * Returns default loyalty program configuration for a business
   */
  getDefaultPrograms(companyName = 'THE ROYAL GARDENIA', companyLogo = '') {
    const stages = this.getDefaultRewardStages();
    return {
      companyName,
      companyLogo,
      visitConfig: {
        programName: companyName || 'THE ROYAL GARDENIA',
        slogan: 'Get rewarded on every purchase',
        orderType: 'Dine-In',
        bannerImageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=800',
        logoUrl: companyLogo || '',
        bgGradientStart: '#4A082F',
        bgGradientEnd: '#8E1449',
        rewardColorStart: '#4A082F',
        rewardColorEnd: '#8E1449',
        pointsName: 'Cookie',
        pointsPerVisit: 10,
        minimumPurchase: 100,
        rewardStages: stages,
        termsNote: 'Terms and conditions apply.\nMinimum purchase of ₹100 required.\n3 offers cannot be clubbed.',
        status: 'inactive',
        isActive: false,
      },
      programs: [
        {
          id: 'prog_visit_made',
          type: 'visit_made',
          title: 'Visit Made',
          description: 'Get rewarded on every purchase',
          earningRule: '1 Visit Made = 10 Cookie',
          rewardCurrency: 'Cookie',
          gradientColors: ['#4A082F', '#8E1449'],
          status: 'inactive',
          isActive: false,
          orderIndex: 0,
          milestones: stages.map((s) => ({
            id: s.id,
            label: `${s.value} Cookie`,
            value: s.value,
            visitCount: s.value,
            iconName: 'cookie',
            rewardText: s.freeItemName,
            rewardType: s.rewardType,
            rewardValue: s.rewardValue,
            minimumPurchase: s.minimumPurchase,
            freeItemName: s.freeItemName,
          })),
        },
        {
          id: 'prog_amount_spent',
          type: 'amount_spent',
          title: 'Amount Spent',
          description: 'Get rewarded on every purchase',
          earningRule: '₹75 Amount Spent = 1 Cookie',
          rewardCurrency: 'Cookie',
          gradientColors: ['#6B0505', '#C81A1A'],
          status: 'inactive',
          isActive: false,
          orderIndex: 1,
          milestones: [
            { id: 'm4', label: '300 Cookie', value: 300, visitCount: 300, iconName: 'cookie', rewardText: '300 Cookie' },
            { id: 'm5', label: '500 Cookie', value: 500, visitCount: 500, iconName: 'cookie', rewardText: '500 Cookie' },
            { id: 'm6', label: '800 Cookie', value: 800, visitCount: 800, iconName: 'cookie', rewardText: '800 Cookie' },
          ],
        },
        {
          id: 'prog_cashback',
          type: 'cashback',
          title: 'Cashback',
          description: 'Get rewarded on every step',
          earningRule: '10% Cashback on sales above ₹500',
          rewardCurrency: '%',
          gradientColors: ['#0A425C', '#1E3A8A'],
          status: 'inactive',
          isActive: false,
          orderIndex: 2,
          cashbackDetails: {
            percentage: 10,
            minSpend: 500,
            headline: '10% Cashback on sales',
            subtext: 'On min. spend of ₹500',
            termsNote: 'Cashback will be credited when another coupon or offer is already applied.',
            billRewardText: 'Rs 500+ bill earns 10% cashback',
            slabTitle: 'STARTER REWARD',
            goal: 'On min purchase of Rs 500',
            reward: '🎁 Earn 10% cashback',
            progressPercent: 65,
          },
        },
      ],
    };
  }

  /**
   * Get or initialize loyalty programs for a business
   */
  async getLoyaltyPrograms(businessId) {
    if (!businessId) {
      throw ApiError.badRequest('Business ID is required');
    }

    const business = await Business.findById(businessId);
    const dynamicCompanyName = business?.profile?.companyName || business?.profile?.name || 'THE ROYAL GARDENIA';
    const dynamicCompanyLogo = business?.profile?.profileImage || '';

    let loyaltyDoc = await LoyaltyProgram.findOne({ businessId });

    if (!loyaltyDoc) {
      const defaultData = this.getDefaultPrograms(dynamicCompanyName, dynamicCompanyLogo);
      loyaltyDoc = await LoyaltyProgram.create({
        businessId,
        companyName: defaultData.companyName,
        companyLogo: defaultData.companyLogo,
        visitConfig: defaultData.visitConfig,
        programs: defaultData.programs,
      });
    }

    return {
      companyName: loyaltyDoc.companyName || dynamicCompanyName,
      companyLogo: loyaltyDoc.companyLogo || dynamicCompanyLogo,
      visitConfig: loyaltyDoc.visitConfig || this.getDefaultPrograms(dynamicCompanyName).visitConfig,
      programs: loyaltyDoc.programs || [],
    };
  }

  /**
   * Get Visit Made configuration specifically
   */
  async getVisitConfig(businessId) {
    const loyalty = await this.getLoyaltyPrograms(businessId);
    return loyalty.visitConfig;
  }

  /**
   * Save / Update Visit Made Configuration
   */
  async saveVisitConfig(businessId, configData) {
    if (!businessId) {
      throw ApiError.badRequest('Business ID is required');
    }

    const rawStages = Array.isArray(configData.rewardStages) ? configData.rewardStages : this.getDefaultRewardStages();
    const formattedStages = rawStages.map((s, idx) => ({
      id: s.id || `stage_${idx + 1}`,
      label: s.label || `${s.visitCount || s.value || 300} ${configData.pointsName || 'Cookie'}`,
      value: Number(s.visitCount || s.value || 300),
      visitCount: Number(s.visitCount || s.value || 300),
      iconName: s.iconName || 'cookie',
      rewardType: s.rewardType || 'Redeem cash discount',
      rewardValue: Number(s.rewardValue || 100),
      minimumPurchase: Number(s.minimumPurchase || 0),
      freeItemName: s.freeItemName || `Cheers ! Rs ${s.rewardValue || 100} off on your purchase.`,
      rewardText: s.freeItemName || `Cheers ! Rs ${s.rewardValue || 100} off on your purchase.`,
      discountScope: s.discountScope || 'Whole bill',
      minSpendRedemptionEnabled: s.minSpendRedemptionEnabled === true,
      applicableProductIds: Array.isArray(s.applicableProductIds) ? s.applicableProductIds : [],
    }));

    const isDraft = configData.status === 'draft' || configData.isDraft === true;
    const isProgramActive = !isDraft && configData.isActive !== false && configData.status !== 'inactive';

    const cleanConfig = {
      programName: configData.programName || 'THE ROYAL GARDENIA',
      slogan: configData.slogan || 'Get rewarded on every purchase',
      orderType: configData.orderType || 'Dine-In',
      bannerImageUrl: configData.bannerImageUrl || 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=800',
      logoUrl: configData.logoUrl || '',
      bgGradientStart: configData.bgGradientStart || '#4A082F',
      bgGradientEnd: configData.bgGradientEnd || '#8E1449',
      rewardColorStart: configData.rewardColorStart || '#4A082F',
      rewardColorEnd: configData.rewardColorEnd || '#8E1449',
      pointsName: configData.pointsName || 'Cookie',
      pointsPerVisit: Number(configData.pointsPerVisit || 10),
      minimumPurchase: Number(configData.minimumPurchase || 100),
      rewardStages: formattedStages,
      termsNote: configData.termsNote || 'Terms and conditions apply.\nMinimum purchase of ₹100 required.\n3 offers cannot be clubbed.',
      minSpendConditionEnabled: configData.minSpendConditionEnabled === true,
      minSpendCondition: Number(configData.minSpendCondition || 0),
      pointEarningGapEnabled: configData.pointEarningGapEnabled === true,
      pointEarningGap: Number(configData.pointEarningGap || 24),
      maxCashbackLimitEnabled: configData.maxCashbackLimitEnabled === true,
      maxCashbackLimit: Number(configData.maxCashbackLimit || 0),
      bonusPointsEnabled: configData.bonusPointsEnabled !== false,
      bonusPointsAmount: Number(configData.bonusPointsAmount || 100),
      bonusRequiredFields: Array.isArray(configData.bonusRequiredFields)
        ? configData.bonusRequiredFields
        : ['name', 'phone', 'gender', 'birthday', 'anniversary'],
      status: isDraft ? 'draft' : (isProgramActive ? 'active' : 'inactive'),
      isActive: isProgramActive,
    };

    let loyaltyDoc = await LoyaltyProgram.findOne({ businessId });
    if (!loyaltyDoc) {
      const defaultData = this.getDefaultPrograms(cleanConfig.programName, cleanConfig.logoUrl);
      loyaltyDoc = new LoyaltyProgram({
        businessId,
        companyName: cleanConfig.programName,
        companyLogo: cleanConfig.logoUrl,
        visitConfig: cleanConfig,
        programs: defaultData.programs,
      });
    }

    loyaltyDoc.companyName = cleanConfig.programName;
    if (cleanConfig.logoUrl) loyaltyDoc.companyLogo = cleanConfig.logoUrl;
    loyaltyDoc.visitConfig = cleanConfig;

    // Enforce Single Active Program Rule: If visit_made is activated, deactivate other programs
    if (isProgramActive) {
      loyaltyDoc.programs.forEach((p) => {
        if (p.type !== 'visit_made') {
          p.isActive = false;
          if (p.status === 'active') p.status = 'inactive';
        }
      });
    }

      // Sync visit_made program in programs array
      const visitProgIdx = loyaltyDoc.programs.findIndex((p) => p.type === 'visit_made');
      if (visitProgIdx >= 0) {
        loyaltyDoc.programs[visitProgIdx].title = cleanConfig.programName;
        loyaltyDoc.programs[visitProgIdx].description = cleanConfig.slogan;
        loyaltyDoc.programs[visitProgIdx].earningRule = `1 Visit Made = ${cleanConfig.pointsPerVisit} ${cleanConfig.pointsName}`;
        loyaltyDoc.programs[visitProgIdx].rewardCurrency = cleanConfig.pointsName;
        loyaltyDoc.programs[visitProgIdx].gradientColors = [
          cleanConfig.bgGradientStart,
          cleanConfig.bgGradientEnd,
        ];
        loyaltyDoc.programs[visitProgIdx].milestones = formattedStages;
        loyaltyDoc.programs[visitProgIdx].status = cleanConfig.status;
        loyaltyDoc.programs[visitProgIdx].isActive = isProgramActive;
      } else {
        loyaltyDoc.programs.push({
          id: 'prog_visit_made',
          type: 'visit_made',
          title: cleanConfig.programName,
          description: cleanConfig.slogan,
          earningRule: `1 Visit Made = ${cleanConfig.pointsPerVisit} ${cleanConfig.pointsName}`,
          rewardCurrency: cleanConfig.pointsName,
          gradientColors: [cleanConfig.bgGradientStart, cleanConfig.bgGradientEnd],
          milestones: formattedStages,
          status: cleanConfig.status,
          isActive: isProgramActive,
          orderIndex: 0,
        });
      }

      await loyaltyDoc.save();

    return loyaltyDoc.visitConfig;
  }

  /**
   * Get Customer Loyalty Profile & Unlocked Stages
   */
  async getCustomerLoyalty(businessId, phone, name = '') {
    if (!businessId) {
      throw ApiError.badRequest('Business ID is required');
    }
    if (!phone) {
      throw ApiError.badRequest('Phone number is required');
    }

    const cleanPhone = phone.trim();
    let customerLoyalty = await CustomerLoyalty.findOne({ businessId, customerPhone: cleanPhone });

    if (!customerLoyalty) {
      const customer = await Customer.findOne({ businessId, phone: cleanPhone });
      customerLoyalty = await CustomerLoyalty.create({
        businessId,
        customerPhone: cleanPhone,
        customerName: name || customer?.name || '',
        customerId: customer?._id || null,
        pointsBalance: 0,
        totalPointsEarned: 0,
        totalPointsRedeemed: 0,
        totalVisits: 0,
        unlockedStages: [],
      });
    } else if (name && !customerLoyalty.customerName) {
      customerLoyalty.customerName = name;
      await customerLoyalty.save();
    }

    const visitConfig = await this.getVisitConfig(businessId);
    const stages = visitConfig?.rewardStages || this.getDefaultRewardStages();

    const balance = customerLoyalty.pointsBalance || 0;
    const availableStages = stages.map((stage) => {
      const requiredPoints = Number(stage.visitCount || stage.value || 0);
      const isUnlocked = balance >= requiredPoints;
      return {
        id: stage.id,
        requiredPoints,
        rewardType: stage.rewardType || '₹ Discount',
        rewardValue: Number(stage.rewardValue || 100),
        minimumPurchase: Number(stage.minimumPurchase || 100),
        freeItemName: stage.freeItemName || `Cheers ! Rs ${stage.rewardValue || 100} off on your purchase.`,
        isUnlocked,
      };
    });

    const unlockedStageIds = availableStages.filter((s) => s.isUnlocked).map((s) => s.id);
    customerLoyalty.unlockedStages = unlockedStageIds;
    await customerLoyalty.save();

    const isProgramActive = visitConfig?.isActive === true && visitConfig?.status !== 'draft' && visitConfig?.status !== 'inactive';
    const orderTypesList = visitConfig?.orderType
      ? visitConfig.orderType.split(',').map((s) => s.trim().replace('-', '')).filter(Boolean)
      : ['DineIn', 'Takeaway'];

    return {
      customerPhone: customerLoyalty.customerPhone,
      customerName: customerLoyalty.customerName,
      pointsBalance: customerLoyalty.pointsBalance,
      totalVisits: customerLoyalty.totalVisits,
      totalPointsEarned: customerLoyalty.totalPointsEarned,
      totalPointsRedeemed: customerLoyalty.totalPointsRedeemed,
      bonusPointsAwarded: customerLoyalty.bonusPointsAwarded === true,
      pointsName: visitConfig?.pointsName || 'Cookie',
      programName: visitConfig?.programName || 'THE ROYAL GARDENIA',
      isProgramActive: isProgramActive,
      orderTypes: orderTypesList.length > 0 ? orderTypesList : ['DineIn', 'Takeaway'],
      unlockedStages: unlockedStageIds,
      availableStages,
    };
  }

  /**
   * Award Points when an Order is Completed / Settled
   */
  async awardPointsForCompletedOrder(businessId, order) {
    if (!order || !order.customerPhone) {
      return { earned: false, reason: 'No customer phone provided' };
    }

    const cleanPhone = order.customerPhone.trim();
    if (!cleanPhone) return { earned: false, reason: 'Empty phone' };

    const existingEarnTx = await LoyaltyTransaction.findOne({
      businessId,
      orderId: order._id || order.id,
      type: 'earn',
    });
    if (existingEarnTx) {
      return { earned: false, reason: 'Points already awarded for this order' };
    }

    const visitConfig = await this.getVisitConfig(businessId);
    if (!visitConfig || visitConfig.isActive === false) {
      return { earned: false, reason: 'Loyalty program not active' };
    }

    const orderTotal = Number(order.totalAmount || order.subtotal || 0);

    // 1. Check Minimum Spend Condition if enabled
    if (visitConfig.minSpendConditionEnabled && Number(visitConfig.minSpendCondition) > 0) {
      if (orderTotal < Number(visitConfig.minSpendCondition)) {
        return { earned: false, reason: `Order total ₹${orderTotal} is below minimum spend condition of ₹${visitConfig.minSpendCondition}` };
      }
    } else {
      const minPurchase = Number(visitConfig.minimumPurchase || 0);
      if (minPurchase > 0 && orderTotal < minPurchase) {
        return { earned: false, reason: `Order total below minimum purchase of ₹${minPurchase}` };
      }
    }

    // 2. Check Order Type eligibility
    if (visitConfig.orderType) {
      const allowedTypes = visitConfig.orderType.toLowerCase().split(',').map((t) => t.trim().replace('-', ''));
      const currentType = (order.orderType || 'dineIn').toLowerCase().replace('-', '').replace('_', '');
      const isAllowed = allowedTypes.some((t) => currentType.includes(t) || t.includes(currentType));
      if (!isAllowed && allowedTypes.length > 0) {
        return { earned: false, reason: `Order type ${order.orderType} not eligible` };
      }
    }

    let customerLoyalty = await CustomerLoyalty.findOne({ businessId, customerPhone: cleanPhone });

    // 3. Check Point Earning Gap (Cooldown period) if enabled
    if (visitConfig.pointEarningGapEnabled && Number(visitConfig.pointEarningGap) > 0) {
      if (customerLoyalty && customerLoyalty.lastEarningAt) {
        const hoursSinceLast = (Date.now() - new Date(customerLoyalty.lastEarningAt).getTime()) / (1000 * 60 * 60);
        if (hoursSinceLast < Number(visitConfig.pointEarningGap)) {
          const remainingHours = Math.ceil(Number(visitConfig.pointEarningGap) - hoursSinceLast);
          return { earned: false, reason: `Point earning gap active. Customer can earn points in ${remainingHours}h` };
        }
      }
    }

    let pointsPerVisit = Number(visitConfig.pointsPerVisit || 10);

    // 4. Check Maximum Limit if enabled
    if (visitConfig.maxCashbackLimitEnabled && Number(visitConfig.maxCashbackLimit) > 0) {
      if (pointsPerVisit > Number(visitConfig.maxCashbackLimit)) {
        pointsPerVisit = Number(visitConfig.maxCashbackLimit);
      }
    }

    const pointsName = visitConfig.pointsName || 'Cookie';
    const programName = visitConfig.programName || 'THE ROYAL GARDENIA';

    if (!customerLoyalty) {
      customerLoyalty = await CustomerLoyalty.create({
        businessId,
        customerPhone: cleanPhone,
        customerName: order.customerName || '',
        pointsBalance: 0,
        totalPointsEarned: 0,
        totalPointsRedeemed: 0,
        totalVisits: 0,
        unlockedStages: [],
      });
    }

    customerLoyalty.pointsBalance += pointsPerVisit;
    customerLoyalty.totalPointsEarned += pointsPerVisit;
    customerLoyalty.totalVisits += 1;
    customerLoyalty.lastEarningAt = new Date();
    if (order.customerName && !customerLoyalty.customerName) {
      customerLoyalty.customerName = order.customerName;
    }

    const stages = visitConfig.rewardStages || this.getDefaultRewardStages();
    const unlockedIds = stages
      .filter((s) => customerLoyalty.pointsBalance >= Number(s.visitCount || s.value || 0))
      .map((s) => s.id);
    customerLoyalty.unlockedStages = unlockedIds;

    await customerLoyalty.save();

    const msg = `[APNA POS] Congratulations! You earned ${pointsPerVisit} ${pointsName} on your order at ${programName}. Total balance: ${customerLoyalty.pointsBalance} ${pointsName}.`;

    await LoyaltyTransaction.create({
      businessId,
      customerPhone: cleanPhone,
      orderId: order._id || (mongoose.Types.ObjectId.isValid(order.id) ? order.id : null),
      orderNumber: order.orderNumber || '',
      type: 'earn',
      points: pointsPerVisit,
      balanceAfter: customerLoyalty.pointsBalance,
      messageHeader: 'APNA POS',
      message: msg,
    });

    try {
      await Notification.create({
        businessId,
        type: 'promotion',
        title: `[APNA POS] ${pointsPerVisit} ${pointsName} Earned`,
        message: msg,
        read: false,
        recipientPhone: cleanPhone,
        metadata: {
          pointsEarned: pointsPerVisit,
          newBalance: customerLoyalty.pointsBalance,
          orderNumber: order.orderNumber,
        },
      });
    } catch (e) {
      // Non-blocking
    }

    return {
      earned: true,
      pointsAwarded: pointsPerVisit,
      newBalance: customerLoyalty.pointsBalance,
      totalVisits: customerLoyalty.totalVisits,
      unlockedStages: unlockedIds,
      message: msg,
    };
  }

  /**
   * Generate & Send OTP for Stage Level Loyalty Redemption
   */
  async sendLoyaltyRedemptionOtp(businessId, phone, stageId) {
    if (!phone) {
      throw ApiError.badRequest('Customer phone number is required');
    }
    if (!stageId) {
      throw ApiError.badRequest('Reward stage ID is required');
    }

    const cleanPhone = phone.trim();
    const customerLoyalty = await CustomerLoyalty.findOne({ businessId, customerPhone: cleanPhone });

    if (!customerLoyalty) {
      throw ApiError.notFound('Customer loyalty account not found');
    }

    const visitConfig = await this.getVisitConfig(businessId);
    const stages = visitConfig?.rewardStages || this.getDefaultRewardStages();
    const stage = stages.find((s) => s.id === stageId);

    if (!stage) {
      throw ApiError.badRequest('Invalid reward stage selected');
    }

    const requiredPoints = Number(stage.visitCount || stage.value || 0);
    const discountValue = Number(stage.rewardValue || 100);

    if (customerLoyalty.pointsBalance < requiredPoints) {
      throw ApiError.badRequest(`Insufficient points balance. Requires ${requiredPoints} ${visitConfig.pointsName || 'Cookies'}, current balance is ${customerLoyalty.pointsBalance}`);
    }

    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    customerLoyalty.activeOtp = {
      otp,
      stageId: stage.id,
      discountValue,
      pointsToRedeem: requiredPoints,
      expiresAt,
    };

    await customerLoyalty.save();

    const programName = visitConfig.programName || 'THE ROYAL GARDENIA';
    const pointsName = visitConfig.pointsName || 'Cookie';
    const otpMessage = `[APNA POS] Your OTP to redeem ₹${discountValue} OFF (${requiredPoints} ${pointsName}) at ${programName} is ${otp}. Valid for 10 minutes.`;

    try {
      await Notification.create({
        businessId,
        type: 'alert',
        title: '[APNA POS] Loyalty Redemption OTP',
        message: otpMessage,
        read: false,
        recipientPhone: cleanPhone,
        metadata: { otp, stageId, discountValue, pointsToRedeem: requiredPoints },
      });
    } catch (e) {
      // Non-blocking
    }

    return {
      success: true,
      message: 'OTP generated and sent to customer phone',
      phone: cleanPhone,
      stageId: stage.id,
      discountValue,
      pointsToRedeem: requiredPoints,
      otpDebug: process.env.NODE_ENV !== 'production' ? otp : undefined,
    };
  }

  /**
   * Verify Redemption OTP
   */
  async verifyLoyaltyRedemptionOtp(businessId, phone, otp) {
    if (!phone || !otp) {
      throw ApiError.badRequest('Phone and OTP are required');
    }

    const cleanPhone = phone.trim();
    const cleanOtp = otp.toString().trim();

    const customerLoyalty = await CustomerLoyalty.findOne({ businessId, customerPhone: cleanPhone });

    if (!customerLoyalty || !customerLoyalty.activeOtp) {
      throw ApiError.badRequest('No active OTP request found for this customer');
    }

    const activeOtp = customerLoyalty.activeOtp;

    if (new Date() > new Date(activeOtp.expiresAt)) {
      customerLoyalty.activeOtp = null;
      await customerLoyalty.save();
      throw ApiError.badRequest('OTP has expired. Please request a new OTP');
    }

    if (activeOtp.otp !== cleanOtp) {
      throw ApiError.badRequest('Invalid OTP entered. Please verify with customer');
    }

    return {
      verified: true,
      stageId: activeOtp.stageId,
      discountAmount: activeOtp.discountValue,
      pointsToRedeem: activeOtp.pointsToRedeem,
      message: 'OTP verified successfully. Stage reward discount applied!',
    };
  }

  /**
   * Settle & Deduct Loyalty Redemption Points linked to Order
   */
  async redeemLoyaltyPoints(businessId, phone, orderId, stageId, discountAmount, pointsToRedeem, orderNumber = '') {
    if (!phone) {
      throw ApiError.badRequest('Phone number is required');
    }

    const cleanPhone = phone.trim();
    const customerLoyalty = await CustomerLoyalty.findOne({ businessId, customerPhone: cleanPhone });

    if (!customerLoyalty) {
      throw ApiError.notFound('Customer loyalty account not found');
    }

    const points = Number(pointsToRedeem) || 0;
    if (customerLoyalty.pointsBalance < points) {
      throw ApiError.badRequest('Insufficient points balance for redemption');
    }

    customerLoyalty.pointsBalance -= points;
    customerLoyalty.totalPointsRedeemed += points;
    customerLoyalty.activeOtp = null;
    customerLoyalty.lastRedemptionAt = new Date();

    const visitConfig = await this.getVisitConfig(businessId);
    const stages = visitConfig?.rewardStages || this.getDefaultRewardStages();
    customerLoyalty.unlockedStages = stages
      .filter((s) => customerLoyalty.pointsBalance >= Number(s.visitCount || s.value || 0))
      .map((s) => s.id);

    await customerLoyalty.save();

    const msg = `[APNA POS] ₹${discountAmount} discount applied on Order #${orderNumber || 'POS'}. ${points} ${visitConfig.pointsName || 'Cookies'} redeemed. Remaining balance: ${customerLoyalty.pointsBalance} ${visitConfig.pointsName || 'Cookies'}.`;

    await LoyaltyTransaction.create({
      businessId,
      customerPhone: cleanPhone,
      orderId: orderId && mongoose.Types.ObjectId.isValid(orderId) ? orderId : null,
      orderNumber: orderNumber || '',
      type: 'redeem',
      points: -points,
      balanceAfter: customerLoyalty.pointsBalance,
      stageId: stageId || '',
      discountAmount: Number(discountAmount) || 0,
      messageHeader: 'APNA POS',
      message: msg,
    });

    return {
      success: true,
      pointsRedeemed: points,
      remainingBalance: customerLoyalty.pointsBalance,
      discountApplied: discountAmount,
      message: msg,
    };
  }

  /**
   * Helper to parse and calculate date ranges
   */
  _getDateFilter(dateRangeStr) {
    const now = new Date();
    let startDate = null;
    let endDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);
    let label = dateRangeStr || 'Last 7 Days';

    if (!dateRangeStr || dateRangeStr === 'Last 7 Days') {
      startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 6, 0, 0, 0, 0);
      label = 'Last 7 Days';
    } else if (dateRangeStr === 'Today') {
      startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
      label = 'Today';
    } else if (dateRangeStr === 'Last 30 Days') {
      startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 29, 0, 0, 0, 0);
      label = 'Last 30 Days';
    } else if (dateRangeStr === 'This Month') {
      startDate = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
      label = 'This Month';
    } else if (dateRangeStr === 'All Time') {
      startDate = new Date(2020, 0, 1);
      label = 'All Time';
    } else if (dateRangeStr.includes('–') || dateRangeStr.includes('-')) {
      const parts = dateRangeStr.split(/[–-]/).map((s) => s.trim());
      if (parts.length === 2) {
        try {
          const endYear = parts[1].match(/\d{4}/) ? parts[1].match(/\d{4}/)[0] : now.getFullYear();
          let sStr = parts[0];
          if (!sStr.match(/\d{4}/)) sStr += ` ${endYear}`;
          const sParsed = new Date(Date.parse(sStr));
          const eParsed = new Date(Date.parse(parts[1]));
          if (!isNaN(sParsed.getTime()) && !isNaN(eParsed.getTime())) {
            startDate = new Date(sParsed.getFullYear(), sParsed.getMonth(), sParsed.getDate(), 0, 0, 0, 0);
            endDate = new Date(eParsed.getFullYear(), eParsed.getMonth(), eParsed.getDate(), 23, 59, 59, 999);
            label = dateRangeStr;
          }
        } catch (_) {}
      }
    }

    if (!startDate) {
      startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 6, 0, 0, 0, 0);
      label = 'Last 7 Days';
    }

    return { startDate, endDate, label };
  }

  /**
   * Transparent Loyalty Health Score calculation (0 - 100)
   */
  calculateLoyaltyHealthScore({
    hasActiveProgram,
    totalParticipants,
    uniqueRedeemingCustomers,
    pointsIssued,
    pointsRedeemed,
    redemptionRateNum,
    totalTransactions,
  }) {
    let score = 0;

    // 1. Program Active Status (Max 15 points)
    if (hasActiveProgram) score += 15;

    // 2. Customer Participation (Max 20 points)
    if (totalParticipants > 0) {
      score += Math.min(20, Math.round((totalParticipants / 50) * 20));
    }

    // 3. Customer Redemption Activity (Max 25 points)
    if (uniqueRedeemingCustomers > 0) {
      const ratio = totalParticipants > 0 ? (uniqueRedeemingCustomers / totalParticipants) : 0;
      score += Math.min(25, Math.round(ratio * 50) + Math.min(10, uniqueRedeemingCustomers * 2));
    }

    // 4. Points Utilization & Redemption Rate (Max 20 points)
    if (redemptionRateNum > 0) {
      if (redemptionRateNum >= 5 && redemptionRateNum <= 60) {
        score += 20;
      } else if (redemptionRateNum > 60) {
        score += 15;
      } else {
        score += Math.round((redemptionRateNum / 5) * 20);
      }
    }

    // 5. Repeat Engagement & Activity (Max 20 points)
    if (totalTransactions > 0) {
      score += Math.min(20, Math.round((totalTransactions / 20) * 20));
    }

    score = Math.max(0, Math.min(100, score));

    let status = 'Healthy score starts from 80+';
    if (score >= 86) status = 'Excellent • High loyalty engagement';
    else if (score >= 71) status = 'Good • Strong reward momentum';
    else if (score >= 51) status = 'Fair • Growing participation';
    else if (score >= 31) status = 'Needs Attention • Boost redemptions';
    else status = 'Poor • Activate and promote loyalty';

    return { score, status };
  }

  /**
   * Get Loyalty Performance analytics (100% Dynamic with Parallel Pipeline)
   */
  async getLoyaltyPerformance(businessId, query = {}) {
    if (!businessId) {
      throw ApiError.badRequest('Business ID is required');
    }

    const { startDate, endDate, label: activeDateRange } = this._getDateFilter(query.dateRange || query.filter);
    const isAllTime = activeDateRange === 'All Time';
    const dateMatch = isAllTime ? {} : { createdAt: { $gte: startDate, $lte: endDate } };

    // Parallel Aggregation Pipeline
    const [
      totalParticipants,
      uniqueRedeemersRaw,
      earnAggRaw,
      redeemAggRaw,
      loyaltyDocRaw,
      totalSalesRaw,
      topAggRaw,
      recentTxDocsRaw,
      dailySalesRaw,
      dailyRedeemRaw,
    ] = await Promise.all([
      // 1. Total participating customers in loyalty
      CustomerLoyalty.countDocuments({ businessId }),

      // 2. Unique customers who have redeemed in date range
      LoyaltyTransaction.distinct('customerPhone', { businessId, type: 'redeem', ...dateMatch }).catch(() => []),

      // 3. Points issued & earn count in date range
      LoyaltyTransaction.aggregate([
        { $match: { businessId, type: 'earn', ...dateMatch } },
        { $group: { _id: null, totalPoints: { $sum: '$points' }, count: { $sum: 1 } } },
      ]).catch(() => []),

      // 4. Points redeemed, discount amount & redeem count in date range
      LoyaltyTransaction.aggregate([
        { $match: { businessId, type: 'redeem', ...dateMatch } },
        {
          $group: {
            _id: null,
            totalPoints: { $sum: { $abs: '$points' } },
            totalDiscount: { $sum: '$discountAmount' },
            count: { $sum: 1 },
          },
        },
      ]).catch(() => []),

      // 5. Loyalty program configuration
      LoyaltyProgram.findOne({ businessId }).lean(),

      // 6. Total sales from completed/settled orders in date range
      Order.aggregate([
        { $match: { businessId, status: { $in: ['completed', 'settled'] }, ...dateMatch } },
        { $group: { _id: null, total: { $sum: '$totalAmount' }, count: { $sum: 1 } } },
      ]).catch(() => []),

      // 7. Top 10 redeeming customers
      LoyaltyTransaction.aggregate([
        { $match: { businessId, type: 'redeem', ...dateMatch } },
        {
          $group: {
            _id: '$customerPhone',
            redemptionCount: { $sum: 1 },
            pointsRedeemed: { $sum: { $abs: '$points' } },
            totalDiscount: { $sum: '$discountAmount' },
          },
        },
        { $sort: { redemptionCount: -1, totalDiscount: -1 } },
        { $limit: 10 },
      ]).catch(() => []),

      // 8. Recent 10 transactions
      LoyaltyTransaction.find({ businessId })
        .sort({ createdAt: -1 })
        .limit(10)
        .populate('orderId', 'orderType totalAmount orderNumber createdAt')
        .lean()
        .catch(() => []),

      // 9. Daily sales aggregation within date range
      Order.aggregate([
        {
          $match: {
            businessId,
            status: { $in: ['completed', 'settled'] },
            createdAt: { $gte: startDate, $lte: endDate },
          },
        },
        {
          $group: {
            _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
            totalRevenue: { $sum: '$totalAmount' },
          },
        },
      ]).catch(() => []),

      // 10. Daily redemptions aggregation within date range
      LoyaltyTransaction.aggregate([
        {
          $match: {
            businessId,
            type: 'redeem',
            createdAt: { $gte: startDate, $lte: endDate },
          },
        },
        {
          $group: {
            _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
            totalRedemptions: { $sum: 1 },
            totalPoints: { $sum: { $abs: '$points' } },
          },
        },
      ]).catch(() => []),
    ]);

    // 1. Process Program Library & Status with unique program deduplication
    let loyaltyDoc = loyaltyDocRaw;
    if (!loyaltyDoc) {
      const defaultData = this.getDefaultPrograms();
      loyaltyDoc = {
        companyName: defaultData.companyName || 'THE ROYAL GARDENIA',
        companyLogo: defaultData.companyLogo || '',
        visitConfig: defaultData.visitConfig,
        programs: defaultData.programs,
        createdAt: new Date(),
      };
    }

    const rawPrograms = Array.isArray(loyaltyDoc.programs) ? loyaltyDoc.programs : [];
    
    // Deduplicate by program ID and type
    const uniqueProgramsMap = new Map();
    rawPrograms.forEach((p) => {
      const key = p.id || p.type;
      if (key && !uniqueProgramsMap.has(key)) {
        uniqueProgramsMap.set(key, {
          ...p,
          id: p.id || `prog_${p.type}`,
          status: p.status || (p.isActive ? 'active' : 'inactive'),
          isActive: p.isActive === true && p.status !== 'draft' && p.status !== 'inactive',
        });
      }
    });

    if (loyaltyDoc.visitConfig) {
      const vc = loyaltyDoc.visitConfig;
      const isVcActive = vc.isActive === true && vc.status !== 'draft' && vc.status !== 'inactive';
      const vcStatus = vc.status || (isVcActive ? 'active' : 'inactive');

      uniqueProgramsMap.set('prog_visit_made', {
        id: 'prog_visit_made',
        type: 'visit_made',
        title: vc.programName || 'Visit Made',
        description: vc.slogan || 'Get rewarded on every purchase',
        earningRule: `1 Visit Made = ${vc.pointsPerVisit || 10} ${vc.pointsName || 'Cookie'}`,
        rewardCurrency: vc.pointsName || 'Cookie',
        gradientColors: [vc.bgGradientStart || '#4A082F', vc.bgGradientEnd || '#8E1449'],
        milestones: vc.rewardStages || [],
        status: vcStatus,
        isActive: isVcActive,
        orderIndex: 0,
        createdAt: loyaltyDoc.createdAt || new Date(),
      });
      if (uniqueProgramsMap.has('visit_made')) {
        uniqueProgramsMap.delete('visit_made');
      }
    }

    const programsList = Array.from(uniqueProgramsMap.values());

    const activePrograms = programsList.filter((p) => (p.status === 'active' || (p.isActive === true && p.status !== 'draft' && p.status !== 'inactive')));
    const draftPrograms = programsList.filter((p) => p.status === 'draft');
    const inactivePrograms = programsList.filter((p) => (p.status === 'inactive' || p.isActive === false) && p.status !== 'draft');

    const activeCount = activePrograms.length;
    const inactiveCount = inactivePrograms.length;
    const draftCount = draftPrograms.length;
    const totalProgramsCount = programsList.length;

    const activeProgram = activePrograms.length > 0 ? activePrograms[0] : null;

    // 2. Metrics & Points Totals
    const pointsIssued = earnAggRaw.length > 0 ? Number(earnAggRaw[0].totalPoints) || 0 : 0;
    const totalEarnTxs = earnAggRaw.length > 0 ? Number(earnAggRaw[0].count) || 0 : 0;
    const pointsRedeemed = redeemAggRaw.length > 0 ? Number(redeemAggRaw[0].totalPoints) || 0 : 0;
    const totalRedeemTxs = redeemAggRaw.length > 0 ? Number(redeemAggRaw[0].count) || 0 : 0;
    const totalDiscountAmount = redeemAggRaw.length > 0 ? Number(redeemAggRaw[0].totalDiscount) || 0 : 0;

    const redemptionRateNum = pointsIssued > 0 ? (pointsRedeemed / pointsIssued) * 100 : 0;
    const redemptionRate = `${redemptionRateNum.toFixed(2)}%`;
    const avgRewardPerRedemption = totalRedeemTxs > 0 ? Math.round(totalDiscountAmount / totalRedeemTxs) : 0;
    const totalRevenue = totalSalesRaw.length > 0 ? Number(totalSalesRaw[0].total) || 0 : 0;
    const uniqueRedeemingCount = Array.isArray(uniqueRedeemersRaw) ? uniqueRedeemersRaw.length : 0;

    // 3. Dynamic Health Score Calculation
    const { score: healthScore, status: healthScoreStatus } = this.calculateLoyaltyHealthScore({
      hasActiveProgram: activeCount > 0,
      totalParticipants,
      uniqueRedeemingCustomers: uniqueRedeemingCount,
      pointsIssued,
      pointsRedeemed,
      redemptionRateNum,
      totalTransactions: totalEarnTxs + totalRedeemTxs,
    });

    // 4. Date-wise Summary Chart Data Generation (7 Daily buckets)
    const salesMap = {};
    (dailySalesRaw || []).forEach((row) => {
      if (row._id) salesMap[row._id] = Number(row.totalRevenue) || 0;
    });

    const redeemMap = {};
    (dailyRedeemRaw || []).forEach((row) => {
      if (row._id) redeemMap[row._id] = Number(row.totalRedemptions) || 0;
    });

    const chartData = [];
    const numDays = 7;
    const dayIntervalMs = 24 * 60 * 60 * 1000;
    const chartStartMs = endDate.getTime() - (numDays - 1) * dayIntervalMs;

    for (let i = 0; i < numDays; i++) {
      const currentDay = new Date(chartStartMs + i * dayIntervalMs);
      const yyyy = currentDay.getFullYear();
      const mm = String(currentDay.getMonth() + 1).padStart(2, '0');
      const dd = String(currentDay.getDate()).padStart(2, '0');
      const key = `${yyyy}-${mm}-${dd}`;

      const dayLabel = currentDay.toLocaleDateString('en-US', { day: 'numeric', month: 'short' });
      chartData.push({
        date: key,
        day: dayLabel,
        redemptions: redeemMap[key] !== undefined ? redeemMap[key] : 0.0,
        revenue: salesMap[key] !== undefined ? salesMap[key] : 0.0,
      });
    }

    // 5. Top 10 Redeeming Customers (UNMASKED Full Phone Numbers)
    const topPhones = (topAggRaw || []).map((t) => t._id).filter(Boolean);
    const [matchedCustomers, matchedLoyalties] = await Promise.all([
      Customer.find({ businessId, phone: { $in: topPhones } }).lean().catch(() => []),
      CustomerLoyalty.find({ businessId, customerPhone: { $in: topPhones } }).lean().catch(() => []),
    ]);

    const nameMap = {};
    (matchedCustomers || []).forEach((c) => {
      if (c.phone) nameMap[c.phone] = c.name || '';
    });
    (matchedLoyalties || []).forEach((cl) => {
      if (cl.customerPhone && !nameMap[cl.customerPhone]) {
        nameMap[cl.customerPhone] = cl.customerName || '';
      }
    });

    const topRedeemingCustomers = (topAggRaw || []).map((item, idx) => {
      const phone = String(item._id || '').trim();
      const customerName = nameMap[phone] || `Customer ${idx + 1}`;
      const count = Number(item.redemptionCount) || 1;
      return {
        phone: phone, // FULL UNMASKED PHONE NUMBER
        name: customerName,
        redemptionCount: count,
        badgeText: `Redemption ${count} Time${count > 1 ? 's' : ''}`,
      };
    });

    // 6. Reward Scoreboard (Dynamic based on Active Program Levels)
    let rewardScoreboard = [];
    const activeStages = activeProgram?.milestones || activeProgram?.rewardStages || loyaltyDoc.visitConfig?.rewardStages || [];

    if (activeStages.length > 0) {
      const stageClaims = await Promise.all(
        activeStages.map(async (st) => {
          const count = await LoyaltyTransaction.countDocuments({
            businessId,
            type: 'redeem',
            $or: [
              { stageId: st.id },
              { stageId: String(st.value || st.visitCount) },
              { discountAmount: st.rewardValue },
            ],
          }).catch(() => 0);

          return {
            rewardText: st.freeItemName || st.rewardText || st.label || `Cheers ! Rs ${st.rewardValue || 100} off on your purchase`,
            claimCount: count,
            rewardType: st.rewardType || 'Redeem cash discount',
          };
        })
      );
      rewardScoreboard = stageClaims;
    }

    // 7. Recent Program Activity (UNMASKED Full Phone Numbers)
    const recentPhones = (recentTxDocsRaw || []).map((tx) => tx.customerPhone).filter(Boolean);
    const recentCusts = await Customer.find({ businessId, phone: { $in: recentPhones } }).lean().catch(() => []);
    const recentNameMap = {};
    (recentCusts || []).forEach((c) => {
      if (c.phone) recentNameMap[c.phone] = c.name || '';
    });

    const recentActivity = (recentTxDocsRaw || []).map((tx) => {
      const isRedeem = tx.type === 'redeem';
      const phone = String(tx.customerPhone || '').trim();
      const orderType = (tx.orderId && tx.orderId.orderType) ? tx.orderId.orderType : 'Quick Payment';
      const dateStr = tx.createdAt
        ? new Date(tx.createdAt).toLocaleString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric',
            hour: 'numeric',
            minute: '2-digit',
            hour12: true,
          })
        : '';

      return {
        customerPhone: phone, // FULL UNMASKED PHONE NUMBER
        action: isRedeem ? 'Redeem' : 'Earn',
        points: isRedeem ? `${tx.points}` : `+${tx.points}`,
        orderType: orderType,
        date: dateStr,
      };
    });

    // 8. Program Library Section
    const programLibrary = programsList.map((p) => {
      const pStatus = p.status || (p.isActive ? 'active' : 'inactive');
      const pCategory = p.type === 'visit_made' ? 'Visit Made' : p.type === 'amount_spent' ? 'Amount Spent' : 'Cashback';
      const createdDateStr = p.createdAt
        ? new Date(p.createdAt).toLocaleDateString('en-GB')
        : (loyaltyDoc.createdAt ? new Date(loyaltyDoc.createdAt).toLocaleDateString('en-GB') : '');

      const vConfig = (p.type === 'visit_made' && loyaltyDoc.visitConfig) ? loyaltyDoc.visitConfig : null;
      
      let orderTypesList = ['Dine-In', 'Takeaway'];
      if (vConfig && vConfig.orderType) {
        orderTypesList = Array.isArray(vConfig.orderType)
          ? vConfig.orderType
          : String(vConfig.orderType).split(',').map((s) => s.trim()).filter(Boolean);
      }

      const stagesList = vConfig?.rewardStages && vConfig.rewardStages.length > 0
        ? vConfig.rewardStages
        : (p.milestones && p.milestones.length > 0 ? p.milestones : []);

      const starterStage = stagesList.length > 0 ? stagesList[0] : null;
      const starterRewardTitle = starterStage
        ? (starterStage.freeItemName || starterStage.rewardText || `🎁 Level 1 Offer (₹${starterStage.rewardValue || 100} off)`)
        : '🎁 Level 1 Offer';
      const starterRewardSubtext = starterStage
        ? `On ${starterStage.visitCount || starterStage.value || 1} Visit${(starterStage.visitCount || starterStage.value || 1) > 1 ? 's' : ''}`
        : 'Starter Reward';

      return {
        id: p.id,
        name: p.title || vConfig?.programName || loyaltyDoc.companyName || 'Loyalty Program',
        status: pStatus,
        createDate: createdDateStr,
        category: pCategory,
        channel: 'Store Visit',
        orderTypes: orderTypesList.length > 0 ? orderTypesList : ['Dine-In', 'Takeaway'],
        bannerImageUrl: vConfig?.bannerImageUrl || 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=800',
        logoUrl: vConfig?.logoUrl || loyaltyDoc.companyLogo || '',
        pointsName: p.rewardCurrency || vConfig?.pointsName || 'Cookie',
        pointsPerVisit: vConfig?.pointsPerVisit || 10,
        slogan: vConfig?.slogan || p.description || 'Get rewarded on every purchase',
        bgGradientStart: vConfig?.bgGradientStart || (p.gradientColors && p.gradientColors[0]) || '#4A082F',
        bgGradientEnd: vConfig?.bgGradientEnd || (p.gradientColors && p.gradientColors[1]) || '#8E1449',
        rewardColorStart: vConfig?.rewardColorStart || '#0F766E',
        rewardColorEnd: vConfig?.rewardColorEnd || '#064E3B',
        starterRewardTitle: starterRewardTitle,
        starterRewardSubtext: starterRewardSubtext,
        isActive: pStatus === 'active',
      };
    });

    // Return structured, 100% dynamic response
    return {
      // 1. Status Section
      statusSection: {
        activeCount,
        inactiveCount,
        draftCount,
        totalCount: totalProgramsCount,
      },

      // 2. Health Score Section
      healthScoreSection: {
        score: healthScore,
        maxScore: 100,
        status: healthScoreStatus,
      },

      // 3. Overview Section
      overviewSection: {
        dateRange: activeDateRange,
        totalRevenue,
        totalRedemptions: totalRedeemTxs,
        totalParticipants,
        uniqueRedeemingCustomers: uniqueRedeemingCount,
      },

      // 4. Summary Chart Section
      summaryChartSection: {
        currentMode: 'Redemption',
        chartData,
      },

      // 5. KPI Metrics Section
      kpiMetricsSection: {
        redemptionRate,
        pointsRedeemed,
        pointsIssued,
        avgRewardPerRedemption,
      },

      // 6. Top Customers Section
      topCustomersSection: {
        title: 'Top 10 Redeeming Customers',
        customers: topRedeemingCustomers,
      },

      // 7. Reward Scoreboard Section
      rewardScoreboardSection: {
        title: 'Reward Scoreboard',
        rewards: rewardScoreboard,
      },

      // 8. Recent Activity Section
      recentActivitySection: {
        title: 'Recent Program Activity',
        activities: recentActivity,
      },

      // 9. Program Library Section
      programLibrarySection: {
        title: 'Program Library',
        description: 'Filter the loyalty list by status while keeping insights and live performance visible above.',
        filterCounts: {
          all: totalProgramsCount,
          active: activeCount,
          inactive: inactiveCount,
          draft: draftCount,
        },
        programs: programLibrary,
      },

      // Top-level aliases for direct access and backward compatibility
      activeProgramsCount: activeCount,
      inactiveProgramsCount: inactiveCount,
      draftProgramsCount: draftCount,
      totalProgramsCount,
      healthScore,
      healthScoreStatus,
      dateRangeText: activeDateRange,
      totalRevenue,
      totalRedemptions: totalRedeemTxs,
      totalParticipants,
      redemptionRate,
      pointsRedeemed,
      pointsIssued,
      avgRewardPerRedemption,
      chartData,
      topRedeemingCustomers,
      rewardScoreboard,
      recentActivity,
      programLibrary,

      // Legacy analytics fields
      totalMembers: totalParticipants,
      activeMembers: uniqueRedeemingCount > 0 ? uniqueRedeemingCount : totalParticipants,
      rewardsClaimed: totalRedeemTxs,
      repeatVisitRate: totalParticipants > 0 ? `${Math.round((totalEarnTxs / totalParticipants) * 10)}%` : '0%',
      totalPointsIssued: pointsIssued,
      totalCashbackGiven: totalDiscountAmount,
      loyaltyRevenue: totalRevenue,
      roiPercentage: totalDiscountAmount > 0 ? `${Math.round((totalRevenue / totalDiscountAmount) * 100)}%` : '0%',
    };
  }

  /**
   * Update or create single loyalty program (enforces single active program rule)
   */
  async updateLoyaltyProgram(businessId, programData) {
    if (!businessId) {
      throw ApiError.badRequest('Business ID is required');
    }

    let loyaltyDoc = await LoyaltyProgram.findOne({ businessId });
    if (!loyaltyDoc) {
      const defaultData = this.getDefaultPrograms();
      loyaltyDoc = await LoyaltyProgram.create({
        businessId,
        companyName: defaultData.companyName,
        companyLogo: defaultData.companyLogo,
        visitConfig: defaultData.visitConfig,
        programs: defaultData.programs,
      });
    }

    const progId = programData.id || `prog_${Date.now()}`;
    const isDraft = programData.status === 'draft' || programData.isDraft === true;
    const isProgramActive = !isDraft && (programData.isActive === true || programData.status === 'active');

    // Enforce Single Active Program Rule: If this program is activated, deactivate others
    if (isProgramActive) {
      loyaltyDoc.programs.forEach((p) => {
        if (p.id !== progId) {
          p.isActive = false;
          if (p.status === 'active') p.status = 'inactive';
        }
      });
      if (loyaltyDoc.visitConfig) {
        const isVisitMade = progId === 'prog_visit_made' || programData.type === 'visit_made';
        loyaltyDoc.visitConfig.isActive = isVisitMade;
        loyaltyDoc.visitConfig.status = isVisitMade ? 'active' : 'inactive';
      }
    } else {
      if (loyaltyDoc.visitConfig && (progId === 'prog_visit_made' || programData.type === 'visit_made')) {
        loyaltyDoc.visitConfig.isActive = false;
        loyaltyDoc.visitConfig.status = isDraft ? 'draft' : 'inactive';
      }
    }

    const cleanProgram = {
      ...programData,
      id: progId,
      status: isDraft ? 'draft' : (isProgramActive ? 'active' : 'inactive'),
      isActive: isProgramActive,
      updatedAt: new Date(),
    };

    const idx = loyaltyDoc.programs.findIndex((p) => p.id === progId);
    if (idx >= 0) {
      loyaltyDoc.programs[idx] = { ...loyaltyDoc.programs[idx].toObject(), ...cleanProgram };
    } else {
      loyaltyDoc.programs.push(cleanProgram);
    }

    await loyaltyDoc.save();
    return loyaltyDoc;
  }
}

module.exports = new LoyaltyService();
