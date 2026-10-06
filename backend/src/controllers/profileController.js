const Business = require('../models/Business');
const User = require('../models/User');
const ProfileHistory = require('../models/ProfileHistory');
const tableService = require('../services/tableService');
const ApiResponse = require('../utils/ApiResponse');
const ApiError = require('../utils/ApiError');

class ProfileController {
  async getProfile(req, res, next) {
    try {
      const business = await Business.findOne({ ownerId: req.user._id });
      return ApiResponse.success(
        res,
        {
          user: req.user,
          business: business || null,
        },
        'Profile retrieved'
      );
    } catch (error) {
      next(error);
    }
  }

  /**
   * Update Business Profile (Name, Company Name, Profile Logo, Phone)
   * and record an audit history in backend and database.
   */
  async updateProfile(req, res, next) {
    try {
      const {
        name,
        companyName,
        profileLogo,
        profileImage,
        phone,
        changeReason,
      } = req.body;

      let business = await Business.findOne({ ownerId: req.user._id });
      if (!business) {
        business = new Business({
          ownerId: req.user._id,
          profile: {},
        });
      }

      const prevLogo = business.profile?.profileImage || '';
      const prevName = business.profile?.name || '';
      const prevCompanyName = business.profile?.companyName || '';
      const prevPhone = business.profile?.phone || req.user.phone || '';

      const effectiveLogo = profileLogo !== undefined ? profileLogo : profileImage;
      const newLogo = effectiveLogo !== undefined ? effectiveLogo.trim() : prevLogo;
      const newName = name !== undefined ? name.trim() : prevName;
      const newCompanyName = companyName !== undefined ? companyName.trim() : prevCompanyName;
      const newPhone = phone !== undefined ? phone.trim() : prevPhone;

      const changedFields = [];
      if (effectiveLogo !== undefined && newLogo !== prevLogo) changedFields.push('profileLogo');
      if (name !== undefined && newName !== prevName) changedFields.push('name');
      if (companyName !== undefined && newCompanyName !== prevCompanyName) changedFields.push('companyName');
      if (phone !== undefined && newPhone !== prevPhone) changedFields.push('phone');

      let historyEntry = null;

      if (changedFields.length > 0) {
        const historyData = {
          businessId: business._id,
          ownerId: req.user._id,
          updatedBy: req.user._id,
          previousProfile: {
            name: prevName,
            companyName: prevCompanyName,
            profileLogo: prevLogo,
            phone: prevPhone,
          },
          updatedProfile: {
            name: newName,
            companyName: newCompanyName,
            profileLogo: newLogo,
            phone: newPhone,
          },
          changedFields,
          changeReason: changeReason || 'Profile edited from Business Settings Hub',
          ipAddress: req.ip || req.headers['x-forwarded-for'] || '',
          updatedAt: new Date(),
        };

        // 1. Persist to ProfileHistory collection
        historyEntry = await ProfileHistory.create(historyData);

        // 2. Also keep recent audit history in embedded business.profileHistory array
        if (!business.profileHistory) {
          business.profileHistory = [];
        }
        business.profileHistory.unshift(historyData);
        if (business.profileHistory.length > 50) {
          business.profileHistory = business.profileHistory.slice(0, 50);
        }
      }

      // Update business profile fields
      business.profile = business.profile || {};
      if (effectiveLogo !== undefined) business.profile.profileImage = newLogo;
      if (name !== undefined) business.profile.name = newName;
      if (companyName !== undefined) business.profile.companyName = newCompanyName;
      if (phone !== undefined) business.profile.phone = newPhone;

      await business.save();

      // Keep user name and phone in sync if provided
      const userUpdates = {};
      if (req.body.ownerName && req.body.ownerName.trim()) {
        userUpdates.name = req.body.ownerName.trim();
      }
      if (phone !== undefined && newPhone) {
        userUpdates.phone = newPhone;
      }
      if (Object.keys(userUpdates).length > 0 && req.user._id) {
        await User.findByIdAndUpdate(req.user._id, userUpdates);
      }

      return ApiResponse.success(
        res,
        {
          business,
          historyEntry,
          changedFields,
        },
        'Business profile updated and audit history recorded successfully'
      );
    } catch (error) {
      next(error);
    }
  }

  /**
   * Retrieve audit history of business profile updates
   */
  async getProfileHistory(req, res, next) {
    try {
      const business = await Business.findOne({ ownerId: req.user._id });
      if (!business) {
        return ApiResponse.success(res, { history: [] }, 'No profile history found');
      }

      let history = await ProfileHistory.find({ businessId: business._id })
        .sort({ createdAt: -1 })
        .limit(100)
        .populate('updatedBy', 'email phone role')
        .lean();

      if (!history || history.length === 0) {
        history = (business.profileHistory || []).map((h) => ({
          ...h,
          id: h._id,
        }));
      }

      return ApiResponse.success(
        res,
        {
          businessId: business._id,
          total: history.length,
          history,
        },
        'Profile update history fetched successfully'
      );
    } catch (error) {
      next(error);
    }
  }

  async updatePosSettings(req, res, next) {
    try {
      const { posViewMode, enableChotuVoice } = req.body;
      const updateData = {};

      if (posViewMode !== undefined) {
        if (!['with_image', 'without_image'].includes(posViewMode)) {
          throw ApiError.badRequest("posViewMode must be either 'with_image' or 'without_image'");
        }
        updateData['orderSettings.posViewMode'] = posViewMode;
      }

      if (typeof enableChotuVoice === 'boolean') {
        updateData['orderSettings.enableChotuVoice'] = enableChotuVoice;
      }

      const business = await Business.findOneAndUpdate(
        { ownerId: req.user._id },
        { $set: updateData },
        { new: true, upsert: true }
      );

      return ApiResponse.success(res, { business }, 'POS settings updated successfully');
    } catch (error) {
      next(error);
    }
  }

  async updateSettings(req, res, next) {
    try {
      let business = await Business.findOne({ ownerId: req.user._id });
      if (!business) {
        business = new Business({
          ownerId: req.user._id,
          profile: {},
        });
      }

      const prevLogo = business.profile?.profileImage || '';
      const prevName = business.profile?.name || '';
      const prevCompanyName = business.profile?.companyName || '';
      const prevPhone = business.profile?.phone || '';

      const allowedUpdates = {};
      const changedFields = [];

      if (req.body.name !== undefined && req.body.name.trim() !== prevName) {
        allowedUpdates['profile.name'] = req.body.name.trim();
        changedFields.push('name');
      }
      if (req.body.companyName !== undefined && req.body.companyName.trim() !== prevCompanyName) {
        allowedUpdates['profile.companyName'] = req.body.companyName.trim();
        changedFields.push('companyName');
      }
      const logoInput = req.body.profileLogo || req.body.profileImage || req.body.logoUrl;
      if (logoInput !== undefined && logoInput.trim() !== prevLogo) {
        allowedUpdates['profile.profileImage'] = logoInput.trim();
        changedFields.push('profileLogo');
      }
      if (req.body.phone !== undefined && req.body.phone.trim() !== prevPhone) {
        allowedUpdates['profile.phone'] = req.body.phone.trim();
        changedFields.push('phone');
      }
      if (req.body.tagline !== undefined) allowedUpdates['profile.tagline'] = req.body.tagline;
      if (req.body.address !== undefined) allowedUpdates['address.addressLine'] = req.body.address;
      if (req.body.taxRate !== undefined) allowedUpdates['orderSettings.tax.percentage'] = req.body.taxRate;
      if (req.body.upiId !== undefined) allowedUpdates['orderSettings.upiId'] = req.body.upiId;
      if (req.body.tableCount !== undefined) {
        allowedUpdates['orderSettings.tableCount'] = Math.max(0, parseInt(req.body.tableCount, 10) || 0);
      }
      if (req.body.posViewMode) {
        if (!['with_image', 'without_image'].includes(req.body.posViewMode)) {
          throw ApiError.badRequest("posViewMode must be either 'with_image' or 'without_image'");
        }
        allowedUpdates['orderSettings.posViewMode'] = req.body.posViewMode;
      }

      // Record history if core profile fields changed
      if (changedFields.length > 0) {
        const historyData = {
          businessId: business._id,
          ownerId: req.user._id,
          updatedBy: req.user._id,
          previousProfile: {
            name: prevName,
            companyName: prevCompanyName,
            profileLogo: prevLogo,
            phone: prevPhone,
          },
          updatedProfile: {
            name: req.body.name !== undefined ? req.body.name.trim() : prevName,
            companyName: req.body.companyName !== undefined ? req.body.companyName.trim() : prevCompanyName,
            profileLogo: logoInput !== undefined ? logoInput.trim() : prevLogo,
            phone: req.body.phone !== undefined ? req.body.phone.trim() : prevPhone,
          },
          changedFields,
          changeReason: 'Profile updated via settings API',
          ipAddress: req.ip || req.headers['x-forwarded-for'] || '',
          updatedAt: new Date(),
        };

        try {
          await ProfileHistory.create(historyData);
          if (!business.profileHistory) business.profileHistory = [];
          business.profileHistory.unshift(historyData);
          if (business.profileHistory.length > 50) {
            business.profileHistory = business.profileHistory.slice(0, 50);
          }
        } catch (e) {
          console.warn('[ProfileController] Failed to record ProfileHistory log:', e.message);
        }
      }

      Object.assign(business, allowedUpdates);
      const updatedBusiness = await Business.findOneAndUpdate(
        { ownerId: req.user._id },
        {
          $set: allowedUpdates,
          ...(business.profileHistory?.length ? { $set: { profileHistory: business.profileHistory } } : {}),
        },
        { new: true, upsert: true }
      );

      if (req.body.tableCount !== undefined && updatedBusiness) {
        await tableService.syncBusinessTableCount(updatedBusiness._id, req.body.tableCount);
      }

      return ApiResponse.success(res, { business: updatedBusiness }, 'Settings updated successfully');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new ProfileController();
