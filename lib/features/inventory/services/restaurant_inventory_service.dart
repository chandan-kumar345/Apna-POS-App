import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../models/raw_material_model.dart';
import '../models/recipe_model.dart';
import '../models/inventory_movement_model.dart';

class RestaurantInventoryService {
  final ApiClient _apiClient = ApiClient();

  // ---------------------------------------------------------------------------
  // 1. DASHBOARD & SUMMARY
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> fetchDashboardSummary() async {
    try {
      final res = await _apiClient.get('/inventory/dashboard-summary');
      if (res != null && res['data'] != null) {
        return res['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[RestaurantInventoryService.fetchDashboardSummary] error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 2. RAW MATERIALS
  // ---------------------------------------------------------------------------

  Future<List<RawMaterialModel>> fetchRawMaterials({
    String? category,
    String? search,
    bool? lowStock,
    String? mode,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null && category.isNotEmpty && category != 'All') {
        queryParams['category'] = category;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (lowStock == true) {
        queryParams['lowStock'] = true;
      }
      if (mode != null && mode.isNotEmpty && mode != 'All') {
        queryParams['mode'] = mode;
      }

      final res = await _apiClient.get('/inventory/raw-materials', queryParameters: queryParams);
      if (res != null && res['data'] != null && res['data']['materials'] != null) {
        final list = res['data']['materials'] as List<dynamic>;
        return list.map((e) => RawMaterialModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[RestaurantInventoryService.fetchRawMaterials] error: $e');
      return [];
    }
  }

  Future<RawMaterialModel?> createRawMaterial(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.post('/inventory/raw-materials', data: data);
      if (res != null && res['data'] != null && res['data']['material'] != null) {
        return RawMaterialModel.fromJson(res['data']['material'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('[RestaurantInventoryService.createRawMaterial] error: $e');
      rethrow;
    }
  }

  Future<RawMaterialModel?> updateRawMaterial(String id, Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.put('/inventory/raw-materials/$id', data: data);
      if (res != null && res['data'] != null && res['data']['material'] != null) {
        return RawMaterialModel.fromJson(res['data']['material'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('[RestaurantInventoryService.updateRawMaterial] error: $e');
      rethrow;
    }
  }

  Future<bool> archiveRawMaterial(String id) async {
    try {
      final res = await _apiClient.delete('/inventory/raw-materials/$id');
      return res != null && res['success'] == true;
    } catch (e) {
      debugPrint('[RestaurantInventoryService.archiveRawMaterial] error: $e');
      return false;
    }
  }

  Future<List<InventoryMovementModel>> fetchMaterialMovements(String materialId) async {
    try {
      final res = await _apiClient.get('/inventory/raw-materials/$materialId/movements');
      if (res != null && res['data'] != null && res['data']['movements'] != null) {
        final list = res['data']['movements'] as List<dynamic>;
        return list.map((e) => InventoryMovementModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[RestaurantInventoryService.fetchMaterialMovements] error: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // 3. RECIPES
  // ---------------------------------------------------------------------------

  Future<List<RecipeModel>> fetchRecipes({String? search, String? productId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (productId != null && productId.isNotEmpty) {
        queryParams['productId'] = productId;
      }

      final res = await _apiClient.get('/inventory/recipes', queryParameters: queryParams);
      if (res != null && res['data'] != null && res['data']['recipes'] != null) {
        final list = res['data']['recipes'] as List<dynamic>;
        return list.map((e) => RecipeModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[RestaurantInventoryService.fetchRecipes] error: $e');
      return [];
    }
  }

  Future<RecipeModel?> createRecipe(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.post('/inventory/recipes', data: data);
      if (res != null && res['data'] != null && res['data']['recipe'] != null) {
        return RecipeModel.fromJson(res['data']['recipe'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('[RestaurantInventoryService.createRecipe] error: $e');
      rethrow;
    }
  }

  Future<RecipeModel?> updateRecipe(String id, Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.put('/inventory/recipes/$id', data: data);
      if (res != null && res['data'] != null && res['data']['recipe'] != null) {
        return RecipeModel.fromJson(res['data']['recipe'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('[RestaurantInventoryService.updateRecipe] error: $e');
      rethrow;
    }
  }

  Future<bool> deleteRecipe(String id) async {
    try {
      final res = await _apiClient.delete('/inventory/recipes/$id');
      return res != null && res['success'] == true;
    } catch (e) {
      debugPrint('[RestaurantInventoryService.deleteRecipe] error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 4. STOCK OPERATIONS (MODE B)
  // ---------------------------------------------------------------------------

  Future<bool> recordStockIn(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.post('/inventory/stock-in', data: data);
      return res != null && res['success'] == true;
    } catch (e) {
      debugPrint('[RestaurantInventoryService.recordStockIn] error: $e');
      rethrow;
    }
  }

  Future<bool> recordStockOut(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.post('/inventory/stock-out', data: data);
      return res != null && res['success'] == true;
    } catch (e) {
      debugPrint('[RestaurantInventoryService.recordStockOut] error: $e');
      rethrow;
    }
  }

  Future<bool> recordPhysicalStockCount(Map<String, dynamic> data) async {
    try {
      final res = await _apiClient.post('/inventory/stock-count', data: data);
      return res != null && res['success'] == true;
    } catch (e) {
      debugPrint('[RestaurantInventoryService.recordPhysicalStockCount] error: $e');
      rethrow;
    }
  }

  Future<bool> recordOpeningStock(List<Map<String, dynamic>> items) async {
    try {
      final res = await _apiClient.post('/inventory/opening-stock', data: {'items': items});
      return res != null && res['success'] == true;
    } catch (e) {
      debugPrint('[RestaurantInventoryService.recordOpeningStock] error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 5. REPORTS
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> fetchStockReport({String? category, String? search}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null && category.isNotEmpty && category != 'All') {
        queryParams['category'] = category;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      final res = await _apiClient.get('/inventory/reports/stock', queryParameters: queryParams);
      if (res != null && res['data'] != null) {
        return res['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[RestaurantInventoryService.fetchStockReport] error: $e');
      return null;
    }
  }

  Future<List<InventoryMovementModel>> fetchMovementsLedger({
    String? materialId,
    String? movementType,
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'limit': 50};
      if (materialId != null && materialId.isNotEmpty) {
        queryParams['materialId'] = materialId;
      }
      if (movementType != null && movementType.isNotEmpty && movementType != 'All') {
        queryParams['movementType'] = movementType;
      }
      final res = await _apiClient.get('/inventory/reports/movements', queryParameters: queryParams);
      if (res != null && res['data'] != null && res['data']['movements'] != null) {
        final list = res['data']['movements'] as List<dynamic>;
        return list.map((e) => InventoryMovementModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[RestaurantInventoryService.fetchMovementsLedger] error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchProductAnalytics() async {
    try {
      final res = await _apiClient.get('/inventory/reports/product-analytics');
      if (res != null && res['data'] != null && res['data']['analytics'] != null) {
        final list = res['data']['analytics'] as List<dynamic>;
        return list.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[RestaurantInventoryService.fetchProductAnalytics] error: $e');
      return [];
    }
  }
}
