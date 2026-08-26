import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../models/order_model.dart';
import '../database/database_service.dart';
import 'auth_service.dart';
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

  factory ItemSaleReportItem.fromJson(Map<String, dynamic> json) => ItemSaleReportItem(
        srNo: (json['srNo'] as num?)?.toInt() ?? 1,
        productId: json['productId']?.toString() ?? '',
        productName: json['productName']?.toString() ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      );
}

class CustomerInsightItem {
  final String name;
  final String phone;
  final int visitCount;

  CustomerInsightItem({
    required this.name,
    this.phone = '',
    this.visitCount = 1,
  });

  factory CustomerInsightItem.fromJson(Map<String, dynamic> json) => CustomerInsightItem(
        name: json['name']?.toString() ?? 'Customer',
        phone: json['phone']?.toString() ?? '',
        visitCount: (json['visitCount'] as num?)?.toInt() ?? 1,
      );
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
    this.count = 0,
    this.amount = 0.0,
  });

  factory PaymentMethodSaleItem.fromJson(Map<String, dynamic> json) => PaymentMethodSaleItem(
        method: json['method']?.toString() ?? 'OTHER',
        count: (json['count'] as num?)?.toInt() ?? 0,
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      );
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
  final AuthService _authService = AuthService();
  DatabaseService get _db => DatabaseService();

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
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final response = await _apiClient.get(
          ApiEndpoints.dashboardSummary,
          queryParameters: _buildQueryParams(period, startDate, endDate),
        );

        if (response != null && response['data'] != null && response['data']['summary'] != null) {
          return DashboardSummaryData.fromJson(response['data']['summary'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      if (!e.toString().contains('Authorization') && !e.toString().contains('401')) {
        debugPrint('[DashboardService.fetchSummary] API warning: $e');
      }
    }

    // Local DB fallback
    final settled = _db.orders.where((o) => o.status == OrderStatus.completed || o.isPaid).toList();
    final active = _db.orders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.preparing).toList();
    double rev = 0;
    for (final o in settled) {
      rev += o.totalAmount;
    }
    return DashboardSummaryData(
      period: period,
      revenue: rev,
      totalOrders: settled.length,
      activeOrdersCount: active.length,
      totalProductsCount: _db.menuItems.length,
    );
  }

  /// 2. Fetch order types breakdown (Dine In, Delivery, Takeaway, Total)
  Future<OrderTypeStatsData> fetchOrderTypes({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final response = await _apiClient.get(
          ApiEndpoints.dashboardOrderTypes,
          queryParameters: _buildQueryParams(period, startDate, endDate),
        );

        if (response != null && response['data'] != null) {
          return OrderTypeStatsData.fromJson(response['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      if (!e.toString().contains('Authorization') && !e.toString().contains('401')) {
        debugPrint('[DashboardService.fetchOrderTypes] API warning: $e');
      }
    }

    // Local DB fallback
    final settled = _db.orders.where((o) => o.status == OrderStatus.completed || o.isPaid).toList();
    int dineCount = 0, delivCount = 0, takeCount = 0;
    double dineAmt = 0, delivAmt = 0, takeAmt = 0;

    for (final o in settled) {
      if (o.orderType == OrderType.dineIn) {
        dineCount++;
        dineAmt += o.totalAmount;
      } else if (o.orderType == OrderType.delivery) {
        delivCount++;
        delivAmt += o.totalAmount;
      } else {
        takeCount++;
        takeAmt += o.totalAmount;
      }
    }

    final totalCount = dineCount + delivCount + takeCount;
    final totalAmt = dineAmt + delivAmt + takeAmt;

    return OrderTypeStatsData(
      dineIn: OrderTypeCountAmount(count: dineCount, amount: dineAmt),
      delivery: OrderTypeCountAmount(count: delivCount, amount: delivAmt),
      takeaway: OrderTypeCountAmount(count: takeCount, amount: takeAmt),
      total: OrderTypeCountAmount(count: totalCount, amount: totalAmt),
    );
  }

  /// 3. Fetch item/product sales report
  Future<List<ItemSaleReportItem>> fetchProductSales({
    String period = 'Today',
    String? startDate,
    String? endDate,
    String? orderType,
  }) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
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
      }
    } catch (e) {
      if (!e.toString().contains('Authorization') && !e.toString().contains('401')) {
        debugPrint('[DashboardService.fetchProductSales] API warning: $e');
      }
    }

    final settled = _db.orders.where((o) => o.status == OrderStatus.completed || o.isPaid).toList();
    final Map<String, ItemSaleReportItem> map = {};
    int sr = 1;
    for (final o in settled) {
      for (final i in o.items) {
        final key = i.item.name;
        final existing = map[key];
        final qty = (existing?.quantity ?? 0) + i.quantity;
        final tot = (existing?.totalAmount ?? 0.0) + (i.item.effectivePrice * i.quantity);
        map[key] = ItemSaleReportItem(
          srNo: existing?.srNo ?? sr++,
          productId: i.item.id,
          productName: key,
          price: i.item.effectivePrice,
          quantity: qty,
          totalAmount: tot,
        );
      }
    }
    return map.values.toList();
  }

  /// 4. Fetch customer analytics (New vs Returning)
  Future<CustomerAnalyticsData> fetchCustomers({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final response = await _apiClient.get(
          ApiEndpoints.dashboardCustomers,
          queryParameters: _buildQueryParams(period, startDate, endDate),
        );

        if (response != null && response['data'] != null) {
          return CustomerAnalyticsData.fromJson(response['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      if (!e.toString().contains('Authorization') && !e.toString().contains('401')) {
        debugPrint('[DashboardService.fetchCustomers] API warning: $e');
      }
    }

    final totalCust = _db.customers;
    final List<CustomerInsightItem> news = [];
    final List<CustomerInsightItem> returns = [];
    for (final c in totalCust) {
      final item = CustomerInsightItem(name: c.name, phone: c.phone, visitCount: c.totalOrders);
      if (c.totalOrders > 1) {
        returns.add(item);
      } else {
        news.add(item);
      }
    }
    return CustomerAnalyticsData(
      newCustomers: news,
      returningCustomers: returns,
    );
  }

  /// 5. Fetch payment methods breakdown (Cash, Card, UPI, etc.)
  Future<PaymentMethodsSummaryData> fetchPaymentMethods({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final response = await _apiClient.get(
          ApiEndpoints.dashboardPaymentMethods,
          queryParameters: _buildQueryParams(period, startDate, endDate),
        );

        if (response != null && response['data'] != null) {
          return PaymentMethodsSummaryData.fromJson(response['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      if (!e.toString().contains('Authorization') && !e.toString().contains('401')) {
        debugPrint('[DashboardService.fetchPaymentMethods] API warning: $e');
      }
    }

    final settled = _db.orders.where((o) => o.status == OrderStatus.completed || o.isPaid).toList();
    final Map<String, Map<String, dynamic>> map = {};
    double total = 0;

    for (final o in settled) {
      total += o.totalAmount;
      var pm = o.paymentMethod.toUpperCase().trim();
      if (pm.startsWith('CASH')) {
        pm = 'CASH';
      } else if (pm.startsWith('CARD')) {
        pm = 'CARD';
      } else if (pm.startsWith('UPI')) {
        pm = 'UPI';
      } else if (pm.startsWith('SPLIT')) {
        pm = 'SPLIT';
      }
      if (pm.isEmpty) pm = 'OTHER';

      if (!map.containsKey(pm)) {
        map[pm] = {'count': 0, 'amount': 0.0};
      }
      map[pm]!['count'] = (map[pm]!['count'] as int) + 1;
      map[pm]!['amount'] = (map[pm]!['amount'] as double) + o.totalAmount;
    }

    final payList = map.entries
        .map((e) => PaymentMethodSaleItem(
              method: e.key,
              count: e.value['count'] as int,
              amount: e.value['amount'] as double,
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return PaymentMethodsSummaryData(
      payments: payList,
      totalAmount: total,
    );
  }

  /// 6. Fetch taxes summary (GST, CGST, SGST, IGST)
  Future<TaxSummaryData> fetchTaxes({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final response = await _apiClient.get(
          ApiEndpoints.dashboardTaxes,
          queryParameters: _buildQueryParams(period, startDate, endDate),
        );

        if (response != null && response['data'] != null) {
          return TaxSummaryData.fromJson(response['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      if (!e.toString().contains('Authorization') && !e.toString().contains('401')) {
        debugPrint('[DashboardService.fetchTaxes] API warning: $e');
      }
    }

    final settled = _db.orders.where((o) => o.status == OrderStatus.completed || o.isPaid).toList();
    double totalTax = 0;
    for (final o in settled) {
      totalTax += o.taxAmount;
    }
    final half = totalTax / 2;
    return TaxSummaryData(totalGST: totalTax, cgst: half, sgst: half, igst: 0.0);
  }

  /// 7. Fetch order status statistics (Successful, Cancelled, Total)
  Future<OrderStatsSummaryData> fetchOrderStats({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final response = await _apiClient.get(
          ApiEndpoints.dashboardOrderStats,
          queryParameters: _buildQueryParams(period, startDate, endDate),
        );

        if (response != null && response['data'] != null) {
          return OrderStatsSummaryData.fromJson(response['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      if (!e.toString().contains('Authorization') && !e.toString().contains('401')) {
        debugPrint('[DashboardService.fetchOrderStats] API warning: $e');
      }
    }

    final settled = _db.orders.where((o) => o.status == OrderStatus.completed || o.isPaid).length;
    final cancelled = _db.orders.where((o) => o.status == OrderStatus.cancelled).length;
    return OrderStatsSummaryData(
      successfulOrders: settled,
      cancelledOrders: cancelled,
      totalOrders: _db.orders.length,
    );
  }

  /// 8. Fetch chart data points
  Future<List<ChartPointData>> fetchChartData({String filter = 'Week'}) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final response = await _apiClient.get(
          ApiEndpoints.dashboardChart,
          queryParameters: {'filter': filter},
        );

        if (response != null && response['data'] != null && response['data']['chartPoints'] != null) {
          final raw = response['data']['chartPoints'] as List<dynamic>;
          return raw.map((c) => ChartPointData.fromJson(c as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      if (!e.toString().contains('Authorization') && !e.toString().contains('401')) {
        debugPrint('[DashboardService.fetchChartData] API warning: $e');
      }
    }

    // Default chart data points based on local settled orders
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final settled = _db.orders.where((o) => o.status == OrderStatus.completed || o.isPaid).toList();
    final avgRev = settled.isNotEmpty ? settled.fold(0.0, (sum, o) => sum + o.totalAmount) / 7 : 0.0;
    return days.map((d) => ChartPointData(label: d, revenue: avgRev, orders: (settled.length / 7).ceil())).toList();
  }
}
