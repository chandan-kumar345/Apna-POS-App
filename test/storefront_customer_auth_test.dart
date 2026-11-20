import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/features/storefront/services/table_qr_phone_auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/storefront_customer_auth_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpClientAdapter old;
  late List<Interceptor> interceptors;
  late StorefrontCustomerAuthAdapter adapter;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final dio = ApiClient().dio;
    old = dio.httpClientAdapter;
    interceptors = List.of(dio.interceptors);
    dio.interceptors.clear();
    dio.httpClientAdapter = adapter = StorefrontCustomerAuthAdapter();
  });
  tearDown(() {
    ApiClient().dio.httpClientAdapter = old;
    ApiClient().dio.interceptors.addAll(interceptors);
  });

  test(
    'wrong code never creates a local customer session; correct code restores across instances',
    () async {
      final auth = TableQrPhoneAuth(restaurantId: 'restaurant-a');
      final challenge = await auth.send('9876543210');
      expect(await auth.token(), isNull);
      await expectLater(challenge.confirm!('123456'), throwsA(anything));
      expect(await auth.token(), isNull);
      final customer = await challenge.confirm!('654321');
      expect(customer.name, 'Valued Customer');
      final restored = await TableQrPhoneAuth(
        restaurantId: 'restaurant-a',
      ).restore();
      expect(restored!.id, customer.id);
      expect(adapter.calls.last.headers['x-storefront-session'], isNotEmpty);
      expect(
        await TableQrPhoneAuth(restaurantId: 'other-restaurant').token(),
        isNull,
      );
    },
  );
  test(
    'optional name is sent only on verification and sign out removes this account token',
    () async {
      final auth = TableQrPhoneAuth(restaurantId: 'restaurant-a');
      final challenge = await auth.send('9876543210');
      expect((await challenge.confirm!('654321', name: ' Aman ')).name, 'Aman');
      final verification = adapter.calls.firstWhere(
        (c) => c.path.endsWith('/verify-otp'),
      );
      expect(verification.data.toString(), contains('Aman'));
      await auth.signOut();
      expect(await auth.restore(), isNull);
    },
  );
  test('failed delivery does not create a verification/session', () async {
    adapter.deliveryFails = true;
    final auth = TableQrPhoneAuth(restaurantId: 'restaurant-a');
    await expectLater(auth.send('9876543210'), throwsA(anything));
    expect(await auth.token(), isNull);
  });
}
