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
import '../../chat/meta_whatsapp_chat_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();
  final ScrollController _scrollController = ScrollController();

  // Filter tabs: new_order is removed; WhatsApp filter added
  final List<Map<String, String>> _filterTabs = [
    {'key': 'All', 'label': 'All'},
    {'key': 'whatsapp_message', 'label': 'WhatsApp'},
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
      // Exclude new_order notifications completely
      if (item.type == NotificationType.newOrder) continue;

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

    // Direct redirection to WhatsApp chat screen if it's a WhatsApp message
    if (notif.type == NotificationType.whatsappMessage ||
        notif.target == NotificationTarget.whatsappChat ||
        notif.entityType == 'whatsapp_chat') {
      final customerPhone = notif.metadata['customerPhone']?.toString() ??
          notif.metadata['phone']?.toString() ??
          notif.entityId;
      final customerName = notif.metadata['customerName']?.toString();

      if (customerPhone != null && customerPhone.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MetaWhatsAppChatScreen(
              initialPhone: customerPhone,
              initialCustomerName: customerName,
            ),
          ),
        );
      }
      return;
    }

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

      case NotificationTarget.whatsappChat:
      case NotificationTarget.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter out any new_order notifications
    final notifications = _service.notifications
        .where((n) => n.type != NotificationType.newOrder)
        .toList();
    final unreadCount = _service.unreadCount;
    final isLoading = _service.isLoading;
    final groupedNotifs = _groupNotificationsChronologically(notifications);

    return Scaffold(
      backgroundColor: const Color(0xFF031024), // Signature Midnight Navy matching the app
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF031024), // Deep Midnight Navy
              Color(0xFF072146), // Rich Royal Navy
              Color(0xFF0A2E5C), // Deep Indigo Blue
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: true,
          child: Column(
            children: [
              // 1. Top Header Bar (Signature Apna POS Deep Navy Bar)
              _buildAppHeader(unreadCount, notifications.isNotEmpty),

              // 2. Active Notifications Workspace (Curved Top Container wrapping the screen like POS)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF2F6), // Neumorphism soft background
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 16,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720), // Responsive wrapped layout
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            // Neumorphic Filter Tabs
                            _buildNeumorphicFilterTabs(),

                            // Push Permission Banner
                            if (!_isPermissionGranted) _buildPermissionBanner(),

                            // Notifications List Body
                            Expanded(
                              child: isLoading && notifications.isEmpty
                                  ? const Center(
                                      child: CircularProgressIndicator(color: Color(0xFF0F172A), strokeWidth: 2.2),
                                    )
                                  : RefreshIndicator(
                                      onRefresh: () => _service.fetchNotifications(filterType: _selectedFilter, refresh: true),
                                      color: const Color(0xFF0F172A),
                                      child: notifications.isEmpty
                                          ? _buildEmptyState()
                                          : ListView.builder(
                                              controller: _scrollController,
                                              physics: const AlwaysScrollableScrollPhysics(),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                              itemCount: groupedNotifs.keys.length + (_service.isLoadingMore ? 1 : 0),
                                              itemBuilder: (context, index) {
                                                if (index == groupedNotifs.keys.length) {
                                                  return const Padding(
                                                    padding: EdgeInsets.symmetric(vertical: 14),
                                                    child: Center(
                                                      child: SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
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
                                                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                                                      child: Text(
                                                        sectionTitle.toUpperCase(),
                                                        style: const TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.w800,
                                                          color: Color(0xFF94A3B8),
                                                          letterSpacing: 0.8,
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
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top Header with signature Apna POS dark navy gradient, back button, and actions
  Widget _buildAppHeader(int unreadCount, bool hasNotifications) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Row(
            children: [
              // Circular Back Button
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 0.8),
                    boxShadow: const [
                      BoxShadow(color: Color(0x25000000), offset: Offset(0, 2), blurRadius: 4),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title & Unread Count Badge
              Expanded(
                child: Row(
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(color: Color(0x40EF4444), offset: Offset(0, 2), blurRadius: 6),
                          ],
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action Menu (Mark all as read / Clear all)
              if (hasNotifications)
                PopupMenuButton<String>(
                  color: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 0.8),
                      boxShadow: const [
                        BoxShadow(color: Color(0x25000000), offset: Offset(0, 2), blurRadius: 4),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.more_vert_rounded, color: Colors.white, size: 18),
                    ),
                  ),
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
                          Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF0F172A)),
                          SizedBox(width: 8),
                          Text('Mark all as read', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          Icon(Icons.clear_all_rounded, size: 16, color: Color(0xFFEF4444)),
                          SizedBox(width: 8),
                          Text('Clear all', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Neumorphic Filter Pills
  Widget _buildNeumorphicFilterTabs() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _filterTabs.map((tab) {
            final key = tab['key']!;
            final label = tab['label']!;
            final isSelected = _selectedFilter == key;

            return Padding(
              padding: const EdgeInsets.only(right: 7),
              child: InkWell(
                onTap: () => _onFilterSelected(key),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                    boxShadow: isSelected
                        ? [
                            const BoxShadow(
                              color: Color(0x2E0F172A),
                              offset: Offset(2, 4),
                              blurRadius: 8,
                            ),
                          ]
                        : const [
                            BoxShadow(
                              color: Color(0x0C000000),
                              offset: Offset(2, 3),
                              blurRadius: 5,
                            ),
                            BoxShadow(
                              color: Colors.white,
                              offset: Offset(-2, -2),
                              blurRadius: 4,
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (key == 'whatsapp_message') ...[
                        Icon(
                          Icons.chat_bubble_rounded,
                          size: 11,
                          color: isSelected ? const Color(0xFF25D366) : const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Push Notification Permission Banner
  Widget _buildPermissionBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), offset: Offset(2, 3), blurRadius: 6),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off_outlined, color: Color(0xFFD97706), size: 14),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alerts Disabled',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
                Text(
                  'Enable alerts to get instant WhatsApp messages & leads.',
                  style: TextStyle(
                    fontSize: 10,
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
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Enable', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  /// Neumorphic Notification Card with white background, curved corners, and smaller typography
  Widget _buildNotificationCard(NotificationItem notif) {
    final isWhatsApp = notif.type == NotificationType.whatsappMessage ||
        notif.target == NotificationTarget.whatsappChat ||
        notif.entityType == 'whatsapp_chat';

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _service.deleteNotification(notif.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(
          color: Colors.white, // Pure white background
          borderRadius: BorderRadius.circular(16), // Curved corners
          border: Border.all(
            color: notif.isRead
                ? const Color(0xFFE8EEF5)
                : (isWhatsApp ? const Color(0xFF86EFAC) : const Color(0xFFBFDBFE)),
            width: notif.isRead ? 0.9 : 1.2,
          ),
          boxShadow: const [
            // Neumorphic dual soft shadows
            BoxShadow(
              color: Color(0x0C000000),
              offset: Offset(3, 4),
              blurRadius: 8,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.white,
              offset: Offset(-2, -2),
              blurRadius: 5,
              spreadRadius: 0,
            ),
          ],
        ),
        child: InkWell(
          onTap: () => _handleNotificationTap(notif),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Neumorphic Icon Container
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: notif.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Color(0x08000000), offset: Offset(1, 2), blurRadius: 3),
                      BoxShadow(color: Colors.white, offset: Offset(-1, -1), blurRadius: 2),
                    ],
                  ),
                  child: Icon(
                    isWhatsApp ? Icons.chat_bubble_rounded : notif.icon,
                    color: notif.color,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),

                // Card Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Title & Timestamp
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5, // Smaller text
                                fontWeight: notif.isRead ? FontWeight.w700 : FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (!notif.isRead)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                color: isWhatsApp ? const Color(0xFF25D366) : const Color(0xFF0F172A),
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            _formatTime(notif.timestamp),
                            style: const TextStyle(
                              fontSize: 9.5, // Smaller time
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Notification Body Message
                      Text(
                        notif.message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11, // Smaller body text
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF475569),
                          height: 1.35,
                        ),
                      ),

                      // Bottom Action Row
                      const SizedBox(height: 5),
                      if (isWhatsApp)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F9EE),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFB7EBCE), width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_rounded, size: 9.5, color: Color(0xFF16A34A)),
                              SizedBox(width: 4),
                              Text(
                                'Tap to open chat',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                              SizedBox(width: 3),
                              Icon(Icons.arrow_forward_ios_rounded, size: 8, color: Color(0xFF16A34A)),
                            ],
                          ),
                        )
                      else if (notif.target != NotificationTarget.none)
                        Row(
                          children: [
                            Text(
                              'Tap to view',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: notif.color,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.arrow_forward_ios_rounded, size: 8, color: notif.color),
                          ],
                        ),
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

  /// Neumorphic Empty State
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x0C000000), offset: Offset(3, 4), blurRadius: 8),
                  BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 6),
                ],
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                color: Color(0xFF64748B),
                size: 36,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No Notifications',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _selectedFilter == 'All'
                  ? "You're all caught up! WhatsApp messages, leads, inventory alerts, and daily summaries will appear here."
                  : 'No notifications in this category.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
