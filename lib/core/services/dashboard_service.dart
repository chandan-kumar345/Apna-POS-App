import 'dart:math' as math;
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

class DashboardOverviewData {
  final DashboardSummaryData summary;
  final OrderTypeStatsData orderTypes;
  final List<ItemSaleReportItem> productSales;
  final CustomerAnalyticsData customers;
  final PaymentMethodsSummaryData paymentMethods;
  final TaxSummaryData taxes;
  final OrderStatsSummaryData orderStats;

  DashboardOverviewData({
    required this.summary,
    required this.orderTypes,
    required this.productSales,
    required this.customers,
    required this.paymentMethods,
    required this.taxes,
    required this.orderStats,
  });

  factory DashboardOverviewData.fromJson(Map<String, dynamic> json) {
    final rawSummary = json['summary'] as Map<String, dynamic>? ?? {};
    final rawOrderTypes = json['orderTypes'] as Map<String, dynamic>? ?? {};
    final rawProducts = json['productSales'] as List<dynamic>? ?? [];
    final rawCustomers = json['customers'] as Map<String, dynamic>? ?? {};
    final rawPayments = json['paymentMethods'] as Map<String, dynamic>? ?? {};
    final rawTaxes = json['taxes'] as Map<String, dynamic>? ?? {};
    final rawOrderStats = json['orderStats'] as Map<String, dynamic>? ?? {};

    return DashboardOverviewData(
      summary: DashboardSummaryData.fromJson(rawSummary),
      orderTypes: OrderTypeStatsData.fromJson(rawOrderTypes),
      productSales: rawProducts
          .whereType<Map<String, dynamic>>()
          .map((p) => ItemSaleReportItem.fromJson(p))
          .toList(),
      customers: CustomerAnalyticsData.fromJson(rawCustomers),
      paymentMethods: PaymentMethodsSummaryData.fromJson(rawPayments),
      taxes: TaxSummaryData.fromJson(rawTaxes),
      orderStats: OrderStatsSummaryData.fromJson(rawOrderStats),
    );
  }
}

class DashboardService {
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();
  final ReportService _reportService = ReportService();
  DatabaseService get _db => DatabaseService();

  Map<String, dynamic> _buildQueryParams(String period, String? startDate, String? endDate) {
    final queryParams = <String, dynamic>{'period': period};
    if (startDate != null && startDate.isNotEmpty) queryParams['startDate'] = startDate;
    if (endDate != null && endDate.isNotEmpty) queryParams['endDate'] = endDate;
    return queryParams;
  }

  (DateTime?, DateTime?) _parseDateRange({String? period, String? startDate, String? endDate}) {
    DateTime? start;
    DateTime? end;
    if (startDate != null && startDate.isNotEmpty) {
      final s = DateTime.tryParse(startDate);
      if (s != null) {
        start = s.isUtc ? s.toLocal() : s;
      }
    }
    if (endDate != null && endDate.isNotEmpty) {
      final e = DateTime.tryParse(endDate);
      if (e != null) {
        end = e.isUtc ? e.toLocal() : e;
      }
    }

    if (start == null || end == null) {
      final now = DateTime.now();
      final p = (period ?? 'Today').toLowerCase().trim();
      if (p == 'today') {
        start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      } else if (p == 'yesterday') {
        final y = now.subtract(const Duration(days: 1));
        start = DateTime(y.year, y.month, y.day, 0, 0, 0);
        end = DateTime(y.year, y.month, y.day, 23, 59, 59, 999);
      } else if (p == 'thisweek' || p == 'week' || p == 'this week') {
        final diff = (now.weekday == 7 ? 6 : now.weekday - 1);
        final mon = now.subtract(Duration(days: diff));
        start = DateTime(mon.year, mon.month, mon.day, 0, 0, 0);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      } else if (p == 'thismonth' || p == 'month' || p == 'this month') {
        start = DateTime(now.year, now.month, 1, 0, 0, 0);
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        end = DateTime(now.year, now.month, lastDay, 23, 59, 59, 999);
      } else if (p == 'thisyear' || p == 'year' || p == 'this year') {
        start = DateTime(now.year, 1, 1, 0, 0, 0);
        end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
      } else if (p == 'all time' || p == 'all' || p == 'alltime') {
        start = DateTime(2020, 1, 1, 0, 0, 0);
        end = DateTime(now.year + 1, 12, 31, 23, 59, 59, 999);
      }
    }
    return (start, end);
  }

  /// Converts authoritative SalesReportData into DashboardOverviewData for complete cross-screen parity
  DashboardOverviewData buildOverviewFromSalesReport(
    SalesReportData report, {
    String period = 'Today',
    DateTime? start,
    DateTime? end,
  }) {
    final allOrders = _db.deduplicateOrdersList(_db.orders);
    final activeOrders = allOrders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.preparing).toList();

    // 1. Summary
    final summary = DashboardSummaryData(
      period: period,
      revenue: report.summary.totalRevenue,
      totalOrders: report.summary.totalOrders,
      activeOrdersCount: activeOrders.length,
      totalProductsCount: _db.menuItems.length,
      topProducts: report.topProducts,
    );

    // 2. Order Types
    int dineInCount = 0;
    double dineInAmount = 0.0;
    int deliveryCount = 0;
    double deliveryAmount = 0.0;
    int takeawayCount = 0;
    double takeawayAmount = 0.0;

    for (final ot in report.salesByOrderType) {
      final t = ot.type.toLowerCase();
      if (t.contains('dine')) {
        dineInCount += ot.count;
        dineInAmount += ot.amount;
      } else if (t.contains('delivery') || t.contains('deliv')) {
        deliveryCount += ot.count;
        deliveryAmount += ot.amount;
      } else if (t.contains('takeaway') || t.contains('take')) {
        takeawayCount += ot.count;
        takeawayAmount += ot.amount;
      }
    }

    final orderTypes = OrderTypeStatsData(
      dineIn: OrderTypeCountAmount(count: dineInCount, amount: dineInAmount),
      delivery: OrderTypeCountAmount(count: deliveryCount, amount: deliveryAmount),
      takeaway: OrderTypeCountAmount(count: takeawayCount, amount: takeawayAmount),
      total: OrderTypeCountAmount(count: report.summary.totalOrders, amount: report.summary.totalRevenue),
    );

    // 3. Product Sales List
    final List<ItemSaleReportItem> productSales = [];
    for (int i = 0; i < report.topProducts.length; i++) {
      final tp = report.topProducts[i];
      final price = tp.quantity > 0 ? (tp.revenue / tp.quantity) : 0.0;
      productSales.add(ItemSaleReportItem(
        srNo: i + 1,
        productId: '',
        productName: tp.name,
        price: price,
        quantity: tp.quantity,
        totalAmount: tp.revenue,
      ));
    }

    // 4. Payment Methods
    final List<PaymentMethodSaleItem> payList = report.paymentModes.map((p) {
      String m = p.mode.toUpperCase();
      if (m.contains('CASH')) {
        m = 'CASH';
      } else if (m.contains('CARD') || m.contains('DEBIT') || m.contains('CREDIT')) {
        m = 'CARD';
      } else if (m.contains('UPI') || m.contains('QR') || m.contains('ONLINE')) {
        m = 'UPI';
      } else if (m.contains('WALLET')) {
        m = 'WALLET';
      } else {
        m = 'OTHER';
      }
      return PaymentMethodSaleItem(
        method: m,
        count: p.count,
        amount: p.amount,
      );
    }).toList();

    final paymentMethods = PaymentMethodsSummaryData(
      payments: payList,
      totalAmount: report.summary.totalRevenue,
    );

    // 5. Taxes
    final half = report.summary.totalTax / 2;
    final taxes = TaxSummaryData(
      totalGST: report.summary.totalTax,
      cgst: report.summary.cgst > 0 ? report.summary.cgst : half,
      sgst: report.summary.sgst > 0 ? report.summary.sgst : half,
      igst: report.summary.igst,
    );

    // 6. Customers
    bool isSameCust(OrderModel o1, String targetPhone, String targetName) {
      final p1 = (o1.customerPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
      final p2 = targetPhone.replaceAll(RegExp(r'[^0-9]'), '');
      if (p1.isNotEmpty && p2.isNotEmpty) {
        final sub1 = p1.length >= 10 ? p1.substring(p1.length - 10) : p1;
        final sub2 = p2.length >= 10 ? p2.substring(p2.length - 10) : p2;
        return sub1 == sub2;
      }
      if (targetName.isNotEmpty && targetName != 'Customer' && targetName != 'Guest Customer') {
        return (o1.customerName ?? '').trim().toLowerCase() == targetName.trim().toLowerCase();
      }
      return false;
    }

    final Map<String, CustomerInsightItem> custMap = {};
    final dbCusts = DatabaseService().customers;

    for (final o in report.orders) {
      if (o.status == OrderStatus.cancelled) continue;
      final name = (o.customerName ?? '').trim();
      final phone = (o.customerPhone ?? '').trim();
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final p10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
      final key = p10.isNotEmpty ? p10 : (name.isNotEmpty && name != 'Customer' ? name.toLowerCase() : '');
      if (key.isEmpty) continue;

      if (!custMap.containsKey(key)) {
        final totalVisits = allOrders.where((ao) {
          if (ao.status == OrderStatus.cancelled) return false;
          return isSameCust(ao, phone, name);
        }).length;

        int baselineOrders = 0;
        for (final c in dbCusts) {
          final cClean = c.phone.replaceAll(RegExp(r'[^0-9]'), '');
          final c10 = cClean.length >= 10 ? cClean.substring(cClean.length - 10) : cClean;
          if ((p10.isNotEmpty && c10 == p10) || (name.isNotEmpty && name != 'Customer' && c.name.trim().toLowerCase() == name.toLowerCase())) {
            baselineOrders = math.max(baselineOrders, c.totalOrders);
          }
        }

        final effVisits = math.max(totalVisits, baselineOrders);

        custMap[key] = CustomerInsightItem(
          name: name.isNotEmpty ? name : 'Customer',
          phone: phone,
          visitCount: effVisits > 0 ? effVisits : 1,
        );
      }
    }

    final List<CustomerInsightItem> localNewCust = [];
    final List<CustomerInsightItem> localRetCust = [];
    for (final c in custMap.values) {
      if (c.visitCount > 1) {
        localRetCust.add(c);
      } else {
        localNewCust.add(c);
      }
    }

    final customers = CustomerAnalyticsData(
      newCustomers: localNewCust,
      returningCustomers: localRetCust,
    );

    // 7. Order Stats
    final allInRange = (start != null && end != null)
        ? allOrders.where((o) {
            final oDate = o.createdDateTime.toLocal();
            return !oDate.isBefore(start) && !oDate.isAfter(end);
          }).toList()
        : allOrders;

    final nonCancelledInRange = allInRange.where((o) => o.status != OrderStatus.cancelled).toList();
    final successfulCount = nonCancelledInRange.where((o) => o.status == OrderStatus.completed || o.isPaid || o.paymentStatus.toLowerCase() == 'paid').length;
    final cancelledCount = allInRange.where((o) => o.status == OrderStatus.cancelled).length;
    final otherCount = nonCancelledInRange.length - successfulCount;

    final orderStats = OrderStatsSummaryData(
      successfulOrders: successfulCount,
      cancelledOrders: cancelledCount,
      otherOrders: otherCount,
      totalOrders: nonCancelledInRange.length,
    );

    return DashboardOverviewData(
      summary: summary,
      orderTypes: orderTypes,
      productSales: productSales,
      customers: customers,
      paymentMethods: paymentMethods,
      taxes: taxes,
      orderStats: orderStats,
    );
  }

  /// Single unified request fetching complete dashboard overview bundle with guaranteed parity
  Future<DashboardOverviewData> fetchOverview({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    final (start, end) = _parseDateRange(period: period, startDate: startDate, endDate: endDate);
    final salesReport = await _reportService.fetchSalesReport(
      period: period,
      startDate: startDate ?? (start != null ? start.toUtc().toIso8601String() : null),
      endDate: endDate ?? (end != null ? end.toUtc().toIso8601String() : null),
    );
    return buildOverviewFromSalesReport(salesReport, period: period, start: start, end: end);
  }

  /// Instant cached overview from synchronized local database
  DashboardOverviewData getLocalOverview({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) {
    final (start, end) = _parseDateRange(period: period, startDate: startDate, endDate: endDate);
    final salesReport = _reportService.getLocalSalesReport(
      period: period,
      startDate: startDate ?? (start != null ? start.toUtc().toIso8601String() : null),
      endDate: endDate ?? (end != null ? end.toUtc().toIso8601String() : null),
    );
    return buildOverviewFromSalesReport(salesReport, period: period, start: start, end: end);
  }

  /// 1. Fetch dashboard order & revenue summary metrics
  Future<DashboardSummaryData> fetchSummary({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    final overview = await fetchOverview(period: period, startDate: startDate, endDate: endDate);
    return overview.summary;
  }

  /// 2. Fetch order types breakdown (Dine In, Delivery, Takeaway, Total)
  Future<OrderTypeStatsData> fetchOrderTypes({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    final overview = await fetchOverview(period: period, startDate: startDate, endDate: endDate);
    return overview.orderTypes;
  }

  /// 3. Fetch item/product sales report
  Future<List<ItemSaleReportItem>> fetchProductSales({
    String period = 'Today',
    String? startDate,
    String? endDate,
    String? orderType,
  }) async {
    final overview = await fetchOverview(period: period, startDate: startDate, endDate: endDate);
    return overview.productSales;
  }

  /// 4. Fetch customer analytics (New vs Returning)
  Future<CustomerAnalyticsData> fetchCustomers({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    final overview = await fetchOverview(period: period, startDate: startDate, endDate: endDate);
    return overview.customers;
  }

  /// 5. Fetch payment methods breakdown (Cash, Card, UPI, etc.)
  Future<PaymentMethodsSummaryData> fetchPaymentMethods({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    final overview = await fetchOverview(period: period, startDate: startDate, endDate: endDate);
    return overview.paymentMethods;
  }

  /// 6. Fetch taxes summary (GST, CGST, SGST, IGST)
  Future<TaxSummaryData> fetchTaxes({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    final overview = await fetchOverview(period: period, startDate: startDate, endDate: endDate);
    return overview.taxes;
  }

  /// 7. Fetch order status statistics (Successful, Cancelled, Total)
  Future<OrderStatsSummaryData> fetchOrderStats({
    String period = 'Today',
    String? startDate,
    String? endDate,
  }) async {
    final overview = await fetchOverview(period: period, startDate: startDate, endDate: endDate);
    return overview.orderStats;
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

    // Default chart data points based on local valid placed orders
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final validOrders = _db.getValidOrders();
    final avgRev = validOrders.isNotEmpty ? validOrders.fold(0.0, (sum, o) => sum + o.totalAmount) / 7 : 0.0;
    return days.map((d) => ChartPointData(label: d, revenue: avgRev, orders: (validOrders.length / 7).ceil())).toList();
  }
}
