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
}
