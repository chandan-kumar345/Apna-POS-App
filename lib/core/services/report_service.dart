import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../database/database_service.dart';
import 'auth_service.dart';

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
  final AuthService _authService = AuthService();
  final DatabaseService _db = DatabaseService();

  /// Unified Authoritative Sales Report API (with seamless offline calculation fallback)
  Future<SalesReportData> fetchSalesReport({
    String? period,
    String? startDate,
    String? endDate,
    String? fromDate,
    String? toDate,
    int limit = 500,
  }) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
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
      }
    } catch (e) {
      if (!e.toString().contains('Authorization') && !e.toString().contains('401')) {
        debugPrint('[ReportService.fetchSalesReport] API warning: $e');
      }
    }

    // Graceful offline computation from synchronized local database orders
    return _buildLocalSalesReport(period: period, startDate: startDate ?? fromDate, endDate: endDate ?? toDate);
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
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
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
      }
    } catch (e) {
      if (!e.toString().contains('Authorization') && !e.toString().contains('401')) {
        debugPrint('[ReportService.fetchSales] API warning: $e');
      }
    }

    // Filter local completed orders
    final settled = _db.orders.where((o) => o.status == OrderStatus.completed || o.isPaid).toList();
    return settled;
  }

  /// Fetch sales summary
  Future<SalesSummaryData> fetchSalesSummary({String? startDate, String? endDate}) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
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
      }
    } catch (e) {
      if (!e.toString().contains('Authorization') && !e.toString().contains('401')) {
        debugPrint('[ReportService.fetchSalesSummary] API warning: $e');
      }
    }

    // Local summary computation
    final settled = _db.orders.where((o) => o.status == OrderStatus.completed || o.isPaid).toList();
    double totalRev = 0;
    double cash = 0;
    double upi = 0;
    double card = 0;
    double tax = 0;
    double disc = 0;

    for (final o in settled) {
      totalRev += o.totalAmount;
      tax += o.taxAmount;
      disc += o.discountAmount;
      final pm = o.paymentMethod.toLowerCase();
      if (pm.contains('cash')) {
        cash += o.totalAmount;
      } else if (pm.contains('upi')) {
        upi += o.totalAmount;
      } else if (pm.contains('card')) {
        card += o.totalAmount;
      } else {
        upi += o.totalAmount;
      }
    }

    return SalesSummaryData(
      totalRevenue: totalRev,
      totalSubtotal: totalRev - tax + disc,
      totalTax: tax,
      totalDiscount: disc,
      totalOrders: settled.length,
      cashSales: cash,
      upiSales: upi,
      cardSales: card,
    );
  }

  /// Fetch top products
  Future<List<TopProductData>> fetchTopProducts({int limit = 10, String? startDate, String? endDate}) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
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
      }
    } catch (e) {
      if (!e.toString().contains('Authorization') && !e.toString().contains('401')) {
        debugPrint('[ReportService.fetchTopProducts] API warning: $e');
      }
    }

    // Local top products calculation
    final settled = _db.orders.where((o) => o.status == OrderStatus.completed || o.isPaid).toList();
    final Map<String, TopProductData> map = {};
    for (final o in settled) {
      for (final item in o.items) {
        final key = item.item.name;
        final existing = map[key];
        final qty = (existing?.quantity ?? 0) + item.quantity;
        final rev = (existing?.revenue ?? 0) + (item.item.effectivePrice * item.quantity);
        map[key] = TopProductData(
          name: key,
          quantity: qty,
          revenue: rev,
          foodType: item.item.itemType.toLowerCase().replaceAll('-', '_'),
        );
      }
    }
    final list = map.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));
    return list.take(limit).toList();
  }

  /// Local calculation fallback for SalesReportData
  SalesReportData _buildLocalSalesReport({String? period, String? startDate, String? endDate}) {
    DateTime? start;
    DateTime? end;
    if (startDate != null && startDate.isNotEmpty) start = DateTime.tryParse(startDate);
    if (endDate != null && endDate.isNotEmpty) end = DateTime.tryParse(endDate);

    final settled = _db.orders.where((o) {
      if (o.status != OrderStatus.completed && !o.isPaid) return false;
      if (start != null && o.createdDateTime.isBefore(start)) return false;
      if (end != null && o.createdDateTime.isAfter(end)) return false;
      return true;
    }).toList();

    double totalRev = 0;
    double totalTax = 0;
    double totalDisc = 0;
    int totalItems = 0;

    final Map<String, double> pmMap = {};
    final Map<String, int> pmCount = {};
    final Map<String, double> otMap = {};
    final Map<String, int> otCount = {};
    final Map<String, TopProductData> prodMap = {};

    for (final o in settled) {
      totalRev += o.totalAmount;
      totalTax += o.taxAmount;
      totalDisc += o.discountAmount;

      for (final i in o.items) {
        totalItems += i.quantity;
        final key = i.item.name;
        final existing = prodMap[key];
        final q = (existing?.quantity ?? 0) + i.quantity;
        final r = (existing?.revenue ?? 0) + (i.item.effectivePrice * i.quantity);
        prodMap[key] = TopProductData(name: key, quantity: q, revenue: r, foodType: i.item.itemType.toLowerCase().replaceAll('-', '_'));
      }

      final pm = o.paymentMethod.isNotEmpty ? o.paymentMethod : 'Cash';
      pmMap[pm] = (pmMap[pm] ?? 0.0) + o.totalAmount;
      pmCount[pm] = (pmCount[pm] ?? 0) + 1;

      final ot = o.orderType == OrderType.dineIn ? 'Dine In' : o.orderType == OrderType.takeaway ? 'Takeaway' : 'Delivery';
      otMap[ot] = (otMap[ot] ?? 0.0) + o.totalAmount;
      otCount[ot] = (otCount[ot] ?? 0) + 1;
    }

    final gross = totalRev - totalTax + totalDisc;
    final halfTax = totalTax / 2;

    final summary = SalesReportSummary(
      totalRevenue: totalRev,
      grossSales: gross,
      netSales: totalRev - totalTax,
      totalOrders: settled.length,
      totalItems: totalItems,
      totalDiscount: totalDisc,
      totalTax: totalTax,
      cgst: halfTax,
      sgst: halfTax,
      igst: 0.0,
      avgOrderValue: settled.isNotEmpty ? totalRev / settled.length : 0.0,
    );

    final paymentModes = pmMap.entries.map((e) {
      return PaymentModeStat(
        mode: e.key,
        rawMode: e.key.toLowerCase(),
        count: pmCount[e.key] ?? 0,
        amount: e.value,
        percentage: totalRev > 0 ? (e.value / totalRev) * 100 : 0.0,
      );
    }).toList();

    final salesByOrderType = otMap.entries.map((e) {
      return OrderTypeStat(
        type: e.key,
        rawType: e.key.toLowerCase(),
        count: otCount[e.key] ?? 0,
        amount: e.value,
      );
    }).toList();

    final topProds = prodMap.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));

    return SalesReportData(
      summary: summary,
      paymentModes: paymentModes,
      salesByOrderType: salesByOrderType,
      topProducts: topProds.take(15).toList(),
      orders: settled,
      period: period ?? 'allTime',
      startDate: startDate ?? '',
      endDate: endDate ?? '',
    );
  }
}
