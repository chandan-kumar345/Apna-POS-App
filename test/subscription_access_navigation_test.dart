import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/services/subscription_service.dart';
import 'package:apna_pos/features/subscription/screens/subscription_screen.dart';
import 'package:apna_pos/features/subscription/widgets/subscription_locked_bottom_sheet.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SubscriptionAdapter implements HttpClientAdapter {
  Future<Map<String, dynamic>> Function()? statusResponse;
  var statusCalls = 0;
  var rejectActivation = false;
  final statusStarted = Completer<void>();

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    Map<String, dynamic> data = {'plans': [], 'addons': []};
    var code = 200;
    if (options.path.endsWith('/status')) {
      statusCalls++;
      if (!statusStarted.isCompleted) statusStarted.complete();
      data = await statusResponse!();
    } else if (options.path.endsWith('/activate') && rejectActivation) {
      code = 400;
      data = {'code': 'PAYMENT_VERIFICATION_REQUIRED'};
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseService();
  final service = SubscriptionService();
  final dio = ApiClient().dio;
  late HttpClientAdapter previousAdapter;
  late List<Interceptor> previousInterceptors;
  late _SubscriptionAdapter adapter;
  const active = {
    'isSubscription': true,
    'isActive': true,
    'isSubscriptionActive': true,
    'subscriptionExpiresAt': '2026-11-17T06:43:19.746Z',
    'expiresAt': '2026-11-17T06:43:19.746Z',
    'status': 'active',
    'plan': 'starter',
  };
  const inactive = {
    'isActive': false,
    'isSubscriptionActive': false,
    'status': 'inactive',
  };

  void account(String suffix) {
    db.currentUser = UserModel(
      id: 'user-$suffix',
      name: 'Subscriber',
      email: 'subscriber-$suffix@example.test',
      role: 'Owner',
      pin: '',
      restaurantId: 'business-$suffix',
    );
    db.restaurant = RestaurantModel(
      id: 'business-$suffix',
      name: 'Subscribed Store',
      tagline: '',
      phone: '',
      address: '',
      cuisineType: 'Restaurant',
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    previousAdapter = dio.httpClientAdapter;
    previousInterceptors = List<Interceptor>.from(dio.interceptors);
    dio.interceptors.clear();
    adapter = _SubscriptionAdapter()..statusResponse = () async => active;
    dio.httpClientAdapter = adapter;
    account('one');
    await db.updateSubscriptionStatus(false);
  });

  tearDown(() async {
    dio.httpClientAdapter = previousAdapter;
    dio.interceptors.addAll(previousInterceptors);
    await db.updateSubscriptionStatus(false);
    db.currentUser = null;
    db.restaurant = null;
  });

  test(
    'fresh active status restores a cached false without interpreting starter as unpaid',
    () async {
      expect(db.isSubscribed, false);
      expect(await service.refreshAccess(), true);
      expect(db.isSubscribed, true);
      expect(adapter.statusCalls, 1);
    },
  );

  test(
    'explicit inactive status clears a previously cached active flag',
    () async {
      await db.updateSubscriptionStatus(true);
      adapter.statusResponse = () async => inactive;
      expect(await service.refreshAccess(), false);
      expect(db.isSubscribed, false);
    },
  );

  test(
    'effective false overrides legacy active text and manual off overrides effective true',
    () {
      expect(
        SubscriptionService.isActiveStatus({
          'isActive': false,
          'status': 'active',
        }),
        false,
      );
      expect(
        SubscriptionService.isActiveStatus({
          'isSubscription': false,
          'isActive': true,
        }),
        false,
      );
      expect(
        SubscriptionService.isActiveStatus({
          'isSubscription': true,
          'isActive': false,
        }),
        false,
      );
    },
  );

  test(
    'concurrent navigation and background refresh share one status request',
    () async {
      final response = Completer<Map<String, dynamic>>();
      adapter.statusResponse = () => response.future;
      final first = service.refreshAccess();
      final second = service.refreshAccess();
    await adapter.statusStarted.future;
      expect(adapter.statusCalls, 1);
      response.complete(active);
      expect(await first, true);
      expect(await second, true);
    },
  );

  test(
    'a delayed response from the previous account cannot activate the current account',
    () async {
      final response = Completer<Map<String, dynamic>>();
      adapter.statusResponse = () => response.future;
      final pending = service.getStatus();
    await adapter.statusStarted.future;
      account('two');
      await db.updateSubscriptionStatus(false);
      response.complete(active);
      await pending;
      expect(db.isSubscribed, false);
    },
  );

  test(
    'a rejected UTR activation cannot manufacture local active status',
    () async {
      adapter.rejectActivation = true;
      expect(
        await service.activateSubscription(paymentRef: 'unverified-utr'),
        false,
      );
      expect(db.isSubscribed, false);
    },
  );

  testWidgets('active subscriber never opens the upgrade bottom sheet', (
    tester,
  ) async {
    var unlocked = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => SubscriptionLockedBottomSheet.show(
                  context,
                  onUnlocked: () => unlocked++,
                ),
                child: const Text('Open feature'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open feature'));
    await tester.pumpAndSettle();
    expect(db.isSubscribed, true);
    expect(unlocked, 1);
    expect(find.byType(SubscriptionLockedBottomSheet), findsNothing);
    expect(find.byType(SubscriptionScreen), findsNothing);
  });

  testWidgets(
    'an existing lock disappears immediately when active status arrives',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2100);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SubscriptionLockedBarrier(
              isLocked: true,
              child: Center(child: Text('Paid feature content')),
            ),
          ),
        ),
      );
      expect(find.byType(SubscriptionLockedBottomSheet), findsOneWidget);
    await tester.runAsync(() => service.refreshAccess());
      await tester.pump();
      expect(find.byType(SubscriptionLockedBottomSheet), findsNothing);
      expect(find.text('Paid feature content'), findsOneWidget);
    },
  );

  testWidgets(
    'already-open subscription screen returns to its feature after a delayed refresh',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2100);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final response = Completer<Map<String, dynamic>>();
      adapter.statusResponse = () => response.future;
      var target = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SubscriptionScreen(
                        sourceFeature: 'loyalty',
                        onNavigateToFeature: (value) => target = value,
                      ),
                    ),
                  ),
                  child: const Text('Open feature'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open feature'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(SubscriptionScreen), findsOneWidget);
      response.complete(active);
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(target, 'loyalty');
      expect(find.byType(SubscriptionScreen), findsNothing);
      expect(find.text('Open feature'), findsOneWidget);
    },
  );
}
