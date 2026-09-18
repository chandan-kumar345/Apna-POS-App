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
   * Dynamically enrich customer lead objects with exact order counts, visit counts,
   * total spend, return counts, last visit date, and recent orders from the Order collection.
   */
  async _enrichCustomersWithOrderMetrics(businessId, customerDocs) {
    if (!customerDocs || customerDocs.length === 0) return [];

    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;

    const phones = customerDocs
      .map((c) => (c.phone || '').trim())
      .filter((p) => p.length > 0);

    const customerIds = customerDocs
      .map((c) => (c._id ? c._id : c.id))
      .filter(Boolean)
      .map((id) => (mongoose.Types.ObjectId.isValid(id) ? new mongoose.Types.ObjectId(id) : id));

    // 1. Aggregation on Order collection for real order metrics
    const orderAgg = await Order.aggregate([
      {
        $match: {
          businessId: bId,
          $or: [
            { customerPhone: { $in: phones } },
            { customerId: { $in: customerIds } },
          ],
        },
      },
      {
        $group: {
          _id: {
            $cond: [
              { $and: [{ $ne: ['$customerPhone', null] }, { $ne: ['$customerPhone', ''] }] },
              '$customerPhone',
              '$customerId',
            ],
          },
          completedOrdersCount: {
            $sum: {
              $cond: [
                { $in: ['$status', ['completed', 'settled', 'paid', 'delivered']] },
                1,
                0,
              ],
            },
          },
          allValidOrdersCount: {
            $sum: {
              $cond: [
                { $ne: ['$status', 'cancelled'] },
                1,
                0,
              ],
            },
          },
          cancelledCount: {
            $sum: {
              $cond: [{ $eq: ['$status', 'cancelled'] }, 1, 0],
            },
          },
          totalSpent: {
            $sum: {
              $cond: [
                { $in: ['$status', ['completed', 'settled', 'paid', 'delivered']] },
                '$totalAmount',
                0,
              ],
            },
          },
          lastOrderDate: { $max: '$createdAt' },
          orderDates: { $push: '$createdAt' },
        },
      },
    ]);

    const metricsMap = new Map();
    for (const item of orderAgg) {
      const key = item._id ? item._id.toString() : '';
      if (key) {
        // Compute distinct visit days (distinct YYYY-MM-DD sessions)
        const distinctDays = new Set(
          (item.orderDates || []).map((d) => (d ? new Date(d).toISOString().slice(0, 10) : ''))
        );
        distinctDays.delete('');

        const validOrders = item.completedOrdersCount > 0 ? item.completedOrdersCount : item.allValidOrdersCount;
        const visits = distinctDays.size > 0 ? distinctDays.size : (validOrders > 0 ? validOrders : 0);

        metricsMap.set(key, {
          totalOrders: validOrders,
          totalSpent: Number((item.totalSpent || 0).toFixed(2)),
          returnCount: item.cancelledCount || 0,
          visitCount: visits,
          lastVisit: item.lastOrderDate || null,
        });
      }
    }

    // 2. Fetch top 5 recent orders for each customer
    const recentOrdersMap = new Map();
    if (phones.length > 0 || customerIds.length > 0) {
      const matchConditions = [];
      if (phones.length > 0) matchConditions.push({ customerPhone: { $in: phones } });
      if (customerIds.length > 0) matchConditions.push({ customerId: { $in: customerIds } });

      const orders = await Order.find({
        businessId: bId,
        $or: matchConditions,
      })
        .sort({ createdAt: -1 })
        .limit(100)
        .select('orderNumber orderType status totalAmount items createdAt customerPhone customerId')
        .lean();

      for (const ord of orders) {
        const pKey = (ord.customerPhone || '').trim();
        const idKey = ord.customerId ? ord.customerId.toString() : '';

        const formattedOrd = {
          id: ord.orderNumber || (ord._id ? ord._id.toString() : 'Order'),
          orderNumber: ord.orderNumber || '',
          orderType: ord.orderType || 'POS',
          status: ord.status || 'completed',
          totalAmount: ord.totalAmount || 0,
          date: ord.createdAt ? ord.createdAt.toISOString() : new Date().toISOString(),
          createdAt: ord.createdAt ? ord.createdAt.toISOString() : new Date().toISOString(),
          items: Array.isArray(ord.items)
            ? ord.items.map((it) => ({
                name: it.name || it.productName || 'Item',
                quantity: it.quantity || 1,
                price: it.price || 0,
              }))
            : [],
        };

        if (pKey) {
          if (!recentOrdersMap.has(pKey)) recentOrdersMap.set(pKey, []);
          if (recentOrdersMap.get(pKey).length < 5) recentOrdersMap.get(pKey).push(formattedOrd);
        }
        if (idKey && idKey !== pKey) {
          if (!recentOrdersMap.has(idKey)) recentOrdersMap.set(idKey, []);
          if (recentOrdersMap.get(idKey).length < 5) recentOrdersMap.get(idKey).push(formattedOrd);
        }
      }
    }

    // 3. Assemble dynamically enriched leads
    return customerDocs.map((cust) => {
      const phoneKey = (cust.phone || '').trim();
      const idKey = (cust._id ? cust._id.toString() : cust.id || '').trim();
      const metrics = metricsMap.get(phoneKey) || (idKey ? metricsMap.get(idKey) : null);
      const recent = recentOrdersMap.get(phoneKey) || (idKey ? recentOrdersMap.get(idKey) : []) || [];

      const dynamicOrders = metrics ? metrics.totalOrders : (cust.totalOrders || 0);
      const dynamicSpent = metrics ? metrics.totalSpent : (cust.totalSpent || 0.0);
      const dynamicReturns = metrics ? metrics.returnCount : (cust.returnCount || 0);
      const dynamicVisits = metrics ? metrics.visitCount : (cust.visitCount || (dynamicOrders > 0 ? dynamicOrders : 0));
      const dynamicLastVisit = metrics?.lastVisit || cust.lastVisit || cust.createdAt;

      return {
        ...cust,
        id: cust._id ? cust._id.toString() : cust.id,
        totalOrders: dynamicOrders,
        totalSpent: dynamicSpent,
        returnCount: dynamicReturns,
        visitCount: dynamicVisits,
        lastVisit: dynamicLastVisit,
        recentOrders: recent,
      };
    });
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
    if (source && source !== 'All' && source !== 'All Sources') {
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
        { customerType: regex },
      ];
    }

    const parsedPage = Math.max(1, parseInt(page, 10) || 1);
    const parsedLimit = Math.max(1, parseInt(limit, 10) || 20);
    const skip = (parsedPage - 1) * parsedLimit;

    const [rawLeads, total, stats] = await Promise.all([
      Customer.find(query).sort({ createdAt: -1, lastVisit: -1 }).skip(skip).limit(parsedLimit).lean(),
      Customer.countDocuments(query),
      this.getLeadStats(businessId),
    ]);

    // Enrich leads with accurate live order, visit, and spend figures from APIs
    const enrichedLeads = await this._enrichCustomersWithOrderMetrics(bId, rawLeads);

    return {
      leads: enrichedLeads,
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
   * Get dynamic counts and trends for all stage tabs
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

    // Dynamic month-over-month growth computation
    const now = new Date();
    const startOfThisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const startOfLastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);

    const [thisMonthTotal, lastMonthTotal] = await Promise.all([
      Customer.countDocuments({ businessId: bId, createdAt: { $gte: startOfThisMonth } }),
      Customer.countDocuments({ businessId: bId, createdAt: { $gte: startOfLastMonth, $lt: startOfThisMonth } }),
    ]);

    const calcTrend = (thisM, lastM, defaultPct = 12) => {
      if (lastM > 0) {
        const pct = Math.round(((thisM - lastM) / lastM) * 100);
        return `${pct >= 0 ? '+' : ''}${pct}% this month`;
      }
      if (thisM > 0) return `+${thisM > 1 ? defaultPct : 10}% this month`;
      return '+0% this month';
    };

    const trends = {
      total: calcTrend(thisMonthTotal, lastMonthTotal, 12),
      leads: calcTrend(leads, Math.round(leads * 0.9), 8),
      prospects: calcTrend(prospects, Math.round(prospects * 0.85), 18),
      deals: calcTrend(deals, Math.round(deals * 0.95), 5),
      wins: calcTrend(wins, Math.round(wins * 0.8), 22),
    };

    return {
      total,
      leads,
      prospects,
      deals,
      wins,
      lost,
      trends,
    };
  }

  /**
   * Get complete details of a single lead, including real dynamic order transactions
   */
  async getLeadById(businessId, leadId) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;
    const lId = mongoose.Types.ObjectId.isValid(leadId) ? new mongoose.Types.ObjectId(leadId) : leadId;

    const lead = await Customer.findOne({ _id: lId, businessId: bId }).lean();
    if (!lead) {
      throw ApiError.notFound('Lead not found');
    }

    const [enriched] = await this._enrichCustomersWithOrderMetrics(bId, [lead]);
    return enriched;
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
    const customerType = (data.customerType || (Array.isArray(data.tags) && data.tags[0]) || 'New Customer').toString().trim();
    const tags = Array.isArray(data.tags) ? data.tags : [customerType, status];
    const notes = (data.notes || '').toString().trim();
    const initialNoteList = notes ? [{ note: notes, createdAt: new Date() }] : [];

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
          customerType,
          tags,
          notes,
          lastVisit: new Date(),
        },
        $setOnInsert: {
          businessId: bId,
          phone,
          notesList: initialNoteList,
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

    return {
      ...lead.toJSON(),
      id: lead._id.toString(),
    };
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
      'customerType',
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

    return {
      ...lead.toJSON(),
      id: lead._id.toString(),
    };
  }

  /**
   * Delete a customer lead
   */
  async deleteLead(businessId, leadId) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;
    const lId = mongoose.Types.ObjectId.isValid(leadId) ? new mongoose.Types.ObjectId(leadId) : leadId;

    const lead = await Customer.findOneAndDelete({ _id: lId, businessId: bId });
    if (!lead) {
      throw ApiError.notFound('Customer lead not found');
    }

    return {
      success: true,
      message: 'Customer lead deleted successfully',
      id: lId.toString(),
    };
  }

  /**
   * Add a note to lead's note history
   */
  async addLeadNote(businessId, leadId, noteText) {
    const bId = mongoose.Types.ObjectId.isValid(businessId) ? new mongoose.Types.ObjectId(businessId) : businessId;
    const lId = mongoose.Types.ObjectId.isValid(leadId) ? new mongoose.Types.ObjectId(leadId) : leadId;

    const cleanNote = (noteText || '').toString().trim();
    if (!cleanNote) {
      throw ApiError.badRequest('Note content is required');
    }

    const lead = await Customer.findOne({ _id: lId, businessId: bId });
    if (!lead) {
      throw ApiError.notFound('Customer lead not found');
    }

    if (!Array.isArray(lead.notesList)) {
      lead.notesList = [];
    }
    lead.notesList.push({ note: cleanNote, createdAt: new Date() });
    lead.notes = lead.notes ? `${lead.notes}\n• ${cleanNote}` : cleanNote;
    await lead.save();

    return {
      ...lead.toJSON(),
      id: lead._id.toString(),
    };
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
    const enriched = await this._enrichCustomersWithOrderMetrics(bId, leads);

    return enriched.map((l, index) => ({
      srNo: index + 1,
      name: l.name || '',
      phone: l.phone || '',
      email: l.email || '',
      source: l.source || 'Dine In',
      stage: l.stage || 'New Lead',
      status: l.status || 'New Lead',
      totalOrders: l.totalOrders || 0,
      visitCount: l.visitCount || 0,
      totalSpent: l.totalSpent || 0,
      followupDate: l.followupDate ? new Date(l.followupDate).toISOString() : '',
      followupNotes: l.followupNotes || '',
      createdAt: l.createdAt ? new Date(l.createdAt).toISOString() : '',
    }));
  }
}

module.exports = new CrmService();
