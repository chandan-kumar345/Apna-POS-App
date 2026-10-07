import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../services/super_admin_api_service.dart';
import '../../models/super_admin_subscription_model.dart';

class SuperAdminSubscriptionsScreen extends StatefulWidget {
  final Function(int targetTab, String? entityId)? onNavigate;

  const SuperAdminSubscriptionsScreen({
    super.key,
    this.onNavigate,
  });

  @override
  State<SuperAdminSubscriptionsScreen> createState() => _SuperAdminSubscriptionsScreenState();
}

class _SuperAdminSubscriptionsScreenState extends State<SuperAdminSubscriptionsScreen> {
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
        final filteredSubs = api.subscriptions.where((s) {
          final matchesQuery = q.isEmpty ||
              s.businessName.toLowerCase().contains(q) ||
              s.ownerName.toLowerCase().contains(q) ||
              s.planName.toLowerCase().contains(q) ||
              s.id.toLowerCase().contains(q);

          final matchesStatus = _filterStatus == 'All' ||
              s.subscriptionStatus.label.toLowerCase() == _filterStatus.toLowerCase();

          return matchesQuery && matchesStatus;
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Subscription Management', style: SuperAdminTheme.h1),
                      const SizedBox(height: 4),
                      Text('Active MRR: ₹${api.monthlyRecurringRevenue.toStringAsFixed(0)} • ${api.activeSubscriptions} active billing contracts', style: SuperAdminTheme.body),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => widget.onNavigate?.call(4, null), // Go to Plans tab
                    icon: const Icon(Icons.layers_rounded, size: 16),
                    label: const Text('Manage SaaS Plans'),
                    style: ElevatedButton.styleFrom(backgroundColor: SuperAdminTheme.primary, foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search & Filter Toolbar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: SuperAdminTheme.neumorphicBox(radius: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textPrimary),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: SuperAdminTheme.textMuted),
                          hintText: 'Search by Business, Owner, Plan, or Subscription ID...',
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
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'Active', 'Expiring Soon', 'Trial', 'Expired', 'Suspended'].map((status) {
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

              // Subscription Table (Section 11 Table)
              Container(
                decoration: SuperAdminTheme.neumorphicBox(radius: 14),
                child: filteredSubs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('No subscription contracts found matching filters.')),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 48,
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 60,
                          headingRowColor: const WidgetStatePropertyAll(SuperAdminTheme.bg),
                          columns: const [
                            DataColumn(label: Text('BUSINESS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('OWNER', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('PLAN & CYCLE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('START DATE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('EXPIRY DATE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('AMOUNT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('PAYMENT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                          ],
                          rows: filteredSubs.map((sub) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  InkWell(
                                    onTap: () => widget.onNavigate?.call(2, sub.businessId),
                                    child: Text(
                                      sub.businessName,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: SuperAdminTheme.primary),
                                    ),
                                  ),
                                ),
                                DataCell(Text(sub.ownerName, style: const TextStyle(fontSize: 12.5, color: SuperAdminTheme.textSecondary))),
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(sub.planName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: SuperAdminTheme.textPrimary)),
                                      Text(sub.billingCycle.label, style: const TextStyle(fontSize: 11, color: SuperAdminTheme.textMuted)),
                                    ],
                                  ),
                                ),
                                DataCell(Text(sub.startDate.toString().split(' ').first, style: const TextStyle(fontSize: 11.5))),
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(sub.expiryDate.toString().split(' ').first, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      Text('${sub.remainingDays} days left', style: const TextStyle(fontSize: 10.5, color: SuperAdminTheme.textMuted)),
                                    ],
                                  ),
                                ),
                                DataCell(Text('₹${sub.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: SuperAdminTheme.textPrimary))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: sub.paymentStatus == 'paid' ? SuperAdminTheme.successLight : SuperAdminTheme.warningLight,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      sub.paymentStatus.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: sub.paymentStatus == 'paid' ? SuperAdminTheme.success : SuperAdminTheme.warning,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(color: sub.subscriptionStatus.bg, borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                      sub.subscriptionStatus.label,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: sub.subscriptionStatus.color),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          sub.subscriptionStatus == SubscriptionStatus.active
                                              ? Icons.check_circle_rounded
                                              : Icons.power_settings_new_rounded,
                                          size: 18,
                                          color: sub.subscriptionStatus == SubscriptionStatus.active
                                              ? SuperAdminTheme.success
                                              : SuperAdminTheme.textMuted,
                                        ),
                                        tooltip: sub.subscriptionStatus == SubscriptionStatus.active
                                            ? 'Deactivate Subscription'
                                            : 'Activate Subscription',
                                        onPressed: () {
                                          final isActive = sub.subscriptionStatus == SubscriptionStatus.active;
                                          api.toggleSubscriptionStatus(sub.businessId, !isActive);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                !isActive
                                                    ? 'Subscription ACTIVATED for ${sub.businessName}'
                                                    : 'Subscription DEACTIVATED for ${sub.businessName}',
                                              ),
                                              backgroundColor: !isActive ? SuperAdminTheme.success : SuperAdminTheme.warning,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.more_time_rounded, size: 17, color: SuperAdminTheme.primary),
                                        tooltip: 'Extend 30 Days',
                                        onPressed: () {
                                          api.extendSubscription(sub.businessId, 30);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Added 30 days to ${sub.businessName}'), backgroundColor: SuperAdminTheme.success),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.upgrade_rounded, size: 17, color: SuperAdminTheme.accent),
                                        tooltip: 'Upgrade / Change Plan',
                                        onPressed: () => widget.onNavigate?.call(2, sub.businessId),
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
}
