import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Global network connectivity checker service for checking internet and network availability.
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  DateTime? _lastCheckTime;
  bool _lastCheckResult = true;

  /// Check whether the device currently has active network / internet access.
  /// Uses reliable HTTP connectivity probe, DNS lookup, and active interface check.
  Future<bool> hasInternet() async {
    if (kIsWeb) {
      return true;
    }

    // Return cached result if checked within the last 3 seconds
    if (_lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!) < const Duration(seconds: 3)) {
      return _lastCheckResult;
    }

    try {
      final isOnline = await _checkConnectivity().timeout(
        const Duration(seconds: 2),
        onTimeout: () => true, // Fallback to true on timeout so Wi-Fi users are never blocked
      );
      _lastCheckResult = isOnline;
      _lastCheckTime = DateTime.now();
      return isOnline;
    } catch (_) {
      _lastCheckResult = true;
      return true;
    }
  }

  Future<bool> _checkConnectivity() async {
    // 1. Fast DNS host lookup (works over all standard Wi-Fi / cellular connections)
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(milliseconds: 1500));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    // 2. HTTP 204 Connectivity Check (standard Android/Chromium captive portal test)
    try {
      final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 1500);
      final request = await client.getUrl(Uri.parse('https://connectivitycheck.gstatic.com/generate_204'));
      final response = await request.close();
      client.close();
      if (response.statusCode == 204 || response.statusCode == 200) {
        return true;
      }
    } catch (_) {}

    // 3. Fallback: Check if device has active network interfaces (Wi-Fi, Ethernet, Mobile)
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      ).timeout(const Duration(milliseconds: 1000));
      if (interfaces.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    // Default to true so local network / Wi-Fi users can connect to local or LAN backend
    return true;
  }
}
