const Business = require('../models/Business');
const User = require('../models/User');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');

class OnboardingController {
  // Helper to get or create single business for user (Idempotent)
  async _getOrCreateBusiness(userId) {
    let business = await Business.findOne({ ownerId: userId });
    if (!business) {
      business = await Business.create({ ownerId: userId });
    }
    return business;
  }

  // Step 1: Save / Update Profile (PATCH /api/v1/onboarding/profile)
  async saveProfile(req, res, next) {
    try {
      const { name, phone, companyName, profileImage, website, referralCode } = req.body;
      const userId = req.user._id;

      const business = await this._getOrCreateBusiness(userId);

      business.profile = {
        name: name.trim(),
        phone: phone.trim(),
        companyName: companyName.trim(),
        profileImage: profileImage || '',
        website: website ? website.trim() : '',
        referralCode: referralCode ? referralCode.trim() : '',
      };

      await business.save();

      // Update user onboardingStep if not already further
      const user = await User.findById(userId);
      if (user.onboardingStep < 1) {
        user.onboardingStep = 1;
        await user.save();
      }

      return ApiResponse.success(
        res,
        {
          onboardingStep: user.onboardingStep,
          profile: business.profile,
          business,
        },
        'Profile details saved successfully'
      );
    } catch (error) {
      next(error);
    }
  }

  // Step 2: Save / Update Business Details (PATCH /api/v1/onboarding/business)
  async saveBusiness(req, res, next) {
    try {
      const { country, currency, timezone, businessType, phone } = req.body;
      const userId = req.user._id;

      const business = await this._getOrCreateBusiness(userId);

      business.business = {
        country: (country || 'IN').trim(),
        currency: (currency || 'INR').trim(),
        timezone: (timezone || 'Asia/Kolkata').trim(),
        businessType: businessType.trim(),
      };

      if (phone && phone.trim()) {
        business.profile.phone = phone.trim();
      }

      await business.save();

      const user = await User.findById(userId);
      if (user.onboardingStep < 2) {
        user.onboardingStep = 2;
        await user.save();
      }

      return ApiResponse.success(
        res,
        {
          onboardingStep: user.onboardingStep,
          businessDetails: business.business,
          business,
        },
        'Business details saved successfully'
      );
    } catch (error) {
      next(error);
    }
  }

  // Step 3: Save / Update Address (PATCH /api/v1/onboarding/address)
  async saveAddress(req, res, next) {
    try {
      const {
        addressLine,
        address,
        building,
        landmark,
        placeType,
        city,
        state,
        country,
        postalCode,
        latitude,
        longitude,
      } = req.body;

      const userId = req.user._id;
      const business = await this._getOrCreateBusiness(userId);

      const resolvedAddressLine = (addressLine || address || '').trim();
      const lat = Number(latitude) || 0;
      const lng = Number(longitude) || 0;

      business.address = {
        addressLine: resolvedAddressLine,
        building: (building || '').trim(),
        landmark: (landmark || '').trim(),
        placeType: placeType || 'work',
        city: city.trim(),
        state: (state || '').trim(),
        country: (country || 'IN').trim(),
        postalCode: (postalCode || '').trim(),
        location: {
          type: 'Point',
          coordinates: [lng, lat],
        },
      };

      await business.save();

      const user = await User.findById(userId);
      if (user.onboardingStep < 3) {
        user.onboardingStep = 3;
        await user.save();
      }

      return ApiResponse.success(
        res,
        {
          onboardingStep: user.onboardingStep,
          address: business.address,
          business,
        },
        'Address saved successfully'
      );
    } catch (error) {
      next(error);
    }
  }

  // Step 4: Save / Update Order Settings (PATCH /api/v1/onboarding/order-settings)
  async saveOrderSettings(req, res, next) {
    try {
      const { services, tax, restaurantType, paymentMethods, upiId, tableCount } = req.body;
      const userId = req.user._id;

      const business = await this._getOrCreateBusiness(userId);

      business.orderSettings = {
        services: {
          dineIn: services?.dineIn ?? true,
          takeaway: services?.takeaway ?? false,
          delivery: services?.delivery ?? false,
        },
        tax: {
          type: tax.type,
          gstNumber: tax.type === 'gst' ? (tax.gstNumber || '').trim().toUpperCase() : '',
          percentage: tax.type === 'gst' ? Number(tax.percentage) : null,
        },
        restaurantType: restaurantType || 'both',
        paymentMethods: {
          cash: paymentMethods?.cash ?? true,
          upi: paymentMethods?.upi ?? true,
          card: paymentMethods?.card ?? false,
        },
        upiId: (upiId || '').trim(),
        tableCount: Math.max(0, Number(tableCount) || 0),
      };

      await business.save();

      const user = await User.findById(userId);
      if (user.onboardingStep < 4) {
        user.onboardingStep = 4;
        await user.save();
      }

      return ApiResponse.success(
        res,
        {
          onboardingStep: user.onboardingStep,
          orderSettings: business.orderSettings,
          business,
        },
        'Order settings saved successfully'
      );
    } catch (error) {
      next(error);
    }
  }

  // Get Onboarding Status (GET /api/v1/onboarding/status)
  async getStatus(req, res, next) {
    try {
      const userId = req.user._id;
      const user = await User.findById(userId);
      const business = await Business.findOne({ ownerId: userId });

      let currentStep = user.onboardingStep || 0;
      let nextStep = currentStep < 4 ? currentStep + 1 : 4;
      if (user.onboardingCompleted) {
        nextStep = null;
      }

      return ApiResponse.success(
        res,
        {
          completed: user.onboardingCompleted,
          currentStep,
          nextStep,
          business: business || null,
        },
        'Onboarding status retrieved'
      );
    } catch (error) {
      next(error);
    }
  }

  // Complete Onboarding with Backend Verification (POST /api/v1/onboarding/complete)
  async completeOnboarding(req, res, next) {
    try {
      const userId = req.user._id;
      const user = await User.findById(userId);
      const business = await Business.findOne({ ownerId: userId });

      if (!business) {
        throw ApiError.badRequest('No business profile found. Please complete onboarding steps first.', null, 'ONBOARDING_INCOMPLETE');
      }

      const missingSteps = [];

      // Verify Step 1
      if (!business.profile?.name || !business.profile?.phone || !business.profile?.companyName) {
        missingSteps.push('Step 1: Profile information');
      }

      // Verify Step 2
      if (!business.business?.country || !business.business?.currency || !business.business?.businessType) {
        missingSteps.push('Step 2: Business details');
      }

      // Verify Step 3
      if (!business.address?.city) {
        missingSteps.push('Step 3: Business address');
      }

      // Verify Step 4
      if (!business.orderSettings?.restaurantType || !business.orderSettings?.tax?.type) {
        missingSteps.push('Step 4: Order settings');
      }

      if (missingSteps.length > 0) {
        throw ApiError.badRequest(
          `Cannot complete onboarding. The following required information is missing: ${missingSteps.join(', ')}`,
          { missingSteps },
          'ONBOARDING_INCOMPLETE'
        );
      }

      user.onboardingCompleted = true;
      user.onboardingStep = 4;
      await user.save();

      return ApiResponse.success(
        res,
        {
          onboardingCompleted: true,
          onboardingStep: 4,
          user: {
            id: user._id,
            email: user.email,
            role: user.role,
            onboardingCompleted: user.onboardingCompleted,
            onboardingStep: user.onboardingStep,
          },
          business,
        },
        'Onboarding completed successfully'
      );
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new OnboardingController();
