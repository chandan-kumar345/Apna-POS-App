import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/models/table_model.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/features/tables/table_management_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Table Timer Parsing & Formatting Tests', () {
    test('parseTableOccupiedSince parses ISO-8601 strings correctly', () {
      final iso = DateTime(2026, 9, 13, 14, 30, 0).toIso8601String();
      final parsed = parseTableOccupiedSince(iso);
      expect(parsed, isNotNull);
      expect(parsed!.hour, 14);
      expect(parsed.minute, 30);
    });

    test('parseTableOccupiedSince parses HH:mm format correctly', () {
      final parsed = parseTableOccupiedSince('14:45');
      expect(parsed, isNotNull);
      expect(parsed!.hour, 14);
      expect(parsed.minute, 45);
    });

    test('parseTableOccupiedSince handles null and invalid strings', () {
      expect(parseTableOccupiedSince(null), isNull);
      expect(parseTableOccupiedSince(''), isNull);
      expect(parseTableOccupiedSince('invalid'), isNull);
    });

    test('formatRunningDuration formats durations under 1 hour as "Xm Ys"', () {
      expect(formatRunningDuration(const Duration(minutes: 0, seconds: 45)), '0m 45s');
      expect(formatRunningDuration(const Duration(minutes: 5, seconds: 7)), '5m 07s');
      expect(formatRunningDuration(const Duration(minutes: 44, seconds: 59)), '44m 59s');
    });

    test('formatRunningDuration formats durations >= 1 hour as "Xh Ym"', () {
      expect(formatRunningDuration(const Duration(hours: 1, minutes: 0)), '1h 00m');
      expect(formatRunningDuration(const Duration(hours: 1, minutes: 24, seconds: 15)), '1h 24m');
      expect(formatRunningDuration(const Duration(hours: 3, minutes: 5)), '3h 05m');
    });

    test('TableModel.getRunningDuration returns null for free tables', () {
      final freeTable = TableModel(
        id: 'tbl_1',
        tableNumber: 1,
        name: 'T-1',
        floor: 'Ground Floor',
        capacity: 4,
        status: TableStatus.free,
        occupiedSince: DateTime.now().toIso8601String(),
      );
      expect(freeTable.getRunningDuration(), isNull);
    });

    test('TableModel.getRunningDuration returns correct duration for occupied table', () {
      final now = DateTime(2026, 9, 13, 16, 0, 0);
      final startTime = now.subtract(const Duration(minutes: 25, seconds: 30));
      final table = TableModel(
        id: 'tbl_2',
        tableNumber: 2,
        name: 'T-2',
        floor: 'Ground Floor',
        capacity: 4,
        status: TableStatus.occupied,
        occupiedSince: startTime.toIso8601String(),
      );

      final dur = table.getRunningDuration(now: now);
      expect(dur, isNotNull);
      expect(dur!.inMinutes, 25);
      expect(dur.inSeconds, 25 * 60 + 30);
      expect(formatRunningDuration(dur), '25m 30s');
    });

    test('TableModel.getRunningDuration falls back to activeOrderCreatedAt if occupiedSince is null', () {
      final now = DateTime(2026, 9, 13, 17, 30, 0);
      final orderTime = now.subtract(const Duration(hours: 1, minutes: 15));
      final table = TableModel(
        id: 'tbl_3',
        tableNumber: 3,
        name: 'T-3',
        floor: 'Ground Floor',
        capacity: 4,
        status: TableStatus.runningKot,
        occupiedSince: null,
      );

      final dur = table.getRunningDuration(
        now: now,
        activeOrderCreatedAt: orderTime.toIso8601String(),
      );
      expect(dur, isNotNull);
      expect(dur!.inHours, 1);
      expect(dur.inMinutes, 75);
      expect(formatRunningDuration(dur), '1h 15m');
    });

    test('TableModel.getRunningDuration picks earlier start time between occupiedSince and activeOrderCreatedAt', () {
      final now = DateTime(2026, 9, 13, 17, 30, 0);
      final earlyTime = now.subtract(const Duration(minutes: 35));
      final laterTime = now.subtract(const Duration(minutes: 10));

      final table1 = TableModel(
        id: 'tbl_early',
        tableNumber: 1,
        name: 'T-1',
        floor: 'Ground Floor',
        capacity: 4,
        status: TableStatus.runningKot,
        occupiedSince: earlyTime.toIso8601String(),
      );

      // table.occupiedSince is earlier (35 min ago), activeOrderCreatedAt is later (10 min ago)
      final dur1 = table1.getRunningDuration(
        now: now,
        activeOrderCreatedAt: laterTime.toIso8601String(),
      );
      expect(dur1?.inMinutes, 35);

      final table2 = TableModel(
        id: 'tbl_later',
        tableNumber: 2,
        name: 'T-2',
        floor: 'Ground Floor',
        capacity: 4,
        status: TableStatus.runningKot,
        occupiedSince: laterTime.toIso8601String(),
      );

      // table.occupiedSince is later (10 min ago), activeOrderCreatedAt is earlier (35 min ago)
      final dur2 = table2.getRunningDuration(
        now: now,
        activeOrderCreatedAt: earlyTime.toIso8601String(),
      );
      expect(dur2?.inMinutes, 35);
    });
  });

  group('Table Management Screen Live Timer Widget Tests', () {
    setUp(() {
      final db = DatabaseService();
      db.tables = [
        TableModel(
          id: 'tbl_1',
          tableNumber: 1,
          name: 'T-1',
          floor: 'Ground Floor',
          capacity: 4,
          status: TableStatus.free,
          occupiedSince: null,
        ),
        TableModel(
          id: 'tbl_2',
          tableNumber: 2,
          name: 'T-2',
          floor: 'Ground Floor',
          capacity: 4,
          status: TableStatus.occupied,
          occupiedSince: DateTime.now().subtract(const Duration(minutes: 18, seconds: 40)).toIso8601String(),
        ),
        TableModel(
          id: 'tbl_3',
          tableNumber: 3,
          name: 'T-3',
          floor: 'Ground Floor',
          capacity: 4,
          status: TableStatus.runningKot,
          occupiedSince: DateTime.now().subtract(const Duration(minutes: 55, seconds: 10)).toIso8601String(),
        ),
      ];
    });

    testWidgets('Renders running duration badge on occupied and runningKot tables, but not free tables', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TableManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check table names
      expect(find.text('T-1'), findsOneWidget);
      expect(find.text('T-2'), findsOneWidget);
      expect(find.text('T-3'), findsOneWidget);

      // Free table T-1 has no timer icon
      // Occupied tables (T-2 and T-3) each show a live timer icon
      expect(find.byIcon(Icons.timer_outlined), findsNWidgets(2));

      // T-2 should show an 18m duration badge
      expect(find.textContaining('18m'), findsOneWidget);

      // T-3 should show a 55m duration badge
      expect(find.textContaining('55m'), findsOneWidget);
    });
  });

  group('Table Timer Lifecycle: Add to Cart -> KOT Print -> Bill Print -> Settle', () {
    final db = DatabaseService();

    setUp(() {
      db.tables = [
        TableModel(
          id: 'tbl_lifecycle',
          tableNumber: 1,
          name: 'T-1',
          floor: 'Ground Floor',
          capacity: 4,
          status: TableStatus.free,
          occupiedSince: null,
        ),
      ];
      db.orders = [];
    });

    test('Adding products to cart marks table occupied and starts timer immediately', () {
      final sampleItem = MenuItemModel(
        id: 'item_1',
        name: 'Paneer Butter Masala',
        category: 'Main Course',
        price: 250.0,
        description: 'Rich creamy paneer curry',
      );

      // 1. Table is initially free with no timing
      expect(db.tables[0].status, TableStatus.free);
      expect(db.tables[0].occupiedSince, isNull);

      // 2. Add product to table cart
      db.setLiveTableCart('T-1', [CartItemModel(item: sampleItem, quantity: 1)]);

      // Table should immediately be occupied with an occupiedSince timestamp
      expect(db.tables[0].status, TableStatus.occupied);
      expect(db.tables[0].occupiedSince, isNotNull);
      final initialStartTime = db.tables[0].occupiedSince!;

      // 3. Adding more products to cart preserves initial startTime
      db.setLiveTableCart('T-1', [
        CartItemModel(item: sampleItem, quantity: 2),
      ]);
      expect(db.tables[0].occupiedSince, equals(initialStartTime));
    });

    test('Printing KOT and printing Bill preserves the original occupiedSince without restarting', () async {
      final initialTime = DateTime(2026, 9, 13, 12, 0, 0).toIso8601String();
      db.tables[0] = db.tables[0].copyWith(
        status: TableStatus.occupied,
        occupiedSince: initialTime,
      );

      final sampleItem = MenuItemModel(
        id: 'item_1',
        name: 'Paneer Butter Masala',
        category: 'Main Course',
        price: 250.0,
        description: 'Rich creamy paneer curry',
      );

      // 1. Print KOT (changes status to runningKot)
      await db.updateTableStatus(
        'tbl_lifecycle',
        TableStatus.runningKot,
        orderId: 'ORD-123',
        occupiedSince: db.tables[0].occupiedSince,
      );

      expect(db.tables[0].status, TableStatus.runningKot);
      expect(db.tables[0].occupiedSince, equals(initialTime));

      // 2. Print Bill / Save & Print (saves order and updates table status)
      await db.saveAndPrintOrder(
        existingOrderId: 'ORD-123',
        items: [CartItemModel(item: sampleItem, quantity: 2)],
        tableNumber: 'T-1',
        orderType: OrderType.dineIn,
        discountAmount: 0.0,
        tipAmount: 0.0,
        deliveryCharge: 0.0,
      );

      expect(db.tables[0].status, TableStatus.runningKot);
      expect(db.tables[0].occupiedSince, equals(initialTime));

      // 3. Incoming socket update with later time should NOT restart ongoing timer
      final laterTime = DateTime(2026, 9, 13, 12, 15, 0).toIso8601String();
      final socketTable = db.tables[0].copyWith(
        occupiedSince: laterTime,
      );
      db.socketService.onTableUpdated?.call(socketTable);

      expect(db.tables[0].occupiedSince, equals(initialTime));
    });

    test('Incoming socket update with status free does NOT wipe out locally running table with cart items', () {
      final initialTime = DateTime(2026, 9, 13, 12, 0, 0).toIso8601String();
      db.tables[0] = db.tables[0].copyWith(
        status: TableStatus.occupied,
        occupiedSince: initialTime,
      );
      final sampleItem = MenuItemModel(
        id: 'item_1',
        name: 'Paneer Butter Masala',
        category: 'Main Course',
        price: 250.0,
        description: 'Rich creamy paneer curry',
      );
      db.setLiveTableCart('T-1', [CartItemModel(item: sampleItem, quantity: 1)]);

      // Stale socket event arrives saying table is free
      final socketTable = db.tables[0].copyWith(
        status: TableStatus.free,
        occupiedSince: null,
      );
      db.socketService.onTableUpdated?.call(socketTable);

      // Table MUST remain occupied and continuous timer preserved!
      expect(db.tables[0].status, TableStatus.occupied);
      expect(db.tables[0].occupiedSince, equals(initialTime));
    });

    test('Settling order stops timing and frees table', () {
      final initialTime = DateTime(2026, 9, 13, 12, 0, 0).toIso8601String();
      db.tables[0] = db.tables[0].copyWith(
        status: TableStatus.runningKot,
        occupiedSince: initialTime,
      );

      // Settle / checkout order
      db.clearTableCartAndFree('T-1');

      expect(db.tables[0].status, TableStatus.free);
      expect(db.tables[0].occupiedSince, isNull);
      expect(db.tables[0].getRunningDuration(), isNull);
    });

    testWidgets('TableManagementScreen mobile view places Takeaway and Delivery buttons below Add Table', (tester) async {
      OrderType? triggeredOrderType;
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableManagementScreen(
              onTakeOrderForType: (type) {
                triggeredOrderType = type;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Takeaway'), findsOneWidget);
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('Add Table'), findsOneWidget);

      final addTableTop = tester.getTopLeft(find.text('Add Table')).dy;
      final takeawayTop = tester.getTopLeft(find.text('Takeaway')).dy;
      final deliveryTop = tester.getTopLeft(find.text('Delivery')).dy;

      // On mobile view, Takeaway and Delivery are positioned below Add Table
      expect(takeawayTop, greaterThan(addTableTop));
      expect(deliveryTop, greaterThan(addTableTop));

      // Tap Takeaway button
      await tester.tap(find.text('Takeaway'));
      await tester.pumpAndSettle();
      expect(triggeredOrderType, OrderType.takeaway);

      // Tap Delivery button
      await tester.tap(find.text('Delivery'));
      await tester.pumpAndSettle();
      expect(triggeredOrderType, OrderType.delivery);
    });

    testWidgets('TableManagementScreen desktop view places Takeaway, Delivery, and Add Table inline', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableManagementScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Takeaway'), findsOneWidget);
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('Add Table'), findsOneWidget);

      final addTableTop = tester.getTopLeft(find.text('Add Table')).dy;
      final takeawayTop = tester.getTopLeft(find.text('Takeaway')).dy;
      final deliveryTop = tester.getTopLeft(find.text('Delivery')).dy;

      // On desktop view, all action buttons are on the same horizontal row
      expect((takeawayTop - addTableTop).abs(), lessThan(5.0));
      expect((deliveryTop - addTableTop).abs(), lessThan(5.0));
    });
  });
}
