import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:apna_pos/core/network/interceptors/auth_interceptor.dart';
import 'package:apna_pos/core/security/secure_storage_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Storage implements ISecureStorageService {
  String? access = 'expired';
  String? refresh = 'refresh';
  var clears = 0;
  @override
  Future<String?> getAccessToken() async => access;
  @override
  Future<String?> getRefreshToken() async => refresh;
  @override
  Future<void> saveAccessToken(String value) async {
    access = value;
  }

  @override
  Future<void> saveRefreshToken(String value) async {
    refresh = value;
  }

  @override
  Future<void> clearAll() async {
    clears++;
    access = null;
    refresh = null;
  }

  @override
  Future<String?> getDeviceId() async => null;
  @override
  Future<String?> getBusinessId() async => null;
  @override
  Future<String?> getUserId() async => 'saved-user';
  @override
  Future<void> saveDeviceId(String value) async {}
  @override
  Future<void> saveBusinessId(String value) async {}
  @override
  Future<void> saveUserId(String value) async {}
}

class _Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) respond;
  _Adapter(this.respond);
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) => respond(options);
}

ResponseBody _reply(int code, [Object data = const {}]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      code,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Storage storage;
  late Dio dio;
  late Dio refreshDio;
  var refreshes = 0;
  var requests = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = _Storage();
    dio = Dio(BaseOptions(baseUrl: 'http://example.test/api/v1'));
    refreshDio = Dio(BaseOptions(baseUrl: 'http://example.test/api/v1'));
    refreshes = 0;
    requests = 0;
    refreshDio.httpClientAdapter = _Adapter((options) async {
      refreshes++;
      // Bound a broken recursive implementation so the regression fails with
      // evidence instead of continuously issuing refreshes until test timeout.
      if (refreshes > 1) return _reply(401);
      return _reply(200, {
        'data': {'accessToken': 'fresh', 'refreshToken': 'rotated'},
      });
    });
    dio.interceptors.add(
      AuthInterceptor(storage, dio, refreshClient: refreshDio),
    );
  });
  tearDown(() {
    dio.close(force: true);
    refreshDio.close(force: true);
  });

  test(
    'a denied resource retry never loops refresh or deletes valid tokens',
    () async {
      dio.httpClientAdapter = _Adapter((options) async {
        requests++;
        return _reply(401);
      });
      await expectLater(dio.get('/resource'), throwsA(isA<DioException>()));
      expect(refreshes, 1);
      expect(requests, 2);
      expect(storage.clears, 0);
      expect(storage.access, 'fresh');
      expect(storage.refresh, 'rotated');
    },
  );

  test('simultaneous expired requests share a single token rotation', () async {
    final ready = Completer<void>();
    refreshDio.httpClientAdapter = _Adapter((options) async {
      refreshes++;
      await ready.future;
      return _reply(200, {
        'data': {'accessToken': 'fresh', 'refreshToken': 'rotated'},
      });
    });
    dio.httpClientAdapter = _Adapter((options) async {
      requests++;
      return _reply(
        options.headers['Authorization'] == 'Bearer fresh' ? 200 : 401,
      );
    });
    final calls = List.generate(4, (_) => dio.get('/resource'));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    ready.complete();
    final responses = await Future.wait(calls);
    expect(responses.every((r) => r.statusCode == 200), isTrue);
    expect(refreshes, 1);
    expect(requests, 8);
    expect(storage.clears, 0);
  });

  test(
    'a late old-token 401 reuses the already rotated access token',
    () async {
      final lateResponse = Completer<void>();
      dio.httpClientAdapter = _Adapter((options) async {
        if (options.headers['Authorization'] == 'Bearer fresh') {
          return _reply(200);
        }
        if (options.path == '/late') await lateResponse.future;
        return _reply(401);
      });
      final late = dio.get('/late');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await dio.get('/early');
      lateResponse.complete();
      expect((await late).statusCode, 200);
      expect(refreshes, 1);
      expect(storage.clears, 0);
    },
  );

  test('offline refresh failure retains saved credentials', () async {
    dio.httpClientAdapter = _Adapter((_) async => _reply(401));
    refreshDio.httpClientAdapter = _Adapter(
      (options) async => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      ),
    );
    await expectLater(dio.get('/resource'), throwsA(isA<DioException>()));
    expect(storage.clears, 0);
    expect(storage.refresh, 'refresh');
  });

  test(
    'malformed successful refresh does not erase the saved session',
    () async {
      dio.httpClientAdapter = _Adapter((_) async => _reply(401));
      refreshDio.httpClientAdapter = _Adapter(
        (_) async => _reply(200, {'data': {}}),
      );
      await expectLater(dio.get('/resource'), throwsA(isA<DioException>()));
      expect(storage.clears, 0);
      expect(storage.refresh, 'refresh');
    },
  );

  test('explicitly rejected refresh credentials are cleared', () async {
    dio.httpClientAdapter = _Adapter((_) async => _reply(401));
    refreshDio.httpClientAdapter = _Adapter((_) async => _reply(401));
    await expectLater(dio.get('/resource'), throwsA(isA<DioException>()));
    expect(storage.clears, 1);
    expect(storage.refresh, isNull);
  });
}
