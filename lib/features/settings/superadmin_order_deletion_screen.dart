import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';

class SuperAdminOrderDeletionScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onNavigateToDashboard;

  const SuperAdminOrderDeletionScreen({
    super.key,
    this.onOpenDrawer,
    this.onNavigateToDashboard,
  });

  @override
  State<SuperAdminOrderDeletionScreen> createState() => _SuperAdminOrderDeletionScreenState();
}

class _SuperAdminOrderDeletionScreenState extends State<SuperAdminOrderDeletionScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _orderNumberController = TextEditingController();
  final TextEditingController _listSearchController = TextEditingController();

  OrderModel? _matchedOrder;
  bool _isDeleting = false;
  bool _isSyncing = false;
  bool _isFinding = false;
  bool _hasSearched = false;
  String _selectedStatusTab = 'All';
  String? _selectedProfileId;

  @override
  void initState() {
    super.initState();
    _db.addListener(_onDbChange);
    _selectedProfileId = _db.currentUser?.id ?? _db.restaurant?.id;
    _syncLatestOrders();
  }

  Future<void> _syncLatestOrders() async {
    if (!mounted) return;
    setState(() => _isSyncing = true);
    try {
      await _db.syncWithBackend();
    } catch (_) {}
    if (mounted) {
      setState(() => _isSyncing = false);
    }
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChange);
    _orderNumberController.dispose();
    _listSearchController.dispose();
    super.dispose();
  }

  void _onDbChange() {
    if (mounted) setState(() {});
  }

  Future<void> _findOrderByNumber(String query) async {
    final clean = query.replaceAll(RegExp(r'[^0-9]'), '').trim();
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a 10-digit numeric order number'),
          backgroundColor: Color(0xFFEA580C),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isFinding = true;
      _hasSearched = true;
    });

    // 1. Search locally
    OrderModel? match = _db.orders.where((o) {
      final oNum = o.orderNumber.replaceAll(RegExp(r'[^0-9]'), '').trim();
      final oId = o.id.replaceAll(RegExp(r'[^0-9]'), '').trim();
      return oNum == clean || oId == clean || o.orderNumber.contains(clean);
    }).firstOrNull;

    // 2. If not found locally, sync with backend & recheck
    if (match == null) {
      try {
        await _db.syncWithBackend();
        match = _db.orders.where((o) {
          final oNum = o.orderNumber.replaceAll(RegExp(r'[^0-9]'), '').trim();
          final oId = o.id.replaceAll(RegExp(r'[^0-9]'), '').trim();
          return oNum == clean || oId == clean || o.orderNumber.contains(clean);
        }).firstOrNull;
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isFinding = false;
        _matchedOrder = match;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      final text = data.text!.replaceAll(RegExp(r'[^0-9]'), '').trim();
      _orderNumberController.text = text;
      _findOrderByNumber(text);
    }
  }

  Future<void> _confirmAndDeleteOrder(OrderModel order) async {
    final orderNumDisplay = order.orderNumber.startsWith('#') ? order.orderNumber : '#${order.orderNumber}';
    final currency = _db.restaurant?.currencySymbol ?? '₹';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Red Alert Icon Box
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: Color(0xFFDC2626),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title & Warning Text
                  const Text(
                    'Delete Order Permanently?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                      children: [
                        const TextSpan(text: 'Are you sure you want to delete '),
                        TextSpan(
                          text: orderNumDisplay,
                          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                        TextSpan(
                          text: ' ($currency${order.effectiveTotalAmount.toStringAsFixed(0)})',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                        ),
                        const TextSpan(
                          text: ' from the database & cloud server? Once deleted, this order will be permanently purged and will ',
                        ),
                        const TextSpan(
                          text: 'NOT appear in Sales Reports, Dashboard, or Database records.',
                          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Delete Now', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      setState(() => _isDeleting = true);

      final success = await _db.deleteOrderByOrderNumber(
        orderNumber: order.orderNumber.isNotEmpty ? order.orderNumber : order.id,
        targetUserId: _selectedProfileId,
        targetRestaurantId: _db.restaurant?.id,
      );

      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _matchedOrder = null;
        _orderNumberController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  success
                      ? '$orderNumDisplay deleted successfully! Sales reports updated.'
                      : 'Order removed from database and web backend.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _confirmAndDeleteEnteredNumber(String rawNumber) async {
    final clean = rawNumber.trim();
    if (clean.isEmpty) return;
    final orderNumDisplay = clean.startsWith('#') ? clean : '#$clean';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: Color(0xFFDC2626),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Direct Purge by Order Number',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
                      children: [
                        const TextSpan(text: 'Permanently delete and purge '),
                        TextSpan(
                          text: orderNumDisplay,
                          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                        const TextSpan(
                          text: ' across local database and web backend server? It will be permanently removed and excluded from Sales Reports.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Purge Now', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      setState(() => _isDeleting = true);

      final success = await _db.deleteOrderByOrderNumber(
        orderNumber: clean,
        targetUserId: _selectedProfileId,
        targetRestaurantId: _db.restaurant?.id,
      );

      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _matchedOrder = null;
        _orderNumberController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  success
                      ? '$orderNumDisplay purged from database and web server.'
                      : 'Purge command sent for $orderNumDisplay.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  String _formatDateTime(dynamic dt) {
    try {
      if (dt == null) return '';
      final parsed = dt is DateTime ? dt : DateTime.tryParse(dt.toString()) ?? DateTime.now();
      return DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
    } catch (_) {
      return dt.toString();
    }
  }

  String _getOrderTypeLabel(OrderType type) {
    switch (type) {
      case OrderType.dineIn:
        return 'Dine-In';
      case OrderType.takeaway:
        return 'Takeaway';
      case OrderType.delivery:
        return 'Delivery';
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.preparing:
        return const Color(0xFFEA580C);
      case OrderStatus.ready:
        return const Color(0xFF10B981);
      case OrderStatus.completed:
        return const Color(0xFF2563EB);
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }

  List<OrderModel> _getFilteredOrders() {
    final listQuery = _listSearchController.text.replaceAll(RegExp(r'^#'), '').trim().toLowerCase();
    return _db.orders.where((o) {
      // 1. Status Filter
      if (_selectedStatusTab == 'Completed' && o.status != OrderStatus.completed) return false;
      if (_selectedStatusTab == 'Cancelled' && o.status != OrderStatus.cancelled) return false;
      if (_selectedStatusTab == 'Pending' && (o.status == OrderStatus.completed || o.status == OrderStatus.cancelled)) return false;

      // 2. Search query in list
      if (listQuery.isNotEmpty) {
        final on = o.orderNumber.replaceAll(RegExp(r'^#'), '').toLowerCase();
        final oid = o.id.toLowerCase();
        final cname = (o.customerName ?? '').toLowerCase();
        final cphone = (o.customerPhone ?? '').toLowerCase();
        final tbl = (o.tableNumber ?? '').toLowerCase();
        final itemsStr = o.items.map((i) => i.item.name.toLowerCase()).join(' ');

        if (!on.contains(listQuery) &&
            !oid.contains(listQuery) &&
            !cname.contains(listQuery) &&
            !cphone.contains(listQuery) &&
            !tbl.contains(listQuery) &&
            !itemsStr.contains(listQuery)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final currency = _db.restaurant?.currencySymbol ?? '₹';
    final user = _db.currentUser;
    final rest = _db.restaurant;
    final allOrders = _getFilteredOrders();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF051C48),
        elevation: 0,
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                tooltip: 'Toggle Navigation',
                onPressed: widget.onOpenDrawer,
              )
            : (Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 19),
                    onPressed: () => Navigator.pop(context),
                  )
                : (widget.onNavigateToDashboard != null
                    ? IconButton(
                        icon: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                        tooltip: 'Back to Dashboard',
                        onPressed: widget.onNavigateToDashboard,
                      )
                    : null)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF60A5FA).withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF60A5FA), size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Super Admin Database',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Purge Orders & Sync Web Server',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sync Database with Cloud Server',
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
            onPressed: _isSyncing ? null : _syncLatestOrders,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 960;

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 24 : 16,
                  vertical: 16,
                ),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Profile Card + Search & Purge Tools
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildProfileContextCard(rest, user),
                                const SizedBox(height: 16),
                                _buildOrderLookupBox(),
                                const SizedBox(height: 16),
                                if (_matchedOrder != null) ...[
                                  _buildMatchedOrderCard(_matchedOrder!, currency),
                                ] else if (_hasSearched && _orderNumberController.text.trim().isNotEmpty) ...[
                                  _buildDirectPurgeNotFoundCard(_orderNumberController.text.trim()),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Right Column: Database Orders Browser
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildDatabaseOrdersHeader(allOrders),
                                const SizedBox(height: 10),
                                _buildListSearchAndFilterTabs(),
                                const SizedBox(height: 12),
                                _buildOrdersListView(allOrders, currency),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProfileContextCard(rest, user),
                          const SizedBox(height: 16),
                          _buildOrderLookupBox(),
                          const SizedBox(height: 16),
                          if (_matchedOrder != null) ...[
                            _buildMatchedOrderCard(_matchedOrder!, currency),
                            const SizedBox(height: 20),
                          ] else if (_hasSearched && _orderNumberController.text.trim().isNotEmpty) ...[
                            _buildDirectPurgeNotFoundCard(_orderNumberController.text.trim()),
                            const SizedBox(height: 20),
                          ],
                          _buildDatabaseOrdersHeader(allOrders),
                          const SizedBox(height: 10),
                          _buildListSearchAndFilterTabs(),
                          const SizedBox(height: 12),
                          _buildOrdersListView(allOrders, currency),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileContextCard(dynamic rest, dynamic user) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: const Icon(Icons.storefront_rounded, color: Color(0xFF2563EB), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rest?.name ?? user?.companyName ?? 'Active Store Profile',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'User: ${user?.name ?? "Owner"} (${user?.role ?? "SuperAdmin"}) • ${user?.email ?? ""}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderLookupBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Find & Delete Order',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter 10-digit numeric order number and click Find to view complete details before deleting from database.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: _orderNumberController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onSubmitted: (val) => _findOrderByNumber(val),
                    decoration: InputDecoration(
                      hintText: 'Enter 10-digit numeric order # (e.g. 1000001001)',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.pin_rounded, color: Color(0xFF2563EB), size: 20),
                      suffixIcon: _orderNumberController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _orderNumberController.clear();
                                setState(() {
                                  _matchedOrder = null;
                                  _hasSearched = false;
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isFinding ? null : () => _findOrderByNumber(_orderNumberController.text.trim()),
                icon: _isFinding
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search_rounded, size: 18, color: Colors.white),
                label: const Text('Find', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _pasteFromClipboard,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.content_paste_rounded, size: 16, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text(
                        'Paste',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDirectPurgeNotFoundCard(String query) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEA580C).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEDD5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_off_rounded, color: Color(0xFFEA580C), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order "$query" Not in Local Cache',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'If this order exists on the cloud/web backend, you can directly purge it below.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _isDeleting ? null : () => _confirmAndDeleteEnteredNumber(query),
            icon: const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.white),
            label: Text(
              'Force Purge "$query" from Database',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseOrdersHeader(List<OrderModel> allOrders) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Orders in Database',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        Text(
          '${allOrders.length} ${allOrders.length == 1 ? "Record" : "Records"}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildListSearchAndFilterTabs() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: _listSearchController,
            onChanged: (val) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Filter by order #, table, customer, items...',
              hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              prefixIcon: Icon(Icons.filter_list_rounded, color: Color(0xFF64748B), size: 18),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: ['All', 'Completed', 'Cancelled', 'Pending'].map((tab) {
              final isSelected = _selectedStatusTab == tab;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(tab),
                  selected: isSelected,
                  selectedColor: const Color(0xFF051C48),
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF051C48) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  onSelected: (val) {
                    setState(() => _selectedStatusTab = tab);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersListView(List<OrderModel> allOrders, String currency) {
    if (allOrders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: const [
            Icon(Icons.inbox_rounded, size: 40, color: Color(0xFFCBD5E1)),
            SizedBox(height: 8),
            Text(
              'No orders in database',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: allOrders.map((order) {
        return _buildOrderListItem(order, currency);
      }).toList(),
    );
  }

  Widget _buildMatchedOrderCard(OrderModel order, String currency) {
    final statusColor = _getStatusColor(order.status);
    final orderNumDisplay = order.orderNumber.startsWith('#') ? order.orderNumber : '#${order.orderNumber}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                orderNumDisplay,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: order.isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: order.isPaid ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      order.isPaid ? 'PAID' : 'UNPAID',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: order.isPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      order.status.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_getOrderTypeLabel(order.orderType)}${order.tableNumber != null && order.tableNumber!.isNotEmpty ? " • Table ${order.tableNumber}" : ""} • ${_formatDateTime(order.createdDateTime)}',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          ...order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                children: [
                  Text('${item.quantity} × ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF2563EB))),
                  Expanded(
                    child: Text(
                      item.item.name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('$currency ${(item.totalPrice).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0F172A))),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              Text(
                '$currency ${order.effectiveTotalAmount.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          if (order.paymentMethod.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Payment: ${order.paymentMethod.toUpperCase()}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isDeleting ? null : () => _confirmAndDeleteOrder(order),
            icon: const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.white),
            label: const Text(
              'Delete Order from Database & Backend',
              style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderListItem(OrderModel order, String currency) {
    final statusColor = _getStatusColor(order.status);
    final orderNumDisplay = order.orderNumber.startsWith('#') ? order.orderNumber : '#${order.orderNumber}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Icon(
              order.orderType == OrderType.dineIn
                  ? Icons.restaurant_rounded
                  : (order.orderType == OrderType.takeaway ? Icons.shopping_bag_outlined : Icons.delivery_dining_rounded),
              size: 16,
              color: const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      orderNumDisplay,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        order.status.name.toUpperCase(),
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDateTime(order.createdDateTime)} • ${order.items.length} ${order.items.length == 1 ? "Item" : "Items"}',
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$currency ${(order.effectiveTotalAmount).toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: () => _confirmAndDeleteOrder(order),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}
