import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
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
    await db.updateRestaurantProfile(
      RestaurantModel(
        id: 'rest_test_001',
        name: 'Test Apna POS Outlet',
        tagline: 'Best food',
        phone: '9876543210',
        address: 'Main Market',
        cuisineType: 'Multi-cuisine',
        taxRate: 5.0,
      ),
    );
    reportService = ReportService();
    dashboardService = DashboardService();
  });

  group('SuperAdmin Order Deletion and Sales Report Exclusion Tests', () {
    test('Deleting an order by orderNumber completely purges it from database and excludes it from sales reports', () async {
      final now = DateTime.now();
      final itemBurger = MenuItemModel(
        id: 'item_1',
        name: 'Crispy Burger',
        description: 'Crispy veggie burger',
        price: 150.0,
        category: 'Burgers',
        itemType: 'Veg',
      );

      final order1 = OrderModel(
        id: 'ord_uuid_001',
        orderNumber: '20261002-1001-T1',
        tableNumber: 'T1',
        orderType: OrderType.dineIn,
        items: [CartItemModel(item: itemBurger, quantity: 2)],
        subtotal: 300.0,
        taxAmount: 15.0,
        totalAmount: 315.0,
        status: OrderStatus.completed,
        isPaid: true,
        paymentStatus: 'paid',
        paymentMethod: 'Cash',
        createdAt: now.toIso8601String(),
      );

      final order2 = OrderModel(
        id: 'ord_uuid_002',
        orderNumber: '20261002-1002-T2',
        tableNumber: 'T2',
        orderType: OrderType.takeaway,
        items: [CartItemModel(item: itemBurger, quantity: 1)],
        subtotal: 150.0,
        taxAmount: 7.5,
        totalAmount: 157.5,
        status: OrderStatus.completed,
        isPaid: true,
        paymentStatus: 'paid',
        paymentMethod: 'UPI',
        createdAt: now.toIso8601String(),
      );

      // Add both orders to db
      db.orders.addAll([order1, order2]);

      expect(db.orders.length, 2);

      // Verify sales before deletion
      var salesReport = reportService.getLocalSalesReport(period: 'today');
      expect(salesReport.summary.totalOrders, 2);
      expect(salesReport.summary.totalRevenue, 315.0 + 157.5);

      var dashSummary = await dashboardService.fetchSummary(period: 'Today');
      expect(dashSummary.totalOrders, 2);
      expect(dashSummary.revenue, 315.0 + 157.5);

      // SuperAdmin deletes order1 using "#20261002-1001-T1" (with hashtag prefix)
      final deleteResult = await db.deleteOrderByOrderNumber(
        orderNumber: '#20261002-1001-T1',
        targetRestaurantId: 'rest_test_001',
      );

      expect(deleteResult, isTrue);
      expect(db.orders.length, 1);
      expect(db.orders.any((o) => o.orderNumber == '20261002-1001-T1'), isFalse);
      expect(db.orders.first.orderNumber, '20261002-1002-T2');

      // Verify sales reports immediately after deletion (Order 1 is excluded)
      salesReport = reportService.getLocalSalesReport(period: 'today');
      expect(salesReport.summary.totalOrders, 1);
      expect(salesReport.summary.totalRevenue, 157.5);

      dashSummary = await dashboardService.fetchSummary(period: 'Today');
      expect(dashSummary.totalOrders, 1);
      expect(dashSummary.revenue, 157.5);

      // SuperAdmin deletes order2 using raw orderNumber without hashtag
      final deleteResult2 = await db.deleteOrderByOrderNumber(
        orderNumber: '20261002-1002-T2',
        targetRestaurantId: 'rest_test_001',
      );

      expect(deleteResult2, isTrue);
      expect(db.orders.length, 0);

      // Verify sales reports after deleting all orders
      salesReport = reportService.getLocalSalesReport(period: 'today');
      expect(salesReport.summary.totalOrders, 0);
      expect(salesReport.summary.totalRevenue, 0.0);

      dashSummary = await dashboardService.fetchSummary(period: 'Today');
      expect(dashSummary.totalOrders, 0);
      expect(dashSummary.revenue, 0.0);
    });

    test('Deleting an order by ID or case-insensitive orderNumber works cleanly', () async {
      final now = DateTime.now();
      final itemPizza = MenuItemModel(
        id: 'item_2',
        name: 'Farmhouse Pizza',
        description: 'Cheesy farmhouse pizza',
        price: 250.0,
        category: 'Pizza',
        itemType: 'Veg',
      );

      final order = OrderModel(
        id: 'ord_custom_uuid_999',
        orderNumber: 'ORD-2026-ABC',
        tableNumber: 'T5',
        orderType: OrderType.dineIn,
        items: [CartItemModel(item: itemPizza, quantity: 1)],
        subtotal: 250.0,
        taxAmount: 12.5,
        totalAmount: 262.5,
        status: OrderStatus.completed,
        isPaid: true,
        paymentStatus: 'paid',
        paymentMethod: 'Card',
        createdAt: now.toIso8601String(),
      );

      db.orders.add(order);
      expect(db.orders.length, 1);

      // Delete by lowercase order number with prefix
      final deleted = await db.deleteOrderByOrderNumber(
        orderNumber: '#ord-2026-abc',
        targetRestaurantId: 'rest_test_001',
      );

      expect(deleted, isTrue);
      expect(db.orders.isEmpty, isTrue);
    });
  });
}
