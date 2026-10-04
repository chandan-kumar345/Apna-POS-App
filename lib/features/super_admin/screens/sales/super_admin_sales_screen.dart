import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../services/super_admin_api_service.dart';
import '../../widgets/super_admin_chart_card.dart';

class SuperAdminSalesScreen extends StatefulWidget {
  final Function(int targetTab, String? entityId)? onNavigate;

  const SuperAdminSalesScreen({
    super.key,
    this.onNavigate,
  });

  @override
  State<SuperAdminSalesScreen> createState() => _SuperAdminSalesScreenState();
}

class _SuperAdminSalesScreenState extends State<SuperAdminSalesScreen> {
  String _timeRange = 'This Month';
  final _searchController = TextEditingController();
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
        final filteredSales = api.sales.where((s) {
          return q.isEmpty ||
              s.businessName.toLowerCase().contains(q) ||
              s.ownerName.toLowerCase().contains(q) ||
              s.invoiceNumber.toLowerCase().contains(q) ||
              s.transactionId.toLowerCase().contains(q);
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Time Range Filter (Section 5 Filters)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sales & Subscription Analytics', style: SuperAdminTheme.h1),
                      const SizedBox(height: 4),
                      Text('Tracking ₹${api.totalRevenue.toStringAsFixed(0)} in gross transactions', style: SuperAdminTheme.body),
                    ],
                  ),
                  _buildTimeFilter(),
                ],
              ),
              const SizedBox(height: 20),

              // Charts Row (Section 5: Revenue Trend & Business Sales)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: SuperAdminTheme.neumorphicBox(radius: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Revenue Growth Breakdown', style: SuperAdminTheme.h3),
                          SizedBox(height: 2),
                          Text('Subscription revenue vs add-on extensions', style: SuperAdminTheme.caption),
                          SizedBox(height: 16),
                          SuperAdminLineChart(
                            labels: ['1-5 Oct', '6-10 Oct', '11-15 Oct', '16-20 Oct', '21-25 Oct', '26-30 Oct'],
                            values: [25000, 48000, 64000, 89000, 118000, 148500],
                            secondaryValues: [6000, 12000, 18000, 24000, 31000, 42000],
                            primaryLabel: 'Base Plan Sales',
                            secondaryLabel: 'Add-ons & Hardware',
                            height: 220,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: SuperAdminTheme.neumorphicBox(radius: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Sales Volume by Category', style: SuperAdminTheme.h3),
                          SizedBox(height: 2),
                          Text('Contract distribution across tiers', style: SuperAdminTheme.caption),
                          SizedBox(height: 16),
                          SuperAdminBarChart(
                            categories: ['Starter', 'Growth Pro', 'Enterprise', 'Hardware'],
                            values: [38, 84, 22, 14],
                            barColors: [
                              SuperAdminTheme.info,
                              SuperAdminTheme.primary,
                              SuperAdminTheme.success,
                              SuperAdminTheme.warning,
                            ],
                            height: 220,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sales by Business Table (Section 5 Table)
              Container(
                decoration: SuperAdminTheme.neumorphicBox(radius: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: SuperAdminTheme.textMuted),
                                hintText: 'Search sales transactions by business, invoice or transaction ID...',
                                filled: true,
                                fillColor: SuperAdminTheme.bg,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: SuperAdminTheme.border)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              onChanged: (val) => setState(() => _searchQuery = val),
                            ),
                          ),
                          const SizedBox(width: 14),
                          ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exported Sales Ledger (CSV)')));
                            },
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text('Export CSV'),
                            style: ElevatedButton.styleFrom(backgroundColor: SuperAdminTheme.primary, foregroundColor: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: SuperAdminTheme.border),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 48,
                        dataRowMinHeight: 56,
                        dataRowMaxHeight: 60,
                        headingRowColor: const WidgetStatePropertyAll(SuperAdminTheme.bg),
                        columns: const [
                          DataColumn(label: Text('BUSINESS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                          DataColumn(label: Text('OWNER', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                          DataColumn(label: Text('PLAN', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                          DataColumn(label: Text('INVOICE / TXN', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                          DataColumn(label: Text('AMOUNT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                          DataColumn(label: Text('METHOD', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                          DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                          DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                        ],
                        rows: filteredSales.map((s) {
                          return DataRow(
                            cells: [
                              DataCell(
                                InkWell(
                                  onTap: () => widget.onNavigate?.call(2, s.businessId),
                                  child: Text(s.businessName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: SuperAdminTheme.primary)),
                                ),
                              ),
                              DataCell(Text(s.ownerName, style: const TextStyle(fontSize: 12.5, color: SuperAdminTheme.textSecondary))),
                              DataCell(Text(s.planName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.invoiceNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
                                    Text(s.transactionId, style: const TextStyle(fontSize: 10.5, color: SuperAdminTheme.textMuted)),
                                  ],
                                ),
                              ),
                              DataCell(Text('₹${s.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: SuperAdminTheme.textPrimary))),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(s.method.icon, size: 14, color: SuperAdminTheme.textSecondary),
                                    const SizedBox(width: 6),
                                    Text(s.method.label, style: const TextStyle(fontSize: 11.5, color: SuperAdminTheme.textSecondary)),
                                  ],
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(color: s.status.bg, borderRadius: BorderRadius.circular(6)),
                                  child: Text(s.status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: s.status.color)),
                                ),
                              ),
                              DataCell(Text(s.date.toString().split(' ').first, style: const TextStyle(fontSize: 11.5, color: SuperAdminTheme.textMuted))),
                            ],
                          );
                        }).toList(),
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

  Widget _buildTimeFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: SuperAdminTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SuperAdminTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _timeRange,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
          items: const [
            DropdownMenuItem(value: 'Today', child: Text('Today')),
            DropdownMenuItem(value: 'Yesterday', child: Text('Yesterday')),
            DropdownMenuItem(value: 'This Week', child: Text('This Week')),
            DropdownMenuItem(value: 'This Month', child: Text('This Month')),
            DropdownMenuItem(value: 'Last Month', child: Text('Last Month')),
            DropdownMenuItem(value: 'This Year', child: Text('This Year')),
            DropdownMenuItem(value: 'Custom Range', child: Text('Custom Date Range')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _timeRange = val);
          },
        ),
      ),
    );
  }
}
