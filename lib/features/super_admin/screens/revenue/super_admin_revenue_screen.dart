import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../services/super_admin_api_service.dart';
import '../../widgets/super_admin_kpi_card.dart';
import '../../widgets/super_admin_chart_card.dart';
import '../../models/super_admin_sales_model.dart';

class SuperAdminRevenueScreen extends StatefulWidget {
  final Function(String route)? onNavigate;

  const SuperAdminRevenueScreen({super.key, this.onNavigate});

  @override
  State<SuperAdminRevenueScreen> createState() => _SuperAdminRevenueScreenState();
}

class _SuperAdminRevenueScreenState extends State<SuperAdminRevenueScreen> {
  String _selectedDateRange = 'This Month';
  final List<String> _dateRanges = [
    'Today',
    'Yesterday',
    'This Week',
    'This Month',
    'Last Month',
    'This Year',
    'All Time',
  ];

  @override
  Widget build(BuildContext context) {
    final api = SuperAdminApiService();

    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final totalRev = api.totalRevenue;
        final mrr = api.monthlyRecurringRevenue;
        final arr = api.annualRunRate;
        final refunds = api.sales
            .where((s) => s.status == PaymentStatus.refunded)
            .fold(0.0, (acc, s) => acc + s.amount);
        final netRev = totalRev - refunds;

        // Breakdown estimates for SaaS metrics
        final newRev = totalRev * 0.35;
        final renewalRev = totalRev * 0.55;
        final upgradeRev = totalRev * 0.10;
        final addonRev = totalRev * 0.08;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              _buildHeader(context),
              const SizedBox(height: 24),

              // KPI Grid (Row 1 - High Level MRR / ARR)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;
                  final crossAxisCount = isDesktop ? 4 : 2;
                  final width = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: width,
                        child: SuperAdminKpiCard(
                          title: 'Total Revenue',
                          value: '₹${totalRev.toStringAsFixed(0)}',
                          changePercentage: 18.4,
                          comparisonPeriod: 'vs last month',
                          icon: Icons.account_balance_wallet_rounded,
                          iconColor: SuperAdminTheme.primaryBlue,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: SuperAdminKpiCard(
                          title: 'Monthly Recurring (MRR)',
                          value: '₹${mrr.toStringAsFixed(0)}',
                          changePercentage: 12.8,
                          comparisonPeriod: 'predictable stream',
                          icon: Icons.repeat_rounded,
                          iconColor: SuperAdminTheme.successGreen,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: SuperAdminKpiCard(
                          title: 'Annual Run Rate (ARR)',
                          value: '₹${(arr / 100000).toStringAsFixed(1)} Lakhs',
                          changePercentage: 15.2,
                          comparisonPeriod: 'forecast annualized',
                          icon: Icons.trending_up_rounded,
                          iconColor: SuperAdminTheme.accentCyan,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: SuperAdminKpiCard(
                          title: 'Net Platform Revenue',
                          value: '₹${netRev.toStringAsFixed(0)}',
                          changePercentage: 16.5,
                          comparisonPeriod: 'post-refund total',
                          icon: Icons.monetization_on_rounded,
                          iconColor: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // KPI Grid (Row 2 - Detailed Revenue Streams)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;
                  final crossAxisCount = isDesktop ? 5 : 2;
                  final width = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: width,
                        child: SuperAdminKpiCard(
                          title: 'New Subscriptions',
                          value: '₹${newRev.toStringAsFixed(0)}',
                          changePercentage: 24.1,
                          comparisonPeriod: 'new customer sales',
                          icon: Icons.add_circle_outline_rounded,
                          iconColor: SuperAdminTheme.successGreen,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: SuperAdminKpiCard(
                          title: 'Renewals',
                          value: '₹${renewalRev.toStringAsFixed(0)}',
                          changePercentage: 8.9,
                          comparisonPeriod: 'retained customer revenue',
                          icon: Icons.autorenew_rounded,
                          iconColor: SuperAdminTheme.primaryBlue,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: SuperAdminKpiCard(
                          title: 'Plan Upgrades',
                          value: '₹${upgradeRev.toStringAsFixed(0)}',
                          changePercentage: 31.5,
                          comparisonPeriod: 'expansion revenue',
                          icon: Icons.upgrade_rounded,
                          iconColor: SuperAdminTheme.purpleAccent,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: SuperAdminKpiCard(
                          title: 'Add-ons & Modules',
                          value: '₹${addonRev.toStringAsFixed(0)}',
                          changePercentage: 11.2,
                          comparisonPeriod: 'extra SMS/KDS packs',
                          icon: Icons.extension_rounded,
                          iconColor: SuperAdminTheme.accentCyan,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: SuperAdminKpiCard(
                          title: 'Refunds Issued',
                          value: '₹${refunds.toStringAsFixed(0)}',
                          changePercentage: -4.2,
                          comparisonPeriod: '1 transaction',
                          icon: Icons.remove_circle_outline_rounded,
                          iconColor: SuperAdminTheme.errorRed,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 28),

              // Main Analytics Charts Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 960;
                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: _buildRevenueTrendChart(),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 4,
                          child: _buildPlanRevenueBreakdown(),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _buildRevenueTrendChart(),
                      const SizedBox(height: 24),
                      _buildPlanRevenueBreakdown(),
                    ],
                  );
                },
              ),

              const SizedBox(height: 28),

              // Secondary Charts Row (New vs Renewal & Business Revenue Summary)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 960;
                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _buildNewVsRenewalChart(),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 5,
                          child: _buildTopRevenueBusinesses(api),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _buildNewVsRenewalChart(),
                      const SizedBox(height: 24),
                      _buildTopRevenueBusinesses(api),
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
            child: const Icon(Icons.analytics_rounded, color: SuperAdminTheme.primaryBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Platform Revenue Dashboard',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: SuperAdminTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Comprehensive financial intelligence, recurring revenue MRR/ARR, and subscription analytics.',
                  style: TextStyle(fontSize: 13, color: SuperAdminTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Date Filter Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: SuperAdminTheme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SuperAdminTheme.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDateRange,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: SuperAdminTheme.textPrimary),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary),
                items: _dateRanges.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedDateRange = val);
                },
              ),
            ),
          ),

          const SizedBox(width: 12),

          // View Detailed Report Button
          ElevatedButton.icon(
            onPressed: () {
              if (widget.onNavigate != null) {
                widget.onNavigate!('revenue_report');
              }
            },
            icon: const Icon(Icons.table_chart_rounded, size: 16),
            label: const Text('Business-Wise Report'),
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

  Widget _buildRevenueTrendChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SuperAdminTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revenue Growth Trend',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Monthly cash inflow & subscription recurring volumes',
                    style: TextStyle(fontSize: 12, color: SuperAdminTheme.textSecondary),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildLegendIndicator('Subscriptions', SuperAdminTheme.primaryBlue),
                  const SizedBox(width: 12),
                  _buildLegendIndicator('Add-ons', SuperAdminTheme.accentCyan),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SizedBox(
            height: 230,
            child: SuperAdminLineChart(
              labels: ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'],
              values: [15000, 28000, 42000, 58000, 76000, 94295],
              secondaryValues: [2000, 4500, 6000, 9000, 11000, 14200],
              primaryLabel: 'Subscriptions',
              secondaryLabel: 'Add-ons',
              primaryColor: SuperAdminTheme.primaryBlue,
              secondaryColor: SuperAdminTheme.accentCyan,
              valuePrefix: '₹',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanRevenueBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SuperAdminTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue by Subscription Plan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Share of revenue generated by tier',
            style: TextStyle(fontSize: 12, color: SuperAdminTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          _buildPlanShareItem(
            name: 'Enterprise Scale',
            revenue: '₹49,999',
            percentage: 53.0,
            color: const Color(0xFF6366F1),
            subscribers: 22,
          ),
          const SizedBox(height: 16),
          _buildPlanShareItem(
            name: 'Growth Pro',
            revenue: '₹34,297',
            percentage: 36.4,
            color: SuperAdminTheme.primaryBlue,
            subscribers: 84,
          ),
          const SizedBox(height: 16),
          _buildPlanShareItem(
            name: 'Starter Launch',
            revenue: '₹9,999',
            percentage: 10.6,
            color: SuperAdminTheme.accentCyan,
            subscribers: 38,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SuperAdminTheme.primaryBlue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SuperAdminTheme.primaryBlue.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 20, color: SuperAdminTheme.primaryBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Enterprise Scale produces 53% of platform revenue with 15% of subscriber base.',
                    style: TextStyle(fontSize: 12, color: SuperAdminTheme.primaryBlue.withOpacity(0.9), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanShareItem({
    required String name,
    required String revenue,
    required double percentage,
    required Color color,
    required int subscribers,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary)),
                const SizedBox(width: 6),
                Text('($subscribers businesses)', style: TextStyle(fontSize: 11, color: SuperAdminTheme.textSecondary)),
              ],
            ),
            Row(
              children: [
                Text(revenue, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
                const SizedBox(width: 8),
                Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: SuperAdminTheme.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildNewVsRenewalChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SuperAdminTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New Acquisition vs Retention Renewals',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Comparison of new logos vs recurring renewals over time',
            style: TextStyle(fontSize: 12, color: SuperAdminTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          const SizedBox(
            height: 200,
            child: SuperAdminBarChart(
              categories: ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'],
              values: [15000, 24000, 36000, 48000, 62000, 75000],
              barColors: [
                SuperAdminTheme.successGreen,
                SuperAdminTheme.primaryBlue,
                SuperAdminTheme.primaryBlue,
                SuperAdminTheme.primaryBlue,
                SuperAdminTheme.primaryBlue,
                SuperAdminTheme.primaryBlue,
              ],
              valuePrefix: '₹',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRevenueBusinesses(SuperAdminApiService api) {
    final topBiz = List.of(api.businesses)..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SuperAdminTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Revenue Generating Businesses',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
              ),
              Text(
                'Lifetime Billed',
                style: TextStyle(fontSize: 12, color: SuperAdminTheme.textSecondary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...topBiz.take(4).map((b) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SuperAdminTheme.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SuperAdminTheme.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: SuperAdminTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        b.name.isNotEmpty ? b.name[0] : 'B',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: SuperAdminTheme.primaryBlue),
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
                          '${b.planName} • ${b.city}',
                          style: TextStyle(fontSize: 11, color: SuperAdminTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${b.totalRevenue.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                      ),
                      Text(
                        '${b.renewalsCount} renewals',
                        style: const TextStyle(fontSize: 11, color: SuperAdminTheme.successGreen, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLegendIndicator(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: SuperAdminTheme.textSecondary)),
      ],
    );
  }
}
