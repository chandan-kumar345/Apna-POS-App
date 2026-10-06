import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/services/report_service.dart';
import 'package:apna_pos/features/settings/business_settings_hub_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Reports Date Filtering & Settings Hub Tests', () {
    final db = DatabaseService();
    final reportService = ReportService();

    setUp(() {
      db.orders.clear();
    });

    test('Strict Date Filtering: If today has 0 sales, do not show previous days orders', () {
      // Add orders from 04 Oct and 06 Oct
      final orderOct4 = OrderModel(
        id: 'ord_oct4',
        orderNumber: '20261004-220933-T1',
        createdAt: '2026-10-04T22:09:33.000',
        subtotal: 500.0,
        taxAmount: 0.0,
        totalAmount: 500.0,
        status: OrderStatus.completed,
        isPaid: true,
        paymentStatus: 'paid',
        paymentMethod: 'Cash',
        items: [],
      );

      final orderOct6 = OrderModel(
        id: 'ord_oct6',
        orderNumber: '20261006-033128-T1',
        createdAt: '2026-10-06T03:31:28.000',
        subtotal: 1266.0,
        taxAmount: 0.0,
        totalAmount: 1266.0,
        status: OrderStatus.completed,
        isPaid: true,
        paymentStatus: 'paid',
        paymentMethod: 'UPI',
        items: [],
      );

      db.orders = [orderOct4, orderOct6];

      // Request report for TODAY (assuming today is 07 Oct)
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0).toIso8601String();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toIso8601String();

      final todayReport = reportService.getLocalSalesReport(
        period: 'today',
        startDate: todayStart,
        endDate: todayEnd,
      );

      // Verify that if no sales happened today, orders list is empty and total revenue is 0
      expect(todayReport.orders.isEmpty, isTrue);
      expect(todayReport.summary.totalRevenue, equals(0.0));
      expect(todayReport.summary.totalOrders, equals(0));

      // Request report for custom date (2026-10-06)
      final oct6Report = reportService.getLocalSalesReport(
        period: 'custom',
        startDate: '2026-10-06T00:00:00.000',
        endDate: '2026-10-06T23:59:59.999',
      );

      expect(oct6Report.orders.length, equals(1));
      expect(oct6Report.orders.first.orderNumber, equals('20261006-033128-T1'));
      expect(oct6Report.summary.totalRevenue, equals(1266.0));
    });

    testWidgets('BusinessSettingsHubScreen renders 3 cards per row without description text', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: BusinessSettingsHubScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Titles are visible
      expect(find.text('Order Setting'), findsOneWidget);
      expect(find.text('POS View'), findsOneWidget);
      expect(find.text('Outlet Info'), findsOneWidget);
      expect(find.text('Print Logs'), findsOneWidget);
      expect(find.text('Security PIN'), findsOneWidget);
      expect(find.text('Chotu AI Voice'), findsOneWidget);

      // Subtitle description texts are removed
      expect(find.text('Dine-In, Tables, GST & Channels'), findsNothing);
      expect(find.text('Invoices, Snapshots & History'), findsNothing);
      expect(find.text('Bluetooth Thermal Bill Printer'), findsNothing);
    });

    testWidgets('Normal business user cannot see SuperAdmin Order Purge section', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      db.currentUser = db.currentUser != null
          ? db.currentUser!.copyWith(role: 'Owner')
          : null;

      await tester.pumpWidget(
        const MaterialApp(
          home: BusinessSettingsHubScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // SuperAdmin section should not be visible for normal users
      expect(find.text('Super Admin & Database'), findsNothing);
      expect(find.text('Order Purge'), findsNothing);
    });
  });
}
