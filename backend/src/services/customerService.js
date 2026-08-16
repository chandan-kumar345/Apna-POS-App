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

  async createOrUpdateCustomer(businessId, customerData) {
    const phone = customerData.phone.trim();
    const customer = await Customer.findOneAndUpdate(
      { businessId, phone },
      {
        $set: {
          name: customerData.name.trim(),
          email: customerData.email ? customerData.email.trim() : '',
          address: customerData.address || '',
          lastVisit: new Date(),
        },
        $setOnInsert: { businessId, phone },
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
