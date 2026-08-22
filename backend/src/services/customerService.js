const Customer = require('../models/Customer');
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
      .select('name phone email address totalOrders totalSpent lastVisit');

    return customers;
  }

  async createOrUpdateCustomer(businessId, customerData) {
    const phone = (customerData.phone || '').toString().trim();
    const name = (customerData.name || '').toString().trim();
    const customer = await Customer.findOneAndUpdate(
      { businessId, phone },
      {
        $set: {
          name,
          email: customerData.email ? customerData.email.trim() : '',
          address: customerData.address || '',
          lastVisit: new Date(),
        },
        $setOnInsert: { businessId, phone, firstVisit: new Date() },
      },
      { upsert: true, new: true }
    );

    return customer;
  }

  async getCustomerByPhone(businessId, phone) {
    const customer = await Customer.findOne({ businessId, phone: phone.trim() });
    return customer;
  }
}

module.exports = new CustomerService();

