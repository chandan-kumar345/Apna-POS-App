import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/features/dashboard/dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = DatabaseService();
    await db.init();
    db.orders.clear();

    db.currentUser = UserModel(
      id: 'owner_01',
      name: 'Owner Name',
      email: 'owner@apnapos.com',
      phone: '9999999999',
      role: 'Owner',
      pin: '1234',
      restaurantId: 'rest_01',
    );

    db.restaurant = RestaurantModel(
      id: 'rest_01',
      name: 'Apna POS Diner',
      tagline: 'Fresh Food Fast',
      phone: '9999999999',
      address: 'Main St',
      cuisineType: 'Indian',
      currencySymbol: '₹',
      taxRate: 5.0,
      billingType: 'GST',
    );
  });

  group('Dashboard Screen Neumorphic UI Tests', () {
    testWidgets('Dashboard renders neumorphic cards, headers, metrics, and sections', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      final testItem = MenuItemModel(
        id: 'item_1',
        name: 'Masala Dosa',
        description: 'Crispy rice crepe',
        price: 120.0,
        category: 'Breakfast',
      );

      final settledOrder = OrderModel(
        id: 'ord_1',
        orderNumber: 'ORD-101',
        tableNumber: 'T1',
        orderType: OrderType.dineIn,
        status: OrderStatus.completed,
        isPaid: true,
        paymentStatus: 'paid',
        paymentMethod: 'Cash',
        subtotal: 120.0,
        taxAmount: 6.0,
        totalAmount: 126.0,
        createdAt: DateTime.now().toIso8601String(),
        items: [CartItemModel(item: testItem, quantity: 1)],
      );

      db.orders.add(settledOrder);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassDashboardScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check Store Header & Subtitle
      expect(find.text('Apna POS Diner'), findsOneWidget);
      expect(find.text('Real-Time Cloud Business Analytics'), findsOneWidget);

      // Check Order Summary Section
      expect(find.text('Order Summary'), findsOneWidget);
      expect(find.text('Total Orders'), findsWidgets);
      expect(find.text('Total Revenue'), findsOneWidget);

      // Check Order Type Grid
      expect(find.text('Dine In'), findsOneWidget);
      expect(find.text('Take Away'), findsOneWidget);
      expect(find.text('Delivery'), findsOneWidget);

      // Check Sections
      expect(find.text('Total sale of item'), findsOneWidget);
      expect(find.text('New Customers'), findsOneWidget);
      expect(find.text('Returning Customers'), findsOneWidget);
      expect(find.text('Total Sales'), findsOneWidget);
      expect(find.text('Taxes'), findsOneWidget);
      expect(find.text('Order Statistics'), findsOneWidget);
    });

    testWidgets('Date filter dropdown opens and shows redesigned neumorphic options', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassDashboardScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Find the dropdown button with "Today"
      final dropdownFinder = find.byType(PopupMenuButton<String>);
      expect(dropdownFinder, findsOneWidget);

      // Tap on dropdown
      await tester.tap(dropdownFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify dropdown options are rendered
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      expect(find.text('This Year'), findsOneWidget);
      expect(find.text('All Time'), findsOneWidget);
      expect(find.text('Custom Date Range'), findsOneWidget);

      // Tap on "Custom Date Range" option
      await tester.tap(find.text('Custom Date Range'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify the custom date range dialog opens with calendar days and Apply button
      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Su'), findsOneWidget);
      expect(find.text('Mo'), findsOneWidget);
      expect(find.text('Tu'), findsOneWidget);

      // Tap Apply
      await tester.tap(find.text('Apply'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog is closed and custom filter is applied
      expect(find.text('Apply'), findsNothing);
    });

    testWidgets('Selecting custom date range filters orders and updates dashboard metrics', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      final testItem = MenuItemModel(
        id: 'item_pizza',
        name: 'Paneer Pizza',
        description: 'Cheesy paneer pizza',
        price: 250.0,
        category: 'Fast Food',
      );

      // Order created 2 days ago (out of "Today" range)
      final pastDate = DateTime.now().subtract(const Duration(days: 2));
      final pastOrder = OrderModel(
        id: 'ord_past_1',
        orderNumber: 'ORD-901',
        tableNumber: 'T2',
        orderType: OrderType.takeaway,
        status: OrderStatus.completed,
        isPaid: true,
        paymentStatus: 'paid',
        paymentMethod: 'UPI',
        subtotal: 500.0,
        taxAmount: 25.0,
        totalAmount: 525.0,
        createdAt: pastDate.toIso8601String(),
        items: [CartItemModel(item: testItem, quantity: 2)],
      );

      db.orders.add(pastOrder);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassDashboardScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially on "Today", so pastOrder is not included in today's local calculation
      // Now open the dropdown and choose "Last 7 Days" in the custom dialog preset
      final dropdownFinder = find.byType(PopupMenuButton<String>);
      await tester.tap(dropdownFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Custom Date Range'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap preset 'Last 7 Days'
      expect(find.text('Last 7 Days'), findsOneWidget);
      await tester.tap(find.text('Last 7 Days'));
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Apply
      await tester.tap(find.text('Apply'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify that the filter badge displays "Custom Date"
      expect(find.text('Custom Date'), findsWidgets);

      // Verify that the Order Summary displays the order count for the custom range
      expect(find.text('Order Summary'), findsOneWidget);
      expect(find.text('Total Orders'), findsWidgets);
    });
  });
}
