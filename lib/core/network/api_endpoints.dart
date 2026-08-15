import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiEndpoints {
  static const String defaultLanIp = '172.16.2.5';
  static const int defaultPort = 5000;

  static String? _resolvedBaseUrl;

  /// Explicitly set custom backend base URL (e.g. http://172.16.2.5:5000/api/v1)
  static Future<void> setCustomBaseUrl(String url) async {
    if (url.trim().isNotEmpty) {
      var clean = url.trim();
      if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
        clean = 'http://$clean';
      }
      if (!clean.endsWith('/api/v1')) {
        if (clean.endsWith('/')) {
          clean = '${clean}api/v1';
        } else {
          clean = '$clean/api/v1';
        }
      }
      _resolvedBaseUrl = clean;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('custom_backend_base_url', clean);
      } catch (_) {}
    }
  }

  static Future<void> resetBaseUrl() async {
    _resolvedBaseUrl = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('custom_backend_base_url');
    } catch (_) {}
  }

  /// Initialize and auto-discover reachable backend server endpoint
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('custom_backend_base_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _resolvedBaseUrl = savedUrl;
        return;
      }
    } catch (_) {}

    if (kIsWeb) {
      _resolvedBaseUrl = 'http://127.0.0.1:$defaultPort/api/v1';
      return;
    }

    // Candidate base URLs in priority order
    final candidates = [
      'http://$defaultLanIp:$defaultPort/api/v1',
      if (Platform.isAndroid) 'http://10.0.2.2:$defaultPort/api/v1',
      'http://127.0.0.1:$defaultPort/api/v1',
      'http://localhost:$defaultPort/api/v1',
    ];

    for (final candidate in candidates) {
      try {
        final response = await http
            .get(Uri.parse('$candidate/health'))
            .timeout(const Duration(milliseconds: 600));
        if (response.statusCode == 200) {
          _resolvedBaseUrl = candidate;
          debugPrint('[ApiEndpoints] Connected to active backend at: $candidate');
          return;
        }
      } catch (_) {}
    }

    // Default fallback if server not yet started during splash
    if (Platform.isAndroid) {
      // Default to Wi-Fi LAN IP so physical devices work out of the box
      _resolvedBaseUrl = 'http://$defaultLanIp:$defaultPort/api/v1';
    } else {
      _resolvedBaseUrl = 'http://127.0.0.1:$defaultPort/api/v1';
    }
  }

  /// Active Base URL
  static String get baseUrl {
    if (_resolvedBaseUrl != null && _resolvedBaseUrl!.isNotEmpty) {
      return _resolvedBaseUrl!;
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:$defaultPort/api/v1';
    }
    if (Platform.isAndroid) {
      return 'http://$defaultLanIp:$defaultPort/api/v1';
    }
    return 'http://127.0.0.1:$defaultPort/api/v1';
  }

  // Auth endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String resetPassword = '/auth/reset-password';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';


  // Onboarding endpoints
  static const String onboardingProfile = '/onboarding/profile';
  static const String onboardingBusiness = '/onboarding/business';
  static const String onboardingAddress = '/onboarding/address';
  static const String onboardingOrderSettings = '/onboarding/order-settings';
  static const String onboardingStatus = '/onboarding/status';
  static const String onboardingComplete = '/onboarding/complete';
}
