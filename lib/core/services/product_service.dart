import 'package:flutter/foundation.dart';
import '../models/menu_item_model.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class ProductService {
  final ApiClient _apiClient = ApiClient();

  // In-memory cache for fast tab navigation
  static final Map<String, List<MenuItemModel>> _posCache = {};
  static DateTime? _lastCacheTime;

  static void clearPosCache() {
    _posCache.clear();
    _lastCacheTime = null;
  }

  /// High-speed POS catalog fetch with caching and lean projection
  Future<List<MenuItemModel>> fetchPosProducts({
    int page = 1,
    int limit = 100,
    String? category,
    String? search,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${category ?? "All"}_${search?.trim() ?? ""}_$page';
    final now = DateTime.now();

    // Cache valid for 3 minutes unless forceRefresh
    if (!forceRefresh &&
        _lastCacheTime != null &&
        now.difference(_lastCacheTime!).inMinutes < 3 &&
        _posCache.containsKey(cacheKey)) {
      return _posCache[cacheKey]!;
    }

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
        ApiEndpoints.productsPos,
        queryParameters: queryParams,
      );

      if (response != null && response['data'] != null) {
        final productsData = response['data']['products'] as List<dynamic>?;
        if (productsData != null) {
          final list = productsData
              .map((p) => MenuItemModel.fromJson(p as Map<String, dynamic>))
              .toList();
          _posCache[cacheKey] = list;
          _lastCacheTime = now;
          return list;
        }
      }
      return [];
    } catch (e) {
      debugPrint('[ProductService.fetchPosProducts] error: $e');
      if (_posCache.containsKey(cacheKey)) {
        return _posCache[cacheKey]!;
      }
      return fetchProducts(page: page, limit: limit, category: category, search: search);
    }
  }

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
      clearPosCache();
      final payload = item.toJson();

      final response = await _apiClient.post(
        ApiEndpoints.products,
        data: payload,
      );

      if (response != null && response is Map && response['data'] != null && response['data']['product'] != null) {
        return MenuItemModel.fromJson(response['data']['product'] as Map);
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
      clearPosCache();
      final payload = item.toJson();
      final targetId = item.productId.isNotEmpty ? item.productId : item.id;

      final response = await _apiClient.put(
        '${ApiEndpoints.products}/$targetId',
        data: payload,
      );

      if (response != null && response is Map && response['data'] != null && response['data']['product'] != null) {
        return MenuItemModel.fromJson(response['data']['product'] as Map);
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
      clearPosCache();
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

  /// Edit / rename category (cascades on backend to all products)
  Future<bool> updateCategory(String oldName, String newName) async {
    try {
      await _apiClient.put(
        '${ApiEndpoints.categories}/${Uri.encodeComponent(oldName.trim())}',
        data: {'name': newName.trim()},
      );
      return true;
    } catch (e) {
      debugPrint('[ProductService.updateCategory] error: $e');
      rethrow;
    }
  }

  /// Delete category
  Future<bool> deleteCategory(String name) async {
    try {
      await _apiClient.delete('${ApiEndpoints.categories}/${Uri.encodeComponent(name.trim())}');
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
        'items': items.map((item) => item.toJson()).toList(),
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

