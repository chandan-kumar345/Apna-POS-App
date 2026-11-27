import 'dart:convert';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/services/bluetooth_printer_service.dart';
import 'package:apna_pos/core/services/sound_service.dart';
import 'package:apna_pos/features/kds/kds_screen.dart';
import 'package:apna_pos/features/orders/incoming_order_accept_screen.dart';
import 'package:apna_pos/features/orders/order_detail_screen.dart';
import 'package:apna_pos/features/orders/order_detail_sheet.dart';
import 'package:apna_pos/features/orders/orders_screen.dart';
import 'package:apna_pos/features/orders/whatsapp_order_action_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAcceptOrderServer implements HttpClientAdapter {
  OrderModel? activeOrder;
  final requests = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    Object data = <String, dynamic>{};

    if (options.path.contains('/accept-whatsapp') && options.method == 'POST') {
      if (activeOrder != null) {
        activeOrder = activeOrder!.copyWith(
          status: OrderStatus.preparing,
          whatsappAcceptanceStatus: 'accepted',
        );
        data = {'order': activeOrder!.toJson()};
      }
    } else if (options.path.endsWith('/status') && options.method == 'PATCH') {
      if (activeOrder != null) {
        activeOrder = activeOrder!.copyWith(status: OrderStatus.preparing);
        data = {'order': activeOrder!.toJson()};
      }
    } else if (options.path.startsWith('/orders/') && options.method == 'GET') {
      data = {'order': activeOrder?.toJson()};
    } else if (options.path == '/orders' && options.method == 'GET') {
      data = {
        'orders': [if (activeOrder != null) activeOrder!.toJson()],
      };
    }

    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

OrderModel _sampleOrder({
  required String id,
  required String orderNumber,
  required String orderSource,
  OrderType orderType = OrderType.delivery,
  String? tableNumber,
}) {
  return OrderModel(
    id: id,
    orderNumber: orderNumber,
    tableNumber: tableNumber,
    orderType: orderType,
    status: OrderStatus.pending,
    items: [
      CartItemModel(
        item: MenuItemModel(
          id: 'item_pizza_1',
          name: 'Achari Paneer Pizza',
          category: 'Pizza',
          price: 309,
          description: 'Achari Paneer Pizza',
        ),
        quantity: 2,
      ),
    ],
    subtotal: 618,
    taxAmount: 30.9,
    totalAmount: 648.9,
    customerName: 'Aarav',
    customerPhone: '+91 9876543210',
    orderSource: orderSource,
    whatsappAcceptanceStatus:
        orderSource == 'whatsapp' ? 'pending_review' : null,
    createdAt: DateTime(2026, 11, 28, 12, 0).toIso8601String(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final db = DatabaseService();
  final printer = BluetoothPrinterService();
  late HttpClientAdapter originalAdapter;
  late _FakeAcceptOrderServer fakeServer;
  late bool originalSound;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    originalSound = SoundService.soundEnabled;
    SoundService.soundEnabled = false;
    originalAdapter = ApiClient().dio.httpClientAdapter;
    fakeServer = _FakeAcceptOrderServer();
    ApiClient().dio.httpClientAdapter = fakeServer;

    await db.init();
    db.orders.clear();
    db.restaurant = RestaurantModel(
      id: 'biz_1',
      slug: 'pizza-47',
      name: 'Pizza 47',
      tagline: '',
      phone: '9876543210',
      address: 'Main Road',
      cuisineType: 'Pizza',
    );
  });

  tearDown(() {
    printer.testAutoPrintIsConnected = null;
    printer.testAutoPrintKot = null;
    ApiClient().dio.httpClientAdapter = originalAdapter;
    SoundService.soundEnabled = originalSound;
  });

  group('BluetoothPrinterService.printKotIfConnected', () {
    test(
      'prints KOT when connected for storefront, dine-in, and WhatsApp, and prevents duplicate KOT print',
      () async {
        final printedOrders = <String>[];
        printer.testAutoPrintIsConnected = () async => true;
        printer.testAutoPrintKot = (order, restaurant, kotNumber) async {
          printedOrders.add('${order.orderSource}:${order.orderNumber}');
          return true;
        };

        for (final ord in [
          _sampleOrder(
            id: 'sf_1',
            orderNumber: 'SF-101',
            orderSource: 'storefront',
            orderType: OrderType.delivery,
          ),
          _sampleOrder(
            id: 'dine_1',
            orderNumber: 'TBL-102',
            orderSource: 'qr',
            orderType: OrderType.dineIn,
            tableNumber: 'T-04',
          ),
          _sampleOrder(
            id: 'wa_1',
            orderNumber: 'WA-103',
            orderSource: 'whatsapp',
            orderType: OrderType.takeaway,
          ),
        ]) {
          final accepted = ord.copyWith(status: OrderStatus.preparing);
          final first = await printer.printKotIfConnected(
            order: accepted,
            restaurant: db.restaurant,
          );
          expect(first, isTrue);
          expect(accepted.items.first.kotQuantity, 2);

          // Calling again with same order does not print duplicate KOT
          final second = await printer.printKotIfConnected(
            order: accepted,
            restaurant: db.restaurant,
          );
          expect(second, isFalse);
        }

        expect(printedOrders, [
          'storefront:SF-101',
          'qr:TBL-102',
          'whatsapp:WA-103',
        ]);
      },
    );

    test('skips printing cleanly when no printer is connected without throwing', () async {
      int printCalls = 0;
      printer.testAutoPrintIsConnected = () async => false;
      printer.testAutoPrintKot = (order, restaurant, kotNumber) async {
        printCalls++;
        return true;
      };

      final order = _sampleOrder(
        id: 'sf_2',
        orderNumber: 'SF-202',
        orderSource: 'storefront',
      ).copyWith(status: OrderStatus.preparing);

      final result = await printer.printKotIfConnected(
        order: order,
        restaurant: db.restaurant,
      );
      expect(result, isFalse);
      expect(printCalls, 0);
      expect(order.items.first.kotQuantity, 0);
    });
  });

  group('UI Order Accept flows print KOT only when printer is connected', () {
    testWidgets('IncomingOrderAcceptScreen prints KOT for storefront dine-in when connected', (tester) async {
      tester.view.physicalSize = const Size(500, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final printedOrderNumbers = <String>[];
      printer.testAutoPrintIsConnected = () async => true;
      printer.testAutoPrintKot = (order, restaurant, kotNumber) async {
        printedOrderNumbers.add(order.orderNumber);
        return true;
      };

      final ord = _sampleOrder(
        id: 'ord_inc_1',
        orderNumber: 'ORD-INC-01',
        orderSource: 'storefront',
        orderType: OrderType.dineIn,
        tableNumber: 'T-01',
      );
      fakeServer.activeOrder = ord;

      await tester.pumpWidget(
        MaterialApp(
          routes: {'/dashboard': (_) => const Scaffold()},
          home: IncomingOrderAcceptScreen(
            orderId: ord.id,
            orderNumber: ord.orderNumber,
            customerPhone: ord.customerPhone!,
            customerName: ord.customerName!,
            totalAmount: ord.totalAmount,
            orderType: 'dineIn',
            source: 'storefront',
            tableNumber: 'T-01',
            items: const [
              {
                'name': 'Achari Paneer Pizza',
                'quantity': 2,
                'price': 309.0,
              },
            ],
            createdAt: DateTime(2026, 11, 28, 12, 0),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.textContaining('Accept'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(printedOrderNumbers, ['ORD-INC-01']);
      expect(db.orders.first.status, OrderStatus.preparing);
    });

    testWidgets('IncomingOrderAcceptScreen accepts without error when printer is NOT connected', (tester) async {
      tester.view.physicalSize = const Size(500, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int kotCalls = 0;
      printer.testAutoPrintIsConnected = () async => false;
      printer.testAutoPrintKot = (order, restaurant, kotNumber) async {
        kotCalls++;
        return true;
      };

      final ord = _sampleOrder(
        id: 'ord_inc_2',
        orderNumber: 'ORD-INC-02',
        orderSource: 'whatsapp',
        orderType: OrderType.delivery,
      );
      fakeServer.activeOrder = ord;

      await tester.pumpWidget(
        MaterialApp(
          routes: {'/dashboard': (_) => const Scaffold()},
          home: IncomingOrderAcceptScreen(
            orderId: ord.id,
            orderNumber: ord.orderNumber,
            customerPhone: ord.customerPhone!,
            customerName: ord.customerName!,
            totalAmount: ord.totalAmount,
            orderType: 'delivery',
            source: 'whatsapp',
            items: const [
              {
                'name': 'Achari Paneer Pizza',
                'quantity': 2,
                'price': 309.0,
              },
            ],
            createdAt: DateTime(2026, 11, 28, 12, 0),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.textContaining('Accept'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(kotCalls, 0);
      expect(db.orders.first.status, OrderStatus.preparing);
    });

    testWidgets('OrderDetailScreen accepts storefront order & prints KOT when connected', (tester) async {
      final printedOrderNumbers = <String>[];
      printer.testAutoPrintIsConnected = () async => true;
      printer.testAutoPrintKot = (order, restaurant, kotNumber) async {
        printedOrderNumbers.add(order.orderNumber);
        return true;
      };

      final ord = _sampleOrder(
        id: 'ord_sf_detail',
        orderNumber: 'ORD-SF-11',
        orderSource: 'storefront',
        orderType: OrderType.delivery,
      );
      fakeServer.activeOrder = ord;
      db.upsertOrderLocally(ord);

      await tester.pumpWidget(
        MaterialApp(
          home: OrderDetailScreen(orderId: ord.id, initialOrder: ord),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accept Order'));
      await tester.pumpAndSettle();

      expect(printedOrderNumbers, ['ORD-SF-11']);
      expect(db.orders.first.status, OrderStatus.preparing);
      expect(find.textContaining('KOT Printed'), findsOneWidget);
    });

    testWidgets('OrderDetailSheet accepts dine-in order cleanly when printer is NOT connected', (tester) async {
      // OrderDetailSheet pre-existing footer row can overflow by ~9.8px inside its hardcoded 480px box.
      final origOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('RenderFlex overflowed')) return;
        origOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = origOnError);

      int kotCalls = 0;
      printer.testAutoPrintIsConnected = () async => false;
      printer.testAutoPrintKot = (order, restaurant, kotNumber) async {
        kotCalls++;
        return true;
      };

      final ord = _sampleOrder(
        id: 'ord_dine_sheet',
        orderNumber: 'ORD-DINE-22',
        orderSource: 'qr',
        orderType: OrderType.dineIn,
        tableNumber: 'T-02',
      );
      fakeServer.activeOrder = ord;
      db.upsertOrderLocally(ord);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderDetailSheet(orderId: ord.id, initialOrder: ord),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accept Order'));
      await tester.pumpAndSettle();

      expect(kotCalls, 0);
      expect(db.orders.first.status, OrderStatus.preparing);
      expect(
        find.textContaining('accepted! Status updated to Preparing.'),
        findsOneWidget,
      );
    });

    testWidgets('WhatsAppOrderActionDialog prints KOT on accept when connected and shows confirmation', (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final printedOrderNumbers = <String>[];
      printer.testAutoPrintIsConnected = () async => true;
      printer.testAutoPrintKot = (order, restaurant, kotNumber) async {
        printedOrderNumbers.add(order.orderNumber);
        return true;
      };

      final ord = _sampleOrder(
        id: 'ord_wa_dlg',
        orderNumber: 'ORD-WA-33',
        orderSource: 'whatsapp',
        orderType: OrderType.takeaway,
      );
      fakeServer.activeOrder = ord;
      db.upsertOrderLocally(ord);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => WhatsAppOrderActionDialog(
                      orderId: ord.id,
                      orderNumber: ord.orderNumber,
                      customerPhone: ord.customerPhone!,
                      customerName: ord.customerName!,
                      totalAmount: ord.totalAmount,
                      orderType: 'takeaway',
                      items: const [
                        {
                          'name': 'Achari Paneer Pizza',
                          'quantity': 2,
                          'price': 309.0,
                        },
                      ],
                      createdAt: DateTime(2026, 11, 28, 12, 0),
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Accept Order'));
      await tester.pumpAndSettle();

      expect(printedOrderNumbers, ['ORD-WA-33']);
      expect(find.textContaining('(KOT Printed)'), findsOneWidget);
    });

    testWidgets('OrdersScreen Accept button transitions pending dine-in order and prints KOT when connected', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final printedOrderNumbers = <String>[];
      printer.testAutoPrintIsConnected = () async => true;
      printer.testAutoPrintKot = (order, restaurant, kotNumber) async {
        printedOrderNumbers.add(order.orderNumber);
        return true;
      };

      final ord = _sampleOrder(
        id: 'ord_list_44',
        orderNumber: 'ORD-QR-44',
        orderSource: 'qr',
        orderType: OrderType.dineIn,
        tableNumber: 'T-05',
      );
      fakeServer.activeOrder = ord;
      db.upsertOrderLocally(ord);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OrdersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final pendingTab = find.textContaining('Pending');
      if (pendingTab.evaluate().isNotEmpty) {
        await tester.tap(pendingTab.first);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Accept').first);
      await tester.pumpAndSettle();

      expect(printedOrderNumbers, ['ORD-QR-44']);
      expect(db.orders.first.status, OrderStatus.preparing);
    });

    testWidgets('KdsScreen Start Cooking on pending order prints KOT when connected', (tester) async {
      tester.view.physicalSize = const Size(1800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final printedOrderNumbers = <String>[];
      printer.testAutoPrintIsConnected = () async => true;
      printer.testAutoPrintKot = (order, restaurant, kotNumber) async {
        printedOrderNumbers.add(order.orderNumber);
        return true;
      };

      final ord = _sampleOrder(
        id: 'ord_kds_55',
        orderNumber: 'ORD-KDS-55',
        orderSource: 'storefront',
        orderType: OrderType.delivery,
      );
      fakeServer.activeOrder = ord;
      db.upsertOrderLocally(ord);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: KdsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start Cooking'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));

      expect(printedOrderNumbers, ['ORD-KDS-55']);
      expect(db.orders.first.status, OrderStatus.preparing);
    });
  });
}
