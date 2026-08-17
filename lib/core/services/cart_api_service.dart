import 'package:flutter/foundation.dart';
import '../models/menu_item_model.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import 'auth_service.dart';

class CartApiService {
  static final CartApiService _instance = CartApiService._internal();
  factory CartApiService() => _instance;
  CartApiService._internal();

  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();

  /// Add a product or variant to the server-side active cart
  Future<Map<String, dynamic>?> addToCart({
    required MenuItemModel item,
    String? tableNumber,
    String orderType = 'dineIn',
    int quantity = 1,
    String? variantName,
  }) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (!isAuth) return null;

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

      final response = await _apiClient.post(
        ApiEndpoints.cartAdd,
        data: payload,
      );

      if (response != null && response is Map && response['data'] != null) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      return null;
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
      final isAuth = await _authService.isAuthenticated();
      if (!isAuth) return null;

      final payload = {
        'productId': productId,
        'variantName': variantName ?? '',
        'tableNumber': tableNumber ?? '',
        'orderType': orderType,
        'quantity': quantity,
      };

      final response = await _apiClient.post(
        ApiEndpoints.cartReduce,
        data: payload,
      );

      if (response != null && response is Map && response['data'] != null) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      return null;
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
          if (tableNumber != null && tableNumber.isNotEmpty) 'tableNumber': tableNumber,
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
      final isAuth = await _authService.isAuthenticated();
      if (!isAuth) return null;

      final payload = {
        'productId': productId,
        'variantName': variantName ?? '',
        'tableNumber': tableNumber ?? '',
        'orderType': orderType,
      };

      final response = await _apiClient.post(
        ApiEndpoints.cartRemove,
        data: payload,
      );

      if (response != null && response is Map && response['data'] != null) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      return null;
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
      final isAuth = await _authService.isAuthenticated();
      if (!isAuth) return null;

      final payload = {
        'tableNumber': tableNumber ?? '',
        'orderType': orderType,
        'items': items,
      };

      final response = await _apiClient.post(
        ApiEndpoints.cartSync,
        data: payload,
      );

      if (response != null && response is Map && response['data'] != null) {
        return Map<String, dynamic>.from(response['data'] as Map);
      }
      return null;
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
      final isAuth = await _authService.isAuthenticated();
      if (!isAuth) return false;

      final payload = {
        'tableNumber': tableNumber ?? '',
        'orderType': orderType,
      };

      await _apiClient.post(
        ApiEndpoints.cartClear,
        data: payload,
      );
      return true;
    } catch (e) {
      debugPrint('[CartApiService.clearCart] error: $e');
      return false;
    }
  }
}
