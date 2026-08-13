import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralized API Client for HTTP communication with Apna POS REST Backend Server.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const String _defaultBaseUrl = 'http://10.0.2.2:5000/api'; // Android Emulator default
  static const String _localBaseUrl = 'http://localhost:5000/api';

  String baseUrl = kIsWeb ? _localBaseUrl : _defaultBaseUrl;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders({bool requireAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAuth) {
      final token = await _storage.read(key: 'access_token');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  /// Perform GET request
  Future<http.Response> get(String endpoint, {bool requireAuth = false}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);

    try {
      final response = await http.get(url, headers: headers).timeout(
        const Duration(seconds: 10),
      );
      return response;
    } catch (e) {
      debugPrint('ApiClient GET Error [$endpoint]: $e');
      rethrow;
    }
  }

  /// Perform POST request
  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requireAuth = false,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 10));
      return response;
    } catch (e) {
      debugPrint('ApiClient POST Error [$endpoint]: $e');
      rethrow;
    }
  }
}
