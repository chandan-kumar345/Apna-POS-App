import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/features/pos/pos_register_screen.dart';
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
      name: 'Shri Sai Cafe',
      tagline: 'Fresh & Tasty',
      phone: '9876543210',
      address: 'Shop 4, Market',
      cuisineType: 'Cafe',
      currencySymbol: '₹',
      billingType: 'Non-GST',
      posViewMode: 'with_image',
    );

    db.categories.addAll(['Beverages', 'Snacks']);

    db.menuItems.addAll([
      MenuItemModel(
        id: 'item_1',
        productId: 'prod_1',
        name: 'Special Chai',
        description: 'Hot authentic masala tea',
        price: 25.0,
        category: 'Beverages',
        itemType: 'veg',
        isAvailable: true,
      ),
      MenuItemModel(
        id: 'item_2',
        productId: 'prod_2',
        name: 'Samosa Pav',
        description: 'Crispy samosa with soft pav',
        price: 35.0,
        category: 'Snacks',
        itemType: 'veg',
        isAvailable: true,
      ),
    ]);
  });

  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: PosRegisterScreen(),
    );
  }

  testWidgets('POS Register Screen renders neumorphic UI components correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 850);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump(const Duration(milliseconds: 300));

    // 1. Verify Top Action Bar elements
    expect(find.text('POS'), findsOneWidget);
    expect(find.text('Tables'), findsOneWidget);
    expect(find.text('Add Item'), findsOneWidget);

    // 2. Verify Search Bar and Category Chips
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Beverages'), findsOneWidget);
    expect(find.text('Snacks'), findsOneWidget);

    // 3. Verify Product Cards rendered with correct names and prices
    expect(find.text('Special Chai'), findsOneWidget);
    expect(find.text('Samosa Pav'), findsOneWidget);
    expect(find.text('₹25'), findsOneWidget);
    expect(find.text('₹35'), findsOneWidget);
    expect(find.text('Add'), findsNWidgets(2));

    // 4. Tap "Add" on first item to test cart interaction & floating capsule
    final addButtons = find.widgetWithText(ElevatedButton, 'Add');
    expect(addButtons, findsNWidgets(2));
    await tester.tap(addButtons.first);
    await tester.pump(const Duration(milliseconds: 300));

    // 5. Verify Floating Neumorphic View Cart Bar appears
    expect(find.text('1 Item Added'), findsOneWidget);
    expect(find.text('Total: ₹ 25.00'), findsOneWidget);
    expect(find.text('View Cart'), findsOneWidget);

    // 6. Tap increment inside stepper to test quantity update
    final plusButton = find.byIcon(Icons.add_rounded);
    expect(plusButton, findsOneWidget);
    await tester.tap(plusButton);
    await tester.pump(const Duration(milliseconds: 300));

    // Verify updated cart count in floating bar
    expect(find.text('2 Items Added'), findsOneWidget);
    expect(find.text('Total: ₹ 50.00'), findsOneWidget);

    // 7. Tap "View Cart" to open the Neumorphic Cart Bottom Sheet
    final viewCartBtn = find.text('View Cart');
    expect(viewCartBtn, findsOneWidget);
    await tester.tap(viewCartBtn);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify Cart Sheet header & item controls
    expect(find.text('Items (2)'), findsOneWidget);
    expect(find.text('Clear Cart'), findsOneWidget);
    expect(find.text('Change Table'), findsOneWidget);
    expect(find.byType(DropdownButtonHideUnderline), findsNothing);
    expect(find.text('Add Customer'), findsOneWidget);
    expect(find.text('KOT'), findsOneWidget);
    expect(find.text('Save & Print'), findsOneWidget);
    expect(find.text('Settle'), findsOneWidget);

    // 8. Tap "Add Customer" to open the Customer Details dialog
    final addCustomerBtn = find.text('Add Customer');
    expect(addCustomerBtn, findsOneWidget);
    await tester.tap(addCustomerBtn);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify Add Customer dialog renders with title, Indian Flag, and circular close button
    expect(find.text('Add Customer Details'), findsOneWidget);
    expect(find.text('🇮🇳'), findsOneWidget);
    expect(find.textContaining('Mobile Number'), findsOneWidget);
    expect(find.textContaining('Name'), findsOneWidget);
    expect(find.text('Save Customer'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsWidgets);

    // Test saving customer details
    final phoneField = find.widgetWithText(TextField, 'Enter Mobile Number');
    expect(phoneField, findsOneWidget);
    await tester.enterText(phoneField, '9876543210');
    await tester.pump(const Duration(milliseconds: 200));

    final saveCustomerBtn = find.widgetWithText(ElevatedButton, 'Save Customer');
    expect(saveCustomerBtn, findsOneWidget);
    await tester.tap(saveCustomerBtn);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Dialog should be dismissed and customer name/phone reflected
    expect(find.text('Add Customer Details'), findsNothing);

    // 9. Tap "Change Table" to open the Select / Change Table dialog
    final changeTableBtn = find.text('Change Table');
    expect(changeTableBtn, findsOneWidget);
    await tester.tap(changeTableBtn);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Verify Change Table dialog elements
    expect(find.text('Change Table'), findsWidgets);
    expect(find.text('All'), findsWidgets);
    expect(find.text('Free'), findsWidgets);
  });

  testWidgets('POS Register Screen renders 6 products per row in tablet view and 3 in mobile view', (WidgetTester tester) async {
    // 1. Tablet View (768 x 1024) -> 6 columns in one row
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump(const Duration(milliseconds: 300));

    final tabletGrid = tester.widget<GridView>(find.byType(GridView).first);
    final tabletDelegate = tabletGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(tabletDelegate.crossAxisCount, equals(6));

    // 2. Mobile Phone View (400 x 850) -> 3 columns in one row
    tester.view.physicalSize = const Size(400, 850);
    await tester.pump(const Duration(milliseconds: 300));

    final mobileGrid = tester.widget<GridView>(find.byType(GridView).first);
    final mobileDelegate = mobileGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(mobileDelegate.crossAxisCount, equals(3));
  });
}
