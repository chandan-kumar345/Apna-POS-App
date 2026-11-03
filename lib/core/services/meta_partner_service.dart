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
    this.qualityRating = 'GREEN',
    this.messagingTier = 'TIER_1K',
    this.displayNameStatus = 'APPROVED',
    this.verifiedName = '',
    this.aboutBio = '',
    this.address = '',
    this.email = '',
    this.website = '',
    this.connectedAt,
    this.metaPartnerVerified = true,
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
      partnerAdminEmail: json['partnerAdminEmail']?.toString() ?? 'sooftcode@gmail.com',
      partnerStatus: json['partnerStatus']?.toString() ?? 'NOT_CONFIGURED',
      onboardingType: json['onboardingType']?.toString() ?? 'embedded_signup',
      coManagementStatus: json['coManagementStatus']?.toString() ?? 'none',
      businessPortfolioId: json['businessPortfolioId']?.toString() ?? '',
      wabaId: json['wabaId']?.toString() ?? '',
      phoneNumberId: json['phoneNumberId']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      qualityRating: json['qualityRating']?.toString() ?? 'GREEN',
      messagingTier: json['messagingTier']?.toString() ?? 'TIER_1K',
      displayNameStatus: json['displayNameStatus']?.toString() ?? 'APPROVED',
      verifiedName: json['verifiedName']?.toString() ?? '',
      aboutBio: json['aboutBio']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      connectedAt: connDate,
      metaPartnerVerified: json['metaPartnerVerified'] != false,
    );
  }
}

class MetaPartnerService {
  static final MetaPartnerService _instance = MetaPartnerService._internal();
  factory MetaPartnerService() => _instance;
  MetaPartnerService._internal();

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
      return null;
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
      return null;
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
      return false;
    }
  }

  /// Send Co-Management Invitation to merchant Business Portfolio
  Future<bool> inviteCoManagement(String businessPortfolioId) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.metaPartnerCoManage,
        data: {
          'businessPortfolioId': businessPortfolioId.trim(),
        },
      );
      return response != null && response['success'] != false;
    } catch (e) {
      debugPrint('[MetaPartnerService] inviteCoManagement error: $e');
      return false;
    }
  }

  /// Disconnect Meta Partner Channel
  Future<bool> disconnect() async {
    try {
      final response = await _apiClient.post(ApiEndpoints.metaPartnerDisconnect);
      return response != null && response['success'] != false;
    } catch (e) {
      debugPrint('[MetaPartnerService] disconnect error: $e');
      return false;
    }
  }

  /// Send real-time test WhatsApp message to verify line operability
  Future<Map<String, dynamic>?> sendTestMessage({
    required String recipientPhone,
    String? message,
    String? templateName,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.metaPartnerTestMessage,
        data: {
          'recipientPhone': recipientPhone.trim(),
          if (message != null) 'message': message.trim(),
          if (templateName != null) 'templateName': templateName.trim(),
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
        return list.map((item) => MetaTemplateItem.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[MetaPartnerService] getTemplates error: $e');
      return [];
    }
  }

  /// Sync/Register default Apna POS restaurant templates with Meta
  Future<bool> syncTemplates() async {
    try {
      final response = await _apiClient.post(ApiEndpoints.metaPartnerTemplatesSync);
      return response != null && response['success'] != false;
    } catch (e) {
      debugPrint('[MetaPartnerService] syncTemplates error: $e');
      return false;
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
      return null;
    }
  }

  /// Exchange Embedded Signup OAuth code for permanent tokens
  Future<Map<String, dynamic>?> exchangeOAuth({
    required String code,
    String businessPortfolioId = '',
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.metaPartnerOAuthExchange,
        data: {
          'code': code.trim(),
          'businessPortfolioId': businessPortfolioId.trim(),
        },
      );
      if (response != null && response is Map<String, dynamic>) {
        return response['data'] as Map<String, dynamic>? ?? response;
      }
      return null;
    } catch (e) {
      debugPrint('[MetaPartnerService] exchangeOAuth error: $e');
      return null;
    }
  }

  /// Get all Meta Channels
  Future<List<MetaChannelItem>> getChannels() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.metaPartnerChannels);
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>? ?? response;
        final list = (data['channels'] as List?) ?? [];
        return list.map((item) => MetaChannelItem.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[MetaPartnerService] getChannels error: $e');
      return [];
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
          return MetaChannelItem.fromJson(data['channel'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[MetaPartnerService] createChannel error: $e');
      rethrow;
    }
  }

  /// Register 2-Step PIN for Channel
  Future<bool> registerPin({required String channelId, String pin = '123456'}) async {
    try {
      final response = await _apiClient.post(
        '${ApiEndpoints.metaPartnerChannels}/$channelId/register-pin',
        data: {'pin': pin},
      );
      return response != null && response['success'] != false;
    } catch (e) {
      debugPrint('[MetaPartnerService] registerPin error: $e');
      return false;
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
      return false;
    }
  }

  /// Toggle Channel Active state
  Future<bool> toggleChannelActive({required String channelId, required bool isActive}) async {
    try {
      final response = await _apiClient.patch(
        '${ApiEndpoints.metaPartnerChannels}/$channelId/toggle-active',
        data: {'isActive': isActive},
      );
      return response != null && response['success'] != false;
    } catch (e) {
      debugPrint('[MetaPartnerService] toggleChannelActive error: $e');
      return false;
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
      return false;
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
    this.isActive = true,
    this.status = 'ACTIVE',
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
      isActive: json['isActive'] != false,
      status: json['status']?.toString() ?? 'ACTIVE',
      integrationStatus: json['integrationStatus']?.toString() ?? 'Active Meta Cloud API',
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
      displayName: json['displayName']?.toString() ?? json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'APPROVED',
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
    this.qualityRating = 'GREEN',
    this.messagingTier = 'TIER_1K',
    this.dailyLimit = 1000,
    this.sentToday = 0,
    this.deliveredRate = '100%',
    this.readRate = '0%',
    this.failedCount = 0,
    this.activeConversations = 0,
    this.customerServiceWindowStatus = 'OPEN',
  });

  factory MetaPartnerAnalytics.fromJson(Map<String, dynamic> json) {
    return MetaPartnerAnalytics(
      qualityRating: json['qualityRating']?.toString() ?? 'GREEN',
      messagingTier: json['messagingTier']?.toString() ?? 'TIER_1K',
      dailyLimit: (json['dailyLimit'] as num?)?.toInt() ?? 1000,
      sentToday: (json['sentToday'] as num?)?.toInt() ?? 0,
      deliveredRate: json['deliveredRate']?.toString() ?? '100%',
      readRate: json['readRate']?.toString() ?? '0%',
      failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
      activeConversations: (json['activeConversations'] as num?)?.toInt() ?? 0,
      customerServiceWindowStatus: json['customerServiceWindowStatus']?.toString() ?? 'OPEN',
    );
  }
}
