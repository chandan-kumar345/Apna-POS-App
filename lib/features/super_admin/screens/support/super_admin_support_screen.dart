import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../services/super_admin_api_service.dart';
import '../../models/super_admin_support_model.dart';

class SuperAdminSupportScreen extends StatefulWidget {
  const SuperAdminSupportScreen({super.key});

  @override
  State<SuperAdminSupportScreen> createState() => _SuperAdminSupportScreenState();
}

class _SuperAdminSupportScreenState extends State<SuperAdminSupportScreen> {
  String _selectedStatus = 'All';
  String _selectedPriority = 'All';
  String _searchQuery = '';
  SupportTicket? _selectedTicket;
  final TextEditingController _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = SuperAdminApiService();

    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final tickets = api.tickets;
        final openCount = tickets.where((t) => t.status == TicketStatus.open).length;
        final inProgressCount = tickets.where((t) => t.status == TicketStatus.inProgress).length;
        final criticalCount = tickets.where((t) => t.priority == TicketPriority.critical).length;
        final waitingCount = tickets.where((t) => t.status == TicketStatus.waitingForCustomer).length;
        final resolvedCount = tickets.where((t) => t.status == TicketStatus.resolved || t.status == TicketStatus.closed).length;

        final filtered = tickets.where((t) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch = query.isEmpty ||
              t.ticketCode.toLowerCase().contains(query) ||
              t.subject.toLowerCase().contains(query) ||
              t.businessName.toLowerCase().contains(query) ||
              t.userName.toLowerCase().contains(query);

          final matchesStatus = _selectedStatus == 'All' || t.status.label == _selectedStatus;
          final matchesPriority = _selectedPriority == 'All' || t.priority.label == _selectedPriority;

          return matchesSearch && matchesStatus && matchesPriority;
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(context),
              const SizedBox(height: 20),

              // KPI Metric Cards
              Row(
                children: [
                  Expanded(
                    child: _buildTicketKpi(
                      title: 'Open Tickets',
                      count: openCount,
                      color: SuperAdminTheme.primaryBlue,
                      icon: Icons.mark_email_unread_rounded,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTicketKpi(
                      title: 'In Progress',
                      count: inProgressCount,
                      color: const Color(0xFF6366F1),
                      icon: Icons.pending_actions_rounded,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTicketKpi(
                      title: 'Critical Priority',
                      count: criticalCount,
                      color: SuperAdminTheme.errorRed,
                      icon: Icons.warning_amber_rounded,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTicketKpi(
                      title: 'Waiting for Customer',
                      count: waitingCount,
                      color: SuperAdminTheme.warningAmber,
                      icon: Icons.hourglass_top_rounded,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTicketKpi(
                      title: 'Resolved',
                      count: resolvedCount,
                      color: SuperAdminTheme.successGreen,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Filter Controls
              _buildFilterBar(context),
              const SizedBox(height: 20),

              // Main Layout: Ticket List & Optional Detail Split
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 960;

                  if (isDesktop && _selectedTicket != null) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 4,
                          child: _buildTicketList(context, filtered),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 6,
                          child: _buildTicketDetailPanel(context, _selectedTicket!, api),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      _buildTicketList(context, filtered),
                      if (_selectedTicket != null) ...[
                        const SizedBox(height: 24),
                        _buildTicketDetailPanel(context, _selectedTicket!, api),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
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
            child: const Icon(Icons.support_agent_rounded, color: SuperAdminTheme.primaryBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Support Ticket Desk',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: SuperAdminTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage customer inquiries, printer/hardware issues, billing inquiries, and feature requests across all businesses.',
                  style: TextStyle(fontSize: 13, color: SuperAdminTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketKpi({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
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
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SuperAdminTheme.textSecondary)),
              const SizedBox(height: 2),
              Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: SuperAdminTheme.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final statusList = ['All', 'Open', 'In Progress', 'Waiting Customer', 'Resolved', 'Closed'];
    final priorityList = ['All', 'Low', 'Medium', 'High', 'Critical'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SuperAdminTheme.cardDecoration(context),
      child: Row(
        children: [
          // Search
          Expanded(
            flex: 3,
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
                  hintText: 'Search by ticket code, business, or subject...',
                  hintStyle: TextStyle(fontSize: 13, color: SuperAdminTheme.textMuted),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: SuperAdminTheme.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Status Filter
          _buildDropdownFilter(
            label: 'Status',
            value: _selectedStatus,
            items: statusList,
            onChanged: (v) => setState(() => _selectedStatus = v!),
          ),
          const SizedBox(width: 12),

          // Priority Filter
          _buildDropdownFilter(
            label: 'Priority',
            value: _selectedPriority,
            items: priorityList,
            onChanged: (v) => setState(() => _selectedPriority = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: SuperAdminTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SuperAdminTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: SuperAdminTheme.textSecondary),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text('$label: $i'))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTicketList(BuildContext context, List<SupportTicket> list) {
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: SuperAdminTheme.cardDecoration(context),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_rounded, size: 48, color: SuperAdminTheme.textMuted),
              const SizedBox(height: 12),
              const Text('No support tickets match the current filter', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: SuperAdminTheme.cardDecoration(context),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: SuperAdminTheme.border),
        itemBuilder: (context, idx) {
          final t = list[idx];
          final isSelected = _selectedTicket?.id == t.id;

          return InkWell(
            onTap: () {
              setState(() {
                _selectedTicket = t;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              color: isSelected ? SuperAdminTheme.primaryBlue.withOpacity(0.06) : Colors.transparent,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: SuperAdminTheme.background,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: SuperAdminTheme.border),
                            ),
                            child: Text(
                              t.ticketCode,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SuperAdminTheme.primaryBlue),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildPriorityBadge(t.priority),
                        ],
                      ),
                      _buildStatusBadge(t.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.subject,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 14, color: SuperAdminTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        t.businessName,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SuperAdminTheme.textSecondary),
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(t.createdAt),
                        style: TextStyle(fontSize: 11, color: SuperAdminTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTicketDetailPanel(
    BuildContext context,
    SupportTicket ticket,
    SuperAdminApiService api,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: SuperAdminTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${ticket.ticketCode} • ${ticket.category}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.primaryBlue),
                        ),
                        const SizedBox(width: 8),
                        _buildPriorityBadge(ticket.priority),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ticket.subject,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                    ),
                  ],
                ),
              ),

              // Status Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: ticket.status.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ticket.status.color.withOpacity(0.4)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<TicketStatus>(
                    value: ticket.status,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: ticket.status.color),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ticket.status.color),
                    items: TicketStatus.values.map((s) {
                      return DropdownMenuItem(value: s, child: Text(s.label));
                    }).toList(),
                    onChanged: (newStatus) {
                      if (newStatus != null) {
                        api.updateTicketStatus(ticket.id, newStatus);
                        setState(() {
                          _selectedTicket = api.tickets.firstWhere((t) => t.id == ticket.id);
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Business & Customer Info Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SuperAdminTheme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SuperAdminTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 18, color: SuperAdminTheme.primaryBlue),
                const SizedBox(width: 8),
                Text(
                  '${ticket.userName} (${ticket.userEmail})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary),
                ),
                const Spacer(),
                const Icon(Icons.business_center_outlined, size: 18, color: SuperAdminTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  ticket.businessName,
                  style: TextStyle(fontSize: 12, color: SuperAdminTheme.textSecondary),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, color: SuperAdminTheme.border),
          const SizedBox(height: 16),

          // Conversation Thread
          const Text(
            'Ticket Thread & History',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
          ),
          const SizedBox(height: 12),

          // Initial message
          _buildMessageBubble(
            sender: ticket.userName,
            role: 'Customer',
            message: ticket.initialMessage,
            time: ticket.createdAt,
            isAdmin: false,
          ),

          // Replies
          ...ticket.replies.map((rep) {
            return _buildMessageBubble(
              sender: rep.senderName,
              role: rep.senderRole,
              message: rep.message,
              time: rep.sentAt,
              isAdmin: rep.isAdmin,
            );
          }),

          const SizedBox(height: 20),
          const Divider(height: 1, color: SuperAdminTheme.border),
          const SizedBox(height: 16),

          // Reply Input Box
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: SuperAdminTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SuperAdminTheme.border),
                  ),
                  child: TextField(
                    controller: _replyController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Type your official support response to customer...',
                      hintStyle: TextStyle(fontSize: 13, color: SuperAdminTheme.textMuted),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  final text = _replyController.text.trim();
                  if (text.isNotEmpty) {
                    api.replyTicket(ticket.id, text);
                    _replyController.clear();
                    setState(() {
                      _selectedTicket = api.tickets.firstWhere((t) => t.id == ticket.id);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reply sent successfully to customer!'),
                        backgroundColor: SuperAdminTheme.successGreen,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Send Reply'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SuperAdminTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String sender,
    required String role,
    required String message,
    required DateTime time,
    required bool isAdmin,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAdmin ? SuperAdminTheme.primaryBlue.withOpacity(0.06) : SuperAdminTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAdmin ? SuperAdminTheme.primaryBlue.withOpacity(0.2) : SuperAdminTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    sender,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isAdmin ? SuperAdminTheme.primaryBlue : SuperAdminTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isAdmin ? SuperAdminTheme.primaryBlue.withOpacity(0.1) : SuperAdminTheme.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      role,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isAdmin ? SuperAdminTheme.primaryBlue : SuperAdminTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                _formatTime(time),
                style: TextStyle(fontSize: 11, color: SuperAdminTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textPrimary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(TicketPriority p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: p.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: p.color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(
            p.label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: p.color),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(TicketStatus s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        s.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: s.color),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
