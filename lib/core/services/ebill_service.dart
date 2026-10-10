import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class EbillEligibility {
  final bool eligible;
  final bool customerPhonePresent;
  final double walletBalance;
  final double ebillCharge;
  final String currency;
  final String? customerPhone;
  final String? customerName;
  final String? reason;

  const EbillEligibility({
    required this.eligible,
    required this.customerPhonePresent,
    required this.walletBalance,
    required this.ebillCharge,
    this.currency = 'INR',
    this.customerPhone,
    this.customerName,
    this.reason,
  });

  factory EbillEligibility.fromJson(Map<String, dynamic> json) {
    return EbillEligibility(
      eligible: json['eligible'] == true,
      customerPhonePresent: json['customerPhonePresent'] == true,
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0.0,
      ebillCharge: (json['ebillCharge'] as num?)?.toDouble() ?? 2.0,
      currency: json['currency']?.toString() ?? 'INR',
      customerPhone: json['customerPhone']?.toString(),
      customerName: json['customerName']?.toString(),
      reason: json['reason']?.toString(),
    );
  }

  double get balanceAfterSend => (walletBalance - ebillCharge).clamp(0.0, double.infinity);
}

class EbillSendResult {
  final bool success;
  final String message;
  final String? ebillId;
  final String? billId;
  final String status;
  final String deliveryStatus;
  final String? whatsappMessageId;
  final double amountCharged;
  final double walletBalance;
  final bool isDuplicate;

  const EbillSendResult({
    required this.success,
    required this.message,
    this.ebillId,
    this.billId,
    required this.status,
    required this.deliveryStatus,
    this.whatsappMessageId,
    this.amountCharged = 0.0,
    this.walletBalance = 0.0,
    this.isDuplicate = false,
  });

  factory EbillSendResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return EbillSendResult(
      success: json['success'] == true,
      message: json['message']?.toString() ?? 'eBill processed',
      ebillId: data['ebillId']?.toString(),
      billId: data['billId']?.toString(),
      status: (data['status']?.toString() ?? 'PROCESSING').toUpperCase(),
      deliveryStatus: (data['deliveryStatus']?.toString() ?? 'PENDING').toUpperCase(),
      whatsappMessageId: data['whatsappMessageId']?.toString(),
      amountCharged: (data['amountCharged'] as num?)?.toDouble() ?? 0.0,
      walletBalance: (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
      isDuplicate: data['isDuplicate'] == true,
    );
  }
}

class EbillService {
  static final EbillService _instance = EbillService._internal();
  factory EbillService() => _instance;
  EbillService._internal();

  final ApiClient _apiClient = ApiClient();

  /// Check whether the bill and business wallet are eligible for eBill
  Future<EbillEligibility> checkEligibility(String billId) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.ebillEligibility(billId));
      if (response != null && response is Map<String, dynamic>) {
        return EbillEligibility.fromJson(response);
      }
      return const EbillEligibility(
        eligible: true,
        customerPhonePresent: true,
        walletBalance: 100.0,
        ebillCharge: 2.0,
      );
    } catch (e) {
      debugPrint('[EbillService] checkEligibility error: $e');
      return EbillEligibility(
        eligible: true,
        customerPhonePresent: true,
        walletBalance: 100.0,
        ebillCharge: 2.0,
        reason: e.toString(),
      );
    }

  }

  /// Request Save & eBill via WhatsApp
  Future<EbillSendResult> sendEbill({
    required String billId,
    String? customerId,
    String? customerPhone,
    String? idempotencyKey,
  }) async {
    final payload = {
      'billId': billId,
      if (customerId != null && customerId.isNotEmpty) 'customerId': customerId,
      if (customerPhone != null && customerPhone.isNotEmpty) 'customerPhone': customerPhone,
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) 'idempotencyKey': idempotencyKey,
    };

    final response = await _apiClient.post(
      ApiEndpoints.ebillSend,
      data: payload,
    );

    if (response != null && response is Map<String, dynamic>) {
      return EbillSendResult.fromJson(response);
    }

    throw Exception('Unexpected empty response from server while sending eBill');
  }

  /// Poll eBill delivery status from WhatsApp webhook updates
  Future<Map<String, dynamic>?> getStatus(String ebillId) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.ebillStatus(ebillId));
      if (response != null && response is Map<String, dynamic> && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[EbillService] getStatus error: $e');
      return null;
    }
  }

  /// Get current business wallet balance
  Future<double?> getWalletBalance() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.walletBalance);
      if (response != null && response is Map<String, dynamic> && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        return (data['balance'] as num?)?.toDouble();
      }
      return null;
    } catch (e) {
      debugPrint('[EbillService] getWalletBalance error: $e');
      return null;
    }
  }
}
