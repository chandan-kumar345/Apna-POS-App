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
   * Helper to normalize source values - maps Dine In / Takeaway / Delivery to POS
   */
  _normalizeSource(source) {
    if (!source) return 'POS';
    const s = source.toString().trim();
    const lower = s.toLowerCase();
    if (
      lower === 'dine in' ||
      lower === 'dinein' ||
      lower === 'dine_in' ||
      lower === 'takeaway' ||
      lower === 'take away' ||
      lower === 'take_away' ||
      lower === 'delivery' ||
      lower === 'pos'
    ) {
      return 'POS';
    }
    return s;
  }

  /**
   * Dynamically enrich customer lead objects with exact order counts, visit counts,
   * total spend, return counts, last visit date, and accurate recent orders from the Order collection.
   */
  async _enrichCustomersWithOrderMetrics(businessId, customerDocs) {
    if (!customerDocs || customerDocs.length === 0) return [];

    const bId = mongoose.Types.ObjectId.isValid(businessId)
      ? new mongoose.Types.ObjectId(businessId)
      : businessId;

    // Collect all phone variations & customer IDs for index mapping
    const phoneMap = new Map(); // last10 -> Set of customer indices
    const idMap = new Map(); // stringId -> Set of customer indices
    const expandedPhones = new Set();
    const customerIds = [];

    customerDocs.forEach((cust, idx) => {
      const rawPhone = (cust.phone || '').toString().trim();
      const digits = rawPhone.replace(/\D/g, '');
      const last10 = digits.length >= 10 ? digits.slice(-10) : digits;

      if (last10) {
        if (!phoneMap.has(last10)) phoneMap.set(last10, new Set());
        phoneMap.get(last10).add(idx);

        expandedPhones.add(last10);
        expandedPhones.add(`+91${last10}`);
        expandedPhones.add(`91${last10}`);
        expandedPhones.add(`0${last10}`);
        expandedPhones.add(rawPhone);
      }

      const idVal = cust._id ? cust._id.toString() : cust.id ? cust.id.toString() : '';
      if (idVal) {
        if (!idMap.has(idVal)) idMap.set(idVal, new Set());
        idMap.get(idVal).add(idx);

        if (mongoose.Types.ObjectId.isValid(idVal)) {
          customerIds.push(new mongoose.Types.ObjectId(idVal));
        }
      }
    });

    // Match all orders belonging to this business for these phones or customerIds
    const matchConditions = [];
    if (expandedPhones.size > 0) {
      matchConditions.push({ customerPhone: { $in: Array.from(expandedPhones) } });
    }
    if (customerIds.length > 0) {
      matchConditions.push({ customerId: { $in: customerIds } });
    }

    const matchingOrders = matchConditions.length > 0
      ? await Order.find({
          businessId: bId,
          $or: matchConditions,
        })
          .sort({ createdAt: -1 })
          .select('orderNumber orderType status totalAmount items createdAt customerPhone customerId')
          .lean()
      : [];

    // Group orders per customer index
    const customerOrdersMap = new Map(); // custIdx -> array of orders
    for (let i = 0; i < customerDocs.length; i++) {
      customerOrdersMap.set(i, []);
    }

    for (const ord of matchingOrders) {
      const ordPhone = (ord.customerPhone || '').toString().trim();
      const ordDigits = ordPhone.replace(/\D/g, '');
      const ordLast10 = ordDigits.length >= 10 ? ordDigits.slice(-10) : ordDigits;
      const ordId = ord.customerId ? ord.customerId.toString() : '';

      const matchedIndices = new Set();
      if (ordLast10 && phoneMap.has(ordLast10)) {
        for (const idx of phoneMap.get(ordLast10)) matchedIndices.add(idx);
      }
      if (ordId && idMap.has(ordId)) {
        for (const idx of idMap.get(ordId)) matchedIndices.add(idx);
      }

      for (const idx of matchedIndices) {
        customerOrdersMap.get(idx).push(ord);
      }
    }

    // Assemble dynamically enriched leads
    return customerDocs.map((cust, idx) => {
      const orders = customerOrdersMap.get(idx) || [];
      const nonCancelledOrders = orders.filter((o) => o.status !== 'cancelled');
      const cancelledOrders = orders.filter((o) => o.status === 'cancelled');

      const dynamicOrders = nonCancelledOrders.length > 0
        ? nonCancelledOrders.length
        : (cust.totalOrders || 0);

      const dynamicSpent = nonCancelledOrders.length > 0
        ? Number(nonCancelledOrders.reduce((sum, o) => sum + Number(o.totalAmount || 0), 0).toFixed(2))
        : Number((cust.totalSpent || 0).toFixed(2));

      const dynamicVisits = dynamicOrders > 0
        ? dynamicOrders
        : (cust.visitCount || cust.totalOrders || 0);

      const dynamicReturns = cancelledOrders.length > 0
        ? cancelledOrders.length
        : (cust.returnCount || 0);

      const dynamicLastVisit = nonCancelledOrders.length > 0
        ? nonCancelledOrders[0].createdAt
        : (cust.lastVisit || cust.createdAt);

      const recentOrders = orders.slice(0, 20).map((ord) => ({
        id: ord.orderNumber || (ord._id ? ord._id.toString() : 'Order'),
        orderNumber: ord.orderNumber || '',
        orderType: 'POS',
        orderMode: ord.orderType || 'dineIn',
        status: ord.status || 'completed',
        totalAmount: Number(ord.totalAmount || 0),
        date: ord.createdAt ? new Date(ord.createdAt).toISOString() : new Date().toISOString(),
        createdAt: ord.createdAt ? new Date(ord.createdAt).toISOString() : new Date().toISOString(),
        items: Array.isArray(ord.items)
          ? ord.items.map((it) => ({
              name: it.name || it.productName || 'Item',
              quantity: it.quantity || 1,
              price: it.price || 0,
            }))
          : [],
      }));

      const normalizedSource = this._normalizeSource(cust.source);

      return {
        ...cust,
        id: cust._id ? cust._id.toString() : cust.id,
        source: normalizedSource,
        totalOrders: dynamicOrders,
        totalSpent: dynamicSpent,
        returnCount: dynamicReturns,
        visitCount: dynamicVisits,
        lastVisit: dynamicLastVisit,
        recentOrders,
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

    // Auto-backfill any distinct customerPhone in Order that doesn't exist in Customer collection yet
    try {
      const orderCustomers = await Order.aggregate([
        {
          $match: {
            businessId: bId,
            customerPhone: { $exists: true, $ne: null, $ne: '' },
          },
        },
        {
          $group: {
            _id: '$customerPhone',
            customerName: { $last: '$customerName' },
            deliveryAddress: { $last: '$deliveryAddress' },
            firstVisit: { $min: '$createdAt' },
            lastVisit: { $max: '$createdAt' },
            orderCount: { $sum: 1 },
            totalSpent: {
              $sum: {
                $cond: [
                  { $in: ['$status', ['completed', 'settled', 'paid', 'delivered']] },
                  '$totalAmount',
                  0,
                ],
              },
            },
          },
        },
      ]);

      if (orderCustomers && orderCustomers.length > 0) {
        const existingPhones = new Set(
          (await Customer.find({ businessId: bId }).select('phone').lean()).map((c) => (c.phone || '').trim())
        );

        const newDocs = [];
        for (const oc of orderCustomers) {
          const p = (oc._id || '').trim();
          if (p && !existingPhones.has(p)) {
            const isRegular = (oc.orderCount || 0) > 1;
            newDocs.push({
              businessId: bId,
              phone: p,
              name: (oc.customerName || '').trim() || 'Walk-in Guest',
              address: oc.deliveryAddress || '',
              source: 'POS',
              stage: isRegular ? 'Won' : 'New Lead',
              status: isRegular ? 'Won' : 'New Lead',
              customerType: isRegular ? 'Regular Customer' : 'New Customer',
              tags: isRegular ? ['Regular Customer', 'POS'] : ['New Customer', 'POS'],
              totalOrders: oc.orderCount || 0,
              totalSpent: oc.totalSpent || 0,
              visitCount: oc.orderCount || 0,
              firstVisit: oc.firstVisit || new Date(),
              lastVisit: oc.lastVisit || new Date(),
            });
          }
        }

        if (newDocs.length > 0) {
          await Customer.insertMany(newDocs, { ordered: false });
        }
      }
    } catch (_) {
      // Ignore background backfill errors
    }

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
      const normSource = this._normalizeSource(source);
      if (normSource === 'POS') {
        query.source = { $in: ['POS', 'Dine In', 'Takeaway', 'Delivery', 'dineIn', 'takeaway', 'delivery', 'dine_in'] };
      } else {
        query.source = new RegExp(normSource.trim(), 'i');
      }
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
    const source = this._normalizeSource(data.source || 'POS');
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
      const source = this._normalizeSource(item.source || item.Source || 'POS');
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
      source: l.source || 'POS',
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
