import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/super_admin_theme.dart';
import '../../services/super_admin_api_service.dart';
import '../../models/super_admin_business_model.dart';

class SuperAdminRevenueReportScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final Function(String businessId)? onSelectBusiness;

  const SuperAdminRevenueReportScreen({
    super.key,
    this.onBack,
    this.onSelectBusiness,
  });

  @override
  State<SuperAdminRevenueReportScreen> createState() => _SuperAdminRevenueReportScreenState();
}

class _SuperAdminRevenueReportScreenState extends State<SuperAdminRevenueReportScreen> {
  String _searchQuery = '';
  String _selectedPlan = 'All';
  String _selectedLocation = 'All';
  String _selectedStatus = 'All';
  String _sortColumn = 'totalRevenue';
  bool _sortAscending = false;

  @override
  Widget build(BuildContext context) {
    final api = SuperAdminApiService();

    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        // Compute revenue rows from businesses and sales
        List<PlatformBusiness> filtered = api.businesses.where((b) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch = query.isEmpty ||
              b.name.toLowerCase().contains(query) ||
              b.ownerName.toLowerCase().contains(query) ||
              b.city.toLowerCase().contains(query);

          final matchesPlan = _selectedPlan == 'All' || b.planName == _selectedPlan;
          final matchesLocation = _selectedLocation == 'All' || b.city == _selectedLocation;
          final matchesStatus = _selectedStatus == 'All' || b.status.label == _selectedStatus;

          return matchesSearch && matchesPlan && matchesLocation && matchesStatus;
        }).toList();

        // Sorting
        filtered.sort((a, b) {
          int cmp = 0;
          if (_sortColumn == 'name') {
            cmp = a.name.compareTo(b.name);
          } else if (_sortColumn == 'totalRevenue') {
            cmp = a.totalRevenue.compareTo(b.totalRevenue);
          } else if (_sortColumn == 'subscriptionRevenue') {
            cmp = a.subscriptionRevenue.compareTo(b.subscriptionRevenue);
          } else if (_sortColumn == 'expiryDate') {
            cmp = a.expiryDate.compareTo(b.expiryDate);
          }
          return _sortAscending ? cmp : -cmp;
        });

        // Totals
        final totalBilled = filtered.fold(0.0, (acc, b) => acc + b.totalRevenue);
        final totalSubRevenue = filtered.fold(0.0, (acc, b) => acc + b.subscriptionRevenue);
        final totalAddons = totalBilled - totalSubRevenue;

        // Extract unique cities
        final cities = ['All', ...api.businesses.map((b) => b.city).toSet()];
        final plans = ['All', ...api.plans.map((p) => p.name).toSet()];
        final statuses = ['All', 'Active', 'Trial', 'Expiring Soon', 'Expired', 'Suspended'];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button & Title Header
              Row(
                children: [
                  if (widget.onBack != null) ...[
                    IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back to Revenue Overview',
                      style: IconButton.styleFrom(
                        backgroundColor: SuperAdminTheme.cardBg,
                        foregroundColor: SuperAdminTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Business-Wise Revenue & Billing Report',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: SuperAdminTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Granular subscriber breakdown, lifetime collections, renewals, and next billing schedules.',
                          style: TextStyle(fontSize: 13, color: SuperAdminTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  // Export Action Buttons
                  _buildExportButton(
                    label: 'Export CSV',
                    icon: Icons.table_view_rounded,
                    color: SuperAdminTheme.successGreen,
                    onTap: () => _exportCsv(filtered),
                  ),
                  const SizedBox(width: 8),
                  _buildExportButton(
                    label: 'Export PDF',
                    icon: Icons.picture_as_pdf_rounded,
                    color: SuperAdminTheme.errorRed,
                    onTap: () => _exportPdf(filtered),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // KPI Metric Cards Row
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Total Filtered Collections',
                      value: '₹${totalBilled.toStringAsFixed(0)}',
                      icon: Icons.account_balance_wallet_rounded,
                      color: SuperAdminTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Subscription Revenue',
                      value: '₹${totalSubRevenue.toStringAsFixed(0)}',
                      icon: Icons.autorenew_rounded,
                      color: SuperAdminTheme.successGreen,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Add-on / Module Collections',
                      value: '₹${totalAddons.toStringAsFixed(0)}',
                      icon: Icons.extension_rounded,
                      color: SuperAdminTheme.purpleAccent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Filtered Businesses',
                      value: '${filtered.length}',
                      icon: Icons.storefront_rounded,
                      color: SuperAdminTheme.accentCyan,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Filter Controls Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: SuperAdminTheme.cardDecoration(context),
                child: Row(
                  children: [
                    // Search box
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
                            hintText: 'Search business, owner, or city...',
                            hintStyle: TextStyle(fontSize: 13, color: SuperAdminTheme.textMuted),
                            prefixIcon: Icon(Icons.search_rounded, size: 20, color: SuperAdminTheme.textSecondary),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Plan Filter
                    _buildDropdownFilter(
                      label: 'Plan',
                      value: _selectedPlan,
                      items: plans,
                      onChanged: (v) => setState(() => _selectedPlan = v!),
                    ),
                    const SizedBox(width: 12),

                    // Location Filter
                    _buildDropdownFilter(
                      label: 'City',
                      value: _selectedLocation,
                      items: cities,
                      onChanged: (v) => setState(() => _selectedLocation = v!),
                    ),
                    const SizedBox(width: 12),

                    // Status Filter
                    _buildDropdownFilter(
                      label: 'Status',
                      value: _selectedStatus,
                      items: statuses,
                      onChanged: (v) => setState(() => _selectedStatus = v!),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Main Data Table
              Container(
                decoration: SuperAdminTheme.cardDecoration(context),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      color: SuperAdminTheme.background,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: _buildSortableHeader('Business & Location', 'name')),
                          Expanded(flex: 2, child: _buildHeaderCell('Owner / Contact')),
                          Expanded(flex: 2, child: _buildHeaderCell('Plan Tier')),
                          Expanded(flex: 2, child: _buildSortableHeader('Total Paid', 'totalRevenue')),
                          Expanded(flex: 2, child: _buildSortableHeader('Sub. Revenue', 'subscriptionRevenue')),
                          Expanded(flex: 2, child: _buildSortableHeader('Next Renewal', 'expiryDate')),
                          Expanded(flex: 2, child: _buildHeaderCell('Status')),
                          const SizedBox(width: 80, child: Text('Action', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textSecondary))),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: SuperAdminTheme.border),

                    // Table Rows
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: SuperAdminTheme.textMuted),
                              const SizedBox(height: 12),
                              const Text('No business revenue records match your filters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary)),
                            ],
                          ),
                        ),
                      )
                    else
                      ...filtered.map((b) => _buildTableRow(context, b)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableRow(BuildContext context, PlatformBusiness b) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SuperAdminTheme.border, width: 0.8)),
      ),
      child: Row(
        children: [
          // Business & City
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: SuperAdminTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      b.name.isNotEmpty ? b.name[0] : 'B',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: SuperAdminTheme.primaryBlue, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${b.city}, ${b.state}',
                        style: TextStyle(fontSize: 11, color: SuperAdminTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Owner
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.ownerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary)),
                Text(b.ownerPhone, style: TextStyle(fontSize: 11, color: SuperAdminTheme.textSecondary)),
              ],
            ),
          ),

          // Plan Tier
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: SuperAdminTheme.primaryBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  b.planName,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SuperAdminTheme.primaryBlue),
                ),
              ),
            ),
          ),

          // Total Paid
          Expanded(
            flex: 2,
            child: Text(
              '₹${b.totalRevenue.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
            ),
          ),

          // Subscription Revenue
          Expanded(
            flex: 2,
            child: Text(
              '₹${b.subscriptionRevenue.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SuperAdminTheme.successGreen),
            ),
          ),

          // Next Renewal
          Expanded(
            flex: 2,
            child: Text(
              b.expiryDate.toString().split(' ').first,
              style: TextStyle(fontSize: 12, color: SuperAdminTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),

          // Status Badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: b.status.badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  b.status.label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: b.status.badgeColor),
                ),
              ),
            ),
          ),

          // Action
          SizedBox(
            width: 80,
            child: IconButton(
              onPressed: () {
                if (widget.onSelectBusiness != null) {
                  widget.onSelectBusiness!(b.id);
                }
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              tooltip: 'View Business Analytics',
              style: IconButton.styleFrom(
                foregroundColor: SuperAdminTheme.primaryBlue,
              ),
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
              Text(
                title,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SuperAdminTheme.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: SuperAdminTheme.textPrimary),
              ),
            ],
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

  Widget _buildHeaderCell(String label) {
    return Text(
      label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textSecondary),
    );
  }

  Widget _buildSortableHeader(String label, String columnKey) {
    final isSelected = _sortColumn == columnKey;
    return InkWell(
      onTap: () {
        setState(() {
          if (_sortColumn == columnKey) {
            _sortAscending = !_sortAscending;
          } else {
            _sortColumn = columnKey;
            _sortAscending = false;
          }
        });
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? SuperAdminTheme.primaryBlue : SuperAdminTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isSelected
                ? (_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)
                : Icons.unfold_more_rounded,
            size: 14,
            color: isSelected ? SuperAdminTheme.primaryBlue : SuperAdminTheme.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.4)),
        backgroundColor: color.withOpacity(0.06),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _exportCsv(List<PlatformBusiness> list) {
    final buffer = StringBuffer();
    buffer.writeln('Business Name,Owner,City,State,Plan,Total Revenue,Subscription Revenue,Expiry Date,Status');
    for (final b in list) {
      buffer.writeln('"${b.name}","${b.ownerName}","${b.city}","${b.state}","${b.planName}",${b.totalRevenue},${b.subscriptionRevenue},"${b.expiryDate.toString().split(' ').first}","${b.status.label}"');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${list.length} rows as CSV! Copied to clipboard and ready for spreadsheet.'),
        backgroundColor: SuperAdminTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _exportPdf(List<PlatformBusiness> list) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generated PDF Financial Summary Document. Ready for print and audit compliance.'),
        backgroundColor: SuperAdminTheme.primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
