import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/models/table_model.dart';
import 'package:flutter_test/flutter_test.dart';

TableModel _table(int number, {double total = 100}) => TableModel(
  id: 'perf-$number',
  tableNumber: number,
  name: 'T-$number',
  status: TableStatus.occupied,
  occupiedSince: '2026-11-13T18:00:00Z',
  activeOrderTotal: total,
  activeItemCount: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseService();
  var notifications = 0;
  void listener() => notifications++;

  setUp(() {
    db.orders = [];
    db.tables = [];
    notifications = 0;
    db.addListener(listener);
  });
  tearDown(() => db.removeListener(listener));

  test('unchanged live total does not notify again', () {
    db.setLiveCartTotal('perf-total', 100);
    notifications = 0;
    for (var i = 0; i < 50; i++) {
      db.setLiveCartTotal('perf-total', 100);
    }
    expect(notifications, 0);
    db.setLiveCartTotal('perf-total', 0);
    expect(notifications, 1);
    db.setLiveCartTotal('perf-total', 0);
    expect(notifications, 1);
  });

  test('duplicate socket snapshots produce only one notification', () {
    final table = _table(901);
    db.socketService.onTableUpdated!(table);
    for (var i = 0; i < 50; i++) {
      // A later server timestamp must not restart the running timer.
      db.socketService.onTableUpdated!(
        table.copyWith(occupiedSince: '2026-11-13T18:01:00Z'),
      );
    }
    expect(notifications, 1);
    expect(db.getLiveCartTotal(table.name), 100);
    expect(db.tables.single.occupiedSince, table.occupiedSince);
  });

  test('changed total and metadata still notify once per event', () {
    final table = _table(902);
    db.socketService.onTableUpdated!(table);
    notifications = 0;
    db.socketService.onTableUpdated!(
      table.copyWith(
        activeOrderTotal: 200,
        activeItemCount: 2,
        floor: 'Terrace',
      ),
    );
    expect(notifications, 1);
    expect(db.getLiveCartTotal(table.name), 200);
    expect(db.tables.single.floor, 'Terrace');
    // Returning to an earlier value is a real change, not a duplicate.
    db.socketService.onTableUpdated!(table);
    expect(notifications, 2);
    expect(db.getLiveCartTotal(table.name), 100);
  });

  test('batch updates notify once and ignore repeated snapshots', () {
    final tables = [_table(903), _table(904)];
    db.socketService.onTablesBatchUpdated!(tables);
    expect(notifications, 1);
    db.socketService.onTablesBatchUpdated!(tables);
    expect(notifications, 1);
    db.socketService.onTablesBatchUpdated!([
      tables.first.copyWith(activeOrderTotal: 150),
      tables.last.copyWith(activeOrderTotal: 250),
    ]);
    expect(notifications, 2);
    expect(db.getLiveCartTotal('T-903'), 150);
    expect(db.getLiveCartTotal('T-904'), 250);
  });

  test('free snapshot clears stale total even if table is unchanged', () {
    final table = _table(905).copyWith(status: TableStatus.free);
    db.tables = [table];
    db.setLiveCartTotal(table.name, 100);
    notifications = 0;
    db.socketService.onTableUpdated!(table);
    expect(db.getLiveCartTotal(table.name), 0);
    expect(notifications, 1);
    db.socketService.onTableUpdated!(table);
    expect(notifications, 1);
  });

  test('free snapshot cannot discard an active local draft', () {
    final table = _table(906);
    db.tables = [table];
    db.setLiveTableCart(table.name, [
      CartItemModel(
        item: MenuItemModel(
          id: 'perf-item',
          name: 'Tea',
          description: '',
          category: 'Drinks',
          price: 10,
        ),
      ),
    ]);
    notifications = 0;
    db.socketService.onTableUpdated!(table.copyWith(status: TableStatus.free));
    expect(notifications, 0);
    expect(db.tables.single.status, TableStatus.occupied);
    expect(db.getLiveTableCart(table.name), hasLength(1));
    db.setLiveTableCart(table.name, []);
  });

  test('cart entry publishes items and total together in one notification', () {
    final table = _table(907);
    db.tables = [table];
    final snapshots = <String>[];
    void capture() => snapshots.add(
      '${db.getLiveTableCart(table.name).length}:${db.getLiveCartTotal(table.name)}',
    );
    db.addListener(capture);
    try {
      db.setLiveTableCart(table.name, [
        CartItemModel(
          item: MenuItemModel(
            id: 'perf-tea',
            name: 'Tea',
            description: '',
            category: 'Drinks',
            price: 10,
          ),
          quantity: 2,
        ),
      ], total: 20);
      expect(notifications, 1);
      expect(snapshots, ['1:20.0']);
      db.setLiveTableCart(table.name, [], total: 0);
      expect(notifications, 2);
      expect(snapshots.last, '0:0.0');
    } finally {
      db.removeListener(capture);
    }
  });
}
