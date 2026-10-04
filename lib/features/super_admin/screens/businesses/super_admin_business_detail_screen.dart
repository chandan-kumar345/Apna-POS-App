import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../models/super_admin_business_model.dart';
import '../../models/super_admin_user_model.dart';
import '../../models/super_admin_sales_model.dart';
import '../../models/super_admin_audit_log_model.dart';
import '../../services/super_admin_api_service.dart';
import '../../widgets/super_admin_kpi_card.dart';
import '../../widgets/super_admin_confirmation_dialog.dart';

class SuperAdminBusinessDetailScreen extends StatefulWidget {
  final String businessId;
  final VoidCallback onBack;
  final Function(int targetTab, String? entityId)? onNavigate;

  const SuperAdminBusinessDetailScreen({
    super.key,
    required this.businessId,
    required this.onBack,
    this.onNavigate,
  });

  @override
  State<SuperAdminBusinessDetailScreen> createState() => _SuperAdminBusinessDetailScreenState();
}

class _SuperAdminBusinessDetailScreenState extends State<SuperAdminBusinessDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = SuperAdminApiService();

    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final biz = api.businesses.firstWhere(
          (b) => b.id == widget.businessId,
          orElse: () => api.businesses.first,
        );

        final bizUsers = api.users.where((u) => u.businessId == biz.id).toList();
        final bizSales = api.sales.where((s) => s.businessId == biz.id).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Back & Actions Bar
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Back to Businesses'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SuperAdminTheme.textSecondary,
                      side: const BorderSide(color: SuperAdminTheme.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const Spacer(),
                  // Extend Subscription Button
                  ElevatedButton.icon(
                    onPressed: () => _showExtendDialog(context, api, biz),
                    icon: const Icon(Icons.more_time_rounded, size: 16),
                    label: const Text('Extend Subscription'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SuperAdminTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Change Plan Button
                  OutlinedButton.icon(
                    onPressed: () => _showChangePlanDialog(context, api, biz),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('Change Plan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SuperAdminTheme.primary,
                      side: const BorderSide(color: SuperAdminTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Suspend / Activate Button
                  if (biz.status != BusinessStatus.suspended)
                    ElevatedButton.icon(
                      onPressed: () => _confirmSuspend(context, api, biz),
                      icon: const Icon(Icons.block_rounded, size: 16),
                      label: const Text('Suspend Business'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SuperAdminTheme.danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () {
                        api.activateBusiness(biz.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Business access reactivated successfully'), backgroundColor: SuperAdminTheme.success),
                        );
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Activate Business'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SuperAdminTheme.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Business Header Card (Section 10 Header)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: SuperAdminTheme.neumorphicBox(radius: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: SuperAdminTheme.primaryLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: SuperAdminTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.restaurant_rounded, color: SuperAdminTheme.primary, size: 36),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(biz.name, style: SuperAdminTheme.h1),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: biz.status.bg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: biz.status.color.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  biz.status.label.toUpperCase(),
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: biz.status.color),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: SuperAdminTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  biz.planName,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SuperAdminTheme.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Business ID: ${biz.id} • Owner: ${biz.ownerName} (${biz.ownerEmail}) • ${biz.city}, ${biz.state}',
                            style: SuperAdminTheme.caption,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Subscription Expiry: ${biz.expiryDate.toString().split(" ").first} (${biz.expiryDate.difference(DateTime.now()).inDays} days remaining)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: biz.isExpiringSoon ? SuperAdminTheme.warning : SuperAdminTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // KPI Summary Cards Grid (Section 10 Dashboard cards)
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  SuperAdminKpiCard(title: 'Total Users', value: '${biz.usersCount}', icon: Icons.people_rounded),
                  SuperAdminKpiCard(title: 'Active Users', value: '${biz.usersCount}', icon: Icons.person_pin_rounded, iconColor: SuperAdminTheme.success),
                  SuperAdminKpiCard(title: 'Total Revenue', value: '₹${biz.totalRevenue.toStringAsFixed(0)}', icon: Icons.payments_rounded, iconColor: SuperAdminTheme.primary),
                  SuperAdminKpiCard(title: 'Subscription Rev', value: '₹${biz.subscriptionRevenue.toStringAsFixed(0)}', icon: Icons.card_membership_rounded, iconColor: SuperAdminTheme.accent),
                  SuperAdminKpiCard(title: 'Orders Processed', value: '3,840', icon: Icons.receipt_long_rounded, iconColor: SuperAdminTheme.info),
                  SuperAdminKpiCard(title: 'Branches', value: '${biz.branchesCount}', icon: Icons.store_rounded),
                  SuperAdminKpiCard(title: 'Team Members', value: '${biz.teamMembersCount}', icon: Icons.group_work_rounded, iconColor: SuperAdminTheme.warning),
                ],
              ),
              const SizedBox(height: 24),

              // 9 Complete Tabs (Section 10 Tabs)
              Container(
                decoration: SuperAdminTheme.neumorphicBox(radius: 14),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: SuperAdminTheme.primary,
                      unselectedLabelColor: SuperAdminTheme.textSecondary,
                      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      indicatorColor: SuperAdminTheme.primary,
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Users'),
                        Tab(text: 'Teams'),
                        Tab(text: 'Subscription'),
                        Tab(text: 'Payments'),
                        Tab(text: 'Sales'),
                        Tab(text: 'Modules'),
                        Tab(text: 'Activity'),
                        Tab(text: 'Reports'),
                      ],
                    ),
                    const Divider(height: 1, color: SuperAdminTheme.border),
                    SizedBox(
                      height: 480,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // 1. Overview Tab
                          _buildOverviewTab(biz),
                          // 2. Users Tab
                          _buildUsersTab(bizUsers),
                          // 3. Teams Tab
                          _buildTeamsTab(biz),
                          // 4. Subscription Tab
                          _buildSubscriptionTab(biz, api),
                          // 5. Payments Tab
                          _buildPaymentsTab(bizSales),
                          // 6. Sales Tab
                          _buildSalesTab(biz, bizSales),
                          // 7. Modules Tab
                          _buildModulesTab(biz, api),
                          // 8. Activity Tab
                          _buildActivityTab(biz, api),
                          // 9. Reports Tab
                          _buildReportsTab(biz),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- TAB IMPLEMENTATIONS ---
  Widget _buildOverviewTab(PlatformBusiness biz) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Contact & Location', style: SuperAdminTheme.h3),
                const SizedBox(height: 12),
                _buildField('Owner Name', biz.ownerName),
                _buildField('Email', biz.ownerEmail),
                _buildField('Phone', biz.ownerPhone),
                _buildField('Address', biz.address),
                _buildField('City / State', '${biz.city}, ${biz.state}'),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Plan & Platform Settings', style: SuperAdminTheme.h3),
                const SizedBox(height: 12),
                _buildField('Category', biz.category),
                _buildField('Current Plan', biz.planName),
                _buildField('Onboarding Date', biz.createdAt.toString().split(' ').first),
                _buildField('Total Renewals', '${biz.renewalsCount} times'),
                _buildField('Upgrades', '${biz.upgradesCount} upgrades'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab(List<PlatformUser> users) {
    if (users.isEmpty) {
      return const Center(child: Text('No users mapped under this business'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: users.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: SuperAdminTheme.border),
      itemBuilder: (context, idx) {
        final u = users[idx];
        return ListTile(
          leading: CircleAvatar(backgroundColor: SuperAdminTheme.primaryLight, child: Text(u.name[0])),
          title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          subtitle: Text('${u.email} • ${u.phone} • Role: ${u.role}', style: const TextStyle(fontSize: 12)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: SuperAdminTheme.successLight, borderRadius: BorderRadius.circular(6)),
            child: Text(u.status.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: SuperAdminTheme.success)),
          ),
        );
      },
    );
  }

  Widget _buildTeamsTab(PlatformBusiness biz) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Team Subscription Status', style: SuperAdminTheme.h3),
              Text('Separate Team Billing active', style: TextStyle(fontSize: 12, color: SuperAdminTheme.primary, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          _buildField('Team Name', '${biz.name} Core Staff Team'),
          _buildField('Total Team Members', '${biz.teamMembersCount} active staff'),
          _buildField('Team Subscription Status', 'Active (Paid monthly ₹799)'),
          _buildField('Next Renewal', biz.expiryDate.toString().split(' ').first),
        ],
      ),
    );
  }

  Widget _buildSubscriptionTab(PlatformBusiness biz, SuperAdminApiService api) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Subscription Lifecycle', style: SuperAdminTheme.h3),
          const SizedBox(height: 16),
          _buildField('Current Plan', biz.planName),
          _buildField('Status', biz.status.label),
          _buildField('Start Date', biz.startDate.toString().split(' ').first),
          _buildField('Expiry Date', biz.expiryDate.toString().split(' ').first),
          _buildField('Days Remaining', '${biz.expiryDate.difference(DateTime.now()).inDays} days'),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showExtendDialog(context, api, biz),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add 30 Subscription Days'),
                style: ElevatedButton.styleFrom(backgroundColor: SuperAdminTheme.primary, foregroundColor: Colors.white),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _showChangePlanDialog(context, api, biz),
                icon: const Icon(Icons.upgrade_rounded, size: 16),
                label: const Text('Upgrade Plan'),
                style: OutlinedButton.styleFrom(foregroundColor: SuperAdminTheme.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab(List<PlatformSaleRecord> sales) {
    if (sales.isEmpty) {
      return const Center(child: Text('No payment transactions recorded for this business.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: sales.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: SuperAdminTheme.border),
      itemBuilder: (context, idx) {
        final s = sales[idx];
        return ListTile(
          leading: const Icon(Icons.receipt_long_rounded, color: SuperAdminTheme.primary),
          title: Text('${s.invoiceNumber} • ₹${s.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          subtitle: Text('Txn: ${s.transactionId} • Method: ${s.method.label} • ${s.date.toString().split(" ").first}', style: const TextStyle(fontSize: 12)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: s.status.bg, borderRadius: BorderRadius.circular(6)),
            child: Text(s.status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: s.status.color)),
          ),
        );
      },
    );
  }

  Widget _buildSalesTab(PlatformBusiness biz, List<PlatformSaleRecord> sales) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sales & Renewal History', style: SuperAdminTheme.h3),
          const SizedBox(height: 16),
          _buildField('Total Paid Lifetime', '₹${biz.totalRevenue.toStringAsFixed(0)}'),
          _buildField('Subscription Revenue', '₹${biz.subscriptionRevenue.toStringAsFixed(0)}'),
          _buildField('Pending Outstanding', '₹${biz.pendingAmount.toStringAsFixed(0)}'),
          _buildField('Renewal Count', '${biz.renewalsCount} successful renewals'),
        ],
      ),
    );
  }

  Widget _buildModulesTab(PlatformBusiness biz, SuperAdminApiService api) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: api.modules.map((m) {
        final isEnabled = biz.enabledModules[m.key] ?? false;
        return SwitchListTile(
          title: Text(m.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          subtitle: Text(m.description, style: const TextStyle(fontSize: 12)),
          value: isEnabled,
          activeColor: SuperAdminTheme.primary,
          onChanged: (val) {
            final updatedMap = Map<String, bool>.from(biz.enabledModules)..[m.key] = val;
            final idx = api.businesses.indexWhere((b) => b.id == biz.id);
            if (idx != -1) {
              // Trigger update
              api.logAudit(
                action: 'Toggled Business Module',
                targetType: AuditTargetType.module,
                targetName: '${biz.name} - ${m.name}',
                targetId: m.key,
                details: 'Changed status to ${val ? "Enabled" : "Disabled"}',
              );
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildActivityTab(PlatformBusiness biz, SuperAdminApiService api) {
    final bizLogs = api.auditLogs.where((l) => l.targetId == biz.id || l.targetName.contains(biz.name)).toList();
    if (bizLogs.isEmpty) {
      return const Center(child: Text('No recorded administrative changes for this business.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: bizLogs.length,
      itemBuilder: (context, idx) {
        final log = bizLogs[idx];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.history_rounded, color: SuperAdminTheme.primary),
          title: Text(log.action, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          subtitle: Text('${log.details} • Admin: ${log.adminName}', style: const TextStyle(fontSize: 11.5)),
          trailing: Text(log.timestamp.toString().split('.').first, style: const TextStyle(fontSize: 11, color: SuperAdminTheme.textMuted)),
        );
      },
    );
  }

  Widget _buildReportsTab(PlatformBusiness biz) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Analytical Reports & Exports', style: SuperAdminTheme.h3),
          const SizedBox(height: 16),
          const Text('Download complete transaction ledger, user sessions, and GST tax invoice statements for this business.', style: SuperAdminTheme.body),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exported Business Ledger as CSV')));
                },
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Export CSV Ledger'),
                style: ElevatedButton.styleFrom(backgroundColor: SuperAdminTheme.primary, foregroundColor: Colors.white),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generated PDF Audit Statement')));
                },
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text('Download PDF Statement'),
                style: OutlinedButton.styleFrom(foregroundColor: SuperAdminTheme.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
        ],
      ),
    );
  }

  void _showExtendDialog(BuildContext context, SuperAdminApiService api, PlatformBusiness biz) {
    int selectedDays = 30;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Extend Subscription for ${biz.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select additional duration to append to current expiry date:'),
              const SizedBox(height: 14),
              DropdownButton<int>(
                value: selectedDays,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 7, child: Text('7 Days (Trial Grace)')),
                  DropdownMenuItem(value: 15, child: Text('15 Days (Half Month)')),
                  DropdownMenuItem(value: 30, child: Text('30 Days (1 Month)')),
                  DropdownMenuItem(value: 90, child: Text('90 Days (1 Quarter)')),
                  DropdownMenuItem(value: 365, child: Text('365 Days (1 Full Year)')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedDays = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                api.extendSubscription(biz.id, selectedDays, note: 'Super Admin manual extension');
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added $selectedDays days to ${biz.name}'), backgroundColor: SuperAdminTheme.success),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: SuperAdminTheme.primary, foregroundColor: Colors.white),
              child: const Text('Apply Extension'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePlanDialog(BuildContext context, SuperAdminApiService api, PlatformBusiness biz) {
    String selectedPlan = api.plans.first.id;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Change Subscription Plan for ${biz.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select new SaaS plan:'),
              const SizedBox(height: 14),
              DropdownButton<String>(
                value: selectedPlan,
                isExpanded: true,
                items: api.plans.map((p) {
                  return DropdownMenuItem(value: p.id, child: Text('${p.name} (₹${p.monthlyPrice}/mo)'));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedPlan = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                api.changeBusinessPlan(biz.id, selectedPlan);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Plan updated successfully'), backgroundColor: SuperAdminTheme.success),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: SuperAdminTheme.primary, foregroundColor: Colors.white),
              child: const Text('Confirm Plan Change'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSuspend(BuildContext context, SuperAdminApiService api, PlatformBusiness biz) {
    SuperAdminConfirmationDialog.show(
      context: context,
      title: 'Suspend Business Platform Access?',
      message: 'Are you sure you want to suspend ${biz.name}? All POS terminals, staff tablets, and online orders will be immediately blocked.',
      confirmLabel: 'Suspend Business',
      onConfirmWithReason: (reason) async {
        api.suspendBusiness(biz.id, reason);
      },
    );
  }
}
