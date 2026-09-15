import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/features/menu/menu_management_screen.dart';
import 'package:apna_pos/core/services/socket_service.dart';
import 'package:apna_pos/core/services/network_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MenuManagementScreen renders categories, products, and 6-dot drag handles correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = DatabaseService();
    db.stopAutoSync();
    SocketService().disconnect();
    NetworkService().dispose();

    final tea = MenuItemModel(
      id: 'bev_tea_1',
      name: 'Masala Chai',
      category: 'Beverages',
      price: 25.0,
      description: 'Hot aromatic chai',
      stockQuantity: 50,
      isAvailable: true,
      itemType: 'veg',
      imageUrl: '',
    );
    final samosa = MenuItemModel(
      id: 'starter_samosa_1',
      name: 'Crispy Samosa',
      category: 'Starters',
      price: 30.0,
      description: 'Spicy potato filled',
      stockQuantity: 20,
      isAvailable: true,
      itemType: 'veg',
      imageUrl: '',
    );

    db.categories = ['Beverages', 'Starters'];
    db.menuItems = [tea, samosa];

    await tester.pumpWidget(
      const MaterialApp(
        home: MenuManagementScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Verify Top Bar elements
    expect(find.text('Menu Management'), findsOneWidget);
    expect(find.text('Preview Menu'), findsOneWidget);
    expect(find.text('Import CSV'), findsWidgets);
    expect(find.text('Add Category'), findsOneWidget);

    // Verify 6-dot drag indicator handles are present
    expect(find.byIcon(Icons.drag_indicator_rounded), findsWidgets);

    // Verify Left Category Panel has Beverages and Starters
    expect(find.text('Beverages'), findsWidgets);
    expect(find.text('Starters'), findsWidgets);

    // Verify Product List for default selected category (Beverages)
    expect(find.text('Masala Chai'), findsOneWidget);
    expect(find.text('Hot aromatic chai'), findsOneWidget);
    expect(find.text('₹25'), findsWidgets);

    // Switch to Starters Category
    await tester.tap(find.text('Starters').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Starters Products are visible
    expect(find.text('Crispy Samosa'), findsOneWidget);
    expect(find.text('₹30'), findsWidgets);

    // Test Search Functionality
    final searchField = find.byType(TextField).first;
    await tester.enterText(searchField, 'UnknownProduct');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('No products found'), findsOneWidget);

    // Clear Search
    await tester.enterText(searchField, '');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Crispy Samosa'), findsOneWidget);

    // Test Preview Menu Dialog
    await tester.tap(find.text('Preview Menu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Live Digital Menu Preview'), findsOneWidget);
    expect(find.text('Customer-facing visual menu simulation'), findsOneWidget);

    // Close Preview Modal
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.byIcon(Icons.close_rounded)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Live Digital Menu Preview'), findsNothing);

    // Flush any pending async timers
    await tester.pump(const Duration(seconds: 2));

    db.stopAutoSync();
    SocketService().disconnect();
    NetworkService().dispose();
  });

  testWidgets('MenuManagementScreen supports Grid View, High-Contrast Switches, and Category Image DB Storage', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = DatabaseService();
    db.stopAutoSync();
    SocketService().disconnect();
    NetworkService().dispose();

    final tea = MenuItemModel(
      id: 'bev_tea_1',
      name: 'Masala Chai',
      category: 'Beverages',
      price: 25.0,
      description: 'Hot aromatic chai',
      stockQuantity: 50,
      isAvailable: true,
      itemType: 'veg',
    );
    final coffee = MenuItemModel(
      id: 'bev_coffee_2',
      name: 'Cold Coffee',
      category: 'Beverages',
      price: 60.0,
      description: 'Creamy iced coffee',
      stockQuantity: 30,
      isAvailable: false, // Inactive state
      itemType: 'veg',
    );

    db.categories = ['Beverages'];
    db.menuItems = [tea, coffee];

    // Test Category Images database methods with R2 remote URL and asset fallback
    await db.saveCategoryImage('Beverages', 'assets/images/beverages.png');
    expect(db.getCategoryImage('Beverages'), 'assets/images/beverages.png');
    expect(db.getCategoryImage('beverages'), 'assets/images/beverages.png');

    await tester.pumpWidget(
      const MaterialApp(
        home: MenuManagementScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify initial Table List View
    expect(find.text('Masala Chai'), findsOneWidget);
    expect(find.text('Cold Coffee'), findsOneWidget);

    // Verify Switches are present and rendered with high contrast styling
    final switches = find.byType(Switch);
    expect(switches, findsWidgets);

    // Switch to Grid View
    await tester.tap(find.text('Grid'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // In Grid view, both items should still be visible
    expect(find.text('Masala Chai'), findsOneWidget);
    expect(find.text('Cold Coffee'), findsOneWidget);

    // Select product via checkbox in Grid View
    final checkboxes = find.byType(Checkbox);
    expect(checkboxes, findsWidgets);
    await tester.tap(checkboxes.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Delete Selected button is active with count
    expect(find.text('Delete Selected (1)'), findsOneWidget);

    // Switch back to List View
    await tester.tap(find.text('List'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Masala Chai'), findsOneWidget);

    // Test category image removal
    await db.removeCategoryImage('Beverages');
    expect(db.getCategoryImage('Beverages'), isNull);

    // Flush timers
    await tester.pump(const Duration(seconds: 2));

    db.stopAutoSync();
    SocketService().disconnect();
    NetworkService().dispose();
  });

  testWidgets('MenuManagementScreen Android Mobile UI renders segmented tabs, category drilldown, and product cards', (WidgetTester tester) async {
    // Narrow Mobile Screen (e.g. 400x800)
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = DatabaseService();
    db.stopAutoSync();
    SocketService().disconnect();
    NetworkService().dispose();

    final paneer = MenuItemModel(
      id: 'main_paneer_1',
      name: 'Shahi Paneer',
      category: 'Main Course',
      price: 230.0,
      description: 'Rich creamy gravy',
      stockQuantity: 48,
      isAvailable: true,
      itemType: 'veg',
      imageUrl: '',
    );
    final dal = MenuItemModel(
      id: 'main_dal_2',
      name: 'Dal Tadka',
      category: 'Main Course',
      price: 199.0,
      description: 'Yellow lentils tempered with ghee',
      stockQuantity: 23,
      isAvailable: true,
      itemType: 'veg',
      imageUrl: '',
    );
    final samosa = MenuItemModel(
      id: 'starter_samosa_1',
      name: 'Crispy Samosa',
      category: 'Starters',
      price: 30.0,
      description: 'Crispy potato snack',
      stockQuantity: 15,
      isAvailable: true,
      itemType: 'veg',
      imageUrl: '',
    );

    db.categories = ['Main Course', 'Starters'];
    db.menuItems = [paneer, dal, samosa];

    await tester.pumpWidget(
      const MaterialApp(
        home: MenuManagementScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. Verify Top Segmented Tabs
    expect(find.text('Categories'), findsWidgets);
    expect(find.text('Products'), findsWidgets);

    // 2. Initial Tab is Categories
    expect(find.text('Add'), findsWidgets);
    expect(find.text('Main Course'), findsOneWidget);
    expect(find.text('2 products'), findsOneWidget);
    expect(find.text('Starters'), findsOneWidget);
    expect(find.text('1 products'), findsOneWidget);

    // Verify 6-dot drag handles
    expect(find.byIcon(Icons.drag_indicator_rounded), findsWidgets);

    // Expand search in Categories
    await tester.tap(find.byIcon(Icons.search_rounded).first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Search categories...'), findsOneWidget);

    // Close search in Categories
    await tester.tap(find.byIcon(Icons.close_rounded).first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 3. Drill down to Products via Chevron / Tap
    await tester.tap(find.byIcon(Icons.chevron_right_rounded).first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 4. Products Tab is now active
    expect(find.text('CSV'), findsOneWidget);
    expect(find.text('Shahi Paneer'), findsOneWidget);
    expect(find.text('48 in stock'), findsOneWidget);
    expect(find.text('₹230'), findsOneWidget);
    expect(find.text('Dal Tadka'), findsOneWidget);
    expect(find.text('23 in stock'), findsOneWidget);
    expect(find.text('₹199'), findsOneWidget);

    // Expand search in Products (hides CSV and Add)
    await tester.tap(find.byIcon(Icons.search_rounded).first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Search products...'), findsOneWidget);

    // Close search in Products (restores CSV and Add)
    await tester.tap(find.byIcon(Icons.close_rounded).first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('CSV'), findsOneWidget);

    // 5. Test Filter Modal
    await tester.tap(find.byIcon(Icons.filter_alt_outlined), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Filter & Sort Products'), findsOneWidget);
    expect(find.text('Apply Filter'), findsOneWidget);

    // Close Filter Modal via Close Icon
    await tester.tap(find.byIcon(Icons.close_rounded).first, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Filter & Sort Products'), findsNothing);

    // 6. Switch back to Categories Tab
    await tester.tap(find.text('Categories').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Main Course'), findsOneWidget);

    // Clean up
    await tester.pump(const Duration(seconds: 2));
    db.stopAutoSync();
    SocketService().disconnect();
    NetworkService().dispose();
  });
}
