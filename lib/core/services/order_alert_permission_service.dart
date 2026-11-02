import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class OrderAlertPermissionService {
  static const MethodChannel _nativeChannel = MethodChannel('com.apnapos.app/order_alert');
  static int _lastCheckTime = 0;
  static Map<String, bool>? _cachedPermissions;

  /// Check whether all essential permissions for incoming WhatsApp background order popups are active
  static Future<Map<String, bool>> checkPermissions({bool forceRefresh = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return {
        'overlayGranted': true,
        'batteryOptimizationIgnored': true,
        'notificationsEnabled': true,
      };
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (!forceRefresh && _cachedPermissions != null && (now - _lastCheckTime < 2500)) {
      return _cachedPermissions!;
    }

    try {
      final res = await _nativeChannel.invokeMapMethod<String, dynamic>('checkOrderPermissions');
      final result = {
        'overlayGranted': res?['overlayGranted'] == true,
        'batteryOptimizationIgnored': res?['batteryOptimizationIgnored'] == true,
        'notificationsEnabled': res?['notificationsEnabled'] == true,
      };
      _cachedPermissions = result;
      _lastCheckTime = now;
      return result;
    } catch (e) {
      debugPrint('[OrderAlertPermissionService] Error checking permissions: $e');
      return {
        'overlayGranted': false,
        'batteryOptimizationIgnored': false,
        'notificationsEnabled': false,
      };
    }
  }

  /// Request "Display over other apps" (SYSTEM_ALERT_WINDOW)
  /// Opens Android settings toggle directly for Apna POS.
  static Future<bool> requestOverlayPermission() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final bool? success = await _nativeChannel.invokeMethod<bool>('requestOverlayPermission');
      return success ?? false;
    } catch (e) {
      debugPrint('[OrderAlertPermissionService] Error requesting overlay permission: $e');
      return false;
    }
  }

  /// Request Battery Optimization Whitelist (prevents OS from killing socket/FCM background service)
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final bool? success = await _nativeChannel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return success ?? false;
    } catch (e) {
      debugPrint('[OrderAlertPermissionService] Error requesting battery optimization ignore: $e');
      return false;
    }
  }

  /// Open Android Application Details Settings (App Info) directly
  static Future<bool> openAppInfoSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final bool? success = await _nativeChannel.invokeMethod<bool>('openAppInfoSettings');
      return success ?? false;
    } catch (e) {
      debugPrint('[OrderAlertPermissionService] Error opening App Info: $e');
      return false;
    }
  }

  /// Helper to check if both overlay and battery optimization are fully ready
  static Future<bool> areCriticalPermissionsGranted() async {
    final status = await checkPermissions();
    return (status['overlayGranted'] == true) &&
        (status['batteryOptimizationIgnored'] == true) &&
        (status['notificationsEnabled'] == true);
  }
}
