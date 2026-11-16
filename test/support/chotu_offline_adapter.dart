import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';

/// No live credentials, providers or API calls in legacy parser/widget tests.
class ChotuOfflineAdapter implements HttpClientAdapter {
  int mutations = 0;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? data,
    Future<void>? cancel,
  ) async {
    final health = options.path.endsWith('/health');
    if (options.method != 'GET') mutations++;
    return ResponseBody.fromString(
      health
          ? '{"data":{"automationAgent":{"enabled":true,"available":true}}}'
          : '{"error":{"code":"TEST_OFFLINE","message":"Offline fixture"}}',
      health ? 200 : 503,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}
