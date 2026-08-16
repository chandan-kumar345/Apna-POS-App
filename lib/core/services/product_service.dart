import 'package:flutter/foundation.dart';
import '../models/menu_item_model.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class ProductService {
  final ApiClient _apiClient = ApiClient();

  /// Fetch products from backend with optional category and search filters
  Future<List<MenuItemModel>> fetchProducts({
    int page = 1,
    int limit = 100,
    String? category,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (category != null && category.isNotEmpty && category != 'All') {
        queryParams['category'] = category;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _apiClient.get(
        ApiEndpoints.products,
        queryParameters: queryParams,
      );

      if (response != null && response['data'] != null) {
        final productsData = response['data']['products'] as List<dynamic>?;
        if (productsData != null) {
          return productsData
              .map((p) => MenuItemModel.fromJson(p as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[ProductService.fetchProducts] error: $e');
      rethrow;
    }
  }

  /// Create a new product in backend MongoDB
  Future<MenuItemModel> createProduct(MenuItemModel item) async {
    try {
      final payload = {
        'name': item.name,
        'description': item.description,
        'category': item.category,
        'price': item.price,
        'salePrice': item.hasDiscount ? item.price * (1 - item.discountPercent / 100) : 0,
        'image': item.imageUrl,
        'foodType': item.itemType.toLowerCase().replaceAll('-', '_'),
        'isAvailable': item.isAvailable,
        'stock': item.stockQuantity,
        'taxPercentage': item.gstPercent ?? 5,
      };

      final response = await _apiClient.post(
        ApiEndpoints.products,
        data: payload,
      );

      if (response != null && response['data'] != null && response['data']['product'] != null) {
        return MenuItemModel.fromJson(response['data']['product'] as Map<String, dynamic>);
      }
      return item;
    } catch (e) {
      debugPrint('[ProductService.createProduct] error: $e');
      rethrow;
    }
  }

  /// Update an existing product
  Future<MenuItemModel> updateProduct(MenuItemModel item) async {
    try {
      final payload = {
        'name': item.name,
        'description': item.description,
        'category': item.category,
        'price': item.price,
        'salePrice': item.hasDiscount ? item.price * (1 - item.discountPercent / 100) : 0,
        'image': item.imageUrl,
        'foodType': item.itemType.toLowerCase().replaceAll('-', '_'),
        'isAvailable': item.isAvailable,
        'stock': item.stockQuantity,
        'taxPercentage': item.gstPercent ?? 5,
      };

      final response = await _apiClient.put(
        '${ApiEndpoints.products}/${item.id}',
        data: payload,
      );

      if (response != null && response['data'] != null && response['data']['product'] != null) {
        return MenuItemModel.fromJson(response['data']['product'] as Map<String, dynamic>);
      }
      return item;
    } catch (e) {
      debugPrint('[ProductService.updateProduct] error: $e');
      rethrow;
    }
  }

  /// Delete a product
  Future<bool> deleteProduct(String productId) async {
    try {
      await _apiClient.delete('${ApiEndpoints.products}/$productId');
      return true;
    } catch (e) {
      debugPrint('[ProductService.deleteProduct] error: $e');
      rethrow;
    }
  }

  /// Fetch categories list
  Future<List<String>> fetchCategories() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.categories);
      if (response != null && response['data'] != null && response['data']['categories'] != null) {
        final raw = response['data']['categories'] as List<dynamic>;
        return raw.map((c) => (c['name'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ProductService.fetchCategories] error: $e');
      return [];
    }
  }

  /// Add new category
  Future<bool> createCategory(String name) async {
    try {
      await _apiClient.post(
        ApiEndpoints.categories,
        data: {'name': name.trim()},
      );
      return true;
    } catch (e) {
      debugPrint('[ProductService.createCategory] error: $e');
      rethrow;
    }
  }

  /// Delete category
  Future<bool> deleteCategory(String name) async {
    try {
      await _apiClient.delete('${ApiEndpoints.categories}/$name');
      return true;
    } catch (e) {
      debugPrint('[ProductService.deleteCategory] error: $e');
      rethrow;
    }
  }

  /// Bulk import products from CSV
  Future<int> bulkImport(List<MenuItemModel> items) async {
    try {
      final payload = {
        'items': items.map((item) => {
              'name': item.name,
              'description': item.description,
              'category': item.category,
              'price': item.price,
              'salePrice': item.hasDiscount ? item.price * (1 - item.discountPercent / 100) : 0,
              'foodType': item.itemType.toLowerCase().replaceAll('-', '_'),
              'isAvailable': item.isAvailable,
              'stock': item.stockQuantity,
              'taxPercentage': item.gstPercent ?? 5,
            }).toList(),
      };

      final response = await _apiClient.post(
        ApiEndpoints.productsBulk,
        data: payload,
      );

      return (response?['data']?['importedCount'] as num?)?.toInt() ?? items.length;
    } catch (e) {
      debugPrint('[ProductService.bulkImport] error: $e');
      rethrow;
    }
  }
}
