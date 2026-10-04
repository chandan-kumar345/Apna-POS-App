import 'package:flutter/material.dart';
import '../theme/super_admin_theme.dart';
import '../services/super_admin_api_service.dart';

class SuperAdminGlobalSearchDialog extends StatefulWidget {
  final Function(int targetTab, String? entityId)? onNavigate;

  const SuperAdminGlobalSearchDialog({
    super.key,
    this.onNavigate,
  });

  static Future<void> show(BuildContext context, {Function(int targetTab, String? entityId)? onNavigate}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => SuperAdminGlobalSearchDialog(onNavigate: onNavigate),
    );
  }

  @override
  State<SuperAdminGlobalSearchDialog> createState() => _SuperAdminGlobalSearchDialogState();
}

class _SuperAdminGlobalSearchDialogState extends State<SuperAdminGlobalSearchDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = SuperAdminApiService();
    final q = _query.toLowerCase().trim();

    // Filter Groups
    final matchedUsers = q.isEmpty
        ? []
        : api.users.where((u) =>
            u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            u.phone.contains(q) ||
            u.id.toLowerCase().contains(q)).toList();

    final matchedBusinesses = q.isEmpty
        ? []
        : api.businesses.where((b) =>
            b.name.toLowerCase().contains(q) ||
            b.ownerName.toLowerCase().contains(q) ||
            b.city.toLowerCase().contains(q) ||
            b.id.toLowerCase().contains(q)).toList();

    final matchedSales = q.isEmpty
        ? []
        : api.sales.where((s) =>
            s.transactionId.toLowerCase().contains(q) ||
            s.invoiceNumber.toLowerCase().contains(q) ||
            s.businessName.toLowerCase().contains(q)).toList();

    final matchedTickets = q.isEmpty
        ? []
        : api.tickets.where((t) =>
            t.ticketCode.toLowerCase().contains(q) ||
            t.subject.toLowerCase().contains(q) ||
            t.businessName.toLowerCase().contains(q)).toList();

    final hasResults = matchedUsers.isNotEmpty ||
        matchedBusinesses.isNotEmpty ||
        matchedSales.isNotEmpty ||
        matchedTickets.isNotEmpty;

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 80, left: 24, right: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: SuperAdminTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: SuperAdminTheme.modalShadow,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Search Input Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: SuperAdminTheme.border)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: SuperAdminTheme.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: SuperAdminTheme.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search businesses, users, transactions, tickets, or phone...',
                        hintStyle: TextStyle(fontSize: 14, color: SuperAdminTheme.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _query = val;
                        });
                      },
                    ),
                  ),
                  if (_query.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: SuperAdminTheme.textMuted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                        });
                      },
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: SuperAdminTheme.bg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: SuperAdminTheme.border),
                    ),
                    child: const Text(
                      'ESC to close',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: SuperAdminTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),

            // Search Results Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _query.isEmpty
                    ? _buildQuickSuggestions()
                    : !hasResults
                        ? _buildNoResults()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Businesses
                              if (matchedBusinesses.isNotEmpty) ...[
                                _buildCategoryHeader('Businesses', Icons.storefront_rounded, matchedBusinesses.length),
                                ...matchedBusinesses.map((b) => _buildResultRow(
                                      title: b.name,
                                      subtitle: '${b.ownerName} • ${b.city} • Plan: ${b.planName}',
                                      badgeText: b.status.label,
                                      badgeColor: b.status.color,
                                      badgeBg: b.status.bg,
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        widget.onNavigate?.call(2, b.id); // Tab 2 = Businesses
                                      },
                                    )),
                                const SizedBox(height: 12),
                              ],

                              // Users
                              if (matchedUsers.isNotEmpty) ...[
                                _buildCategoryHeader('Users', Icons.people_rounded, matchedUsers.length),
                                ...matchedUsers.map((u) => _buildResultRow(
                                      title: u.name,
                                      subtitle: '${u.email} • ${u.phone} • ${u.businessName}',
                                      badgeText: u.role,
                                      badgeColor: SuperAdminTheme.primary,
                                      badgeBg: SuperAdminTheme.primaryLight,
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        widget.onNavigate?.call(1, u.id); // Tab 1 = Users
                                      },
                                    )),
                                const SizedBox(height: 12),
                              ],

                              // Transactions & Invoices
                              if (matchedSales.isNotEmpty) ...[
                                _buildCategoryHeader('Transactions & Invoices', Icons.receipt_long_rounded, matchedSales.length),
                                ...matchedSales.map((s) => _buildResultRow(
                                      title: '${s.invoiceNumber} (${s.transactionId})',
                                      subtitle: '${s.businessName} • ₹${s.amount.toStringAsFixed(0)} • Method: ${s.method.label}',
                                      badgeText: s.status.label,
                                      badgeColor: s.status.color,
                                      badgeBg: s.status.bg,
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        widget.onNavigate?.call(6, s.transactionId); // Tab 6 = Payments
                                      },
                                    )),
                                const SizedBox(height: 12),
                              ],

                              // Support Tickets
                              if (matchedTickets.isNotEmpty) ...[
                                _buildCategoryHeader('Support Tickets', Icons.support_agent_rounded, matchedTickets.length),
                                ...matchedTickets.map((t) => _buildResultRow(
                                      title: '#${t.ticketCode} - ${t.subject}',
                                      subtitle: '${t.businessName} • ${t.category} • Priority: ${t.priority.label}',
                                      badgeText: t.status.label,
                                      badgeColor: t.status.color,
                                      badgeBg: t.status.bg,
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        widget.onNavigate?.call(10, t.id); // Tab 10 = Support
                                      },
                                    )),
                              ],
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String title, IconData icon, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: SuperAdminTheme.textMuted),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: SuperAdminTheme.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: SuperAdminTheme.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SuperAdminTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow({
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      hoverColor: SuperAdminTheme.bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: SuperAdminTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: SuperAdminTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Quick Shortcuts',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textMuted),
        ),
        SizedBox(height: 10),
        ListTile(
          dense: true,
          leading: Icon(Icons.flash_on_rounded, color: SuperAdminTheme.warning, size: 20),
          title: Text('Search by Business ID (e.g. biz_101)', style: TextStyle(fontSize: 13)),
          subtitle: Text('Directly jump to any restaurant profile and billing ledger', style: TextStyle(fontSize: 11.5)),
        ),
        ListTile(
          dense: true,
          leading: Icon(Icons.receipt_rounded, color: SuperAdminTheme.primary, size: 20),
          title: Text('Search by Transaction ID (e.g. TXN_99812401)', style: TextStyle(fontSize: 13)),
          subtitle: Text('Instantly inspect invoices and issue refunds', style: TextStyle(fontSize: 11.5)),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.search_off_rounded, size: 42, color: SuperAdminTheme.textMuted),
            const SizedBox(height: 12),
            const Text(
              'No matching records found',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'No results matching "$_query". Try searching by name, email, or invoice number.',
              style: const TextStyle(fontSize: 12.5, color: SuperAdminTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
