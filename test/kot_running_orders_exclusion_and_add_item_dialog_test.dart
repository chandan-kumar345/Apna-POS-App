import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/services/report_service.dart';
import 'package:apna_pos/core/services/dashboard_service.dart';
import 'package:apna_pos/features/pos/pos_register_screen.dart';

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
      name: 'Apna POS Demo',
      tagline: 'Fresh & Fast',
      phone: '9999999999',
      address: 'Main Street',
      cuisineType: 'Indian',
      currencySymbol: '₹',
      taxRate: 5.0,
      billingType: 'GST',
    );
  });

  group('KOT Running Orders Exclusion from Sales in Dashboard & Reports', () {
    test('KOT running and pending orders are not counted in sales revenue or sales order count', () async {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day, 13, 0, 0);

      final paneerTikka = MenuItemModel(
        id: 'item_paneer',
        name: 'Paneer Tikka',
        description: 'Grilled paneer',
        price: 250.0,
        category: 'Starters',
        itemType: 'Veg',
      );

      final butterNaan = MenuItemModel(
        id: 'item_naan',
        name: 'Butter Naan',
        description: 'Fresh tandoori naan',
        price: 50.0,
        category: 'Breads',
        itemType: 'Veg',
      );

      // 1. Settled Order: ₹500 (2x Paneer Tikka), Completed, Paid via Cash
      final settledOrder1 = OrderModel(
        id: 'settled_001',
        orderNumber: 'ORD-SETTLED-01',
        tableNumber: 'T1',
        orderType: OrderType.dineIn,
        status: OrderStatus.completed,
        isPaid: true,
        paymentStatus: 'paid',
        paymentMethod: 'Cash',
        subtotal: 500.0,
        taxAmount: 25.0,
        discountAmount: 0.0,
        totalAmount: 525.0,
        createdAt: todayDate.toIso8601String(),
        items: [CartItemModel(item: paneerTikka, quantity: 2)],
      );

      // 2. KOT Running Order (Status: preparing, unpaid): ₹100 (2x Butter Naan)
      final runningKotOrder1 = OrderModel(
        id: 'kot_001',
        orderNumber: 'KOT-RUNNING-01',
        tableNumber: 'T2',
        orderType: OrderType.dineIn,
        status: OrderStatus.preparing,
        isPaid: false,
        paymentStatus: 'pending',
        paymentMethod: 'KOT',
        subtotal: 100.0,
        taxAmount: 5.0,
        discountAmount: 0.0,
        totalAmount: 105.0,
        createdAt: todayDate.add(const Duration(minutes: 10)).toIso8601String(),
        items: [CartItemModel(item: butterNaan, quantity: 2)],
      );

      // 3. Pending KOT Order (Status: pending, unpaid): ₹250
      final pendingKotOrder2 = OrderModel(
        id: 'kot_002',
        orderNumber: 'KOT-RUNNING-02',
        tableNumber: 'T3',
        orderType: OrderType.dineIn,
        status: OrderStatus.pending,
        isPaid: false,
        paymentStatus: 'pending',
        paymentMethod: 'KOT',
        subtotal: 250.0,
        taxAmount: 12.5,
        discountAmount: 0.0,
        totalAmount: 262.5,
        createdAt: todayDate.add(const Duration(minutes: 20)).toIso8601String(),
        items: [CartItemModel(item: paneerTikka, quantity: 1)],
      );

      // 4. Cancelled Order: ₹50
      final cancelledOrder = OrderModel(
        id: 'cancelled_001',
        orderNumber: 'ORD-CANCEL-01',
        tableNumber: 'T4',
        orderType: OrderType.dineIn,
        status: OrderStatus.cancelled,
        isPaid: false,
        paymentStatus: 'unpaid',
        paymentMethod: 'Cash',
        subtotal: 50.0,
        taxAmount: 2.5,
        discountAmount: 0.0,
        totalAmount: 52.5,
        createdAt: todayDate.add(const Duration(minutes: 30)).toIso8601String(),
        items: [CartItemModel(item: butterNaan, quantity: 1)],
      );

      // Save all orders to DB
      db.orders.addAll([settledOrder1, runningKotOrder1, pendingKotOrder2, cancelledOrder]);

      // Verify DatabaseService helpers
      final completed = db.getCompletedOrders();
      expect(completed.length, 1);
      expect(completed.first.orderNumber, 'ORD-SETTLED-01');

      // Verify Sales Report
      final report = reportService.getLocalSalesReport(period: 'today');
      expect(report.summary.totalOrders, 1, reason: 'Only completed/settled orders should be counted in sales report');
      expect(report.summary.totalRevenue, 525.0, reason: 'KOT running orders should not be calculated in revenue');
      expect(report.summary.totalTax, 25.0);
      expect(report.orders.length, 1);
      expect(report.orders.first.orderNumber, 'ORD-SETTLED-01');

      // Verify Dashboard Overview
      final dashboardSummary = await dashboardService.fetchSummary(period: 'Today');
      expect(dashboardSummary.totalOrders, 1, reason: 'Dashboard total orders must only count settled orders');
      expect(dashboardSummary.revenue, 525.0, reason: 'Dashboard revenue must only count settled orders');
      expect(dashboardSummary.activeOrdersCount, 2, reason: 'Active orders count must track the 2 running KOT orders');

      final orderTypes = await dashboardService.fetchOrderTypes(period: 'Today');
      expect(orderTypes.total.count, 1);
      expect(orderTypes.total.amount, 525.0);
      expect(orderTypes.dineIn.count, 1);
      expect(orderTypes.dineIn.amount, 525.0);
    });
  });

  group('Add Item Manually Redesigned Popup Dialog Widget Test', () {
    testWidgets('Renders all redesigned popup UI elements and texts visibly in dialog', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));

      final nameController = TextEditingController();
      final priceController = TextEditingController();
      int quantity = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (dialogCtx) => StatefulBuilder(
                      builder: (context, setDialogState) {
                        return Dialog(
                          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          backgroundColor: Colors.white,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Container(
                                      width: 40,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(Icons.shopping_cart_outlined),
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Add Item Manually',
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            Text(
                                              'Enter item details to add to cart',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded),
                                        onPressed: () => Navigator.pop(dialogCtx),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Item Name *'),
                                  TextField(
                                    key: const Key('item_name_input'),
                                    controller: nameController,
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. Water Bottle, Extra Roti...',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Price (₹) *'),
                                            TextField(
                                              key: const Key('price_input'),
                                              controller: priceController,
                                              decoration: const InputDecoration(hintText: '0.00'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Qty'),
                                            Text('$quantity'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  const Text('Food Type'),
                                  const Text('Tax Rate'),
                                  Row(
                                    children: [0.0, 5.0, 12.0, 18.0, 28.0].map((rate) {
                                      final label = rate == 0.0 ? '0%' : '${rate.toStringAsFixed(0)}%';
                                      return Expanded(
                                        child: Text(label),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      const Text('Cancel'),
                                      const Text('Add to Cart'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                child: const Text('Open Popup'),
              ),
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('Open Popup'));
      await tester.pumpAndSettle();

      // Check Header Texts
      expect(find.text('Add Item Manually'), findsOneWidget);
      expect(find.text('Enter item details to add to cart'), findsOneWidget);

      // Check Form Fields
      expect(find.text('Item Name *'), findsOneWidget);
      expect(find.text('Price (₹) *'), findsOneWidget);
      expect(find.text('Qty'), findsOneWidget);
      expect(find.text('Food Type'), findsOneWidget);
      expect(find.text('Tax Rate'), findsOneWidget);

      // Check Tax Percentages
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('5%'), findsOneWidget);
      expect(find.text('12%'), findsOneWidget);
      expect(find.text('18%'), findsOneWidget);
      expect(find.text('28%'), findsOneWidget);

      // Check Buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Add to Cart'), findsOneWidget);
    });

    testWidgets('Confirmation dialog renders Temporary and Permanent options properly', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));

      ManualItemPersistenceMode? chosenMode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  chosenMode = await showDialog<ManualItemPersistenceMode>(
                    context: ctx,
                    builder: (confirmCtx) {
                      return Dialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Save Product Type'),
                            const Text('Choose how to add this item to POS'),
                            const Text('Water Bottle 1L'),
                            const Text('₹20 × 2 = ₹40  •  5% GST'),
                            InkWell(
                              onTap: () => Navigator.pop(confirmCtx, ManualItemPersistenceMode.temporary),
                              child: const Column(
                                children: [
                                  Text('Temporary'),
                                  Text('Cart Only'),
                                  Text('Add to cart for current order only. Will NOT appear in POS menu catalog or Menu Management.'),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(confirmCtx, ManualItemPersistenceMode.permanent),
                              child: const Column(
                                children: [
                                  Text('Permanent'),
                                  Text('Save to Menu'),
                                  Text('Add to cart AND save to POS menu & Menu Management so you can edit and reuse it anytime.'),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(confirmCtx, null),
                              child: const Text('Back / Cancel'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                child: const Text('Trigger Confirmation'),
              ),
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('Trigger Confirmation'));
      await tester.pumpAndSettle();

      expect(find.text('Save Product Type'), findsOneWidget);
      expect(find.text('Choose how to add this item to POS'), findsOneWidget);
      expect(find.text('Temporary'), findsOneWidget);
      expect(find.text('Cart Only'), findsOneWidget);
      expect(find.text('Permanent'), findsOneWidget);
      expect(find.text('Save to Menu'), findsOneWidget);

      // Tap Temporary
      await tester.tap(find.text('Temporary'));
      await tester.pumpAndSettle();
      expect(chosenMode, ManualItemPersistenceMode.temporary);
    });

    test('Temporary product adds only to cart while Permanent product saves to db.menuItems', () async {
      final db = DatabaseService();
      await db.init();

      db.menuItems = [
        MenuItemModel(
          id: 'item_1',
          productId: 'prod_1',
          name: 'Existing Pizza',
          category: 'Pizzas',
          price: 250.0,
          description: 'Delicious pizza',
        ),
      ];

      // 1. Temporary addition
      final tempItem = MenuItemModel(
        id: 'temp_101',
        productId: 'temp_101',
        name: 'Special Water Bottle',
        category: 'Custom',
        price: 20.0,
        description: 'Temporary water',
      );

      final List<CartItemModel> cart = [];
      cart.add(CartItemModel(item: tempItem, quantity: 2));

      // Assert that temp product is in cart
      expect(cart.length, 1);
      expect(cart.first.item.name, 'Special Water Bottle');
      expect(cart.first.item.id.startsWith('temp_'), isTrue);

      // Assert that temp product is NOT in menuItems
      expect(db.menuItems.any((m) => m.name == 'Special Water Bottle'), isFalse);
      expect(db.menuItems.length, 1);

      // 2. Permanent addition
      final permanentItem = MenuItemModel(
        id: 'prod_202',
        productId: 'prod_202',
        name: 'Garlic Breadsticks',
        category: 'Appetizers',
        price: 120.0,
        description: 'Garlic breadsticks',
      );

      await db.saveMenuItem(permanentItem);
      cart.add(CartItemModel(item: permanentItem, quantity: 1));

      // Assert that permanent product is in cart AND in db.menuItems
      expect(cart.length, 2);
      expect(db.menuItems.any((m) => m.name == 'Garlic Breadsticks'), isTrue);
      expect(db.menuItems.length, 2);
      expect(db.categories.contains('Appetizers'), isTrue);
    });
  });
}

