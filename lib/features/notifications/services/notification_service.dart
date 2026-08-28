import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/services/local_notification_service.dart';
import '../models/notification_model.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal() {
    _loadCachedNotifications();
    _startPolling();
  }

  static const String _cacheKey = 'apna_pos_notifications_cache_v2';
  static const String _unreadCacheKey = 'apna_pos_notifications_unread_count_v2';

  final ApiClient _apiClient = ApiClient();

  final List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String _activeFilter = 'All';

  Timer? _pollingTimer;

  List<NotificationItem> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _currentPage < _totalPages;
  String? get errorMessage => _errorMessage;
  String get activeFilter => _activeFilter;

  /// Load cached notifications instantly on startup for zero-latency UI rendering
  Future<void> _loadCachedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(_cacheKey);
      _unreadCount = prefs.getInt(_unreadCacheKey) ?? 0;

      if (rawJson != null && rawJson.isNotEmpty) {
        final List decoded = jsonDecode(rawJson);
        final cachedItems = decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => NotificationItem.fromJson(item))
            .toList();

        if (cachedItems.isNotEmpty && _notifications.isEmpty) {
          _notifications.addAll(cachedItems);
          _unreadCount = _notifications.where((n) => !n.isRead).length;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error loading cached notifications: $e');
    }
  }

  /// Persist current notifications list into local storage asynchronously
  Future<void> _persistNotificationsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = jsonEncode(_notifications.take(50).map((n) => n.toJson()).toList());
      await prefs.setString(_cacheKey, listJson);
      await prefs.setInt(_unreadCacheKey, _unreadCount);
    } catch (_) {}
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    // Poll unread count and new notifications every 25 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      fetchUnreadCount();
      fetchNotifications(refresh: false, silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  /// Fetch initial or filtered notifications from backend API
  Future<void> fetchNotifications({
    int page = 1,
    int limit = 20,
    String? filterType,
    bool refresh = false,
    bool silent = false,
  }) async {
    if (_isLoading) return;

    if (filterType != null) {
      _activeFilter = filterType;
    }

    if (!silent && _notifications.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    _errorMessage = null;
    if (page == 1 || refresh) {
      _currentPage = 1;
    }

    try {
      final queryParams = <String, String>{
        'page': '$page',
        'limit': '$limit',
      };

      if (_activeFilter != 'All' && _activeFilter.isNotEmpty) {
        queryParams['type'] = _activeFilter;
      }

      final response = await _apiClient.get(
        ApiEndpoints.notifications,
        queryParameters: queryParams,
      );

      final data = response['data'] as Map<String, dynamic>? ?? {};
      final notifsList = (data['notifications'] as List?) ?? [];
      final pagination = (data['pagination'] as Map<String, dynamic>?) ?? {};

      final items =
          notifsList.map((n) => NotificationItem.fromJson(n as Map<String, dynamic>)).toList();

      // Check for newly arrived unread notifications to trigger push & sound
      if (_notifications.isNotEmpty && items.isNotEmpty) {
        final existingIds = _notifications.map((n) => n.id).toSet();
        for (final newItem in items) {
          if (!existingIds.contains(newItem.id) && !newItem.isRead) {
            if (newItem.type == NotificationType.dailySalesSummary) {
              LocalNotificationService().deliverDailyBusinessSummaryPushNotification(
                totalSales: (newItem.metadata['totalSales'] as num?)?.toDouble() ?? 0.0,
                orderCount: (newItem.metadata['ordersCount'] as num?)?.toInt() ?? 0,
                revenue: (newItem.metadata['revenue'] as num?)?.toDouble() ?? 0.0,
                dateStr: newItem.metadata['date']?.toString(),
                formattedDate: newItem.metadata['formattedDate']?.toString(),
                orders: (newItem.metadata['orders'] as List?) ?? [],
              );
            } else if (newItem.type != NotificationType.newOrder) {
              LocalNotificationService().showPushNotification(
                title: newItem.title,
                body: newItem.message,
                type: newItem.type,
                entityType: newItem.entityType,
                entityId: newItem.entityId,
                metadata: newItem.metadata,
                playSound: true,
              );
            }
          }
        }
      }

      if (page == 1 || refresh || silent) {
        // Merge seamlessly without flashing
        _notifications.clear();
        _notifications.addAll(items);
      } else {
        _notifications.addAll(items);
      }

      _currentPage = (pagination['page'] as int?) ?? page;
      _totalPages = (pagination['totalPages'] as int?) ?? 1;
      _unreadCount =
          (data['unreadCount'] as int?) ?? _notifications.where((n) => !n.isRead).length;
      _errorMessage = null;

      _persistNotificationsToCache();
    } catch (e) {
      debugPrint('[NotificationService] Error fetching notifications: $e');
      if (_notifications.isEmpty) {
        _errorMessage = 'Unable to load notifications. Please check your connection.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load next page for infinite scrolling
  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final queryParams = <String, String>{
        'page': '$nextPage',
        'limit': '20',
      };

      if (_activeFilter != 'All' && _activeFilter.isNotEmpty) {
        queryParams['type'] = _activeFilter;
      }

      final response = await _apiClient.get(
        ApiEndpoints.notifications,
        queryParameters: queryParams,
      );

      final data = response['data'] as Map<String, dynamic>? ?? {};
      final notifsList = (data['notifications'] as List?) ?? [];
      final pagination = (data['pagination'] as Map<String, dynamic>?) ?? {};

      final items =
          notifsList.map((n) => NotificationItem.fromJson(n as Map<String, dynamic>)).toList();
      _notifications.addAll(items);

      _currentPage = (pagination['page'] as int?) ?? nextPage;
      _totalPages = (pagination['totalPages'] as int?) ?? _totalPages;
      _unreadCount = (data['unreadCount'] as int?) ?? _unreadCount;

      _persistNotificationsToCache();
    } catch (e) {
      debugPrint('[NotificationService] Error loading more notifications: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Fetch live unread count from API
  Future<void> fetchUnreadCount() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.notificationsUnreadCount);
      final data = response['data'] as Map<String, dynamic>? ?? {};
      final count = (data['unreadCount'] as int?) ?? 0;
      if (_unreadCount != count) {
        _unreadCount = count;
        notifyListeners();
        _persistNotificationsToCache();
      }
    } catch (_) {}
  }

  /// Mark single notification as read (Optimistic UI + API Sync)
  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      _unreadCount = (_unreadCount - 1).clamp(0, 9999);
      notifyListeners();
      _persistNotificationsToCache();

      try {
        await _apiClient.patch(ApiEndpoints.notificationRead(id));
      } catch (e) {
        debugPrint('[NotificationService] Error marking as read: $e');
      }
    }
  }

  /// Mark all notifications as read (Optimistic UI + API Sync)
  Future<void> markAllAsRead() async {
    for (var n in _notifications) {
      n.isRead = true;
    }
    _unreadCount = 0;
    notifyListeners();
    _persistNotificationsToCache();

    try {
      await _apiClient.patch(ApiEndpoints.notificationsReadAll);
    } catch (e) {
      debugPrint('[NotificationService] Error marking all as read: $e');
    }
  }

  /// Delete a single notification (Optimistic UI + API Sync)
  Future<void> deleteNotification(String id) async {
    final notif = _notifications.firstWhere((n) => n.id == id, orElse: () => _notifications.first);
    if (!notif.isRead) {
      _unreadCount = (_unreadCount - 1).clamp(0, 9999);
    }
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
    _persistNotificationsToCache();

    try {
      await _apiClient.delete(ApiEndpoints.notificationDelete(id));
    } catch (e) {
      debugPrint('[NotificationService] Error deleting notification: $e');
    }
  }

  /// Clear all notifications (Optimistic UI + API Sync)
  Future<void> clearAll() async {
    _notifications.clear();
    _unreadCount = 0;
    notifyListeners();
    _persistNotificationsToCache();

    try {
      await _apiClient.delete(ApiEndpoints.notificationsClearAll);
    } catch (e) {
      debugPrint('[NotificationService] Error clearing notifications: $e');
    }
  }

  /// Register device push token to backend
  Future<void> registerDeviceToken(String token, {String platform = 'android'}) async {
    try {
      await _apiClient.post(
        ApiEndpoints.registerDeviceToken,
        data: {
          'token': token,
          'platform': platform,
        },
      );
    } catch (e) {
      debugPrint('[NotificationService] Error registering device token: $e');
    }
  }

  /// Add a notification locally and notify listeners so it immediately shows up in Notification Center
  void addLocalNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.welcome,
    String? entityType,
    String? entityId,
    Map<String, dynamic> metadata = const {},
  }) {
    final newItem = NotificationItem(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      type: type,
      rawType: type == NotificationType.welcome
          ? 'welcome'
          : (type == NotificationType.dailySalesSummary ? 'daily_sales_summary' : 'system'),
      timestamp: DateTime.now(),
      isRead: false,
      entityType: entityType ?? 'system',
      entityId: entityId,
      metadata: metadata,
    );

    // Prevent duplicate welcomes
    if (type == NotificationType.welcome &&
        _notifications.any((n) => n.type == NotificationType.welcome)) {
      return;
    }

    _notifications.insert(0, newItem);
    _unreadCount++;
    notifyListeners();
    _persistNotificationsToCache();

    // Play sound feedback
    SoundService.playNotificationSound();
  }
}
