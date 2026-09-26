const mongoose = require('mongoose');
const Staff = require('../models/Staff');
const User = require('../models/User');

class StaffService {
  _buildStaffQuery(businessId, id) {
    if (mongoose.Types.ObjectId.isValid(id)) {
      return { _id: id, businessId };
    }
    return {
      businessId,
      $or: [
        { employeeId: id },
        { email: id.toLowerCase() },
      ],
    };
  }
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
    const query = this._buildStaffQuery(businessId, id);
    const staff = await Staff.findOne(query);
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

    const email = staffData.email ? staffData.email.trim().toLowerCase() : '';
    const phone = staffData.phone ? staffData.phone.trim() : '';
    const rawPassword = staffData.password || 'Staff@123';

    let user = null;
    if (email) {
      const existingUser = await User.findOne({ email });
      if (existingUser) {
        throw new Error('An account with this email address already exists.');
      }

      const passwordHash = await User.hashPassword(rawPassword);
      user = await User.create({
        email,
        phone: phone || undefined,
        passwordHash,
        role: (staffData.role || 'cashier').toLowerCase(),
        businessId,
        onboardingCompleted: true,
        onboardingStep: 4,
      });
    }

    const staff = new Staff({
      ...staffData,
      businessId,
      userId: user ? user._id : undefined,
      employeeId,
      status: staffData.status || 'Active',
      role: staffData.role || 'Cashier',
    });

    await staff.save();

    if (user) {
      user.staffId = staff._id;
      await user.save();
    }

    return staff;
  }

  async updateStaff(businessId, id, staffData) {
    const query = this._buildStaffQuery(businessId, id);
    let existingStaff = await Staff.findOne(query);
    if (!existingStaff) {
      return this.createStaff(businessId, { ...staffData, employeeId: staffData.employeeId || id });
    }

    const staff = await Staff.findOneAndUpdate(
      { _id: existingStaff._id, businessId },
      { $set: staffData },
      { new: true, runValidators: true }
    );

    // Synchronize password or details with linked User
    const email = staffData.email ? staffData.email.trim().toLowerCase() : staff.email;
    const phone = staffData.phone !== undefined ? staffData.phone.trim() : staff.phone;

    if (staff.userId) {
      const userUpdates = {};
      if (staffData.password && staffData.password.trim().length > 0) {
        userUpdates.passwordHash = await User.hashPassword(staffData.password.trim());
      }
      if (staffData.role) {
        userUpdates.role = staffData.role.toLowerCase();
      }
      if (staffData.email && staffData.email.trim().toLowerCase() !== existingStaff.email) {
        userUpdates.email = staffData.email.trim().toLowerCase();
      }
      if (staffData.phone !== undefined) {
        userUpdates.phone = staffData.phone.trim();
      }

      if (Object.keys(userUpdates).length > 0) {
        await User.findByIdAndUpdate(staff.userId, { $set: userUpdates });
      }
    } else if (email && staffData.password && staffData.password.trim().length > 0) {
      // Create user if not linked yet
      const existingUser = await User.findOne({ email });
      if (!existingUser) {
        const passwordHash = await User.hashPassword(staffData.password.trim());
        const user = await User.create({
          email,
          phone: phone || undefined,
          passwordHash,
          role: (staff.role || 'cashier').toLowerCase(),
          businessId,
          staffId: staff._id,
          onboardingCompleted: true,
          onboardingStep: 4,
        });
        staff.userId = user._id;
        await staff.save();
      }
    }

    return staff;
  }

  async toggleStaffStatus(businessId, id) {
    const query = this._buildStaffQuery(businessId, id);
    const staff = await Staff.findOne(query);
    if (!staff) {
      throw new Error('Staff member not found');
    }

    staff.status = staff.status === 'Active' ? 'Inactive' : 'Active';
    await staff.save();
    return staff;
  }

  async deleteStaff(businessId, id) {
    const query = this._buildStaffQuery(businessId, id);
    const staff = await Staff.findOneAndDelete(query);
    if (!staff) {
      throw new Error('Staff member not found');
    }

    if (staff.userId) {
      try {
        await User.findByIdAndDelete(staff.userId);
      } catch (_) {}
    }

    return { id, message: 'Staff member deleted successfully' };
  }
}

module.exports = new StaffService();
