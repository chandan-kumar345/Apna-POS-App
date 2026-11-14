import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../database/database_service.dart';
import '../models/menu_item_model.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import 'auth_service.dart';
import 'cart_mutation_queue.dart';

class CartApiService {
  static final CartApiService _instance = CartApiService._internal();
  factory CartApiService() => _instance;
  CartApiService._internal();

  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();
  late final _mutations = CartMutationQueue(_postMutation);

  String get _scope =>
      '${ApiEndpoints.baseUrl}|${DatabaseService().currentUser?.id}|${DatabaseService().currentBusinessId}';
  String _cartKey(String? table, String type) => '$type|${table?.trim() ?? ''}';

  Future<Map<String, dynamic>?> _postMutation(
    String scope,
    String path,
    Map<String, dynamic> payload,
  ) async {
    if (scope != _scope ||
        !await _authService.isAuthenticated() ||
        scope != _scope) {
      return null;
    }
    try {
      final response = await _apiClient.postOnce(path, data: payload);
      if (response is Map && response['data'] is Map) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
    } catch (error) {
      debugPrint('[CartApiService] Background cart sync failed: $error');
    }
    return null;
  }

  Future<void> flushPending({
    String? tableNumber,
    String orderType = 'dineIn',
  }) => _mutations.flush(_scope, _cartKey(tableNumber, orderType));

  /// Add a product or variant to the server-side active cart
  Future<Map<String, dynamic>?> addToCart({
    required MenuItemModel item,
    String? tableNumber,
    String orderType = 'dineIn',
    int quantity = 1,
    String? variantName,
  }) async {
    try {
      final payload = {
        'tableNumber': tableNumber ?? '',
        'orderType': orderType,
        'quantity': quantity,
        'variantName': variantName ?? '',
        'product': {
          'productId': item.productId.isNotEmpty ? item.productId : item.id,
          'name': item.name,
          'price': item.price,
          'salePrice': item.salePrice,
          'effectivePrice': item.effectivePrice,
          'hasDiscount': item.hasDiscount,
          'discountPercent': item.discountPercent,
          'foodType': item.itemType.toLowerCase().replaceAll('-', '_'),
          'imageUrl': item.imageUrl,
          'variantName': variantName ?? '',
        },
      };

      return await _mutations.enqueue(
        scope: _scope,
        cart: _cartKey(tableNumber, orderType),
        path: ApiEndpoints.cartAdd,
        payload: payload,
        mergeKey: jsonEncode(payload['product']),
      );
    } catch (e) {
      debugPrint('[CartApiService.addToCart] error: $e');
      return null;
    }
  }

  /// Reduce quantity of a product / variant in the server-side active cart
  Future<Map<String, dynamic>?> reduceProductFromCart({
    required String productId,
    String? variantName,
    String? tableNumber,
    String orderType = 'dineIn',
    int quantity = 1,
  }) async {
    try {
      final payload = {
        'productId': productId,
        'variantName': variantName ?? '',
        'tableNumber': tableNumber ?? '',
        'orderType': orderType,
        'quantity': quantity,
      };

      return await _mutations.enqueue(
        scope: _scope,
        cart: _cartKey(tableNumber, orderType),
        path: ApiEndpoints.cartReduce,
        payload: payload,
        mergeKey: '$productId|${variantName ?? ''}',
      );
    } catch (e) {
      debugPrint('[CartApiService.reduceProductFromCart] error: $e');
      return null;
    }
  }

  /// Fetch active cart from backend
  Future<Map<String, dynamic>?> getCart({
    String? tableNumber,
    String orderType = 'dineIn',
  }) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (!isAuth) return null;

      final response = await _apiClient.get(
        ApiEndpoints.cart,
        queryParameters: {
          if (tableNumber != null && tableNumber.isNotEmpty)
            'tableNumber': tableNumber,
          'orderType': orderType,
        },
      );

      if (response != null && response is Map && response['data'] != null) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      return null;
    } catch (e) {
      debugPrint('[CartApiService.getCart] error: $e');
      return null;
    }
  }

  /// Remove item completely from cart on backend
  Future<Map<String, dynamic>?> removeItemFromCart({
    required String productId,
    String? variantName,
    String? tableNumber,
    String orderType = 'dineIn',
  }) async {
    try {
      final payload = {
        'productId': productId,
        'variantName': variantName ?? '',
        'tableNumber': tableNumber ?? '',
        'orderType': orderType,
      };

      return await _mutations.enqueue(
        scope: _scope,
        cart: _cartKey(tableNumber, orderType),
        path: ApiEndpoints.cartRemove,
        payload: payload,
        immediate: true,
      );
    } catch (e) {
      debugPrint('[CartApiService.removeItemFromCart] error: $e');
      return null;
    }
  }

  /// Sync complete list of cart items in batch to backend
  Future<Map<String, dynamic>?> syncCart({
    required List<Map<String, dynamic>> items,
    String? tableNumber,
    String orderType = 'dineIn',
  }) async {
    try {
      final payload = {
        'tableNumber': tableNumber ?? '',
        'orderType': orderType,
        'items': items.map((item) => Map<String, dynamic>.from(item)).toList(),
      };

      return await _mutations.enqueue(
        scope: _scope,
        cart: _cartKey(tableNumber, orderType),
        path: ApiEndpoints.cartSync,
        payload: payload,
        immediate: true,
      );
    } catch (e) {
      debugPrint('[CartApiService.syncCart] error: $e');
      return null;
    }
  }

  /// Clear active cart on backend
  Future<bool> clearCart({
    String? tableNumber,
    String orderType = 'dineIn',
  }) async {
    try {
      final payload = {
        'tableNumber': tableNumber ?? '',
        'orderType': orderType,
      };

      final result = await _mutations.enqueue(
        scope: _scope,
        cart: _cartKey(tableNumber, orderType),
        path: ApiEndpoints.cartClear,
        payload: payload,
        immediate: true,
      );
      return result != null;
    } catch (e) {
      debugPrint('[CartApiService.clearCart] error: $e');
      return false;
    }
  }
}
