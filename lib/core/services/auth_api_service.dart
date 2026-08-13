import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../security/secure_storage_service.dart';

class AuthApiService {
  static String activeBaseUrl = 'http://localhost:5000/api/auth';
  
  static final List<String> _candidateBaseUrls = [
    'http://localhost:5000/api/auth',
    'http://10.0.2.2:5000/api/auth', // Android Emulator Bridge
    'http://127.0.0.1:5000/api/auth',
  ];

  static final AuthApiService _instance = AuthApiService._internal();
  factory AuthApiService() => _instance;
  AuthApiService._internal();

  final SecureStorageService _storage = SecureStorageService();

  /// Set or override custom server host IP / URL (e.g., http://192.168.1.100:5000)
  static Future<void> setServerUrl(String customUrl) async {
    var clean = customUrl.trim();
    if (clean.isEmpty) return;
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'http://$clean';
    }
    if (!clean.endsWith('/api/auth')) {
      clean = clean.endsWith('/') ? '${clean}api/auth' : '$clean/api/auth';
    }
    activeBaseUrl = clean;
    if (!_candidateBaseUrls.contains(clean)) {
      _candidateBaseUrls.insert(0, clean);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('apna_pos_server_url', clean);
  }

  /// Load custom saved server URL on app initialization
  static Future<void> initServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('apna_pos_server_url');
    if (saved != null && saved.isNotEmpty) {
      activeBaseUrl = saved;
      if (!_candidateBaseUrls.contains(saved)) {
        _candidateBaseUrls.insert(0, saved);
      }
    }
  }

  /// Private helper to perform POST with candidate host fallback
  Future<http.Response> _postWithFallback(String path, Map<String, dynamic> body) async {
    await initServerUrl();
    List<String> urlsToTry = List.from(_candidateBaseUrls);
    if (!urlsToTry.contains(activeBaseUrl)) {
      urlsToTry.insert(0, activeBaseUrl);
    }

    Object? lastError;
    for (String base in urlsToTry) {
      try {
        final uri = Uri.parse('$base$path');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode >= 200 && response.statusCode < 500) {
          activeBaseUrl = base; // Save working URL as active!
          return response;
        }
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Could not connect to authentication server at $activeBaseUrl');
  }

  /// Register a new user on backend Node Express / MongoDB Atlas
  Future<Map<String, dynamic>> register({
    required String name,
    required String password,
    String? email,
    String? phone,
    String? businessName,
    String? deviceId,
    String? deviceName,
  }) async {
    final response = await _postWithFallback('/register', {
      'name': name,
      'password': password,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (businessName != null) 'businessName': businessName,
      'deviceId': deviceId ?? 'flutter_device',
      'deviceName': deviceName ?? 'Flutter App',
    });

    final data = jsonDecode(response.body);
    if (response.statusCode == 201 && data['success'] == true) {
      await _saveTokens(data['accessToken'], data['refreshToken']);
    }
    return data;
  }

  /// Login with email or phone + password on backend Node Express / MongoDB Atlas
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
    String? deviceId,
    String? deviceName,
  }) async {
    try {
      final response = await _postWithFallback('/login', {
        'identifier': identifier,
        'password': password,
        'deviceId': deviceId ?? 'flutter_device',
        'deviceName': deviceName ?? 'Flutter App',
      });

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        await _saveTokens(data['accessToken'], data['refreshToken']);
      }
      return data;
    } catch (e) {
      debugPrint('AuthApiService login network failure: $e');
      return {'success': false, 'message': 'Backend server offline'};
    }
  }

  /// Send OTP to phone
  Future<Map<String, dynamic>> sendOtp(String phone, {String purpose = 'login'}) async {
    final response = await _postWithFallback('/send-otp', {
      'phone': phone,
      'purpose': purpose,
    });
    return jsonDecode(response.body);
  }

  /// Verify OTP and login/register
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    String? name,
    String? deviceId,
    String? deviceName,
  }) async {
    final response = await _postWithFallback('/verify-otp', {
      'phone': phone,
      'otp': otp,
      if (name != null) 'name': name,
      'deviceId': deviceId ?? 'flutter_device',
      'deviceName': deviceName ?? 'Flutter App',
    });

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      await _saveTokens(data['accessToken'], data['refreshToken']);
    }
    return data;
  }

  /// Refresh Access Token using stored Refresh Token
  Future<bool> refreshToken() async {
    final refreshToken = await _storage.read('refresh_token');
    if (refreshToken == null) return false;

    try {
      final response = await _postWithFallback('/refresh-token', {
        'refreshToken': refreshToken,
        'deviceId': 'flutter_device',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          await _saveTokens(data['accessToken'], data['refreshToken']);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Get current user profile
  Future<Map<String, dynamic>?> getMe() async {
    final token = await _storage.read('access_token');
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$activeBaseUrl/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 401) {
        final refreshed = await refreshToken();
        if (refreshed) {
          return getMe();
        }
        return null;
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return null;
  }

  /// Get active logged in devices
  Future<List<dynamic>> getActiveDevices() async {
    final token = await _storage.read('access_token');
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$activeBaseUrl/devices'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['devices'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  /// Logout from this device
  Future<bool> logout() async {
    final token = await _storage.read('access_token');
    if (token != null) {
      try {
        await _postWithFallback('/logout', {
          'deviceId': 'flutter_device',
        });
      } catch (_) {}
    }
    await _storage.delete('access_token');
    await _storage.delete('refresh_token');
    return true;
  }

  /// Save tokens to Secure Storage
  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    await _storage.write('access_token', accessToken);
    await _storage.write('refresh_token', refreshToken);
  }
}
