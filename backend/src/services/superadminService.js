const mongoose = require('mongoose');
const User = require('../models/User');
const Business = require('../models/Business');
const Order = require('../models/Order');
const Product = require('../models/Product');
const Category = require('../models/Category');
const Table = require('../models/Table');
const Customer = require('../models/Customer');
const Staff = require('../models/Staff');
const Sale = require('../models/Sale');
const { Notification } = require('../models/Notification');
const { SubscriptionLead } = require('../models/SubscriptionLead');
const Cart = require('../models/Cart');
const Extra = require('../models/Extra');
const PrintLog = require('../models/PrintLog');
const ChotuActionLog = require('../models/ChotuActionLog');
const tokenService = require('./tokenService');
const ApiError = require('../utils/ApiError');

const SUPERADMIN_EMAIL = 'chandanyaduvanshi190@gmail.com';
const SUPERADMIN_PASSWORD_DEFAULT = 'Admin@12';

class SuperadminService {
  /**
   * Automatically ensure Super Admin user exists with credentials
   */
  async seedSuperAdmin() {
    try {
      const email = SUPERADMIN_EMAIL.toLowerCase();
      let user = await User.findOne({ email }).select('+passwordHash');

      if (!user) {
        console.log(`[SuperAdmin] Initializing master owner account for ${email}...`);
        const passwordHash = await User.hashPassword(SUPERADMIN_PASSWORD_DEFAULT);
        user = await User.create({
          email,
          phone: '+91 9709590000',
          passwordHash,
          role: 'superadmin',
          isSuperAdmin: true,
          status: 'active',
          emailVerified: true,
          phoneVerified: true,
          onboardingCompleted: true,
          onboardingStep: 4,
          subscription: {
            plan: 'enterprise',
            status: 'active',
            startDate: new Date(),
            expiresAt: new Date(Date.now() + 100 * 365 * 24 * 60 * 60 * 1000), // Lifetime
            billingCycle: 'lifetime',
            maxTables: 9999,
            maxStaff: 9999,
            notes: 'Master Platform Owner (SuperAdmin)',
          },
        });

        // Ensure Business entry exists
        await Business.create({
          ownerId: user._id,
          profile: {
            name: 'Chandan Yaduvanshi',
            companyName: 'Apna POS Master HQ',
            phone: '+91 9709590000',
          },
          business: {
            businessType: 'Headquarters',
            currency: 'INR',
            country: 'IN',
          },
        });

        console.log(`[SuperAdmin] Master owner account created successfully: ${email}`);
      } else {
        // Ensure flags are up to date
        let modified = false;
        if (!user.isSuperAdmin) {
          user.isSuperAdmin = true;
          modified = true;
        }
        if (user.role !== 'superadmin') {
          user.role = 'superadmin';
          modified = true;
        }
        if (user.status !== 'active') {
          user.status = 'active';
          modified = true;
        }

        // Verify password hash or ensure standard default is accepted
        const isPasswordValid = await user.comparePassword(SUPERADMIN_PASSWORD_DEFAULT);
        if (!isPasswordValid) {
          user.passwordHash = await User.hashPassword(SUPERADMIN_PASSWORD_DEFAULT);
          modified = true;
          console.log(`[SuperAdmin] Password synchronized for ${email}`);
        }

        if (modified) {
          await user.save();
          console.log(`[SuperAdmin] Master owner account privileges verified: ${email}`);
        }
      }
      return user;
    } catch (err) {
      console.error(`[SuperAdmin Seeding Warning]`, err.message);
    }
  }

  /**
   * Superadmin Login (strictly for chandanyaduvanshi190@gmail.com)
   */
  async login(email, password) {
    if (!email || !password) {
      throw ApiError.badRequest('Email and password are required', 'MISSING_CREDENTIALS');
    }

    const normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail !== SUPERADMIN_EMAIL.toLowerCase()) {
      throw ApiError.forbidden(
        'Access Denied: Only the Apna POS platform owner (chandanyaduvanshi190@gmail.com) can log into this dashboard.',
        'SUPERADMIN_UNAUTHORIZED'
      );
    }

    let user = await User.findOne({ email: normalizedEmail }).select('+passwordHash');
    if (!user) {
      // Auto seed if missing
      await this.seedSuperAdmin();
      user = await User.findOne({ email: normalizedEmail }).select('+passwordHash');
    }

    if (!user) {
      throw ApiError.unauthorized('Owner account initialization failed. Please try again.', 'USER_NOT_FOUND');
    }

    const isValid = await user.comparePassword(password);
    if (!isValid) {
      throw ApiError.unauthorized('Incorrect owner password. Please enter Admin@12.', 'INVALID_CREDENTIALS');
    }

    const tokens = await tokenService.generateAuthTokens(user);
    const business = await Business.findOne({ ownerId: user._id }).lean();

    return {
      user: {
        id: user._id,
        email: user.email,
        phone: user.phone || '',
        name: business?.profile?.name || 'Owner',
        companyName: business?.profile?.companyName || 'Apna POS Master HQ',
        role: 'superadmin',
        isSuperAdmin: true,
        status: user.status || 'active',
        subscription: user.subscription || { plan: 'enterprise', status: 'active' },
      },
      ...tokens,
    };
  }

  /**
   * Comprehensive Platform Overview Statistics
   */
  async getPlatformStats() {
    const [
      totalUsers,
      activeUsers,
      inactiveUsers,
      suspendedUsers,
      totalBusinesses,
      totalOrders,
      totalProducts,
      totalTables,
      totalStaff,
      totalCustomers,
      totalLeads,
      salesAggregate,
      subscriptionBreakdown,
      recentUsers,
      recentOrders,
    ] = await Promise.all([
      User.countDocuments({}),
      User.countDocuments({ status: { $in: ['active', null] } }),
      User.countDocuments({ status: 'inactive' }),
      User.countDocuments({ status: 'suspended' }),
      Business.countDocuments({}),
      Order.countDocuments({}),
      Product.countDocuments({}),
      Table.countDocuments({}),
      Staff.countDocuments({}),
      Customer.countDocuments({}),
      SubscriptionLead.countDocuments({}),
      Order.aggregate([
        { $match: { orderStatus: { $ne: 'cancelled' } } },
        {
          $group: {
            _id: null,
            totalRevenue: { $sum: '$grandTotal' },
            avgOrderValue: { $avg: '$grandTotal' },
          },
        },
      ]),
      User.aggregate([
        {
          $group: {
            _id: { $ifNull: ['$subscription.plan', 'starter'] },
            count: { $sum: 1 },
          },
        },
      ]),
      User.find({})
        .sort({ createdAt: -1 })
        .limit(8)
        .lean(),
      Order.find({})
        .sort({ createdAt: -1 })
        .limit(8)
        .lean(),
    ]);

    // Attach business profiles to recent users
    const recentUsersWithDetails = await Promise.all(
      recentUsers.map(async (u) => {
        const biz = await Business.findOne({ ownerId: u._id }).select('profile business').lean();
        const orderCount = await Order.countDocuments({ businessId: biz?._id });
        return {
          id: u._id,
          email: u.email,
          phone: u.phone,
          status: u.status || 'active',
          role: u.role,
          subscription: u.subscription || { plan: 'starter', status: 'active' },
          companyName: biz?.profile?.companyName || 'Not Set',
          businessType: biz?.business?.businessType || 'Restaurant',
          orderCount,
          createdAt: u.createdAt,
        };
      })
    );

    // Monthly registrations growth (last 6 months)
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 5);
    sixMonthsAgo.setDate(1);

    const monthlyGrowth = await User.aggregate([
      { $match: { createdAt: { $gte: sixMonthsAgo } } },
      {
        $group: {
          _id: {
            year: { $year: '$createdAt' },
            month: { $month: '$createdAt' },
          },
          count: { $sum: 1 },
        },
      },
      { $sort: { '_id.year': 1, '_id.month': 1 } },
    ]);

    // Format subscription map
    const plansCount = {
      starter: 0,
      growth: 0,
      pro: 0,
      enterprise: 0,
      custom: 0,
    };
    (subscriptionBreakdown || []).forEach((item) => {
      const key = (item._id || 'starter').toLowerCase();
      plansCount[key] = (plansCount[key] || 0) + item.count;
    });

    const totalRev = salesAggregate[0]?.totalRevenue || 0;
    const avgOrder = salesAggregate[0]?.avgOrderValue || 0;

    return {
      totals: {
        users: totalUsers,
        activeUsers,
        inactiveUsers,
        suspendedUsers,
        businesses: totalBusinesses,
        orders: totalOrders,
        revenue: Math.round(totalRev * 100) / 100,
        avgOrderValue: Math.round(avgOrder * 100) / 100,
        products: totalProducts,
        tables: totalTables,
        staff: totalStaff,
        customers: totalCustomers,
        leads: totalLeads,
      },
      plansBreakdown: plansCount,
      monthlyGrowth,
      recentUsers: recentUsersWithDetails,
      recentOrders,
    };
  }

  /**
   * Get Paginated and Filtered User List with Full Business Info & Store Stats
   */
  async getUsers({ search = '', status = 'all', plan = 'all', role = 'all', page = 1, limit = 20 }) {
    const p = Math.max(1, parseInt(page, 10) || 1);
    const l = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (p - 1) * l;

    const query = {};

    if (status && status !== 'all') {
      if (status === 'active') {
        query.status = { $in: ['active', null] };
      } else {
        query.status = status;
      }
    }

    if (plan && plan !== 'all') {
      query['subscription.plan'] = plan;
    }

    if (role && role !== 'all') {
      query.role = role;
    }

    let userIdsFromBusiness = [];
    if (search && search.trim().length > 0) {
      const term = search.trim();
      const regex = new RegExp(term, 'i');

      // Find businesses matching name / companyName / phone
      const matchingBusinesses = await Business.find({
        $or: [
          { 'profile.name': regex },
          { 'profile.companyName': regex },
          { 'profile.phone': regex },
          { 'address.city': regex },
        ],
      }).select('ownerId');

      userIdsFromBusiness = matchingBusinesses.map((b) => b.ownerId);

      query.$or = [
        { email: regex },
        { phone: regex },
        { _id: { $in: userIdsFromBusiness } },
      ];
    }

    const [total, users] = await Promise.all([
      User.countDocuments(query),
      User.find(query)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(l)
        .lean(),
    ]);

    // Enhance each user with their Business profile, order counts, product counts, staff counts, table counts
    const populatedUsers = await Promise.all(
      users.map(async (u) => {
        let business = null;
        if (u.businessId) {
          business = await Business.findById(u.businessId).lean();
        }
        if (!business) {
          business = await Business.findOne({ ownerId: u._id }).lean();
        }

        const bizId = business?._id;
        const [ordersCount, productsCount, tablesCount, staffCount, salesSum] = await Promise.all([
          bizId ? Order.countDocuments({ businessId: bizId }) : 0,
          bizId ? Product.countDocuments({ businessId: bizId }) : 0,
          bizId ? Table.countDocuments({ businessId: bizId }) : 0,
          bizId ? Staff.countDocuments({ businessId: bizId }) : 0,
          bizId
            ? Order.aggregate([
                { $match: { businessId: bizId, orderStatus: { $ne: 'cancelled' } } },
                { $group: { _id: null, total: { $sum: '$grandTotal' } } },
              ])
            : [],
        ]);

        const totalSales = salesSum[0]?.total || 0;

        return {
          id: u._id,
          email: u.email,
          phone: u.phone || business?.profile?.phone || '',
          role: u.role || 'owner',
          status: u.status || 'active',
          isSuperAdmin: !!u.isSuperAdmin,
          emailVerified: !!u.emailVerified,
          onboardingCompleted: !!u.onboardingCompleted,
          createdAt: u.createdAt,
          updatedAt: u.updatedAt,
          subscription: u.subscription || {
            plan: 'starter',
            status: 'active',
            startDate: u.createdAt,
            expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
            billingCycle: 'annual',
            maxTables: 50,
            maxStaff: 20,
          },
          business: business
            ? {
                id: business._id,
                name: business.profile?.name || '',
                companyName: business.profile?.companyName || '',
                phone: business.profile?.phone || '',
                website: business.profile?.website || '',
                businessType: business.business?.businessType || 'Restaurant',
                currency: business.business?.currency || 'INR',
                city: business.address?.city || '',
                state: business.address?.state || '',
                addressLine: business.address?.addressLine || '',
                profileImage: business.profile?.profileImage || '',
              }
            : null,
          metrics: {
            ordersCount,
            productsCount,
            tablesCount,
            staffCount,
            totalSales: Math.round(totalSales * 100) / 100,
          },
        };
      })
    );

    return {
      users: populatedUsers,
      pagination: {
        total,
        page: p,
        limit: l,
        pages: Math.ceil(total / l) || 1,
      },
    };
  }

  /**
   * Create New User and Store from Admin Web Dashboard
   */
  async createUser(data) {
    const {
      email,
      password,
      phone,
      name,
      companyName,
      businessType,
      role = 'owner',
      status = 'active',
      plan = 'starter',
      subscriptionStatus = 'active',
      expiresInDays = 365,
      billingCycle = 'annual',
      maxTables = 50,
      maxStaff = 20,
      city = '',
      state = '',
      notes = '',
    } = data;

    if (!email || !password) {
      throw ApiError.badRequest('Email and password are required', 'MISSING_FIELDS');
    }

    const normalizedEmail = email.trim().toLowerCase();
    const existing = await User.findOne({ email: normalizedEmail });
    if (existing) {
      throw ApiError.conflict('A user with this email address already exists', 'EMAIL_EXISTS');
    }

    const passwordHash = await User.hashPassword(password);
    const expiresAt = new Date(Date.now() + Number(expiresInDays || 365) * 24 * 60 * 60 * 1000);

    const user = new User({
      email: normalizedEmail,
      phone: phone ? phone.trim() : undefined,
      passwordHash,
      role: role.toLowerCase(),
      status: status || 'active',
      emailVerified: true,
      onboardingCompleted: true,
      onboardingStep: 4,
      subscription: {
        plan: plan.toLowerCase(),
        status: subscriptionStatus.toLowerCase(),
        startDate: new Date(),
        expiresAt,
        billingCycle,
        maxTables: Number(maxTables) || 50,
        maxStaff: Number(maxStaff) || 20,
        notes,
      },
    });

    await user.save();

    const business = new Business({
      ownerId: user._id,
      profile: {
        name: name ? name.trim() : normalizedEmail.split('@')[0],
        companyName: companyName ? companyName.trim() : 'My Store',
        phone: phone ? phone.trim() : '',
      },
      business: {
        businessType: businessType || 'Restaurant',
        currency: 'INR',
        country: 'IN',
      },
      address: {
        city: city ? city.trim() : '',
        state: state ? state.trim() : '',
      },
    });

    await business.save();

    user.businessId = business._id;
    await user.save();

    return {
      user: {
        id: user._id,
        email: user.email,
        phone: user.phone,
        role: user.role,
        status: user.status,
        subscription: user.subscription,
      },
      business: {
        id: business._id,
        name: business.profile.name,
        companyName: business.profile.companyName,
      },
    };
  }

  /**
   * Get Detailed Information for a Single User & Store
   */
  async getUserById(userId) {
    const user = await User.findById(userId).lean();
    if (!user) {
      throw ApiError.notFound('User not found', 'USER_NOT_FOUND');
    }

    let business = null;
    if (user.businessId) {
      business = await Business.findById(user.businessId).lean();
    }
    if (!business) {
      business = await Business.findOne({ ownerId: user._id }).lean();
    }

    const bizId = business?._id;

    const [orders, products, tables, staff, customers] = await Promise.all([
      bizId ? Order.find({ businessId: bizId }).sort({ createdAt: -1 }).limit(10).lean() : [],
      bizId ? Product.find({ businessId: bizId }).sort({ createdAt: -1 }).limit(10).lean() : [],
      bizId ? Table.find({ businessId: bizId }).lean() : [],
      bizId ? Staff.find({ businessId: bizId }).lean() : [],
      bizId ? Customer.find({ businessId: bizId }).sort({ createdAt: -1 }).limit(10).lean() : [],
    ]);

    const salesAggregate = bizId
      ? await Order.aggregate([
          { $match: { businessId: bizId, orderStatus: { $ne: 'cancelled' } } },
          {
            $group: {
              _id: null,
              totalRevenue: { $sum: '$grandTotal' },
              orderCount: { $sum: 1 },
            },
          },
        ])
      : [];

    return {
      user: {
        id: user._id,
        email: user.email,
        phone: user.phone,
        role: user.role,
        status: user.status || 'active',
        isSuperAdmin: !!user.isSuperAdmin,
        emailVerified: user.emailVerified,
        onboardingCompleted: user.onboardingCompleted,
        onboardingStep: user.onboardingStep,
        subscription: user.subscription || { plan: 'starter', status: 'active' },
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      business,
      stats: {
        totalRevenue: Math.round((salesAggregate[0]?.totalRevenue || 0) * 100) / 100,
        totalOrders: salesAggregate[0]?.orderCount || 0,
        totalProducts: products.length,
        totalTables: tables.length,
        totalStaff: staff.length,
        totalCustomers: customers.length,
      },
      recentOrders: orders,
      recentProducts: products,
      tables,
      staff,
    };
  }

  /**
   * Update User & Business Profile
   */
  async updateUser(userId, data) {
    const user = await User.findById(userId);
    if (!user) {
      throw ApiError.notFound('User not found', 'USER_NOT_FOUND');
    }

    // Prevent changing master superadmin email away from designated
    if (user.email.toLowerCase() === SUPERADMIN_EMAIL.toLowerCase() && data.email && data.email.toLowerCase() !== SUPERADMIN_EMAIL.toLowerCase()) {
      throw ApiError.forbidden('The master owner email cannot be changed.', 'PROTECTED_USER');
    }

    if (data.email && data.email.trim().toLowerCase() !== user.email) {
      const emailExists = await User.findOne({
        email: data.email.trim().toLowerCase(),
        _id: { $ne: user._id },
      });
      if (emailExists) {
        throw ApiError.conflict('Email is already taken by another account', 'EMAIL_EXISTS');
      }
      user.email = data.email.trim().toLowerCase();
    }

    if (data.phone !== undefined) user.phone = data.phone.trim();
    if (data.role) user.role = data.role.toLowerCase();
    if (data.status) user.status = data.status;

    if (data.password && data.password.trim().length >= 6) {
      user.passwordHash = await User.hashPassword(data.password.trim());
    }

    await user.save();

    // Update Business if provided
    let business = await Business.findOne({ ownerId: user._id });
    if (!business && user.businessId) {
      business = await Business.findById(user.businessId);
    }

    if (business) {
      if (data.name !== undefined) business.profile.name = data.name.trim();
      if (data.companyName !== undefined) business.profile.companyName = data.companyName.trim();
      if (data.phone !== undefined) business.profile.phone = data.phone.trim();
      if (data.website !== undefined) business.profile.website = data.website.trim();
      if (data.businessType !== undefined) business.business.businessType = data.businessType.trim();
      if (data.city !== undefined) business.address.city = data.city.trim();
      if (data.state !== undefined) business.address.state = data.state.trim();
      if (data.addressLine !== undefined) business.address.addressLine = data.addressLine.trim();
      await business.save();
    }

    return {
      user,
      business,
    };
  }

  /**
   * Update Status (Active / Inactive / Suspended)
   */
  async updateUserStatus(userId, status) {
    const validStatuses = ['active', 'inactive', 'suspended'];
    if (!validStatuses.includes(status)) {
      throw ApiError.badRequest(`Status must be one of: ${validStatuses.join(', ')}`, 'INVALID_STATUS');
    }

    const user = await User.findById(userId);
    if (!user) {
      throw ApiError.notFound('User not found', 'USER_NOT_FOUND');
    }

    if (user.email.toLowerCase() === SUPERADMIN_EMAIL.toLowerCase()) {
      throw ApiError.forbidden('The master owner account status cannot be deactivated or suspended.', 'PROTECTED_USER');
    }

    user.status = status;
    await user.save();

    return {
      id: user._id,
      email: user.email,
      status: user.status,
    };
  }

  /**
   * Update Subscription Plan, Expiry & Limits
   */
  async updateUserSubscription(userId, subData) {
    const user = await User.findById(userId);
    if (!user) {
      throw ApiError.notFound('User not found', 'USER_NOT_FOUND');
    }

    user.subscription = user.subscription || {};

    if (subData.plan) user.subscription.plan = subData.plan.toLowerCase();
    if (subData.status) user.subscription.status = subData.status.toLowerCase();
    if (subData.billingCycle) user.subscription.billingCycle = subData.billingCycle.toLowerCase();
    if (subData.maxTables !== undefined) user.subscription.maxTables = Number(subData.maxTables);
    if (subData.maxStaff !== undefined) user.subscription.maxStaff = Number(subData.maxStaff);
    if (subData.notes !== undefined) user.subscription.notes = subData.notes;

    if (subData.expiresAt) {
      user.subscription.expiresAt = new Date(subData.expiresAt);
    } else if (subData.extendDays) {
      const currentExpiry = user.subscription.expiresAt && user.subscription.expiresAt > new Date()
        ? new Date(user.subscription.expiresAt)
        : new Date();
      currentExpiry.setDate(currentExpiry.getDate() + Number(subData.extendDays));
      user.subscription.expiresAt = currentExpiry;
    }

    await user.save();

    return {
      id: user._id,
      email: user.email,
      subscription: user.subscription,
    };
  }

  /**
   * Reset Password for a User
   */
  async resetUserPassword(userId, newPassword) {
    if (!newPassword || newPassword.trim().length < 6) {
      throw ApiError.badRequest('Password must be at least 6 characters long', 'INVALID_PASSWORD');
    }

    const user = await User.findById(userId);
    if (!user) {
      throw ApiError.notFound('User not found', 'USER_NOT_FOUND');
    }

    user.passwordHash = await User.hashPassword(newPassword.trim());
    await user.save();

    return {
      success: true,
      message: `Password successfully updated for user ${user.email}`,
    };
  }

  /**
   * Delete User and All Associated Store Data
   */
  async deleteUser(userId) {
    const user = await User.findById(userId);
    if (!user) {
      throw ApiError.notFound('User not found', 'USER_NOT_FOUND');
    }

    if (user.email.toLowerCase() === SUPERADMIN_EMAIL.toLowerCase()) {
      throw ApiError.forbidden('The master owner account cannot be deleted.', 'PROTECTED_USER');
    }

    // Find business
    let business = null;
    if (user.businessId) {
      business = await Business.findById(user.businessId);
    }
    if (!business) {
      business = await Business.findOne({ ownerId: user._id });
    }

    const bizId = business?._id;

    // Delete associated resources if business exists
    if (bizId) {
      await Promise.all([
        Order.deleteMany({ businessId: bizId }),
        Product.deleteMany({ businessId: bizId }),
        Category.deleteMany({ businessId: bizId }),
        Table.deleteMany({ businessId: bizId }),
        Staff.deleteMany({ businessId: bizId }),
        Customer.deleteMany({ businessId: bizId }),
        Sale.deleteMany({ businessId: bizId }),
        Notification.deleteMany({ businessId: bizId }),
        Cart.deleteMany({ businessId: bizId }),
        PrintLog.deleteMany({ businessId: bizId }),
        Extra.deleteMany({ businessId: bizId }),
        Business.findByIdAndDelete(bizId),
      ]);
    }

    await User.findByIdAndDelete(user._id);

    return {
      success: true,
      message: `User ${user.email} and all associated store data deleted successfully.`,
    };
  }

  /**
   * Database Collections Overview
   */
  async getDatabaseOverview() {
    const collections = [
      { name: 'Users', model: User, icon: 'users', desc: 'Registered store owners & staff logins' },
      { name: 'Businesses', model: Business, icon: 'store', desc: 'Restaurant & business outlet profiles' },
      { name: 'Orders', model: Order, icon: 'receipt', desc: 'POS orders, dine-in & takeaway receipts' },
      { name: 'Products', model: Product, icon: 'utensils', desc: 'Menu items, pricing, variants, add-ons' },
      { name: 'Categories', model: Category, icon: 'tags', desc: 'Menu categories and item groups' },
      { name: 'Tables', model: Table, icon: 'chair', desc: 'Dine-in tables and sections' },
      { name: 'Customers', model: Customer, icon: 'user-friends', desc: 'Customer CRM directory and visit logs' },
      { name: 'Staff', model: Staff, icon: 'id-badge', desc: 'Cashiers, managers, waiters, kitchen staff' },
      { name: 'Sales', model: Sale, icon: 'chart-line', desc: 'Daily settlement and ledger records' },
      { name: 'SubscriptionLeads', model: SubscriptionLead, icon: 'envelope-open-text', desc: 'Lead requests submitted via app' },
      { name: 'Notifications', model: Notification, icon: 'bell', desc: 'System and store notifications' },
      { name: 'PrintLogs', model: PrintLog, icon: 'print', desc: 'Thermal KOT & receipt print logs' },
      { name: 'ChotuActionLogs', model: ChotuActionLog, icon: 'robot', desc: 'AI Voice assistant command logs' },
    ];

    const stats = await Promise.all(
      collections.map(async (c) => {
        try {
          const count = await c.model.countDocuments({});
          const lastDoc = await c.model.findOne().sort({ createdAt: -1 }).select('createdAt').lean();
          return {
            name: c.name,
            icon: c.icon,
            desc: c.desc,
            count,
            lastActivity: lastDoc?.createdAt || null,
          };
        } catch (e) {
          return {
            name: c.name,
            icon: c.icon,
            desc: c.desc,
            count: 0,
            lastActivity: null,
          };
        }
      })
    );

    return {
      databaseName: mongoose.connection.name || 'apna_pos',
      connectionState: mongoose.connection.readyState === 1 ? 'Connected (Ready)' : 'Disconnected',
      host: mongoose.connection.host || 'MongoDB Cluster',
      collections: stats,
    };
  }

  /**
   * Fetch Paginated Documents from a specific collection for Admin inspection
   */
  async getCollectionDocuments(collectionName, { page = 1, limit = 20, search = '' }) {
    const map = {
      users: User,
      businesses: Business,
      orders: Order,
      products: Product,
      categories: Category,
      tables: Table,
      customers: Customer,
      staff: Staff,
      sales: Sale,
      subscriptionleads: SubscriptionLead,
      notifications: Notification,
      printlogs: PrintLog,
      chotuactionlogs: ChotuActionLog,
    };

    const key = (collectionName || '').toLowerCase().trim();
    const Model = map[key];

    if (!Model) {
      throw ApiError.badRequest(`Unknown collection: ${collectionName}`, 'INVALID_COLLECTION');
    }

    const p = Math.max(1, parseInt(page, 10) || 1);
    const l = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (p - 1) * l;

    const [total, docs] = await Promise.all([
      Model.countDocuments({}),
      Model.find({})
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(l)
        .lean(),
    ]);

    return {
      collection: collectionName,
      total,
      page: p,
      limit: l,
      pages: Math.ceil(total / l) || 1,
      documents: docs,
    };
  }

  /**
   * Get Subscription Leads
   */
  async getLeads({ status = 'all', page = 1, limit = 20, search = '' }) {
    const p = Math.max(1, parseInt(page, 10) || 1);
    const l = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (p - 1) * l;

    const query = {};
    if (status && status !== 'all') {
      query.status = status;
    }

    if (search && search.trim()) {
      const regex = new RegExp(search.trim(), 'i');
      query.$or = [
        { restaurantName: regex },
        { contactPerson: regex },
        { phone: regex },
        { email: regex },
        { selectedPlan: regex },
      ];
    }

    const [total, leads] = await Promise.all([
      SubscriptionLead.countDocuments(query),
      SubscriptionLead.find(query)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(l)
        .lean(),
    ]);

    return {
      leads,
      pagination: {
        total,
        page: p,
        limit: l,
        pages: Math.ceil(total / l) || 1,
      },
    };
  }

  /**
   * Update Lead Status
   */
  async updateLead(leadId, { status, notes }) {
    const lead = await SubscriptionLead.findById(leadId);
    if (!lead) {
      throw ApiError.notFound('Subscription lead not found', 'LEAD_NOT_FOUND');
    }

    if (status) lead.status = status;
    if (notes !== undefined) lead.notes = notes;

    await lead.save();

    return lead;
  }

  /**
   * Delete Lead
   */
  async deleteLead(leadId) {
    const lead = await SubscriptionLead.findByIdAndDelete(leadId);
    if (!lead) {
      throw ApiError.notFound('Subscription lead not found', 'LEAD_NOT_FOUND');
    }
    return { success: true, message: 'Lead deleted successfully' };
  }

  /**
   * Get Authoritative Sales Report for a specific user / business with Staff Segregation
   */
  async getUserSalesReport(userId, query = {}) {
    const user = await User.findById(userId).lean();
    if (!user) {
      throw ApiError.notFound('User not found', 'USER_NOT_FOUND');
    }

    let business = null;
    if (user.businessId) {
      business = await Business.findById(user.businessId).lean();
    }
    if (!business) {
      business = await Business.findOne({ ownerId: user._id }).lean();
    }

    const bizId = business?._id;
    if (!bizId) {
      return {
        user: { id: user._id, email: user.email, name: 'No Store' },
        summary: { totalRevenue: 0, grossSales: 0, totalOrders: 0, avgOrderValue: 0 },
        staffWise: [],
        paymentModes: [],
        topProducts: [],
        orders: [],
      };
    }

    const salesService = require('./salesService');
    const reportData = await salesService.getSalesReport(bizId, query);

    // Fetch registered staff directory for this store
    const storeStaff = await Staff.find({ businessId: bizId }).lean();
    const existingStaffMap = new Map();
    (reportData.staffWise || []).forEach((s) => {
      existingStaffMap.set((s.staffName || '').toLowerCase().trim(), s);
    });

    const enrichedStaffWise = [...(reportData.staffWise || [])];
    for (const staffMember of storeStaff) {
      const sKey = (staffMember.name || '').toLowerCase().trim();
      if (!existingStaffMap.has(sKey)) {
        enrichedStaffWise.push({
          staffId: staffMember._id.toString(),
          staffName: staffMember.name || 'Staff Member',
          role: staffMember.role || 'Staff',
          billsCount: 0,
          totalRevenue: 0.0,
          percentage: 0.0,
          avgTicket: 0.0,
          orders: [],
        });
      }
    }

    return {
      user: {
        id: user._id,
        email: user.email,
        phone: user.phone || business.profile?.phone || '',
        name: business.profile?.name || user.email.split('@')[0],
        companyName: business.profile?.companyName || 'Store Outlet',
        businessType: business.business?.businessType || 'Restaurant',
      },
      business: {
        id: business._id,
        name: business.profile?.name || '',
        companyName: business.profile?.companyName || '',
        city: business.address?.city || '',
      },
      summary: reportData.summary,
      staffWise: enrichedStaffWise,
      paymentModes: reportData.paymentModes,
      salesByOrderType: reportData.salesByOrderType,
      topProducts: reportData.topProducts,
      salesTrend: reportData.salesTrend,
      orders: reportData.orders,
      period: reportData.period,
      startDate: reportData.startDate,
      endDate: reportData.endDate,
    };
  }

  /**
   * Super Admin Order Purge: deletes an order globally or for a specific user store
   */
  async deleteOrder(orderIdOrNumber, targetUserId) {
    let businessId = null;
    if (targetUserId) {
      const user = await User.findById(targetUserId);
      if (user) {
        const business = await Business.findOne({ ownerId: user._id });
        if (business) businessId = business._id;
      }
    }

    const orderService = require('./orderService');
    return await orderService.deleteOrder(businessId, orderIdOrNumber);
  }
}

module.exports = new SuperadminService();
