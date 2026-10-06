import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/features/reports/reports_screen.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => Directory.systemTemp.path;

  @override
  Future<String?> getDownloadsPath() async => Directory.systemTemp.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;

  setUp(() async {
    PathProviderPlatform.instance = MockPathProviderPlatform();
    SharedPreferences.setMockInitialValues({});
    db = DatabaseService();
    await db.init();
    db.orders.clear();

    db.currentUser = UserModel(
      id: 'owner_01',
      name: 'Test Owner',
      email: 'owner@apnapos.com',
      phone: '9999999999',
      role: 'Owner',
      pin: '1234',
      restaurantId: 'rest_01',
    );

    db.restaurant = RestaurantModel(
      id: 'rest_01',
      name: 'Apna POS Restaurant',
      tagline: 'Delicious Food Fast',
      phone: '9876543210',
      address: 'Shop 101, Main Road',
      cuisineType: 'Indian',
      currencySymbol: '₹',
      taxRate: 5.0,
      billingType: 'GST',
    );

    final item1 = MenuItemModel(
      id: 'item_1',
      name: 'Paneer Butter Masala',
      description: 'Creamy cottage cheese curry',
      price: 250.0,
      category: 'Main Course',
      itemType: 'Veg',
    );

    final order1 = OrderModel(
      id: 'ord_1',
      orderNumber: 'ORD-001',
      tableNumber: 'T1',
      status: OrderStatus.completed,
      orderType: OrderType.dineIn,
      isPaid: true,
      paymentStatus: 'paid',
      paymentMethod: 'UPI',
      subtotal: 500.0,
      taxAmount: 25.0,
      discountAmount: 0.0,
      totalAmount: 525.0,
      items: [
        CartItemModel(
          item: item1,
          quantity: 2,
        ),
      ],
      createdAt: DateTime.now().toIso8601String(),
    );

    db.orders.add(order1);
  });

  group('Reports Screen Neumorphic UI Tests', () {
    testWidgets('ReportsScreen renders desktop neumorphic layout without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReportsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header and KPI cards
      expect(find.text('Total Sales'), findsAtLeastNWidgets(1));
      expect(find.text('Total Orders'), findsOneWidget);
      expect(find.text('Average Order Value'), findsOneWidget);
      expect(find.text('Total Items Sold'), findsOneWidget);
      expect(find.text('Total Bills'), findsOneWidget);

      // Verify Filter Buttons
      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);

      // Verify Tabs
      expect(find.text('Sales Details'), findsOneWidget);
      expect(find.text('Top Products'), findsOneWidget);
      expect(find.text('Category Wise'), findsOneWidget);
      expect(find.text('Payment Mode'), findsAtLeastNWidgets(1));
    });

    testWidgets('ReportsScreen wraps smoothly on mobile viewport without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReportsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify KPI elements are present
      expect(find.text('Total Sales'), findsAtLeastNWidgets(1));
      expect(find.text('Total Orders'), findsOneWidget);

      // Verify action buttons exist in mobile
      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);

      // Verify default preset is 'Today'
      expect(find.text('Today'), findsOneWidget);

      // Verify the inner table filter button is removed
      expect(find.byIcon(Icons.filter_alt_rounded), findsNothing);

      // Verify tapping export saves directly and shows SnackBar
      final exportBtn = find.byIcon(Icons.file_download_outlined);
      await tester.ensureVisible(exportBtn);
      await tester.runAsync(() async {
        await tester.tap(exportBtn);
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Your Excel sales report is downloaded.'), findsOneWidget);
    });
  });
}
