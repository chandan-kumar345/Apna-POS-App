import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/super_admin_theme.dart';
import '../../services/super_admin_api_service.dart';

class SuperAdminReportsScreen extends StatefulWidget {
  final Function(String route)? onNavigate;

  const SuperAdminReportsScreen({super.key, this.onNavigate});

  @override
  State<SuperAdminReportsScreen> createState() => _SuperAdminReportsScreenState();
}

class _SuperAdminReportsScreenState extends State<SuperAdminReportsScreen> {
  String _selectedDateRange = 'This Quarter (Q3 FY26)';

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
              // Header
              _buildHeader(context),
              const SizedBox(height: 24),

              // Reports Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;
                  final crossAxisCount = isDesktop ? 2 : 1;
                  final width = (constraints.maxWidth - (crossAxisCount - 1) * 20) / crossAxisCount;

                  return Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      SizedBox(
                        width: width,
                        child: _buildReportCard(
                          title: 'Financial Reconciliation & GST Tax Report',
                          category: 'FINANCE & TAX',
                          description: 'Full itemized platform transaction ledger, GST tax liability, gateway processing fees, net payouts, and refund logs.',
                          icon: Icons.receipt_long_rounded,
                          color: SuperAdminTheme.primaryBlue,
                          metrics: [
                            'Total Billed: ₹${api.totalRevenue.toStringAsFixed(0)}',
                            'GST (18%): ₹${(api.totalRevenue * 0.18).toStringAsFixed(0)}',
                            'Settled: ₹${(api.totalRevenue * 0.98).toStringAsFixed(0)}',
                          ],
                          onView: () {
                            if (widget.onNavigate != null) {
                              widget.onNavigate!('revenue_report');
                            }
                          },
                          onDownload: () => _simulateDownload('Financial_GST_Reconciliation_Q3.xlsx'),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _buildReportCard(
                          title: 'Subscription Churn & Retention Analytics',
                          category: 'SAAS RETENTION',
                          description: 'Monthly Cohort Analysis, net revenue retention (NRR), renewal velocity, plan upgrades, downgrades, and churned accounts.',
                          icon: Icons.autorenew_rounded,
                          color: SuperAdminTheme.successGreen,
                          metrics: [
                            'Active Subs: ${api.activeSubscriptions}',
                            'Expiring in 7 Days: ${api.expiringSoonSubscriptions}',
                            'Churn Rate: 1.8%',
                          ],
                          onView: () => _showReportPreviewDialog(context, 'Subscription Churn & Retention Report', [
                            ['Metric', 'Current Period', 'Previous Period', 'Change'],
                            ['Gross Renewal Rate', '94.2%', '91.8%', '+2.4%'],
                            ['Net Retention Rate (NRR)', '114.5%', '109.2%', '+5.3%'],
                            ['Trial-to-Paid Conversion', '42.8%', '38.5%', '+4.3%'],
                            ['Avg Customer Lifetime', '18.4 Months', '16.2 Months', '+2.2 Mo'],
                          ]),
                          onDownload: () => _simulateDownload('Subscription_Churn_Analytics.pdf'),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _buildReportCard(
                          title: 'Merchant Onboarding & Growth Funnel',
                          category: 'ACQUISITIONS',
                          description: 'Funnel analytics tracking new restaurant signups, trial activations, verification milestones, and branch expansions.',
                          icon: Icons.trending_up_rounded,
                          color: const Color(0xFF6366F1),
                          metrics: [
                            'Total Outlets: ${api.totalBusinesses}',
                            'Active: ${api.activeBusinesses}',
                            'Trial Accounts: ${api.trialBusinesses}',
                          ],
                          onView: () => _showReportPreviewDialog(context, 'Merchant Onboarding Funnel', [
                            ['Funnel Stage', 'Count', 'Conversion Rate'],
                            ['Signups / Downloads', '340', '100%'],
                            ['Store Profile Completed', '289', '85.0%'],
                            ['First Bill Punched', '245', '72.0%'],
                            ['Trial Converted to Paid', '142', '41.7%'],
                          ]),
                          onDownload: () => _simulateDownload('Merchant_Onboarding_Funnel.csv'),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _buildReportCard(
                          title: 'Feature & Module Adoption Audit',
                          category: 'PRODUCT USAGE',
                          description: 'Live telemetry breakdown of which modules (KDS, Loyalty, WhatsApp, Online Ordering, Inventory) deliver highest merchant ROI.',
                          icon: Icons.extension_rounded,
                          color: SuperAdminTheme.purpleAccent,
                          metrics: [
                            'POS Fast Billing: 100%',
                            'WhatsApp Marketing: 78%',
                            'KDS Kitchen: 62%',
                          ],
                          onView: () {
                            if (widget.onNavigate != null) {
                              widget.onNavigate!('modules');
                            }
                          },
                          onDownload: () => _simulateDownload('Feature_Adoption_Report.xlsx'),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _buildReportCard(
                          title: 'Support SLA & Ticket Performance',
                          category: 'CUSTOMER SUCCESS',
                          description: 'Support desk velocity, first-response time, mean time to resolution (MTTR), and satisfaction ratings by issue category.',
                          icon: Icons.support_agent_rounded,
                          color: SuperAdminTheme.warningAmber,
                          metrics: [
                            'Avg MTTR: 28 mins',
                            'CSAT Score: 4.8 / 5.0',
                            'Total Resolved: ${api.tickets.length}',
                          ],
                          onView: () {
                            if (widget.onNavigate != null) {
                              widget.onNavigate!('support');
                            }
                          },
                          onDownload: () => _simulateDownload('Support_SLA_Performance.pdf'),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _buildReportCard(
                          title: 'System Security & Compliance Audit Trail',
                          category: 'FORENSICS',
                          description: 'Comprehensive forensic logs of all administrator actions, credential changes, data exports, and permission elevations.',
                          icon: Icons.security_rounded,
                          color: SuperAdminTheme.errorRed,
                          metrics: [
                            'Events Logged: ${api.auditLogs.length}',
                            'Immutability: 100% Verified',
                            'IP Integrity: OK',
                          ],
                          onView: () {
                            if (widget.onNavigate != null) {
                              widget.onNavigate!('audit_logs');
                            }
                          },
                          onDownload: () => _simulateDownload('Audit_Security_Trail.csv'),
                        ),
                      ),
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
            child: const Icon(Icons.assessment_rounded, color: SuperAdminTheme.primaryBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Platform Analytics & Compliance Reports',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: SuperAdminTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Download executive summary reports, financial GST reconciliation, subscriber cohort analysis, and forensic audit archives.',
                  style: TextStyle(fontSize: 13, color: SuperAdminTheme.textSecondary),
                ),
              ],
            ),
          ),
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
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: SuperAdminTheme.textSecondary),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary),
                items: [
                  'This Month (Oct 2026)',
                  'Last Month (Sep 2026)',
                  'This Quarter (Q3 FY26)',
                  'Full Year (FY 2025-26)',
                ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedDateRange = v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String category,
    required String description,
    required IconData icon,
    required Color color,
    required List<String> metrics,
    required VoidCallback onView,
    required VoidCallback onDownload,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: SuperAdminTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(fontSize: 12, color: SuperAdminTheme.textSecondary, height: 1.35),
          ),

          const SizedBox(height: 16),
          // Metric pills
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: metrics.map((m) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: SuperAdminTheme.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: SuperAdminTheme.border),
                ),
                child: Text(
                  m,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),
          const Divider(height: 1, color: SuperAdminTheme.border),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View Report'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: SuperAdminTheme.primaryBlue.withOpacity(0.4)),
                    foregroundColor: SuperAdminTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SuperAdminTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReportPreviewDialog(BuildContext context, String title, List<List<String>> tableData) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: SuperAdminTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
          content: SizedBox(
            width: 500,
            child: Table(
              border: TableBorder.all(color: SuperAdminTheme.border),
              children: tableData.map((row) {
                final isHeader = row == tableData.first;
                return TableRow(
                  decoration: BoxDecoration(color: isHeader ? SuperAdminTheme.background : Colors.transparent),
                  children: row.map((cell) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        cell,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
                          color: isHeader ? SuperAdminTheme.textPrimary : SuperAdminTheme.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: SuperAdminTheme.primaryBlue, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  void _simulateDownload(String filename) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generated and downloaded $filename successfully!'),
        backgroundColor: SuperAdminTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
