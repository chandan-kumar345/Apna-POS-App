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
    final isOrder = typeStr == 'whatsapp_order_request' ||
        typeStr == 'whatsapp_new_order' ||
        typeStr == 'whatsapp_order' ||
        typeStr == 'new_order' ||
        typeStr == 'newOrder' ||
        typeStr == 'order_created' ||
        typeStr == 'order' ||
        data['entityType'] == 'whatsapp_order' ||
        data['entityType'] == 'order' ||
        data['orderId'] != null;

    if (isOrder) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_incoming_order_payload', jsonEncode(data));
        debugPrint('[FCM Background] ✅ Cached pending order in SharedPreferences for immediate popup upon app wake: ${data['orderNumber'] ?? data['orderId']}');
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

      // Obtain current device push token and register with retries
      registerTokenWithBackend();

      // Secondary delayed registration to ensure ApiEndpoints resolution has completed
      Future.delayed(const Duration(seconds: 4), () {
        registerTokenWithBackend();
      });

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
        typeStr == 'order_created' ||
        typeStr == 'order' ||
        data['entityType'] == 'order' ||
        data['orderId'] != null;

    final isDailySummary = typeStr == 'daily_sales_summary' ||
        data['entityType'] == 'sales_report' ||
        data['type'] == 'daily_sales_summary';

    final notifId = isDailySummary
        ? 9991
        : (isWhatsAppOrder && data['orderId'] != null
            ? data['orderId'].toString().hashCode.abs().remainder(100000)
            : 0);

    LocalNotificationService().showPushNotification(
      id: notifId,
      title: title,
      body: body,
      payload: jsonEncode(data),
      type: isWhatsAppOrder
          ? NotificationType.whatsappOrderRequest
          : (isDailySummary
              ? NotificationType.dailySalesSummary
              : LocalNotificationService().resolveNotificationType(typeStr)),
      entityType: data['entityType']?.toString(),
      entityId: data['entityId']?.toString(),
      metadata: data,
      playSound: true,
      channelId: isDailySummary
          ? 'apna_pos_sales_v2'
          : (isWhatsAppOrder ? 'apna_pos_whatsapp_orders_v2' : 'apna_pos_general_v2'),
      channelName: isDailySummary
          ? 'Sales & Business Reports'
          : (isWhatsAppOrder ? 'WhatsApp Orders & Alerts' : 'General Alerts & Orders'),
      channelDescription: isDailySummary
          ? 'Extended high-priority daily sales summaries and business metrics'
          : 'Real-time notifications for orders, leads, and daily summaries',
    );

    // If order alert received, directly trigger the action screen
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

  /// Register FCM push token with backend with automatic retries and endpoint check
  Future<bool> registerTokenWithBackend([String? explicitToken]) async {
    if (!isSupported) return false;

    try {
      final storage = SecureStorageService();
      String? token = explicitToken;

      // 1. Fetch token from Firebase if not passed
      if (token == null || token.isEmpty) {
        try {
          token = await FirebaseMessaging.instance.getToken();
        } catch (e) {
          debugPrint('[FcmService] Initial getToken failed: $e');
        }
      }

      // Fallback to locally cached token
      token ??= await storage.getPushToken();

      if (token == null || token.isEmpty) {
        debugPrint('[FcmService] No device push token available to register');
        return false;
      }

      // Cache token locally so it persists across restarts
      await storage.savePushToken(token);

      // 2. Check if user is authenticated
      final accessToken = await storage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('[FcmService] User not logged in yet; push token cached locally');
        return false;
      }

      // 3. Retry loop (up to 3 attempts with exponential backoff)
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          // If baseUrl is not yet resolved, wait for it
          if (ApiEndpoints.baseUrl.isEmpty) {
            await ApiEndpoints.initialize();
          }

          final businessId = await storage.getBusinessId();
          final apiClient = ApiClient();
          final response = await apiClient.post(
            ApiEndpoints.registerDeviceToken,
            data: {
              'token': token,
              'platform': defaultTargetPlatform.name.toLowerCase(),
              if (businessId != null && businessId.isNotEmpty) 'businessId': businessId,
            },
          );

          if (response != null) {
            debugPrint('[FcmService] ✅ Registered device FCM push token with backend (attempt $attempt): $token');
            return true;
          }
        } catch (e) {
          debugPrint('[FcmService] Register token attempt $attempt error: $e');
          if (attempt < 3) {
            await Future.delayed(Duration(seconds: attempt * 2));
          }
        }
      }
    } catch (e) {
      debugPrint('[FcmService] Non-blocking push token registration notice: $e');
    }
    return false;
  }
}
