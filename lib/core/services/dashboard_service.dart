import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import 'report_service.dart';

class DashboardSummaryData {
  final String period;
  final double revenue;
  final int totalOrders;
  final int activeOrdersCount;
  final int totalProductsCount;
  final int dineInOrders;
  final double dineInSales;
  final int takeawayOrders;
  final double takeawaySales;
  final int deliveryOrders;
  final double deliverySales;
  final int totalTables;
  final int occupiedTables;
  final int billedTables;
  final int freeTables;
  final List<TopProductData> topProducts;

  DashboardSummaryData({
    this.period = 'Today',
    this.revenue = 0,
    this.totalOrders = 0,
    this.activeOrdersCount = 0,
    this.totalProductsCount = 0,
    this.dineInOrders = 0,
    this.dineInSales = 0,
    this.takeawayOrders = 0,
    this.takeawaySales = 0,
    this.deliveryOrders = 0,
    this.deliverySales = 0,
    this.totalTables = 0,
    this.occupiedTables = 0,
    this.billedTables = 0,
    this.freeTables = 0,
    this.topProducts = const [],
  });

  factory DashboardSummaryData.fromJson(Map<String, dynamic> json) {
    final orderTypes = json['orderTypes'] as Map<String, dynamic>? ?? {};
    final tables = json['tables'] as Map<String, dynamic>? ?? {};
    final topList = json['topProducts'] as List<dynamic>? ?? [];

    return DashboardSummaryData(
      period: json['period'] ?? 'Today',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      activeOrdersCount: (json['activeOrdersCount'] as num?)?.toInt() ?? 0,
      totalProductsCount: (json['totalProductsCount'] as num?)?.toInt() ?? 0,
      dineInOrders: (orderTypes['dineIn']?['count'] as num?)?.toInt() ?? 0,
      dineInSales: (orderTypes['dineIn']?['amount'] as num?)?.toDouble() ?? 0.0,
      takeawayOrders: (orderTypes['takeaway']?['count'] as num?)?.toInt() ?? 0,
      takeawaySales: (orderTypes['takeaway']?['amount'] as num?)?.toDouble() ?? 0.0,
      deliveryOrders: (orderTypes['delivery']?['count'] as num?)?.toInt() ?? 0,
      deliverySales: (orderTypes['delivery']?['amount'] as num?)?.toDouble() ?? 0.0,
      totalTables: (tables['totalTables'] as num?)?.toInt() ?? 0,
      occupiedTables: (tables['occupiedTables'] as num?)?.toInt() ?? 0,
      billedTables: (tables['billedTables'] as num?)?.toInt() ?? 0,
      freeTables: (tables['freeTables'] as num?)?.toInt() ?? 0,
      topProducts: topList.map((p) => TopProductData.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }
}

class ChartPointData {
  final String label;
  final double revenue;
  final int orders;

  ChartPointData({
    required this.label,
    required this.revenue,
    required this.orders,
  });

  factory ChartPointData.fromJson(Map<String, dynamic> json) => ChartPointData(
        label: json['label'] ?? '',
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
        orders: (json['orders'] as num?)?.toInt() ?? 0,
      );
}

class DashboardService {
  final ApiClient _apiClient = ApiClient();

  /// Fetch dashboard summary metrics
  Future<DashboardSummaryData> fetchSummary({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{'period': period};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final response = await _apiClient.get(
        ApiEndpoints.dashboardSummary,
        queryParameters: queryParams,
      );

      if (response != null && response['data'] != null && response['data']['summary'] != null) {
        return DashboardSummaryData.fromJson(response['data']['summary'] as Map<String, dynamic>);
      }
      return DashboardSummaryData();
    } catch (e) {
      debugPrint('[DashboardService.fetchSummary] error: $e');
      return DashboardSummaryData();
    }
  }

  /// Fetch chart data points
  Future<List<ChartPointData>> fetchChartData({String filter = 'Week'}) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.dashboardChart,
        queryParameters: {'filter': filter},
      );

      if (response != null && response['data'] != null && response['data']['chartPoints'] != null) {
        final raw = response['data']['chartPoints'] as List<dynamic>;
        return raw.map((c) => ChartPointData.fromJson(c as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[DashboardService.fetchChartData] error: $e');
      return [];
    }
  }
}
