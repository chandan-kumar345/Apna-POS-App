import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../features/notifications/services/notification_service.dart';
import '../../features/notifications/models/notification_model.dart';
import 'sound_service.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initialize local notification channels for Android and iOS
  Future<void> init() async {
    if (_isInitialized || kIsWeb) return;

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
  }) async {
    if (kIsWeb) return;
    if (!_isInitialized) await init();

    // 1. Play immediate in-app audio feedback from assets
    if (playSound) {
      SoundService.playNotificationSound();
    }

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'apna_pos_general_v2',
        'General Alerts & Orders',
        channelDescription: 'Real-time notifications for orders, leads, and daily summaries',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'Notification_sound.mp3',
      );

      const NotificationDetails platformDetails = NotificationDetails(
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

  /// Deliver daily business summary as a prominent system push notification & register in Notification Center
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

      final title = 'Your Daily Business Summary 📊';
      final body = orderCount > 0
          ? 'Here’s your business summary for $dateLabel: Total Sales ₹${totalSales.toStringAsFixed(0)} from $orderCount orders. Tap to view orders breakdown.'
          : 'Your daily summary for $dateLabel is ready. No orders recorded today. Tap to view report.';

      final Map<String, dynamic> metadata = {
        'date': dateStr ?? DateTime.now().toIso8601String().split('T')[0],
        'formattedDate': dateLabel,
        'totalSales': totalSales,
        'revenue': revenue,
        'ordersCount': orderCount,
        'orders': orders,
      };

      // 1. Show device native push notification in system tray with sound
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
      );

      // 2. Add directly to Notification Center list
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
