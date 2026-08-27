import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPermissionHelper {
  static const String _prefKeyInitialRequested = 'has_requested_initial_app_permissions';

  /// Request all required app permissions on initial install/launch
  /// directly via native Android system permission popups (no custom UI)
  static Future<void> requestAllAppPermissionsOnStartup() async {
    try {
      if (kIsWeb) return;

      final prefs = await SharedPreferences.getInstance();
      final alreadyRequested = prefs.getBool(_prefKeyInitialRequested) ?? false;
      if (alreadyRequested) {
        // Also ensure notification permission is checked on Android 13+
        if (Platform.isAndroid || Platform.isIOS) {
          final notifStatus = await Permission.notification.status;
          if (notifStatus.isDenied) {
            await Permission.notification.request();
          }
        }
        return;
      }

      await prefs.setBool(_prefKeyInitialRequested, true);

      // Directly invoke system-level permission popups
      final permissionsToRequest = <Permission>[
        Permission.notification,
        Permission.camera,
        Permission.location,
        if (Platform.isAndroid) ...[
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ],
      ];

      await permissionsToRequest.request();
    } catch (e) {
      debugPrint('[NotificationPermissionHelper] Error requesting initial permissions: $e');
    }
  }

  /// Check if notification permission is currently granted
  static Future<bool> isPermissionGranted() async {
    try {
      if (kIsWeb) return true;
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Directly trigger native system notification permission popup
  static Future<bool> requestPermissionDirectly() async {
    try {
      if (kIsWeb) return true;
      final status = await Permission.notification.request();
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
      return status.isGranted;
    } catch (e) {
      debugPrint('[NotificationPermissionHelper] Error requesting notification permission: $e');
      return false;
    }
  }
}
