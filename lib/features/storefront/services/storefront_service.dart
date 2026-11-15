import 'package:flutter/foundation.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/restaurant_model.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/extra_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/storefront_model.dart';

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

  /// Public storefronts always load from their own API. Local data is preview-only.
  Future<StorefrontData> loadStorefront(
    String slug, {
    String? tableCode,
    String? restaurantCode,
    bool preview = false,
  }) async {
    final cleanSlug = slug.trim().toLowerCase();
    final local = _db.restaurant;
    if (preview &&
        local != null &&
        (cleanSlug == 'preview' ||
            cleanSlug == local.storefrontSlug.toLowerCase() ||
            cleanSlug == local.id.toLowerCase())) {
      final localBanners = _db.storefrontBanners.where((b) => b.isActive).toList();
      final data = StorefrontData(
        restaurant: local,
        categories: ['All', ..._db.categories.where((c) => c != 'All')],
        menuItems: List.of(_db.menuItems),
        addOns: List.of(_db.extras),
        banners: localBanners.isNotEmpty
            ? localBanners
            : [
                StorefrontBanner(
                  id: 'banner_local_default',
                  tag: 'SUPER SAVER COMBO',
                  headline: 'COMBO DELIGHT BOX',
                  subtitle: '${_db.menuItems.isNotEmpty ? _db.menuItems.first.name : "Pizza + Fries + Drink"} at exclusive prices',
                  ctaText: 'GRAB COMBO',
                  imageUrl: _db.menuItems.isNotEmpty ? _db.menuItems.first.imageUrl : '',
                  accentColorHex: _db.storefrontThemeColor,
                  couponCode: 'COMBO100',
                  discountText: 'FLAT ₹100 OFF',
                ),
              ],
        isOnline: _db.isStorefrontOnline,
        themeColorHex: _db.storefrontThemeColor,
        themeColorEndHex: _db.storefrontThemeColorEnd,
        rating: 4.6,
        reviewCount: '1.2k+',
        deliveryEta: '25–35 mins',
        pickupEta: '15–20 mins',
      );
      return data;
    }
    final response = await _apiClient.get(
      ApiEndpoints.storefront(cleanSlug),
      queryParameters: {
        if (tableCode?.trim().isNotEmpty == true) 'T': tableCode!.trim(),
        if (restaurantCode?.trim().isNotEmpty == true)
          'R': restaurantCode!.trim(),
      },
    );
    if (response['data'] is! Map)
      throw StateError('The restaurant menu is unavailable.');
    final json = Map<String, dynamic>.from(response['data'] as Map);
    if (json['restaurant'] is! Map)
      throw StateError('Restaurant profile is missing.');
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
                (b) => StorefrontBanner.fromJson(Map<String, dynamic>.from(b)),
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
      rating: (profile['rating'] as num?)?.toDouble() ?? 4.6,
      reviewCount: (profile['reviewCount']?.toString().isNotEmpty == true ? profile['reviewCount'].toString() : '1.2k+'),
      deliveryEta: (json['deliveryEta']?.toString().isNotEmpty == true ? json['deliveryEta'].toString() : '25–35 mins'),
      pickupEta: (json['pickupEta']?.toString().isNotEmpty == true ? json['pickupEta'].toString() : '15–20 mins'),
    );
    _brandCache[cleanSlug] = data;
    if (_brandCache.length > 16) _brandCache.remove(_brandCache.keys.first);
    cacheCategory(cleanSlug, restaurant.cuisineType);
    return data;
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

    // 1. Save locally in DatabaseService
    final localSuccess = await _db.placeOnlineStorefrontOrder(order);

    // 2. Submit to backend API
    try {
      final slugTarget = restaurant.storefrontSlug.isNotEmpty
          ? restaurant.storefrontSlug
          : (restaurant.slug.isNotEmpty ? restaurant.slug : 'store');
      await _apiClient.post(
        ApiEndpoints.storefrontOrder(slugTarget),
        data: {
          'orderNumber': orderNumber,
          'orderType': isDineIn
              ? 'dineIn'
              : (orderType == OrderType.delivery ? 'delivery' : 'takeaway'),
          'tableNumber': tableNumber?.trim(),
          'orderSource': 'storefront',
          'items': order.items.map((i) => i.toJson()).toList(),
          'subtotal': subtotal,
          'taxAmount': taxAmount,
          'deliveryCharge': isDineIn ? 0.0 : deliveryFee,
          'totalAmount': totalAmount,
          'paymentMethod': paymentMethod,
          'deliveryAddress': isDineIn
              ? 'Table ${tableNumber?.trim() ?? "Dine-In"}'
              : deliveryAddress,
          'customerName': customerName,
          'customerPhone': customerPhone,
          'notes': specialNote,
        },
      );
    } catch (e) {
      debugPrint('[StorefrontService] Backend order submit notice: $e');
    }

    return localSuccess;
  }
}
