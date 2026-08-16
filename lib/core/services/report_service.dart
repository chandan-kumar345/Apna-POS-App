import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class SalesSummaryData {
  final double totalRevenue;
  final double totalSubtotal;
  final double totalTax;
  final double totalDiscount;
  final int totalOrders;
  final double cashSales;
  final double upiSales;
  final double cardSales;

  SalesSummaryData({
    this.totalRevenue = 0,
    this.totalSubtotal = 0,
    this.totalTax = 0,
    this.totalDiscount = 0,
    this.totalOrders = 0,
    this.cashSales = 0,
    this.upiSales = 0,
    this.cardSales = 0,
  });

  factory SalesSummaryData.fromJson(Map<String, dynamic> json) => SalesSummaryData(
        totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
        totalSubtotal: (json['totalSubtotal'] as num?)?.toDouble() ?? 0.0,
        totalTax: (json['totalTax'] as num?)?.toDouble() ?? 0.0,
        totalDiscount: (json['totalDiscount'] as num?)?.toDouble() ?? 0.0,
        totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
        cashSales: (json['cashSales'] as num?)?.toDouble() ?? 0.0,
        upiSales: (json['upiSales'] as num?)?.toDouble() ?? 0.0,
        cardSales: (json['cardSales'] as num?)?.toDouble() ?? 0.0,
      );
}

class TopProductData {
  final String name;
  final int quantity;
  final double revenue;
  final String foodType;

  TopProductData({
    required this.name,
    required this.quantity,
    required this.revenue,
    this.foodType = 'veg',
  });

  factory TopProductData.fromJson(Map<String, dynamic> json) => TopProductData(
        name: json['name'] ?? '',
        quantity: (json['totalQuantity'] ?? json['quantity'] as num?)?.toInt() ?? 0,
        revenue: (json['totalRevenue'] ?? json['revenue'] as num?)?.toDouble() ?? 0.0,
        foodType: json['foodType'] ?? 'veg',
      );
}

class ReportService {
  final ApiClient _apiClient = ApiClient();

  /// Fetch sales list
  Future<List<OrderModel>> fetchSales({
    int page = 1,
    int limit = 50,
    String? paymentMethod,
    String? startDate,
    String? endDate,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (paymentMethod != null && paymentMethod.isNotEmpty && paymentMethod != 'All') {
        queryParams['paymentMethod'] = paymentMethod.toLowerCase();
      }
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _apiClient.get(
        ApiEndpoints.sales,
        queryParameters: queryParams,
      );

      if (response != null && response['data'] != null && response['data']['sales'] != null) {
        final raw = response['data']['sales'] as List<dynamic>;
        return raw.map((s) => OrderModel.fromJson(s as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ReportService.fetchSales] error: $e');
      return [];
    }
  }

  /// Fetch sales summary
  Future<SalesSummaryData> fetchSalesSummary({String? startDate, String? endDate}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final response = await _apiClient.get(
        ApiEndpoints.salesSummary,
        queryParameters: queryParams,
      );

      if (response != null && response['data'] != null && response['data']['summary'] != null) {
        return SalesSummaryData.fromJson(response['data']['summary'] as Map<String, dynamic>);
      }
      return SalesSummaryData();
    } catch (e) {
      debugPrint('[ReportService.fetchSalesSummary] error: $e');
      return SalesSummaryData();
    }
  }

  /// Fetch top products
  Future<List<TopProductData>> fetchTopProducts({int limit = 10, String? startDate, String? endDate}) async {
    try {
      final queryParams = <String, dynamic>{'limit': limit};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final response = await _apiClient.get(
        ApiEndpoints.topProducts,
        queryParameters: queryParams,
      );

      if (response != null && response['data'] != null && response['data']['topProducts'] != null) {
        final raw = response['data']['topProducts'] as List<dynamic>;
        return raw.map((p) => TopProductData.fromJson(p as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[ReportService.fetchTopProducts] error: $e');
      return [];
    }
  }
}
