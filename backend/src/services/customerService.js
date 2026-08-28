const Customer = require('../models/Customer');
const CustomerLoyalty = require('../models/CustomerLoyalty');
const LoyaltyProgram = require('../models/LoyaltyProgram');
const ApiError = require('../utils/ApiError');

class CustomerService {
  async getCustomers(businessId, { page = 1, limit = 50, search } = {}) {
    const query = { businessId };

    if (search && search.trim()) {
      const regex = new RegExp(search.trim(), 'i');
      query.$or = [{ name: regex }, { phone: regex }, { email: regex }];
    }

    const skip = (Math.max(1, parseInt(page, 10)) - 1) * Math.max(1, parseInt(limit, 10));
    const parsedLimit = Math.max(1, parseInt(limit, 10));

    const [customers, total] = await Promise.all([
      Customer.find(query).sort({ lastVisit: -1 }).skip(skip).limit(parsedLimit),
      Customer.countDocuments(query),
    ]);

    return {
      customers,
      pagination: {
        total,
        page: parseInt(page, 10),
        limit: parsedLimit,
        totalPages: Math.ceil(total / parsedLimit),
      },
    };
  }

  async getSuggestions(businessId, queryText = '') {
    const clean = (queryText || '').toString().trim();
    const query = { businessId };

    if (clean.length > 0) {
      const regex = new RegExp(clean, 'i');
      query.$or = [{ phone: regex }, { name: regex }];
    }

    const customers = await Customer.find(query)
      .sort({ lastVisit: -1 })
      .limit(10)
      .select('name phone email address totalOrders totalSpent lastVisit gender birthday anniversary bonusPointsAwarded');

    return customers;
  }

  async createOrUpdateCustomer(businessId, customerData) {
    const phone = (customerData.phone || '').toString().trim();
    const name = (customerData.name || '').toString().trim();
    const gender = (customerData.gender || '').toString().trim();
    const email = customerData.email ? customerData.email.trim() : '';
    const address = customerData.address || '';
    const birthday = customerData.birthday || customerData.dob || null;
    const anniversary = customerData.anniversary || null;

    let customer = await Customer.findOne({ businessId, phone });

    if (!customer) {
      customer = new Customer({
        businessId,
        phone,
        name,
        email,
        address,
        gender,
        birthday,
        anniversary,
        firstVisit: new Date(),
        lastVisit: new Date(),
      });
    } else {
      if (name) customer.name = name;
      if (email) customer.email = email;
      if (address) customer.address = address;
      if (gender) customer.gender = gender;
      if (birthday) customer.birthday = birthday;
      if (anniversary) customer.anniversary = anniversary;
      customer.lastVisit = new Date();
    }

    // Check if customer has provided all 5 details: name, phone, gender, birthday, anniversary
    const hasAllBonusDetails = Boolean(
      customer.name &&
      customer.phone &&
      customer.gender &&
      customer.birthday &&
      customer.anniversary
    );

    let bonusAwarded = false;
    let awardedAmount = 0;

    if (hasAllBonusDetails && !customer.bonusPointsAwarded) {
      try {
        const loyaltyDoc = await LoyaltyProgram.findOne({ businessId });
        const isBonusEnabled = loyaltyDoc?.visitConfig?.bonusPointsEnabled !== false;
        const bonusAmount = loyaltyDoc?.visitConfig?.bonusPointsAmount || 100;

        if (isBonusEnabled && bonusAmount > 0) {
          await CustomerLoyalty.findOneAndUpdate(
            { businessId, customerPhone: phone },
            {
              $inc: { pointsBalance: bonusAmount, totalPointsEarned: bonusAmount },
              $set: {
                customerName: customer.name,
                customerId: customer._id,
                bonusPointsAwarded: true,
                bonusAwardedAt: new Date(),
              },
              $setOnInsert: { businessId, customerPhone: phone },
            },
            { upsert: true, new: true }
          );

          customer.bonusPointsAwarded = true;
          bonusAwarded = true;
          awardedAmount = bonusAmount;
        }
      } catch (err) {
        console.error('[CustomerService] Error awarding profile bonus points:', err);
      }
    }

    await customer.save();

    const result = customer.toJSON();
    if (bonusAwarded) {
      result.bonusAwarded = {
        amount: awardedAmount,
        message: `🎉 ${awardedAmount} bonus points awarded for complete profile!`,
      };
    }

    return result;
  }

  async getCustomerByPhone(businessId, phone) {
    const customer = await Customer.findOne({ businessId, phone: phone.trim() });
    return customer;
  }
}

module.exports = new CustomerService();

