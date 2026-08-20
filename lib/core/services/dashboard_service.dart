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
  final List<TopProductData> topProducts;

  DashboardSummaryData({
    this.period = 'Today',
    this.revenue = 0,
    this.totalOrders = 0,
    this.activeOrdersCount = 0,
    this.totalProductsCount = 0,
    this.topProducts = const [],
  });

  factory DashboardSummaryData.fromJson(Map<String, dynamic> json) {
    final topList = json['topProducts'] as List<dynamic>? ?? [];

    return DashboardSummaryData(
      period: json['period'] ?? 'Today',
      revenue: (json['totalRevenue'] as num?)?.toDouble() ?? (json['revenue'] as num?)?.toDouble() ?? 0.0,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      activeOrdersCount: (json['activeOrdersCount'] as num?)?.toInt() ?? 0,
      totalProductsCount: (json['totalProductsCount'] as num?)?.toInt() ?? 0,
      topProducts: topList.map((p) => TopProductData.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }
}

class OrderTypeCountAmount {
  final int count;
  final double amount;

  OrderTypeCountAmount({this.count = 0, this.amount = 0.0});

  factory OrderTypeCountAmount.fromJson(Map<String, dynamic>? json) {
    if (json == null) return OrderTypeCountAmount();
    return OrderTypeCountAmount(
      count: (json['count'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OrderTypeStatsData {
  final OrderTypeCountAmount dineIn;
  final OrderTypeCountAmount delivery;
  final OrderTypeCountAmount takeaway;
  final OrderTypeCountAmount total;

  OrderTypeStatsData({
    required this.dineIn,
    required this.delivery,
    required this.takeaway,
    required this.total,
  });

  factory OrderTypeStatsData.fromJson(Map<String, dynamic> json) {
    return OrderTypeStatsData(
      dineIn: OrderTypeCountAmount.fromJson(json['dineIn'] as Map<String, dynamic>?),
      delivery: OrderTypeCountAmount.fromJson(json['delivery'] as Map<String, dynamic>?),
      takeaway: OrderTypeCountAmount.fromJson(json['takeaway'] as Map<String, dynamic>?),
      total: OrderTypeCountAmount.fromJson(json['total'] as Map<String, dynamic>?),
    );
  }

  factory OrderTypeStatsData.empty() {
    return OrderTypeStatsData(
      dineIn: OrderTypeCountAmount(),
      delivery: OrderTypeCountAmount(),
      takeaway: OrderTypeCountAmount(),
      total: OrderTypeCountAmount(),
    );
  }
}

class ItemSaleReportItem {
  final int srNo;
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final double totalAmount;

  ItemSaleReportItem({
    required this.srNo,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.totalAmount,
  });

  factory ItemSaleReportItem.fromJson(Map<String, dynamic> json) {
    return ItemSaleReportItem(
      srNo: (json['srNo'] as num?)?.toInt() ?? 0,
      productId: json['productId']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CustomerInsightItem {
  final String name;
  final String phone;
  final int visitCount;

  CustomerInsightItem({
    required this.name,
    required this.phone,
    required this.visitCount,
  });

  factory CustomerInsightItem.fromJson(Map<String, dynamic> json) {
    return CustomerInsightItem(
      name: json['name']?.toString() ?? 'Unknown',
      phone: json['phone']?.toString() ?? '',
      visitCount: (json['visitCount'] as num?)?.toInt() ?? 1,
    );
  }
}

class CustomerAnalyticsData {
  final List<CustomerInsightItem> newCustomers;
  final List<CustomerInsightItem> returningCustomers;

  CustomerAnalyticsData({
    this.newCustomers = const [],
    this.returningCustomers = const [],
  });

  factory CustomerAnalyticsData.fromJson(Map<String, dynamic> json) {
    final newList = json['newCustomers'] as List<dynamic>? ?? [];
    final retList = json['returningCustomers'] as List<dynamic>? ?? [];
    return CustomerAnalyticsData(
      newCustomers: newList.map((c) => CustomerInsightItem.fromJson(c as Map<String, dynamic>)).toList(),
      returningCustomers: retList.map((c) => CustomerInsightItem.fromJson(c as Map<String, dynamic>)).toList(),
    );
  }
}

class PaymentMethodSaleItem {
  final String method;
  final int count;
  final double amount;

  PaymentMethodSaleItem({
    required this.method,
    required this.count,
    required this.amount,
  });

  factory PaymentMethodSaleItem.fromJson(Map<String, dynamic> json) {
    return PaymentMethodSaleItem(
      method: json['method']?.toString() ?? 'OTHER',
      count: (json['count'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PaymentMethodsSummaryData {
  final List<PaymentMethodSaleItem> payments;
  final double totalAmount;

  PaymentMethodsSummaryData({
    this.payments = const [],
    this.totalAmount = 0.0,
  });

  factory PaymentMethodsSummaryData.fromJson(Map<String, dynamic> json) {
    final list = json['payments'] as List<dynamic>? ?? [];
    return PaymentMethodsSummaryData(
      payments: list.map((p) => PaymentMethodSaleItem.fromJson(p as Map<String, dynamic>)).toList(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TaxSummaryData {
  final double totalGST;
  final double cgst;
  final double sgst;
  final double igst;

  TaxSummaryData({
    this.totalGST = 0.0,
    this.cgst = 0.0,
    this.sgst = 0.0,
    this.igst = 0.0,
  });

  factory TaxSummaryData.fromJson(Map<String, dynamic> json) {
    return TaxSummaryData(
      totalGST: (json['totalGST'] as num?)?.toDouble() ?? 0.0,
      cgst: (json['cgst'] as num?)?.toDouble() ?? 0.0,
      sgst: (json['sgst'] as num?)?.toDouble() ?? 0.0,
      igst: (json['igst'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OrderStatsSummaryData {
  final int successfulOrders;
  final int cancelledOrders;
  final int otherOrders;
  final int totalOrders;

  OrderStatsSummaryData({
    this.successfulOrders = 0,
    this.cancelledOrders = 0,
    this.otherOrders = 0,
    this.totalOrders = 0,
  });

  factory OrderStatsSummaryData.fromJson(Map<String, dynamic> json) {
    return OrderStatsSummaryData(
      successfulOrders: (json['successfulOrders'] as num?)?.toInt() ?? 0,
      cancelledOrders: (json['cancelledOrders'] as num?)?.toInt() ?? 0,
      otherOrders: (json['otherOrders'] as num?)?.toInt() ?? 0,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
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

  Map<String, dynamic> _buildQueryParams(String period, String? startDate, String? endDate) {
    final queryParams = <String, dynamic>{'period': period};
    if (startDate != null && startDate.isNotEmpty) queryParams['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) queryParams['endDate'] = endDate;
    return queryParams;
  }

  /// 1. Fetch dashboard order & revenue summary metrics
  Future<DashboardSummaryData> fetchSummary({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.dashboardSummary,
        queryParameters: _buildQueryParams(period, startDate, endDate),
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

  /// 2. Fetch order types breakdown (Dine In, Delivery, Takeaway, Total)
  Future<OrderTypeStatsData> fetchOrderTypes({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.dashboardOrderTypes,
        queryParameters: _buildQueryParams(period, startDate, endDate),
      );

      if (response != null && response['data'] != null) {
        return OrderTypeStatsData.fromJson(response['data'] as Map<String, dynamic>);
      }
      return OrderTypeStatsData.empty();
    } catch (e) {
      debugPrint('[DashboardService.fetchOrderTypes] error: $e');
      return OrderTypeStatsData.empty();
    }
  }

  /// 3. Fetch item/product sales report
  Future<List<ItemSaleReportItem>> fetchProductSales({
    String period = 'Today',
    String? startDate,
    String? endDate,
    String? orderType,
  }) async {
    try {
      final params = _buildQueryParams(period, startDate, endDate);
      if (orderType != null && orderType.isNotEmpty && orderType != 'All') {
        params['orderType'] = orderType;
      }

      final response = await _apiClient.get(
        ApiEndpoints.dashboardProductSales,
        queryParameters: params,
      );

      if (response != null && response['data'] != null && response['data']['items'] != null) {
        final list = response['data']['items'] as List<dynamic>;
        return list.map((i) => ItemSaleReportItem.fromJson(i as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[DashboardService.fetchProductSales] error: $e');
      return [];
    }
  }

  /// 4. Fetch customer analytics (New vs Returning)
  Future<CustomerAnalyticsData> fetchCustomers({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.dashboardCustomers,
        queryParameters: _buildQueryParams(period, startDate, endDate),
      );

      if (response != null && response['data'] != null) {
        return CustomerAnalyticsData.fromJson(response['data'] as Map<String, dynamic>);
      }
      return CustomerAnalyticsData();
    } catch (e) {
      debugPrint('[DashboardService.fetchCustomers] error: $e');
      return CustomerAnalyticsData();
    }
  }

  /// 5. Fetch payment methods breakdown (Cash, Card, UPI, etc.)
  Future<PaymentMethodsSummaryData> fetchPaymentMethods({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.dashboardPaymentMethods,
        queryParameters: _buildQueryParams(period, startDate, endDate),
      );

      if (response != null && response['data'] != null) {
        return PaymentMethodsSummaryData.fromJson(response['data'] as Map<String, dynamic>);
      }
      return PaymentMethodsSummaryData();
    } catch (e) {
      debugPrint('[DashboardService.fetchPaymentMethods] error: $e');
      return PaymentMethodsSummaryData();
    }
  }

  /// 6. Fetch taxes summary (GST, CGST, SGST, IGST)
  Future<TaxSummaryData> fetchTaxes({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.dashboardTaxes,
        queryParameters: _buildQueryParams(period, startDate, endDate),
      );

      if (response != null && response['data'] != null) {
        return TaxSummaryData.fromJson(response['data'] as Map<String, dynamic>);
      }
      return TaxSummaryData();
    } catch (e) {
      debugPrint('[DashboardService.fetchTaxes] error: $e');
      return TaxSummaryData();
    }
  }

  /// 7. Fetch order status statistics (Successful, Cancelled, Total)
  Future<OrderStatsSummaryData> fetchOrderStats({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _apiClient.get(
        ApiEndpoints.dashboardOrderStats,
        queryParameters: _buildQueryParams(period, startDate, endDate),
      );

      if (response != null && response['data'] != null) {
        return OrderStatsSummaryData.fromJson(response['data'] as Map<String, dynamic>);
      }
      return OrderStatsSummaryData();
    } catch (e) {
      debugPrint('[DashboardService.fetchOrderStats] error: $e');
      return OrderStatsSummaryData();
    }
  }

  /// 8. Fetch chart data points
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
