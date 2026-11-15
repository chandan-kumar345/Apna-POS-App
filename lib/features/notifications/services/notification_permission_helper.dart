import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
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
  static Future<void> requestStartupPermissionsAfterLogin() {
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
        await FcmService().enableNotifications();
        await prefs.setBool(_prefKeyPostLoginRequested, true);
        return;
      }

      // Keep this list explicit: media files use the system picker.
      final permissions = <Permission>[
        Permission.notification,
        Permission.camera,
        Permission.microphone,
        Permission.location,
        if (defaultTargetPlatform == TargetPlatform.android) ...[
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

  static bool get _usesFirebaseAuthorization =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.iOS;

  /// Reading authorization is safe during navigation and after returning from settings.
  static Future<bool> isPermissionGranted() async {
    if (!FcmService.isSupported) return true;
    try {
      if (_usesFirebaseAuthorization) {
        final settings = await FirebaseMessaging.instance.getNotificationSettings();
        return settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
      }
      return (await Permission.notification.status).isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Call only from an explicit Enable alerts action.
  static Future<bool> requestPermissionDirectly() async {
    if (!FcmService.isSupported) return true;
    try {
      if (_usesFirebaseAuthorization) {
        return await FcmService().enableNotifications();
      }
      final current = await Permission.notification.status;
      if (current.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      final granted = current.isGranted ||
          (current.isDenied && (await Permission.notification.request()).isGranted);
      if (granted) unawaited(FcmService().registerTokenWithBackend());
      return granted;
    } catch (error) {
      debugPrint('[NotificationPermissionHelper] Error enabling alerts: $error');
      return false;
    }
  }
}
