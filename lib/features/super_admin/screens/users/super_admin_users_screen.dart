import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../models/super_admin_user_model.dart';
import '../../services/super_admin_api_service.dart';
import '../../widgets/super_admin_confirmation_dialog.dart';

class SuperAdminUsersScreen extends StatefulWidget {
  final Function(String userId)? onSelectUser;
  final Function(int targetTab, String? entityId)? onNavigate;

  const SuperAdminUsersScreen({
    super.key,
    this.onSelectUser,
    this.onNavigate,
  });

  @override
  State<SuperAdminUsersScreen> createState() => _SuperAdminUsersScreenState();
}

class _SuperAdminUsersScreenState extends State<SuperAdminUsersScreen> {
  final _searchController = TextEditingController();
  String _filterStatus = 'All';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = SuperAdminApiService();

    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final q = _searchQuery.toLowerCase().trim();
        final filteredUsers = api.users.where((u) {
          final matchesQuery = q.isEmpty ||
              u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q) ||
              u.phone.contains(q) ||
              u.businessName.toLowerCase().contains(q) ||
              u.id.toLowerCase().contains(q);

          final matchesStatus = _filterStatus == 'All' ||
              u.status.toLowerCase() == _filterStatus.toLowerCase();

          return matchesQuery && matchesStatus;
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Action Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Users Management', style: SuperAdminTheme.h1),
                      const SizedBox(height: 4),
                      Text('Total ${api.totalUsers} registered users across all client businesses', style: SuperAdminTheme.body),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Filter Controls & Search Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: SuperAdminTheme.neumorphicBox(radius: 12),
                child: Row(
                  children: [
                    // Search Box
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textPrimary),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: SuperAdminTheme.textMuted),
                          hintText: 'Search by Name, Email, Phone, Business, or ID...',
                          filled: true,
                          fillColor: SuperAdminTheme.bg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: SuperAdminTheme.border)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          isDense: true,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Status Filter Tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'Active', 'Trial', 'Paid', 'Suspended', 'Expired'].map((status) {
                          final isSelected = _filterStatus == status;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(status),
                              selected: isSelected,
                              selectedColor: SuperAdminTheme.primaryLight,
                              backgroundColor: SuperAdminTheme.bg,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? SuperAdminTheme.primary : SuperAdminTheme.textSecondary,
                              ),
                              side: BorderSide(
                                color: isSelected ? SuperAdminTheme.primary.withValues(alpha: 0.3) : SuperAdminTheme.border,
                              ),
                              onSelected: (_) => setState(() => _filterStatus = status),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Users Table (Section 7: Users Table)
              Container(
                decoration: SuperAdminTheme.neumorphicBox(radius: 14),
                child: filteredUsers.isEmpty
                    ? _buildEmptyState()
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 48,
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 56,
                          headingRowColor: const WidgetStatePropertyAll(SuperAdminTheme.bg),
                          columns: const [
                            DataColumn(label: Text('USER ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('NAME & EMAIL', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('PHONE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('BUSINESS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('ROLE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('PLAN', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('CREATED', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                          ],
                          rows: filteredUsers.map((user) {
                            return DataRow(
                              cells: [
                                DataCell(Text(user.id, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: SuperAdminTheme.primary))),
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(user.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: SuperAdminTheme.textPrimary)),
                                      Text(user.email, style: const TextStyle(fontSize: 11, color: SuperAdminTheme.textMuted)),
                                    ],
                                  ),
                                ),
                                DataCell(Text(user.phone, style: const TextStyle(fontSize: 12, color: SuperAdminTheme.textSecondary))),
                                DataCell(
                                  InkWell(
                                    onTap: () => widget.onNavigate?.call(2, user.businessId),
                                    child: Text(
                                      user.businessName,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SuperAdminTheme.primary, decoration: TextDecoration.underline),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                    decoration: BoxDecoration(color: SuperAdminTheme.bg, borderRadius: BorderRadius.circular(6)),
                                    child: Text(user.role, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SuperAdminTheme.textSecondary)),
                                  ),
                                ),
                                DataCell(_buildStatusBadge(user.status)),
                                DataCell(Text(user.subscriptionPlan, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary))),
                                DataCell(Text(user.createdAt.toString().split(' ').first, style: const TextStyle(fontSize: 11.5, color: SuperAdminTheme.textMuted))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility_rounded, size: 17, color: SuperAdminTheme.primary),
                                        tooltip: 'View Profile',
                                        onPressed: () => widget.onSelectUser?.call(user.id),
                                      ),
                                      if (user.status != 'suspended')
                                        IconButton(
                                          icon: const Icon(Icons.block_rounded, size: 17, color: SuperAdminTheme.danger),
                                          tooltip: 'Suspend Account',
                                          onPressed: () => _confirmSuspend(context, api, user),
                                        )
                                      else
                                        IconButton(
                                          icon: const Icon(Icons.check_circle_rounded, size: 17, color: SuperAdminTheme.success),
                                          tooltip: 'Activate Account',
                                          onPressed: () => api.activateUser(user.id),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.lock_reset_rounded, size: 17, color: SuperAdminTheme.textSecondary),
                                        tooltip: 'Reset Password',
                                        onPressed: () {
                                          api.resetUserPassword(user.id);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Password reset dispatched for ${user.email}')),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    Color bg;
    switch (status.toLowerCase()) {
      case 'active':
      case 'paid':
        color = SuperAdminTheme.success;
        bg = SuperAdminTheme.successLight;
        break;
      case 'trial':
        color = SuperAdminTheme.info;
        bg = SuperAdminTheme.infoLight;
        break;
      case 'suspended':
        color = SuperAdminTheme.danger;
        bg = SuperAdminTheme.dangerLight;
        break;
      default:
        color = SuperAdminTheme.warning;
        bg = SuperAdminTheme.warningLight;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.person_search_rounded, size: 40, color: SuperAdminTheme.textMuted),
            SizedBox(height: 10),
            Text('No users found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
            SizedBox(height: 4),
            Text('Try adjusting your search criteria or status filters.', style: TextStyle(fontSize: 12, color: SuperAdminTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  void _confirmSuspend(BuildContext context, SuperAdminApiService api, PlatformUser user) {
    SuperAdminConfirmationDialog.show(
      context: context,
      title: 'Suspend User Account?',
      message: 'Are you sure you want to suspend access for ${user.name}? This will log them out of all active sessions.',
      confirmLabel: 'Suspend User',
      onConfirmWithReason: (reason) async {
        api.suspendUser(user.id, reason);
      },
    );
  }
}
