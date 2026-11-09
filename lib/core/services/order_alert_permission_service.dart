import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderAlertPermissionService {
  static const MethodChannel _nativeChannel = MethodChannel('com.apnapos.app/order_alert');
  static int _lastCheckTime = 0;
  static Map<String, bool>? _cachedPermissions;
  static bool _isPromptShowing = false;
  static const String _prefKeyLastOverlayPromptTime = 'last_overlay_permission_prompt_time';

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

  /// Show a clean, non-intrusive dialog asking the user to grant "Display over other apps"
  static Future<bool> showOverlayPermissionPromptIfNeeded(
    BuildContext context, {
    bool force = false,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    if (_isPromptShowing) return false;

    try {
      final perms = await checkPermissions(forceRefresh: true);
      if (perms['overlayGranted'] == true) {
        return true;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastPrompt = prefs.getInt(_prefKeyLastOverlayPromptTime) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Without force, prompt at most once per 30 minutes so user is gently guided
      if (!force && (now - lastPrompt < 30 * 60 * 1000)) {
        return false;
      }

      await prefs.setInt(_prefKeyLastOverlayPromptTime, now);
      _isPromptShowing = true;

      if (!context.mounted) {
        _isPromptShowing = false;
        return false;
      }

      final bool? granted = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogCtx) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: const [
                BoxShadow(color: Color(0x24000000), blurRadius: 28, offset: Offset(0, 10)),
              ],
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(color: Color(0x332563EB), blurRadius: 10, offset: Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(
                        Icons.layers_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Order Alert Permission',
                            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Display over other apps',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogCtx, false),
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Allows new incoming WhatsApp and online customer orders to automatically pop up on your screen even when you are using other apps or when your phone is locked.\n\n💡 Note: If settings shows a list of apps, tap "Apna POS" and turn the switch ON.',
                          style: TextStyle(fontSize: 12.5, height: 1.45, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(dialogCtx, true);
                      await openAppInfoSettings();
                    },
                    icon: const Icon(Icons.settings_outlined, size: 16, color: Color(0xFF64748B)),
                    label: const Text(
                      'Open Apna POS App Info instead',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Later',
                          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(dialogCtx, true);
                          await requestOverlayPermission();
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                        label: const Text(
                          'Allow Permission',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      _isPromptShowing = false;
      return granted ?? false;
    } catch (e) {
      _isPromptShowing = false;
      debugPrint('[OrderAlertPermissionService] Error prompting overlay permission: $e');
      return false;
    }
  }
}
