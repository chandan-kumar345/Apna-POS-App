import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/order_alert_permission_service.dart';

class NotificationPermissionHelper {
  static const String _prefKeyPostLoginRequested =
      'has_requested_post_login_permissions';
  static const String _prefKeyFullScreenRequested =
      'has_requested_order_full_screen_permission_v1';
  static Future<void>? _requestInProgress;

  /// Ask once after login, using only system permission screens.
  static Future<void> requestAllAppPermissionsAfterLogin() {
    if (DatabaseService().currentUser == null ||
        (!kIsWeb &&
            defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return Future<void>.value();
    }

    return _requestInProgress ??= _requestPostLoginPermissions().whenComplete(
      () {
        _requestInProgress = null;
      },
    );
  }

  static Future<void> _requestPostLoginPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (DatabaseService().currentUser == null) return;
      if (prefs.getBool(_prefKeyPostLoginRequested) == true) {
        // Existing installs already completed the old permission sequence.
        // The new special access has its own once-only migration flag.
        await _requestFullScreenPermissionIfNeeded(prefs);
        return;
      }

      if (kIsWeb) {
        await FcmService().requestNotificationPermissionAfterLogin();
        await prefs.setBool(_prefKeyPostLoginRequested, true);
        return;
      }

      final permissions = <Permission>[
        Permission.notification,
        Permission.camera,
        Permission.microphone,
        Permission.location,
        Permission.photos,
        if (defaultTargetPlatform == TargetPlatform.android) ...[
          Permission.storage,
          Permission.videos,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ] else ...[
          Permission.speech,
          Permission.bluetooth,
        ],
      ];

      final pending = <Permission>[];
      for (final permission in permissions) {
        if ((await permission.status).isDenied) pending.add(permission);
      }
      if (DatabaseService().currentUser == null) return;
      if (pending.isNotEmpty) await pending.request();
      if (DatabaseService().currentUser == null) return;

      if (defaultTargetPlatform == TargetPlatform.android) {
        final batteryStatus =
            await Permission.ignoreBatteryOptimizations.status;
        if (batteryStatus.isDenied) {
          await Permission.ignoreBatteryOptimizations.request();
        }
        if (DatabaseService().currentUser == null) return;

        await _requestFullScreenPermissionIfNeeded(prefs);
        if (DatabaseService().currentUser == null) return;

        // Open Android's permission section directly, after other prompts finish.
        final orderPermissions =
            await OrderAlertPermissionService.checkPermissions(
              forceRefresh: true,
            );
        if (DatabaseService().currentUser == null) return;
        if (orderPermissions['overlayGranted'] != true) {
          await OrderAlertPermissionService.requestOverlayPermission();
        }
      }

      // Record denials too; normal navigation must not repeat the setup sequence.
      await prefs.setBool(_prefKeyPostLoginRequested, true);
      unawaited(FcmService().registerTokenWithBackend());
    } catch (e) {
      debugPrint(
        '[NotificationPermissionHelper] Error requesting post-login permissions: $e',
      );
    }
  }

  static Future<void> _requestFullScreenPermissionIfNeeded(
    SharedPreferences prefs,
  ) async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        DatabaseService().currentUser == null ||
        prefs.getBool(_prefKeyFullScreenRequested) == true) {
      return;
    }
    final permissions = await OrderAlertPermissionService.checkPermissions(
      forceRefresh: true,
    );
    if (DatabaseService().currentUser == null ||
        permissions['fullScreenIntentRequired'] != true) {
      return;
    }
    if (permissions['fullScreenIntentGranted'] != true) {
      await OrderAlertPermissionService.requestFullScreenIntentPermission();
    }
    // Keep a denial as a completed request. The settings page supports retry;
    // normal navigation must not keep opening system settings.
    await prefs.setBool(_prefKeyFullScreenRequested, true);
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
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        return true;
      }
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
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        return true;
      }
      final status = await Permission.ignoreBatteryOptimizations.status;
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Request ignore battery optimizations
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        return true;
      }
      final status = await Permission.ignoreBatteryOptimizations.request();
      return status.isGranted;
    } catch (e) {
      debugPrint(
        '[NotificationPermissionHelper] Error requesting ignoreBatteryOptimizations: $e',
      );
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
      debugPrint(
        '[NotificationPermissionHelper] Error requesting notification permission: $e',
      );
      return false;
    }
  }
}
