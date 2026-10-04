import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../services/super_admin_api_service.dart';
import '../../models/super_admin_notification_model.dart';

class SuperAdminNotificationsScreen extends StatefulWidget {
  const SuperAdminNotificationsScreen({super.key});

  @override
  State<SuperAdminNotificationsScreen> createState() => _SuperAdminNotificationsScreenState();
}

class _SuperAdminNotificationsScreenState extends State<SuperAdminNotificationsScreen> {
  String _searchQuery = '';
  String _selectedTypeFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final api = SuperAdminApiService();

    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final notifications = api.notifications;

        final filtered = notifications.where((n) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch = query.isEmpty ||
              n.title.toLowerCase().contains(query) ||
              n.message.toLowerCase().contains(query) ||
              n.targetAudience.label.toLowerCase().contains(query);

          final matchesType = _selectedTypeFilter == 'All' || n.type.label == _selectedTypeFilter;

          return matchesSearch && matchesType;
        }).toList();

        final totalSent = notifications.length;
        final totalRecipients = notifications.fold(0, (acc, n) => acc + n.totalRecipients);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(context, api),
              const SizedBox(height: 20),

              // KPI Row
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Total Broadcasts',
                      value: '$totalSent',
                      icon: Icons.campaign_rounded,
                      color: SuperAdminTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Total Deliveries',
                      value: '$totalRecipients',
                      icon: Icons.mark_email_read_rounded,
                      color: SuperAdminTheme.successGreen,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Avg. Open Rate',
                      value: '84.2%',
                      icon: Icons.insights_rounded,
                      color: SuperAdminTheme.purpleAccent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Active Platform Channels',
                      value: 'In-App + Push',
                      icon: Icons.cell_tower_rounded,
                      color: SuperAdminTheme.accentCyan,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Search & Filter
              Container(
                padding: const EdgeInsets.all(16),
                decoration: SuperAdminTheme.cardDecoration(context),
                child: Row(
                  children: [
                    // Search box
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: SuperAdminTheme.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: SuperAdminTheme.border),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Search sent notifications by title or audience...',
                            hintStyle: TextStyle(fontSize: 13, color: SuperAdminTheme.textMuted),
                            prefixIcon: Icon(Icons.search_rounded, size: 20, color: SuperAdminTheme.textSecondary),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Type Filter Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: SuperAdminTheme.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: SuperAdminTheme.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTypeFilter,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: SuperAdminTheme.textSecondary),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary),
                          items: [
                            'All',
                            ...PlatformNotificationType.values.map((t) => t.label),
                          ].map((t) => DropdownMenuItem(value: t, child: Text('Type: $t'))).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedTypeFilter = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Notifications History Table
              Container(
                decoration: SuperAdminTheme.cardDecoration(context),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      color: SuperAdminTheme.background,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: const Row(
                        children: [
                          Expanded(flex: 4, child: Text('Broadcast Title & Message', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textSecondary))),
                          Expanded(flex: 2, child: Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textSecondary))),
                          Expanded(flex: 2, child: Text('Target Audience', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textSecondary))),
                          Expanded(flex: 2, child: Text('Sent Date & Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textSecondary))),
                          Expanded(flex: 2, child: Text('Read Rate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textSecondary))),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: SuperAdminTheme.border),

                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.notifications_off_outlined, size: 48, color: SuperAdminTheme.textMuted),
                              const SizedBox(height: 12),
                              const Text('No platform notifications found', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary)),
                            ],
                          ),
                        ),
                      )
                    else
                      ...filtered.map((n) => _buildNotificationRow(context, n)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, SuperAdminApiService api) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SuperAdminTheme.cardDecoration(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SuperAdminTheme.primaryBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.campaign_rounded, color: SuperAdminTheme.primaryBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Platform Broadcast & Notification Desk',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: SuperAdminTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Broadcast instant alerts, maintenance schedules, subscription renewal nudges, and release notes to merchant devices.',
                  style: TextStyle(fontSize: 13, color: SuperAdminTheme.textSecondary),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _showComposeNotificationDialog(context, api),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Send Broadcast Notification'),
            style: ElevatedButton.styleFrom(
              backgroundColor: SuperAdminTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationRow(BuildContext context, PlatformBroadcastNotification n) {
    final readPercentage = n.totalRecipients > 0 ? (n.readCount / n.totalRecipients) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SuperAdminTheme.border, width: 0.8)),
      ),
      child: Row(
        children: [
          // Title & Message
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  n.message,
                  style: TextStyle(fontSize: 12, color: SuperAdminTheme.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Type
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: n.type.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(n.type.icon, size: 14, color: n.type.color),
                    const SizedBox(width: 4),
                    Text(
                      n.type.label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: n.type.color),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Audience
          Expanded(
            flex: 2,
            child: Text(
              n.targetAudience.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary),
            ),
          ),

          // Date & Admin
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.sentAt.toString().split('.').first,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary),
                ),
                Text(
                  'by ${n.sentBy}',
                  style: TextStyle(fontSize: 11, color: SuperAdminTheme.textSecondary),
                ),
              ],
            ),
          ),

          // Read Rate
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${n.readCount} / ${n.totalRecipients}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                    ),
                    Text(
                      '${(readPercentage * 100).toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SuperAdminTheme.successGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: readPercentage,
                    minHeight: 6,
                    backgroundColor: SuperAdminTheme.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(SuperAdminTheme.successGreen),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SuperAdminTheme.cardDecoration(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SuperAdminTheme.textSecondary)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: SuperAdminTheme.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  void _showComposeNotificationDialog(BuildContext context, SuperAdminApiService api) {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    PlatformNotificationType selectedType = PlatformNotificationType.systemAnnouncement;
    NotificationTarget selectedTarget = NotificationTarget.allBusinesses;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: SuperAdminTheme.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SuperAdminTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.send_rounded, color: SuperAdminTheme.primaryBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Compose Broadcast Notification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
                      Text('Direct instant notification to merchant POS terminals', style: TextStyle(fontSize: 12, color: SuperAdminTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      const Text('Notification Title:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleController,
                        style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'e.g., Scheduled Server Maintenance or Flash Feature Release',
                          hintStyle: TextStyle(fontSize: 12, color: SuperAdminTheme.textMuted),
                          filled: true,
                          fillColor: SuperAdminTheme.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: SuperAdminTheme.border)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Notification Type Dropdown
                      const Text('Notification Category:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: SuperAdminTheme.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: SuperAdminTheme.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<PlatformNotificationType>(
                            value: selectedType,
                            isExpanded: true,
                            items: PlatformNotificationType.values.map((t) {
                              return DropdownMenuItem(
                                value: t,
                                child: Row(
                                  children: [
                                    Icon(t.icon, size: 16, color: t.color),
                                    const SizedBox(width: 8),
                                    Text(t.label, style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textPrimary)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedType = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Target Audience Dropdown
                      const Text('Target Audience:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: SuperAdminTheme.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: SuperAdminTheme.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<NotificationTarget>(
                            value: selectedTarget,
                            isExpanded: true,
                            items: NotificationTarget.values.map((t) {
                              return DropdownMenuItem(
                                value: t,
                                child: Text(t.label, style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textPrimary)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedTarget = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Message Body
                      const Text('Broadcast Message:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: messageController,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Enter complete announcement message that will appear on merchant screens...',
                          hintStyle: TextStyle(fontSize: 12, color: SuperAdminTheme.textMuted),
                          filled: true,
                          fillColor: SuperAdminTheme.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: SuperAdminTheme.border)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: SuperAdminTheme.textSecondary)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final msg = messageController.text.trim();
                    if (title.isNotEmpty && msg.isNotEmpty) {
                      final newNotif = PlatformBroadcastNotification(
                        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
                        title: title,
                        message: msg,
                        type: selectedType,
                        targetAudience: selectedTarget,
                        sentAt: DateTime.now(),
                        sentBy: 'Super Admin',
                        totalRecipients: api.businesses.length * 15,
                        readCount: 0,
                      );
                      api.broadcastNotification(newNotif);
                      Navigator.pop(dialogCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notification broadcast dispatched to all matching merchants!'),
                          backgroundColor: SuperAdminTheme.successGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Broadcast Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SuperAdminTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
