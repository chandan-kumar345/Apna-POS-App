import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../models/super_admin_sales_model.dart';
import '../../services/super_admin_api_service.dart';
import '../../widgets/super_admin_confirmation_dialog.dart';

class SuperAdminPaymentsScreen extends StatefulWidget {
  final Function(int targetTab, String? entityId)? onNavigate;

  const SuperAdminPaymentsScreen({
    super.key,
    this.onNavigate,
  });

  @override
  State<SuperAdminPaymentsScreen> createState() => _SuperAdminPaymentsScreenState();
}

class _SuperAdminPaymentsScreenState extends State<SuperAdminPaymentsScreen> {
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
        final filteredPayments = api.sales.where((s) {
          final matchesQuery = q.isEmpty ||
              s.transactionId.toLowerCase().contains(q) ||
              s.invoiceNumber.toLowerCase().contains(q) ||
              s.businessName.toLowerCase().contains(q) ||
              s.ownerName.toLowerCase().contains(q);

          final matchesStatus = _filterStatus == 'All' ||
              s.status.label.toLowerCase() == _filterStatus.toLowerCase();

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
                      const Text('Payments & Gateway Transactions', style: SuperAdminTheme.h1),
                      const SizedBox(height: 4),
                      Text('Processed ₹${api.totalRevenue.toStringAsFixed(0)} across UPI, Cards, NetBanking and Payment Gateway', style: SuperAdminTheme.body),
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
                          hintText: 'Search by Transaction ID, Invoice Number, or Business Name...',
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
                        children: ['All', 'Successful', 'Pending', 'Failed', 'Refunded'].map((status) {
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

              // Payments Table (Section 14: Payments Table)
              Container(
                decoration: SuperAdminTheme.neumorphicBox(radius: 14),
                child: filteredPayments.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('No payment records found matching criteria.')),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 48,
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 60,
                          headingRowColor: const WidgetStatePropertyAll(SuperAdminTheme.bg),
                          columns: const [
                            DataColumn(label: Text('TRANSACTION ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('BUSINESS & USER', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('INVOICE NO', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('AMOUNT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('METHOD', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('DATE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: SuperAdminTheme.textMuted))),
                          ],
                          rows: filteredPayments.map((p) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    p.transactionId,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: SuperAdminTheme.primary),
                                  ),
                                ),
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.businessName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: SuperAdminTheme.textPrimary)),
                                      Text(p.ownerName, style: const TextStyle(fontSize: 11, color: SuperAdminTheme.textMuted)),
                                    ],
                                  ),
                                ),
                                DataCell(Text(p.invoiceNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                DataCell(Text('₹${p.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: SuperAdminTheme.textPrimary))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(p.method.icon, size: 14, color: SuperAdminTheme.textSecondary),
                                      const SizedBox(width: 6),
                                      Text(p.method.label, style: const TextStyle(fontSize: 11.5)),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(color: p.status.bg, borderRadius: BorderRadius.circular(6)),
                                    child: Text(p.status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: p.status.color)),
                                  ),
                                ),
                                DataCell(Text(p.date.toString().split(' ').first, style: const TextStyle(fontSize: 11.5, color: SuperAdminTheme.textMuted))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.receipt_rounded, size: 17, color: SuperAdminTheme.primary),
                                        tooltip: 'View Invoice Details',
                                        onPressed: () => _viewInvoice(context, p),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.download_rounded, size: 17, color: SuperAdminTheme.accent),
                                        tooltip: 'Download Invoice',
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Downloaded PDF for ${p.invoiceNumber}')),
                                          );
                                        },
                                      ),
                                      if (p.status == PaymentStatus.successful)
                                        IconButton(
                                          icon: const Icon(Icons.undo_rounded, size: 17, color: SuperAdminTheme.danger),
                                          tooltip: 'Refund Payment',
                                          onPressed: () => _showRefundModal(context, api, p),
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

  void _viewInvoice(BuildContext context, PlatformSaleRecord p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Payment Transaction: ${p.transactionId}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice: ${p.invoiceNumber}'),
            const SizedBox(height: 6),
            Text('Business: ${p.businessName} (${p.ownerName})'),
            const SizedBox(height: 6),
            Text('Payment Method: ${p.method.label}'),
            const SizedBox(height: 6),
            Text('Status: ${p.status.label}', style: TextStyle(fontWeight: FontWeight.w700, color: p.status.color)),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Amount Settled', style: TextStyle(fontWeight: FontWeight.w700)),
                Text('₹${p.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: SuperAdminTheme.primary)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported ${p.invoiceNumber}')));
            },
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: SuperAdminTheme.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showRefundModal(BuildContext context, SuperAdminApiService api, PlatformSaleRecord p) {
    SuperAdminConfirmationDialog.show(
      context: context,
      title: 'Refund Payment: ${p.transactionId}',
      message: 'Issue a refund of ₹${p.amount.toStringAsFixed(0)} to ${p.businessName}? This is logged to audit trail.',
      confirmLabel: 'Issue Refund',
      onConfirmWithReason: (reason) async {
        api.refundSale(p.transactionId, reason);
      },
    );
  }
}
