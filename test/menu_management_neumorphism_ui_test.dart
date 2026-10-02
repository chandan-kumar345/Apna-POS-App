import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/features/menu/menu_management_screen.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseService db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = DatabaseService();
    await db.init();
    db.menuItems.clear();
    db.categories.clear();
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
      name: 'Test Kitchen',
      tagline: 'Fresh & Tasty',
      phone: '9876543210',
      address: 'Shop 4, Market',
      cuisineType: 'Cafe',
      currencySymbol: '₹',
      billingType: 'Non-GST',
      posViewMode: 'with_image',
    );

    db.categories.addAll(['Main Course', 'Beverages']);

    db.menuItems.addAll([
      MenuItemModel(
        id: 'item_1',
        productId: 'prod_1',
        name: 'Chicken Biryani',
        description: 'Aromatic basmati rice with chicken',
        price: 130.0,
        category: 'Main Course',
        itemType: 'non_veg',
        isAvailable: true,
        stockQuantity: 39,
      ),
      MenuItemModel(
        id: 'item_2',
        productId: 'prod_2',
        name: 'Paneer Butter Masala',
        description: 'Rich cottage cheese curry',
        price: 180.0,
        category: 'Main Course',
        itemType: 'veg',
        isAvailable: true,
        stockQuantity: 15,
      ),
      MenuItemModel(
        id: 'item_3',
        productId: 'prod_3',
        name: 'Cold Coffee',
        description: 'Chilled iced coffee with cream',
        price: 80.0,
        category: 'Beverages',
        itemType: 'veg',
        isAvailable: false,
        stockQuantity: 0,
      ),
    ]);
  });

  testWidgets('Renders Menu Management screen with Neumorphic UI and segmented tabs on mobile', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: MenuManagementScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Segmented Tabs exist
    expect(find.text('Categories'), findsWidgets);
    expect(find.text('Products'), findsWidgets);

    // Verify Default Tab is Categories
    expect(find.text('Main Course'), findsWidgets);
    expect(find.text('Beverages'), findsWidgets);

    // Tap on Products tab
    final productsTab = find.text('Products').first;
    await tester.tap(productsTab);
    await tester.pumpAndSettle();

    // Tap All (3) to show all products across categories
    await tester.tap(find.text('All (3)'));
    await tester.pumpAndSettle();

    // Verify Products View rendered with product details
    expect(find.text('Chicken Biryani'), findsOneWidget);
    expect(find.text('Paneer Butter Masala'), findsOneWidget);
    expect(find.text('Cold Coffee'), findsOneWidget);

    // Verify Price Badges
    expect(find.text('₹130'), findsOneWidget);
    expect(find.text('₹180'), findsOneWidget);
    expect(find.text('₹80'), findsOneWidget);

    // Verify Stock Badges
    expect(find.text('39 in stock'), findsOneWidget);
    expect(find.text('15 in stock'), findsOneWidget);
    expect(find.text('Out of stock'), findsOneWidget);

    // Verify Quick Category Filter Chips
    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('Main Course (2)'), findsOneWidget);
    expect(find.text('Beverages (1)'), findsOneWidget);

    // Verify Action Bar: Search, Filter, CSV, Add
    expect(find.byIcon(Icons.search_rounded), findsWidgets);
    expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('Category filter chip filters products correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: MenuManagementScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Products Tab
    await tester.tap(find.text('Products').first);
    await tester.pumpAndSettle();

    // Tap on Beverages category chip
    await tester.tap(find.text('Beverages (1)'));
    await tester.pumpAndSettle();

    // Only Cold Coffee should be shown
    expect(find.text('Cold Coffee'), findsOneWidget);
    expect(find.text('Chicken Biryani'), findsNothing);
    expect(find.text('Paneer Butter Masala'), findsNothing);

    // Tap All to restore
    await tester.tap(find.text('All (3)'));
    await tester.pumpAndSettle();

    expect(find.text('Chicken Biryani'), findsOneWidget);
    expect(find.text('Paneer Butter Masala'), findsOneWidget);
    expect(find.text('Cold Coffee'), findsOneWidget);
  });

  testWidgets('Search filters products in real time', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: MenuManagementScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Products Tab
    await tester.tap(find.text('Products').first);
    await tester.pumpAndSettle();

    // Enter search text
    final searchField = find.widgetWithText(TextField, 'Search products...');
    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, 'Biryani');
    await tester.pumpAndSettle();

    expect(find.text('Chicken Biryani'), findsOneWidget);
    expect(find.text('Paneer Butter Masala'), findsNothing);
    expect(find.text('Cold Coffee'), findsNothing);
  });
}
