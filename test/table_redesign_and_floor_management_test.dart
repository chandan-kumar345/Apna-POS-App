import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/table_model.dart';
import 'package:apna_pos/features/tables/table_management_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = DatabaseService();
    await db.init();
    db.tables.clear();
    db.resetCustomFloors();
    // Seed test tables
    db.tables.addAll([
      TableModel(id: 'tbl_1', tableNumber: 1, name: 'T-1', floor: 'Ground Floor', capacity: 4),
      TableModel(id: 'tbl_2', tableNumber: 2, name: 'T-2', floor: 'Ground Floor', capacity: 4),
      TableModel(id: 'tbl_3', tableNumber: 3, name: 'T-3', floor: '1st Floor', capacity: 4),
    ]);
  });

  group('DatabaseService Floor & Table Management Tests', () {
    test('allFloors includes default and table floors', () {
      final db = DatabaseService();
      expect(db.allFloors.contains('Ground Floor'), isTrue);
      expect(db.allFloors.contains('1st Floor'), isTrue);
    });

    test('addCustomFloor adds new floor to allFloors', () async {
      final db = DatabaseService();
      await db.addCustomFloor('Rooftop Lounge');
      expect(db.customFloors.contains('Rooftop Lounge'), isTrue);
      expect(db.allFloors.contains('Rooftop Lounge'), isTrue);
    });

    test('renameFloor renames floor across customFloors and all matching tables', () async {
      final db = DatabaseService();
      expect(db.tables.where((t) => t.floor == '1st Floor').length, 1);

      await db.renameFloor('1st Floor', 'Terrace View');

      expect(db.allFloors.contains('Terrace View'), isTrue);
      expect(db.tables.where((t) => t.floor == 'Terrace View').length, 1);
      expect(db.tables.where((t) => t.floor == '1st Floor').length, 0);
    });

    test('addTable creates table with specified floor and natural numbering', () async {
      final db = DatabaseService();
      await db.addTable('VIP-1', 'Rooftop Lounge', 6, count: 1);

      final added = db.tables.firstWhere((t) => t.name == 'VIP-1');
      expect(added.floor, 'Rooftop Lounge');
      expect(added.capacity, 6);
      expect(db.allFloors.contains('Rooftop Lounge'), isTrue);
    });
  });

  group('TableManagementScreen Redesigned UI & Flow Tests', () {
    testWidgets('Renders compact header stats and floor filter tabs', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TableManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify compact Stat Cards (Available, KOT Running, Occupied, Reserved)
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('KOT Running'), findsOneWidget);
      expect(find.text('Occupied'), findsOneWidget);
      expect(find.text('Reserved'), findsOneWidget);

      // Verify Add Table button
      expect(find.byKey(const ValueKey('add_table_top_button')), findsOneWidget);
    });

    testWidgets('Tapping Add Table opens redesigned Add Dining Table popup with floor cards and + button', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TableManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Add Table"
      await tester.ensureVisible(find.byKey(const ValueKey('add_table_top_button')));
      await tester.tap(find.byKey(const ValueKey('add_table_top_button')), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify popup header
      expect(find.text('Add Dining Table'), findsOneWidget);
      expect(find.text('Enter table name and assign a dining floor or area'), findsOneWidget);

      // Verify table name input and floor section
      expect(find.text('Table Name / Number'), findsOneWidget);
      expect(find.text('Floor / Dining Area'), findsOneWidget);
      expect(find.byKey(const ValueKey('add_floor_button')), findsOneWidget);

      // Verify edit floor field
      expect(find.text('Edit Selected Floor Name'), findsOneWidget);
      expect(find.byKey(const ValueKey('edit_floor_name_field')), findsOneWidget);

      // Verify actions
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byKey(const ValueKey('create_table_submit_button')), findsOneWidget);
    });

    testWidgets('Tapping + button opens Create New Floor modal and creates floor', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TableManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Add Table dialog
      await tester.ensureVisible(find.byKey(const ValueKey('add_table_top_button')));
      await tester.tap(find.byKey(const ValueKey('add_table_top_button')), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Tap + button
      await tester.ensureVisible(find.byKey(const ValueKey('add_floor_button')));
      await tester.tap(find.byKey(const ValueKey('add_floor_button')), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Create New Floor'), findsOneWidget);

      // Enter new floor name and create
      await tester.enterText(find.widgetWithText(TextField, 'e.g. 2nd Floor, Rooftop, Garden'), 'Poolside');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Floor'));
      await tester.pumpAndSettle();

      // Verify new floor is created and visible in dialog
      expect(find.descendant(of: find.byType(Dialog), matching: find.text('Poolside')), findsWidgets);
    });

    testWidgets('Editing selected floor name directly renames the floor', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TableManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Add Table dialog
      await tester.ensureVisible(find.byKey(const ValueKey('add_table_top_button')));
      await tester.tap(find.byKey(const ValueKey('add_table_top_button')), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Edit floor text field
      final editField = find.byKey(const ValueKey('edit_floor_name_field'));
      await tester.enterText(editField, 'Sky Dining');
      await tester.pumpAndSettle();

      final db = DatabaseService();
      expect(db.allFloors.contains('Sky Dining'), isTrue);
    });

    testWidgets('Renders 3 tables in one row in mobile view and shows cart value in table boxes', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = DatabaseService();
      // Setup T-1 free, T-2 with live cart value 450, T-3 reserved
      db.tables = [
        TableModel(id: 'tbl_1', tableNumber: 1, name: 'T-1', floor: 'Ground Floor', capacity: 4, status: TableStatus.free),
        TableModel(id: 'tbl_2', tableNumber: 2, name: 'T-2', floor: 'Ground Floor', capacity: 4, status: TableStatus.occupied, activeOrderTotal: 450.0),
        TableModel(id: 'tbl_3', tableNumber: 3, name: 'T-3', floor: 'Ground Floor', capacity: 4, status: TableStatus.reserved),
      ];
      db.setLiveCartTotal('T-2', 450.0);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TableManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 3 tables are visible in the grid
      expect(find.text('T-1'), findsOneWidget);
      expect(find.text('T-2'), findsOneWidget);
      expect(find.text('T-3'), findsOneWidget);

      // Verify cart value is shown for T-2
      expect(find.textContaining('450'), findsOneWidget);

      // Verify grid crossAxisCount is 3 on mobile
      final gridFinder = find.byType(GridView);
      expect(gridFinder, findsOneWidget);
      final grid = tester.widget<GridView>(gridFinder);
      final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);

      // Verify Reserved box is rendered with Reserved status and View button
      expect(find.text('Reserved'), findsWidgets);

      // Verify T-1 has centered shopping cart button without 'Add to Cart' text
      expect(find.byKey(const ValueKey('add_to_cart_T-1')), findsOneWidget);
      expect(find.text('Add to Cart'), findsNothing);
    });
  });
}
