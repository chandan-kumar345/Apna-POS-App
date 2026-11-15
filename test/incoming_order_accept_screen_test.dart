import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/services/sound_service.dart';
import 'package:apna_pos/features/orders/incoming_order_accept_screen.dart';
import 'package:apna_pos/features/orders/widgets/incoming_order_accept_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseService();
  final captureDirectory = Platform.environment['INCOMING_ORDER_CAPTURE_DIR'];
  var id = 0;
  late bool originalSound;
  setUpAll(() async {
    final file = File('C:/Windows/Fonts/segoeui.ttf');
    if (captureDirectory != null && file.existsSync()) {
      await (FontLoader('OrderReview')..addFont(
            Future.value(ByteData.sublistView(file.readAsBytesSync())),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db.orders.clear();
    originalSound = SoundService.soundEnabled;
    SoundService.soundEnabled = false;
    id++;
  });
  tearDown(() {
    SoundService.soundEnabled = originalSound;
  });

  Future<void> mount(
    WidgetTester tester, {
    String? table = 'T12',
    String type = 'dineIn',
    String source = 'storefront',
    String address = '',
    Size size = const Size(390, 844),
    GlobalKey? key,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: captureDirectory == null ? null : 'OrderReview',
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: IncomingOrderAcceptScreen(
            orderId: 'incoming-test-$id',
            orderNumber: 'ORD-261115-7048',
            customerPhone: '+91 80846 06550',
            customerName: 'Nakul',
            totalAmount: 337,
            orderType: type,
            source: source,
            tableNumber: table,
            deliveryAddress: address,
            items: const [
              {
                'name': 'Achari Paneer Pizza',
                'quantity': 1,
                'price': 309,
                'foodType': 'veg',
                'variantName': 'Regular',
                'note': 'Less spicy',
              },
            ],
            createdAt: DateTime(2026, 11, 15, 13, 2),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (captureDirectory == null) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(captureDirectory).createSync(recursive: true);
      File(
        '$captureDirectory/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final source in ['whatsapp', 'online', 'store']) {
    testWidgets('incoming order labels the $source source independently of table type', (tester) async {
      await mount(tester, source: source);
      expect(find.text('${source == 'whatsapp' ? 'WhatsApp' : source == 'store' ? 'Store' : 'Online'}'), findsOneWidget);
      expect(find.text('Table 12'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'table QR order shows the table, real items, totals and kitchen actions',
    (tester) async {
      final key = GlobalKey();
      await mount(tester, key: key);
      expect(find.text('Table 12'), findsOneWidget);
      expect(find.text('TABLE QR ORDER'), findsOneWidget);
      expect(find.text('#ORD-261115-7048'), findsOneWidget);
      expect(find.text('Nakul'), findsOneWidget);
      expect(find.text('Achari Paneer Pizza'), findsOneWidget);
      expect(find.text('Regular'), findsOneWidget);
      expect(find.text('Note: Less spicy'), findsOneWidget);
      expect(find.text('\u20b9337'), findsOneWidget);
      expect(find.text('Accept & send to kitchen'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.byTooltip('Call customer'), findsOneWidget);
      expect(db.orders.single.tableNumber, '12');
      expect(db.orders.single.isPaid, isFalse);
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'table-order-390');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'all preparation times are available and changing selection works',
    (tester) async {
      await mount(tester, size: const Size(320, 740));
      for (final value in [10, 15, 20, 25, 30, 45]) {
        expect(find.text('$value mins'), findsOneWidget);
      }
      await tester.ensureVisible(find.text('30 mins'));
      await tester.tap(find.text('30 mins'));
      await tester.pump();
      expect(
        tester
            .widget<IncomingOrderAcceptView>(
              find.byType(IncomingOrderAcceptView),
            )
            .selectedPrepTime,
        30,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'nested notification payload with empty metadata retains table and order ID',
    (tester) async {
      late BuildContext routeContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              routeContext = context;
              return const Scaffold();
            },
          ),
        ),
      );
      final route = IncomingOrderAcceptScreen.openFromPayload(routeContext, {
        'type': 'new_order',
        'tableNumber': '',
        'metadata': jsonEncode({'tableNumber': '', 'orderId': ''}),
        'order': {
          '_id': 'nested-order-$id',
          'orderNumber': 'NESTED-$id',
          'tableNumber': 'T07',
          'customerName': 'Nakul',
          'orderType': 'dineIn',
          'orderSource': 'storefront',
          'totalAmount': 337,
          'items': [
            {'name': 'Pizza', 'price': 337, 'quantity': 1},
          ],
        },
      });
      await tester.pumpAndSettle();
      expect(find.text('Table 7'), findsOneWidget);
      expect(db.orders.single.id, 'nested-order-$id');
      expect(db.orders.single.tableNumber, '7');
      Navigator.of(tester.element(find.byType(IncomingOrderAcceptView))).pop();
      await tester.pumpAndSettle();
      await route;
      expect(IncomingOrderAcceptScreen.isShowing, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('table number refreshes if the order arrives after the alert', (
    tester,
  ) async {
    await mount(tester, table: null, source: 'table_qr');
    expect(find.text('Table number not provided'), findsOneWidget);
    expect(find.text('Table 1'), findsNothing);
    db.upsertOrderLocally(db.orders.single.copyWith(tableNumber: 'T03'));
    await tester.pump();
    expect(find.text('Table 3'), findsOneWidget);
    expect(find.text('Table number not provided'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'delivery address does not create a false table and decline remains available',
    (tester) async {
      await mount(
        tester,
        table: null,
        type: 'delivery',
        source: 'whatsapp',
        address: '12 Stable Road, Block T12',
      );
      expect(find.text('Delivery order'), findsOneWidget);
      expect(find.text('12 Stable Road, Block T12'), findsOneWidget);
      expect(find.text('TABLE QR ORDER'), findsNothing);
      expect(find.text('Accept order'), findsOneWidget);
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(find.text('Restaurant is closing soon'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'timer updates without rebuilding the full order view and mute toggles',
    (tester) async {
      await mount(tester);
      final original = tester.widget<IncomingOrderAcceptView>(
        find.byType(IncomingOrderAcceptView),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('89s'), findsOneWidget);
      expect(
        identical(
          original,
          tester.widget(find.byType(IncomingOrderAcceptView)),
        ),
        isTrue,
      );
      await tester.tap(find.byTooltip('Mute order alert'));
      await tester.pump();
      expect(find.byTooltip('Unmute order alert'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'compact layout and larger text avoid overflow while actions remain visible',
    (tester) async {
      final key = GlobalKey();
      await mount(tester, key: key, size: const Size(320, 740), textScale: 1.2);
      expect(find.text('Table 12'), findsOneWidget);
      expect(find.text('Decline').hitTestable(), findsOneWidget);
      expect(
        find.text('Accept & send to kitchen').hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'table-order-320');
      await tester.ensureVisible(find.text('45 mins'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
