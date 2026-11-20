import 'dart:convert';

import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/models/table_model.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/security/secure_storage_service.dart';
import 'package:apna_pos/core/services/order_service.dart';
import 'package:apna_pos/core/services/socket_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OrderServer implements HttpClientAdapter {
  late OrderModel order;
  final requests = <RequestOptions>[];
  bool failStatusUpdate = false;
  bool hideFromRecentPage = false;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    var code = 200;
    Object data = <String, dynamic>{};
    if (options.path.startsWith('/orders/') &&
        options.path.endsWith('/status')) {
      if (failStatusUpdate) {
        code = 503;
      } else {
        order = order.copyWith(
          status: OrderStatus.values.byName(options.data['status'] as String),
        );
        data = {'order': order.toJson()};
      }
    } else if (options.path == '/orders') {
      data = options.method == 'GET'
          ? {
              'orders': [
                if (!hideFromRecentPage ||
                    options.queryParameters.containsKey('search'))
                  order.toJson(),
              ],
            }
          : {'order': order.toJson()};
    }
    return ResponseBody.fromString(
      jsonEncode({'success': code == 200, 'data': data}),
      code,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

OrderModel _order(OrderStatus status, {bool synced = true}) => OrderModel(
  id: '507f1f77bcf86cd799439011',
  orderNumber: '#ORD-261116-9437',
  tableNumber: 'T01',
  status: status,
  isPaid: status == OrderStatus.completed,
  paymentStatus: status == OrderStatus.completed ? 'paid' : 'pending',
  paymentMethod: status == OrderStatus.completed
      ? 'Cash'
      : 'Pay at Counter / Table',
  isSynced: synced,
  items: [
    CartItemModel(
      item: MenuItemModel(
        id: 'pizza',
        name: 'Pizza',
        category: 'Pizza',
        price: 399,
        description: '',
      ),
      quantity: 1,
    ),
  ],
  subtotal: 399,
  taxAmount: 20,
  totalAmount: 419,
  createdAt: '2026-11-16T00:45:00',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseService();
  final dio = ApiClient().dio;
  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  late HttpClientAdapter oldAdapter;
  late List<Interceptor> oldInterceptors;
  late _OrderServer server;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (_) async => null);
    await SecureStorageService().saveAccessToken('multidevice-test-token');
    oldAdapter = dio.httpClientAdapter;
    oldInterceptors = List.of(dio.interceptors);
    dio.interceptors.clear(keepImplyContentTypeInterceptor: false);
    dio.httpClientAdapter = server = _OrderServer();
    server.order = _order(OrderStatus.completed);
    db.orders = [_order(OrderStatus.pending)];
    db.tables = [];
    db.restaurant = null;
    db.menuItems = [];
    db.currentUser = null;
    db.setLiveTableCart('T01', [], total: 0);
  });

  tearDown(() async {
    await SecureStorageService().clearAll();
    dio.httpClientAdapter = oldAdapter;
    dio.interceptors.clear(keepImplyContentTypeInterceptor: false);
    dio.interceptors.addAll(oldInterceptors);
    SocketService().disconnect();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  for (final status in [
    OrderStatus.completed,
    OrderStatus.cancelled,
    OrderStatus.ready,
  ]) {
    for (final sync in ['orders screen', 'background', 'full refresh']) {
      test('$sync adopts phone $status over cached web pending', () async {
        server.order = _order(status);
        switch (sync) {
          case 'orders screen':
            await db.syncOrdersOnly();
          case 'background':
            await db.syncTablesAndOrdersSilently();
          case 'full refresh':
            await db.syncWithBackend();
        }
        expect(db.orders, hasLength(1));
        expect(db.orders.single.status, status);
        expect(db.orders.single.isSynced, isTrue);
        expect(db.orders.single.isPaid, status == OrderStatus.completed);
      });
    }
  }

  test(
    'server cancellation replaces cached preparing and optional # prefix',
    () async {
      db.orders = [
        _order(OrderStatus.preparing).copyWith(orderNumber: 'ORD-261116-9437'),
      ];
      server.order = _order(OrderStatus.cancelled);
      await db.syncOrdersOnly();
      expect(db.orders, hasLength(1));
      expect(db.orders.single.status, OrderStatus.cancelled);
    },
  );

  test('offline settlement survives a stale active server snapshot', () async {
    db.orders = [_order(OrderStatus.completed, synced: false)];
    server.order = _order(OrderStatus.pending);
    await db.syncOrdersOnly();
    expect(db.orders.single.status, OrderStatus.completed);
    expect(db.orders.single.isSynced, isFalse);
  });

  for (final status in [OrderStatus.completed, OrderStatus.cancelled]) {
    test(
      'legacy local $status is queued when the server still has pending',
      () async {
        db.orders = [_order(status)];
        server.order = _order(OrderStatus.pending);
        await db.syncOrdersOnly();
        expect(db.orders.single.status, status);
        expect(db.orders.single.isSynced, isFalse);
      },
    );
  }

  test(
    'offline payment completion stays queued during a stale server refresh',
    () async {
      await SecureStorageService().clearAll();
      await db.completeOrderPayment(db.orders.single.id, 'Cash');
      expect(db.orders.single.status, OrderStatus.completed);
      expect(db.orders.single.isSynced, isFalse);
      server.order = _order(OrderStatus.pending);
      await SecureStorageService().saveAccessToken('multidevice-test-token');
      await db.syncOrdersOnly();
      expect(db.orders.single.status, OrderStatus.completed);
      expect(db.orders.single.isSynced, isFalse);
    },
  );

  test(
    'old pending order is reconciled even outside the recent server page',
    () async {
      server.hideFromRecentPage = true;
      await db.syncOrdersOnly();
      expect(db.orders.single.status, OrderStatus.completed);
      expect(
        server.requests.any(
          (r) => r.queryParameters['search'] == 'ORD-261116-9437',
        ),
        isTrue,
      );
    },
  );

  test(
    'unsynced stale table pending adopts a completed server order',
    () async {
      db.orders = [_order(OrderStatus.pending, synced: false)];
      await db.syncTablesAndOrdersSilently();
      expect(db.orders.single.status, OrderStatus.completed);
      expect(db.orders.single.isSynced, isTrue);
    },
  );

  test(
    'replayed pending create cannot turn server completion into pending',
    () async {
      final result = await OrderService().createOrder(
        _order(OrderStatus.pending, synced: false),
      );
      expect(result.status, OrderStatus.completed);
      expect(result.isPaid, isTrue);
    },
  );

  test('polled terminal order clears its stale table cart', () async {
    final local = db.orders.single;
    db.tables = [
      TableModel(
        id: 'table-1',
        name: 'T-1',
        tableNumber: 1,
        status: TableStatus.occupied,
        currentOrderId: local.id,
        activeOrderNumber: local.orderNumber,
        activeOrderTotal: 419,
        occupiedSince: local.createdAt,
      ),
    ];
    db.setLiveTableCart('T-1', local.items, total: 419);
    await db.syncOrdersOnly();
    expect(db.tables.single.status, TableStatus.free);
    expect(db.tables.single.currentOrderId, isNull);
    expect(db.getLiveTableCart('T-1'), isEmpty);
    expect(server.requests.where((r) => r.method != 'GET'), isEmpty);
  });

  test(
    'closing an old order preserves a newer active order on the same table',
    () async {
      final newer = _order(
        OrderStatus.preparing,
      ).copyWith(id: 'new-order', orderNumber: 'ORD-NEW');
      db.orders.add(newer);
      db.tables = [
        TableModel(
          id: 'table-1',
          name: 'T-1',
          tableNumber: 1,
          status: TableStatus.runningKot,
          currentOrderId: newer.id,
          activeOrderNumber: newer.orderNumber,
          occupiedSince: newer.createdAt,
        ),
      ];
      db.setLiveTableCart('T-1', newer.items, total: 419);
      await db.syncOrdersOnly();
      expect(db.orders, hasLength(2));
      expect(db.tables.single.status, TableStatus.runningKot);
      expect(db.tables.single.currentOrderId, newer.id);
      expect(db.getLiveTableCart('T-1'), isNotEmpty);
    },
  );

  test(
    'server ready is not downgraded by an older unsynced preparing replay',
    () async {
      server.order = _order(OrderStatus.ready);
      final result = await OrderService().createOrder(
        _order(OrderStatus.preparing, synced: false),
      );
      expect(result.status, OrderStatus.ready);
      expect(server.requests.where((r) => r.method == 'PATCH'), isEmpty);
    },
  );

  test('socket status acknowledgement survives a later refresh', () async {
    server.order = _order(OrderStatus.cancelled);
    SocketService().onOrderUpdated?.call({
      'orderId': server.order.id,
      'orderNumber': server.order.orderNumber,
      'tableNumber': server.order.tableNumber,
      'status': 'cancelled',
    });
    expect(db.orders.single.status, OrderStatus.cancelled);
    expect(db.orders.single.isSynced, isTrue);
    await db.syncOrdersOnly();
    expect(db.orders.single.status, OrderStatus.cancelled);
  });

  test(
    'failed cancellation stays unsynced and is retried in background',
    () async {
      server.order = _order(OrderStatus.pending);
      server.failStatusUpdate = true;
      await db.updateOrderStatus(db.orders.single.id, OrderStatus.cancelled);
      await Future<void>.delayed(Duration.zero);
      expect(db.orders.single.status, OrderStatus.cancelled);
      expect(db.orders.single.isSynced, isFalse);
      server.failStatusUpdate = false;
      await db.syncTablesAndOrdersSilently();
      expect(server.order.status, OrderStatus.cancelled);
      expect(db.orders.single.status, OrderStatus.cancelled);
      expect(db.orders.single.isSynced, isTrue);
    },
  );
}
