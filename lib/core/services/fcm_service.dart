import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../security/secure_storage_service.dart';
import 'local_notification_service.dart';
import '../../features/notifications/models/notification_model.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Top-level background message handler invoked by OS when app is terminated or in background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('[FCM Background] Message received in background/terminated state: ${message.messageId} (Data: ${message.data})');
  try {
    final data = message.data;
    final typeStr = data['type']?.toString();
    if (typeStr == 'whatsapp_order_request' ||
        typeStr == 'whatsapp_new_order' ||
        typeStr == 'whatsapp_order') {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_incoming_order_payload', jsonEncode(data));
      } catch (err) {
        debugPrint('[FCM Background] Error caching pending order in prefs: $err');
      }
    }
    await LocalNotificationService.showNotificationFromRemoteMessage(message);
  } catch (e) {
    debugPrint('[FCM Background] Error displaying native notification: $e');
  }
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  bool _isInitialized = false;

  static bool get isSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Initialize Firebase Cloud Messaging listeners and background handlers
  Future<void> init() async {
    if (_isInitialized) return;
    if (!isSupported) {
      debugPrint('[FcmService] Push notifications skipped (unsupported platform: $defaultTargetPlatform)');
      return;
    }

    try {
      // Register background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request permissions
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('[FcmService] Notification permission status: ${settings.authorizationStatus}');

      // Configure foreground options
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Obtain current device push token
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('[FcmService] FCM device token: ${token.substring(0, token.length > 12 ? 12 : token.length)}...');
        await registerTokenWithBackend(token);
      }

      // Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('[FcmService] FCM token refreshed: ${newToken.substring(0, newToken.length > 12 ? 12 : newToken.length)}...');
        registerTokenWithBackend(newToken);
      });

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FcmService] Foreground message received: ${message.notification?.title}');
        _handleForegroundMessage(message);
      });

      // Tap from background listener
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FcmService] Notification opened from background tray: ${message.notification?.title}');
        _handleNotificationTap(message);
      });

      // Check initial message if app launched directly from terminated state
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FcmService] App launched from terminated state via notification: ${initialMessage.notification?.title}');
        _handleNotificationTap(initialMessage);
      }

      // Proactively check if a pending incoming order was queued while app was sleeping/locked
      LocalNotificationService.checkAndShowPendingIncomingOrder();

      _isInitialized = true;
      debugPrint('[FcmService] Initialized successfully');
    } catch (e) {
      debugPrint('[FcmService] Initialization error: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] ?? 'Apna POS Notification';
    final body = notification?.body ?? data['message'] ?? '';
    final typeStr = data['type']?.toString() ?? 'system';

    final isWhatsAppOrder = typeStr == 'whatsapp_order_request' ||
        typeStr == 'whatsapp_order' ||
        typeStr == 'whatsapp_new_order' ||
        data['entityType'] == 'whatsapp_order';

    final isOrder = isWhatsAppOrder ||
        typeStr == 'new_order' ||
        typeStr == 'newOrder' ||
        typeStr == 'order_created';

    LocalNotificationService().showPushNotification(
      title: title,
      body: body,
      payload: jsonEncode(data),
      type: isWhatsAppOrder
          ? NotificationType.whatsappOrderRequest
          : LocalNotificationService().resolveNotificationType(typeStr),
      entityType: data['entityType']?.toString(),
      entityId: data['entityId']?.toString(),
      metadata: data,
      playSound: true,
    );

    // If order alert received, directly trigger the action dialog
    if (isOrder) {
      LocalNotificationService.handlePayloadDirectly(data);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    if (data.isNotEmpty) {
      LocalNotificationService.handlePayloadDirectly(data);
    }
  }

  /// Register FCM push token with backend
  Future<void> registerTokenWithBackend([String? explicitToken]) async {
    if (!isSupported) return;

    try {
      final storage = SecureStorageService();
      final token = explicitToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      final accessToken = await storage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        // User not logged in yet; cache token to submit right after login
        await storage.savePushToken(token);
        return;
      }

      final apiClient = ApiClient();
      await apiClient.post(
        ApiEndpoints.registerDeviceToken,
        data: {
          'token': token,
          'platform': defaultTargetPlatform.name.toLowerCase(),
        },
      );
      debugPrint('[FcmService] ✅ Registered device FCM push token with backend');
    } catch (e) {
      debugPrint('[FcmService] Non-blocking push token registration notice: $e');
    }
  }
}
