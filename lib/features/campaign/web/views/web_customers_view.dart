import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/services/customer_service.dart';
import '../views/campaign_dashboard_view.dart';

class WebCustomersView extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback? onNavigateToGroups;

  const WebCustomersView({
    super.key,
    required this.onBack,
    this.onNavigateToGroups,
  });

  @override
  State<WebCustomersView> createState() => _WebCustomersViewState();
}

class _WebCustomersViewState extends State<WebCustomersView> {
  final ApiClient _client = ApiClient();
  final TextEditingController _searchCtrl = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final NumberFormat _numFormat = NumberFormat.decimalPattern('en_IN');

  List<CustomerModel> _customers = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _totalCustomers = 0;
  int _currentPage = 1;
  static const int _pageSize = 25;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _currentPage = 1;
      });
      _loadCustomers();
    });
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final queryParams = {
        'search': _searchCtrl.text.trim(),
        'page': _currentPage,
        'limit': _pageSize,
      };

      final response = await _client.get(
        ApiEndpoints.customers,
        queryParameters: queryParams,
      );

      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        List<dynamic> rawCustomers = [];
        int total = 0;

        if (data is Map<String, dynamic>) {
          rawCustomers = data['customers'] as List<dynamic>? ?? [];
          final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
          total = (pagination['total'] as num?)?.toInt() ?? rawCustomers.length;
        } else if (data is List) {
          rawCustomers = data;
          total = rawCustomers.length;
        }

        final parsed = rawCustomers
            .map((c) => CustomerModel.fromJson(Map<String, dynamic>.from(c as Map)))
            .toList();

        if (mounted) {
          setState(() {
            _customers = parsed;
            _totalCustomers = total;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('[WebCustomersView] Error loading customers: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load customers. Please check your connection and retry.';
      });
    }
  }

  void _openAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            child: Container(
              width: 440,
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person_add_rounded, color: Color(0xFF0F2942), size: 22),
                            SizedBox(width: 10),
                            Text(
                              'Add New Customer',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Full Name *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Rahul Sharma',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter customer name' : null,
                    ),
                    const SizedBox(height: 14),
                    const Text('Mobile Number *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'e.g. 9876543210',
                        prefixText: '+91 ',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please enter mobile number';
                        final clean = val.trim().replaceAll(RegExp(r'[^\d]'), '');
                        if (clean.length < 10) return 'Enter a valid 10-digit number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setDialogState(() => isSaving = true);
                                  try {
                                    final clean = phoneCtrl.text.trim().replaceAll(RegExp(r'[^\d]'), '');
                                    final phone = clean.startsWith('91') && clean.length == 12 ? '+$clean' : '+91$clean';
                                    await _client.post(
                                      ApiEndpoints.customers,
                                      data: {
                                        'name': nameCtrl.text.trim(),
                                        'phone': phone,
                                      },
                                    );
                                    if (dialogCtx.mounted) {
                                      Navigator.pop(dialogCtx);
                                      _loadCustomers();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Customer added successfully!'),
                                          backgroundColor: Color(0xFF10B981),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setDialogState(() => isSaving = false);
                                    if (dialogCtx.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Could not add customer: $e'),
                                          backgroundColor: Colors.redAccent,
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF082559),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Save Customer', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openImportContactsDialog() {
    final textCtrl = TextEditingController();
    bool isImporting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final lines = textCtrl.text
              .split(RegExp(r'[\n,]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList();
          final count = lines.length;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.white,
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.upload_file_rounded, color: Color(0xFF0F2942), size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Import Customer Contacts',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Paste mobile numbers separated by new line or comma. Each valid number will be added to your customer records.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Phone Numbers', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                      Text(
                        '$count numbers detected',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: count > 0 ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: textCtrl,
                    maxLines: 6,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: 'e.g.\n9876543210\n9812345678\n+919709593705',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isImporting ? null : () => Navigator.pop(dialogCtx),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: isImporting || count == 0
                            ? null
                            : () async {
                                setDialogState(() => isImporting = true);
                                int importedCount = 0;
                                for (final line in lines) {
                                  final clean = line.replaceAll(RegExp(r'[^\d]'), '');
                                  if (clean.length >= 10) {
                                    final phone = clean.startsWith('91') && clean.length == 12 ? '+$clean' : '+91$clean';
                                    try {
                                      await _client.post(
                                        ApiEndpoints.customers,
                                        data: {
                                          'name': 'Customer',
                                          'phone': phone,
                                        },
                                      );
                                      importedCount++;
                                    } catch (_) {}
                                  }
                                }
                                if (dialogCtx.mounted) {
                                  Navigator.pop(dialogCtx);
                                  _loadCustomers();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Imported $importedCount customer contacts!'),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF082559),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: isImporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Import Contacts', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F2FC),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              // Header Row
              _buildTopBar(),

              // Customers List or State
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Color(0xFF7047D6)),
                      )
                    : _errorMessage != null && _customers.isEmpty
                        ? _buildErrorView()
                        : _buildCustomersTable(),
              ),

              // Pagination Footer
              if (!_isLoading && _customers.isNotEmpty) _buildPaginationFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                tooltip: 'Back to Campaigns',
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Customers Directory',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_numFormat.format(_totalCustomers)} Customers',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7047D6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Search, manage and group your POS customers for targeted WhatsApp campaigns.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const Spacer(),
              if (widget.onNavigateToGroups != null)
                OutlinedButton.icon(
                  onPressed: widget.onNavigateToGroups,
                  icon: const Icon(Icons.groups_rounded, size: 16),
                  label: const Text('Audience Groups'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7047D6),
                    side: const BorderSide(color: Color(0xFFDDD6FE)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _openImportContactsDialog,
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                label: const Text('Import Contacts'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF082559),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _openAddCustomerDialog,
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Add Customer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF082559),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Search by customer name or phone number...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF7047D6), width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _loadCustomers,
                tooltip: 'Refresh list',
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
          const SizedBox(height: 12),
          Text(_errorMessage!, style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadCustomers,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersTable() {
    if (_customers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline_rounded, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              _searchCtrl.text.isNotEmpty ? 'No customers found matching "${_searchCtrl.text}"' : 'No customers yet',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Add customers manually or import a contact list to send campaigns.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openAddCustomerDialog,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add First Customer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF082559),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 780;

        return RefreshIndicator(
          onRefresh: _loadCustomers,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 48, child: Text('#', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)))),
                        Expanded(flex: 3, child: Text('Customer', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)))),
                        Expanded(flex: 2, child: Text('Phone', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)))),
                        if (isWide) ...[
                          Expanded(flex: 2, child: Text('Orders Placed', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)))),
                          Expanded(flex: 2, child: Text('Total Spent', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF64748B)))),
                        ],
                      ],
                    ),
                  ),

                  // Table Rows
                  for (int i = 0; i < _customers.length; i++) _buildCustomerRow(i, _customers[i], isWide),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomerRow(int index, CustomerModel customer, bool isWide) {
    final serial = ((_currentPage - 1) * _pageSize) + index + 1;
    final name = customer.name.isNotEmpty ? customer.name : 'Customer';
    final initials = name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : const Color(0xFFFAFCFF),
        border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              '$serial',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFEDE9FE),
                  child: Text(
                    initials.isNotEmpty ? initials : 'C',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF7047D6)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (customer.email != null && customer.email!.isNotEmpty)
                        Text(
                          customer.email!,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  customer.phone.isNotEmpty ? customer.phone : '—',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                ),
              ],
            ),
          ),
          if (isWide) ...[
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${customer.totalOrders} orders',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _currencyFormat.format(customer.totalSpent),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaginationFooter() {
    final totalPages = (_totalCustomers / _pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${((_currentPage - 1) * _pageSize) + 1}–${((_currentPage - 1) * _pageSize) + _customers.length} of ${_numFormat.format(_totalCustomers)}',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 1
                    ? () {
                        setState(() => _currentPage--);
                        _loadCustomers();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                'Page $_currentPage of $totalPages',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
              IconButton(
                onPressed: _currentPage < totalPages
                    ? () {
                        setState(() => _currentPage++);
                        _loadCustomers();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
