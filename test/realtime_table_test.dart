import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/models/table_model.dart';

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
}
