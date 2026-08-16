import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../database/database_service.dart';


class OnboardingService {
  static final OnboardingService _instance = OnboardingService._internal();
  factory OnboardingService() => _instance;
  OnboardingService._internal();

  final ApiClient _apiClient = ApiClient();
  DatabaseService get _db => DatabaseService();

  // Step 1: Save / Update Profile
  Future<Map<String, dynamic>> saveProfile({
    required String name,
    required String phone,
    required String companyName,
    String? profileImage,
    String? website,
    String? referralCode,
  }) async {
    final payload = {
      'name': name.trim(),
      'phone': phone.trim(),
      'companyName': companyName.trim(),
      'profileImage': profileImage ?? '',
      'website': website?.trim() ?? '',
      'referralCode': referralCode?.trim() ?? '',
    };

    final response = await _apiClient.patch(
      ApiEndpoints.onboardingProfile,
      data: payload,
    );

    final data = response['data'] as Map<String, dynamic>;

    // Update local DatabaseService cache
    final currentUser = _db.currentUser;
    if (currentUser != null) {
      final updated = currentUser.copyWith(
        name: name.trim(),
        phone: phone.trim(),
        companyName: companyName.trim(),
        website: website?.trim(),
        referralCode: referralCode?.trim(),
        profilePhotoPath: profileImage,
        onboardingStep: (data['onboardingStep'] as num?)?.toInt() ?? 1,
      );
      await _db.saveActiveUser(updated);
    }

    final rest = _db.restaurant;
    if (rest != null) {
      await _db.saveRestaurantOnboarding(
        rest.copyWith(
          name: companyName.trim(),
          phone: phone.trim(),
        ),
      );
    }

    return data;
  }

  // Step 2: Save / Update Business Details
  Future<Map<String, dynamic>> saveBusinessDetails({
    required String country,
    required String currency,
    required String timezone,
    required String businessType,
    String? phone,
  }) async {
    final payload = {
      'country': country.trim(),
      'currency': currency.trim(),
      'timezone': timezone.trim(),
      'businessType': businessType.trim(),
      if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
    };

    final response = await _apiClient.patch(
      ApiEndpoints.onboardingBusiness,
      data: payload,
    );

    final data = response['data'] as Map<String, dynamic>;

    final currentUser = _db.currentUser;
    if (currentUser != null) {
      final updated = currentUser.copyWith(
        onboardingStep: (data['onboardingStep'] as num?)?.toInt() ?? 2,
      );
      await _db.saveActiveUser(updated);
    }

    final rest = _db.restaurant;
    if (rest != null) {
      await _db.saveRestaurantOnboarding(
        rest.copyWith(
          cuisineType: businessType.trim(),
          currencySymbol: currency.trim() == 'INR' ? '₹' : currency.trim(),
        ),
      );
    }

    return data;
  }

  // Step 3: Save / Update Address
  Future<Map<String, dynamic>> saveAddress({
    String? addressLine,
    String? building,
    String? landmark,
    String placeType = 'work',
    required String city,
    String? state,
    String country = 'IN',
    String? postalCode,
    double latitude = 0.0,
    double longitude = 0.0,
  }) async {
    final payload = {
      'addressLine': addressLine ?? '',
      'building': building ?? '',
      'landmark': landmark ?? '',
      'placeType': placeType,
      'city': city.trim(),
      'state': state ?? '',
      'country': country,
      'postalCode': postalCode ?? '',
      'latitude': latitude,
      'longitude': longitude,
    };

    final response = await _apiClient.patch(
      ApiEndpoints.onboardingAddress,
      data: payload,
    );

    final data = response['data'] as Map<String, dynamic>;

    final currentUser = _db.currentUser;
    if (currentUser != null) {
      final updated = currentUser.copyWith(
        onboardingStep: (data['onboardingStep'] as num?)?.toInt() ?? 3,
      );
      await _db.saveActiveUser(updated);
    }

    final rest = _db.restaurant;
    if (rest != null) {
      await _db.saveRestaurantOnboarding(
        rest.copyWith(
          address: addressLine != null && addressLine.isNotEmpty
              ? addressLine
              : '$city, $country',
        ),
      );
    }

    return data;
  }

  // Step 4: Save / Update Order Settings
  Future<Map<String, dynamic>> saveOrderSettings({
    required Map<String, bool> services,
    required String taxType,
    String? gstNumber,
    double? taxPercentage,
    required String restaurantType,
    required Map<String, bool> paymentMethods,
    String? upiId,
    required int tableCount,
  }) async {
    final payload = {
      'services': services,
      'tax': {
        'type': taxType,
        'gstNumber': gstNumber ?? '',
        'percentage': taxPercentage,
      },
      'restaurantType': restaurantType,
      'paymentMethods': paymentMethods,
      'upiId': upiId ?? '',
      'tableCount': tableCount,
    };

    final response = await _apiClient.patch(
      ApiEndpoints.onboardingOrderSettings,
      data: payload,
    );

    final data = response['data'] as Map<String, dynamic>;

    final currentUser = _db.currentUser;
    if (currentUser != null) {
      final updated = currentUser.copyWith(
        onboardingStep: (data['onboardingStep'] as num?)?.toInt() ?? 4,
      );
      await _db.saveActiveUser(updated);
    }

    final rest = _db.restaurant;
    if (rest != null) {
      await _db.saveRestaurantOnboarding(
        rest.copyWith(
          services: services.entries.where((e) => e.value).map((e) => e.key).toList(),
          billingType: taxType == 'gst' ? 'GST' : 'Non-GST',
          gstNumber: gstNumber ?? '',
          taxRate: taxType == 'gst' ? (taxPercentage ?? 5.0) : 0.0,
          restaurantType: restaurantType,
          upiId: upiId ?? 'apnapos@upi',
          tableCount: tableCount,
        ),
      );
    }

    return data;
  }

  // Get Onboarding Status
  Future<Map<String, dynamic>> getStatus() async {
    final response = await _apiClient.get(ApiEndpoints.onboardingStatus);
    return response['data'] as Map<String, dynamic>;
  }

  // Complete Onboarding (Backend verified)
  Future<Map<String, dynamic>> completeOnboarding() async {
    final response = await _apiClient.post(ApiEndpoints.onboardingComplete);
    final data = response['data'] as Map<String, dynamic>;

    final currentUser = _db.currentUser;
    if (currentUser != null) {
      final updated = currentUser.copyWith(
        onboardingCompleted: true,
        onboardingStep: 4,
      );
      await _db.saveActiveUser(updated);
    }

    final rest = _db.restaurant;
    if (rest != null) {
      await _db.saveRestaurantOnboarding(
        rest.copyWith(
          isOnboarded: true,
        ),
      );
    }

    return data;
  }
}
