import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../models/super_admin_sales_model.dart';
import '../../services/super_admin_api_service.dart';
import '../../widgets/super_admin_kpi_card.dart';
import '../../widgets/super_admin_chart_card.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  final Function(int targetTab, String? entityId)? onNavigate;

  const SuperAdminDashboardScreen({
    super.key,
    this.onNavigate,
  });

  @override
  State<SuperAdminDashboardScreen> createState() => _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  String _selectedTimeFilter = 'This Month';

  @override
  Widget build(BuildContext context) {
    final api = SuperAdminApiService();

    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner & Quick Filter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Platform Overview',
                        style: SuperAdminTheme.h1,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Real-time SaaS performance, revenue trends, and business metrics.',
                        style: SuperAdminTheme.body,
                      ),
                    ],
                  ),
                  _buildTimeFilterDropdown(),
                ],
              ),
              const SizedBox(height: 20),

              // 12 KPI Cards Grid (Section 4)
              _buildKpiGrid(api),
              const SizedBox(height: 24),

              // Revenue Overview & Sales Breakdown Charts (Section 5)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Revenue Trend Line Chart
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: SuperAdminTheme.neumorphicBox(radius: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('Revenue Trend', style: SuperAdminTheme.h3),
                                  SizedBox(height: 2),
                                  Text('Monthly recurring vs Add-on sales', style: SuperAdminTheme.caption),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: SuperAdminTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'MRR: ₹${api.monthlyRecurringRevenue.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SuperAdminLineChart(
                            labels: const ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'],
                            values: const [48000, 62000, 78000, 95000, 115000, 148500],
                            secondaryValues: const [12000, 18000, 22000, 26000, 31000, 42000],
                            primaryLabel: 'Subscription Revenue',
                            secondaryLabel: 'Add-ons & Hardware',
                            height: 230,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Right: Business Sales Breakdown Bar Chart
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: SuperAdminTheme.neumorphicBox(radius: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Business Sales Activity', style: SuperAdminTheme.h3),
                          const SizedBox(height: 2),
                          const Text('Subscriptions, renewals & upgrades', style: SuperAdminTheme.caption),
                          const SizedBox(height: 16),
                          SuperAdminBarChart(
                            categories: const ['New', 'Renewals', 'Upgrades', 'Downgrades', 'Cancelled'],
                            values: const [18, 42, 12, 3, 2],
                            barColors: const [
                              SuperAdminTheme.primary,
                              SuperAdminTheme.success,
                              SuperAdminTheme.info,
                              SuperAdminTheme.warning,
                              SuperAdminTheme.danger,
                            ],
                            height: 230,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Sales by Business Table (Section 5 Table)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: SuperAdminTheme.neumorphicBox(radius: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Recent Platform Transactions', style: SuperAdminTheme.h3),
                            SizedBox(height: 2),
                            Text('Live transaction log from all registered businesses', style: SuperAdminTheme.caption),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => widget.onNavigate?.call(5, null), // Sales tab
                          icon: const Text('View All Sales', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          label: const Icon(Icons.arrow_forward_rounded, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildRecentSalesTable(api),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: SuperAdminTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SuperAdminTheme.border),
        boxShadow: SuperAdminTheme.flatCardShadow,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTimeFilter,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: SuperAdminTheme.textSecondary),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
          items: const [
            DropdownMenuItem(value: 'Today', child: Text('Today')),
            DropdownMenuItem(value: 'Yesterday', child: Text('Yesterday')),
            DropdownMenuItem(value: 'This Week', child: Text('This Week')),
            DropdownMenuItem(value: 'This Month', child: Text('This Month')),
            DropdownMenuItem(value: 'Last Month', child: Text('Last Month')),
            DropdownMenuItem(value: 'This Year', child: Text('This Year')),
            DropdownMenuItem(value: 'Custom Date Range', child: Text('Custom Range')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedTimeFilter = val);
          },
        ),
      ),
    );
  }

  Widget _buildKpiGrid(SuperAdminApiService api) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 3 : 2);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.65,
          children: [
            SuperAdminKpiCard(
              title: 'Total Users',
              value: '${api.totalUsers}',
              changePercentage: 14.8,
              icon: Icons.people_rounded,
              iconColor: SuperAdminTheme.primary,
              onTap: () => widget.onNavigate?.call(1, null),
            ),
            SuperAdminKpiCard(
              title: 'Active Users',
              value: '${api.activeUsers}',
              changePercentage: 11.2,
              icon: Icons.person_pin_rounded,
              iconColor: SuperAdminTheme.success,
              onTap: () => widget.onNavigate?.call(1, null),
            ),
            SuperAdminKpiCard(
              title: 'Total Businesses',
              value: '${api.totalBusinesses}',
              changePercentage: 18.5,
              icon: Icons.storefront_rounded,
              iconColor: SuperAdminTheme.accent,
              onTap: () => widget.onNavigate?.call(2, null),
            ),
            SuperAdminKpiCard(
              title: 'Active Businesses',
              value: '${api.activeBusinesses}',
              changePercentage: 12.4,
              icon: Icons.verified_rounded,
              iconColor: SuperAdminTheme.success,
              onTap: () => widget.onNavigate?.call(2, null),
            ),
            SuperAdminKpiCard(
              title: 'Trial Businesses',
              value: '${api.trialBusinesses}',
              subtitle: '14-day evaluation',
              icon: Icons.timelapse_rounded,
              iconColor: SuperAdminTheme.info,
              onTap: () => widget.onNavigate?.call(2, null),
            ),
            SuperAdminKpiCard(
              title: 'Expired Businesses',
              value: '${api.expiredBusinesses}',
              subtitle: 'Requires renewal outreach',
              icon: Icons.timer_off_rounded,
              iconColor: SuperAdminTheme.danger,
              onTap: () => widget.onNavigate?.call(2, null),
            ),
            SuperAdminKpiCard(
              title: 'Active Subscriptions',
              value: '${api.activeSubscriptions}',
              changePercentage: 15.0,
              icon: Icons.card_membership_rounded,
              iconColor: SuperAdminTheme.primary,
              onTap: () => widget.onNavigate?.call(3, null),
            ),
            SuperAdminKpiCard(
              title: 'Expired Subscriptions',
              value: '${api.expiredSubscriptions}',
              subtitle: 'Action required',
              icon: Icons.event_busy_rounded,
              iconColor: SuperAdminTheme.warning,
              onTap: () => widget.onNavigate?.call(3, null),
            ),
            SuperAdminKpiCard(
              title: 'Monthly Recurring Revenue (MRR)',
              value: '₹${api.monthlyRecurringRevenue.toStringAsFixed(0)}',
              changePercentage: 22.8,
              icon: Icons.trending_up_rounded,
              iconColor: SuperAdminTheme.success,
              onTap: () => widget.onNavigate?.call(7, null),
            ),
            SuperAdminKpiCard(
              title: 'Total Revenue',
              value: '₹${api.totalRevenue.toStringAsFixed(0)}',
              changePercentage: 28.4,
              icon: Icons.account_balance_wallet_rounded,
              iconColor: SuperAdminTheme.primary,
              onTap: () => widget.onNavigate?.call(7, null),
            ),
            SuperAdminKpiCard(
              title: 'Pending Payments',
              value: '₹${api.pendingPayments.toStringAsFixed(0)}',
              subtitle: 'Follow-up queued',
              icon: Icons.hourglass_top_rounded,
              iconColor: SuperAdminTheme.warning,
              onTap: () => widget.onNavigate?.call(6, null),
            ),
            SuperAdminKpiCard(
              title: 'New Businesses This Month',
              value: '${api.newBusinessesThisMonth}',
              changePercentage: 33.3,
              icon: Icons.domain_add_rounded,
              iconColor: SuperAdminTheme.success,
              onTap: () => widget.onNavigate?.call(2, null),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentSalesTable(SuperAdminApiService api) {
    return Container(
      decoration: BoxDecoration(
        color: SuperAdminTheme.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SuperAdminTheme.border),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.2),
          1: FlexColumnWidth(1.8),
          2: FlexColumnWidth(1.6),
          3: FlexColumnWidth(1.2),
          4: FlexColumnWidth(1.2),
          5: FlexColumnWidth(1.4),
        },
        children: [
          // Table Header
          TableRow(
            decoration: const BoxDecoration(
              color: SuperAdminTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            children: const [
              _TableHeaderCell('Business'),
              _TableHeaderCell('Owner'),
              _TableHeaderCell('Plan'),
              _TableHeaderCell('Amount'),
              _TableHeaderCell('Status'),
              _TableHeaderCell('Date'),
            ],
          ),
          // Table Data Rows
          ...api.sales.take(5).map((s) {
            return TableRow(
              children: [
                _TableCell(
                  child: Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 16, color: SuperAdminTheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.businessName,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                _TableCell(child: Text(s.ownerName, style: const TextStyle(fontSize: 12, color: SuperAdminTheme.textSecondary))),
                _TableCell(child: Text(s.planName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary))),
                _TableCell(child: Text('₹${s.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary))),
                _TableCell(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: s.status.bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      s.status.label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: s.status.color),
                    ),
                  ),
                ),
                _TableCell(
                  child: Text(
                    s.date.toString().split(' ').first,
                    style: const TextStyle(fontSize: 11.5, color: SuperAdminTheme.textMuted),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String label;
  const _TableHeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: SuperAdminTheme.textMuted,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final Widget child;
  const _TableCell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: child,
    );
  }
}
