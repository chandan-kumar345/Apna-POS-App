const Staff = require('../models/Staff');

class StaffService {
  async getStaff(businessId, query = {}) {
    const {
      search,
      role,
      status,
      page = 1,
      limit = 20,
      sortBy = 'createdAt',
      sortOrder = 'desc',
    } = query;

    const filter = { businessId };

    if (role && role !== 'All' && role !== 'All Roles') {
      filter.role = new RegExp(`^${role.trim()}$`, 'i');
    }

    if (status && status !== 'All' && status !== 'All Status') {
      filter.status = new RegExp(`^${status.trim()}$`, 'i');
    }

    if (search && search.trim().length > 0) {
      const searchRegex = new RegExp(search.trim(), 'i');
      filter.$or = [
        { name: searchRegex },
        { employeeId: searchRegex },
        { phone: searchRegex },
        { email: searchRegex },
        { role: searchRegex },
      ];
    }

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.max(1, parseInt(limit, 10) || 20);
    const skip = (pageNum - 1) * limitNum;

    const sortOptions = {};
    sortOptions[sortBy] = sortOrder === 'asc' ? 1 : -1;

    const [staffList, totalCount] = await Promise.all([
      Staff.find(filter).sort(sortOptions).skip(skip).limit(limitNum).lean(),
      Staff.countDocuments(filter),
    ]);

    const formattedStaff = staffList.map((s) => ({
      ...s,
      id: s._id ? s._id.toString() : s.id,
    }));

    return {
      staff: formattedStaff,
      pagination: {
        total: totalCount,
        page: pageNum,
        limit: limitNum,
        totalPages: Math.ceil(totalCount / limitNum) || 1,
      },
    };
  }

  async getStaffStats(businessId) {
    const [totalStaff, activeCount, inactiveCount, adminCount] = await Promise.all([
      Staff.countDocuments({ businessId }),
      Staff.countDocuments({ businessId, status: 'Active' }),
      Staff.countDocuments({ businessId, status: 'Inactive' }),
      Staff.countDocuments({ businessId, role: { $regex: /^admin$/i } }),
    ]);

    return {
      total: totalStaff,
      active: activeCount,
      inactive: inactiveCount,
      admins: adminCount,
    };
  }

  async getStaffById(businessId, id) {
    const staff = await Staff.findOne({ _id: id, businessId });
    if (!staff) {
      throw new Error('Staff member not found');
    }
    return staff;
  }

  async createStaff(businessId, staffData) {
    let employeeId = staffData.employeeId ? staffData.employeeId.trim() : '';

    if (!employeeId) {
      // Auto-generate next EMP ID
      const count = await Staff.countDocuments({ businessId });
      employeeId = `EMP${String(count + 1).padStart(3, '0')}`;
    }

    const staff = new Staff({
      ...staffData,
      businessId,
      employeeId,
      status: staffData.status || 'Active',
      role: staffData.role || 'Cashier',
    });

    await staff.save();
    return staff;
  }

  async updateStaff(businessId, id, staffData) {
    const staff = await Staff.findOneAndUpdate(
      { _id: id, businessId },
      { $set: staffData },
      { new: true, runValidators: true }
    );

    if (!staff) {
      throw new Error('Staff member not found');
    }
    return staff;
  }

  async toggleStaffStatus(businessId, id) {
    const staff = await Staff.findOne({ _id: id, businessId });
    if (!staff) {
      throw new Error('Staff member not found');
    }

    staff.status = staff.status === 'Active' ? 'Inactive' : 'Active';
    await staff.save();
    return staff;
  }

  async deleteStaff(businessId, id) {
    const staff = await Staff.findOneAndDelete({ _id: id, businessId });
    if (!staff) {
      throw new Error('Staff member not found');
    }
    return { id, message: 'Staff member deleted successfully' };
  }
}

module.exports = new StaffService();
