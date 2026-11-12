import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/network/api_exception.dart';
import 'package:apna_pos/core/services/chotu_automation_client.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/network/api_endpoints.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';

class OriginChangeAdapter implements HttpClientAdapter {
  var calls = 0;
  Uri? requested;
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    calls++;
    requested = options.uri;
    await ApiEndpoints.setCustomBaseUrl('https://other.invalid/api/v1');
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('lost response is not retried on a rediscovered API origin', () async {
    final dio = ApiClient().dio;
    final previousAdapter = dio.httpClientAdapter;
    final previousInterceptors = List<Interceptor>.from(dio.interceptors);
    final previousOrigin = ApiEndpoints.baseUrl;
    final adapter = OriginChangeAdapter();
    dio.interceptors.clear();
    dio.httpClientAdapter = adapter;
    try {
      await ApiEndpoints.setCustomBaseUrl('https://original.invalid/api/v1');
      final client = ChotuAutomationClient();
      final result = await client.runTurn(
        scope: 'original|business|user',
        sessionId: 'session',
        text: 'order',
        apiBaseUrl: ApiEndpoints.baseUrl,
      );
      expect(result['status'], 'unconfirmed');
      expect(adapter.calls, 1);
      expect(
        adapter.requested.toString(),
        'https://original.invalid/api/v1/chotu/agent/turn',
      );
      expect(await client.hasPending('original|business|user'), true);
    } finally {
      dio.httpClientAdapter = previousAdapter;
      dio.interceptors.addAll(previousInterceptors);
      await ApiEndpoints.setCustomBaseUrl(previousOrigin);
    }
  });

  test(
    'a lost response persists the exact turn and retries it after recreation',
    () async {
      late Map<String, dynamic> firstPayload;
      final first = ChotuAutomationClient(
        transport: (payload, key) async {
          firstPayload = Map.from(payload);
          throw ApiException(message: 'connection lost', code: 'TIMEOUT');
        },
      );
      final lost = await first.runTurn(
        scope: 'origin|business|user',
        sessionId: 'session-original',
        text: 'Table 5 pe ek naan',
        tableNumber: 'T-5',
        apiKey: 'secret-test-key',
      );
      expect(lost['status'], 'unconfirmed');
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(
        ChotuAutomationClient.pendingKey('origin|business|user'),
      )!;
      expect(saved, isNot(contains('secret-test-key')));
      expect(jsonDecode(saved), firstPayload);
      final recreated = ChotuAutomationClient(
        transport: (payload, key) async {
          expect(payload, firstPayload);
          return {
            'status': 'completed',
            'isDuplicate': true,
            'chotuMessage': 'Order recorded',
          };
        },
      );
      final resolved = await recreated.runTurn(
        scope: 'origin|business|user',
        sessionId: 'new-session',
        text: 'Table 5 pe ek naan',
        tableNumber: 'T-8',
      );
      expect(resolved['isDuplicate'], true);
      expect(await recreated.hasPending('origin|business|user'), false);
    },
  );

  test(
    'another business, actor or origin cannot reuse a pending turn',
    () async {
      final failed = ChotuAutomationClient(
        transport: (_, _) async => throw StateError('offline'),
      );
      await failed.runTurn(
        scope: 'one|business|user',
        sessionId: 'private',
        text: 'private order',
      );
      for (final scope in [
        'one|other-business|user',
        'one|business|other-user',
        'other|business|user',
      ]) {
        final client = ChotuAutomationClient(
          transport: (payload, _) async {
            expect(payload['sessionId'], 'new');
            expect(payload['text'], 'new order');
            return {
              'status': 'needs_clarification',
              'chotuMessage': 'Which table?',
            };
          },
        );
        await client.runTurn(scope: scope, sessionId: 'new', text: 'new order');
      }
      expect(await failed.hasPending('one|business|user'), true);
    },
  );

  test(
    'resolves an older uncertain instruction before accepting a different one',
    () async {
      final failed = ChotuAutomationClient(
        transport: (_, _) async => throw StateError('offline'),
      );
      await failed.runTurn(
        scope: 'scope',
        sessionId: 'session',
        text: 'first order',
      );
      final client = ChotuAutomationClient(
        transport: (payload, _) async {
          expect(payload['text'], 'first order');
          return {
            'status': 'completed',
            'chotuMessage': 'First order recorded',
          };
        },
      );
      final result = await client.runTurn(
        scope: 'scope',
        sessionId: 'session',
        text: 'different order',
      );
      expect(
        result['chotuMessage'],
        contains('nayi instruction dobara boliye'),
      );
    },
  );

  test(
    'a malformed receipt remains unconfirmed and never becomes local success',
    () async {
      final client = ChotuAutomationClient(
        transport: (_, _) async => {'status': 'unknown'},
      );
      final result = await client.runTurn(
        scope: 'scope',
        sessionId: 'session',
        text: 'order',
      );
      expect(result['status'], 'unconfirmed');
      expect(await client.hasPending('scope'), true);
    },
  );

  test(
    'validation rejection clears pending identity, conflict retains it',
    () async {
      for (final status in [400, 409]) {
        final client = ChotuAutomationClient(
          transport: (_, _) async {
            throw ApiException(message: 'Rejected', statusCode: status);
          },
        );
        await client.runTurn(
          scope: '$status',
          sessionId: 'session',
          text: 'order',
        );
        expect(await client.hasPending('$status'), status == 409);
      }
    },
  );

  test('overlapping speech callbacks cannot dispatch a second turn', () async {
    final response = Completer<Map<String, dynamic>>();
    var calls = 0;
    final client = ChotuAutomationClient(
      transport: (_, _) {
        calls++;
        return response.future;
      },
    );
    final first = client.runTurn(
      scope: 'scope',
      sessionId: 'session',
      text: 'first',
    );
    await Future<void>.delayed(Duration.zero);
    final overlap = await client.runTurn(
      scope: 'scope',
      sessionId: 'session',
      text: 'second',
    );
    expect(overlap['status'], 'busy');
    expect(calls, 1);
    response.complete({'status': 'completed', 'chotuMessage': 'Done'});
    await first;
  });

  test(
    'replayed snapshot preserves edits after a lost response, including notes',
    () {
      final original = [
        {
          'productId': 'p',
          'quantity': 1,
          'price': 40,
          'gstPercent': 5,
          'note': '',
        },
      ];
      final edited = [
        {
          'productId': 'p',
          'quantity': 3,
          'price': 40,
          'gstPercent': 5,
          'note': 'no onion',
        },
      ];
      final server = [
        {
          'productId': 'p',
          'quantity': 2,
          'price': 40,
          'gstPercent': 5,
          'note': '',
        },
      ];
      expect(
        ChotuAutomationClient.canInstallSnapshot(
          current: edited,
          before: edited,
          original: original,
          incoming: server,
          recoveredPending: true,
        ),
        false,
      );
      expect(
        ChotuAutomationClient.canInstallSnapshot(
          current: original,
          before: original,
          original: original,
          incoming: server,
          recoveredPending: true,
        ),
        true,
      );
      final changedNote = [
        {
          'productId': 'p',
          'quantity': 1,
          'price': 40,
          'gstPercent': 5,
          'note': 'extra spicy',
        },
      ];
      expect(
        ChotuAutomationClient.canInstallSnapshot(
          current: changedNote,
          before: original,
          original: original,
          incoming: server,
          recoveredPending: false,
        ),
        false,
      );
      expect(
        ChotuAutomationClient.canInstallSnapshot(
          current: server,
          before: edited,
          original: original,
          incoming: server,
          recoveredPending: true,
        ),
        true,
      );
    },
  );
}
