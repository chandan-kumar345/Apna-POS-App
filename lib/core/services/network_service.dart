import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../network/api_endpoints.dart';
import '../database/database_service.dart';

/// Global network connectivity & reachability service for offline/online state detection.
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal() {
    _startMonitoring();
  }

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  bool get isOnline => isOnlineNotifier.value;

  Timer? _monitorTimer;
  DateTime? _lastCheckTime;
  bool _isChecking = false;

  void _startMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      checkNow();
    });
    checkNow();
  }

  void dispose() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  /// Force immediate connection check and notify listeners
  Future<bool> checkNow() async {
    if (_isChecking) return isOnlineNotifier.value;
    _isChecking = true;

    try {
      final wasOnline = isOnlineNotifier.value;
      final isNowOnline = await _checkConnectivity();

      if (isOnlineNotifier.value != isNowOnline) {
        isOnlineNotifier.value = isNowOnline;
        debugPrint('[NetworkService] Connection state changed: ${isNowOnline ? "ONLINE" : "OFFLINE"}');

        // Automatically trigger sync when transitioning from offline to online!
        if (!wasOnline && isNowOnline) {
          try {
            debugPrint('[NetworkService] Reconnected! Triggering automatic cloud sync...');
            DatabaseService().syncWithBackend();
          } catch (e) {
            debugPrint('[NetworkService] Auto-sync error on reconnect: $e');
          }
        }
      }

      _lastCheckResult = isNowOnline;
      _lastCheckTime = DateTime.now();
      return isNowOnline;
    } catch (_) {
      return isOnlineNotifier.value;
    } finally {
      _isChecking = false;
    }
  }

  bool _lastCheckResult = true;

  /// Check whether the device currently has active network / internet access.
  Future<bool> hasInternet() async {
    if (kIsWeb) return true;

    if (_lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!) < const Duration(seconds: 2)) {
      return _lastCheckResult;
    }

    return checkNow();
  }

  Future<bool> _checkConnectivity() async {
    if (kIsWeb) return true;

    // 1. Direct probe to active backend server endpoint if available
    try {
      final isServerAlive = await ApiEndpoints.testConnection(ApiEndpoints.baseUrl);
      if (isServerAlive) return true;
    } catch (_) {}

    // 2. HTTP 204 Connectivity Check (standard Android/Chromium captive portal test)
    try {
      final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 1200);
      final request = await client.getUrl(Uri.parse('https://connectivitycheck.gstatic.com/generate_204'));
      final response = await request.close().timeout(const Duration(milliseconds: 1200));
      client.close();
      if (response.statusCode == 204 || response.statusCode == 200) {
        return true;
      }
    } catch (_) {}

    // 3. Fast DNS host lookup (google.com / 1.1.1.1)
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(milliseconds: 1200));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    return false;
  }
}
