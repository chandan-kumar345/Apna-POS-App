import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../services/super_admin_api_service.dart';

class SuperAdminTeamSubscriptionsScreen extends StatelessWidget {
  final Function(int targetTab, String? entityId)? onNavigate;

  const SuperAdminTeamSubscriptionsScreen({
    super.key,
    this.onNavigate,
  });

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Team Subscriptions', style: SuperAdminTheme.h1),
                      SizedBox(height: 4),
                      Text('Dedicated team-level billing separate from core business subscriptions (Section 13).', style: SuperAdminTheme.body),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Info Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SuperAdminTheme.infoLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SuperAdminTheme.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline_rounded, color: SuperAdminTheme.info, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Team Subscriptions are isolated from primary business plan renewals. Team pricing covers concurrent staff seats, kitchen display nodes, and multi-waiter shift concurrency.',
                        style: TextStyle(fontSize: 12.5, color: SuperAdminTheme.textPrimary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Team Subscriptions Table
              Container(
                decoration: SuperAdminTheme.neumorphicBox(radius: 14),
                child: api.teamSubscriptions.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('No team-level subscriptions active.')),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 48,
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 60,
                          headingRowColor: const WidgetStatePropertyAll(SuperAdminTheme.bg),
                          columns: const [
                            DataColumn(label: Text('TEAM NAME', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('BUSINESS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('SEATS / MEMBERS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('TEAM PRICE / MO', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('EXPIRY DATE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('PAYMENT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                          ],
                          rows: api.teamSubscriptions.map((ts) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      const Icon(Icons.group_work_rounded, color: SuperAdminTheme.primary, size: 18),
                                      const SizedBox(width: 8),
                                      Text(ts.teamName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: SuperAdminTheme.textPrimary)),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  InkWell(
                                    onTap: () => onNavigate?.call(2, ts.businessId),
                                    child: Text(ts.businessName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: SuperAdminTheme.primary)),
                                  ),
                                ),
                                DataCell(Text('${ts.memberCount} Staff Accounts', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                                DataCell(Text('₹${ts.teamPricePerMonth.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary))),
                                DataCell(Text(ts.expiryDate.toString().split(' ').first, style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: SuperAdminTheme.successLight, borderRadius: BorderRadius.circular(4)),
                                    child: Text(ts.paymentStatus.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: SuperAdminTheme.success)),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(color: ts.status.bg, borderRadius: BorderRadius.circular(6)),
                                    child: Text(ts.status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ts.status.color)),
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
