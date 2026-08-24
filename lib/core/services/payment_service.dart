import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class PaymentQrResult {
  final bool success;
  final bool isDynamicGateway;
  final String gateway;
  final String qrId;
  final String qrImageUrl;
  final String qrIntentUrl;
  final double amount;
  final String orderNumber;
  final String orderId;
  final DateTime? expiresAt;

  PaymentQrResult({
    required this.success,
    required this.isDynamicGateway,
    required this.gateway,
    required this.qrId,
    required this.qrImageUrl,
    required this.qrIntentUrl,
    required this.amount,
    required this.orderNumber,
    required this.orderId,
    this.expiresAt,
  });

  factory PaymentQrResult.fromJson(Map<String, dynamic> json) {
    DateTime? parsedExpiry;
    if (json['expiresAt'] != null) {
      parsedExpiry = DateTime.tryParse(json['expiresAt'].toString());
    }

    return PaymentQrResult(
      success: json['success'] ?? true,
      isDynamicGateway: json['isDynamicGateway'] ?? false,
      gateway: json['gateway']?.toString() ?? 'standard_upi',
      qrId: json['qrId']?.toString() ?? '',
      qrImageUrl: json['qrImageUrl']?.toString() ?? '',
      qrIntentUrl: json['qrIntentUrl']?.toString() ?? '',
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      orderNumber: json['orderNumber']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      expiresAt: parsedExpiry,
    );
  }
}

class PaymentStatusResult {
  final bool isPaid;
  final String paymentStatus;
  final String? utr;
  final String? paymentId;
  final String? orderNumber;
  final double? totalAmount;

  PaymentStatusResult({
    required this.isPaid,
    required this.paymentStatus,
    this.utr,
    this.paymentId,
    this.orderNumber,
    this.totalAmount,
  });

  factory PaymentStatusResult.fromJson(Map<String, dynamic> json) {
    return PaymentStatusResult(
      isPaid: json['isPaid'] == true ||
          json['paymentStatus'] == 'paid' ||
          json['paymentStatus'] == 'completed',
      paymentStatus: json['paymentStatus']?.toString() ?? 'pending',
      utr: json['utr']?.toString(),
      paymentId: json['paymentId']?.toString(),
      orderNumber: json['orderNumber']?.toString(),
      totalAmount: (json['totalAmount'] is num) ? (json['totalAmount'] as num).toDouble() : null,
    );
  }
}

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final ApiClient _apiClient = ApiClient();

  /// Request a dynamic Razorpay UPI QR code or standard UPI intent URL for an order
  Future<PaymentQrResult> generatePaymentQr({
    required String orderId,
    required String orderNumber,
    required double amount,
    String? customerName,
    String? customerPhone,
  }) async {
    try {
      final payload = {
        'orderId': orderId,
        'orderNumber': orderNumber,
        'amount': amount,
        'customerName': customerName ?? '',
        'customerPhone': customerPhone ?? '',
      };

      final response = await _apiClient.post(
        ApiEndpoints.createPaymentQr,
        data: payload,
      );

      if (response != null && response['success'] == true && response['data'] != null) {
        return PaymentQrResult.fromJson(response['data'] as Map<String, dynamic>);
      }

      throw Exception(response?['error']?['message'] ?? 'Failed to generate UPI QR from server');
    } catch (e) {
      debugPrint('[PaymentService.generatePaymentQr] Error: $e');
      rethrow;
    }
  }

  /// Real-time polling verification of payment status for an active order
  Future<PaymentStatusResult> checkPaymentStatus(String orderId) async {
    try {
      final response = await _apiClient.get(
        '${ApiEndpoints.paymentStatus}/$orderId',
      );

      if (response != null && response['success'] == true && response['data'] != null) {
        return PaymentStatusResult.fromJson(response['data'] as Map<String, dynamic>);
      }

      return PaymentStatusResult(isPaid: false, paymentStatus: 'pending');
    } catch (e) {
      debugPrint('[PaymentService.checkPaymentStatus] Error: $e');
      return PaymentStatusResult(isPaid: false, paymentStatus: 'pending');
    }
  }
}
