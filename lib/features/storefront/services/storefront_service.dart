import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/restaurant_model.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/extra_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/services/firestore_service.dart';
import '../models/storefront_model.dart';
import 'storefront_order_service.dart';

class StorefrontService {
  static final StorefrontService _instance = StorefrontService._internal();
  factory StorefrontService() => _instance;
  StorefrontService._internal();

  final DatabaseService _db = DatabaseService();
  final ApiClient _apiClient = ApiClient();
  final Map<String, String> _categoryCache = {};

  String? getCachedCategory(String slug) =>
      _categoryCache[slug.trim().toLowerCase()];

  void cacheCategory(String slug, String category) {
    if (slug.isNotEmpty && category.isNotEmpty) {
      _categoryCache[slug.trim().toLowerCase()] = category.trim();
    }
  }

  final Map<String, StorefrontData> _brandCache = {};
  StorefrontData? cachedStorefront(String slug) =>
      _brandCache[slug.trim().toLowerCase()];
  Future<RestaurantModel> loadBranding(String slug) async {
    final response = await _apiClient.get(
      ApiEndpoints.storefront(slug.trim().toLowerCase()),
      queryParameters: {'brandingOnly': 'true'},
    );
    final json = Map<String, dynamic>.from(
      response['data']['restaurant'] as Map,
    );
    return RestaurantModel.fromJson({
      ...json,
      'openingTime': json['openingTime'] ?? '',
      'closingTime': json['closingTime'] ?? '',
      'likesCount': 0,
    });
  }

  /// Public storefronts always load from their own API. Local data is preview-only or offline backup.
  Future<StorefrontData> loadStorefront(
    String slug, {
    String? tableCode,
    String? restaurantCode,
    bool preview = false,
  }) async {
    final cleanSlug = slug.trim().toLowerCase();
    final local = _db.restaurant;
    final bool isLocalMatch = local != null &&
        (preview ||
            cleanSlug == 'preview' ||
            cleanSlug == local.storefrontSlug.trim().toLowerCase() ||
            cleanSlug == local.id.trim().toLowerCase() ||
            cleanSlug ==
                local.name
                    .trim()
                    .toLowerCase()
                    .replaceAll(RegExp(r'[^a-z0-9]+'), '-'));

    // Fast local resolve for merchant in-app previews
    if (preview && local != null) {
      StorefrontTableInfo? previewTable;
      if (tableCode != null && tableCode.trim().isNotEmpty) {
        final cleanTable = tableCode.trim().toUpperCase();
        final parsedNum =
            int.tryParse(cleanTable.replaceAll(RegExp(r'[^0-9]'), ''));
        final matched = _db.tables
            .where(
              (t) =>
                  (parsedNum != null && t.tableNumber == parsedNum) ||
                  cleanTable == 'T${t.tableNumber.toString().padLeft(2, '0')}' ||
                  t.name.toUpperCase().replaceAll(' ', '') ==
                      cleanTable.replaceAll(' ', ''),
            )
            .firstOrNull;
        final totalTables = _db.tables.isNotEmpty ? _db.tables.length : 20;
        previewTable = StorefrontTableInfo(
          isValid: true,
          tableCode: cleanTable,
          tableNumber: matched?.tableNumber ?? parsedNum ?? 1,
          name: matched?.name ?? 'Table ${parsedNum ?? 1}',
          floor: matched?.floor ?? 'Ground Floor',
          capacity: matched?.capacity ?? 4,
          isTableOrdering: true,
          restaurantCode: restaurantCode ?? 'R1',
          totalTables: totalTables,
        );
      }

      final data = StorefrontData(
        restaurant: local,
        categories: ['All', ..._db.categories.where((c) => c != 'All')],
        menuItems: List.of(_db.menuItems),
        addOns: List.of(_db.extras),
        banners: _db.storefrontBanners.where((b) => b.isActive).toList(),
        isOnline: _db.isStorefrontOnline,
        themeColorHex: _db.storefrontThemeColor,
        themeColorEndHex: _db.storefrontThemeColorEnd,
        tableInfo: previewTable,
      );
      return data;
    }

    // 1. Primary: Fetch live data from backend
    try {
      final response = await _apiClient.get(
        ApiEndpoints.storefront(cleanSlug),
        queryParameters: {
          if (tableCode?.trim().isNotEmpty == true) 'T': tableCode!.trim(),
          if (restaurantCode?.trim().isNotEmpty == true)
            'R': restaurantCode!.trim(),
        },
      );
      if (response['data'] is! Map) {
        throw StateError('The restaurant menu is unavailable.');
      }
      final json = Map<String, dynamic>.from(response['data'] as Map);
      if (json['restaurant'] is! Map) {
        throw StateError('Restaurant profile is missing.');
      }
      final profile = Map<String, dynamic>.from(json['restaurant'] as Map);
      profile['openingTime'] ??= '';
      profile['closingTime'] ??= '';
      profile['likesCount'] ??= 0;
      final restaurant = RestaurantModel.fromJson(profile);
      final items = (json['products'] as List? ?? [])
          .whereType<Map>()
          .map(
            (item) => MenuItemModel.fromJson({
              ...Map<String, dynamic>.from(item),
              'rating': item['rating'] ?? 0,
            }),
          )
          .toList();
      final categories = (json['categories'] as List? ?? [])
          .map((c) => c.toString())
          .where((c) => c.trim().isNotEmpty && c != 'All')
          .toSet();
      categories.addAll(
        items.map((item) => item.category).where((c) => c.trim().isNotEmpty),
      );
      final data = StorefrontData(
        restaurant: restaurant,
        categories: ['All', ...categories],
        menuItems: items,
        addOns: (json['addons'] as List? ?? [])
            .whereType<Map>()
            .map((a) => ExtraModel.fromJson(Map<String, dynamic>.from(a)))
            .toList(),
        banners:
            (json['banners'] as List? ?? [])
                .whereType<Map>()
                .map(
                  (b) =>
                      StorefrontBanner.fromJson(Map<String, dynamic>.from(b)),
                )
                .where((b) => b.isActive)
                .toList()
              ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)),
        isOnline: json['isOnline'] as bool? ?? restaurant.isStorefrontOnline,
        themeColorHex:
            (json['themeColorHex'] as num?)?.toInt() ??
            restaurant.storefrontThemeColor,
        themeColorEndHex:
            (json['themeColorEndHex'] as num?)?.toInt() ??
            restaurant.storefrontThemeColorEnd,
        tableInfo: json['table'] is Map
            ? StorefrontTableInfo.fromJson(
                Map<String, dynamic>.from(json['table'] as Map),
              )
            : null,
        rating: (profile['rating'] as num?)?.toDouble(),
        reviewCount: profile['reviewCount']?.toString() ?? '',
        deliveryEta: json['deliveryEta']?.toString() ?? '',
        pickupEta: json['pickupEta']?.toString() ?? '',
      );
      _brandCache[cleanSlug] = data;
      if (_brandCache.length > 16) _brandCache.remove(_brandCache.keys.first);
      cacheCategory(cleanSlug, restaurant.cuisineType);
      return data;
    } catch (apiError) {
      debugPrint('[StorefrontService] Primary API error: $apiError');

      // Fallback 1: Memory cache
      if (_brandCache.containsKey(cleanSlug)) {
        debugPrint('[StorefrontService] Serving from memory brand cache for $cleanSlug');
        return _brandCache[cleanSlug]!;
      }

      // Fallback 2: Local POS database
      if (isLocalMatch && local != null) {
        debugPrint('[StorefrontService] Serving from local POS database for $cleanSlug');
        StorefrontTableInfo? fallbackTable;
        if (tableCode != null && tableCode.trim().isNotEmpty) {
          final cleanTable = tableCode.trim().toUpperCase();
          final parsedNum =
              int.tryParse(cleanTable.replaceAll(RegExp(r'[^0-9]'), ''));
          fallbackTable = StorefrontTableInfo(
            isValid: true,
            tableCode: cleanTable,
            tableNumber: parsedNum ?? 1,
            name: 'Table ${parsedNum ?? 1}',
            floor: 'Ground Floor',
            capacity: 4,
            isTableOrdering: true,
            restaurantCode: restaurantCode ?? 'R1',
            totalTables: _db.tables.isNotEmpty ? _db.tables.length : 20,
          );
        }
        return StorefrontData(
          restaurant: local,
          categories: ['All', ..._db.categories.where((c) => c != 'All')],
          menuItems: List.of(_db.menuItems),
          addOns: List.of(_db.extras),
          banners: _db.storefrontBanners.where((b) => b.isActive).toList(),
          isOnline: _db.isStorefrontOnline,
          themeColorHex: _db.storefrontThemeColor,
          themeColorEndHex: _db.storefrontThemeColorEnd,
          tableInfo: fallbackTable,
        );
      }

      // Fallback 3: Cloud Firestore
      try {
        debugPrint('[StorefrontService] Attempting Firestore fallback for $cleanSlug');
        final firestoreRest =
            await FirestoreService().getRestaurantBySlug(cleanSlug);
        if (firestoreRest != null) {
          final menuData =
              await FirestoreService().getStorefrontMenu(firestoreRest.id);
          final rawItems = (menuData?['items'] as List? ?? []);
          final items = rawItems
              .whereType<Map>()
              .map((m) => MenuItemModel.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          final cats = (menuData?['categories'] as List? ?? [])
              .map((c) => c.toString())
              .where((c) => c.trim().isNotEmpty && c != 'All')
              .toSet();
          cats.addAll(items.map((i) => i.category).where((c) => c.trim().isNotEmpty));
          final banners =
              await FirestoreService().getStorefrontBanners(firestoreRest.id);
          final settings =
              await FirestoreService().getStorefrontSettings(firestoreRest.id);

          StorefrontTableInfo? tableInfo;
          if (tableCode != null && tableCode.trim().isNotEmpty) {
            final cleanTable = tableCode.trim().toUpperCase();
            final parsedNum =
                int.tryParse(cleanTable.replaceAll(RegExp(r'[^0-9]'), ''));
            tableInfo = StorefrontTableInfo(
              isValid: true,
              tableCode: cleanTable,
              tableNumber: parsedNum ?? 1,
              name: 'Table ${parsedNum ?? 1}',
              floor: 'Ground Floor',
              capacity: 4,
              isTableOrdering: true,
              restaurantCode: restaurantCode ?? 'R1',
              totalTables:
                  firestoreRest.tableCount > 0 ? firestoreRest.tableCount : 20,
            );
          }

          final data = StorefrontData(
            restaurant: firestoreRest,
            categories: ['All', ...cats],
            menuItems: items,
            addOns: const [],
            banners: banners,
            isOnline:
                settings?['isStorefrontOnline'] as bool? ??
                firestoreRest.isStorefrontOnline,
            themeColorHex:
                (settings?['storefrontThemeColor'] as num?)?.toInt() ??
                firestoreRest.storefrontThemeColor,
            themeColorEndHex:
                (settings?['storefrontThemeColorEnd'] as num?)?.toInt() ??
                firestoreRest.storefrontThemeColorEnd,
            tableInfo: tableInfo,
          );
          _brandCache[cleanSlug] = data;
          return data;
        }
      } catch (firestoreError) {
        debugPrint(
          '[StorefrontService] Firestore fallback error: $firestoreError',
        );
      }

      rethrow;
    }
  }

  /// Submit customer online order
  Future<bool> submitOrder({
    required RestaurantModel restaurant,
    required OrderType orderType,
    required List<StorefrontCartItem> cartItems,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required double subtotal,
    required double taxAmount,
    required double deliveryFee,
    required double totalAmount,
    required String paymentMethod,
    String specialNote = '',
    String? tableNumber,
  }) async {
    final orderNumber =
        'ONL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final nowIso = DateTime.now().toIso8601String();
    final bool isDineIn =
        orderType == OrderType.dineIn ||
        (tableNumber != null && tableNumber.trim().isNotEmpty);
    final bool resolvedIsPaid = isDineIn ? false : (paymentMethod == 'UPI');
    final String resolvedPaymentStatus = isDineIn
        ? 'pending'
        : (resolvedIsPaid ? 'paid' : 'pending');
    final String resolvedPaymentMethod = isDineIn
        ? 'Pay at Counter / Table'
        : paymentMethod;

    final order = OrderModel(
      id: 'ord_onl_${DateTime.now().millisecondsSinceEpoch}',
      orderNumber: orderNumber,
      orderType: isDineIn ? OrderType.dineIn : orderType,
      tableNumber: tableNumber?.trim(),
      status: OrderStatus.pending,
      items: cartItems.map((c) => c.toCartItemModel()).toList(),
      subtotal: subtotal,
      taxAmount: taxAmount,
      deliveryCharge: isDineIn ? 0.0 : deliveryFee,
      totalAmount: totalAmount,
      paymentMethod: resolvedPaymentMethod,
      paymentStatus: resolvedPaymentStatus,
      isPaid: resolvedIsPaid,
      deliveryAddress: orderType == OrderType.delivery
          ? deliveryAddress
          : (isDineIn ? 'Table ${tableNumber?.trim() ?? "Dine-In"}' : null),
      createdAt: nowIso,
      customerName: customerName,
      customerPhone: customerPhone,
      orderSource: 'storefront',
    );

    try {
      final savedOrder = await StorefrontOrderService().submit(order, restaurant, notes: specialNote);
      await _db.placeOnlineStorefrontOrder(savedOrder, skipFirestoreSync: true, showIncomingAlert: false);
      return true;
    } catch (error) {
      debugPrint('[StorefrontService] Restaurant order submission failed: $error');
      return false;
    }
  }
}
