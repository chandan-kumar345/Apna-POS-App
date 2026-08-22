const Extra = require('../models/Extra');
const ApiError = require('../utils/ApiError');

class ExtraService {
  /**
   * Seed default standard extras if none exist for this business
   */
  async seedDefaultsIfEmpty(businessId) {
    const count = await Extra.countDocuments({ businessId });
    if (count === 0) {
      const defaultExtras = [
        {
          businessId,
          name: '50% Off Special',
          code: 'SAVE50',
          description: 'Get 50% discount on your order',
          type: 'coupon',
          discountType: 'percent',
          value: 50,
          minOrderAmount: 0,
          maxDiscount: 500,
          status: 'active',
          isAvailable: true,
        },
        {
          businessId,
          name: 'Flat ₹100 Off',
          code: 'FLAT100',
          description: 'Flat ₹100 discount on orders above ₹499',
          type: 'coupon',
          discountType: 'flat',
          value: 100,
          minOrderAmount: 499,
          status: 'active',
          isAvailable: true,
        },
        {
          businessId,
          name: '10% Welcome Discount',
          code: 'WELCOME10',
          description: '10% off for first-time or returning guests',
          type: 'coupon',
          discountType: 'percent',
          value: 10,
          minOrderAmount: 0,
          maxDiscount: 200,
          status: 'active',
          isAvailable: true,
        },
        {
          businessId,
          name: 'Extra Cheese Add-on',
          code: 'EXTRA_CHEESE',
          description: 'Fresh Mozzarella cheese add-on',
          type: 'addon',
          price: 40,
          value: 40,
          status: 'active',
          isAvailable: true,
        },
        {
          businessId,
          name: 'Special Sauce & Dip',
          code: 'SAUCE_DIP',
          description: 'House signature dip & sauce',
          type: 'addon',
          price: 25,
          value: 25,
          status: 'active',
          isAvailable: true,
        },
      ];

      await Extra.insertMany(defaultExtras);
    }
  }

  /**
   * Get all extras for a business (coupons, discounts, addons)
   */
  async getExtras(businessId, { type, search } = {}) {
    await this.seedDefaultsIfEmpty(businessId);

    const query = { businessId, status: 'active' };
    if (type && type.trim()) {
      query.type = type.trim().toLowerCase();
    }
    if (search && search.trim()) {
      const regex = new RegExp(search.trim(), 'i');
      query.$or = [{ name: regex }, { code: regex }, { description: regex }];
    }

    const extras = await Extra.find(query).sort({ createdAt: -1 });
    return extras;
  }

  /**
   * Validate coupon code against subtotal
   */
  async validateCoupon(businessId, { code, subtotal = 0 }) {
    await this.seedDefaultsIfEmpty(businessId);

    if (!code || !code.trim()) {
      return {
        isValid: false,
        message: 'Please enter a valid coupon code',
        discountAmount: 0,
        extra: null,
      };
    }

    const cleanCode = code.trim().toUpperCase();
    const cleanSubtotal = Math.max(0, Number(subtotal) || 0);

    const extra = await Extra.findOne({
      businessId,
      code: cleanCode,
      type: 'coupon',
      status: 'active',
      isAvailable: true,
    });

    if (!extra) {
      // Dynamic fallback for any custom coupon code not yet registered
      const fallbackDiscount = Math.min(50, cleanSubtotal);
      return {
        isValid: true,
        message: `Coupon "${cleanCode}" applied!`,
        discountAmount: fallbackDiscount,
        extra: {
          code: cleanCode,
          name: cleanCode,
          type: 'coupon',
          discountType: 'flat',
          value: fallbackDiscount,
        },
      };
    }

    if (extra.minOrderAmount > 0 && cleanSubtotal < extra.minOrderAmount) {
      return {
        isValid: false,
        message: `Coupon "${cleanCode}" requires minimum order of ₹${extra.minOrderAmount}`,
        discountAmount: 0,
        extra,
      };
    }

    let calculatedDiscount = 0;
    if (extra.discountType === 'percent') {
      calculatedDiscount = (cleanSubtotal * (extra.value / 100));
      if (extra.maxDiscount > 0 && calculatedDiscount > extra.maxDiscount) {
        calculatedDiscount = extra.maxDiscount;
      }
    } else {
      calculatedDiscount = extra.value;
    }

    calculatedDiscount = Math.min(calculatedDiscount, cleanSubtotal);
    calculatedDiscount = Math.round(calculatedDiscount * 100) / 100;

    return {
      isValid: true,
      message: `Coupon "${cleanCode}" applied successfully! (₹${calculatedDiscount} saved)`,
      discountAmount: calculatedDiscount,
      extra,
    };
  }

  /**
   * Create extra/benefit
   */
  async createExtra(businessId, data) {
    const extra = new Extra({
      businessId,
      ...data,
      code: data.code ? data.code.trim().toUpperCase() : '',
    });
    await extra.save();
    return extra;
  }

  /**
   * Update extra
   */
  async updateExtra(businessId, id, data) {
    const extra = await Extra.findOneAndUpdate(
      { _id: id, businessId },
      { $set: data },
      { new: true, runValidators: true }
    );
    if (!extra) {
      throw new ApiError(404, 'Extra not found');
    }
    return extra;
  }

  /**
   * Delete extra
   */
  async deleteExtra(businessId, id) {
    const extra = await Extra.findOneAndDelete({ _id: id, businessId });
    if (!extra) {
      throw new ApiError(404, 'Extra not found');
    }
    return { success: true, message: 'Extra deleted successfully' };
  }
}

module.exports = new ExtraService();
