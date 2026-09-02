const { SubscriptionLead } = require('../models/SubscriptionLead');
const { Notification } = require('../models/Notification');
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
}

module.exports = new SubscriptionService();
