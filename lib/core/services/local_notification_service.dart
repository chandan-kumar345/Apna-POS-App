import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import '../../features/notifications/services/notification_service.dart';
import '../../features/notifications/models/notification_model.dart';
import 'sales_notification_banner_generator.dart';
import 'sound_service.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

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
        },
      );

      _isInitialized = true;
      debugPrint('[LocalNotificationService] Initialized successfully');
    } catch (e) {
      debugPrint('[LocalNotificationService] Initialization error: $e');
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
    // 1. Play immediate in-app audio feedback from assets
    if (playSound) {
      SoundService.playNotificationSound();
    }

    if (!_isSupportedPlatform) {
      debugPrint('[LocalNotificationService] Push notification delivered (in-app): "$title"');
      return;
    }

    if (!_isInitialized) await init();

    try {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: importance,
        priority: priority,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification_sound'),
        styleInformation: styleInformation,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        actions: actions,
        color: color,
        visibility: visibility,
        category: category,
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

      await _notificationsPlugin.show(
        id == 0 ? DateTime.now().millisecondsSinceEpoch.remainder(100000) : id,
        title,
        body,
        platformDetails,
        payload: payload,
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
}
