import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../network/api_endpoints.dart';
import '../database/database_service.dart';

/// Global network connectivity & reachability service for offline/online state detection.
class NetworkService {
  static NetworkService? _activeInstance;
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal() {
    _activeInstance = this;
    _startMonitoring();
  }

  /// Triggers an immediate connectivity re-check only if [NetworkService] is already
  /// actively monitoring, avoiding unexpected timers in isolated tests.
  static void notifyConnectionFailureIfActive() {
    final instance = _activeInstance;
    if (instance != null && (instance._monitorTimer?.isActive ?? false)) {
      unawaited(instance.checkNow());
    }
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
    if (_lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!) < const Duration(seconds: 2)) {
      return _lastCheckResult;
    }

    return checkNow();
  }

  /// Returns true when [url] targets a public internet host rather than localhost or LAN.
  @visibleForTesting
  static bool isPublicInternetUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) return false;
    final host = uri.host.toLowerCase();
    if (host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '0.0.0.0' ||
        host.endsWith('.local')) {
      return false;
    }

    final parts = host.split('.');
    if (parts.length == 4 && parts.every((p) => int.tryParse(p) != null)) {
      final a = int.parse(parts[0]);
      final b = int.parse(parts[1]);
      if (a == 10 || a == 127) return false;
      if (a == 192 && b == 168) return false;
      if (a == 172 && b >= 16 && b <= 31) return false;
      if (a == 169 && b == 254) return false;
    }

    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  Future<bool> _checkConnectivity() async {
    if (kIsWeb) {
      return _anySucceeds([
        _probeHttpStatus('https://dns.google/resolve?name=example.com&type=A', expectedStatus: 200),
        _probeHttpStatus('${ApiEndpoints.productionApiUrl}/health', expectedStatus: 200),
      ]);
    }

    final checks = <Future<bool>>[
      _probeGenerate204('https://connectivitycheck.gstatic.com/generate_204'),
      _probeGenerate204('https://clients3.google.com/generate_204'),
      _probeSocket('1.1.1.1', 443),
      _probeSocket('8.8.8.8', 53),
    ];

    // Only treat the configured API endpoint as internet reachability when it is public.
    if (isPublicInternetUrl(ApiEndpoints.baseUrl)) {
      checks.add(ApiEndpoints.testConnection(ApiEndpoints.baseUrl));
    }

    return _anySucceeds(checks);
  }

  Future<bool> _anySucceeds(List<Future<bool>> checks) {
    if (checks.isEmpty) return Future.value(false);
    final completer = Completer<bool>();
    var remaining = checks.length;

    for (final check in checks) {
      check.then((ok) {
        if (ok && !completer.isCompleted) {
          completer.complete(true);
        } else {
          remaining--;
          if (remaining == 0 && !completer.isCompleted) {
            completer.complete(false);
          }
        }
      }).catchError((_) {
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          completer.complete(false);
        }
      });
    }

    return completer.future;
  }

  Future<bool> _probeHttpStatus(String url, {required int expectedStatus}) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(milliseconds: 1600));
      return response.statusCode == expectedStatus;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _probeGenerate204(String url) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(milliseconds: 1400);
      final request = await client
          .getUrl(Uri.parse(url))
          .timeout(const Duration(milliseconds: 1400));
      final response = await request
          .close()
          .timeout(const Duration(milliseconds: 1400));
      await response.drain<void>().timeout(const Duration(milliseconds: 500));
      return response.statusCode == 204;
    } catch (_) {
      return false;
    } finally {
      try {
        client?.close(force: true);
      } catch (_) {}
    }
  }

  Future<bool> _probeSocket(String host, int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 1400),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
  }
}
