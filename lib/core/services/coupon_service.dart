import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_service.dart';
import '../models/coupon_model.dart';
import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'firestore_service.dart';

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
  final _firestore = FirestoreService();
  final _db = DatabaseService();

  static const String _cacheKey = 'cached_coupons_list_v2';
  List<CouponModel> _cachedCoupons = [];
  bool _isCacheLoaded = false;

  /// In-memory cached coupons list for instantaneous 0ms display
  List<CouponModel> get cachedCoupons => List.unmodifiable(_cachedCoupons);

  /// Synchronize cached coupons with Cloud Firestore for multi-device sync
  Future<void> _syncToCloud() async {
    final restId = _db.restaurant?.id;
    if (restId != null && restId.isNotEmpty) {
      try {
        await _firestore.saveCoupons(restaurantId: restId, coupons: _cachedCoupons);
      } catch (e) {
        debugPrint('[CouponService] _syncToCloud notice: $e');
      }
    }
  }

  /// Merge remote Cloud Firestore coupons into local cache for multi-device sync
  Future<void> _mergeFromCloud() async {
    final restId = _db.restaurant?.id;
    if (restId != null && restId.isNotEmpty) {
      try {
        final cloudCoupons = await _firestore.getCoupons(restId);
        if (cloudCoupons.isNotEmpty) {
          for (final c in cloudCoupons) {
            final idx = _cachedCoupons.indexWhere((existing) => existing.id == c.id || existing.code == c.code);
            if (idx != -1) {
              _cachedCoupons[idx] = c;
            } else {
              _cachedCoupons.add(c);
            }
          }
          _saveCacheToPrefs();
        }
      } catch (e) {
        debugPrint('[CouponService] _mergeFromCloud notice: $e');
      }
    }
  }

  /// Initialize local memory cache from persistent SharedPreferences
  Future<void> initCache() async {
    if (_isCacheLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cacheKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          _cachedCoupons = decoded
              .map((e) => CouponModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      _isCacheLoaded = true;
    } catch (e) {
      debugPrint('[CouponService] initCache error: $e');
      _isCacheLoaded = true;
    }
  }

  Future<void> _saveCacheToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = _cachedCoupons.map((c) {
        final m = c.toJson();
        m['id'] = c.id;
        return m;
      }).toList();
      await prefs.setString(_cacheKey, jsonEncode(rawList));
    } catch (e) {
      debugPrint('[CouponService] _saveCacheToPrefs error: $e');
    }
  }

  /// Fetch list of coupons with local caching and short network timeout
  Future<CouponPaginatedResult> getCoupons({
    String? search,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    if (!_isCacheLoaded) {
      await initCache();
    }

    // Merge any remote Firestore coupons from other logged-in devices
    await _mergeFromCloud();

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

      // Add 4-second timeout to prevent app from getting stuck or lagging
      final res = await _client
          .get('/coupons', queryParameters: query)
          .timeout(const Duration(seconds: 4));

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

        // Update local cache for default list queries
        if (page == 1 && (search == null || search.trim().isEmpty) && (status == null || status == 'all')) {
          _cachedCoupons = List.from(coupons);
          _saveCacheToPrefs();
          _syncToCloud();
        } else {
          // Merge newly fetched coupons into cache
          for (final c in coupons) {
            final idx = _cachedCoupons.indexWhere((existing) => existing.id == c.id);
            if (idx != -1) {
              _cachedCoupons[idx] = c;
            } else {
              _cachedCoupons.add(c);
            }
          }
          _saveCacheToPrefs();
          _syncToCloud();
        }

        return CouponPaginatedResult(
          coupons: coupons,
          total: (pagination['total'] as num?)?.toInt() ?? coupons.length,
          page: (pagination['page'] as num?)?.toInt() ?? page,
          totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
        );
      }
      return CouponPaginatedResult(coupons: [], total: 0, page: 1, totalPages: 1);
    } catch (e) {
      debugPrint('[CouponService] getCoupons network fetch failed or timed out: $e');
      // If we have cached coupons, fallback immediately to offline cache instead of failing or getting stuck
      if (_cachedCoupons.isNotEmpty) {
        var filtered = List<CouponModel>.from(_cachedCoupons);
        if (search != null && search.trim().isNotEmpty) {
          final q = search.trim().toLowerCase();
          filtered = filtered.where((c) =>
              c.code.toLowerCase().contains(q) ||
              c.title.toLowerCase().contains(q) ||
              c.description.toLowerCase().contains(q)).toList();
        }
        if (status != null && status.isNotEmpty && status != 'all') {
          if (status == 'active') {
            filtered = filtered.where((c) => c.isActive && !c.isExpired).toList();
          } else if (status == 'inactive') {
            filtered = filtered.where((c) => !c.isActive).toList();
          }
        }
        return CouponPaginatedResult(
          coupons: filtered,
          total: filtered.length,
          page: page,
          totalPages: 1,
        );
      }
      // If no cache, return empty result gracefully so UI does not get stuck
      return CouponPaginatedResult(coupons: [], total: 0, page: 1, totalPages: 1);
    }
  }

  /// Create a new coupon
  Future<CouponModel> createCoupon(CouponModel coupon) async {
    try {
      final res = await _client
          .post('/coupons', data: coupon.toJson())
          .timeout(const Duration(seconds: 5));
      if (res != null && res['success'] == true && res['data'] != null) {
        final created = CouponModel.fromJson(res['data'] as Map<String, dynamic>);
        _cachedCoupons.removeWhere((c) => c.id == created.id || c.code == created.code);
        _cachedCoupons.insert(0, created);
        _saveCacheToPrefs();
        _syncToCloud();
        return created;
      }
      throw ApiException(message: res?['message'] ?? 'Failed to create coupon');
    } catch (e) {
      debugPrint('[CouponService] createCoupon error: $e');
      if (e is! ApiException) {
        final localCoupon = coupon.copyWith(
          id: coupon.id.isNotEmpty ? coupon.id : 'local_${DateTime.now().millisecondsSinceEpoch}',
        );
        _cachedCoupons.removeWhere((c) => c.code == localCoupon.code);
        _cachedCoupons.insert(0, localCoupon);
        _saveCacheToPrefs();
        _syncToCloud();
        return localCoupon;
      }
      rethrow;
    }
  }

  /// Update an existing coupon
  Future<CouponModel> updateCoupon(String id, CouponModel coupon) async {
    try {
      final res = await _client
          .put('/coupons/$id', data: coupon.toJson())
          .timeout(const Duration(seconds: 5));
      if (res != null && res['success'] == true && res['data'] != null) {
        final updated = CouponModel.fromJson(res['data'] as Map<String, dynamic>);
        final idx = _cachedCoupons.indexWhere((c) => c.id == id || c.id == updated.id);
        if (idx != -1) {
          _cachedCoupons[idx] = updated;
        } else {
          _cachedCoupons.insert(0, updated);
        }
        _saveCacheToPrefs();
        _syncToCloud();
        return updated;
      }
      throw ApiException(message: res?['message'] ?? 'Failed to update coupon');
    } catch (e) {
      debugPrint('[CouponService] updateCoupon error: $e');
      if (e is! ApiException) {
        final idx = _cachedCoupons.indexWhere((c) => c.id == id);
        if (idx != -1) {
          _cachedCoupons[idx] = coupon;
          _saveCacheToPrefs();
          _syncToCloud();
          return coupon;
        }
      }
      rethrow;
    }
  }

  /// Toggle active/inactive status
  Future<CouponModel> toggleCoupon(String id) async {
    try {
      final res = await _client
          .patch('/coupons/$id/toggle')
          .timeout(const Duration(seconds: 4));
      if (res != null && res['success'] == true && res['data'] != null) {
        final updated = CouponModel.fromJson(res['data'] as Map<String, dynamic>);
        final idx = _cachedCoupons.indexWhere((c) => c.id == id);
        if (idx != -1) {
          _cachedCoupons[idx] = updated;
          _saveCacheToPrefs();
          _syncToCloud();
        }
        return updated;
      }
      throw ApiException(message: res?['message'] ?? 'Failed to toggle coupon status');
    } catch (e) {
      debugPrint('[CouponService] toggleCoupon error: $e');
      final idx = _cachedCoupons.indexWhere((c) => c.id == id);
      if (idx != -1) {
        final toggled = _cachedCoupons[idx].copyWith(isActive: !_cachedCoupons[idx].isActive);
        _cachedCoupons[idx] = toggled;
        _saveCacheToPrefs();
        _syncToCloud();
        return toggled;
      }
      rethrow;
    }
  }

  /// Soft delete or remove coupon
  Future<bool> deleteCoupon(String id) async {
    _cachedCoupons.removeWhere((c) => c.id == id);
    _saveCacheToPrefs();
    _syncToCloud();
    try {
      final res = await _client
          .delete('/coupons/$id')
          .timeout(const Duration(seconds: 4));
      return res != null && res['success'] == true;
    } catch (e) {
      debugPrint('[CouponService] deleteCoupon error: $e');
      return true;
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
      }).timeout(const Duration(seconds: 4));

      if (res != null) {
        return CouponValidationResult.fromJson(res as Map<String, dynamic>);
      }
      return const CouponValidationResult(valid: false, message: 'Invalid response from server');
    } on ApiException catch (e) {
      return CouponValidationResult(valid: false, message: e.message);
    } catch (e) {
      debugPrint('[CouponService] validateCoupon network error ($e), checking local cache');
      // Offline fallback validation from local cache
      final found = _cachedCoupons.where((c) => c.code.toUpperCase() == code.trim().toUpperCase()).firstOrNull;
      if (found != null && found.isActive && !found.isExpired) {
        if (found.minCartAmount > 0 && cartSubtotal < found.minCartAmount) {
          return CouponValidationResult(
            valid: false,
            message: 'Minimum order amount of ₹${found.minCartAmount.toStringAsFixed(0)} required',
          );
        }
        double discount = 0.0;
        if (found.isPercentage) {
          discount = (cartSubtotal * found.discountValue) / 100.0;
          if (found.maxDiscountAmount != null && found.maxDiscountAmount! > 0) {
            discount = discount > found.maxDiscountAmount! ? found.maxDiscountAmount! : discount;
          }
        } else {
          discount = found.discountValue > cartSubtotal ? cartSubtotal : found.discountValue;
        }
        return CouponValidationResult(
          valid: true,
          code: found.code,
          discountAmount: discount,
          discountType: found.discountType,
          discountValue: found.discountValue,
          message: 'Coupon applied successfully',
          coupon: found,
        );
      }
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
      ).timeout(const Duration(seconds: 4));
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