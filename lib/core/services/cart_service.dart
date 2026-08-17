import 'package:flutter/foundation.dart';
import '../models/menu_item_model.dart';
import '../models/order_model.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class CartService {
  final ApiClient _apiClient = ApiClient();

  /// Get active cart for table / orderType
  Future<Map<String, dynamic>?> fetchCart({
    String? tableNumber,
    String orderType = 'dineIn',
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.cart,
        queryParameters: {
          if (tableNumber != null && tableNumber.isNotEmpty) 'tableNumber': tableNumber,
          'orderType': orderType,
        },
      );

      if (response != null && response['data'] != null && response['data']['cart'] != null) {
        return response['data']['cart'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[CartService.fetchCart] error: $e');
      return null;
    }
  }

  /// Add product to cart via API
  Future<Map<String, dynamic>?> addToCart({
    required MenuItemModel product,
    String? tableNumber,
    String orderType = 'dineIn',
    String? variantName,
    int quantity = 1,
  }) async {
    try {
      final payload = {
        'tableNumber': tableNumber ?? '',
        'orderType': orderType,
        'quantity': quantity > 0 ? quantity : 1,
        'variantName': variantName ?? '',
        'product': {
          'productId': product.id,
          'name': product.name,
          'price': product.price,
          'salePrice': product.salePrice,
          'hasDiscount': product.hasDiscount,
          'discountPercent': product.discountPercent,
          'foodType': product.foodType.name,
          'imageUrl': product.imageUrl ?? '',
        },
      };

      final response = await _apiClient.post(
        ApiEndpoints.cartAdd,
        data: payload,
      );

      if (response != null && response['data'] != null && response['data']['cart'] != null) {
        return response['data']['cart'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[CartService.addToCart] error: $e');
      return null;
    }
  }

  /// Reduce quantity of a product in the cart via API
  Future<Map<String, dynamic>?> reduceProductFromCart({
    required String productId,
    String? tableNumber,
    String orderType = 'dineIn',
    String? variantName,
    int quantity = 1,
  }) async {
    try {
      final payload = {
        'productId': productId,
        'tableNumber': tableNumber ?? '',
        'orderType': orderType,
        'variantName': variantName ?? '',
        'quantity': quantity > 0 ? quantity : 1,
      };

      final response = await _apiClient.post(
        ApiEndpoints.cartReduce,
        data: payload,
      );

      if (response != null && response['data'] != null && response['data']['cart'] != null) {
        return response['data']['cart'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[CartService.reduceProductFromCart] error: $e');
      return null;
    }
  }

  /// Remove item completely from cart via API
  Future<Map<String, dynamic>?> removeItemFromCart({
    required String productId,
    String? tableNumber,
    String orderType = 'dineIn',
    String? variantName,
  }) async {
    try {
      final payload = {
        'productId': productId,
        'tableNumber': tableNumber ?? '',
        'orderType': orderType,
        'variantName': variantName ?? '',
      };

      final response = await _apiClient.post(
        ApiEndpoints.cartRemove,
        data: payload,
      );

      if (response != null && response['data'] != null && response['data']['cart'] != null) {
        return response['data']['cart'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[CartService.removeItemFromCart] error: $e');
      return null;
    }
  }

  /// Sync full cart items batch to backend
  Future<Map<String, dynamic>?> syncCart({
    required List<CartItemModel> items,
    String? tableNumber,
    String orderType = 'dineIn',
  }) async {
    try {
      final payload = {
        'tableNumber': tableNumber ?? '',
        'orderType': orderType,
        'items': items.map((ci) => {
          'productId': ci.item.id,
          'name': ci.item.name,
          'price': ci.item.price,
          'salePrice': ci.item.salePrice,
          'hasDiscount': ci.item.hasDiscount,
          'discountPercent': ci.item.discountPercent,
          'variantName': ci.selectedVariant?.name ?? '',
          'quantity': ci.quantity,
          'foodType': ci.item.foodType.name,
          'imageUrl': ci.item.imageUrl ?? '',
        }).toList(),
      };

      final response = await _apiClient.post(
        ApiEndpoints.cartSync,
        data: payload,
      );

      if (response != null && response['data'] != null && response['data']['cart'] != null) {
        return response['data']['cart'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[CartService.syncCart] error: $e');
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

      await _apiClient.post(
        ApiEndpoints.cartClear,
        data: payload,
      );
      return true;
    } catch (e) {
      debugPrint('[CartService.clearCart] error: $e');
      return false;
    }
  }
}
