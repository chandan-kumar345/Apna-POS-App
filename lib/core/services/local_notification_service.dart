import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../features/notifications/services/notification_service.dart';
import '../../features/notifications/models/notification_model.dart';

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
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
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
  }) async {
    if (kIsWeb) return;
    if (!_isInitialized) await init();

    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'apna_pos_general',
        'General Alerts',
        channelDescription: 'Real-time notifications for orders, leads, and business updates',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id,
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

  /// Deliver welcome push notification when user logs in or creates an account
  Future<void> deliverWelcomeNotificationOnLogin({String? userName}) async {
    try {
      final greetingName = (userName != null && userName.trim().isNotEmpty)
          ? userName.trim()
          : 'there';

      final title = 'Welcome to Apna POS 🎉';
      final body = 'Hi $greetingName, welcome! Your smart POS partner is ready to manage your sales, orders & business operations.';

      // Slight delay so the login transition completes smoothly
      await Future.delayed(const Duration(milliseconds: 600));

      // 1. Show native device push notification in system tray
      await showPushNotification(
        id: 1002,
        title: title,
        body: body,
        payload: 'welcome',
        type: NotificationType.welcome,
      );

      // 2. Add directly to in-app Notification Center so it appears in the Notification screen
      NotificationService().addLocalNotification(
        title: title,
        message: body,
        type: NotificationType.welcome,
        entityType: 'user',
      );

      // 3. Sync with backend notification center
      NotificationService().fetchNotifications(refresh: true);
      NotificationService().fetchUnreadCount();
    } catch (e) {
      debugPrint('[LocalNotificationService] Error delivering login welcome push notification: $e');
    }
  }
}
