import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../features/notifications/services/notification_service.dart';
import '../../features/notifications/models/notification_model.dart';
import '../../features/chat/meta_whatsapp_chat_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/orders/incoming_order_accept_screen.dart';
import 'sales_notification_banner_generator.dart';
import 'sound_service.dart';
import 'fcm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_service.dart';

/// Top-level background notification tap entrypoint invoked by OS when app is in background/terminated
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('[LocalNotificationService] 🔔 Background notification action tapped: ${notificationResponse.actionId}, payload: ${notificationResponse.payload}');
  try {
    SharedPreferences.getInstance().then((prefs) {
      final payload = notificationResponse.payload;
      if (payload != null && payload.isNotEmpty) {
        prefs.setString('pending_incoming_order_payload', payload);
      }
      if (notificationResponse.actionId == 'accept_order') {
        prefs.setString('pending_notification_action', 'accept');
      } else if (notificationResponse.actionId == 'reject_order') {
        prefs.setString('pending_notification_action', 'reject');
      } else {
        prefs.setString('pending_notification_action', 'view');
      }
    });
  } catch (e) {
    debugPrint('[LocalNotificationService] Error storing background notification response: $e');
  }
}

class LocalNotificationService with WidgetsBindingObserver {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  /// Global Navigator key for deep-linking into WhatsApp chats or screens on notification tap
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static final Map<String, int> _staticDedupeMemoryCache = {};
  bool _isInitialized = false;

  /// Checks and suppresses duplicate notifications across FCM, Socket.IO, Polling, and background isolates.
  /// Combines in-memory cache and SharedPreferences for true cross-isolate synchronization.
  static Future<bool> shouldSuppressDuplicate({
    int? id,
    String? tag,
    String? orderId,
    String? orderNumber,
    String? entityId,
    String? type,
    String? title,
    String? body,
    int debounceSeconds = 25,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final int effectiveDebounceMs = debounceSeconds * 1000;

    final Set<String> keys = {};

    final cleanType = (type ?? '').toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
    final cleanTag = (tag ?? '').toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
    final isDailySummary = cleanType.contains('dailysalessummary') ||
        cleanType.contains('salesreport') ||
        cleanTag.contains('dailysalessummary');

    if (isDailySummary) {
      keys.add('daily_sales_summary');
      final now = DateTime.now();
      keys.add('daily_sales_summary_${now.year}_${now.month}_${now.day}');
    }

    if (id != null && id != 0) {
      keys.add('notif_id_$id');
    }

    if (orderId != null && orderId.trim().isNotEmpty) {
      final cleanId = orderId.trim().toLowerCase();
      keys.add('order_$cleanId');
      keys.add('entity_$cleanId');
    }

    if (orderNumber != null && orderNumber.trim().isNotEmpty) {
      final cleanNum = orderNumber.trim().toLowerCase().replaceAll('#', '');
      keys.add('ordernum_$cleanNum');
      keys.add('order_$cleanNum');
    }

    if (entityId != null && entityId.trim().isNotEmpty) {
      keys.add('entity_${entityId.trim().toLowerCase()}');
    }

    if (tag != null && tag.trim().isNotEmpty) {
      keys.add('tag_${tag.trim().toLowerCase()}');
    }

    // Normalized alphanumeric content fingerprint (ignores emojis, spaces, punctuation, case)
    if (title != null && title.trim().isNotEmpty) {
      final cleanTitle = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final cleanBody = (body ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (cleanTitle.isNotEmpty) {
        final titlePart = cleanTitle.length > 25 ? cleanTitle.substring(0, 25) : cleanTitle;
        final bodyPart = cleanBody.length > 35 ? cleanBody.substring(0, 35) : cleanBody;
        keys.add('content_${titlePart}_$bodyPart');
      }
    }

    // Body + Entity/Tag matching: prevents duplicate notification when body is identical for the same chat/order/tag
    if (body != null && body.trim().isNotEmpty) {
      final cleanBody = body.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (cleanBody.isNotEmpty) {
        final bodyPart = cleanBody.length > 30 ? cleanBody.substring(0, 30) : cleanBody;
        if (entityId != null && entityId.trim().isNotEmpty) {
          keys.add('body_${entityId.trim().toLowerCase()}_$bodyPart');
        }
        if (tag != null && tag.trim().isNotEmpty) {
          keys.add('body_${tag.trim().toLowerCase()}_$bodyPart');
        }
        if (orderId != null && orderId.trim().isNotEmpty) {
          keys.add('body_${orderId.trim().toLowerCase()}_$bodyPart');
        }
      }
    }

    if (keys.isEmpty) return false;

    // 1. Check in-memory static cache first (instant)
    for (final k in keys) {
      if (_staticDedupeMemoryCache.containsKey(k)) {
        final last = _staticDedupeMemoryCache[k]!;
        if (nowMs - last < effectiveDebounceMs) {
          debugPrint('[LocalNotificationService] 🚫 Suppressed duplicate (in-memory key: $k, elapsed: ${nowMs - last}ms < ${effectiveDebounceMs}ms)');
          return true;
        }
      }
    }

    // 2. Check SharedPreferences for cross-isolate deduplication (FCM background isolate vs UI isolate)
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in keys) {
        final prefKey = 'notif_dedupe_$k';
        final last = prefs.getInt(prefKey);
        if (last != null && (nowMs - last < effectiveDebounceMs)) {
          _staticDedupeMemoryCache[k] = last;
          debugPrint('[LocalNotificationService] 🚫 Suppressed duplicate (SharedPreferences key: $k, elapsed: ${nowMs - last}ms < ${effectiveDebounceMs}ms)');
          return true;
        }
      }

      // 3. Not a duplicate -> Record timestamp across memory and SharedPreferences for all generated keys
      for (final k in keys) {
        _staticDedupeMemoryCache[k] = nowMs;
        await prefs.setInt('notif_dedupe_$k', nowMs);
      }

      if (_staticDedupeMemoryCache.length > 80) {
        _staticDedupeMemoryCache.removeWhere((_, time) => nowMs - time > 180000);
      }
    } catch (e) {
      debugPrint('[LocalNotificationService] Error checking deduplication in SharedPreferences: $e');
    }

    return false;
  }

  /// In-memory queue for incoming order payloads received while SplashScreen is animating
  static Map<String, dynamic>? _pendingIncomingOrderPayload;
  static Timer? _retryShowOrderTimer;

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Handle notification payload when tapped from system notification tray or fullScreenIntent
  static void _handleNotificationPayload(
    String? payload, {
    bool autoAccept = false,
    bool autoReject = false,
  }) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        final type = decoded['type']?.toString();
        final entityType = decoded['entityType']?.toString();
        final metadata = decoded['metadata'] as Map<String, dynamic>? ?? {};

        // Incoming WhatsApp & Urgent Order Alert handling
        final isOrder = type == 'whatsapp_order_request' ||
            type == 'whatsapp_new_order' ||
            type == 'whatsapp_order' ||
            type == 'new_order' ||
            type == 'newOrder' ||
            type == 'order_created' ||
            type == 'order' ||
            entityType == 'whatsapp_order' ||
            entityType == 'order' ||
            decoded['orderId'] != null ||
            metadata['orderId'] != null;

        final orderId = (decoded['orderId'] ?? metadata['orderId'] ?? '').toString().trim();
        final orderNum = (decoded['orderNumber'] ?? metadata['orderNumber'] ?? '').toString().trim();
        final rawType = (decoded['orderType'] ?? metadata['orderType'] ?? '').toString().toLowerCase();
        final cleanType = rawType.replaceAll(RegExp(r'[-_\s]'), '');
        final rawSource = (decoded['orderSource'] ?? metadata['orderSource'] ?? '').toString().toLowerCase();
        final pm = (decoded['paymentMethod'] ?? metadata['paymentMethod'] ?? '').toString().toLowerCase();
        final isKot = pm.contains('kot') || decoded['isKot'] == true || metadata['isKot'] == true || (decoded['status'] ?? '').toString().toLowerCase() == 'preparing';

        final tblNum = (decoded['tableNumber'] ?? metadata['tableNumber'] ?? decoded['table'] ?? metadata['table'])?.toString().trim();
        final bool isTableOrder = (tblNum != null && tblNum.isNotEmpty) ||
            rawSource.contains('qr') ||
            rawSource.contains('table') ||
            cleanType.contains('table') ||
            (decoded['deliveryAddress'] ?? metadata['deliveryAddress'] ?? '').toString().toLowerCase().contains('table');

        final bool isExplicitExternal = rawSource == 'whatsapp' ||
            rawSource == 'profile' ||
            rawSource == 'storefront' ||
            rawSource == 'online' ||
            rawSource == 'qr' ||
            isTableOrder ||
            cleanType.contains('whatsapp') ||
            cleanType.contains('profile') ||
            cleanType.contains('table') ||
            type == 'whatsapp_order_request' ||
            type == 'whatsapp_order' ||
            type == 'table_order' ||
            type == 'qr_order';

        final bool isDineInOrLocalPos = !isExplicitExternal && (
            isKot ||
            rawSource == 'pos' ||
            rawSource == 'counter' ||
            rawSource == 'local' ||
            DatabaseService.isKnownPosOrder(orderId) ||
            DatabaseService.isKnownPosOrder(orderNum)
        );

        if (isOrder && !isDineInOrLocalPos) {
          if (IncomingOrderAcceptScreen.isShowing &&
              (IncomingOrderAcceptScreen.currentShowingOrderId == orderId ||
               IncomingOrderAcceptScreen.currentShowingOrderNumber == orderNum)) {
            debugPrint('[LocalNotificationService] Incoming order screen already showing for order  / . Suppressing duplicate open.');
            return;
          }

          SoundService.boostHardwareVolume();
          SoundService.bringAppToFront(payload: jsonEncode(decoded), isUrgent: true);
          if (SplashScreen.isSplashActive) {
            debugPrint('[LocalNotificationService] ⏳ SplashScreen active. Queueing order payload for display post-splash.');
            _pendingIncomingOrderPayload = decoded;
            return;
          }

          _pendingIncomingOrderPayload = decoded;
          _retryShowOrderTimer?.cancel();
          int attempts = 0;
          _retryShowOrderTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
            attempts++;
            if (SplashScreen.isSplashActive) {
              _pendingIncomingOrderPayload = decoded;
              timer.cancel();
              return;
            }
            final ctx = navigatorKey.currentContext;
            if (ctx != null && ctx.mounted) {
              timer.cancel();
              _pendingIncomingOrderPayload = null;
              IncomingOrderAcceptScreen.openFromPayload(
                ctx,
                decoded,
                autoAccept: autoAccept,
                autoReject: autoReject,
              );
            } else if (attempts >= 15) {
              // Phone might be locked or unmounted. Keep payload stored so unlock triggers it!
              timer.cancel();
              _pendingIncomingOrderPayload = decoded;
            }
          });
          return;
        }

        if (type == 'whatsappMessage' ||
            type == 'whatsapp_message' ||
            entityType == 'whatsapp_chat') {
          final phone = metadata['customerPhone']?.toString() ??
              metadata['phone']?.toString() ??
              decoded['entityId']?.toString();
          final name = metadata['customerName']?.toString();

          if (phone != null && phone.isNotEmpty) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => MetaWhatsAppChatScreen(
                  initialPhone: phone,
                  initialCustomerName: name,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalNotificationService] Error handling payload: $e');
    }
  }

  /// Directly handle payload map from FCM or Socket background handlers
  static void handlePayloadDirectly(Map<String, dynamic> data, {bool autoAccept = false}) {
    try {
      final jsonStr = jsonEncode(data);
      _pendingIncomingOrderPayload = data;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('pending_incoming_order_payload', jsonStr);
      }).catchError((_) {});

      SoundService.boostHardwareVolume();
      SoundService.bringAppToFront(payload: jsonStr, isUrgent: true);
      _handleNotificationPayload(jsonStr, autoAccept: autoAccept);
    } catch (e) {
      debugPrint('[LocalNotificationService] Error in handlePayloadDirectly: $e');
    }
  }

  /// Resolve notification type from string identifier
  NotificationType resolveNotificationType(String? type) {
    if (type == null) return NotificationType.system;
    final lower = type.toLowerCase();
    if (lower == 'whatsapp_order_request' ||
        lower == 'whatsapp_new_order' ||
        lower == 'whatsapp_order') {
      return NotificationType.whatsappOrderRequest;
    }
    if (lower == 'whatsapp_message' || lower == 'whatsappmessage') {
      return NotificationType.whatsappMessage;
    }
    if (lower == 'new_lead' || lower == 'lead' || lower == 'crm') {
      return NotificationType.newLead;
    }
    if (lower == 'daily_sales_summary' || lower == 'dailysalessummary') {
      return NotificationType.dailySalesSummary;
    }
    if (lower == 'inventory' || lower == 'low_stock' || lower == 'lowstock') {
      return NotificationType.lowStock;
    }
    if (lower == 'welcome') {
      return NotificationType.welcome;
    }
    return NotificationType.system;
  }

  /// Initialize local notification channels for Android and iOS
  Future<void> init() async {
    if (_isInitialized || !_isSupportedPlatform) return;

    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('[LocalNotificationService] Notification tapped in foreground/background: ${response.payload} (action: ${response.actionId})');
          _handleNotificationResponse(response);
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      // Explicitly register Android Notification Channels so background/terminated push notifications are never dropped
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          // WhatsApp Orders & Urgent Alerts Channel - Highest Importance, Sound, Vibration, Full Screen Intent
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'apna_pos_whatsapp_orders_v2',
              'WhatsApp Orders & Alerts',
              description: 'Urgent incoming WhatsApp customer orders with instant alert and popup',
              importance: Importance.max,
              playSound: true,
              sound: RawResourceAndroidNotificationSound('notification_sound'),
              enableVibration: true,
              enableLights: true,
            ),
          );

          // WhatsApp Messages Channel - High Importance, Sound, Vibration, Lights
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'apna_pos_whatsapp_messages_v1',
              'WhatsApp Messages',
              description: 'Real-time notifications for incoming WhatsApp customer messages',
              importance: Importance.max,
              playSound: true,
              sound: RawResourceAndroidNotificationSound('notification_sound'),
              enableVibration: true,
              enableLights: true,
            ),
          );

          // General Alerts & Orders Channel
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'apna_pos_general_v2',
              'General Alerts & Orders',
              description: 'Real-time notifications for orders, leads, and daily summaries',
              importance: Importance.max,
              playSound: true,
              sound: RawResourceAndroidNotificationSound('notification_sound'),
              enableVibration: true,
              enableLights: true,
            ),
          );

          // Daily Sales Reports Channel
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'apna_pos_sales_v2',
              'Daily Sales Reports',
              description: 'Visual end-of-day sales summary and performance metrics',
              importance: Importance.max,
              playSound: true,
              sound: RawResourceAndroidNotificationSound('notification_sound'),
              enableVibration: true,
              enableLights: true,
            ),
          );
        }
      }

      try {
        WidgetsBinding.instance.addObserver(this);
      } catch (_) {}

      // Check if launched by tapping a local notification or via FullScreenIntent
      final launchDetails = await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payload = launchDetails.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          debugPrint('[LocalNotificationService] App launched via local notification fullScreenIntent: $payload');
          _handleNotificationPayload(payload);
        }
      }

      // Check SharedPreferences for any pending incoming orders delivered during background/sleep
      checkAndShowPendingIncomingOrder();

      _isInitialized = true;
      debugPrint('[LocalNotificationService] Initialized with all Android channels successfully');
    } catch (e) {
      debugPrint('[LocalNotificationService] Initialization error: $e');
    }
  }

  static int _lastResumeCheckTime = 0;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastResumeCheckTime < 800) {
        return;
      }
      _lastResumeCheckTime = now;

      // 1. Check local queue from FCM background isolate or device unlock
      checkAndShowPendingIncomingOrder();
      // 2. Proactively verify and register device push token with backend
      try {
        FcmService().registerTokenWithBackend();
      } catch (_) {}

    }
  }

  static void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    final isAccept = response.actionId == 'accept_order';
    final isReject = response.actionId == 'reject_order';
    _handleNotificationPayload(payload, autoAccept: isAccept, autoReject: isReject);
  }

  /// Check if a high-priority WhatsApp or online order was received while the phone was locked or app was killed
  static Future<void> checkAndShowPendingIncomingOrder() async {
    try {
      if (SplashScreen.isSplashActive) {
        debugPrint('[LocalNotificationService] checkAndShowPendingIncomingOrder deferred (splash active)');
        return;
      }
      if (IncomingOrderAcceptScreen.isShowing) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // Check in-memory pending payload first
      if (_pendingIncomingOrderPayload != null) {
        final payload = _pendingIncomingOrderPayload!;
        _pendingIncomingOrderPayload = null;
        final pendingAction = prefs.getString('pending_notification_action');
        if (pendingAction != null) {
          await prefs.remove('pending_notification_action');
        }
        await prefs.remove('pending_incoming_order_payload');
        _handleNotificationPayload(
          jsonEncode(payload),
          autoAccept: pendingAction == 'accept',
          autoReject: pendingAction == 'reject',
        );
        return;
      }

      final pendingJson = prefs.getString('pending_incoming_order_payload');
      final pendingAction = prefs.getString('pending_notification_action');
      if (pendingJson != null && pendingJson.isNotEmpty) {
        await prefs.remove('pending_incoming_order_payload');
        if (pendingAction != null) {
          await prefs.remove('pending_notification_action');
        }
        try {
          final decoded = jsonDecode(pendingJson);
          if (decoded is Map) {
            final Map<String, dynamic> m = Map<String, dynamic>.from(decoded);
            final rawSrc = (m['orderSource'] ?? '').toString().toLowerCase();
            final rawType = (m['orderType'] ?? '').toString().toLowerCase();
            final cleanType = rawType.replaceAll(RegExp(r'[-_\s]'), '');
            final ordId = (m['orderId'] ?? '').toString();
            final ordNum = (m['orderNumber'] ?? '').toString();
            final bool isExplicitExternal = rawSrc == 'whatsapp' ||
                rawSrc == 'profile' ||
                rawSrc == 'storefront' ||
                rawSrc == 'online' ||
                rawSrc == 'qr' ||
                cleanType.contains('whatsapp') ||
                cleanType.contains('profile');
            final isPos = !isExplicitExternal && (
                rawSrc == 'pos' ||
                rawSrc == 'counter' ||
                rawSrc == 'local' ||
                DatabaseService.isKnownPosOrder(ordId) ||
                DatabaseService.isKnownPosOrder(ordNum));
            if (isPos) {
              debugPrint('[LocalNotificationService] Discarding pending POS order payload from prefs');
              return;
            }
            if (DatabaseService.isOrderDismissed(ordId, ordNum)) {
              debugPrint('[LocalNotificationService] Discarding already dismissed order payload: $ordNum / $ordId');
              return;
            }
            final createdAtStr = m['createdAt']?.toString();
            if (createdAtStr != null && createdAtStr.isNotEmpty) {
              final parsed = DateTime.tryParse(createdAtStr);
              if (parsed != null) {
                final ageSec = DateTime.now().difference(parsed).inSeconds.abs();
                if (ageSec > 900) {
                  debugPrint('[LocalNotificationService] Discarding stale order payload from prefs (age: ${ageSec}s)');
                  return;
                }
              }
            }
          }
        } catch (_) {}
        debugPrint('[LocalNotificationService] Found pending background order in SharedPreferences: $pendingJson (Action: $pendingAction)');
        _handleNotificationPayload(
          pendingJson,
          autoAccept: pendingAction == 'accept',
          autoReject: pendingAction == 'reject',
        );
        return;
      }

      // Check database for any unhandled pending external order placed within last 15 mins
      if (!IncomingOrderAcceptScreen.isShowing) {
        final pendingDbOrder = await DatabaseService().findPendingExternalOrderForPrompt();
        if (pendingDbOrder != null && !IncomingOrderAcceptScreen.isShowing) {
          final ctx = navigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            IncomingOrderAcceptScreen.openFromPayload(ctx, pendingDbOrder);
          } else {
            _pendingIncomingOrderPayload = pendingDbOrder;
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalNotificationService] Error checking pending incoming order: $e');
    }
  }

  /// Display a native system notification from an incoming FCM RemoteMessage (invoked in foreground, background, and terminated states)
  static Future<void> showNotificationFromRemoteMessage(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final data = message.data;

      final rawTitle = notification?.title ?? data['title']?.toString() ?? 'Apna POS Notification';
      final rawBody = notification?.body ?? data['message']?.toString() ?? '';
      final typeStr = data['type']?.toString() ?? 'system';

      final orderId = (data['orderId'] ?? '').toString().trim();
      final orderNum = (data['orderNumber'] ?? '').toString().trim();
      final rawType = (data['orderType'] ?? '').toString().toLowerCase();
      final cleanType = rawType.replaceAll(RegExp(r'[-_\s]'), '');
      final rawSource = (data['orderSource'] ?? '').toString().toLowerCase();
      final pm = (data['paymentMethod'] ?? '').toString().toLowerCase();
      final isKot = pm.contains('kot') || data['isKot'] == true || data['isKot'] == 'true' || (data['status'] ?? '').toString().toLowerCase() == 'preparing';

      final bool isExplicitChatMessage = typeStr == 'whatsapp_message' ||
          typeStr == 'chat_message' ||
          data['entityType'] == 'whatsapp_chat' ||
          data['entityType'] == 'whatsapp_message' ||
          data['type'] == 'whatsapp_message' ||
          data['type'] == 'chat_message';

      final bool isExplicitExternal = !isExplicitChatMessage && (
          rawSource == 'whatsapp' ||
          rawSource == 'profile' ||
          rawSource == 'storefront' ||
          rawSource == 'online' ||
          rawSource == 'qr' ||
          cleanType.contains('whatsapp') ||
          cleanType.contains('profile') ||
          typeStr == 'whatsapp_order_request'
      );

      final bool isDineInOrLocalPos = isKot ||
          (!isExplicitExternal && (
            rawSource == 'pos' ||
            rawSource == 'counter' ||
            rawSource == 'local' ||
            DatabaseService.isKnownPosOrder(orderId) ||
            DatabaseService.isKnownPosOrder(orderNum)
          ));

      if (isDineInOrLocalPos) {
        debugPrint('[LocalNotificationService] Background push suppressed for POS/Dine-In order: $orderNum / $orderId');
        return;
      }

      final isWhatsAppOrder = !isExplicitChatMessage && !isDineInOrLocalPos && (
          typeStr == 'whatsapp_order_request' ||
          typeStr == 'whatsapp_new_order' ||
          typeStr == 'whatsapp_order' ||
          (typeStr == 'new_order' && rawSource != 'pos') ||
          (typeStr == 'newOrder' && rawSource != 'pos') ||
          (typeStr == 'order_created' && rawSource != 'pos') ||
          (data['entityType'] == 'whatsapp_order') ||
          (isExplicitExternal && (orderId.isNotEmpty || orderNum.isNotEmpty))
      );

      String finalTitle = rawTitle;
      String finalBody = rawBody;
      StyleInformation? bigTextStyle;

      if (isWhatsAppOrder) {
        final orderNum = data['orderNumber']?.toString() ?? data['orderId']?.toString() ?? '';
        final cleanNum = orderNum.isNotEmpty
            ? (orderNum.startsWith('#') ? orderNum : '#$orderNum')
            : '';
        final amount = data['totalAmount']?.toString() ?? '';
        final custName = data['customerName']?.toString();
        final cleanName = (custName != null && custName.isNotEmpty && custName != 'Customer')
            ? custName
            : 'Customer';
        final oType = (data['orderType']?.toString() ?? 'takeaway').toUpperCase();

        // 1. High-impact short title that NEVER truncates
        if (cleanNum.isNotEmpty) {
          finalTitle = amount.isNotEmpty ? '🔔 $cleanNum • ₹$amount' : '🔔 New Order: $cleanNum';
        } else {
          finalTitle = amount.isNotEmpty ? '🔔 New Order • ₹$amount' : '🔔 New Order Received';
        }

        // 2. Parse items for expanded preview
        String itemsSummary = '';
        try {
          final rawItems = data['items'];
          if (rawItems is String && rawItems.isNotEmpty) {
            final decoded = jsonDecode(rawItems);
            if (decoded is List && decoded.isNotEmpty) {
              final names = decoded.map((i) => '${i['name'] ?? 'Item'} x${i['quantity'] ?? 1}').take(3).join(', ');
              final extra = decoded.length > 3 ? ' +${decoded.length - 3} more' : '';
              itemsSummary = '$names$extra';
            }
          }
        } catch (_) {}

        if (itemsSummary.isNotEmpty) {
          finalBody = '$cleanName ($oType)\n$itemsSummary';
        } else {
          finalBody = '$cleanName placed an order ($oType)';
        }

        bigTextStyle = BigTextStyleInformation(
          itemsSummary.isNotEmpty
              ? '$cleanName • $oType\n$itemsSummary\n⚡ Tap ACCEPT to confirm or REJECT to decline'
              : '$cleanName placed an order ($oType)\n⚡ Tap ACCEPT to confirm or REJECT to decline',
          contentTitle: finalTitle,
          summaryText: '🚨 Incoming Order Action Required',
          htmlFormatBigText: false,
          htmlFormatContentTitle: false,
        );
      }

      final isDailySummary = typeStr == 'daily_sales_summary' ||
          data['entityType'] == 'sales_report' ||
          data['type'] == 'daily_sales_summary';

      final notifTag = data['notificationTag']?.toString();

      final notifId = isDailySummary
          ? 9991
          : (isWhatsAppOrder && data['orderId'] != null
              ? data['orderId'].toString().hashCode.abs().remainder(100000)
              : 0);

      final instance = LocalNotificationService();
      await instance.init();

      await instance.showPushNotification(
        tag: notifTag,
        id: notifId,
        title: finalTitle,
        body: finalBody,
        payload: jsonEncode(data),
        styleInformation: bigTextStyle,
        skipDedupe: true,
        type: isWhatsAppOrder
            ? NotificationType.whatsappOrderRequest
            : (isDailySummary
                ? NotificationType.dailySalesSummary
                : instance.resolveNotificationType(typeStr)),
        channelId: isDailySummary
            ? 'apna_pos_sales_v2'
            : (isWhatsAppOrder
                ? 'apna_pos_whatsapp_orders_v2'
                : (typeStr.contains('whatsapp') ? 'apna_pos_whatsapp_messages_v1' : 'apna_pos_general_v2')),
        channelName: isDailySummary
            ? 'Sales & Business Reports'
            : (isWhatsAppOrder ? 'WhatsApp Orders & Alerts' : 'General Alerts & Orders'),
        channelDescription: isDailySummary
            ? 'Extended high-priority daily sales summaries and business metrics'
            : 'Real-time notifications for orders, leads, and daily summaries',
        entityType: data['entityType']?.toString(),
        entityId: data['entityId']?.toString(),
        metadata: data,
        playSound: true,
      );
    } catch (e) {
      debugPrint('[LocalNotificationService] Error showing notification from RemoteMessage: $e');
    }
  }

  /// Show standard push notification and register in Notification Center
  Future<void> showPushNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
    String? tag,
    NotificationType type = NotificationType.system,
    String? entityType,
    String? entityId,
    Map<String, dynamic> metadata = const {},
    bool playSound = true,
    bool skipDedupe = false,
    StyleInformation? styleInformation,
    String channelId = 'apna_pos_general_v2',
    String channelName = 'General Alerts & Orders',
    String channelDescription = 'Real-time notifications for orders, leads, and daily summaries',
    Importance importance = Importance.max,
    Priority priority = Priority.high,
    List<AndroidNotificationAction>? actions,
    Color? color,
    NotificationVisibility visibility = NotificationVisibility.public,
    AndroidNotificationCategory? category,
  }) async {
    final Map<String, dynamic> effectiveMeta = Map<String, dynamic>.from(metadata);
    if (payload != null && payload.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final k = entry.key.toString();
            if (!effectiveMeta.containsKey(k) || effectiveMeta[k] == null || effectiveMeta[k].toString().isEmpty) {
              effectiveMeta[k] = entry.value;
            }
          }
          if (decoded['metadata'] is Map) {
            final innerMeta = decoded['metadata'] as Map;
            for (final entry in innerMeta.entries) {
              final k = entry.key.toString();
              if (!effectiveMeta.containsKey(k) || effectiveMeta[k] == null || effectiveMeta[k].toString().isEmpty) {
                effectiveMeta[k] = entry.value;
              }
            }
          }
        }
      } catch (_) {}
    }

    final cleanTitle = title.trim().toLowerCase();
    final cleanBody = body.trim().toLowerCase();
    final orderId = (effectiveMeta['orderId'] ?? '').toString().trim();
    final orderNum = (effectiveMeta['orderNumber'] ?? '').toString().trim();
    final cleanType = type.name.toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
    final cleanMetaType = (effectiveMeta['type'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
    final cleanEntityType = (entityType ?? effectiveMeta['entityType'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
    final isDailySummary = type == NotificationType.dailySalesSummary ||
        cleanType.contains('dailysalessummary') ||
        cleanMetaType.contains('dailysalessummary') ||
        cleanEntityType.contains('salesreport') ||
        entityType == 'sales_report';

    final bool isExplicitChatMessage = type == NotificationType.whatsappMessage ||
        cleanEntityType == 'whatsappchat' ||
        cleanEntityType == 'chatmessage' ||
        effectiveMeta['type'] == 'whatsapp_message' ||
        effectiveMeta['type'] == 'chat_message' ||
        effectiveMeta['entityType'] == 'whatsapp_chat';

    final bool hasOrderIdentifiers = orderId.isNotEmpty || orderNum.isNotEmpty;

    final isOrderHint = !isExplicitChatMessage && (
        type == NotificationType.whatsappOrderRequest ||
        effectiveMeta['type'] == 'whatsapp_order_request' ||
        effectiveMeta['type'] == 'whatsapp_new_order' ||
        effectiveMeta['type'] == 'whatsapp_order' ||
        effectiveMeta['type'] == 'new_order' ||
        effectiveMeta['type'] == 'newOrder' ||
        effectiveMeta['type'] == 'order_created' ||
        (hasOrderIdentifiers && effectiveMeta['orderId'] != null)
    );

    final String? effectiveTag = tag ??
        (isDailySummary
            ? 'daily_sales_summary'
            : (isExplicitChatMessage
                ? 'chat_${effectiveMeta['chatId'] ?? entityId ?? "whatsapp"}'
                : (isOrderHint
                    ? 'order_${orderId.isNotEmpty ? orderId : (orderNum.isNotEmpty ? orderNum : "incoming")}'
                    : (effectiveMeta['notificationTag']?.toString() ??
                        (orderId.isNotEmpty ? 'order_$orderId' : null)))));

    // 0. Deduplicate notifications across Socket & FCM using unified cross-isolate debouncer
    if (!skipDedupe) {
      final isDuplicate = await shouldSuppressDuplicate(
        id: id != 0 ? id : (isDailySummary ? 9991 : null),
        tag: effectiveTag,
        orderId: orderId.isNotEmpty ? orderId : null,
        orderNumber: orderNum.isNotEmpty ? orderNum : null,
        entityId: entityId ?? effectiveMeta['entityId']?.toString(),
        type: type.name,
        title: title,
        body: body,
        debounceSeconds: isDailySummary ? 120 : 25,
      );

      if (isDuplicate) {
        debugPrint('[LocalNotificationService] 🚫 Suppressed duplicate push in showPushNotification: "$title"');
        return;
      }
    }

    final bool isAppForeground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    if (!_isSupportedPlatform) {
      if (playSound) {
        final rawType = (effectiveMeta['orderType'] ?? effectiveMeta['type'] ?? '').toString().toLowerCase().trim();
        final isOrder = type == NotificationType.whatsappOrderRequest || rawType.contains('order');
        if (isOrder) {
          SoundService.playOrderRingtone();
        } else {
          SoundService.playNotificationSound();
        }
      }
      debugPrint('[LocalNotificationService] Push notification delivered (in-app): "$title"');
      return;
    }

    if (!_isInitialized) await init();

    try {
      final orderId = (effectiveMeta['orderId'] ?? '').toString().trim();
      final orderNum = (effectiveMeta['orderNumber'] ?? '').toString().trim();
      final oSource = (effectiveMeta['orderSource'] ?? effectiveMeta['source'] ?? '').toString().toLowerCase().trim();
      final rawType = (effectiveMeta['orderType'] ?? effectiveMeta['type'] ?? '').toString().toLowerCase().trim();
      final cleanType = rawType.replaceAll(RegExp(r'[-_\s]'), '');
      final pm = (effectiveMeta['paymentMethod'] ?? '').toString().toLowerCase();
      final isKot = pm.contains('kot') ||
          effectiveMeta['isKot'] == true ||
          effectiveMeta['isKot'] == 'true' ||
          (effectiveMeta['status'] ?? '').toString().toLowerCase() == 'preparing';

      final bool isExplicitChatMessage = type == NotificationType.whatsappMessage ||
          cleanEntityType == 'whatsappchat' ||
          cleanEntityType == 'chatmessage' ||
          effectiveMeta['type'] == 'whatsapp_message' ||
          effectiveMeta['type'] == 'chat_message' ||
          effectiveMeta['entityType'] == 'whatsapp_chat';

      final bool hasOrderIdentifiers = orderId.isNotEmpty || orderNum.isNotEmpty;

      final bool isOrderType = type == NotificationType.whatsappOrderRequest ||
          channelId == 'apna_pos_whatsapp_orders_v2' ||
          channelId == 'apna_pos_whatsapp_orders_v1' ||
          effectiveMeta['type'] == 'whatsapp_order_request' ||
          effectiveMeta['type'] == 'whatsapp_new_order' ||
          effectiveMeta['type'] == 'whatsapp_order' ||
          effectiveMeta['type'] == 'new_order' ||
          effectiveMeta['type'] == 'newOrder' ||
          effectiveMeta['type'] == 'order_created';

      final bool isExplicitExternalOrder = !isExplicitChatMessage && (
          isOrderType ||
          (hasOrderIdentifiers && (
              oSource == 'whatsapp' ||
              oSource == 'profile' ||
              oSource == 'storefront' ||
              oSource == 'online' ||
              oSource == 'qr' ||
              cleanType == 'whatsapporder' ||
              cleanType == 'profileorder' ||
              cleanType == 'storefrontorder'
          ))
      );

      final bool isPosOrder = !isExplicitExternalOrder && (
          isKot ||
          oSource == 'pos' ||
          oSource == 'counter' ||
          oSource == 'local' ||
          DatabaseService.isKnownPosOrder(orderId) ||
          DatabaseService.isKnownPosOrder(orderNum)
      );

      final bool matchesKnownOrderInTitle = (orderNum.isNotEmpty && DatabaseService.isKnownPosOrder(orderNum)) ||
          (orderId.isNotEmpty && DatabaseService.isKnownPosOrder(orderId));
      final bool titleOrBodyContainsDineIn = cleanTitle.contains('dinein') || cleanBody.contains('dinein');

      if (!isExplicitChatMessage && (isPosOrder || (!isExplicitExternalOrder && (matchesKnownOrderInTitle || titleOrBodyContainsDineIn)))) {
        debugPrint('[LocalNotificationService] Suppressing push notification for POS order: $orderNum / $orderId');
        return;
      }

      final isWhatsAppOrder = !isExplicitChatMessage && (isExplicitExternalOrder || isOrderType);

      // Play audio feedback based on notification category
      if (playSound) {
        if (isWhatsAppOrder) {
          SoundService.playOrderRingtone();
        } else {
          SoundService.playNotificationSound();
        }
      }
      final isWhatsApp = isWhatsAppOrder || type == NotificationType.whatsappMessage;
      final effectiveChannelId = isWhatsAppOrder
          ? 'apna_pos_whatsapp_orders_v2'
          : (isWhatsApp ? 'apna_pos_whatsapp_messages_v1' : channelId);
      final effectiveChannelName = isWhatsAppOrder
          ? 'WhatsApp Orders & Alerts'
          : (isWhatsApp ? 'WhatsApp Messages' : channelName);
      final effectiveChannelDesc = isWhatsAppOrder
          ? 'Urgent incoming customer orders with instant alert and popup'
          : (isWhatsApp
              ? 'Real-time notifications for incoming WhatsApp customer messages'
              : channelDescription);
      final effectiveColor = isWhatsApp ? const Color(0xFF25D366) : color;

      final defaultActions = (isWhatsAppOrder)
          ? <AndroidNotificationAction>[
              const AndroidNotificationAction(
                'accept_order',
                '✅ ACCEPT',
                showsUserInterface: true,
                cancelNotification: true,
                contextual: false,
              ),
              const AndroidNotificationAction(
                'reject_order',
                '❌ REJECT',
                showsUserInterface: true,
                cancelNotification: true,
                contextual: false,
              ),
            ]
          : null;

      StyleInformation? effectiveStyle = styleInformation;
      if (effectiveStyle == null && isWhatsAppOrder) {
        effectiveStyle = BigTextStyleInformation(
          '$body\n⚡ Tap ACCEPT to confirm or REJECT to decline',
          contentTitle: title,
          summaryText: '🚨 Incoming Order Action Required',
          htmlFormatBigText: false,
          htmlFormatContentTitle: false,
        );
      } else if (effectiveStyle == null && isWhatsApp) {
        effectiveStyle = BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'WhatsApp Chat',
          htmlFormatBigText: false,
          htmlFormatContentTitle: false,
        );
      }

      final String? effectiveTag = tag ??
          (isDailySummary
              ? 'daily_sales_summary'
              : (isExplicitChatMessage
                  ? 'chat_${effectiveMeta['chatId'] ?? entityId ?? "whatsapp"}'
                  : (isWhatsAppOrder
                      ? 'order_${orderId.isNotEmpty ? orderId : (orderNum.isNotEmpty ? orderNum : "incoming")}'
                      : (effectiveMeta['notificationTag']?.toString() ??
                          (orderId.isNotEmpty ? 'order_$orderId' : null)))));

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        effectiveChannelId,
        effectiveChannelName,
        channelDescription: effectiveChannelDesc,
        importance: (isWhatsApp || isWhatsAppOrder) ? Importance.max : importance,
        priority: (isWhatsApp || isWhatsAppOrder) ? Priority.max : priority,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        styleInformation: effectiveStyle,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        actions: actions ?? defaultActions,
        color: effectiveColor,
        fullScreenIntent: !isAppForeground && isWhatsAppOrder,
        visibility: NotificationVisibility.public,
        tag: effectiveTag,
        category: isWhatsAppOrder
            ? AndroidNotificationCategory.call
            : (isWhatsApp ? AndroidNotificationCategory.message : category),
        ticker: isWhatsAppOrder
            ? 'New Incoming Order!'
            : (isWhatsApp ? 'New WhatsApp Message' : null),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'Notification_sound.mp3',
      );

      final NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final effectivePayload = payload ??
          jsonEncode({
            'type': type.name,
            'entityType': entityType ?? (isWhatsApp ? 'whatsapp_chat' : 'system'),
            'entityId': entityId,
            'metadata': metadata,
          });

      final int effectiveId;
      if (isDailySummary) {
        effectiveId = 9991;
      } else if (isWhatsAppOrder) {
        effectiveId = orderId.isNotEmpty
            ? orderId.hashCode.abs().remainder(100000)
            : (orderNum.isNotEmpty ? orderNum.hashCode.abs().remainder(100000) : (id != 0 ? id : 9992));
      } else if (id != 0) {
        effectiveId = id;
      } else if (orderId.isNotEmpty) {
        effectiveId = orderId.hashCode.abs().remainder(100000);
      } else if (isExplicitChatMessage) {
        final cId = (entityId ?? effectiveMeta['chatId'] ?? effectiveMeta['customerPhone'])?.toString().trim();
        effectiveId = (cId != null && cId.isNotEmpty)
            ? cId.hashCode.abs().remainder(100000)
            : (effectiveTag != null ? effectiveTag.hashCode.abs().remainder(100000) : 9993);
      } else if (effectiveTag != null && effectiveTag.isNotEmpty) {
        effectiveId = effectiveTag.hashCode.abs().remainder(100000);
      } else {
        effectiveId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      }

      await _notificationsPlugin.show(
        effectiveId,
        title,
        body,
        platformDetails,
        payload: effectivePayload,
      );
      debugPrint('[LocalNotificationService] Push notification delivered: "$title"');
    } catch (e) {
      debugPrint('[LocalNotificationService] Error showing push notification: $e');
    }
  }

  /// Deliver daily business summary as a prominent visual push notification in native notification center
  Future<void> deliverDailyBusinessSummaryPushNotification({
    required double totalSales,
    required int orderCount,
    required double revenue,
    String? dateStr,
    String? formattedDate,
    List<dynamic> orders = const [],
  }) async {
    try {
      final dateLabel = (formattedDate != null && formattedDate.trim().isNotEmpty)
          ? formattedDate.trim()
          : (dateStr ?? 'Today');

      final double avgOrderValue =
          orderCount > 0 ? (totalSales / orderCount).roundToDouble() : 0.0;

      final currencyFormatter = NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 0,
      );

      final String salesFormatted = currencyFormatter.format(totalSales.round());
      final String avgFormatted = currencyFormatter.format(avgOrderValue.round());

      final title = 'Daily Sales Summary 📊 • $dateLabel';
      final String body;
      final String expandedBigText;

      if (orderCount > 0) {
        body = '🟢 Sales: $salesFormatted  •  🔵 Orders: $orderCount  •  🟠 Avg: $avgFormatted';
        expandedBigText = '🎉 Business Performance for $dateLabel:\n'
            '• Revenue: $salesFormatted earned\n'
            '• Orders: $orderCount completed\n'
            '• Avg Ticket: $avgFormatted/order\n'
            'Tap to inspect sales breakdown & payment methods.';
      } else {
        body = 'Your daily summary for $dateLabel is ready. No orders recorded today.';
        expandedBigText =
            'No sales recorded for $dateLabel. Your register and catalog are active and ready for tomorrow.';
      }

      final Map<String, dynamic> metadata = {
        'date': dateStr ?? DateTime.now().toIso8601String().split('T')[0],
        'formattedDate': dateLabel,
        'totalSales': totalSales,
        'revenue': revenue,
        'ordersCount': orderCount,
        'avgOrderValue': avgOrderValue,
        'orders': orders,
      };

      // 1. Generate 3-Card Visual Metric Banner for Native Notification Tray
      String? bannerPath;
      if (_isSupportedPlatform) {
        bannerPath = await SalesNotificationBannerGenerator.generateBannerFile(
          totalSales: totalSales,
          orderCount: orderCount,
          avgOrderValue: avgOrderValue,
        );
      }

      StyleInformation? styleInfo;
      if (bannerPath != null && bannerPath.isNotEmpty) {
        styleInfo = BigPictureStyleInformation(
          FilePathAndroidBitmap(bannerPath),
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          contentTitle: '📊 Daily Sales Summary • $dateLabel',
          summaryText: '🟢 $salesFormatted  •  🔵 $orderCount Orders  •  🟠 Avg $avgFormatted',
          hideExpandedLargeIcon: true,
        );
      } else {
        styleInfo = BigTextStyleInformation(
          expandedBigText,
          contentTitle: title,
          summaryText: '$salesFormatted • $orderCount Orders',
        );
      }

      // 2. Show device native push notification in system tray with 3-card banner in extended mode
      await showPushNotification(
        id: 9991,
        title: title,
        body: body,
        payload: 'daily_sales_summary',
        type: NotificationType.dailySalesSummary,
        entityType: 'sales_report',
        entityId: dateStr,
        metadata: metadata,
        playSound: true,
        channelId: 'apna_pos_sales_v2',
        channelName: 'Sales & Business Reports',
        channelDescription: 'Extended high-priority daily sales summaries and business metrics',
        importance: Importance.max,
        priority: Priority.max,
        color: const Color(0xFF0F9D58),
        category: AndroidNotificationCategory.status,
        visibility: NotificationVisibility.public,
        actions: const [
          AndroidNotificationAction(
            'view_sales_report',
            '📊 View Sales Report',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
        styleInformation: styleInfo,
      );

      // 3. Add directly to Notification Center list
      NotificationService().addLocalNotification(
        title: title,
        message: body,
        type: NotificationType.dailySalesSummary,
        entityType: 'sales_report',
        entityId: dateStr,
        metadata: metadata,
      );
    } catch (e) {
      debugPrint('[LocalNotificationService] Error delivering daily summary push: $e');
    }
  }

  /// Deliver welcome push notification when user logs in or creates an account
  Future<void> deliverWelcomeNotificationOnLogin({String? userName}) async {
    try {
      final greetingName = (userName != null && userName.trim().isNotEmpty)
          ? userName.trim()
          : 'there';

      final title = 'Welcome to Apna POS 🎉';
      final body =
          'Hi $greetingName, welcome! Your smart POS partner is ready to manage your sales, orders & business operations.';

      await Future.delayed(const Duration(milliseconds: 600));

      await showPushNotification(
        id: 1002,
        title: title,
        body: body,
        payload: 'welcome',
        type: NotificationType.welcome,
        playSound: true,
      );

      NotificationService().addLocalNotification(
        title: title,
        message: body,
        type: NotificationType.welcome,
        entityType: 'user',
      );

      NotificationService().fetchNotifications(refresh: true);
      NotificationService().fetchUnreadCount();
    } catch (e) {
      debugPrint('[LocalNotificationService] Error delivering login welcome push notification: $e');
    }
  }
  /// Cancel any pending local push notification for an order that has been handled
  Future<void> cancelNotificationForOrder(String orderId) async {
    if (orderId.trim().isEmpty || !_isSupportedPlatform) return;
    try {
      final cleanId = orderId.trim();
      final id = cleanId.hashCode.abs().remainder(100000);
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        try {
          await androidPlugin.cancel(id, tag: 'order_$cleanId');
        } catch (_) {}
      }
      await _notificationsPlugin.cancel(id);
      debugPrint('[LocalNotificationService] Cancelled push notification for order: $cleanId (ID: $id)');
    } catch (e) {
      debugPrint('[LocalNotificationService] Error cancelling notification: $e');
    }
  }
}
