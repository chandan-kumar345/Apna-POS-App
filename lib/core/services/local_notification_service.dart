import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../features/notifications/services/notification_service.dart';
import '../../features/notifications/models/notification_model.dart';
import '../../features/chat/meta_whatsapp_chat_screen.dart';
import 'sales_notification_banner_generator.dart';
import 'sound_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/orders/whatsapp_order_action_dialog.dart';
import '../database/database_service.dart';

class LocalNotificationService with WidgetsBindingObserver {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  /// Global Navigator key for deep-linking into WhatsApp chats or screens on notification tap
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final Map<String, int> _recentNotificationDedupe = {};
  bool _isInitialized = false;

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Handle notification payload when tapped from system notification tray
  static void _handleNotificationPayload(String? payload) {
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
            entityType == 'whatsapp_order' ||
            entityType == 'order';

        if (isOrder) {
          final orderId = metadata['orderId']?.toString() ??
              decoded['orderId']?.toString() ??
              decoded['entityId']?.toString() ??
              '';
          final orderNumber = metadata['orderNumber']?.toString() ??
              decoded['orderNumber']?.toString() ??
              '';
          final phone = metadata['customerPhone']?.toString() ??
              decoded['customerPhone']?.toString() ??
              '';
          final name = metadata['customerName']?.toString() ??
              decoded['customerName']?.toString() ??
              'Customer';
          final totalAmount = double.tryParse(metadata['totalAmount']?.toString() ??
                  decoded['totalAmount']?.toString() ??
                  '0') ??
              0.0;
          final orderType = metadata['orderType']?.toString() ??
              decoded['orderType']?.toString() ??
              'takeaway';
          final deliveryAddress = metadata['deliveryAddress']?.toString() ??
              decoded['deliveryAddress']?.toString() ??
              '';
          final itemsPayload = metadata['items'] ?? decoded['items'];
          final createdAtStr = metadata['createdAt']?.toString() ?? decoded['createdAt']?.toString();
          final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

          int attempts = 0;
          void tryShowOrderDialog() {
            attempts++;
            final ctx = navigatorKey.currentContext;
            if (ctx != null) {
              WhatsAppOrderActionDialog.show(
                ctx,
                orderId: orderId,
                orderNumber: orderNumber,
                customerPhone: phone,
                customerName: name,
                totalAmount: totalAmount,
                orderType: orderType,
                deliveryAddress: deliveryAddress,
                itemsPayload: itemsPayload,
                createdAt: createdAt,
              );
            } else if (attempts < 30) {
              Future.delayed(const Duration(milliseconds: 250), tryShowOrderDialog);
            }
          }

          tryShowOrderDialog();
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
  static void handlePayloadDirectly(Map<String, dynamic> data) {
    try {
      _handleNotificationPayload(jsonEncode(data));
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
          debugPrint('[LocalNotificationService] Notification tapped: ${response.payload}');
          _handleNotificationPayload(response.payload);
        },
      );

      // Explicitly register Android Notification Channels so background/terminated push notifications are never dropped
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          // WhatsApp Orders & Urgent Alerts Channel - Highest Importance, Sound, Vibration, Full Screen Intent
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'apna_pos_whatsapp_orders_v1',
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 1. Check local queue from FCM background isolate
      checkAndShowPendingIncomingOrder();
      // 2. Proactively query backend for any unaccepted orders received while asleep
      try {
        DatabaseService().checkAndPromptPendingWhatsAppOrders();
      } catch (_) {}
    }
  }

  /// Check if a high-priority WhatsApp order was received while the phone was locked or app was killed
  static Future<void> checkAndShowPendingIncomingOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingJson = prefs.getString('pending_incoming_order_payload');
      if (pendingJson != null && pendingJson.isNotEmpty) {
        await prefs.remove('pending_incoming_order_payload');
        debugPrint('[LocalNotificationService] Found pending background order in SharedPreferences: $pendingJson');
        _handleNotificationPayload(pendingJson);
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

      final title = notification?.title ?? data['title']?.toString() ?? 'Apna POS Notification';
      final body = notification?.body ?? data['message']?.toString() ?? '';
      final typeStr = data['type']?.toString() ?? 'system';

      final isWhatsAppOrder = typeStr == 'whatsapp_order_request' ||
          typeStr == 'whatsapp_new_order' ||
          typeStr == 'whatsapp_order' ||
          typeStr == 'new_order' ||
          typeStr == 'newOrder' ||
          typeStr == 'order_created' ||
          data['entityType'] == 'whatsapp_order' ||
          data['orderSource'] == 'whatsapp';

      final instance = LocalNotificationService();
      await instance.init();

      await instance.showPushNotification(
        title: title,
        body: body,
        payload: jsonEncode(data),
        type: isWhatsAppOrder
            ? NotificationType.whatsappOrderRequest
            : instance.resolveNotificationType(typeStr),
        channelId: isWhatsAppOrder
            ? 'apna_pos_whatsapp_orders_v1'
            : (typeStr.contains('whatsapp') ? 'apna_pos_whatsapp_messages_v1' : 'apna_pos_general_v2'),
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
    NotificationType type = NotificationType.system,
    String? entityType,
    String? entityId,
    Map<String, dynamic> metadata = const {},
    bool playSound = true,
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
    // 0. Deduplicate notifications across Socket & FCM using normalized title and body
    final cleanTitle = title.trim().toLowerCase();
    final cleanBody = body.trim().toLowerCase();
    final dedupeKey = '$cleanTitle::$cleanBody';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_recentNotificationDedupe.containsKey(dedupeKey)) {
      final prev = _recentNotificationDedupe[dedupeKey]!;
      if (nowMs - prev < 4500) {
        debugPrint('[LocalNotificationService] Suppressing duplicate push: "$title" within debounce window');
        return;
      }
    }
    _recentNotificationDedupe[dedupeKey] = nowMs;
    if (_recentNotificationDedupe.length > 50) {
      _recentNotificationDedupe.removeWhere((_, time) => nowMs - time > 10000);
    }

    // 1. Play in-app audio feedback ONLY on platforms without native channel sound
    // (Android/iOS channels already play notification_sound natively via system NotificationManager)
    if (playSound && (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      SoundService.playNotificationSound();
    }

    if (!_isSupportedPlatform) {
      if (playSound) {
        SoundService.playNotificationSound();
      }
      debugPrint('[LocalNotificationService] Push notification delivered (in-app): "$title"');
      return;
    }

    if (!_isInitialized) await init();

    try {
      final isWhatsAppOrder = type == NotificationType.whatsappOrderRequest ||
          channelId == 'apna_pos_whatsapp_orders_v1' ||
          metadata['type'] == 'whatsapp_order_request' ||
          metadata['type'] == 'whatsapp_new_order';
      final isWhatsApp = isWhatsAppOrder || type == NotificationType.whatsappMessage;
      final effectiveChannelId = isWhatsAppOrder
          ? 'apna_pos_whatsapp_orders_v1'
          : (isWhatsApp ? 'apna_pos_whatsapp_messages_v1' : channelId);
      final effectiveChannelName = isWhatsAppOrder
          ? 'WhatsApp Orders & Alerts'
          : (isWhatsApp ? 'WhatsApp Messages' : channelName);
      final effectiveChannelDesc = isWhatsAppOrder
          ? 'Urgent incoming WhatsApp customer orders with instant alert and popup'
          : (isWhatsApp
              ? 'Real-time notifications for incoming WhatsApp customer messages'
              : channelDescription);
      final effectiveColor = isWhatsApp ? const Color(0xFF25D366) : color;

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
        styleInformation: styleInformation,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        actions: actions,
        color: effectiveColor,
        fullScreenIntent: isWhatsAppOrder,
        visibility: NotificationVisibility.public,
        category: isWhatsAppOrder
            ? AndroidNotificationCategory.call
            : (isWhatsApp ? AndroidNotificationCategory.message : category),
        ticker: isWhatsAppOrder
            ? 'New WhatsApp Order!'
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

      await _notificationsPlugin.show(
        id == 0 ? DateTime.now().millisecondsSinceEpoch.remainder(100000) : id,
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
      final id = orderId.trim().hashCode.abs().remainder(100000);
      await _notificationsPlugin.cancel(id);
      debugPrint('[LocalNotificationService] Cancelled push notification for order: $orderId (ID: $id)');
    } catch (e) {
      debugPrint('[LocalNotificationService] Error cancelling notification: $e');
    }
  }
}
