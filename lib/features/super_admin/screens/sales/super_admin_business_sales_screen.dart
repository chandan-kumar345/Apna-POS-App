import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../models/super_admin_business_model.dart';
import '../../models/super_admin_sales_model.dart';
import '../../services/super_admin_api_service.dart';
import '../../widgets/super_admin_confirmation_dialog.dart';

class SuperAdminBusinessSalesScreen extends StatefulWidget {
  final String? initialBusinessId;
  final Function(int targetTab, String? entityId)? onNavigate;

  const SuperAdminBusinessSalesScreen({
    super.key,
    this.initialBusinessId,
    this.onNavigate,
  });

  @override
  State<SuperAdminBusinessSalesScreen> createState() => _SuperAdminBusinessSalesScreenState();
}

class _SuperAdminBusinessSalesScreenState extends State<SuperAdminBusinessSalesScreen> {
  late String _selectedBusinessId;

  @override
  void initState() {
    super.initState();
    final api = SuperAdminApiService();
    _selectedBusinessId = widget.initialBusinessId ?? (api.businesses.isNotEmpty ? api.businesses.first.id : '');
  }

  @override
  Widget build(BuildContext context) {
    final api = SuperAdminApiService();

    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final biz = api.businesses.firstWhere(
          (b) => b.id == _selectedBusinessId,
          orElse: () => api.businesses.first,
        );

        final bizSales = api.sales.where((s) => s.businessId == biz.id).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Business Selector (Section 6: Business Sales Analytics)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Business Sales & Revenue Drill-Down', style: SuperAdminTheme.h1),
                      SizedBox(height: 4),
                      Text('Dedicated individual business ledger, invoice management, and plan controls (Section 6).', style: SuperAdminTheme.body),
                    ],
                  ),
                  // Business Selector Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: SuperAdminTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: SuperAdminTheme.primary, width: 1.5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBusinessId,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: SuperAdminTheme.primary),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                        items: api.businesses.map((b) {
                          return DropdownMenuItem(
                            value: b.id,
                            child: Row(
                              children: [
                                const Icon(Icons.storefront_rounded, size: 16, color: SuperAdminTheme.primary),
                                const SizedBox(width: 8),
                                Text('${b.name} (${b.city})'),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedBusinessId = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Selected Business Detail Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: SuperAdminTheme.neumorphicBox(radius: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(biz.name, style: SuperAdminTheme.h2),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: biz.status.bg, borderRadius: BorderRadius.circular(6)),
                              child: Text(biz.status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: biz.status.color)),
                            ),
                          ],
                        ),
                        // Quick Action Buttons
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _showExtendDialog(context, api, biz),
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 15),
                              label: const Text('Extend Days'),
                              style: ElevatedButton.styleFrom(backgroundColor: SuperAdminTheme.primary, foregroundColor: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _showChangePlanDialog(context, api, biz),
                              icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                              label: const Text('Change Plan'),
                              style: OutlinedButton.styleFrom(foregroundColor: SuperAdminTheme.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: SuperAdminTheme.border),

                    // Key Business Info Metrics Grid
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMetricItem('Business ID', biz.id),
                              _buildMetricItem('Owner / Contact', '${biz.ownerName} (${biz.ownerPhone})'),
                              _buildMetricItem('Current Plan', biz.planName),
                              _buildMetricItem('Subscription Status', biz.status.label),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMetricItem('Subscription Start', biz.startDate.toString().split(' ').first),
                              _buildMetricItem('Subscription Expiry', biz.expiryDate.toString().split(' ').first),
                              _buildMetricItem('Total Amount Paid', '₹${biz.totalRevenue.toStringAsFixed(0)}'),
                              _buildMetricItem('Pending Balance', '₹${biz.pendingAmount.toStringAsFixed(0)}'),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMetricItem('Renewals Count', '${biz.renewalsCount} times'),
                              _buildMetricItem('Upgrades / Downgrades', '${biz.upgradesCount} / ${biz.downgradesCount}'),
                              _buildMetricItem('Active Users', '${biz.usersCount} accounts'),
                              _buildMetricItem('Team Members', '${biz.teamMembersCount} staff members'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Business Sales History & Invoice Actions
              Container(
                decoration: SuperAdminTheme.neumorphicBox(radius: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Invoice & Payment History', style: SuperAdminTheme.h3),
                          Text('${bizSales.length} Total Invoices', style: SuperAdminTheme.caption),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: SuperAdminTheme.border),
                    if (bizSales.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: Text('No transactions recorded for this business.')),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 48,
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 60,
                          headingRowColor: const WidgetStatePropertyAll(SuperAdminTheme.bg),
                          columns: const [
                            DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('INVOICE NO', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('PLAN', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('TRANSACTION ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('AMOUNT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('PAYMENT STATUS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('METHOD', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                          ],
                          rows: bizSales.map((s) {
                            return DataRow(
                              cells: [
                                DataCell(Text(s.date.toString().split(' ').first, style: const TextStyle(fontSize: 12))),
                                DataCell(Text(s.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: SuperAdminTheme.primary))),
                                DataCell(Text(s.planName, style: const TextStyle(fontSize: 12))),
                                DataCell(Text(s.transactionId, style: const TextStyle(fontSize: 11.5, color: SuperAdminTheme.textMuted))),
                                DataCell(Text('₹${s.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: SuperAdminTheme.textPrimary))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(color: s.status.bg, borderRadius: BorderRadius.circular(6)),
                                    child: Text(s.status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: s.status.color)),
                                  ),
                                ),
                                DataCell(Text(s.method.label, style: const TextStyle(fontSize: 12))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility_rounded, size: 17, color: SuperAdminTheme.primary),
                                        tooltip: 'View Invoice',
                                        onPressed: () => _viewInvoiceModal(context, s),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.download_rounded, size: 17, color: SuperAdminTheme.accent),
                                        tooltip: 'Download PDF Invoice',
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Downloaded ${s.invoiceNumber}.pdf')),
                                          );
                                        },
                                      ),
                                      if (s.status == PaymentStatus.successful)
                                        IconButton(
                                          icon: const Icon(Icons.undo_rounded, size: 17, color: SuperAdminTheme.danger),
                                          tooltip: 'Issue Refund',
                                          onPressed: () => _showRefundModal(context, api, s),
                                        ),
                                    ],
                                  ),
                                ),
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

  Widget _buildMetricItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: SuperAdminTheme.textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
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
          title: Text('Extend Subscription for ${biz.name}'),
          content: DropdownButton<int>(
            value: selectedDays,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 7, child: Text('7 Days')),
              DropdownMenuItem(value: 15, child: Text('15 Days')),
              DropdownMenuItem(value: 30, child: Text('30 Days')),
              DropdownMenuItem(value: 90, child: Text('90 Days')),
            ],
            onChanged: (val) {
              if (val != null) setModalState(() => selectedDays = val);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                api.extendSubscription(biz.id, selectedDays);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $selectedDays days to ${biz.name}')));
              },
              child: const Text('Apply'),
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
          title: Text('Change Plan for ${biz.name}'),
          content: DropdownButton<String>(
            value: selectedPlan,
            isExpanded: true,
            items: api.plans.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (₹${p.monthlyPrice}/mo)'))).toList(),
            onChanged: (val) {
              if (val != null) setModalState(() => selectedPlan = val);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                api.changeBusinessPlan(biz.id, selectedPlan);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan updated successfully')));
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _viewInvoiceModal(BuildContext context, PlatformSaleRecord sale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Invoice: ${sale.invoiceNumber}'),
            IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Billed To: ${sale.businessName} (${sale.ownerName})', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Transaction ID: ${sale.transactionId}', style: const TextStyle(fontSize: 12, color: SuperAdminTheme.textMuted)),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Plan: ${sale.planName}'),
                  Text('₹${sale.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('GST (18% Included)'),
                  Text('₹0.00', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount Paid', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  Text('₹${sale.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: SuperAdminTheme.primary)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloaded PDF for ${sale.invoiceNumber}')));
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download PDF Invoice'),
            style: ElevatedButton.styleFrom(backgroundColor: SuperAdminTheme.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showRefundModal(BuildContext context, SuperAdminApiService api, PlatformSaleRecord sale) {
    SuperAdminConfirmationDialog.show(
      context: context,
      title: 'Issue Payment Refund?',
      message: 'Are you sure you want to refund ₹${sale.amount.toStringAsFixed(0)} for ${sale.businessName}? This transaction will be marked as refunded in accounting ledger.',
      confirmLabel: 'Process Refund',
      onConfirmWithReason: (reason) async {
        api.refundSale(sale.transactionId, reason);
      },
    );
  }
}
