import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../security/secure_storage_service.dart';
import '../database/database_service.dart';
import '../models/incoming_order_payload.dart';
import '../models/incoming_order_alert.dart';
import 'local_notification_service.dart';
import 'sound_service.dart';
import '../../features/notifications/models/notification_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Top-level background message handler invoked by OS when app is terminated or in background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint(
    '[FCM Background] Message received in background/terminated state: ${message.messageId} (Data: ${message.data})',
  );
  try {
    final data = IncomingOrderPayload.normalize(message.data);
    final typeStr = data['type']?.toString();
    final alert = IncomingOrderAlert(data);
    final orderId = alert.orderId, orderNum = alert.orderNumber;
    final isChatMessage = alert.isChat;
    final isOrder = alert.isIncoming;
    if (alert.isOrder && !isOrder) return;
    if (alert.isLocal) return;
    if (isOrder && data['apna_native_order_handled'] == 'true') {
      // Native dispatcher already persisted and posted this order. The UI isolate
      // consumes its launch payload; a second notification would ring twice.
      return;
    }

    final hasNotificationPayload = message.notification != null;
    final isDailySummary =
        typeStr == 'daily_sales_summary' ||
        data['entityType'] == 'sales_report' ||
        data['type'] == 'daily_sales_summary';

    final resolvedEntityId =
        (data['entityId'] ?? data['chatId'] ?? data['orderId'] ?? '')
            .toString()
            .trim();
    final effectiveTag =
        data['notificationTag']?.toString() ??
        (isDailySummary
            ? 'daily_sales_summary'
            : (isChatMessage && resolvedEntityId.isNotEmpty
                  ? 'chat_$resolvedEntityId'
                  : (isOrder && (orderId.isNotEmpty || orderNum.isNotEmpty)
                        ? 'order_${orderId.isNotEmpty ? orderId : orderNum}'
                        : null)));

    final int notifId = isDailySummary
        ? 9991
        : (isOrder && orderId.isNotEmpty
              ? orderId.hashCode.abs().remainder(100000)
              : (isChatMessage && resolvedEntityId.isNotEmpty
                    ? resolvedEntityId.hashCode.abs().remainder(100000)
                    : 0));

    // 1. Cross-isolate deduplication check (synchronizes across FCM background and UI isolates)
    final isDuplicate = await LocalNotificationService.shouldSuppressDuplicate(
      id: notifId != 0 ? notifId : null,
      tag: effectiveTag,
      orderId: orderId.isNotEmpty ? orderId : null,
      orderNumber: orderNum.isNotEmpty ? orderNum : null,
      entityId: resolvedEntityId.isNotEmpty ? resolvedEntityId : null,
      type: typeStr,
      title: message.notification?.title ?? data['title']?.toString(),
      body: message.notification?.body ?? data['message']?.toString(),
      debounceSeconds: isDailySummary ? 120 : 25,
    );

    if (isDuplicate) {
      debugPrint(
        '[FCM Background] 🚫 Suppressed duplicate FCM notification: $typeStr / $orderNum / $orderId',
      );
      return;
    }

    // 2. Cache pending order for instant full-screen popup
    if (isOrder) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'pending_incoming_order_payload',
          jsonEncode(data),
        );
        debugPrint(
          '[FCM Background] ✅ Cached pending order in SharedPreferences for immediate popup upon app wake: ${data['orderNumber'] ?? data['orderId']}',
        );
      } catch (err) {
        debugPrint(
          '[FCM Background] Error caching pending order in prefs: $err',
        );
      }
      try {
        SoundService.boostHardwareVolume();
        SoundService.bringAppToFront(payload: jsonEncode(data), isUrgent: true);
      } catch (_) {}
    }

    // 3. Android OS already automatically posts notifications with a top-level notification block
    // to the status bar when the app is in background/terminated.
    // For non-order items (e.g. daily sales summary or standard alerts), calling showNotificationFromRemoteMessage
    // would produce an exact DUPLICATE card in the notification shade!
    // We only call showNotificationFromRemoteMessage if:
    // - There is NO top-level notification block (data-only push), OR
    // - It is an incoming order requiring custom fullScreenIntent, Accept/Reject actions, and ringtone.
    if (hasNotificationPayload && !isOrder) {
      debugPrint(
        '[FCM Background] System tray notification already rendered by Android OS. Skipping local duplicate.',
      );
      return;
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
      debugPrint(
        '[FcmService] Push notifications skipped (unsupported platform: $defaultTargetPlatform)',
      );
      return;
    }

    try {
      // Register background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Startup may inspect authorization, but permission prompts wait for login.
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();

      debugPrint(
        '[FcmService] Notification permission status: ${settings.authorizationStatus}',
      );

      // Configure foreground options
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound:
                false, // Local playback applies the user's selected sound once.
          );

      // Obtain current device push token and register with retries
      registerTokenWithBackend();

      // Secondary delayed registration to ensure ApiEndpoints resolution has completed
      Future.delayed(const Duration(seconds: 4), () {
        registerTokenWithBackend();
      });

      // Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint(
          '[FcmService] FCM token refreshed: ${newToken.substring(0, newToken.length > 12 ? 12 : newToken.length)}...',
        );
        registerTokenWithBackend(newToken);
      });

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          '[FcmService] Foreground message received: ${message.notification?.title}',
        );
        _handleForegroundMessage(message);
      });

      // Tap from background listener
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint(
          '[FcmService] Notification opened from background tray: ${message.notification?.title}',
        );
        _handleNotificationTap(message);
      });

      // Check initial message if app launched directly from terminated state
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
          '[FcmService] App launched from terminated state via notification: ${initialMessage.notification?.title}',
        );
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

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = IncomingOrderPayload.normalize(message.data);

    final title =
        notification?.title ?? data['title'] ?? 'Apna POS Notification';
    final body = notification?.body ?? data['message'] ?? '';
    final typeStr = data['type']?.toString() ?? 'system';

    final alert = IncomingOrderAlert(data);
    final orderId = alert.orderId, orderNum = alert.orderNumber;
    final isChatMessage = alert.isChat;
    final isOrder = alert.isIncoming;
    final isWhatsAppOrder = isOrder;
    if (alert.isHandled) {
      LocalNotificationService.handleOrderUpdate(data);
      return;
    }
    if (alert.isOrder && !isOrder) return;
    if (alert.isLocal) return;
    if (isOrder) {
      // Notification/ringtone deduplication must not drop the screen handoff.
      LocalNotificationService.handlePayloadDirectly(data);
      if (data['apna_native_order_handled'] == 'true') return;
    }

    final isDailySummary =
        typeStr == 'daily_sales_summary' ||
        data['entityType'] == 'sales_report' ||
        data['type'] == 'daily_sales_summary';

    final resolvedEntityId =
        (data['entityId'] ?? data['chatId'] ?? data['orderId'] ?? '')
            .toString()
            .trim();
    final effectiveTag =
        data['notificationTag']?.toString() ??
        (isDailySummary
            ? 'daily_sales_summary'
            : (isChatMessage && resolvedEntityId.isNotEmpty
                  ? 'chat_$resolvedEntityId'
                  : (isWhatsAppOrder &&
                            (orderId.isNotEmpty || orderNum.isNotEmpty)
                        ? 'order_${orderId.isNotEmpty ? orderId : orderNum}'
                        : (resolvedEntityId.isNotEmpty
                              ? 'notif_$resolvedEntityId'
                              : null))));

    final int notifId;
    if (isDailySummary) {
      notifId = 9991;
    } else if (isWhatsAppOrder && (orderId.isNotEmpty || orderNum.isNotEmpty)) {
      notifId = orderId.isNotEmpty
          ? orderId.hashCode.abs().remainder(100000)
          : orderNum.hashCode.abs().remainder(100000);
    } else if (isChatMessage && resolvedEntityId.isNotEmpty) {
      notifId = resolvedEntityId.hashCode.abs().remainder(100000);
    } else if (effectiveTag != null && effectiveTag.isNotEmpty) {
      notifId = effectiveTag.hashCode.abs().remainder(100000);
    } else {
      notifId = 0;
    }

    final isDuplicate = await LocalNotificationService.shouldSuppressDuplicate(
      id: notifId != 0 ? notifId : null,
      tag: effectiveTag,
      orderId: orderId.isNotEmpty ? orderId : null,
      orderNumber: orderNum.isNotEmpty ? orderNum : null,
      entityId: resolvedEntityId.isNotEmpty ? resolvedEntityId : null,
      type: typeStr,
      title: title,
      body: body,
      debounceSeconds: isDailySummary ? 120 : 25,
    );

    if (isDuplicate) {
      debugPrint(
        '[FcmService Foreground] 🚫 Suppressed duplicate FCM notification: $typeStr / $title',
      );
      return;
    }

    LocalNotificationService().showPushNotification(
      id: notifId,
      title: title,
      body: body,
      tag: effectiveTag,
      payload: jsonEncode(data),
      type: isWhatsAppOrder
          ? NotificationType.whatsappOrderRequest
          : (isDailySummary
                ? NotificationType.dailySalesSummary
                : LocalNotificationService().resolveNotificationType(typeStr)),
      entityType:
          data['entityType']?.toString() ??
          (isChatMessage ? 'whatsapp_chat' : null),
      entityId: resolvedEntityId.isNotEmpty ? resolvedEntityId : null,
      metadata: data,
      playSound: true,
      skipDedupe: true, // Already deduplicated above.
      channelId: isDailySummary
          ? 'apna_pos_sales_v2'
          : (isWhatsAppOrder
                ? 'apna_pos_whatsapp_orders_v2'
                : (isChatMessage
                      ? 'apna_pos_whatsapp_messages_v1'
                      : 'apna_pos_general_v2')),
      channelName: isDailySummary
          ? 'Sales & Business Reports'
          : (isWhatsAppOrder
                ? 'WhatsApp Orders & Alerts'
                : (isChatMessage
                      ? 'WhatsApp Messages'
                      : 'General Alerts & Orders')),
      channelDescription: isDailySummary
          ? 'Extended high-priority daily sales summaries and business metrics'
          : 'Real-time notifications for orders, leads, and daily summaries',
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = IncomingOrderPayload.normalize(message.data);
    if (data.isNotEmpty) {
      LocalNotificationService.handlePayloadDirectly(data);
    }
  }

  /// Called when the user explicitly enables push alerts.
  Future<bool> enableNotifications() async {
    if (!isSupported || DatabaseService().currentUser == null) return false;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
    if (granted) unawaited(registerTokenWithBackend());
    return granted;
  }

  /// Register FCM push token with backend with automatic retries and endpoint check
  Future<bool> registerTokenWithBackend([String? explicitToken]) async {
    if (!isSupported) return false;

    try {
      final storage = SecureStorageService();
      final accessToken = await storage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) return false;
      String? token = explicitToken;

      // 1. Fetch token from Firebase if not passed
      if (token == null || token.isEmpty) {
        // getToken can itself prompt in browsers; only fetch after authorization.
        final settings = await FirebaseMessaging.instance
            .getNotificationSettings();
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          return false;
        }
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

      // 2. Retry loop (up to 3 attempts with exponential backoff)
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
              if (businessId != null && businessId.isNotEmpty)
                'businessId': businessId,
            },
          );

          if (response != null) {
            debugPrint(
              '[FcmService] ✅ Registered device FCM push token with backend (attempt $attempt): $token',
            );
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
      debugPrint(
        '[FcmService] Non-blocking push token registration notice: $e',
      );
    }
    return false;
  }
}
