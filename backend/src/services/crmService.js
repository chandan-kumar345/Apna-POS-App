const mongoose = require('mongoose');
const Customer = require('../models/Customer');
const Order = require('../models/Order');
const notificationService = require('./notificationService');
const ApiError = require('../utils/ApiError');

class CrmService {
  /**
   * Helper to normalize stage filter values
   */
  _normalizeStage(stage) {
    if (!stage || stage === 'All') return null;
    const s = stage.toString().toLowerCase().trim();
    if (s.includes('lead')) return ['New Lead', 'Lead', 'leads'];
    if (s.includes('prospect')) return ['Prospect', 'Prospects', 'prospect'];
    if (s.includes('deal')) return ['Deal', 'Deals', 'deal'];
    if (s.includes('win') || s.includes('won')) return ['Won', 'Wins', 'won'];
    if (s.includes('lost')) return ['Lost', 'lost'];
    return [stage];
  }

  /**
   * Get paginated leads with filtering, search, and dynamic stage statistics
   */
  async getLeads(businessId, {
    page = 1,
    limit = 20,
    search,
    stage,
    status,
    source,
    startDate,
    endDate,
  } = {}) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;
    const query = { businessId: bId };

    // Stage filter
    const stageValues = this._normalizeStage(stage);
    if (stageValues && stageValues.length > 0) {
      query.stage = { $in: stageValues };
    }

    // Status filter
    if (status && status !== 'All') {
      query.status = new RegExp(status.trim(), 'i');
    }

    // Source filter
    if (source && source !== 'All') {
      query.source = new RegExp(source.trim(), 'i');
    }

    // Date range filter
    if (startDate && endDate) {
      const start = new Date(startDate);
      const end = new Date(endDate);
      if (!isNaN(start.getTime()) && !isNaN(end.getTime())) {
        query.createdAt = { $gte: start, $lte: end };
      }
    }

    // Search filter
    if (search && search.trim()) {
      const regex = new RegExp(search.trim(), 'i');
      query.$or = [
        { name: regex },
        { phone: regex },
        { email: regex },
        { source: regex },
        { tags: regex },
      ];
    }

    const parsedPage = Math.max(1, parseInt(page, 10) || 1);
    const parsedLimit = Math.max(1, parseInt(limit, 10) || 20);
    const skip = (parsedPage - 1) * parsedLimit;

    const [leads, total, stats] = await Promise.all([
      Customer.find(query).sort({ createdAt: -1, lastVisit: -1 }).skip(skip).limit(parsedLimit).lean(),
      Customer.countDocuments(query),
      this.getLeadStats(businessId),
    ]);

    return {
      leads: leads.map((l) => ({
        ...l,
        id: l._id.toString(),
      })),
      pagination: {
        total,
        page: parsedPage,
        limit: parsedLimit,
        totalPages: Math.ceil(total / parsedLimit),
      },
      stats,
    };
  }

  /**
   * Get dynamic counts for all stage tabs
   */
  async getLeadStats(businessId) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;

    const agg = await Customer.aggregate([
      { $match: { businessId: bId } },
      {
        $group: {
          _id: { $toLower: '$stage' },
          count: { $sum: 1 },
        },
      },
    ]);

    let total = 0;
    let leads = 0;
    let prospects = 0;
    let deals = 0;
    let wins = 0;
    let lost = 0;

    for (const item of agg) {
      const st = item._id || '';
      const c = item.count || 0;
      total += c;
      if (st.includes('lead')) leads += c;
      else if (st.includes('prospect')) prospects += c;
      else if (st.includes('deal')) deals += c;
      else if (st.includes('win') || st.includes('won')) wins += c;
      else if (st.includes('lost')) lost += c;
      else leads += c;
    }

    return {
      total,
      leads,
      prospects,
      deals,
      wins,
      lost,
    };
  }

  /**
   * Get complete details of a single lead, including recent order transactions
   */
  async getLeadById(businessId, leadId) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;
    const lId = mongoose.Types.ObjectId.isValid(leadId) ? new mongoose.Types.ObjectId(leadId) : leadId;

    const lead = await Customer.findOne({ _id: lId, businessId: bId }).lean();
    if (!lead) {
      throw ApiError.notFound('Lead not found');
    }

    // Fetch up to 10 recent orders for this customer
    const phone = (lead.phone || '').trim();
    let recentOrders = [];
    if (phone) {
      recentOrders = await Order.find({
        businessId: bId,
        $or: [{ customerPhone: phone }, { customerId: lId }],
      })
        .sort({ createdAt: -1 })
        .limit(10)
        .select('orderNumber orderType status totalAmount items createdAt')
        .lean();
    }

    return {
      ...lead,
      id: lead._id.toString(),
      recentOrders,
    };
  }

  /**
   * Create or update a customer lead
   */
  async createLead(businessId, data) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;
    const phone = (data.phone || '').toString().trim();
    if (!phone) {
      throw ApiError.badRequest('Customer phone number is required');
    }

    const name = (data.name || '').toString().trim() || 'Guest Customer';
    const email = (data.email || '').toString().trim();
    const address = (data.address || '').toString().trim();
    const source = (data.source || 'Dine In').toString().trim();
    const stage = (data.stage || 'New Lead').toString().trim();
    const status = (data.status || 'New Lead').toString().trim();
    const tags = Array.isArray(data.tags) ? data.tags : [status];
    const notes = (data.notes || '').toString().trim();

    const lead = await Customer.findOneAndUpdate(
      { businessId: bId, phone },
      {
        $set: {
          name,
          email,
          address,
          source,
          stage,
          status,
          tags,
          notes,
          lastVisit: new Date(),
        },
        $setOnInsert: {
          businessId: bId,
          phone,
          firstVisit: new Date(),
          createdAt: new Date(),
        },
      },
      { upsert: true, new: true }
    );

    // Trigger New Lead Notification with idempotency
    try {
      await notificationService.createNotification({
        businessId: bId,
        type: 'new_lead',
        title: 'New Lead Generated',
        message: `A new lead has been added: ${lead.name}. Source: ${lead.source || 'Manual'}. Tap to view lead details.`,
        entityType: 'lead',
        entityId: lead._id.toString(),
        metadata: {
          leadId: lead._id.toString(),
          name: lead.name,
          source: lead.source,
          phone: lead.phone,
        },
        idempotencyKey: `new_lead_${lead._id.toString()}`,
      });
    } catch (err) {
      console.warn(`[Lead Notification Notice] ${err.message}`);
    }

    return lead;
  }

  /**
   * Update existing lead
   */
  async updateLead(businessId, leadId, updateData) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;
    const lId = mongoose.Types.ObjectId.isValid(leadId) ? new mongoose.Types.ObjectId(leadId) : leadId;

    const allowedFields = [
      'name',
      'phone',
      'email',
      'address',
      'source',
      'stage',
      'status',
      'tags',
      'notes',
      'followupDate',
      'followupNotes',
      'followupStatus',
      'isLiked',
      'isStarred',
    ];

    const setObj = {};
    for (const field of allowedFields) {
      if (updateData[field] !== undefined) {
        setObj[field] = updateData[field];
      }
    }

    const lead = await Customer.findOneAndUpdate(
      { _id: lId, businessId: bId },
      { $set: setObj },
      { new: true }
    );

    if (!lead) {
      throw ApiError.notFound('Lead not found');
    }

    return lead;
  }

  /**
   * Update lead stage
   */
  async updateLeadStage(businessId, leadId, stage) {
    return this.updateLead(businessId, leadId, { stage });
  }

  /**
   * Schedule or update a follow-up
   */
  async setFollowup(businessId, leadId, { followupDate, followupNotes, followupStatus = 'pending' }) {
    return this.updateLead(businessId, leadId, {
      followupDate: followupDate ? new Date(followupDate) : null,
      followupNotes: (followupNotes || '').toString().trim(),
      followupStatus,
    });
  }

  /**
   * Toggle like status
   */
  async toggleLike(businessId, leadId) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;
    const lId = mongoose.Types.ObjectId.isValid(leadId) ? new mongoose.Types.ObjectId(leadId) : leadId;

    const lead = await Customer.findOne({ _id: lId, businessId: bId });
    if (!lead) throw ApiError.notFound('Lead not found');

    lead.isLiked = !lead.isLiked;
    await lead.save();
    return lead;
  }

  /**
   * Toggle star/favorite status
   */
  async toggleStar(businessId, leadId) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;
    const lId = mongoose.Types.ObjectId.isValid(leadId) ? new mongoose.Types.ObjectId(leadId) : leadId;

    const lead = await Customer.findOne({ _id: lId, businessId: bId });
    if (!lead) throw ApiError.notFound('Lead not found');

    lead.isStarred = !lead.isStarred;
    await lead.save();
    return lead;
  }

  /**
   * Bulk import leads
   */
  async importLeads(businessId, leadsArray) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;
    if (!Array.isArray(leadsArray) || leadsArray.length === 0) {
      throw ApiError.badRequest('Array of leads is required for import');
    }

    let successCount = 0;
    for (const item of leadsArray) {
      const phone = (item.phone || item.Phone || '').toString().trim();
      if (!phone) continue;

      const name = (item.name || item.Name || 'Guest Customer').toString().trim();
      const email = (item.email || item.Email || '').toString().trim();
      const source = (item.source || item.Source || 'Dine In').toString().trim();
      const stage = (item.stage || item.Stage || 'New Lead').toString().trim();

      await Customer.findOneAndUpdate(
        { businessId: bId, phone },
        {
          $set: {
            name,
            email,
            source,
            stage,
            lastVisit: new Date(),
          },
          $setOnInsert: {
            businessId: bId,
            phone,
            firstVisit: new Date(),
            createdAt: new Date(),
          },
        },
        { upsert: true }
      );
      successCount++;
    }

    return { importedCount: successCount };
  }

  /**
   * Export all leads for CSV / Excel
   */
  async exportLeads(businessId) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;
    const leads = await Customer.find({ businessId: bId }).sort({ createdAt: -1 }).lean();

    return leads.map((l, index) => ({
      srNo: index + 1,
      name: l.name || '',
      phone: l.phone || '',
      email: l.email || '',
      source: l.source || 'Dine In',
      stage: l.stage || 'New Lead',
      status: l.status || 'New Lead',
      totalOrders: l.totalOrders || 0,
      totalSpent: l.totalSpent || 0,
      followupDate: l.followupDate ? l.followupDate.toISOString() : '',
      followupNotes: l.followupNotes || '',
      createdAt: l.createdAt ? l.createdAt.toISOString() : '',
    }));
  }
}

module.exports = new CrmService();
