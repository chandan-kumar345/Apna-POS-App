import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/models/table_model.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/database/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real-Time Table Model Tests', () {
    test('TableModel correctly deserializes status strings', () {
      final jsonFree = {
        'id': 'tbl_1',
        'tableNumber': 1,
        'name': 'T-1',
        'floor': 'Ground Floor',
        'capacity': 4,
        'status': 'free',
      };
      final tableFree = TableModel.fromJson(jsonFree);
      expect(tableFree.status, TableStatus.free);
      expect(tableFree.name, 'T-1');

      final jsonOccupied = {
        'id': 'tbl_2',
        'tableNumber': 2,
        'name': 'T-2',
        'floor': 'Ground Floor',
        'capacity': 4,
        'status': 'occupied',
        'occupiedSince': '14:30',
      };
      final tableOccupied = TableModel.fromJson(jsonOccupied);
      expect(tableOccupied.status, TableStatus.occupied);
      expect(tableOccupied.occupiedSince, '14:30');

      final jsonKot = {
        'id': 'tbl_3',
        'tableNumber': 3,
        'name': 'T-3',
        'floor': '1st Floor',
        'capacity': 6,
        'status': 'runningKot',
        'activeOrder': {
          'id': 'ord_123',
          'orderNumber': 'ORD-5501',
          'totalAmount': 750.0,
          'itemCount': 3,
        }
      };
      final tableKot = TableModel.fromJson(jsonKot);
      expect(tableKot.status, TableStatus.runningKot);
      expect(tableKot.activeOrderNumber, 'ORD-5501');
      expect(tableKot.activeOrderTotal, 750.0);
      expect(tableKot.activeItemCount, 3);
    });

    test('isSameTable correctly matches diverse table name formats across devices', () {
      expect(isSameTable('T-1', 'T-1'), isTrue);
      expect(isSameTable('T-1', '1'), isTrue);
      expect(isSameTable('1', 'T-1'), isTrue);
      expect(isSameTable('Table 1', 'T-1'), isTrue);
      expect(isSameTable('t1', 'T-1'), isTrue);
      expect(isSameTable('T-1', 'T-2'), isFalse);
      expect(isSameTable('T-5', '5'), isTrue);
    });

    test('Selective TableModel copyWith preserves unaffected fields', () {
      final original = TableModel(
        id: 'tbl_5',
        tableNumber: 5,
        name: 'T-5',
        floor: 'Terrace',
        capacity: 4,
        status: TableStatus.free,
      );

      final updated = original.copyWith(
        status: TableStatus.occupied,
        occupiedSince: '15:45',
        activeOrderTotal: 320.0,
      );

      expect(updated.id, 'tbl_5');
      expect(updated.tableNumber, 5);
      expect(updated.name, 'T-5');
      expect(updated.floor, 'Terrace');
      expect(updated.capacity, 4);
      expect(updated.status, TableStatus.occupied);
      expect(updated.occupiedSince, '15:45');
      expect(updated.activeOrderTotal, 320.0);
    });

    test('Table Status Lifecycle: Free -> Occupied on adding products -> Running KOT on Print KOT -> Free on Settle/Clear', () {
      // 1. Initial State: Free table
      var table = TableModel(
        id: 'tbl_10',
        tableNumber: 10,
        name: 'T-10',
        floor: 'Ground Floor',
        capacity: 4,
        status: TableStatus.free,
      );
      expect(table.status, TableStatus.free);
      expect(table.activeOrderTotal, 0.0);

      // 2. User adds products into table cart -> status becomes Occupied
      table = table.copyWith(
        status: TableStatus.occupied,
        activeItemCount: 2,
        activeOrderTotal: 480.0,
        occupiedSince: '12:30',
      );
      expect(table.status, TableStatus.occupied);
      expect(table.activeOrderTotal, 480.0);
      expect(table.activeItemCount, 2);

      // 3. User clicks Print KOT -> status becomes Running KOT
      table = table.copyWith(
        status: TableStatus.runningKot,
        currentOrderId: 'ORD-9901',
        activeOrderNumber: '20260912-1230-T10',
        activeOrderTotal: 480.0,
      );
      expect(table.status, TableStatus.runningKot);
      expect(table.currentOrderId, 'ORD-9901');

      // 4. Order is Settled / Cart Cleared -> status returns to Free
      table = table.copyWith(
        status: TableStatus.free,
        currentOrderId: null,
        activeOrderNumber: null,
        activeOrderTotal: 0.0,
        activeItemCount: 0,
        occupiedSince: null,
      );
      expect(table.status, TableStatus.free);
      expect(table.activeOrderTotal, 0.0);
      expect(table.activeItemCount, 0);
      expect(table.currentOrderId, isNull);
    });
  });

  group('Multi-Device Table Settlement & Real-Time Sync Tests', () {
    final db = DatabaseService();

    setUp(() {
      db.tables = [
        TableModel(
          id: 'tbl_3',
          tableNumber: 3,
          name: 'Table 3',
          floor: 'Ground Floor',
          capacity: 4,
          status: TableStatus.occupied,
          occupiedSince: '12:00',
          activeOrderTotal: 500.0,
          activeItemCount: 2,
        ),
        TableModel(
          id: 'tbl_4',
          tableNumber: 4,
          name: 'Table 4',
          floor: 'Ground Floor',
          capacity: 4,
          status: TableStatus.runningKot,
          occupiedSince: '12:10',
          activeOrderTotal: 300.0,
          activeItemCount: 1,
        ),
      ];
      db.orders = [
        OrderModel(
          id: 'ord_table3',
          orderNumber: 'ORD-7701',
          tableNumber: 'Table 3',
          orderType: OrderType.dineIn,
          status: OrderStatus.preparing,
          paymentStatus: 'pending',
          isPaid: false,
          subtotal: 500.0,
          taxAmount: 0.0,
          totalAmount: 500.0,
          items: [],
          createdAt: DateTime.now().toIso8601String(),
        ),
        OrderModel(
          id: 'ord_table4',
          orderNumber: 'ORD-7702',
          tableNumber: 'Table 4',
          orderType: OrderType.dineIn,
          status: OrderStatus.preparing,
          paymentStatus: 'pending',
          isPaid: false,
          subtotal: 300.0,
          taxAmount: 0.0,
          totalAmount: 300.0,
          items: [],
          createdAt: DateTime.now().toIso8601String(),
        ),
      ];
      final item = MenuItemModel(
        id: 'item_naan',
        name: 'Butter Naan',
        category: 'Breads',
        price: 50.0,
        description: 'Hot butter naan',
      );
      db.setLiveTableCart('Table 3', [CartItemModel(item: item, quantity: 2)]);
    });

    test('When peer device settles Table 3, onOrderSettled frees Table 3 and purges cart while preserving Table 4', () {
      // Pre-condition: Table 3 is occupied with local cart and active order
      expect(db.tables[0].status, TableStatus.occupied);
      expect(db.getLiveTableCart('Table 3').length, 1);
      expect(db.orders[0].status, OrderStatus.preparing);

      // Simulate incoming order:settled socket event from Android
      db.socketService.onOrderSettled?.call({
        'orderId': 'ord_table3',
        'orderNumber': 'ORD-7701',
        'tableNumber': 'Table 3',
        'status': 'completed',
        'paymentStatus': 'paid',
        'totalAmount': 500.0,
        'paymentMethod': 'Cash',
      });

      // 1. Table 3 MUST be free, with zero active order total and no running duration
      expect(db.tables[0].status, TableStatus.free);
      expect(db.tables[0].occupiedSince, isNull);
      expect(db.tables[0].activeOrderTotal, 0.0);
      expect(db.tables[0].activeItemCount, 0);

      // 2. Table 3 cart MUST be completely cleared across all devices
      expect(db.getLiveTableCart('Table 3'), isEmpty);

      // 3. The order in orders list MUST be marked completed and paid
      final settledOrder = db.orders.firstWhere((o) => o.id == 'ord_table3');
      expect(settledOrder.status, OrderStatus.completed);
      expect(settledOrder.isPaid, isTrue);
      expect(settledOrder.paymentStatus, 'paid');

      // 4. Table 4 is unaffected and keeps running
      expect(db.tables[1].status, TableStatus.runningKot);
      expect(db.tables[1].occupiedSince, '12:10');
    });

    test('When remote table update reports free, stale draft cart from settled session does not zombie-lock table', () {
      // Mark local order completed
      db.orders[0] = db.orders[0].copyWith(status: OrderStatus.completed, isPaid: true, paymentStatus: 'paid');

      // Incoming socket table update says Table 3 is free
      final remoteFree = db.tables[0].copyWith(
        status: TableStatus.free,
        occupiedSince: null,
        activeOrderTotal: 0.0,
        activeItemCount: 0,
        currentOrderId: null,
        activeOrderNumber: null,
      );

      db.socketService.onTableUpdated?.call(remoteFree);

      // Table 3 MUST be freed and stale draft cart purged!
      expect(db.tables[0].status, TableStatus.free);
      expect(db.getLiveTableCart('Table 3'), isEmpty);
    });
  });
}
