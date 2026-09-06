import 'package:flutter/foundation.dart';
import '../models/extra_model.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../utils/order_calculator.dart';

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

  /// Validate coupon/promo code against subtotal via API or dynamic percentage parser
  Future<CouponValidationResult> validateCoupon({
    required String code,
    required double subtotal,
    List<dynamic>? availableCoupons,
  }) async {
    final cleanCode = code.trim();
    if (cleanCode.isEmpty) {
      return CouponValidationResult(
        isValid: false,
        message: 'Please enter a valid promo code or percentage (e.g. 10%, SAVE20)',
        discountAmount: 0.0,
      );
    }

    try {
      final response = await _apiClient.post(
        ApiEndpoints.validateCoupon,
        data: {
          'code': cleanCode,
          'subtotal': subtotal,
        },
      );

      if (response != null && response['data'] != null) {
        final result = CouponValidationResult.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        if (result.isValid) {
          return result;
        }
      }
    } catch (e) {
      debugPrint('[ExtraService.validateCoupon] API note: $e');
    }

    // Local dynamic percentage parsing & offline validation
    final upper = cleanCode.toUpperCase();
    final double percent = OrderCalculator.parsePromoDiscountPercent(
      cleanCode,
      availableCoupons: availableCoupons,
    );

    if (percent > 0) {
      final double discount = (subtotal * (percent / 100.0)).clamp(0.0, subtotal);
      final percentFormatted = percent.truncateToDouble() == percent
          ? percent.toStringAsFixed(0)
          : percent.toStringAsFixed(1);
      return CouponValidationResult(
        isValid: true,
        message: 'Promo "$cleanCode" applied! $percentFormatted% off (-₹${discount.toStringAsFixed(2)}) before GST',
        discountAmount: discount,
        extra: ExtraModel(
          id: 'promo_$cleanCode',
          name: cleanCode,
          code: cleanCode,
          discountType: 'percent',
          value: percent,
        ),
      );
    }

    if (upper == 'FLAT100') {
      if (subtotal >= 499) {
        final discount = 100.0.clamp(0.0, subtotal);
        return CouponValidationResult(
          isValid: true,
          message: 'Coupon "FLAT100" applied! ₹100 flat discount off before GST',
          discountAmount: discount,
          extra: ExtraModel(
            id: 'local_FLAT100',
            name: 'FLAT100',
            code: 'FLAT100',
            discountType: 'flat',
            value: 100.0,
          ),
        );
      } else {
        return CouponValidationResult(
          isValid: false,
          message: 'FLAT100 requires minimum order of ₹499',
          discountAmount: 0.0,
        );
      }
    }

    return CouponValidationResult(
      isValid: false,
      message: 'Invalid promo code. Enter a percentage (e.g. 10%, 20%) or coupon code.',
      discountAmount: 0.0,
    );
  }
}
