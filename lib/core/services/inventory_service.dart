import 'package:flutter/foundation.dart';
import '../models/inventory_model.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class InventoryService {
  final ApiClient _apiClient = ApiClient();

  /// Fetch inventory items
  Future<List<InventoryItemModel>> fetchInventory({String? category, bool? lowStock}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (category != null && category.isNotEmpty && category != 'All') {
        queryParams['category'] = category;
      }
      if (lowStock != null) {
        queryParams['lowStock'] = lowStock;
      }

      final response = await _apiClient.get(
        ApiEndpoints.inventory,
        queryParameters: queryParams,
      );

      if (response != null && response['data'] != null && response['data']['items'] != null) {
        final raw = response['data']['items'] as List<dynamic>;
        return raw.map((i) => InventoryItemModel.fromJson(i as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[InventoryService.fetchInventory] error: $e');
      return [];
    }
  }

  /// Create inventory item
  Future<InventoryItemModel> createItem(InventoryItemModel item) async {
    try {
      final payload = {
        'itemName': item.name,
        'category': item.category,
        'quantity': item.quantity,
        'unit': item.unit,
        'minThreshold': item.minThreshold,
        'costPerUnit': item.costPerUnit,
        'supplier': item.supplier,
      };

      final response = await _apiClient.post(
        ApiEndpoints.inventory,
        data: payload,
      );

      if (response != null && response['data'] != null && response['data']['item'] != null) {
        return InventoryItemModel.fromJson(response['data']['item'] as Map<String, dynamic>);
      }
      return item;
    } catch (e) {
      debugPrint('[InventoryService.createItem] error: $e');
      rethrow;
    }
  }

  /// Update inventory item
  Future<InventoryItemModel> updateItem(InventoryItemModel item) async {
    try {
      final payload = {
        'itemName': item.name,
        'category': item.category,
        'quantity': item.quantity,
        'unit': item.unit,
        'minThreshold': item.minThreshold,
        'costPerUnit': item.costPerUnit,
        'supplier': item.supplier,
      };

      final response = await _apiClient.put(
        '${ApiEndpoints.inventory}/${item.id}',
        data: payload,
      );

      if (response != null && response['data'] != null && response['data']['item'] != null) {
        return InventoryItemModel.fromJson(response['data']['item'] as Map<String, dynamic>);
      }
      return item;
    } catch (e) {
      debugPrint('[InventoryService.updateItem] error: $e');
      rethrow;
    }
  }

  /// Delete inventory item
  Future<bool> deleteItem(String itemId) async {
    try {
      await _apiClient.delete('${ApiEndpoints.inventory}/$itemId');
      return true;
    } catch (e) {
      debugPrint('[InventoryService.deleteItem] error: $e');
      return false;
    }
  }
}
