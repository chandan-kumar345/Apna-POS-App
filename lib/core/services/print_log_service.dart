import 'package:flutter/foundation.dart';
import '../models/print_log_model.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class PrintLogService {
  final ApiClient _apiClient = ApiClient();

  /// Fetch list of print logs with optional filtering & pagination
  Future<List<PrintLogModel>> fetchPrintLogs({
    int page = 1,
    int limit = 50,
    String? period,
    String? startDate,
    String? endDate,
    String? orderNumber,
    String? paymentStatus,
    String? orderStatus,
    String? printType,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (period != null && period.isNotEmpty && period != 'allTime' && period != 'all') {
        queryParams['period'] = period;
      }
      if (startDate != null && startDate.isNotEmpty) queryParams['startDate'] = startDate;
      if (endDate != null && endDate.isNotEmpty) queryParams['endDate'] = endDate;
      if (orderNumber != null && orderNumber.isNotEmpty) queryParams['orderNumber'] = orderNumber;
      if (paymentStatus != null && paymentStatus.isNotEmpty && paymentStatus != 'All') {
        queryParams['paymentStatus'] = paymentStatus.toLowerCase();
      }
      if (orderStatus != null && orderStatus.isNotEmpty && orderStatus != 'All') {
        queryParams['orderStatus'] = orderStatus.toLowerCase();
      }
      if (printType != null && printType.isNotEmpty && printType != 'All') {
        queryParams['printType'] = printType.toLowerCase();
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _apiClient.get(
        ApiEndpoints.printLogs,
        queryParameters: queryParams,
      );

      if (response != null && response['data'] != null) {
        final logsData = response['data']['printLogs'] as List<dynamic>?;
        if (logsData != null) {
          return logsData
              .map((l) => PrintLogModel.fromJson(l as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[PrintLogService.fetchPrintLogs] error: $e');
      return [];
    }
  }

  /// Get specific print log snapshot by ID
  Future<PrintLogModel?> getPrintLog(String id) async {
    try {
      final response = await _apiClient.get('${ApiEndpoints.printLogs}/$id');
      if (response != null && response['data'] != null && response['data']['printLog'] != null) {
        return PrintLogModel.fromJson(response['data']['printLog'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('[PrintLogService.getPrintLog] error: $e');
      return null;
    }
  }

  /// Record a reprint event on the server
  Future<PrintLogModel?> reprintLog(String id) async {
    try {
      final response = await _apiClient.post('${ApiEndpoints.printLogs}/$id/reprint');
      if (response != null && response['data'] != null && response['data']['printLog'] != null) {
        return PrintLogModel.fromJson(response['data']['printLog'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('[PrintLogService.reprintLog] error: $e');
      return null;
    }
  }
}
