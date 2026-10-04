import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../models/super_admin_business_model.dart';
import '../../services/super_admin_api_service.dart';
import '../../widgets/super_admin_confirmation_dialog.dart';

class SuperAdminBusinessesScreen extends StatefulWidget {
  final Function(String businessId)? onSelectBusiness;
  final Function(int targetTab, String? entityId)? onNavigate;

  const SuperAdminBusinessesScreen({
    super.key,
    this.onSelectBusiness,
    this.onNavigate,
  });

  @override
  State<SuperAdminBusinessesScreen> createState() => _SuperAdminBusinessesScreenState();
}

class _SuperAdminBusinessesScreenState extends State<SuperAdminBusinessesScreen> {
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
        final filteredBusinesses = api.businesses.where((b) {
          final matchesQuery = q.isEmpty ||
              b.name.toLowerCase().contains(q) ||
              b.ownerName.toLowerCase().contains(q) ||
              b.city.toLowerCase().contains(q) ||
              b.category.toLowerCase().contains(q) ||
              b.id.toLowerCase().contains(q);

          final matchesStatus = _filterStatus == 'All' ||
              b.status.label.toLowerCase() == _filterStatus.toLowerCase();

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
                      const Text('Businesses Management', style: SuperAdminTheme.h1),
                      const SizedBox(height: 4),
                      Text('Managing ${api.totalBusinesses} restaurants, cafes & franchises on Apna POSS platform', style: SuperAdminTheme.body),
                    ],
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
                          hintText: 'Search by Business Name, Owner, City, Category, or ID...',
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
                        children: ['All', 'Active', 'Trial', 'Suspended', 'Expired'].map((status) {
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

              // Businesses Table (Section 9: Business Management Table)
              Container(
                decoration: SuperAdminTheme.neumorphicBox(radius: 14),
                child: filteredBusinesses.isEmpty
                    ? _buildEmptyState()
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 48,
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 60,
                          headingRowColor: const WidgetStatePropertyAll(SuperAdminTheme.bg),
                          columns: const [
                            DataColumn(label: Text('BUSINESS & ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('OWNER', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('CATEGORY', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('PLAN', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('USERS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('TOTAL REVENUE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('EXPIRY', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                          ],
                          rows: filteredBusinesses.map((biz) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  InkWell(
                                    onTap: () => widget.onSelectBusiness?.call(biz.id),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(biz.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: SuperAdminTheme.primary)),
                                        Text('${biz.id} • ${biz.city}', style: const TextStyle(fontSize: 11, color: SuperAdminTheme.textMuted)),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(biz.ownerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: SuperAdminTheme.textPrimary)),
                                      Text(biz.ownerEmail, style: const TextStyle(fontSize: 11, color: SuperAdminTheme.textMuted)),
                                    ],
                                  ),
                                ),
                                DataCell(Text(biz.category, style: const TextStyle(fontSize: 12, color: SuperAdminTheme.textSecondary))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(color: SuperAdminTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                                    child: Text(biz.planName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SuperAdminTheme.primary)),
                                  ),
                                ),
                                DataCell(Text('${biz.usersCount} users', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(color: biz.status.bg, borderRadius: BorderRadius.circular(6)),
                                    child: Text(biz.status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: biz.status.color)),
                                  ),
                                ),
                                DataCell(Text('₹${biz.totalRevenue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary))),
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(biz.expiryDate.toString().split(' ').first, style: const TextStyle(fontSize: 11.5, color: SuperAdminTheme.textSecondary)),
                                      if (biz.isExpiringSoon)
                                        const Text('Expiring Soon', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SuperAdminTheme.warning)),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.open_in_new_rounded, size: 17, color: SuperAdminTheme.primary),
                                        tooltip: 'View Business Overview',
                                        onPressed: () => widget.onSelectBusiness?.call(biz.id),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.more_time_rounded, size: 17, color: SuperAdminTheme.accent),
                                        tooltip: 'Extend Subscription',
                                        onPressed: () => _showExtendDialog(context, api, biz),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.swap_horiz_rounded, size: 17, color: SuperAdminTheme.info),
                                        tooltip: 'Change Plan',
                                        onPressed: () => _showChangePlanDialog(context, api, biz),
                                      ),
                                      if (biz.status != BusinessStatus.suspended)
                                        IconButton(
                                          icon: const Icon(Icons.block_rounded, size: 17, color: SuperAdminTheme.danger),
                                          tooltip: 'Suspend Business',
                                          onPressed: () => _confirmSuspend(context, api, biz),
                                        )
                                      else
                                        IconButton(
                                          icon: const Icon(Icons.check_circle_rounded, size: 17, color: SuperAdminTheme.success),
                                          tooltip: 'Activate Business',
                                          onPressed: () => api.activateBusiness(biz.id),
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

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.storefront_outlined, size: 40, color: SuperAdminTheme.textMuted),
            SizedBox(height: 10),
            Text('No businesses found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
            SizedBox(height: 4),
            Text('Try adjusting your search criteria or status filters.', style: TextStyle(fontSize: 12, color: SuperAdminTheme.textMuted)),
          ],
        ),
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
          title: Text('Extend Subscription: ${biz.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select additional duration to append to current expiry:'),
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
                api.extendSubscription(biz.id, selectedDays);
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
          title: Text('Change Plan for ${biz.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selectedPlan,
                isExpanded: true,
                items: api.plans.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (₹${p.monthlyPrice}/mo)'))).toList(),
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
      message: 'Are you sure you want to suspend access for ${biz.name}? Terminals and orders will be immediately blocked.',
      confirmLabel: 'Suspend Business',
      onConfirmWithReason: (reason) async {
        api.suspendBusiness(biz.id, reason);
      },
    );
  }
}
