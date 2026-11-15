import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// A separate platform write models Android/FCM changing storage behind the UI cache.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:apna_pos/core/models/incoming_order_alert.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/services/local_notification_service.dart';
import 'package:apna_pos/core/services/sound_service.dart';
import 'package:apna_pos/features/auth/splash_screen.dart';
import 'package:apna_pos/features/orders/incoming_order_accept_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final android = TargetPlatformVariant.only(TargetPlatform.android);
  const channel = MethodChannel('com.apnapos.app/incoming_order');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var serial = 0;
  Map<String, dynamic>? nativePending;
  Map<String, dynamic> order() => {
    'type': 'qr_order',
    'orderId': 'launch-test-${++serial}',
    'orderNumber': 'LAUNCH-$serial',
    'orderSource': 'storefront',
    'orderType': 'dineIn',
    'tableNumber': 'T02',
    'totalAmount': 309,
    'customerName': 'Test guest',
    'items': [
      {'name': 'Pizza', 'quantity': 1, 'price': 309},
    ],
    'createdAt': DateTime.now().toUtc().toIso8601String(),
  };
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DatabaseService().orders.clear();
    SoundService.soundEnabled = false;
    SplashScreen.isSplashActive = false;
    nativePending = null;
    messenger.setMockMethodCallHandler(channel, (_) async => nativePending);
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.apnapos.app/order_alert'),
      (_) async => false,
    );
  });
  tearDown(() {
    SplashScreen.isSplashActive = false;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.apnapos.app/order_alert'),
      null,
    );
  });
  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: LocalNotificationService.navigatorKey,
        home: const Scaffold(body: Text('POS home')),
      ),
    );
    await tester.pump();
  }

  Future<void> settleOrder(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  Future<void> event(
    Map<String, dynamic> payload, {
    String action = 'view',
  }) async {
    const codec = StandardMethodCodec();
    await messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(
        MethodCall('incomingOrder', {
          'payload': jsonEncode(payload),
          'action': action,
        }),
      ),
      (_) {},
    );
  }

  testWidgets(
    'native warm intent opens order while Flutter remains resumed; duplicate does not stack',
    (tester) async {
      await mount(tester);
      await LocalNotificationService.initializeIncomingOrderBridge();
      final payload = order();
      await event(payload);
      await settleOrder(tester);
      expect(find.byType(IncomingOrderAcceptScreen), findsOneWidget);
      expect(find.text('Table 2'), findsOneWidget);
      await event(payload);
      await settleOrder(tester);
      expect(find.byType(IncomingOrderAcceptScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: android,
  );

  testWidgets(
    'resume reloads a native background write hidden by the UI preferences cache',
    (tester) async {
      await mount(tester);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pending_incoming_order_payload'), isNull);
      final payload = order();
      await SharedPreferencesStorePlatform.instance.setValue(
        'String',
        'flutter.pending_incoming_order_payload',
        jsonEncode(payload),
      );
      expect(prefs.getString('pending_incoming_order_payload'), isNull);
      await LocalNotificationService.checkAndShowPendingIncomingOrder();
      await settleOrder(tester);
      expect(find.byType(IncomingOrderAcceptScreen), findsOneWidget);
      expect(find.text('Table 2'), findsOneWidget);
      expect(prefs.getString('pending_incoming_order_payload'), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: android,
  );

  testWidgets(
    'notification reject acts on the visible order instead of being lost as a duplicate',
    (tester) async {
      await mount(tester);
      await LocalNotificationService.initializeIncomingOrderBridge();
      final payload = order();
      await event(payload);
      await settleOrder(tester);
      await event(payload, action: 'reject');
      await settleOrder(tester);
      expect(find.text('Kitchen is at maximum capacity'), findsOneWidget);
      expect(find.byType(IncomingOrderAcceptScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
    variant: android,
  );

  testWidgets(
    'cold launch keeps the order during splash and presents it after routing',
    (tester) async {
      await mount(tester);
      final payload = order();
      nativePending = {'payload': jsonEncode(payload), 'action': 'view'};
      SplashScreen.isSplashActive = true;
      await LocalNotificationService.initializeIncomingOrderBridge();
      await settleOrder(tester);
      expect(find.byType(IncomingOrderAcceptScreen), findsNothing);
      SplashScreen.isSplashActive = false;
      await LocalNotificationService.checkAndShowPendingIncomingOrder();
      await settleOrder(tester);
      expect(find.byType(IncomingOrderAcceptScreen), findsOneWidget);
      expect(find.text('Table 2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
    variant: android,
  );

  for (final status in [
    'accepted',
    'preparing',
    'ready',
    'completed',
    'rejected',
    'cancelled',
  ]) {
    test('handled $status push never reopens an accept screen', () {
      expect(
        IncomingOrderAlert({...order(), 'status': status}).isIncoming,
        isFalse,
      );
    });
  }

  testWidgets('native stale launch payload never opens an old accept screen', (
    tester,
  ) async {
    await mount(tester);
    final payload = {
      ...order(),
      'createdAt': DateTime.now()
          .subtract(const Duration(hours: 1))
          .toUtc()
          .toIso8601String(),
    };
    nativePending = {'payload': jsonEncode(payload), 'action': 'accept'};
    await LocalNotificationService.initializeIncomingOrderBridge();
    await settleOrder(tester);
    expect(find.byType(IncomingOrderAcceptScreen), findsNothing);
    await tester.pumpWidget(const SizedBox());
  }, variant: android);

  testWidgets(
    'handled event during splash suppresses the old queued incoming order',
    (tester) async {
      await mount(tester);
      await LocalNotificationService.initializeIncomingOrderBridge();
      final payload = order();
      SplashScreen.isSplashActive = true;
      await event(payload);
      LocalNotificationService.handleOrderUpdate({
        ...payload,
        'status': 'accepted',
      });
      SplashScreen.isSplashActive = false;
      await LocalNotificationService.checkAndShowPendingIncomingOrder();
      await settleOrder(tester);
      expect(find.byType(IncomingOrderAcceptScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
    variant: android,
  );

  testWidgets(
    'reject intent queued during splash keeps its action after startup',
    (tester) async {
      await mount(tester);
      await LocalNotificationService.initializeIncomingOrderBridge();
      SplashScreen.isSplashActive = true;
      await event(order(), action: 'reject');
      SplashScreen.isSplashActive = false;
      await LocalNotificationService.checkAndShowPendingIncomingOrder();
      await settleOrder(tester);
      expect(find.text('Kitchen is at maximum capacity'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
    variant: android,
  );

  testWidgets(
    'native handled marker suppresses a cached queued order after background delivery',
    (tester) async {
      await mount(tester);
      await LocalNotificationService.initializeIncomingOrderBridge();
      final payload = order();
      SplashScreen.isSplashActive = true;
      await event(payload);
      await SharedPreferencesStorePlatform.instance.setValue(
        'String',
        'flutter.apna_handled_order_keys',
        jsonEncode({payload['orderId']: DateTime.now().millisecondsSinceEpoch}),
      );
      SplashScreen.isSplashActive = false;
      await LocalNotificationService.checkAndShowPendingIncomingOrder();
      await settleOrder(tester);
      expect(find.byType(IncomingOrderAcceptScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
    variant: android,
  );

  test('payment references and paid orders cannot become incoming screens', () {
    expect(
      IncomingOrderAlert({...order(), 'type': 'payment_received'}).isIncoming,
      isFalse,
    );
    expect(
      IncomingOrderAlert({...order(), 'status': 'paid'}).isIncoming,
      isFalse,
    );
  });
  test(
    'local POS, KOT and customer chat never become urgent incoming screens',
    () {
      expect(
        IncomingOrderAlert({...order(), 'orderSource': 'pos'}).isIncoming,
        isFalse,
      );
      expect(
        IncomingOrderAlert({...order(), 'isKot': true}).isIncoming,
        isFalse,
      );
      expect(
        IncomingOrderAlert({...order(), 'type': 'whatsapp_message'}).isIncoming,
        isFalse,
      );
    },
  );
  test(
    'nested QR/table orders qualify consistently across delivery states',
    () {
      for (final type in [
        'new_order',
        'qr_order',
        'table_order',
        'whatsapp_order_request',
      ]) {
        expect(
          IncomingOrderAlert({
            'metadata': jsonEncode({...order(), 'type': type}),
          }).isIncoming,
          isTrue,
        );
      }
    },
  );
}
