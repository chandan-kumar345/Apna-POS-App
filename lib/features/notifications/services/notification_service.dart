import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/notification_model.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal() {
    _startPolling();
  }

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

  void _startPolling() {
    _pollingTimer?.cancel();
    // Poll unread count every 30 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchUnreadCount();
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
  }) async {
    if (_isLoading) return;

    if (filterType != null) {
      _activeFilter = filterType;
    }

    _isLoading = true;
    _errorMessage = null;
    if (page == 1 || refresh) {
      _currentPage = 1;
    }
    notifyListeners();

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

      final items = notifsList.map((n) => NotificationItem.fromJson(n as Map<String, dynamic>)).toList();

      if (page == 1 || refresh) {
        _notifications.clear();
        _notifications.addAll(items);
      } else {
        _notifications.addAll(items);
      }

      _currentPage = (pagination['page'] as int?) ?? page;
      _totalPages = (pagination['totalPages'] as int?) ?? 1;
      _unreadCount = (data['unreadCount'] as int?) ?? _notifications.where((n) => !n.isRead).length;
      _errorMessage = null;
    } catch (e) {
      debugPrint('[NotificationService] Error fetching notifications: $e');
      _errorMessage = 'Unable to load notifications. Please check your connection.';
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

      final items = notifsList.map((n) => NotificationItem.fromJson(n as Map<String, dynamic>)).toList();
      _notifications.addAll(items);

      _currentPage = (pagination['page'] as int?) ?? nextPage;
      _totalPages = (pagination['totalPages'] as int?) ?? _totalPages;
      _unreadCount = (data['unreadCount'] as int?) ?? _unreadCount;
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
      }
    } catch (_) {
      // Quietly ignore network polling errors
    }
  }

  /// Mark single notification as read (Optimistic UI + API Sync)
  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      _unreadCount = (_unreadCount - 1).clamp(0, 9999);
      notifyListeners();

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
      rawType: type == NotificationType.welcome ? 'welcome' : 'system',
      timestamp: DateTime.now(),
      isRead: false,
      entityType: entityType ?? 'system',
      entityId: entityId,
      metadata: metadata,
    );

    // Prevent duplicate welcomes
    if (type == NotificationType.welcome && _notifications.any((n) => n.type == NotificationType.welcome)) {
      return;
    }

    _notifications.insert(0, newItem);
    _unreadCount++;
    notifyListeners();
  }
}
