import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/notification_permission_helper.dart';
import '../../orders/order_detail_sheet.dart';
import '../../crm/screens/crm_leads_screen.dart';
import '../../inventory/inventory_screen.dart';
import '../../dashboard/main_layout.dart';
import '../widgets/daily_business_summary_dialog.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _filterTabs = [
    {'key': 'All', 'label': 'All'},
    {'key': 'new_order', 'label': 'Orders'},
    {'key': 'new_lead', 'label': 'Leads'},
    {'key': 'daily_sales_summary', 'label': 'Daily Summary'},
    {'key': 'low_stock', 'label': 'Inventory'},
    {'key': 'system', 'label': 'System'},
  ];

  String _selectedFilter = 'All';
  bool _isPermissionGranted = true;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
    _scrollController.addListener(_onScroll);

    _checkPermission();

    // Initial fetch from backend API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _service.fetchNotifications(filterType: _selectedFilter, refresh: true);
    });
  }

  Future<void> _checkPermission() async {
    final granted = await NotificationPermissionHelper.isPermissionGranted();
    if (mounted && _isPermissionGranted != granted) {
      setState(() => _isPermissionGranted = granted);
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_service.hasMore && !_service.isLoadingMore) {
        _service.loadMore();
      }
    }
  }

  void _onFilterSelected(String filterKey) {
    setState(() => _selectedFilter = filterKey);
    _service.fetchNotifications(filterType: filterKey, refresh: true);
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('dd MMM, h:mm a').format(time);
  }

  Map<String, List<NotificationItem>> _groupNotificationsChronologically(List<NotificationItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<NotificationItem>> groups = {
      'Today': [],
      'Yesterday': [],
      'Earlier': [],
    };

    for (final item in items) {
      final itemDate = DateTime(item.timestamp.year, item.timestamp.month, item.timestamp.day);
      if (itemDate.isAtSameMomentAs(today)) {
        groups['Today']!.add(item);
      } else if (itemDate.isAtSameMomentAs(yesterday)) {
        groups['Yesterday']!.add(item);
      } else {
        groups['Earlier']!.add(item);
      }
    }

    // Remove empty groups
    groups.removeWhere((key, value) => value.isEmpty);
    return groups;
  }

  void _handleNotificationTap(NotificationItem notif) {
    _service.markAsRead(notif.id);

    switch (notif.target) {
      case NotificationTarget.orderDetails:
        OrderDetailSheet.show(
          context,
          orderId: notif.entityId,
          orderNumber: notif.metadata['orderNumber']?.toString(),
        );
        break;

      case NotificationTarget.crmLead:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CrmLeadsScreen()),
        );
        break;

      case NotificationTarget.salesReport:
        DailyBusinessSummaryDialog.show(
          context,
          metadata: {
            ...notif.metadata,
            'entityId': notif.entityId,
            'timestamp': notif.timestamp.toIso8601String(),
          },
          title: notif.title,
          message: notif.message,
        );
        break;

      case NotificationTarget.dashboard:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainLayout()),
          (route) => false,
        );
        break;

      case NotificationTarget.inventory:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const InventoryScreen()),
        );
        break;

      case NotificationTarget.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _service.notifications;
    final unreadCount = _service.unreadCount;
    final isLoading = _service.isLoading;
    final groupedNotifs = _groupNotificationsChronologically(notifications);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF082559),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Text(
              'Notification Center',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (val) {
                if (val == 'read_all') {
                  _service.markAllAsRead();
                } else if (val == 'clear_all') {
                  _service.clearAll();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'read_all',
                  child: Row(
                    children: [
                      Icon(Icons.done_all_rounded, size: 18, color: Color(0xFF082559)),
                      SizedBox(width: 10),
                      Text('Mark all as read', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.clear_all_rounded, size: 18, color: Color(0xFFEF4444)),
                      SizedBox(width: 10),
                      Text('Clear all', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterTabs.map((tab) {
                  final key = tab['key']!;
                  final label = tab['label']!;
                  final isSelected = _selectedFilter == key;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => _onFilterSelected(key),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF082559) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF082559) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                            color: isSelected ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Notification Permission Banner (if not granted)
          if (!_isPermissionGranted)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 12, 14, 2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_off_outlined, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Push Notifications Disabled',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Enable alerts to get instant updates for orders & leads.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final granted = await NotificationPermissionHelper.requestPermissionDirectly();
                      if (mounted) {
                        setState(() => _isPermissionGranted = granted);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF082559),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Enable',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),

          // Body Content
          Expanded(
            child: isLoading && notifications.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF082559)),
                  )
                : RefreshIndicator(
                    onRefresh: () => _service.fetchNotifications(filterType: _selectedFilter, refresh: true),
                    color: const Color(0xFF082559),
                    child: notifications.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            itemCount: groupedNotifs.keys.length + (_service.isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == groupedNotifs.keys.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF082559)),
                                    ),
                                  ),
                                );
                              }

                              final sectionTitle = groupedNotifs.keys.elementAt(index);
                              final sectionItems = groupedNotifs[sectionTitle]!;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                                    child: Text(
                                      sectionTitle,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF64748B),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  ...sectionItems.map((item) => _buildNotificationCard(item)),
                                ],
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2FE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                color: Color(0xFF082559),
                size: 44,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedFilter == 'All'
                  ? 'You are all caught up! New orders, customer leads, and business summaries will appear here.'
                  : 'No notifications in this category.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notif) {
    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _service.deleteNotification(notif.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notif.isRead ? const Color(0xFFE2E8F0) : const Color(0xFFBFDBFE),
            width: notif.isRead ? 1 : 1.2,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: InkWell(
          onTap: () => _handleNotificationTap(notif),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Avatar
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: notif.color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(notif.icon, color: notif.color, size: 20),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: notif.isRead ? FontWeight.w700 : FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (!notif.isRead)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF082559),
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            _formatTime(notif.timestamp),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif.message,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                          height: 1.35,
                        ),
                      ),
                      if (notif.target != NotificationTarget.none) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              'Tap to view',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: notif.color,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: notif.color),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
