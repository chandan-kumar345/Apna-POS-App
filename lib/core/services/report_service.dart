import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

/// Complete Sales Report Summary Metrics
class SalesReportSummary {
  final double totalRevenue;
  final double grossSales;
  final double netSales;
  final int totalOrders;
  final int totalItems;
  final double totalDiscount;
  final double totalTax;
  final double cgst;
  final double sgst;
  final double igst;
  final double avgOrderValue;

  SalesReportSummary({
    this.totalRevenue = 0.0,
    this.grossSales = 0.0,
    this.netSales = 0.0,
    this.totalOrders = 0,
    this.totalItems = 0,
    this.totalDiscount = 0.0,
    this.totalTax = 0.0,
    this.cgst = 0.0,
    this.sgst = 0.0,
    this.igst = 0.0,
    this.avgOrderValue = 0.0,
  });

  factory SalesReportSummary.fromJson(Map<String, dynamic> json) => SalesReportSummary(
        totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
        grossSales: (json['grossSales'] as num?)?.toDouble() ?? 0.0,
        netSales: (json['netSales'] as num?)?.toDouble() ?? 0.0,
        totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
        totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
        totalDiscount: (json['totalDiscount'] as num?)?.toDouble() ?? 0.0,
        totalTax: (json['totalTax'] as num?)?.toDouble() ?? 0.0,
        cgst: (json['cgst'] as num?)?.toDouble() ?? 0.0,
        sgst: (json['sgst'] as num?)?.toDouble() ?? 0.0,
        igst: (json['igst'] as num?)?.toDouble() ?? 0.0,
        avgOrderValue: (json['avgOrderValue'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Dynamic Payment Mode Metric returned from backend
class PaymentModeStat {
  final String mode;
  final String rawMode;
  final int count;
  final double amount;
  final double percentage;

  PaymentModeStat({
    required this.mode,
    this.rawMode = '',
    this.count = 0,
    this.amount = 0.0,
    this.percentage = 0.0,
  });

  factory PaymentModeStat.fromJson(Map<String, dynamic> json) => PaymentModeStat(
        mode: json['mode']?.toString() ?? 'Cash',
        rawMode: json['rawMode']?.toString() ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Order Type Metric (Dine-in, Takeaway, Delivery)
class OrderTypeStat {
  final String type;
  final String rawType;
  final int count;
  final double amount;

  OrderTypeStat({
    required this.type,
    this.rawType = '',
    this.count = 0,
    this.amount = 0.0,
  });

  factory OrderTypeStat.fromJson(Map<String, dynamic> json) => OrderTypeStat(
        type: json['type']?.toString() ?? 'Dine In',
        rawType: json['rawType']?.toString() ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Top Product Sales Data
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
        name: json['name']?.toString() ?? '',
        quantity: (json['totalQuantity'] ?? json['quantity'] as num?)?.toInt() ?? 0,
        revenue: (json['totalRevenue'] ?? json['revenue'] as num?)?.toDouble() ?? 0.0,
        foodType: json['foodType']?.toString() ?? 'veg',
      );
}

/// Unified Sales Report Complete Response Model
class SalesReportData {
  final SalesReportSummary summary;
  final List<PaymentModeStat> paymentModes;
  final List<OrderTypeStat> salesByOrderType;
  final List<TopProductData> topProducts;
  final List<OrderModel> orders;
  final String startDate;
  final String endDate;
  final String period;

  SalesReportData({
    SalesReportSummary? summary,
    this.paymentModes = const [],
    this.salesByOrderType = const [],
    this.topProducts = const [],
    this.orders = const [],
    this.startDate = '',
    this.endDate = '',
    this.period = 'allTime',
  }) : summary = summary ?? SalesReportSummary();

  factory SalesReportData.fromJson(Map<String, dynamic> json) {
    final summaryJson = json['summary'] as Map<String, dynamic>? ?? {};
    final paymentModesList = (json['paymentModes'] as List<dynamic>? ?? [])
        .map((p) => PaymentModeStat.fromJson(p as Map<String, dynamic>))
        .toList();
    final orderTypesList = (json['salesByOrderType'] as List<dynamic>? ?? [])
        .map((t) => OrderTypeStat.fromJson(t as Map<String, dynamic>))
        .toList();
    final topProductsList = (json['topProducts'] as List<dynamic>? ?? [])
        .map((tp) => TopProductData.fromJson(tp as Map<String, dynamic>))
        .toList();
    final ordersList = (json['orders'] as List<dynamic>? ?? [])
        .map((o) => OrderModel.fromJson(o as Map<String, dynamic>))
        .toList();

    return SalesReportData(
      summary: SalesReportSummary.fromJson(summaryJson),
      paymentModes: paymentModesList,
      salesByOrderType: orderTypesList,
      topProducts: topProductsList,
      orders: ordersList,
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      period: json['period']?.toString() ?? 'allTime',
    );
  }
}

/// Backwards-compatible sales summary class
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
        totalSubtotal: (json['totalSubtotal'] ?? json['grossSales'] as num?)?.toDouble() ?? 0.0,
        totalTax: (json['totalTax'] as num?)?.toDouble() ?? 0.0,
        totalDiscount: (json['totalDiscount'] as num?)?.toDouble() ?? 0.0,
        totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
        cashSales: (json['cashSales'] as num?)?.toDouble() ?? 0.0,
        upiSales: (json['upiSales'] as num?)?.toDouble() ?? 0.0,
        cardSales: (json['cardSales'] as num?)?.toDouble() ?? 0.0,
      );
}

class ReportService {
  final ApiClient _apiClient = ApiClient();

  /// Unified Authoritative Sales Report API
  Future<SalesReportData> fetchSalesReport({
    String? period,
    String? startDate,
    String? endDate,
    String? fromDate,
    String? toDate,
    int limit = 500,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
      };
      if (period != null && period.isNotEmpty) queryParams['period'] = period;
      if (startDate != null && startDate.isNotEmpty) queryParams['startDate'] = startDate;
      if (endDate != null && endDate.isNotEmpty) queryParams['endDate'] = endDate;
      if (fromDate != null && fromDate.isNotEmpty) queryParams['fromDate'] = fromDate;
      if (toDate != null && toDate.isNotEmpty) queryParams['toDate'] = toDate;

      final response = await _apiClient.get(
        ApiEndpoints.salesReport,
        queryParameters: queryParams,
      );

      if (response != null && response['data'] != null) {
        return SalesReportData.fromJson(response['data'] as Map<String, dynamic>);
      }
      return SalesReportData();
    } catch (e) {
      debugPrint('[ReportService.fetchSalesReport] error: $e');
      rethrow;
    }
  }

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
