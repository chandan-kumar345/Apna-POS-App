import 'dart:async';
import 'dart:convert';

import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/models/table_model.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/security/secure_storage_service.dart';
import 'package:apna_pos/core/services/cart_api_service.dart';
import 'package:apna_pos/core/services/network_service.dart';
import 'package:apna_pos/core/services/socket_service.dart';
import 'package:apna_pos/features/pos/pos_register_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CountedItem extends MenuItemModel {
  var serializations = 0;
  var priceReads = 0;
  var nameReads = 0;
  @override
  String get name {
    nameReads++;
    return super.name;
  }
  _CountedItem(int number)
    : super(
        id: 'burst-$number',
        productId: 'burst-$number',
        name: 'Burst item $number',
        description: '',
        category: 'Drinks',
        price: 25,
      );
  @override
  double get effectivePrice {
    priceReads++;
    return super.effectivePrice;
  }

  @override
  Map<String, dynamic> toJson() {
    serializations++;
    return super.toJson();
  }
}

class _CartAdapter implements HttpClientAdapter {
  final requests = <Map<String, dynamic>>[];
  var inFlight = 0;
  var peakInFlight = 0;
  var loseResponse = false;
  Completer<void>? holdResponse;
  final started = Completer<void>();
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    if (options.path.contains('/cart/')) {
      inFlight++;
      if (inFlight > peakInFlight) peakInFlight = inFlight;
      requests.add({
        'path': options.path,
        ...Map<String, dynamic>.from(options.data as Map),
      });
      if (!started.isCompleted) started.complete();
      await holdResponse?.future;
      await Future<void>.delayed(const Duration(milliseconds: 25));
      inFlight--;
      if (loseResponse) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }
    }
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': {}}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseService();
  final dio = ApiClient().dio;
  late HttpClientAdapter priorAdapter;
  late List<Interceptor> priorInterceptors;
  late _CartAdapter adapter;
  late _CountedItem first;
  late _CountedItem untouched;
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          storage,
          (call) async => null,
        );
    priorAdapter = dio.httpClientAdapter;
    priorInterceptors = List<Interceptor>.from(dio.interceptors);
    dio.interceptors.clear();
    adapter = _CartAdapter();
    dio.httpClientAdapter = adapter;
    await SecureStorageService().clearAll();
    await db.init();
    db.stopAutoSync();
    await SecureStorageService().saveAccessToken('quantity-fixture-token');
    db.currentUser = UserModel(
      id: 'quantity-owner',
      name: 'Owner',
      email: 'burst@example.test',
      role: 'Owner',
      pin: '',
      restaurantId: 'quantity-business',
    );
    db.restaurant = RestaurantModel(
      id: 'quantity-business',
      name: 'Burst Cafe',
      tagline: '',
      phone: '',
      address: '',
      cuisineType: 'Cafe',
      posViewMode: 'without_image',
      billingType: 'Non-GST',
    );
    db.orders = [];
    db.tables = [
      TableModel(
        id: 'burst-table',
        tableNumber: 9,
        name: 'T-9',
        status: TableStatus.occupied,
        occupiedSince: '2026-11-14T00:00:00Z',
      ),
    ];
    first = _CountedItem(0);
    untouched = _CountedItem(1);
    db.menuItems = [
      first,
      untouched,
      for (var i = 2; i < 20; i++) _CountedItem(i),
    ];
    db.categories = ['Drinks'];
    db.setLiveTableCart('T-9', [], total: 0);
  });

  tearDown(() {
    db.stopAutoSync();
    SocketService().disconnect();
    NetworkService().dispose();
    dio.httpClientAdapter = priorAdapter;
    dio.interceptors.addAll(priorInterceptors);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null);
  });

  test(
    'mixed edits, removal and clear remain ordered behind the quantity burst',
    () async {
      final api = CartApiService();
      final edits = [
        for (var i = 0; i < 20; i++)
          api.addToCart(item: first, tableNumber: 'T-9', variantName: 'Small'),
        for (var i = 0; i < 7; i++)
          api.reduceProductFromCart(
            productId: first.id,
            tableNumber: 'T-9',
            variantName: 'Small',
          ),
        api.removeItemFromCart(
          productId: first.id,
          tableNumber: 'T-9',
          variantName: 'Small',
        ),
        api.addToCart(
          item: first,
          tableNumber: 'T-9',
          variantName: 'Large',
          quantity: 3,
        ),
      ];
      final clear = api.clearCart(tableNumber: 'T-9');
      await Future.wait([...edits, clear]);
      expect(adapter.requests.map((r) => r['path']), [
        '/cart/add',
        '/cart/reduce',
        '/cart/remove',
        '/cart/add',
        '/cart/clear',
      ]);
      expect(adapter.requests.first['quantity'], 20);
      expect(adapter.requests[1]['quantity'], 7);
      expect(adapter.requests[3]['product']['variantName'], 'Large');
      expect(adapter.requests[3]['quantity'], 3);
      expect(adapter.peakInFlight, 1);
    },
  );

  test(
    'edits arriving during a slow request are combined into one ordered follow-up',
    () async {
      adapter.holdResponse = Completer<void>();
      final api = CartApiService();
      final firstEdit = api.addToCart(item: first, tableNumber: 'T-9');
      final flushing = api.flushPending(tableNumber: 'T-9');
      await adapter.started.future;
      final next = List.generate(
        25,
        (_) => api.addToCart(item: first, tableNumber: 'T-9'),
      );
      expect(adapter.requests, hasLength(1));
      adapter.holdResponse!.complete();
      await Future.wait([firstEdit, ...next]);
      await flushing;
      expect(adapter.requests.map((r) => r['quantity']), [1, 25]);
      expect(adapter.peakInFlight, 1);
    },
  );

  test('different variants and tables keep their own quantities', () async {
    final api = CartApiService();
    await Future.wait([
      api.addToCart(
        item: first,
        tableNumber: 'T-9',
        variantName: 'Small',
        quantity: 2,
      ),
      api.addToCart(
        item: first,
        tableNumber: 'T-9',
        variantName: 'Large',
        quantity: 4,
      ),
      api.addToCart(
        item: first,
        tableNumber: 'T-10',
        variantName: 'Small',
        quantity: 6,
      ),
    ]);
    expect(adapter.requests, hasLength(3));
    expect(
      adapter.requests
          .where((r) => r['tableNumber'] == 'T-9')
          .map((r) => r['quantity']),
      [2, 4],
    );
    expect(
      adapter.requests.singleWhere(
        (r) => r['tableNumber'] == 'T-10',
      )['quantity'],
      6,
    );
  });

  test(
    'pending edits are discarded instead of being sent using another account',
    () async {
      final pending = CartApiService().addToCart(
        item: first,
        tableNumber: 'T-9',
      );
      db.currentUser = db.currentUser!.copyWith(
        id: 'different-owner',
        restaurantId: 'different-business',
      );
      expect(await pending, isNull);
      expect(adapter.requests, isEmpty);
    },
  );

  test(
    'a lost mutation response is not automatically replayed as a second increment',
    () async {
      adapter.loseResponse = true;
      expect(
        await CartApiService().addToCart(
          item: first,
          tableNumber: 'T-9',
          quantity: 10,
        ),
        isNull,
      );
      expect(adapter.requests, hasLength(1));
    },
  );

  test(
    'a quantity burst updates memory immediately and persists one latest snapshot',
    () async {
      first.serializations = 0;
      var notifications = 0;
      void listener() => notifications++;
      db.addListener(listener);
      try {
        for (var quantity = 1; quantity <= 50; quantity++) {
          db.setLiveTableCart(
            'T-9',
            [CartItemModel(item: first, quantity: quantity)],
            total: quantity * 25,
            deferPersistence: true,
            notifyImmediately: false,
          );
          expect(db.getLiveTableCart('T-9').single.quantity, quantity);
        }
        expect(first.serializations, 0);
        expect(notifications, 0);
        await db.flushLiveCartPersistence();
        expect(first.serializations, 1);
        expect(notifications, 1);
        final prefs = await SharedPreferences.getInstance();
        final saved =
            jsonDecode(
                  prefs.getString('apna_pos_quantity-owner_live_table_carts')!,
                )
                as Map;
        expect(saved['T-9'][0]['quantity'], 50);
        debugPrint(
          'Burst evidence: 50 local edits, 1 serialization, 1 global notification, final quantity 50.',
        );
      } finally {
        db.removeListener(listener);
      }
    },
  );

  test(
    'clear supersedes a buffered draft without resurrecting the old quantity',
    () async {
      db.setLiveTableCart(
        'T-9',
        [CartItemModel(item: first, quantity: 30)],
        total: 750,
        deferPersistence: true,
      );
      db.setLiveTableCart('T-9', [], total: 0);
      await db.flushLiveCartPersistence();
      final prefs = await SharedPreferences.getInstance();
      final saved =
          jsonDecode(
                prefs.getString('apna_pos_quantity-owner_live_table_carts')!,
              )
              as Map;
      expect(saved.containsKey('T-9'), false);
    },
  );

  test(
    '30 rapid increments send one combined delta instead of 30 simultaneous requests',
    () async {
      await Future.wait(
        List.generate(
          30,
          (_) => CartApiService().addToCart(item: first, tableNumber: 'T-9'),
        ),
      );
      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single['quantity'], 30);
      expect(adapter.peakInFlight, 1);
    },
  );

  testWidgets(
    'switching tables during a buffered burst keeps each draft separate',
    (tester) async {
      tester.view.physicalSize = const Size(432, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      db.tables.add(TableModel(id: 'other-burst-table', tableNumber: 10, name: 'T-10',
        status: TableStatus.occupied, occupiedSince: '2026-11-14T00:00:00Z'));
      const key = ValueKey('quantity-pos');
      await tester.pumpWidget(const MaterialApp(home: PosRegisterScreen(key: key, initialTable: 'T-9')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Burst item 0'));
      await tester.pump(const Duration(milliseconds: 30));
      final plus = find.descendant(
        of: find.byKey(const ValueKey('prod_no_img_burst-0_burst-0')),
        matching: find.byIcon(Icons.add_rounded));
      for (var i = 0; i < 9; i++) {
        await tester.tap(plus);
        await tester.pump(const Duration(milliseconds: 5));
      }
      await tester.pumpWidget(const MaterialApp(home: PosRegisterScreen(
        key: key, initialTable: 'T-10', tableSelectionToken: 2)));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Burst item 1'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(db.getLiveTableCart('T-9').single.quantity, 10);
      expect(db.getLiveTableCart('T-10').single.item.id, untouched.id);
      expect(db.getLiveTableCart('T-10').single.quantity, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
    },
  );

  testWidgets('hidden POS ignores unrelated database redraws and reads fresh data on return', (tester) async {
    tester.view.physicalSize = const Size(432, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget host(bool visible) => MaterialApp(home: TickerMode(enabled: visible,
      child: const PosRegisterScreen(initialTable: 'T-9')));
    await tester.pumpWidget(host(true));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(host(false));
    await tester.pump();
    untouched.nameReads = 0;
    for (var i = 0; i < 10; i++) {
      db.setLiveCartTotal('unrelated-update', i.toDouble());
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(untouched.nameReads, 0,
        reason: 'Hidden POS must not rebuild its catalog for background updates');
    db.menuItems = [_CountedItem(99)];
    db.setLiveCartTotal('unrelated-update', 11);
    await tester.pumpWidget(host(true));
    await tester.pump();
    expect(find.text('Burst item 99'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'rapid quantity taps keep exact local cart without rebuilding unrelated cards',
    (tester) async {
      tester.view.physicalSize = const Size(432, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: PosRegisterScreen(initialTable: 'T-9')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Burst item 0'));
      await tester.pump(const Duration(milliseconds: 300));
      first.serializations = 0;
      untouched.priceReads = 0;
      final product = find.byKey(const ValueKey('prod_no_img_burst-0_burst-0'));
      final plus = find.descendant(
        of: product,
        matching: find.byIcon(Icons.add_rounded),
      );
      for (var i = 0; i < 30; i++) {
        await tester.tap(plus);
        await tester.pump(const Duration(milliseconds: 5));
      }
      expect(db.getLiveTableCart('T-9').single.quantity, 31);
      expect(db.getLiveCartTotal('T-9'), 775);
      expect(find.text('31 Items Added'), findsOneWidget);
      expect(
        untouched.priceReads,
        0,
        reason: 'Unchanged product cards must not rebuild for each cart tap',
      );
      expect(
        first.serializations,
        lessThanOrEqualTo(2),
        reason: 'A tap burst must not serialize every draft repeatedly',
      );
      debugPrint(
        'Widget burst: 30 taps, quantity 31, unrelated card rebuilds ${untouched.priceReads}, serializations during burst ${first.serializations}.',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}
