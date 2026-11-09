import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/order_alert_permission_service.dart';

class NotificationPermissionHelper {
  static const String _prefKeyInitialRequested = 'has_requested_initial_app_permissions';

  /// Request all required app permissions on initial install/launch
  /// directly via native Android system permission popups (no custom UI)
  static Future<void> requestAllAppPermissionsOnStartup() async {
    try {
      if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) return;

      final prefs = await SharedPreferences.getInstance();
      final alreadyRequested = prefs.getBool(_prefKeyInitialRequested) ?? false;
      if (alreadyRequested) {
        // Also ensure notification permission is checked on Android 13+
        if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
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
        if (defaultTargetPlatform == TargetPlatform.android) ...[
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ],
      ];

      await permissionsToRequest.request();

      // On Android, also check and request background battery optimization exemption
      if (defaultTargetPlatform == TargetPlatform.android) {
        final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
        if (!batteryStatus.isGranted) {
          await Permission.ignoreBatteryOptimizations.request();
        }
      }
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

  /// Check if 'Display over other apps' (SYSTEM_ALERT_WINDOW) is granted
  static Future<bool> isSystemAlertWindowGranted() async {
    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
      final perms = await OrderAlertPermissionService.checkPermissions();
      return perms['overlayGranted'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Request 'Display over other apps' permission
  static Future<bool> requestSystemAlertWindow() async {
    return OrderAlertPermissionService.requestOverlayPermission();
  }

  /// Check if battery optimizations are ignored (to prevent OEM background freezing)
  static Future<bool> isBatteryOptimizationsIgnored() async {
    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Request ignore battery optimizations
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
      final status = await Permission.ignoreBatteryOptimizations.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('[NotificationPermissionHelper] Error requesting ignoreBatteryOptimizations: $e');
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
