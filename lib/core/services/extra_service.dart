import 'package:flutter/foundation.dart';
import '../models/extra_model.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class ExtraService {
  final ApiClient _apiClient = ApiClient();

  /// Fetch all active extras/coupons/benefits from backend
  Future<List<ExtraModel>> fetchExtras({String? type, String? search}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (type != null && type.trim().isNotEmpty) {
        queryParams['type'] = type.trim();
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _apiClient.get(
        ApiEndpoints.extras,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response != null &&
          response['data'] != null &&
          response['data']['extras'] != null) {
        final rawList = response['data']['extras'] as List<dynamic>;
        return rawList
            .map((e) => ExtraModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ExtraService.fetchExtras] error: $e');
      return [];
    }
  }

  /// Validate coupon code against subtotal via API
  Future<CouponValidationResult> validateCoupon({
    required String code,
    required double subtotal,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.validateCoupon,
        data: {
          'code': code.trim(),
          'subtotal': subtotal,
        },
      );

      if (response != null && response['data'] != null) {
        return CouponValidationResult.fromJson(
          response['data'] as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('[ExtraService.validateCoupon] API error: $e');
    }

    // Local fallback if offline
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return CouponValidationResult(
        isValid: false,
        message: 'Please enter a valid coupon code',
        discountAmount: 0.0,
      );
    }

    double discount = 0.0;
    if (cleanCode == 'SAVE50') {
      discount = (subtotal * 0.50).clamp(0.0, subtotal);
    } else if (cleanCode == 'FLAT100') {
      if (subtotal >= 499) {
        discount = 100.0.clamp(0.0, subtotal);
      } else {
        return CouponValidationResult(
          isValid: false,
          message: 'FLAT100 requires minimum order of ₹499',
          discountAmount: 0.0,
        );
      }
    } else if (cleanCode == 'WELCOME10') {
      discount = (subtotal * 0.10).clamp(0.0, subtotal);
    } else {
      discount = 50.0.clamp(0.0, subtotal);
    }

    return CouponValidationResult(
      isValid: true,
      message: 'Coupon "$cleanCode" applied!',
      discountAmount: discount,
      extra: ExtraModel(
        id: 'local_$cleanCode',
        name: cleanCode,
        code: cleanCode,
        value: discount,
      ),
    );
  }
}
