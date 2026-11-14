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
  async getStatus(businessId = null, userId = null) {
    if (!businessId && userId) {
      const user = await User.findById(userId);
      const business = user?.businessId ? await Business.findById(user.businessId) : await Business.findOne({ ownerId: userId });
      businessId = business?._id;
    }
    return require('./entitlementService').status(businessId, userId);
  }

  async activateSubscription(businessId, userId, paymentData = {}) {
    return require('./subscriptionRenewalService').verify(businessId, paymentData);
  }

  async assignStaffSubscription() {
    throw ApiError.badRequest('Subscription access is business-scoped. Update the business entitlement through the platform administrator.');
  }

  async updateStatus(businessId, userId, subData = {}) {
    const changes = {};
    for (const key of ['isSubscription', 'isChotuAiActive', 'subscriptionExpiresAt']) {
      if (subData[key] !== undefined) changes[key] = subData[key];
    }
    if (changes.isSubscription === undefined) {
      const legacy = subData.isSubscriptionActive ?? subData.isActive;
      if (legacy !== undefined) changes.isSubscription = legacy;
    }
    if (changes.subscriptionExpiresAt === undefined && subData.expiresAt !== undefined) changes.subscriptionExpiresAt = subData.expiresAt;
    return require('./entitlementService').updateControls(businessId, changes);
  }

  async syncAllOwnerUsers() {
    // Entitlement migration is explicit and reviewed; listing/startup never seeds
    // grants or invents expiry dates from user-level legacy flags.
    return { synchronized: 0 };
  }

  async getAllSubscriptions(query = {}) {
    // Listing does not write or seed entitlement records.

    const filter = {};
    if (query.targetType) filter.targetType = query.targetType;
    if (query.status || query.isActive !== undefined || query.isSubscriptionActive !== undefined) {
      const rows = await Business.collection.find({}).toArray();
      const desired = query.isActive ?? query.isSubscriptionActive;
      const ids = rows.filter((business) => {
        const current = require('./entitlementService').evaluate(business);
        return (!query.status || current.status === query.status)
          && (desired === undefined || current.isActive === (desired === true || desired === 'true'));
      }).map((business) => business._id);
      filter.businessId = { $in: ids };
    }
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
      Subscription.find(filter).sort({ userCreatedAt: -1, createdAt: -1 }).skip(skip).limit(limit),
      Subscription.countDocuments(filter),
    ]);

    const calculated = await Promise.all(subscriptions.map(async (record) => {
      const item = record.toObject();
      try { return { ...item, ...await require('./entitlementService').status(item.businessId, item.userId), _id: item._id }; }
      catch (_) { return { ...item, ...require('./entitlementService').evaluate(null) }; }
    }));
    return {
      subscriptions: calculated,
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
