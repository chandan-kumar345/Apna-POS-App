import 'dart:async';
import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../security/secure_storage_service.dart';
import '../models/user_model.dart';
import '../models/business_model.dart';
import '../models/restaurant_model.dart';
import '../database/database_service.dart';
import 'product_service.dart';
import 'local_notification_service.dart';
import 'fcm_service.dart';

import 'session_manager.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiClient _apiClient = ApiClient();
  final SecureStorageService _storage = SecureStorageService();
  final SessionManager _sessionManager = SessionManager();
  DatabaseService get _db => DatabaseService();

  // Register
  Future<Map<String, dynamic>> register(String email, String password, {String? phone}) async {
    final response = await _apiClient.post(
      ApiEndpoints.register,
      data: {
        'email': email.trim().toLowerCase(),
        'password': password,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    );

    final data = response['data'] as Map<String, dynamic>;
    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    final userJson = data['user'] as Map<String, dynamic>;

    if (accessToken != null) {
      await _storage.saveAccessToken(accessToken);
    }
    if (refreshToken != null) {
      await _storage.saveRefreshToken(refreshToken);
    }

    final user = UserModel.fromJson(userJson);
    await _storage.saveUserId(user.id);
    await _sessionManager.saveSession(user.id);
    await _db.saveActiveUser(user);
    await _db.clearUserDataForNewAccount();
    ProductService.clearPosCache();

    // Register device push token with backend
    unawaited(FcmService().registerTokenWithBackend());

    // Deliver welcome push notification upon register
    LocalNotificationService().deliverWelcomeNotificationOnLogin(userName: user.name);

    return data;
  }

  // Login (by email, phone, or employee ID)
  Future<Map<String, dynamic>> login(String identifier, String password, {String? pin}) async {
    final cleanIdentifier = identifier.trim().contains('@')
        ? identifier.trim().toLowerCase()
        : identifier.trim();

    final response = await _apiClient.post(
      ApiEndpoints.login,
      data: {
        'identifier': cleanIdentifier,
        'email': cleanIdentifier,
        'password': password,
        if (pin != null && pin.trim().isNotEmpty) 'pin': pin.trim(),
      },
    );


    final data = response['data'] as Map<String, dynamic>;
    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    final userJson = data['user'] as Map<String, dynamic>;

    if (accessToken != null) {
      await _storage.saveAccessToken(accessToken);
    }
    if (refreshToken != null) {
      await _storage.saveRefreshToken(refreshToken);
    }

    ProductService.clearPosCache();

    // Extract business details if present
    final businessJson = (data['business'] ?? userJson['business']) as Map<String, dynamic>?;
    if (businessJson != null && businessJson['profile'] != null && businessJson['profile'] is Map) {
      final profile = businessJson['profile'] as Map<String, dynamic>;
      if ((userJson['name'] == null || (userJson['name'] as String).isEmpty) && profile['name'] != null) {
        userJson['name'] = profile['name'];
      }
      if ((userJson['companyName'] == null || (userJson['companyName'] as String).isEmpty) && profile['companyName'] != null) {
        userJson['companyName'] = profile['companyName'];
      }
      if ((userJson['profilePhotoPath'] == null || (userJson['profilePhotoPath'] as String).isEmpty) && profile['profileImage'] != null) {
        userJson['profilePhotoPath'] = profile['profileImage'];
      }
      if ((userJson['phone'] == null || (userJson['phone'] as String).isEmpty) && profile['phone'] != null) {
        userJson['phone'] = profile['phone'];
      }
    }

    final user = UserModel.fromJson(userJson);
    await _storage.saveUserId(user.id);
    await _sessionManager.saveSession(user.id);
    await _db.saveActiveUser(user);
    await _db.loadUserDataForActiveUser(user.id);

    // If business data is attached in login response, update db cache
    if (businessJson != null) {
      try {
        final business = BusinessModel.fromJson(businessJson);
        final rest = _db.restaurant;
        final updated = (rest ?? RestaurantModel(
          id: user.id,
          name: business.profile.companyName.isNotEmpty ? business.profile.companyName : 'My Restaurant',
          tagline: 'Smart POS',
          phone: business.profile.phone,
          address: business.address.addressLine,
          cuisineType: business.business.businessType.isNotEmpty ? business.business.businessType : 'Restaurant',
          currencySymbol: business.business.currency == 'INR' ? '₹' : business.business.currency,
          tableCount: business.orderSettings.tableCount,
          isOnboarded: user.onboardingCompleted,
        )).copyWith(
          name: business.profile.companyName.isNotEmpty ? business.profile.companyName : rest?.name,
          phone: business.profile.phone.isNotEmpty ? business.profile.phone : rest?.phone,
          address: business.address.addressLine.isNotEmpty ? business.address.addressLine : rest?.address,
          cuisineType: business.business.businessType.isNotEmpty ? business.business.businessType : rest?.cuisineType,
          currencySymbol: business.business.currency == 'INR' ? '₹' : business.business.currency,
          tableCount: business.orderSettings.tableCount,
          isOnboarded: user.onboardingCompleted,
        );
        final bId = (businessJson['_id'] ?? businessJson['id'])?.toString();
        if (bId != null && bId.isNotEmpty) {
          await _db.saveBusinessId(bId);
        }
        await _db.saveRestaurantOnboarding(updated);
      } catch (e) {
        debugPrint('Error caching business from login: $e');
      }
    }

    // Restore WhatsApp connection credentials immediately upon login
    await _restoreWhatsAppSettingsIfPresent(userJson, businessJson);

    // Auto-fetch all cloud orders, products, tables, and floor status asynchronously in the background
    unawaited(_db.syncWithBackend().catchError((e) {
      debugPrint('[AuthService] background sync notice: $e');
    }));

    // Register device push token with backend
    unawaited(FcmService().registerTokenWithBackend());

    // Deliver welcome push notification upon login in background
    unawaited(Future(() => LocalNotificationService().deliverWelcomeNotificationOnLogin(userName: user.name)));

    return data;
  }

  // Dedicated Staff Login (by employeeId, email, or phone with password or PIN)
  Future<Map<String, dynamic>> staffLogin({
    required String identifier,
    String? password,
    String? pin,
    String? businessId,
  }) async {
    final cleanIdentifier = identifier.trim().contains('@')
        ? identifier.trim().toLowerCase()
        : identifier.trim();

    final response = await _apiClient.post(
      ApiEndpoints.staffLogin,
      data: {
        'identifier': cleanIdentifier,
        'employeeId': cleanIdentifier,
        'email': cleanIdentifier,
        if (password != null && password.trim().isNotEmpty) 'password': password.trim(),
        if (pin != null && pin.trim().isNotEmpty) 'pin': pin.trim(),
        if (businessId != null && businessId.trim().isNotEmpty) 'businessId': businessId.trim(),
      },
    );

    final data = response['data'] as Map<String, dynamic>;
    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    final userJson = data['user'] as Map<String, dynamic>;

    if (accessToken != null) {
      await _storage.saveAccessToken(accessToken);
    }
    if (refreshToken != null) {
      await _storage.saveRefreshToken(refreshToken);
    }

    ProductService.clearPosCache();

    final businessJson = (data['business'] ?? userJson['business']) as Map<String, dynamic>?;
    if (businessJson != null && businessJson['profile'] != null && businessJson['profile'] is Map) {
      final profile = businessJson['profile'] as Map<String, dynamic>;
      if ((userJson['name'] == null || (userJson['name'] as String).isEmpty) && profile['name'] != null) {
        userJson['name'] = profile['name'];
      }
      if ((userJson['companyName'] == null || (userJson['companyName'] as String).isEmpty) && profile['companyName'] != null) {
        userJson['companyName'] = profile['companyName'];
      }
      if ((userJson['profilePhotoPath'] == null || (userJson['profilePhotoPath'] as String).isEmpty) && profile['profileImage'] != null) {
        userJson['profilePhotoPath'] = profile['profileImage'];
      }
      if ((userJson['phone'] == null || (userJson['phone'] as String).isEmpty) && profile['phone'] != null) {
        userJson['phone'] = profile['phone'];
      }
    }

    final staffJson = (data['staff'] ?? data['staffMember'] ?? userJson['staff']) as Map<String, dynamic>?;
    if (staffJson != null) {
      final staffAvatar = staffJson['avatarUrl'] ?? staffJson['profilePhotoPath'] ?? staffJson['photoUrl'] ?? staffJson['avatar'] ?? staffJson['profileImage'] ?? staffJson['logoUrl'] ?? staffJson['logo'];
      if (staffAvatar != null && staffAvatar.toString().trim().isNotEmpty) {
        userJson['profilePhotoPath'] = staffAvatar.toString().trim();
        userJson['avatarUrl'] = staffAvatar.toString().trim();
      }
    }

    final user = UserModel.fromJson(userJson);
    await _storage.saveUserId(user.id);
    await _sessionManager.saveSession(user.id);
    await _db.saveActiveUser(user);
    await _db.loadUserDataForActiveUser(user.id);

    if (businessJson != null) {
      try {
        final business = BusinessModel.fromJson(businessJson);
        final rest = _db.restaurant;
        final updated = (rest ?? RestaurantModel(
          id: user.id,
          name: business.profile.companyName.isNotEmpty ? business.profile.companyName : 'My Restaurant',
          tagline: 'Smart POS',
          phone: business.profile.phone,
          address: business.address.addressLine,
          cuisineType: business.business.businessType.isNotEmpty ? business.business.businessType : 'Restaurant',
          currencySymbol: business.business.currency == 'INR' ? '₹' : business.business.currency,
          tableCount: business.orderSettings.tableCount,
          isOnboarded: user.onboardingCompleted,
        )).copyWith(
          name: business.profile.companyName.isNotEmpty ? business.profile.companyName : rest?.name,
          phone: business.profile.phone.isNotEmpty ? business.profile.phone : rest?.phone,
          address: business.address.addressLine.isNotEmpty ? business.address.addressLine : rest?.address,
          cuisineType: business.business.businessType.isNotEmpty ? business.business.businessType : rest?.cuisineType,
          currencySymbol: business.business.currency == 'INR' ? '₹' : business.business.currency,
          tableCount: business.orderSettings.tableCount,
          isOnboarded: user.onboardingCompleted,
        );
        await _db.saveRestaurantOnboarding(updated);
      } catch (e) {
        debugPrint('Error caching business from staffLogin: $e');
      }
    }

    // Restore WhatsApp connection credentials immediately upon staff login
    await _restoreWhatsAppSettingsIfPresent(userJson, businessJson);

    unawaited(_db.syncWithBackend().catchError((e) {
      debugPrint('[AuthService] background sync notice: $e');
    }));

    // Register device push token with backend
    unawaited(FcmService().registerTokenWithBackend());

    unawaited(Future(() => LocalNotificationService().deliverWelcomeNotificationOnLogin(userName: user.name)));

    return data;
  }

  // Get Me
  Future<Map<String, dynamic>> getMe() async {
    final response = await _apiClient.get(ApiEndpoints.me);
    final data = response['data'] as Map<String, dynamic>;

    final userJson = data['user'] as Map<String, dynamic>;
    final businessJson = (data['business'] ?? userJson['business']) as Map<String, dynamic>?;

    if (businessJson != null && businessJson['profile'] != null && businessJson['profile'] is Map) {
      final profile = businessJson['profile'] as Map<String, dynamic>;
      if ((userJson['name'] == null || (userJson['name'] as String).isEmpty) && profile['name'] != null) {
        userJson['name'] = profile['name'];
      }
      if ((userJson['companyName'] == null || (userJson['companyName'] as String).isEmpty) && profile['companyName'] != null) {
        userJson['companyName'] = profile['companyName'];
      }
      if ((userJson['profilePhotoPath'] == null || (userJson['profilePhotoPath'] as String).isEmpty) && profile['profileImage'] != null) {
        userJson['profilePhotoPath'] = profile['profileImage'];
      }
      if ((userJson['phone'] == null || (userJson['phone'] as String).isEmpty) && profile['phone'] != null) {
        userJson['phone'] = profile['phone'];
      }
    }

    final user = UserModel.fromJson(userJson);
    await _db.saveActiveUser(user);

    if (businessJson != null) {
      try {
        final business = BusinessModel.fromJson(businessJson);
        final rest = _db.restaurant;
        final updated = (rest ?? RestaurantModel(
          id: user.id,
          name: business.profile.companyName.isNotEmpty ? business.profile.companyName : 'My Restaurant',
          tagline: 'Smart POS',
          phone: business.profile.phone,
          address: business.address.addressLine,
          cuisineType: business.business.businessType.isNotEmpty ? business.business.businessType : 'Restaurant',
          currencySymbol: business.business.currency == 'INR' ? '₹' : business.business.currency,
          tableCount: business.orderSettings.tableCount,
          isOnboarded: user.onboardingCompleted,
        )).copyWith(
          name: business.profile.companyName.isNotEmpty ? business.profile.companyName : rest?.name,
          phone: business.profile.phone.isNotEmpty ? business.profile.phone : rest?.phone,
          address: business.address.addressLine.isNotEmpty ? business.address.addressLine : rest?.address,
          cuisineType: business.business.businessType.isNotEmpty ? business.business.businessType : rest?.cuisineType,
          currencySymbol: business.business.currency == 'INR' ? '₹' : business.business.currency,
          tableCount: business.orderSettings.tableCount,
          isOnboarded: user.onboardingCompleted,
        );
        await _db.saveRestaurantOnboarding(updated);
      } catch (e) {
        debugPrint('Error caching business from getMe: $e');
      }
    }

    // Restore WhatsApp connection credentials immediately upon profile sync
    await _restoreWhatsAppSettingsIfPresent(userJson, businessJson);

    return data;
  }


  // Logout
  Future<void> logout() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken != null) {
        await _apiClient.post(
          ApiEndpoints.logout,
          data: {'refreshToken': refreshToken},
        );
      }
    } catch (e) {
      debugPrint('Logout api warning: $e');
    } finally {
      ProductService.clearPosCache();
      await _storage.clearAll();
      await _sessionManager.clearSession();
      await _db.logout();
    }
  }


  // Reset Password
  Future<Map<String, dynamic>> resetPassword(String email, String newPassword) async {
    final response = await _apiClient.post(
      ApiEndpoints.resetPassword,
      data: {
        'email': email.trim().toLowerCase(),
        'newPassword': newPassword,
      },
    );
    return (response['data'] as Map<String, dynamic>?) ?? response;
  }

  // Check if active access token exists
  Future<bool> isAuthenticated() async {
    final token = await _storage.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> _restoreWhatsAppSettingsIfPresent(
    Map<String, dynamic>? userJson,
    Map<String, dynamic>? businessJson,
  ) async {
    try {
      final waJson = (userJson?['whatsappSettings'] ?? businessJson?['whatsappSettings']) as Map<String, dynamic>?;
      if (waJson != null && (waJson['phoneNumberId'] != null || waJson['phoneNumber'] != null)) {
        final pId = waJson['phoneNumberId']?.toString() ?? '';
        final pNum = waJson['phoneNumber']?.toString() ?? '';
        final token = waJson['accessToken']?.toString() ?? '';
        final waba = waJson['wabaId']?.toString() ?? '';
        final isEn = waJson['enabled'] == true || pId.isNotEmpty;
        if (pId.isNotEmpty || pNum.isNotEmpty) {
          await _db.saveWhatsAppIntegrationSettings(
            enabled: isEn,
            provider: 'meta_cloud',
            phoneNumber: pNum,
            phoneId: pId,
            wabaId: waba,
            accessToken: token,
            webhookToken: _db.whatsAppWebhookToken,
          );
          debugPrint('[AuthService] 📲 Auto-restored connected WhatsApp into local database: $pId ($pNum)');
        }
      }
    } catch (e) {
      debugPrint('[AuthService] WhatsApp restore notice: $e');
    }
  }
}

