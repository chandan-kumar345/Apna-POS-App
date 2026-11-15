import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart' show DioException, Options;

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../network/api_exception.dart';

typedef ChotuTurnTransport =
    Future<Map<String, dynamic>> Function(
      Map<String, dynamic> payload,
      String? apiKey,
    );

/// Durable transport for the agent. A lost response never becomes local success.
class ChotuAutomationClient {
  ChotuAutomationClient({ChotuTurnTransport? transport})
    : _transport = transport ?? _post;

  final ChotuTurnTransport _transport;
  bool _inFlight = false;

  static Future<Map<String, dynamic>> _post(
    Map<String, dynamic> payload,
    String? apiKey,
  ) async {
    // Pin this mutation to its captured API origin. General POS transport may
    // rediscover another host after a timeout, which is unsafe for a lost receipt.
    final origin = payload['_apiBaseUrl']?.toString() ?? ApiEndpoints.baseUrl;
    if (origin != ApiEndpoints.baseUrl) {
      throw StateError('API origin changed while dispatching the order');
    }
    final endpoint = '$origin${ApiEndpoints.chotuAgentTurn}';
    dynamic body;
    try {
      final response = await ApiClient().dio.post<dynamic>(
        endpoint,
        data: Map<String, dynamic>.from(payload)..remove('_apiBaseUrl'),
        options: Options(
          followRedirects: false,
          headers: apiKey != null && apiKey.isNotEmpty
              ? {'x-gemini-api-key': apiKey}
              : null,
        ),
      );
      body = response.data;
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
    if (body is! Map || body['data'] is! Map) {
      throw const FormatException('Missing Chotu turn receipt');
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  static String pendingKey(String scope) =>
      'chotu_agent_pending_${base64Url.encode(utf8.encode(scope))}';

  Future<bool> hasPending(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(pendingKey(scope));
  }

  static bool canInstallSnapshot({
    required List<Map<String, dynamic>> current,
    required List<Map<String, dynamic>> before,
    required List<Map<String, dynamic>> original,
    required List<Map<String, dynamic>> incoming,
    required bool recoveredPending,
  }) {
    String signature(List<Map<String, dynamic>> lines) {
      final entries =
          lines
              .map(
                (line) => jsonEncode([
                  line['productId'],
                  line['quantity'],
                  line['note'] ?? '',
                  line['price'],
                  line['gstPercent'],
                ]),
              )
              .toList()
            ..sort();
      return entries.join('|');
    }

    final now = signature(current);
    if (now == signature(incoming)) return true;
    return now == signature(before) &&
        (!recoveredPending || now == signature(original));
  }

  Future<Map<String, dynamic>> runTurn({
    required String scope,
    required String sessionId,
    required String text,
    String? tableNumber,
    String? apiKey,
    List<Map<String, dynamic>>? expectedDrafts,
    String? apiBaseUrl,
    String? businessId,
    String? userId,
  }) async {
    if (_inFlight) {
      return {
        'status': 'busy',
        'chotuMessage': 'Chotu abhi previous instruction process kar raha hai.',
      };
    }
    _inFlight = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = pendingKey(scope);
      final saved = prefs.getString(key);
      final payload = saved == null
          ? <String, dynamic>{
              'sessionId': sessionId,
              'requestId':
                  'turn_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(0x7fffffff)}',
              'text': text.trim(),
              'currentTableContext': tableNumber ?? '',
              '_apiBaseUrl': ?apiBaseUrl,
              'expectedBusinessId': ?businessId,
              'expectedUserId': ?userId,
              if (expectedDrafts != null && expectedDrafts.isNotEmpty)
                'expectedDrafts': expectedDrafts,
            }
          : Map<String, dynamic>.from(jsonDecode(saved) as Map);
      final replayingPrevious = saved != null && payload['text'] != text.trim();
      // Persist before dispatch. If storage fails, do not send a potentially
      // unrepeatable order mutation.
      if (saved == null && !await prefs.setString(key, jsonEncode(payload))) {
        throw StateError('Unable to persist the pending order instruction');
      }
      final result = await _transport(payload, apiKey);
      const statuses = {
        'completed',
        'answered',
        'needs_clarification',
        'needs_confirmation',
        'unsupported',
        'rejected',
        'needs_review',
      };
      if (!statuses.contains(result['status'])) {
        throw const FormatException('Unrecognised Chotu turn receipt');
      }
      await prefs.remove(key);
      return {
        ...result,
        'recoveredPending': saved != null,
        'requestDrafts': payload['expectedDrafts'] ?? const [],
        if (replayingPrevious)
          'chotuMessage':
              '${result['chotuMessage'] ?? ''} Previous instruction ka result hai; nayi instruction dobara boliye.',
      };
    } on ApiException catch (error) {
      // Validation errors are definitive non-execution. Authentication errors,
      // timeouts and conflicts retain the identity for reconciliation/retry.
      if (error.statusCode == 400 || error.statusCode == 422) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(pendingKey(scope));
      }
      return {
        'status': 'unconfirmed',
        'errorCode': error.code,
        'accessStatusCode': error.statusCode,
        'chotuMessage':
            '${error.message} Order success confirm nahi hua. Same instruction repeat karke receipt check kijiye.',
      };
    } catch (_) {
      return {
        'status': 'unconfirmed',
        'chotuMessage':
            'Order ka result confirm nahi hua. Same instruction repeat karke receipt check kijiye. Local order execute nahi hua.',
      };
    } finally {
      _inFlight = false;
    }
  }
}
