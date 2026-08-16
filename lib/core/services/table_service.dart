import 'package:flutter/foundation.dart';
import '../models/table_model.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class TableService {
  final ApiClient _apiClient = ApiClient();

  /// Fetch tables from backend
  Future<List<TableModel>> fetchTables() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.tables);
      if (response != null && response['data'] != null && response['data']['tables'] != null) {
        final raw = response['data']['tables'] as List<dynamic>;
        return raw.map((t) => TableModel.fromJson(t as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[TableService.fetchTables] error: $e');
      return [];
    }
  }

  /// Create table
  Future<TableModel> createTable(TableModel table) async {
    try {
      final payload = {
        'tableNumber': table.tableNumber,
        'name': table.name,
        'floor': table.floor,
        'capacity': table.capacity,
      };

      final response = await _apiClient.post(
        ApiEndpoints.tables,
        data: payload,
      );

      if (response != null && response['data'] != null && response['data']['table'] != null) {
        return TableModel.fromJson(response['data']['table'] as Map<String, dynamic>);
      }
      return table;
    } catch (e) {
      debugPrint('[TableService.createTable] error: $e');
      rethrow;
    }
  }

  /// Update table status
  Future<bool> updateTableStatus(String tableId, TableStatus status, {String? orderId}) async {
    try {
      await _apiClient.patch(
        '${ApiEndpoints.tables}/$tableId/status',
        data: {
          'status': status.name,
          if (orderId != null) 'currentOrderId': orderId,
        },
      );
      return true;
    } catch (e) {
      debugPrint('[TableService.updateTableStatus] error: $e');
      return false;
    }
  }

  /// Delete table
  Future<bool> deleteTable(String tableId) async {
    try {
      await _apiClient.delete('${ApiEndpoints.tables}/$tableId');
      return true;
    } catch (e) {
      debugPrint('[TableService.deleteTable] error: $e');
      return false;
    }
  }
}
