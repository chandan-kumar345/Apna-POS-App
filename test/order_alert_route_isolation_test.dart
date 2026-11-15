import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:apna_pos/main.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/navigation/storefront_route.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/services/local_notification_service.dart';
import 'package:apna_pos/features/auth/splash_screen.dart';
import 'package:apna_pos/features/storefront/screens/customer_storefront_screen.dart';
import 'package:apna_pos/features/orders/incoming_order_accept_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'public storefront routes stay web-only and preserve table QR context',
    () {
      for (final url in [
        '/pizza-47/R=R1&T=T04',
        '/store/pizza-47?R=R1&T=T04',
        '/?store=pizza-47&restaurantCode=R1&tableCode=T04',
        '/#/pizza-47?R=R1&T=T04',
        '/#/store/pizza-47/R=R1&T=T04',
      ]) {
        final uri = Uri.parse(url);
        expect(parseStorefrontRoute(uri, isWeb: false), isNull);
        final web = parseStorefrontRoute(uri, isWeb: true)!;
        expect(web.slug, 'pizza-47', reason: url);
        expect(web.restaurantCode, 'R1', reason: url);
        expect(web.tableCode, 'T04', reason: url);
      }
      for (final route in ['/login', '/dashboard', '/admin', '/splash']) {
        expect(parseStorefrontRoute(Uri.parse(route), isWeb: true), isNull);
      }
    },
  );
  late List<Interceptor> original;
  final requests = <String>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({'sound_feedback_enabled': false});
    FlutterSecureStorage.setMockInitialValues({});
    DatabaseService().orders.clear();
    SplashScreen.isSplashActive = false;
    requests.clear();
    original = List.of(ApiClient().dio.interceptors);
    ApiClient().dio.interceptors
      ..clear()
      ..add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options.path);
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 404,
                  data: {'message': 'Storefront not found'},
                ),
              ),
            );
          },
        ),
      );
  });
  tearDown(() {
    ApiClient().dio.interceptors
      ..clear()
      ..addAll(original);
    SplashScreen.isSplashActive = false;
  });

  testWidgets(
    'native notification initial route never opens a customer storefront',
    (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/incoming-order';
      addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
      );
      await tester.pumpWidget(
        const ApnaPosApp(initialHome: Scaffold(body: Text('Merchant POS'))),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(CustomerStorefrontScreen), findsNothing);
      expect(find.text('Merchant POS'), findsOneWidget);
      expect(requests.where((path) => path.contains('/storefront/')), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'warm unknown native route cannot replace an order alert with storefront error',
    (tester) async {
      await tester.pumpWidget(
        const ApnaPosApp(initialHome: Scaffold(body: Text('Merchant POS'))),
      );
      await tester.pump();
      final context = tester.element(find.text('Merchant POS'));
      Navigator.of(context).pushNamed('/notification-launch');
      await tester.pumpAndSettle();
      expect(find.byType(CustomerStorefrontScreen), findsNothing);
      LocalNotificationService.handlePayloadDirectly({
        'type': 'qr_order',
        'orderId': 'route-isolation-qr',
        'orderNumber': 'ROUTE-QR',
        'orderSource': 'storefront',
        'orderType': 'dineIn',
        'tableNumber': 'T04',
        'customerName': 'Test guest',
        'totalAmount': 249,
        'items': [
          {'name': 'Pizza', 'quantity': 1, 'price': 249},
        ],
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byType(IncomingOrderAcceptScreen), findsOneWidget);
      expect(find.text('Table 4'), findsOneWidget);
      expect(find.byType(CustomerStorefrontScreen), findsNothing);
      expect(requests.where((path) => path.contains('/storefront/')), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
