import 'package:flutter/foundation.dart';
import '../models/coupon_model.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';

class CouponPaginatedResult {
  final List<CouponModel> coupons;
  final int total;
  final int page;
  final int totalPages;

  CouponPaginatedResult({
    required this.coupons,
    required this.total,
    required this.page,
    required this.totalPages,
  });
}

class CouponService {
  static final CouponService _instance = CouponService._internal();
  factory CouponService() => _instance;
  CouponService._internal();

  final _client = ApiClient();

  /// Fetch list of coupons with optional search, status ('active', 'inactive', 'all'), and pagination
  Future<CouponPaginatedResult> getCoupons({
    String? search,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.trim().isNotEmpty) {
        query['search'] = search.trim();
      }
      if (status != null && status.isNotEmpty && status != 'all') {
        query['status'] = status;
      }

      final res = await _client.get('/coupons', queryParameters: query);
      if (res != null && res['success'] == true) {
        List<dynamic> list = [];
        Map<String, dynamic> pagination = {};

        if (res['data'] is List) {
          list = res['data'] as List<dynamic>;
        } else if (res['data'] is Map<String, dynamic>) {
          final dataMap = res['data'] as Map<String, dynamic>;
          if (dataMap['coupons'] is List) {
            list = dataMap['coupons'] as List<dynamic>;
          }
          if (dataMap['pagination'] is Map<String, dynamic>) {
            pagination = dataMap['pagination'] as Map<String, dynamic>;
          }
        } else if (res['coupons'] is List) {
          list = res['coupons'] as List<dynamic>;
        }

        if (pagination.isEmpty && res['pagination'] is Map<String, dynamic>) {
          pagination = res['pagination'] as Map<String, dynamic>;
        }

        final coupons = list.map((e) => CouponModel.fromJson(e as Map<String, dynamic>)).toList();
        return CouponPaginatedResult(
          coupons: coupons,
          total: (pagination['total'] as num?)?.toInt() ?? coupons.length,
          page: (pagination['page'] as num?)?.toInt() ?? page,
          totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
        );
      }
      return CouponPaginatedResult(coupons: [], total: 0, page: 1, totalPages: 1);
    } catch (e) {
      debugPrint('[CouponService] getCoupons error: $e');
      rethrow;
    }
  }

  /// Create a new coupon
  Future<CouponModel> createCoupon(CouponModel coupon) async {
    try {
      final res = await _client.post('/coupons', data: coupon.toJson());
      if (res != null && res['success'] == true && res['data'] != null) {
        return CouponModel.fromJson(res['data'] as Map<String, dynamic>);
      }
      throw ApiException(message: res?['message'] ?? 'Failed to create coupon');
    } catch (e) {
      debugPrint('[CouponService] createCoupon error: $e');
      rethrow;
    }
  }

  /// Update an existing coupon
  Future<CouponModel> updateCoupon(String id, CouponModel coupon) async {
    try {
      final res = await _client.put('/coupons/$id', data: coupon.toJson());
      if (res != null && res['success'] == true && res['data'] != null) {
        return CouponModel.fromJson(res['data'] as Map<String, dynamic>);
      }
      throw ApiException(message: res?['message'] ?? 'Failed to update coupon');
    } catch (e) {
      debugPrint('[CouponService] updateCoupon error: $e');
      rethrow;
    }
  }

  /// Toggle active/inactive status
  Future<CouponModel> toggleCoupon(String id) async {
    try {
      final res = await _client.patch('/coupons/$id/toggle');
      if (res != null && res['success'] == true && res['data'] != null) {
        return CouponModel.fromJson(res['data'] as Map<String, dynamic>);
      }
      throw ApiException(message: res?['message'] ?? 'Failed to toggle coupon status');
    } catch (e) {
      debugPrint('[CouponService] toggleCoupon error: $e');
      rethrow;
    }
  }

  /// Soft delete or remove coupon
  Future<bool> deleteCoupon(String id) async {
    try {
      final res = await _client.delete('/coupons/$id');
      return res != null && res['success'] == true;
    } catch (e) {
      debugPrint('[CouponService] deleteCoupon error: $e');
      rethrow;
    }
  }

  /// Validate coupon code against live cart items & rules
  Future<CouponValidationResult> validateCoupon({
    required String code,
    required double cartSubtotal,
    String? orderType,
    String? customerId,
    List<Map<String, dynamic>>? cartItems,
  }) async {
    try {
      final res = await _client.post('/coupons/validate', data: {
        'code': code.trim().toUpperCase(),
        'cartSubtotal': cartSubtotal,
        'orderType': ?orderType,
        'customerId': ?customerId,
        'cartItems': ?cartItems,
      });

      if (res != null) {
        return CouponValidationResult.fromJson(res as Map<String, dynamic>);
      }
      return const CouponValidationResult(valid: false, message: 'Invalid response from server');
    } on ApiException catch (e) {
      return CouponValidationResult(valid: false, message: e.message);
    } catch (e) {
      return CouponValidationResult(valid: false, message: e.toString());
    }
  }

  /// Get redemptions for a specific coupon
  Future<List<CouponRedemptionModel>> getRedemptions(
    String couponId, {
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final res = await _client.get(
        '/coupons/$couponId/redemptions',
        queryParameters: {'page': page, 'limit': limit},
      );
      if (res != null && res['success'] == true) {
        List<dynamic> list = [];
        if (res['data'] is List) {
          list = res['data'] as List<dynamic>;
        } else if (res['data'] is Map<String, dynamic>) {
          final map = res['data'] as Map<String, dynamic>;
          if (map['redemptions'] is List) {
            list = map['redemptions'] as List<dynamic>;
          }
        } else if (res['redemptions'] is List) {
          list = res['redemptions'] as List<dynamic>;
        }
        return list.map((e) => CouponRedemptionModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[CouponService] getRedemptions error: $e');
      return [];
    }
  }
}
