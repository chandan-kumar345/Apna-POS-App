import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/security/secure_storage_service.dart';
import 'package:apna_pos/features/campaign/mobile/mobile_customers_data.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Object response = <String, Object>{
    'success': true,
    'data': <String, Object>{},
  };
  int status = 200;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(response),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Adapter adapter;
  late HttpClientAdapter previous;
  late MobileCustomersApi api;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await SecureStorageService().clearAll();
    await SecureStorageService().saveAccessToken('test-access-token');
    await SecureStorageService().saveBusinessId('business-test');
    adapter = _Adapter();
    previous = ApiClient().dio.httpClientAdapter;
    ApiClient().dio.httpClientAdapter = adapter;
    api = MobileCustomersApi();
  });
  tearDown(() {
    ApiClient().dio.httpClientAdapter = previous;
  });

  test(
    'customer pagination and search use the active business authentication',
    () async {
      adapter.response = {
        'success': true,
        'data': {
          'customers': [
            {'id': 'c1', 'name': 'Customer', 'phone': '+919876500001'},
          ],
          'pagination': {'total': 124, 'page': 2},
        },
      };
      final result = await api.customers(search: 'Customer', page: 2);
      expect(result.total, 124);
      expect(result.page, 2);
      expect(result.customers.single.id, 'c1');
      final request = adapter.requests.single;
      expect(request.path, '/customers');
      expect(request.queryParameters, {
        'search': 'Customer',
        'page': 2,
        'limit': 50,
      });
      expect(request.headers['Authorization'], 'Bearer test-access-token');
      expect(request.headers['X-Business-ID'], 'business-test');
    },
  );
  test(
    'group responses preserve saved membership counts and updated dates',
    () async {
      adapter.response = {
        'success': true,
        'data': [
          {
            'id': 'g1',
            'name': 'Customers',
            'totalNumbers': 1,
            'updatedAt': '2026-11-20T22:00:00Z',
            'numbers': [
              {'phone': '+919876500001', 'name': 'Jane'},
            ],
          },
        ],
      };
      final group = (await api.groups()).single;
      expect(group.totalNumbers, 1);
      expect(group.numbers.single.name, 'Jane');
      expect(group.updatedAt, DateTime.parse('2026-11-20T22:00:00Z'));
    },
  );
  test(
    'create persists exact entered contacts once and requires a saved identifier',
    () async {
      adapter.response = {
        'success': true,
        'data': {
          'id': 'saved-group',
          'name': 'Weekend',
          'numbers': [
            {'phone': '+919876500001'},
          ],
        },
      };
      final group = await api.saveGroup(
        name: ' Weekend ',
        numbers: [
          {'name': 'Jane', 'phone': '+919876500001'},
        ],
      );
      expect(group.id, 'saved-group');
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.data['numbers'], [
        {'name': 'Jane', 'phone': '+919876500001'},
      ]);
      expect(adapter.requests.single.data['name'], 'Weekend');
      adapter.response = {'success': true, 'data': {}};
      await expectLater(
        api.saveGroup(name: 'No record', numbers: []),
        throwsStateError,
      );
    },
  );
  test(
    'failed create and delete propagate failure without local success records',
    () async {
      adapter.status = 503;
      adapter.response = {'success': false, 'message': 'Offline fixture'};
      await expectLater(
        api.saveGroup(
          name: 'Weekend',
          numbers: [
            {'phone': '+919876500001'},
          ],
        ),
        throwsException,
      );
      expect(adapter.requests.length, 1);
      await expectLater(api.deleteGroup('g1'), throwsException);
      expect(adapter.requests.last.method, 'DELETE');
    },
  );
  test(
    'edit uses the saved group endpoint and customer save rejects an empty response',
    () async {
      adapter.response = {
        'success': true,
        'data': {'id': 'g1', 'name': 'Renamed', 'numbers': []},
      };
      await api.saveGroup(id: 'g1', name: 'Renamed', numbers: []);
      expect(adapter.requests.single.method, 'PUT');
      expect(adapter.requests.single.path, '/campaigns/groups/g1');
      adapter.response = {'success': true, 'data': {}};
      await expectLater(
        api.saveCustomer('Jane', '+919876500001'),
        throwsStateError,
      );
    },
  );
}
