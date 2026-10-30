const mongoose = require('mongoose');
const Coupon = require('../models/Coupon');
const CouponRedemption = require('../models/CouponRedemption');
const Campaign = require('../models/Campaign');
const Order = require('../models/Order');
const ApiError = require('../utils/ApiError');

class CouponService {
  /**
   * Create a new coupon with strict business-level validations
   */
  async createCoupon(businessId, data) {
    const code = (data.code || '').trim().toUpperCase();
    if (!code) {
      throw ApiError.badRequest('Coupon code is required');
    }

    const existing = await Coupon.findOne({ businessId, code });
    if (existing) {
      throw ApiError.badRequest(`Coupon with code "${code}" already exists for this business`);
    }

    const discountType = data.discountType === 'flat' ? 'flat' : 'percentage';
    const discountValue = Number(data.discountValue) || 0;
    if (discountValue <= 0) {
      throw ApiError.badRequest('Discount value must be greater than zero');
    }

    if (discountType === 'percentage' && discountValue > 100) {
      throw ApiError.badRequest('Percentage discount cannot exceed 100%');
    }

    const minCartAmount = Math.max(0, Number(data.minCartAmount) || 0);
    const maxDiscountAmount = data.maxDiscountAmount != null ? Math.max(0, Number(data.maxDiscountAmount)) : null;

    let startDate = data.startDate ? new Date(data.startDate) : new Date();
    if (isNaN(startDate.getTime())) startDate = new Date();

    let endDate = null;
    if (data.endDate) {
      endDate = new Date(data.endDate);
      if (isNaN(endDate.getTime())) endDate = null;
    }

    if (endDate && endDate < startDate) {
      throw ApiError.badRequest('End date must be greater than or equal to start date');
    }

    const coupon = await Coupon.create({
      businessId,
      code,
      title: (data.title || code).trim(),
      description: (data.description || '').trim(),
      discountType,
      discountValue,
      maxDiscountAmount,
      minCartAmount,
      startDate,
      endDate,
      isActive: data.isActive !== undefined ? Boolean(data.isActive) : true,
      orderTypes: Array.isArray(data.orderTypes) && data.orderTypes.length > 0 ? data.orderTypes : ['dineIn', 'takeaway', 'delivery'],
      applicableCategories: Array.isArray(data.applicableCategories) ? data.applicableCategories : [],
      applicableProducts: Array.isArray(data.applicableProducts) ? data.applicableProducts : [],
      excludedProducts: Array.isArray(data.excludedProducts) ? data.excludedProducts : [],
      customerEligibility: ['all', 'new', 'repeat', 'min_orders'].includes(data.customerEligibility) ? data.customerEligibility : 'all',
      customerMinOrders: Math.max(0, Number(data.customerMinOrders) || 0),
      usageLimitPerCustomer: data.usageLimitPerCustomer != null ? Math.max(0, Number(data.usageLimitPerCustomer)) : 1,
      totalUsageLimit: data.totalUsageLimit != null ? Math.max(0, Number(data.totalUsageLimit)) : 0,
      validDays: Array.isArray(data.validDays) && data.validDays.length > 0 ? data.validDays : [0, 1, 2, 3, 4, 5, 6],
      timeSlots: Array.isArray(data.timeSlots) ? data.timeSlots : [],
      termsAndConditions: Array.isArray(data.termsAndConditions) ? data.termsAndConditions : [],
    });

    return coupon;
  }

  /**
   * Fetch all coupons for the business with filtering and pagination
   */
  async getCoupons(businessId, query = {}) {
    const { page = 1, limit = 50, search, status } = query;
    const andConditions = [{ businessId }];

    if (search && search.trim()) {
      const regex = new RegExp(search.trim(), 'i');
      andConditions.push({
        $or: [{ code: regex }, { title: regex }, { description: regex }],
      });
    }

    const now = new Date();
    if (status === 'active') {
      andConditions.push({
        isActive: true,
        startDate: { $lte: now },
        $or: [{ endDate: null }, { endDate: { $gte: now } }],
      });
    } else if (status === 'inactive') {
      andConditions.push({ isActive: false });
    } else if (status === 'expired') {
      andConditions.push({ endDate: { $lt: now } });
    }

    const filter = andConditions.length === 1 ? andConditions[0] : { $and: andConditions };

    const parsedLimit = Math.max(1, parseInt(limit, 10));
    const parsedPage = Math.max(1, parseInt(page, 10));
    const skip = (parsedPage - 1) * parsedLimit;

    const [coupons, total] = await Promise.all([
      Coupon.find(filter).sort({ createdAt: -1 }).skip(skip).limit(parsedLimit).lean(),
      Coupon.countDocuments(filter),
    ]);

    // Format id and attach live expiration status flag
    const formatted = coupons.map((c) => {
      c.id = c._id.toString();
      const isExpired = c.endDate ? new Date(c.endDate) < now : false;
      c.isExpired = isExpired;
      c.effectiveStatus = !c.isActive ? 'Inactive' : isExpired ? 'Expired' : 'Active';
      return c;
    });

    return {
      coupons: formatted,
      pagination: {
        total,
        page: parsedPage,
        limit: parsedLimit,
        totalPages: Math.ceil(total / parsedLimit),
      },
    };
  }

  /**
   * Get single coupon by ID
   */
  async getCouponById(businessId, id) {
    const coupon = await Coupon.findOne({ _id: id, businessId }).lean();
    if (!coupon) {
      throw ApiError.notFound('Coupon not found');
    }
    coupon.id = coupon._id.toString();
    const now = new Date();
    coupon.isExpired = coupon.endDate ? new Date(coupon.endDate) < now : false;
    coupon.effectiveStatus = !coupon.isActive ? 'Inactive' : coupon.isExpired ? 'Expired' : 'Active';
    return coupon;
  }

  /**
   * Update coupon
   */
  async updateCoupon(businessId, id, data) {
    const coupon = await Coupon.findOne({ _id: id, businessId });
    if (!coupon) {
      throw ApiError.notFound('Coupon not found');
    }

    if (data.code && data.code.trim().toUpperCase() !== coupon.code) {
      const newCode = data.code.trim().toUpperCase();
      const existing = await Coupon.findOne({ businessId, code: newCode, _id: { $ne: id } });
      if (existing) {
        throw ApiError.badRequest(`Coupon code "${newCode}" is already taken`);
      }
      coupon.code = newCode;
    }

    if (data.title !== undefined) coupon.title = data.title.trim();
    if (data.description !== undefined) coupon.description = data.description.trim();
    if (data.discountType !== undefined) coupon.discountType = data.discountType === 'flat' ? 'flat' : 'percentage';
    if (data.discountValue !== undefined) {
      const dv = Number(data.discountValue) || 0;
      if (dv <= 0) throw ApiError.badRequest('Discount value must be greater than zero');
      if (coupon.discountType === 'percentage' && dv > 100) {
        throw ApiError.badRequest('Percentage discount cannot exceed 100%');
      }
      coupon.discountValue = dv;
    }

    if (data.maxDiscountAmount !== undefined) {
      coupon.maxDiscountAmount = data.maxDiscountAmount != null ? Math.max(0, Number(data.maxDiscountAmount)) : null;
    }
    if (data.minCartAmount !== undefined) {
      coupon.minCartAmount = Math.max(0, Number(data.minCartAmount) || 0);
    }
    if (data.startDate !== undefined) {
      coupon.startDate = data.startDate ? new Date(data.startDate) : coupon.startDate;
    }
    if (data.endDate !== undefined) {
      coupon.endDate = data.endDate ? new Date(data.endDate) : null;
    }
    if (coupon.endDate && coupon.endDate < coupon.startDate) {
      throw ApiError.badRequest('End date must be greater than or equal to start date');
    }

    if (data.isActive !== undefined) coupon.isActive = Boolean(data.isActive);
    if (Array.isArray(data.orderTypes)) coupon.orderTypes = data.orderTypes;
    if (Array.isArray(data.applicableCategories)) coupon.applicableCategories = data.applicableCategories;
    if (Array.isArray(data.applicableProducts)) coupon.applicableProducts = data.applicableProducts;
    if (Array.isArray(data.excludedProducts)) coupon.excludedProducts = data.excludedProducts;
    if (data.customerEligibility !== undefined) coupon.customerEligibility = data.customerEligibility;
    if (data.customerMinOrders !== undefined) coupon.customerMinOrders = Math.max(0, Number(data.customerMinOrders) || 0);
    if (data.usageLimitPerCustomer !== undefined) coupon.usageLimitPerCustomer = Math.max(0, Number(data.usageLimitPerCustomer) || 0);
    if (data.totalUsageLimit !== undefined) coupon.totalUsageLimit = Math.max(0, Number(data.totalUsageLimit) || 0);
    if (Array.isArray(data.validDays)) coupon.validDays = data.validDays;
    if (Array.isArray(data.timeSlots)) coupon.timeSlots = data.timeSlots;
    if (Array.isArray(data.termsAndConditions)) coupon.termsAndConditions = data.termsAndConditions;

    await coupon.save();
    return coupon;
  }

  /**
   * Toggle coupon activation
   */
  async toggleCouponStatus(businessId, id) {
    const coupon = await Coupon.findOne({ _id: id, businessId });
    if (!coupon) {
      throw ApiError.notFound('Coupon not found');
    }
    coupon.isActive = !coupon.isActive;
    await coupon.save();
    return coupon;
  }

  /**
   * Delete coupon
   */
  async deleteCoupon(businessId, id) {
    const coupon = await Coupon.findOneAndDelete({ _id: id, businessId });
    if (!coupon) {
      throw ApiError.notFound('Coupon not found');
    }
    return { id, message: 'Coupon deleted successfully' };
  }

  /**
   * Comprehensive 11-step validation engine for POS / Cart / Online Ordering checkout
   */
  async validateCoupon(businessId, payload = {}) {
    const {
      code,
      cartItems = [],
      subtotal,
      cartSubtotal,
      orderType = 'dineIn',
      customerPhone,
      customerId,
    } = payload;

    if (!code || !code.trim()) {
      return { valid: false, message: 'Please enter a coupon code' };
    }

    const currentSubtotal = Math.max(0, Number(subtotal ?? cartSubtotal ?? 0));
    const cleanCode = code.trim().toUpperCase();
    const cleanPhone = (customerPhone || customerId || '').toString().trim();

    // 1. Coupon exists & 2. Belongs to current business
    const coupon = await Coupon.findOne({ businessId, code: cleanCode }).lean();
    if (!coupon) {
      return { valid: false, message: 'Coupon not found or inactive for this business.' };
    }

    if (!coupon.isActive) {
      return { valid: false, message: 'Coupon not found or inactive for this business.' };
    }

    const now = new Date();

    // 3. Campaign is active (if linked) & 4. Campaign has not expired
    if (coupon.campaignId) {
      const campaign = await Campaign.findOne({ _id: coupon.campaignId, businessId }).lean();
      if (campaign) {
        if (['paused', 'cancelled', 'failed'].includes(campaign.status)) {
          return { valid: false, message: 'This campaign is currently not active' };
        }
        if (campaign.couponSettings?.hasExpiryDate && campaign.couponSettings.expiryDate) {
          if (new Date(campaign.couponSettings.expiryDate) < now) {
            return { valid: false, message: 'This campaign coupon has expired.' };
          }
        }
      }
    }

    // 5. Coupon has not expired
    if (coupon.startDate && new Date(coupon.startDate) > now) {
      return { valid: false, message: `Coupon "${cleanCode}" is not active yet` };
    }
    if (coupon.endDate && new Date(coupon.endDate) < now) {
      return { valid: false, message: 'This campaign coupon has expired.' };
    }

    // Day of week check
    const currentDay = now.getDay(); // 0: Sun, 1: Mon, ...
    if (Array.isArray(coupon.validDays) && coupon.validDays.length > 0 && !coupon.validDays.includes(currentDay)) {
      const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      return { valid: false, message: `Coupon "${cleanCode}" is not valid on ${dayNames[currentDay]}` };
    }

    // Time slot check
    if (Array.isArray(coupon.timeSlots) && coupon.timeSlots.length > 0) {
      const currentHours = now.getHours().toString().padStart(2, '0');
      const currentMinutes = now.getMinutes().toString().padStart(2, '0');
      const currentTimeStr = `${currentHours}:${currentMinutes}`;

      const isInSlot = coupon.timeSlots.some((slot) => {
        if (!slot.startTime || !slot.endTime) return true;
        return currentTimeStr >= slot.startTime && currentTimeStr <= slot.endTime;
      });

      if (!isInSlot) {
        return { valid: false, message: `Coupon "${cleanCode}" is only valid during specified hours` };
      }
    }

    // Order type check
    const normOrderType = orderType.toLowerCase().replace(/[-_]/g, '');
    const allowedTypes = (coupon.orderTypes || ['dineIn', 'takeaway', 'delivery']).map((t) => t.toLowerCase().replace(/[-_]/g, ''));
    if (!allowedTypes.includes(normOrderType)) {
      return { valid: false, message: `Coupon "${cleanCode}" is not valid for ${orderType} orders` };
    }

    // Global usage limit check
    if (coupon.totalUsageLimit > 0 && coupon.totalTimesUsed >= coupon.totalUsageLimit) {
      return { valid: false, message: `Coupon "${cleanCode}" total usage limit has been reached` };
    }

    // 6. Customer is eligible & 7. Customer has not exceeded redemption limits
    if (cleanPhone) {
      // Check customer order history if eligibility requires it
      if (coupon.customerEligibility === 'new') {
        const orderCount = await Order.countDocuments({
          businessId,
          customerPhone: cleanPhone,
          status: 'completed',
        });
        if (orderCount > 0) {
          return { valid: false, message: `Coupon "${cleanCode}" is valid for new customers only` };
        }
      } else if (coupon.customerEligibility === 'repeat') {
        const orderCount = await Order.countDocuments({
          businessId,
          customerPhone: cleanPhone,
          status: 'completed',
        });
        if (orderCount === 0) {
          return { valid: false, message: `Coupon "${cleanCode}" is valid for repeat customers only` };
        }
      } else if (coupon.customerEligibility === 'min_orders' && coupon.customerMinOrders > 0) {
        const orderCount = await Order.countDocuments({
          businessId,
          customerPhone: cleanPhone,
          status: 'completed',
        });
        if (orderCount < coupon.customerMinOrders) {
          return {
            valid: false,
            message: `Coupon "${cleanCode}" requires at least ${coupon.customerMinOrders} past completed orders (you have ${orderCount})`,
          };
        }
      }

      // Check customer redemption limits (Only Once vs Multiple Times)
      const usedCount = await CouponRedemption.countDocuments({
        businessId,
        couponCode: cleanCode,
        customerPhone: cleanPhone,
      });

      const maxLimit = coupon.usageLimitPerCustomer != null ? coupon.usageLimitPerCustomer : 1;
      if (maxLimit === 1 && usedCount >= 1) {
        return {
          valid: false,
          message: 'You have already redeemed this campaign coupon.',
        };
      } else if (maxLimit > 1 && usedCount >= maxLimit) {
        return {
          valid: false,
          message: 'You have reached the maximum redemption limit for this coupon.',
        };
      }
    }

    // 9. Selected products exist in the cart if product-specific rewards are configured
    let eligibleSubtotal = currentSubtotal;
    const isSelectedProductsScope = coupon.rewardScope === 'chosen_products' ||
      (Array.isArray(coupon.applicableProducts) && coupon.applicableProducts.length > 0);

    if (isSelectedProductsScope || (Array.isArray(coupon.applicableCategories) && coupon.applicableCategories.length > 0) || (Array.isArray(coupon.excludedProducts) && coupon.excludedProducts.length > 0)) {
      let filteredSubtotal = 0;
      let matchedAnyItem = false;

      const hasCategoryFilter = Array.isArray(coupon.applicableCategories) && coupon.applicableCategories.length > 0;
      const hasProductFilter = isSelectedProductsScope && Array.isArray(coupon.applicableProducts) && coupon.applicableProducts.length > 0;
      const hasExcludedFilter = Array.isArray(coupon.excludedProducts) && coupon.excludedProducts.length > 0;

      for (const ci of cartItems) {
        const pId = (ci.productId || ci.id || (ci.item && (ci.item.productId || ci.item.id)) || '').toString();
        const pName = (ci.name || (ci.item && ci.item.name) || '').toString().toLowerCase();
        const pCategory = (ci.category || (ci.item && ci.item.category) || '').toString().toLowerCase();
        const itemTotal = Number(ci.totalPrice ?? (ci.price ? ci.price * (ci.quantity || 1) : 0)) || 0;

        // Excluded products check
        if (hasExcludedFilter) {
          const isExcluded = coupon.excludedProducts.some((ex) => ex.toString() === pId || pName.includes(ex.toString().toLowerCase()));
          if (isExcluded) continue;
        }

        // Category & Product inclusion
        let eligible = true;
        if (hasCategoryFilter) {
          eligible = coupon.applicableCategories.some((cat) => pCategory.includes(cat.toLowerCase()));
        }
        if (hasProductFilter) {
          const productEligible = coupon.applicableProducts.some((p) => p.toString() === pId || pName.includes(p.toString().toLowerCase()));
          eligible = hasCategoryFilter ? eligible && productEligible : productEligible;
        }

        if (eligible) {
          filteredSubtotal += itemTotal;
          matchedAnyItem = true;
        }
      }

      if (isSelectedProductsScope && !matchedAnyItem) {
        return {
          valid: false,
          message: 'This coupon applies only to selected products. Please add eligible products to your cart.',
        };
      }
      eligibleSubtotal = filteredSubtotal;
    }

    // 8. Minimum spend requirement is satisfied (evaluated on eligible cart amount!)
    if (coupon.minCartAmount > 0 && eligibleSubtotal < coupon.minCartAmount) {
      return {
        valid: false,
        message: `Add products worth ₹${Math.round(coupon.minCartAmount)} or more to redeem this coupon.`,
      };
    }

    // 10. Reward calculation is valid & 11. Maximum cashback cap is respected
    let discountAmount = 0;
    const discType = coupon.discountType || 'percentage';

    if (discType === 'flat') {
      discountAmount = Math.min(coupon.discountValue, eligibleSubtotal);
    } else if (discType === 'percentage' || discType === 'cashback') {
      const calcDiscount = (eligibleSubtotal * coupon.discountValue) / 100;
      discountAmount = (coupon.maxDiscountAmount && coupon.maxDiscountAmount > 0)
        ? Math.min(calcDiscount, coupon.maxDiscountAmount)
        : calcDiscount;
      discountAmount = Math.min(discountAmount, eligibleSubtotal);
    } else if (discType === 'free_gift') {
      discountAmount = Math.min(Number(coupon.freeGiftProductPrice || coupon.discountValue || 0), eligibleSubtotal);
    } else {
      discountAmount = Math.min(coupon.discountValue, eligibleSubtotal);
    }

    discountAmount = Math.round(discountAmount * 100) / 100;
    const finalPayable = Math.max(0, currentSubtotal - discountAmount);

    coupon.id = coupon._id ? coupon._id.toString() : coupon.id;

    return {
      valid: true,
      coupon: {
        id: coupon.id,
        code: coupon.code,
        title: coupon.title,
        description: coupon.description,
        discountType: coupon.discountType,
        discountValue: coupon.discountValue,
        maxDiscountAmount: coupon.maxDiscountAmount,
        minCartAmount: coupon.minCartAmount,
        rewardScope: coupon.rewardScope || 'whole_bill',
      },
      discountAmount,
      eligibleSubtotal,
      finalPayableAmount: Math.round(finalPayable * 100) / 100,
      message: `Coupon "${coupon.code}" applied! You save ₹${discountAmount.toFixed(2)}`,
    };
  }

  /**
   * Atomically record redemption when an order is completed/paid
   */
  async recordRedemption(businessId, { couponCode, campaignId, orderId, orderNumber, customerPhone, customerName, orderSubtotal, discountAmount, finalOrderAmount }) {
    if (!couponCode || !discountAmount || discountAmount <= 0) return null;

    const cleanCode = couponCode.trim().toUpperCase();
    const coupon = await Coupon.findOne({ businessId, code: cleanCode });
    if (!coupon) return null;

    // Create redemption log atomically
    const redemption = await CouponRedemption.create({
      businessId,
      couponId: coupon._id,
      campaignId: campaignId || coupon.campaignId || null,
      couponCode: cleanCode,
      orderId,
      orderNumber: orderNumber || '',
      customerPhone: (customerPhone || '').toString().trim(),
      customerName: customerName || '',
      orderSubtotal: Number(orderSubtotal) || 0,
      discountAmount: Number(discountAmount) || 0,
      finalOrderAmount: Number(finalOrderAmount) || 0,
      redeemedAt: new Date(),
    });

    // Increment usage counter on coupon atomically
    await Coupon.findByIdAndUpdate(coupon._id, { $inc: { totalTimesUsed: 1 } });

    return redemption;
  }

  /**
   * Coupon Redemptions Report with filtering and statistics
   */
  async getRedemptionReports(businessId, query = {}) {
    const { page = 1, limit = 50, couponCode, customerPhone, startDate, endDate } = query;
    const filter = { businessId };

    if (couponCode && couponCode.trim()) {
      filter.couponCode = couponCode.trim().toUpperCase();
    }
    if (customerPhone && customerPhone.trim()) {
      filter.customerPhone = customerPhone.trim();
    }
    if (startDate || endDate) {
      filter.redeemedAt = {};
      if (startDate) filter.redeemedAt.$gte = new Date(startDate);
      if (endDate) {
        const e = new Date(endDate);
        e.setHours(23, 59, 59, 999);
        filter.redeemedAt.$lte = e;
      }
    }

    const parsedLimit = Math.max(1, parseInt(limit, 10));
    const parsedPage = Math.max(1, parseInt(page, 10));
    const skip = (parsedPage - 1) * parsedLimit;

    const [redemptions, total, stats] = await Promise.all([
      CouponRedemption.find(filter).sort({ redeemedAt: -1 }).skip(skip).limit(parsedLimit).lean(),
      CouponRedemption.countDocuments(filter),
      CouponRedemption.aggregate([
        { $match: filter },
        {
          $group: {
            _id: null,
            totalDiscountGiven: { $sum: '$discountAmount' },
            totalOrders: { $sum: 1 },
          },
        },
      ]),
    ]);

    const formatted = redemptions.map((r) => {
      r.id = r._id.toString();
      return r;
    });

    const summary = stats[0] || { totalDiscountGiven: 0, totalOrders: 0 };

    return {
      redemptions: formatted,
      summary: {
        totalDiscountGiven: Math.round(summary.totalDiscountGiven * 100) / 100,
        totalOrders: summary.totalOrders,
      },
      pagination: {
        total,
        page: parsedPage,
        limit: parsedLimit,
        totalPages: Math.ceil(total / parsedLimit),
      },
    };
  }
}

module.exports = new CouponService();
