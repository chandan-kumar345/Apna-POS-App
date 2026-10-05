const { SubscriptionLead } = require('../models/SubscriptionLead');
const { Notification } = require('../models/Notification');
const Subscription = require('../models/Subscription');
const Business = require('../models/Business');
const User = require('../models/User');
const Staff = require('../models/Staff');
const emailService = require('./emailService');
const ApiError = require('../utils/ApiError');

class SubscriptionService {
  /**
   * Return standardized subscription plans and features
   */
  getPlans() {
    return {
      plans: [
        {
          id: 'plan_starter',
          name: 'Starter / Essential',
          badge: 'Basic',
          priceMonthly: 0,
          priceAnnual: 0,
          popular: false,
          description: 'Essential billing and table management for small cafes and food trucks.',
          features: [
            'Unlimited Table & Quick POS Billing',
            '1 Active Cashier Terminal',
            'Basic Menu & Category Management',
            'Realtime Dine-In, Takeaway, Delivery',
            'Standard Daily Sales Reports',
            'Thermal Receipt & KOT Printing',
          ],
          ctaLabel: 'Current Free Plan',
          isCurrent: true,
        },
        {
          id: 'plan_growth',
          name: 'Growth / Pro All-in-One',
          badge: 'Most Popular 🔥',
          priceMonthly: 999,
          priceAnnual: 7999,
          annualSavingsText: 'Save 33% (₹7,999/yr)',
          popular: true,
          description: 'The complete powerhouse suite for growing restaurants and multi-floor outlets.',
          features: [
            'Everything in Starter, plus:',
            '📦 Advanced Inventory & Low-Stock Alerts',
            '👑 Full Loyalty & Customer Rewards Engine',
            '📢 Marketing Campaign & Promo Hub',
            '⚡ Multi-Device Realtime Cloud Sync',
            '📱 Dynamic UPI QR Payments & Auto-Settlement',
            '📊 Advanced Multi-Filter Sales & Tax Reports',
            '👥 Unlimited Staff & Role Management',
            '⚡ 24/7 Priority Technical Support',
          ],
          ctaLabel: 'I\'m Interested',
          isCurrent: false,
        },
        {
          id: 'plan_enterprise',
          name: 'Enterprise / Multi-Branch',
          badge: 'Custom',
          priceMonthly: 2499,
          priceAnnual: 19999,
          annualSavingsText: 'Custom Setup & SLA',
          popular: false,
          description: 'Tailored for restaurant chains, franchises, and enterprise food businesses.',
          features: [
            'Everything in Growth / Pro, plus:',
            '🏢 Multi-Branch Centralized Dashboard',
            '🔄 Central Kitchen & Cross-Store Inventory',
            '🌐 Custom Domain & Branded Customer App',
            '💳 Custom Payment Gateway & Direct Bank APIs',
            '🛠️ Dedicated Account Manager & SLA Support',
            '📈 AI-Powered Sales Forecasting & Cost Optimization',
          ],
          ctaLabel: 'Request Demo / Talk to Sales',
          isCurrent: false,
        },
      ],
      addons: [
        {
          id: 'addon_inventory',
          name: 'Inventory Pro Addon',
          icon: 'inventory_2',
          priceMonthly: 499,
          description: 'Raw material tracking, recipe costing, low stock WhatsApp notifications.',
        },
        {
          id: 'addon_loyalty',
          name: 'Loyalty & Cashback Suite',
          icon: 'card_giftcard',
          priceMonthly: 499,
          description: 'Visit-made rewards, points redemption, customer tiers & branded passes.',
        },
        {
          id: 'addon_campaign',
          name: 'Marketing & Broadcast Hub',
          icon: 'campaign',
          priceMonthly: 499,
          description: 'Automated WhatsApp promo broadcasts, festival offers & coupon codes.',
        },
      ],
    };
  }

  /**
   * Create Subscription Lead and Notify sooftcode@gmail.com
   */
  async createLead(leadData, user = null, business = null) {
    if (!leadData.phone || String(leadData.phone).trim().length === 0) {
      throw ApiError.badRequest('Phone number is required');
    }

    const restaurantName = leadData.restaurantName || business?.name || user?.companyName || 'My Restaurant';
    const contactPerson = leadData.contactPerson || user?.name || restaurantName;
    const phone = String(leadData.phone).trim();
    const email = leadData.email ? String(leadData.email).trim().toLowerCase() : (user?.email || '');
    const selectedPlan = leadData.selectedPlan || 'Growth / Pro Plan';
    const billingCycle = leadData.billingCycle || 'annual';
    const sourceFeature = leadData.sourceFeature || 'subscription_screen';
    const notes = leadData.notes || '';
    const price = Number(leadData.price || 0);
    const interestedFeatures = Array.isArray(leadData.interestedFeatures) ? leadData.interestedFeatures : [];

    // 1. Save Lead to MongoDB
    const lead = new SubscriptionLead({
      businessId: business?._id || user?.businessId || null,
      userId: user?._id || null,
      restaurantName,
      contactPerson,
      phone,
      email,
      selectedPlan,
      billingCycle,
      price,
      sourceFeature,
      interestedFeatures,
      notes,
      status: 'new',
      emailNotificationRecipient: 'sooftcode@gmail.com',
    });

    await lead.save();
    console.log(`[SubscriptionService] Lead saved with ID: ${lead._id} for ${restaurantName}`);

    // 2. Dispatch Email Notification to sooftcode@gmail.com
    let emailResult = { sent: false };
    try {
      emailResult = await emailService.sendLeadNotificationEmail(lead);
      lead.emailNotificationSent = emailResult.sent === true;
      if (!emailResult.sent && emailResult.error) {
        lead.emailNotificationError = emailResult.error;
      }
      await lead.save();
    } catch (emailErr) {
      console.error(`[SubscriptionService] Email dispatch failed:`, emailErr.message);
      lead.emailNotificationError = emailErr.message;
      await lead.save();
    }

    // 3. Create In-App Notification if user or business exists
    try {
      if (business?._id || user?._id) {
        await Notification.create({
          userId: user?._id || null,
          businessId: business?._id || null,
          type: 'new_lead',
          title: 'Interest Received!',
          message: `Thank you for your interest in ${selectedPlan}. Our team will contact you at ${phone} shortly!`,
          entityType: 'lead',
          entityId: lead._id.toString(),
          metadata: {
            plan: selectedPlan,
            phone,
            source: sourceFeature,
          },
        });
      }
    } catch (notifErr) {
      console.warn(`[SubscriptionService] In-app notification creation non-blocking error:`, notifErr.message);
    }

    return {
      success: true,
      message: 'Thank you! Your interest has been submitted. Our sales team will get in touch with you shortly.',
      leadId: lead._id,
      emailSent: lead.emailNotificationSent,
      recipient: 'sooftcode@gmail.com',
    };
  }

  /**
   * Get all leads for admin / business review
   */
  async getLeads(businessId = null) {
    const filter = businessId ? { businessId } : {};
    return SubscriptionLead.find(filter).sort({ createdAt: -1 }).limit(100);
  }

  /**
   * Get Current Business / User / Staff Subscription Status
   */
  async getStatus(businessId = null, userId = null, staffId = null) {
    let business = null;
    let user = null;
    let staff = null;

    if (staffId) {
      staff = await Staff.findById(staffId);
      if (staff && !businessId) businessId = staff.businessId;
      if (staff && staff.userId && !userId) userId = staff.userId;
    }

    if (businessId) {
      business = await Business.findById(businessId);
    }
    if (userId) {
      user = await User.findById(userId);
      if (!business && user) {
        business = await Business.findOne({ ownerId: user._id });
      }
      if (!staff && user && user.staffId) {
        staff = await Staff.findById(user.staffId);
      }
    }

    const targetBizId = business?._id || businessId;
    const targetUserId = user?._id || userId;
    const targetStaffId = staff?._id || staffId;

    // 1. Primary Authority: Check the new "subscriptions" collection
    let subDoc = null;
    if (targetStaffId) {
      subDoc = await Subscription.findOne({ staffId: targetStaffId }).sort({ createdAt: -1 });
    }
    if (!subDoc && targetBizId) {
      subDoc = await Subscription.findOne({ businessId: targetBizId }).sort({ createdAt: -1 });
    }
    if (!subDoc && targetUserId) {
      subDoc = await Subscription.findOne({ userId: targetUserId }).sort({ createdAt: -1 });
    }
    if (!subDoc && user?.email) {
      subDoc = await Subscription.findOne({ userEmail: user.email.toLowerCase().trim() }).sort({ createdAt: -1 });
    }

    let isSubscribed = false;
    let plan = 'standard';
    let amount = 300;
    let upiId = '9709593705@ybl';
    let paymentRef = '';
    let activatedAt = null;
    let expiresAt = null;
    let targetType = 'business';

    if (subDoc) {
      // Document found in the new subscriptions collection
      if (subDoc.isActive !== undefined && subDoc.isActive !== null) {
        isSubscribed = Boolean(subDoc.isActive);
      } else {
        isSubscribed = subDoc.status === 'active';
      }

      // Check if past expiry
      if (subDoc.expiresAt && new Date(subDoc.expiresAt) < new Date()) {
        isSubscribed = false;
      }

      plan = subDoc.plan || 'standard';
      amount = subDoc.amount || 300;
      upiId = subDoc.upiId || '9709593705@ybl';
      paymentRef = subDoc.paymentRef || '';
      activatedAt = subDoc.activatedAt || subDoc.createdAt || null;
      expiresAt = subDoc.expiresAt || null;
      targetType = subDoc.targetType || (targetStaffId ? 'staff' : 'business');
    } else {
      // Fallback to legacy embedded business/user/staff subscription
      const bizSub = business?.subscription || {};
      const userSub = user?.subscription || {};
      const staffSub = staff?.subscription || {};

      if (bizSub.isActive !== undefined && bizSub.isActive !== null) {
        isSubscribed = Boolean(bizSub.isActive);
      } else if (bizSub.status !== undefined && bizSub.status !== null) {
        isSubscribed = bizSub.status === 'active';
      } else if (userSub.isActive !== undefined && userSub.isActive !== null) {
        isSubscribed = Boolean(userSub.isActive);
      } else if (userSub.status !== undefined && userSub.status !== null) {
        isSubscribed = userSub.status === 'active';
      } else if (staffSub.isActive !== undefined) {
        isSubscribed = Boolean(staffSub.isActive);
      }

      plan = bizSub.plan || userSub.plan || staffSub.plan || 'standard';
      amount = bizSub.amount || 300;
      upiId = bizSub.upiId || '9709593705@ybl';
      paymentRef = bizSub.paymentRef || userSub.paymentRef || '';
      activatedAt = bizSub.activatedAt || userSub.startDate || null;
      expiresAt = bizSub.expiresAt || userSub.expiresAt || null;

      // Seed / Upsert into the new "subscriptions" collection so it appears immediately in MongoDB Compass
      if (targetBizId || targetUserId) {
        try {
          subDoc = await Subscription.create({
            businessId: targetBizId || null,
            userId: targetUserId || null,
            staffId: targetStaffId || null,
            targetType: targetStaffId ? 'staff' : 'business',
            userEmail: user?.email || '',
            userName: user?.name || business?.profile?.name || staff?.name || '',
            businessName: business?.profile?.companyName || 'My Restaurant',
            phone: user?.phone || business?.profile?.phone || staff?.phone || '',
            plan,
            amount,
            isActive: isSubscribed,
            status: isSubscribed ? 'active' : 'inactive',
            upiId,
            paymentRef,
            activatedAt: activatedAt || new Date(),
            expiresAt: expiresAt || null,
          });
        } catch (_) {}
      }
    }

    const upiPayUrl = `upi://pay?pa=${upiId}&pn=Apna%20POS&am=${amount}&cu=INR&tn=Apna%20POS%20Subscription%20Unlock`;

    return {
      isActive: isSubscribed,
      isSubscribed,
      status: isSubscribed ? 'active' : 'inactive',
      plan,
      amount,
      upiId,
      upiPayUrl,
      activatedAt,
      expiresAt,
      paymentRef,
      targetType,
      businessId: targetBizId || null,
      userId: targetUserId || null,
      staffId: targetStaffId || null,
      subscriptionId: subDoc?._id || null,
    };
  }

  /**
   * Unlock / Activate Subscription upon UPI payment
   */
  async activateSubscription(businessId = null, userId = null, paymentData = {}) {
    let business = null;
    let user = null;

    const targetBizId = businessId || paymentData.businessId;
    const targetUserId = userId || paymentData.userId;

    if (targetBizId) {
      business = await Business.findById(targetBizId);
    }
    if (targetUserId) {
      user = await User.findById(targetUserId);
      if (!business && user) {
        business = await Business.findOne({ ownerId: user._id });
      }
    }

    if (!business && !user) {
      business = await Business.findOne().sort({ createdAt: -1 });
      if (business) {
        user = await User.findById(business.ownerId);
      } else {
        user = await User.findOne().sort({ createdAt: -1 });
      }
    }

    const ref = paymentData.paymentRef || paymentData.transactionId || paymentData.utr || `UPI_${Date.now()}`;
    const now = new Date();
    const expiry = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days active
    const amount = Number(paymentData.amount) || 300;

    // 1. Create or Update document in the new "subscriptions" collection
    const subFilter = business?._id
      ? { businessId: business._id }
      : (user?._id ? { userId: user._id } : { userEmail: user?.email || 'admin@apnapos.com' });

    const subscription = await Subscription.findOneAndUpdate(
      subFilter,
      {
        businessId: business?._id || null,
        userId: user?._id || business?.ownerId || null,
        targetType: 'business',
        userEmail: user?.email || '',
        userName: user?.name || business?.profile?.name || '',
        businessName: business?.profile?.companyName || 'My Restaurant',
        phone: user?.phone || business?.profile?.phone || '',
        plan: paymentData.plan || 'standard',
        billingCycle: paymentData.billingCycle || 'monthly',
        amount,
        currency: 'INR',
        isActive: true,
        status: 'active',
        upiId: '9709593705@ybl',
        paymentRef: ref,
        paymentMethod: paymentData.paymentMethod || 'upi',
        activatedAt: now,
        expiresAt: expiry,
        features: ['pos', 'tables', 'orders', 'reports', 'inventory', 'loyalty', 'campaign', 'staff'],
      },
      { upsert: true, new: true }
    );

    // 2. Sync to Business model
    if (business) {
      business.subscription = business.subscription || {};
      business.subscription.isActive = true;
      business.subscription.status = 'active';
      business.subscription.amount = amount;
      business.subscription.upiId = '9709593705@ybl';
      business.subscription.activatedAt = now;
      business.subscription.expiresAt = expiry;
      business.subscription.paymentRef = ref;
      await business.save();
    }

    // 3. Sync to User model
    if (user) {
      user.subscription = user.subscription || {};
      user.subscription.isActive = true;
      user.subscription.status = 'active';
      user.subscription.startDate = now;
      user.subscription.expiresAt = expiry;
      user.subscription.paymentRef = ref;
      await user.save();
    }

    // 4. Also activate all staff belonging to this business
    if (business?._id) {
      try {
        await Staff.updateMany(
          { businessId: business._id },
          {
            $set: {
              'subscription.isActive': true,
              'subscription.status': 'active',
              'subscription.plan': 'standard',
              'subscription.assignedAt': now,
              'subscription.expiresAt': expiry,
            },
          }
        );
      } catch (_) {}
    }

    // 5. Trigger in-app notification
    try {
      if (business?._id) {
        await Notification.create({
          businessId: business._id,
          title: '🎉 Subscription Activated!',
          message: `Your Apna POS subscription is now active until ${expiry.toLocaleDateString()}. Thank you!`,
          type: 'system',
          read: false,
        });
      }
    } catch (_) {}

    return {
      isActive: true,
      isSubscribed: true,
      status: 'active',
      plan: subscription.plan || 'standard',
      amount,
      upiId: '9709593705@ybl',
      paymentRef: ref,
      activatedAt: now,
      expiresAt: expiry,
      subscriptionId: subscription._id,
    };
  }

  /**
   * Assign / Activate Subscription for a Specific Staff Member
   */
  async assignStaffSubscription({ businessId, staffId, userId, plan = 'standard', amount = 300, days = 30, isActive = true }) {
    if (!staffId && !userId) {
      throw ApiError.badRequest('Staff ID or User ID is required');
    }

    let staff = null;
    if (staffId) staff = await Staff.findById(staffId);
    let user = null;
    if (userId) user = await User.findById(userId);
    let business = null;
    if (businessId) business = await Business.findById(businessId);

    const now = new Date();
    const expiry = new Date(Date.now() + days * 24 * 60 * 60 * 1000);

    const subDoc = await Subscription.findOneAndUpdate(
      { staffId: staff?._id || staffId },
      {
        businessId: business?._id || staff?.businessId || null,
        userId: user?._id || staff?.userId || null,
        staffId: staff?._id || staffId,
        targetType: 'staff',
        userEmail: staff?.email || user?.email || '',
        userName: staff?.name || user?.name || '',
        businessName: business?.profile?.companyName || 'My Restaurant',
        phone: staff?.phone || user?.phone || '',
        plan,
        amount,
        isActive: Boolean(isActive),
        status: isActive ? 'active' : 'inactive',
        activatedAt: now,
        expiresAt: expiry,
      },
      { upsert: true, new: true }
    );

    if (staff) {
      staff.subscription = {
        isActive: Boolean(isActive),
        status: isActive ? 'active' : 'inactive',
        plan,
        assignedAt: now,
        expiresAt: expiry,
      };
      await staff.save();
    }

    return subDoc;
  }

  /**
   * Update subscription directly (e.g. from Compass, SuperAdmin, or API toggle)
   */
  async updateStatus(businessId = null, userId = null, subData = {}) {
    let business = null;
    let user = null;

    if (businessId) {
      business = await Business.findById(businessId);
    }
    if (userId) {
      user = await User.findById(userId);
      if (!business && user) {
        business = await Business.findOne({ ownerId: user._id });
      }
    }

    const isActive = subData.isActive !== undefined ? Boolean(subData.isActive) : (subData.status === 'active');
    const status = isActive ? 'active' : (subData.status || 'inactive');

    const filter = subData.subscriptionId
      ? { _id: subData.subscriptionId }
      : (business?._id ? { businessId: business._id } : { userId: user?._id });

    if (subData.subscriptionId || business?._id || user?._id) {
      await Subscription.findOneAndUpdate(
        filter,
        {
          $set: {
            isActive,
            status,
            ...(subData.plan && { plan: subData.plan }),
            ...(subData.amount && { amount: Number(subData.amount) }),
            ...(subData.expiresAt && { expiresAt: new Date(subData.expiresAt) }),
          },
        },
        { upsert: true }
      );
    }

    if (business) {
      business.subscription = business.subscription || {};
      business.subscription.isActive = isActive;
      business.subscription.status = status;
      if (subData.plan) business.subscription.plan = subData.plan;
      if (subData.amount) business.subscription.amount = Number(subData.amount);
      if (subData.expiresAt) business.subscription.expiresAt = new Date(subData.expiresAt);
      await business.save();
    }

    if (user) {
      user.subscription = user.subscription || {};
      user.subscription.isActive = isActive;
      user.subscription.status = status;
      if (subData.plan) user.subscription.plan = subData.plan;
      if (subData.expiresAt) user.subscription.expiresAt = new Date(subData.expiresAt);
      await user.save();
    }

    return this.getStatus(business?._id, user?._id);
  }

  /**
   * Get all subscriptions for Admin/Compass list view
   */
  async getAllSubscriptions(query = {}) {
    const filter = {};
    if (query.targetType) filter.targetType = query.targetType;
    if (query.status) filter.status = query.status;
    if (query.isActive !== undefined) filter.isActive = query.isActive === 'true' || query.isActive === true;
    if (query.search) {
      filter.$or = [
        { userName: { $regex: query.search, $options: 'i' } },
        { userEmail: { $regex: query.search, $options: 'i' } },
        { businessName: { $regex: query.search, $options: 'i' } },
        { phone: { $regex: query.search, $options: 'i' } },
        { paymentRef: { $regex: query.search, $options: 'i' } },
      ];
    }

    const page = Math.max(1, parseInt(query.page, 10) || 1);
    const limit = Math.min(100, parseInt(query.limit, 10) || 20);
    const skip = (page - 1) * limit;

    const [subscriptions, total] = await Promise.all([
      Subscription.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit),
      Subscription.countDocuments(filter),
    ]);

    return {
      subscriptions,
      pagination: {
        total,
        page,
        limit,
        pages: Math.ceil(total / limit),
      },
    };
  }
}

module.exports = new SubscriptionService();
