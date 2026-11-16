import 'dart:convert';
import 'dart:typed_data';

import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/navigation/merchant_section.dart';
import 'package:apna_pos/core/navigation/merchant_web_router.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/services/local_notification_service.dart';
import 'package:apna_pos/core/services/network_service.dart';
import 'package:apna_pos/core/services/socket_service.dart';
import 'package:apna_pos/core/services/sound_service.dart';
import 'package:apna_pos/features/auth/login_screen.dart';
import 'package:apna_pos/features/auth/splash_screen.dart';
import 'package:apna_pos/features/dashboard/dashboard_screen.dart';
import 'package:apna_pos/features/dashboard/main_layout.dart';
import 'package:apna_pos/features/notifications/services/notification_service.dart';
import 'package:apna_pos/features/pos/pos_register_screen.dart';
import 'package:apna_pos/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MerchantAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.path.endsWith('/status')
        ? {'isActive': true, 'expiresAt': '2099-01-01T00:00:00Z'}
        : {'unreadCount': 0};
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  final db = DatabaseService();
  final dio = ApiClient().dio;
  const navigation = SystemChannels.navigation;
  const codec = JSONMethodCodec();

  UserModel merchant(String role, List<String> permissions) => UserModel(
    id: role.toLowerCase(),
    name: role,
    email: '${role.toLowerCase()}@example.test',
    role: role,
    pin: '',
    restaurantId: 'merchant-route-test',
    permissions: permissions,
    onboardingCompleted: true,
  );

  Future<void> finishSplash(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(SplashScreen.writingDuration);
    await tester.pump();
    await tester.pump(SplashScreen.completedLogoHoldDuration);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  Future<void> browserLocation(WidgetTester tester, String path) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      navigation.name,
      codec.encodeMethodCall(
        MethodCall('pushRouteInformation', {'location': path, 'state': null}),
      ),
      (_) {},
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
    'merchant links restore login, switch the live shell and enforce staff permissions',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      final reports = <MethodCall>[];
      messenger.setMockMethodCallHandler(navigation, (call) async {
        if (call.method == 'routeInformationUpdated') reports.add(call);
        return null;
      });
      final originalAdapter = dio.httpClientAdapter;
      final originalInterceptors = List<Interceptor>.of(dio.interceptors);
      dio.httpClientAdapter = _MerchantAdapter();
      dio.interceptors.clear();
      SharedPreferences.setMockInitialValues({});
      SoundService.soundEnabled = false;
      db.currentUser = null;
      db.restaurant = RestaurantModel(
        id: 'merchant-route-test',
        name: 'Route Cafe',
        tagline: '',
        phone: '',
        address: '',
        cuisineType: 'Cafe',
        isSubscribed: true,
      );
      await db.updateSubscriptionStatus(true);
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final layout = find.byType(MainLayout);
      MerchantWebRouterDelegate router() =>
          MerchantWebRouterDelegate.maybeOf(tester.element(layout))!;
      int selectedIndex() => tester
          .widget<SmoothAnimatedIndexedStack>(
            find.byType(SmoothAnimatedIndexedStack),
          )
          .index;

      try {
        await tester.pumpWidget(
          ApnaPosApp(
            initialHome: const SplashScreen(openLoginWhenSignedOut: true),
            merchantWebLocation: Uri.parse('/dashboard'),
          ),
        );
        expect(layout, findsNothing);
        await finishSplash(tester);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(layout, findsNothing);

        // Complete the session as interactive sign-in does, without a network
        // login: install the authenticated user and replace the login page.
        db.currentUser = merchant('Owner', const ['*']);
        LocalNotificationService.navigatorKey.currentState!
            .pushReplacement<void, void>(
              MaterialPageRoute(builder: (_) => const MainLayout()),
            );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(selectedIndex(), MerchantSection.dashboard.index);
        expect(find.byType(GlassDashboardScreen), findsOneWidget);
        expect(router().currentConfiguration.path, '/dashboard');
        final firstShell = tester.state(layout);

        // Use the real dashboard's navigation callback, then deliver the
        // same platform messages used by browser Back and Forward.
        tester
            .widget<GlassDashboardScreen>(find.byType(GlassDashboardScreen))
            .onNavigateTab!(MerchantSection.pos.index);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(selectedIndex(), MerchantSection.pos.index);
        expect(find.byType(PosRegisterScreen), findsOneWidget);
        expect(router().currentConfiguration.path, '/pos');
        expect(
          reports.any(
            (call) =>
                call.arguments['uri'] == '/pos' &&
                call.arguments['replace'] == false,
          ),
          isTrue,
        );
        final pos = tester.state(find.byType(PosRegisterScreen));

        await browserLocation(tester, '/dashboard');
        expect(selectedIndex(), MerchantSection.dashboard.index);
        await browserLocation(tester, '/pos');
        expect(selectedIndex(), MerchantSection.pos.index);
        expect(tester.state(layout), same(firstShell));
        expect(tester.state(find.byType(PosRegisterScreen)), same(pos));

        // Opening a separate /dashboard URL as a cashier still goes through
        // the same section-access checks, and leaves the allowed POS active.
        await tester.pumpWidget(const SizedBox.shrink());
        db.currentUser = merchant('Cashier', const ['pos']);
        await tester.pumpWidget(
          ApnaPosApp(
            initialHome: const SplashScreen(openLoginWhenSignedOut: true),
            merchantWebLocation: Uri.parse('/dashboard'),
          ),
        );
        await finishSplash(tester);
        expect(selectedIndex(), MerchantSection.pos.index);
        expect(find.byType(GlassDashboardScreen), findsNothing);
        expect(router().currentConfiguration.path, '/pos');
        expect(find.textContaining('Access Denied'), findsOneWidget);

        // Refreshing a canonical POS URL with a restored session opens POS
        // directly without the login screen.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          ApnaPosApp(
            initialHome: const SplashScreen(openLoginWhenSignedOut: true),
            merchantWebLocation: Uri.parse('/pos'),
          ),
        );
        await finishSplash(tester);
        expect(selectedIndex(), MerchantSection.pos.index);
        expect(find.byType(LoginScreen), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        SocketService().disconnect();
        NetworkService().dispose();
        NotificationService().dispose();
        db.currentUser = null;
        db.restaurant = null;
        dio.httpClientAdapter = originalAdapter;
        dio.interceptors.addAll(originalInterceptors);
        messenger.setMockMethodCallHandler(navigation, null);
        await tester.pump(const Duration(seconds: 2));
      }
    },
  );
}
