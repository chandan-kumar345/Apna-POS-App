import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/services/report_service.dart';
import 'package:apna_pos/core/services/dashboard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;
  late ReportService reportService;
  late DashboardService dashboardService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = DatabaseService();
    await db.init();
    db.orders.clear();
    reportService = ReportService();
    dashboardService = DashboardService();
  });

  group('Dashboard and Sales Report Data Parity Tests', () {
    test('Parity on empty database', () async {
      final report = reportService.getLocalSalesReport(period: 'today');
      final dashboardSummary = await dashboardService.fetchSummary(period: 'Today');
      final dashboardPayments = await dashboardService.fetchPaymentMethods(period: 'Today');
      final dashboardTaxes = await dashboardService.fetchTaxes(period: 'Today');
      final dashboardOrderTypes = await dashboardService.fetchOrderTypes(period: 'Today');

      expect(report.summary.totalRevenue, 0.0);
      expect(dashboardSummary.revenue, 0.0);
      expect(report.summary.totalOrders, 0);
      expect(dashboardSummary.totalOrders, 0);
      expect(report.paymentModes, isEmpty);
      expect(dashboardPayments.payments, isEmpty);
      expect(report.summary.totalTax, 0.0);
      expect(dashboardTaxes.totalGST, 0.0);
      expect(dashboardOrderTypes.total.count, 0);
    });

    test('Parity with settled, cancelled, and pending orders across date ranges', () async {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day, 12, 0, 0);
      final yesterdayDate = todayDate.subtract(const Duration(days: 1));
      final lastMonthDate = DateTime(now.year, now.month - 1, 15, 12, 0, 0);

      final burger = MenuItemModel(
        id: 'item_burger',
        name: 'Veggie Burger',
        description: 'Tasty veggie burger',
        price: 100.0,
        category: 'Fast Food',
        itemType: 'Veg',
      );
      final pizza = MenuItemModel(
        id: 'item_pizza',
        name: 'Cheese Pizza',
        description: 'Delicious cheese pizza',
        price: 250.0,
        category: 'Fast Food',
        itemType: 'Veg',
      );

      // 1. Order 1: Today, completed, Dine-In, Cash, Total = 200, Tax = 10, Discount = 0
      final order1 = OrderModel(
        id: 'ord_1',
        orderNumber: 'ORD-001',
        tableNumber: 'T1',
        orderType: OrderType.dineIn,
        status: OrderStatus.completed,
        isPaid: true,
        paymentStatus: 'paid',
        paymentMethod: 'Cash',
        subtotal: 190.0,
        taxAmount: 10.0,
        discountAmount: 0.0,
        totalAmount: 200.0,
        createdAt: todayDate.toIso8601String(),
        items: [
          CartItemModel(item: burger, quantity: 2),
        ],
      );

      // 2. Order 2: Today, completed, Delivery, UPI, Total = 500, Tax = 25, Discount = 25
      final order2 = OrderModel(
        id: 'ord_2',
        orderNumber: 'ORD-002',
        orderType: OrderType.delivery,
        status: OrderStatus.completed,
        isPaid: true,
        paymentStatus: 'paid',
        paymentMethod: 'UPI',
        subtotal: 500.0,
        taxAmount: 25.0,
        discountAmount: 25.0,
        totalAmount: 500.0,
        createdAt: todayDate.add(const Duration(hours: 1)).toIso8601String(),
        items: [
          CartItemModel(item: pizza, quantity: 2),
        ],
      );

      // 3. Order 3: Today, CANCELLED (should be excluded from revenue and sales summary)
      final order3 = OrderModel(
        id: 'ord_3',
        orderNumber: 'ORD-003',
        orderType: OrderType.takeaway,
        status: OrderStatus.cancelled,
        isPaid: false,
        paymentStatus: 'unpaid',
        paymentMethod: 'Cash',
        subtotal: 100.0,
        taxAmount: 5.0,
        discountAmount: 0.0,
        totalAmount: 105.0,
        createdAt: todayDate.add(const Duration(hours: 2)).toIso8601String(),
        items: [
          CartItemModel(item: burger, quantity: 1),
        ],
      );

      // 4. Order 4: Today, PENDING (unpaid active KOT, should be excluded from sales reports)
      final order4 = OrderModel(
        id: 'ord_4',
        orderNumber: 'ORD-004',
        orderType: OrderType.dineIn,
        status: OrderStatus.pending,
        isPaid: false,
        paymentStatus: 'unpaid',
        paymentMethod: 'Cash',
        subtotal: 100.0,
        taxAmount: 5.0,
        discountAmount: 0.0,
        totalAmount: 105.0,
        createdAt: todayDate.add(const Duration(hours: 3)).toIso8601String(),
        items: [
          CartItemModel(item: burger, quantity: 1),
        ],
      );

      // 5. Order 5: Yesterday, completed, Takeaway, Card, Total = 300, Tax = 15, Discount = 0
      final order5 = OrderModel(
        id: 'ord_5',
        orderNumber: 'ORD-005',
        orderType: OrderType.takeaway,
        status: OrderStatus.completed,
        isPaid: true,
        paymentStatus: 'paid',
        paymentMethod: 'Card',
        subtotal: 285.0,
        taxAmount: 15.0,
        discountAmount: 0.0,
        totalAmount: 300.0,
        createdAt: yesterdayDate.toIso8601String(),
        items: [
          CartItemModel(item: burger, quantity: 3),
        ],
      );

      // 6. Order 6: Last Month, completed, Dine-in, Split, Total = 600, Tax = 30, Discount = 0
      final order6 = OrderModel(
        id: 'ord_6',
        orderNumber: 'ORD-006',
        orderType: OrderType.dineIn,
        status: OrderStatus.completed,
        isPaid: true,
        paymentStatus: 'paid',
        paymentMethod: 'Split',
        subtotal: 570.0,
        taxAmount: 30.0,
        discountAmount: 0.0,
        totalAmount: 600.0,
        createdAt: lastMonthDate.toIso8601String(),
        items: [
          CartItemModel(item: pizza, quantity: 2),
          CartItemModel(item: burger, quantity: 1),
        ],
      );

      // Save orders directly into local database
      db.orders.addAll([order1, order2, order3, order4, order5, order6]);

      // ----------------------------------------------------
      // A. Verify "Today" Filter Parity
      // ----------------------------------------------------
      final todayReport = reportService.getLocalSalesReport(period: 'today');
      final todayDashSummary = await dashboardService.fetchSummary(period: 'Today');
      final todayDashPayments = await dashboardService.fetchPaymentMethods(period: 'Today');
      final todayDashTaxes = await dashboardService.fetchTaxes(period: 'Today');
      final todayDashOrderTypes = await dashboardService.fetchOrderTypes(period: 'Today');

      // Total orders: exactly 2 (order1 and order2)
      expect(todayReport.summary.totalOrders, 2);
      expect(todayDashSummary.totalOrders, 2);

      // Total revenue: 200 + 500 = 700
      expect(todayReport.summary.totalRevenue, 700.0);
      expect(todayDashSummary.revenue, 700.0);

      // Total taxes: 10 + 25 = 35
      expect(todayReport.summary.totalTax, 35.0);
      expect(todayDashTaxes.totalGST, 35.0);

      // Payment breakdown: Cash 200, UPI 500
      expect(todayDashPayments.totalAmount, 700.0);
      final cashStat = todayReport.paymentModes.firstWhere((p) => p.mode.toLowerCase().contains('cash'));
      final upiStat = todayReport.paymentModes.firstWhere((p) => p.mode.toLowerCase().contains('upi'));
      expect(cashStat.amount, 200.0);
      expect(upiStat.amount, 500.0);

      // Order types: Dine-In (1, 200), Delivery (1, 500), Takeaway (0, 0)
      expect(todayDashOrderTypes.dineIn.count, 1);
      expect(todayDashOrderTypes.dineIn.amount, 200.0);
      expect(todayDashOrderTypes.delivery.count, 1);
      expect(todayDashOrderTypes.delivery.amount, 500.0);
      expect(todayDashOrderTypes.takeaway.count, 0);
      expect(todayDashOrderTypes.total.count, 2);
      expect(todayDashOrderTypes.total.amount, 700.0);

      // ----------------------------------------------------
      // B. Verify "Yesterday" Filter Parity
      // ----------------------------------------------------
      final yestReport = reportService.getLocalSalesReport(period: 'yesterday');
      final yestDashSummary = await dashboardService.fetchSummary(period: 'Yesterday');
      final yestDashPayments = await dashboardService.fetchPaymentMethods(period: 'Yesterday');
      final yestDashTaxes = await dashboardService.fetchTaxes(period: 'Yesterday');

      // Total orders: exactly 1 (order5)
      expect(yestReport.summary.totalOrders, 1);
      expect(yestDashSummary.totalOrders, 1);

      // Total revenue: 300
      expect(yestReport.summary.totalRevenue, 300.0);
      expect(yestDashSummary.revenue, 300.0);

      // Total tax: 15
      expect(yestReport.summary.totalTax, 15.0);
      expect(yestDashTaxes.totalGST, 15.0);

      // Payment: Card 300
      expect(yestDashPayments.totalAmount, 300.0);
      expect(yestReport.paymentModes.first.amount, 300.0);

      // ----------------------------------------------------
      // C. Verify "All Time" Filter Parity
      // ----------------------------------------------------
      final allReport = reportService.getLocalSalesReport(period: 'allTime');
      final allDashSummary = await dashboardService.fetchSummary(period: 'All Time');
      final allDashTaxes = await dashboardService.fetchTaxes(period: 'All Time');

      // Total completed orders: 4 (order1, order2, order5, order6)
      expect(allReport.summary.totalOrders, 4);
      expect(allDashSummary.totalOrders, 4);

      // Total revenue: 200 + 500 + 300 + 600 = 1600
      expect(allReport.summary.totalRevenue, 1600.0);
      expect(allDashSummary.revenue, 1600.0);

      // Total taxes: 10 + 25 + 15 + 30 = 80
      expect(allReport.summary.totalTax, 80.0);
      expect(allDashTaxes.totalGST, 80.0);
    });

    test('Deduplication handles duplicate orders consistently in both reports and dashboard', () async {
      final now = DateTime.now();
      final burger = MenuItemModel(
        id: 'item_burger',
        name: 'Burger',
        description: 'Burger',
        price: 100.0,
        category: 'Fast Food',
        itemType: 'Veg',
      );

      final originalOrder = OrderModel(
        id: 'ord_dup_1',
        orderNumber: 'ORD-DUP-001',
        status: OrderStatus.completed,
        isPaid: true,
        paymentStatus: 'paid',
        paymentMethod: 'Cash',
        subtotal: 100.0,
        taxAmount: 5.0,
        discountAmount: 0.0,
        totalAmount: 105.0,
        createdAt: now.toIso8601String(),
        items: [CartItemModel(item: burger, quantity: 1)],
      );

      final duplicateOrder = OrderModel(
        id: 'ord_dup_2',
        orderNumber: 'ORD-DUP-001', // Same orderNumber
        status: OrderStatus.completed,
        isPaid: true,
        paymentStatus: 'paid',
        paymentMethod: 'Cash',
        subtotal: 100.0,
        taxAmount: 5.0,
        discountAmount: 0.0,
        totalAmount: 105.0,
        createdAt: now.toIso8601String(),
        items: [CartItemModel(item: burger, quantity: 1)],
      );

      db.orders.addAll([originalOrder, duplicateOrder]);

      final report = reportService.getLocalSalesReport(period: 'today');
      final summary = await dashboardService.fetchSummary(period: 'Today');

      // Deduplication ensures ORD-DUP-001 is counted exactly once
      expect(report.summary.totalOrders, 1);
      expect(summary.totalOrders, 1);
      expect(report.summary.totalRevenue, 105.0);
      expect(summary.revenue, 105.0);
    });
  });
}
