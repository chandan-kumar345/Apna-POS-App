import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class MetaPartnerStatus {
  final bool isPartnerManaged;
  final String partnerAdminEmail;
  final String partnerStatus;
  final String onboardingType;
  final String coManagementStatus;
  final String businessPortfolioId;
  final String wabaId;
  final String phoneNumberId;
  final String phoneNumber;
  final String qualityRating;
  final String messagingTier;
  final String displayNameStatus;
  final String verifiedName;
  final String aboutBio;
  final String address;
  final String email;
  final String website;
  final DateTime? connectedAt;
  final bool metaPartnerVerified;
  final bool canSend, signupAvailable, pinRegistered, webhookSubscribed;
  final String healthMessage;

  const MetaPartnerStatus({
    this.isPartnerManaged = false,
    this.partnerAdminEmail = 'sooftcode@gmail.com',
    this.partnerStatus = 'NOT_CONFIGURED',
    this.onboardingType = 'embedded_signup',
    this.coManagementStatus = 'none',
    this.businessPortfolioId = '',
    this.wabaId = '',
    this.phoneNumberId = '',
    this.phoneNumber = '',
    this.qualityRating = 'UNKNOWN',
    this.messagingTier = 'UNKNOWN',
    this.displayNameStatus = 'UNKNOWN',
    this.verifiedName = '',
    this.aboutBio = '',
    this.address = '',
    this.email = '',
    this.website = '',
    this.connectedAt,
    this.metaPartnerVerified = false,
    this.canSend = false,
    this.signupAvailable = false,
    this.pinRegistered = false,
    this.webhookSubscribed = false,
    this.healthMessage = '',
  });

  factory MetaPartnerStatus.fromJson(Map<String, dynamic> json) {
    DateTime? connDate;
    if (json['connectedAt'] != null) {
      try {
        connDate = DateTime.parse(json['connectedAt'].toString());
      } catch (_) {}
    }

    return MetaPartnerStatus(
      isPartnerManaged: json['isPartnerManaged'] == true,
      partnerAdminEmail:
          json['partnerAdminEmail']?.toString() ?? 'sooftcode@gmail.com',
      partnerStatus: json['partnerStatus']?.toString() ?? 'NOT_CONFIGURED',
      onboardingType: json['onboardingType']?.toString() ?? 'embedded_signup',
      coManagementStatus: json['coManagementStatus']?.toString() ?? 'none',
      businessPortfolioId: json['businessPortfolioId']?.toString() ?? '',
      wabaId: json['wabaId']?.toString() ?? '',
      phoneNumberId: json['phoneNumberId']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      qualityRating: json['qualityRating']?.toString() ?? 'UNKNOWN',
      messagingTier: json['messagingTier']?.toString() ?? 'UNKNOWN',
      displayNameStatus: json['displayNameStatus']?.toString() ?? 'UNKNOWN',
      verifiedName: json['verifiedName']?.toString() ?? '',
      aboutBio: json['aboutBio']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      connectedAt: connDate,
      metaPartnerVerified: json['metaPartnerVerified'] == true,
      canSend: json['canSend'] == true,
      signupAvailable: json['signupAvailable'] == true,
      pinRegistered: json['pinRegistered'] == true,
      webhookSubscribed: json['webhookSubscribed'] == true,
      healthMessage: json['healthMessage']?.toString() ?? '',
    );
  }
}

class MetaPartnerService {
  static final MetaPartnerService _instance = MetaPartnerService._internal();
  factory MetaPartnerService() => _instance;
  MetaPartnerService._internal();
  MetaPartnerService.forTesting();

  final ApiClient _apiClient = ApiClient();

  /// Retrieve current partner connection status and metrics
  Future<MetaPartnerStatus?> getStatus() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.metaPartnerStatus);
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>? ?? response;
        return MetaPartnerStatus.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('[MetaPartnerService] getStatus error: $e');
      rethrow;
    }
  }

  /// Connect or link merchant WABA via Partner Channel
  Future<Map<String, dynamic>?> connectWaba({
    required String wabaId,
    required String phoneNumberId,
    required String phoneNumber,
    String accessToken = '',
    String appSecret = '',
    String businessPortfolioId = '',
    String onboardingType = 'embedded_signup',
    String verifiedName = '',
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.metaPartnerConnect,
        data: {
          'wabaId': wabaId.trim(),
          'phoneNumberId': phoneNumberId.trim(),
          'phoneNumber': phoneNumber.trim(),
          'accessToken': accessToken.trim(),
          'appSecret': appSecret.trim(),
          'businessPortfolioId': businessPortfolioId.trim(),
          'onboardingType': onboardingType,
          'verifiedName': verifiedName.trim(),
        },
      );

      if (response != null && response is Map<String, dynamic>) {
        return response['data'] as Map<String, dynamic>? ?? response;
      }
      return null;
    } catch (e) {
      debugPrint('[MetaPartnerService] connectWaba error: $e');
      rethrow;
    }
  }

  /// Update WhatsApp Business Profile via Partner Channel
  Future<bool> updateProfile({
    String? verifiedName,
    String? aboutBio,
    String? address,
    String? email,
    String? website,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (verifiedName != null) body['verifiedName'] = verifiedName.trim();
      if (aboutBio != null) body['aboutBio'] = aboutBio.trim();
      if (address != null) body['address'] = address.trim();
      if (email != null) body['email'] = email.trim();
      if (website != null) body['website'] = website.trim();

      final response = await _apiClient.put(
        ApiEndpoints.metaPartnerProfile,
        data: body,
      );

      return response != null && response['success'] != false;
    } catch (e) {
      debugPrint('[MetaPartnerService] updateProfile error: $e');
      rethrow;
    }
  }

  /// Send Co-Management Invitation to merchant Business Portfolio
  Future<bool> inviteCoManagement(String businessPortfolioId) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.metaPartnerCoManage,
        data: {'businessPortfolioId': businessPortfolioId.trim()},
      );
      return response != null && response['success'] != false;
    } catch (e) {
      debugPrint('[MetaPartnerService] inviteCoManagement error: $e');
      rethrow;
    }
  }

  /// Disconnect Meta Partner Channel
  Future<bool> disconnect() async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.metaPartnerDisconnect,
      );
      return response != null && response['success'] != false;
    } catch (e) {
      debugPrint('[MetaPartnerService] disconnect error: $e');
      rethrow;
    }
  }

  /// Send real-time test WhatsApp message to verify line operability
  Future<Map<String, dynamic>?> sendTestMessage({
    required String recipientPhone,
    String? message,
    String? templateName,
    String language = 'en_US',
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.metaPartnerTestMessage,
        data: {
          'recipientPhone': recipientPhone.trim(),
          if (message != null) 'message': message.trim(),
          if (templateName != null) 'templateName': templateName.trim(),
          'language': language,
        },
      );
      if (response != null && response is Map<String, dynamic>) {
        return response['data'] as Map<String, dynamic>? ?? response;
      }
      return null;
    } catch (e) {
      debugPrint('[MetaPartnerService] sendTestMessage error: $e');
      rethrow;
    }
  }

  /// Get WhatsApp message templates (POS default fleet + Meta Cloud)
  Future<List<MetaTemplateItem>> getTemplates() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.metaPartnerTemplates);
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>? ?? response;
        final list = (data['templates'] as List?) ?? [];
        return list
            .map(
              (item) => MetaTemplateItem.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[MetaPartnerService] getTemplates error: $e');
      rethrow;
    }
  }

  /// Sync/Register default Apna POS restaurant templates with Meta
  Future<bool> syncTemplates() async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.metaPartnerTemplatesSync,
      );
      return response != null && response['success'] != false;
    } catch (e) {
      debugPrint('[MetaPartnerService] syncTemplates error: $e');
      rethrow;
    }
  }

  /// Fetch 24-hr messaging analytics and Tier usage
  Future<MetaPartnerAnalytics?> getAnalytics() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.metaPartnerAnalytics);
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>? ?? response;
        return MetaPartnerAnalytics.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('[MetaPartnerService] getAnalytics error: $e');
      rethrow;
    }
  }

  /// Exchange Embedded Signup OAuth code for permanent tokens
  Future<Map<String, dynamic>?> exchangeOAuth({
    required String code,
    required String wabaId,
    required String phoneNumberId,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.metaPartnerOAuthExchange,
        data: {
          'code': code.trim(),
          'wabaId': wabaId.trim(),
          'phoneNumberId': phoneNumberId.trim(),
        },
      );
      if (response != null && response is Map<String, dynamic>) {
        return response['data'] as Map<String, dynamic>? ?? response;
      }
      return null;
    } catch (e) {
      debugPrint('[MetaPartnerService] exchangeOAuth error: $e');
      rethrow;
    }
  }

  Future<Uri> startSignup() async {
    final response = await _apiClient.post('/meta-partner/onboarding/start');
    final data = response['data'] as Map<String, dynamic>;
    return Uri.parse(data['url'].toString());
  }

  /// Get all Meta Channels
  Future<List<MetaChannelItem>> getChannels() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.metaPartnerChannels);
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>? ?? response;
        final list = (data['channels'] as List?) ?? [];
        return list
            .map(
              (item) => MetaChannelItem.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[MetaPartnerService] getChannels error: $e');
      rethrow;
    }
  }

  /// Create New Meta Channel
  Future<MetaChannelItem?> createChannel({
    required String name,
    required String phoneNumber,
    bool isActive = true,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.metaPartnerChannels,
        data: {
          'name': name.trim(),
          'phoneNumber': phoneNumber.trim(),
          'isActive': isActive,
        },
      );
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>? ?? response;
        if (data['channel'] != null) {
          return MetaChannelItem.fromJson(
            data['channel'] as Map<String, dynamic>,
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('[MetaPartnerService] createChannel error: $e');
      rethrow;
    }
  }

  /// Register 2-Step PIN for Channel
  Future<bool> registerPin({
    required String channelId,
    required String pin,
  }) async {
    try {
      final response = await _apiClient.post(
        '${ApiEndpoints.metaPartnerChannels}/$channelId/register-pin',
        data: {'pin': pin},
      );
      return response != null && response['success'] != false;
    } catch (e) {
      debugPrint('[MetaPartnerService] registerPin error: $e');
      rethrow;
    }
  }

  /// Subscribe Webhook for Channel
  Future<bool> subscribeWebhook({required String channelId}) async {
    try {
      final response = await _apiClient.post(
        '${ApiEndpoints.metaPartnerChannels}/$channelId/subscribe-webhook',
      );
      return response != null && response['success'] != false;
    } catch (e) {
      debugPrint('[MetaPartnerService] subscribeWebhook error: $e');
      rethrow;
    }
  }

  /// Toggle Channel Active state
  Future<bool> toggleChannelActive({
    required String channelId,
    required bool isActive,
  }) async {
    try {
      final response = await _apiClient.patch(
        '${ApiEndpoints.metaPartnerChannels}/$channelId/toggle-active',
        data: {'isActive': isActive},
      );
      return response != null && response['success'] != false;
    } catch (e) {
      debugPrint('[MetaPartnerService] toggleChannelActive error: $e');
      rethrow;
    }
  }

  /// Delete Channel
  Future<bool> deleteChannel({required String channelId}) async {
    try {
      final response = await _apiClient.delete(
        '${ApiEndpoints.metaPartnerChannels}/$channelId',
      );
      return response != null && response['success'] != false;
    } catch (e) {
      debugPrint('[MetaPartnerService] deleteChannel error: $e');
      rethrow;
    }
  }
}

class MetaChannelItem {
  final String channelId;
  final String name;
  final String phoneNumber;
  final String phoneNumberId;
  final String wabaId;
  final bool isActive;
  final String status;
  final String integrationStatus;
  final bool pinRegistered;
  final bool webhookSubscribed;
  final DateTime? createdAt;

  const MetaChannelItem({
    required this.channelId,
    required this.name,
    required this.phoneNumber,
    this.phoneNumberId = '',
    this.wabaId = '',
    this.isActive = false,
    this.status = 'PENDING',
    this.integrationStatus = 'Active Meta Cloud API',
    this.pinRegistered = false,
    this.webhookSubscribed = false,
    this.createdAt,
  });

  factory MetaChannelItem.fromJson(Map<String, dynamic> json) {
    DateTime? dt;
    if (json['createdAt'] != null) {
      try {
        dt = DateTime.parse(json['createdAt'].toString());
      } catch (_) {}
    }
    return MetaChannelItem(
      channelId: json['channelId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'WhatsApp Channel',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      phoneNumberId: json['phoneNumberId']?.toString() ?? '',
      wabaId: json['wabaId']?.toString() ?? '',
      isActive: json['isActive'] == true,
      status: json['status']?.toString() ?? 'PENDING',
      integrationStatus:
          json['integrationStatus']?.toString() ?? 'Active Meta Cloud API',
      pinRegistered: json['pinRegistered'] == true,
      webhookSubscribed: json['webhookSubscribed'] == true,
      createdAt: dt,
    );
  }
}

class MetaTemplateItem {
  final String name;
  final String category;
  final String displayName;
  final String description;
  final String status;
  final String language;
  final bool isLiveSynced;

  const MetaTemplateItem({
    required this.name,
    required this.category,
    required this.displayName,
    required this.description,
    required this.status,
    required this.language,
    this.isLiveSynced = false,
  });

  factory MetaTemplateItem.fromJson(Map<String, dynamic> json) {
    return MetaTemplateItem(
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'UTILITY',
      displayName:
          json['displayName']?.toString() ?? json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNKNOWN',
      language: json['language']?.toString() ?? 'en_US',
      isLiveSynced: json['isLiveSynced'] == true,
    );
  }
}

class MetaPartnerAnalytics {
  final String qualityRating;
  final String messagingTier;
  final int dailyLimit;
  final int sentToday;
  final String deliveredRate;
  final String readRate;
  final int failedCount;
  final int activeConversations;
  final String customerServiceWindowStatus;

  const MetaPartnerAnalytics({
    this.qualityRating = 'UNKNOWN',
    this.messagingTier = 'UNKNOWN',
    this.dailyLimit = 0,
    this.sentToday = 0,
    this.deliveredRate = '?',
    this.readRate = '0%',
    this.failedCount = 0,
    this.activeConversations = 0,
    this.customerServiceWindowStatus = 'PER_CUSTOMER',
  });

  factory MetaPartnerAnalytics.fromJson(Map<String, dynamic> json) {
    return MetaPartnerAnalytics(
      qualityRating: json['qualityRating']?.toString() ?? 'UNKNOWN',
      messagingTier: json['messagingTier']?.toString() ?? 'UNKNOWN',
      dailyLimit: (json['dailyLimit'] as num?)?.toInt() ?? 0,
      sentToday: (json['sentToday'] as num?)?.toInt() ?? 0,
      deliveredRate: json['deliveredRate']?.toString() ?? '?',
      readRate: json['readRate']?.toString() ?? '0%',
      failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
      activeConversations: (json['activeConversations'] as num?)?.toInt() ?? 0,
      customerServiceWindowStatus:
          json['customerServiceWindowStatus']?.toString() ?? 'PER_CUSTOMER',
    );
  }
}
