import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';
import '../../core/models/table_model.dart';
import 'order_detail_sheet.dart';
import '../pos/receipt_dialog.dart';
import '../pos/payment_modal.dart';
import '../../core/services/bluetooth_printer_service.dart';
import '../../core/widgets/printer_selection_dialog.dart';

class OrdersScreen extends StatefulWidget {
  final Function(String tableName)? onOpenPosForTable;
  final String? initialOrderId;
  final String? initialOrderNumber;
  final bool showBackButton;

  const OrdersScreen({
    super.key,
    this.onOpenPosForTable,
    this.initialOrderId,
    this.initialOrderNumber,
    this.showBackButton = false,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final db = DatabaseService();

  // REMOVED 'All' OPTION; DEFAULT TO 'DineIn' & 'Preparing'
  String _selectedOrderTypeFilter = 'DineIn'; // 'DineIn', 'TakeAway', 'Delivery'
  String _selectedStatusFilter = 'Preparing'; // 'Pending', 'Preparing', 'Ready', 'Completed', 'Cancelled'
  String _searchQuery = '';
  bool _isManualRefreshing = false;
  bool _hasCheckedInitialOrder = false;

  @override
  void initState() {
    super.initState();
    db.addListener(_onDbChange);
    db.syncWithBackend().then((_) {
      if (mounted) _checkInitialOrder();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialOrder();
    });
  }

  void _checkInitialOrder() {
    if (_hasCheckedInitialOrder) return;
    if (widget.initialOrderId == null && widget.initialOrderNumber == null) return;

    final targetId = widget.initialOrderId?.trim().toLowerCase();
    final targetNum = widget.initialOrderNumber?.trim().toLowerCase();

    final matched = db.orders.firstWhere(
      (o) =>
          (targetId != null &&
              (o.id.toLowerCase() == targetId || o.orderNumber.toLowerCase() == targetId)) ||
          (targetNum != null && o.orderNumber.toLowerCase() == targetNum),
      orElse: () => OrderModel(
        id: '',
        orderNumber: '',
        items: const [],
        subtotal: 0,
        taxAmount: 0,
        totalAmount: 0,
        createdAt: '',
      ),
    );

    if (matched.id.isNotEmpty && mounted) {
      _hasCheckedInitialOrder = true;
      setState(() {
        if (matched.orderType == OrderType.takeaway) {
          _selectedOrderTypeFilter = 'TakeAway';
        } else if (matched.orderType == OrderType.delivery) {
          _selectedOrderTypeFilter = 'Delivery';
        } else {
          _selectedOrderTypeFilter = 'DineIn';
        }

        if (matched.status == OrderStatus.completed) {
          _selectedStatusFilter = 'Completed';
        } else if (matched.status == OrderStatus.ready) {
          _selectedStatusFilter = 'Ready';
        } else if (matched.status == OrderStatus.cancelled) {
          _selectedStatusFilter = 'Cancelled';
        } else if (matched.status == OrderStatus.pending) {
          _selectedStatusFilter = 'Pending';
        } else {
          _selectedStatusFilter = 'Preparing';
        }

        _searchQuery = matched.orderNumber;
      });

      // Automatically open the detailed order bottom sheet dialog
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          OrderDetailSheet.show(context, initialOrder: matched);
        }
      });
    }
  }

  Future<void> _refreshOrders() async {
    setState(() => _isManualRefreshing = true);
    await db.syncWithBackend();
    if (mounted) {
      setState(() => _isManualRefreshing = false);
    }
  }

  Future<void> _settleOrderFromList(OrderModel order) async {
    final currency = db.restaurant?.currencySymbol ?? '₹';
    final modalResult = await showDialog<dynamic>(
      context: context,
      builder: (_) => PaymentModal(
        order: order,
        currency: currency,
      ),
    );

    if (modalResult != null) {
      final String resultMethod = modalResult is PaymentModalResult
          ? modalResult.paymentMethod
          : modalResult.toString();
      final double? roundOff = modalResult is PaymentModalResult ? modalResult.roundOff : null;
      final double? totalAmount = modalResult is PaymentModalResult ? modalResult.totalAmount : null;

      if (resultMethod.isNotEmpty) {
        final completedOrder = await db.settleOrder(
          orderId: order.id,
          paymentMethod: resultMethod,
          totalAmount: totalAmount ?? order.totalAmount,
          roundOff: roundOff ?? 0.0,
        );

        if (!mounted) return;
        showDialog(
          context: context,
          useRootNavigator: true,
          barrierDismissible: true,
          builder: (_) => ReceiptDialog(order: completedOrder, currency: currency),
        );
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    db.removeListener(_onDbChange);
    super.dispose();
  }

  void _onDbChange() {
    if (mounted) setState(() {});
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B); // Amber
      case OrderStatus.preparing:
        return const Color(0xFF051C48); // Theme Navy
      case OrderStatus.ready:
        return const Color(0xFF10B981); // Emerald Green
      case OrderStatus.completed:
        return const Color(0xFF051C48); // Theme Navy
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444); // Red
    }
  }

  String _getStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _getOrderTypeLabel(OrderType type) {
    switch (type) {
      case OrderType.dineIn:
        return 'DineIn';
      case OrderType.takeaway:
        return 'TakeAway';
      case OrderType.delivery:
        return 'Delivery';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = db.restaurant?.currencySymbol ?? '₹';

    return ListenableBuilder(
      listenable: db,
      builder: (context, _) {
        // Filter orders by OrderType (NO 'All' option)
        List<OrderModel> typeFilteredOrders = db.orders.where((o) {
          if (_selectedOrderTypeFilter == 'Delivery') return o.orderType == OrderType.delivery;
          if (_selectedOrderTypeFilter == 'DineIn') return o.orderType == OrderType.dineIn;
          if (_selectedOrderTypeFilter == 'TakeAway') return o.orderType == OrderType.takeaway;
          return true;
        }).toList();

        // RUNNING KOT AUTOMATICALLY LOGIC FOR PREPARING
        int countForStatus(OrderStatus s) {
          return typeFilteredOrders.where((o) {
            if (s == OrderStatus.preparing) {
              final isRunningKotTable = o.tableNumber != null &&
                  db.tables.any((t) => (t.name == o.tableNumber || t.tableNumber.toString() == o.tableNumber) && t.status == TableStatus.runningKot);
              return o.status == OrderStatus.preparing || (isRunningKotTable && o.status == OrderStatus.pending);
            }
            return o.status == s;
          }).length;
        }

        final pendingCount = countForStatus(OrderStatus.pending);
        final preparingCount = countForStatus(OrderStatus.preparing);
        final readyCount = countForStatus(OrderStatus.ready);
        final completedCount = countForStatus(OrderStatus.completed);
        final cancelledCount = countForStatus(OrderStatus.cancelled);

        // Filter orders by selected status with Running KOT auto-classification
        List<OrderModel> filteredOrders = typeFilteredOrders.where((o) {
          if (_selectedStatusFilter == 'Pending') return o.status == OrderStatus.pending;
          if (_selectedStatusFilter == 'Preparing') {
            final isRunningKotTable = o.tableNumber != null &&
                db.tables.any((t) => (t.name == o.tableNumber || t.tableNumber.toString() == o.tableNumber) && t.status == TableStatus.runningKot);
            return o.status == OrderStatus.preparing || (isRunningKotTable && o.status == OrderStatus.pending);
          }
          if (_selectedStatusFilter == 'Ready') return o.status == OrderStatus.ready;
          if (_selectedStatusFilter == 'Completed') return o.status == OrderStatus.completed;
          if (_selectedStatusFilter == 'Cancelled') return o.status == OrderStatus.cancelled;
          return true;
        }).toList();

        // Search Filter
        if (_searchQuery.trim().isNotEmpty) {
          final q = _searchQuery.toLowerCase().trim();
          filteredOrders = filteredOrders.where((o) {
            final matchesNum = o.orderNumber.toLowerCase().contains(q);
            final matchesTable = (o.tableNumber ?? '').toLowerCase().contains(q);
            final matchesAddress = (o.deliveryAddress ?? '').toLowerCase().contains(q);
            return matchesNum || matchesTable || matchesAddress;
          }).toList();
        }

        // Sort latest orders first
        filteredOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar: Clean Title with Back & Refresh Action
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                  child: Row(
                    children: [
                      if (Navigator.of(context).canPop() || widget.showBackButton) ...[
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF051C48), size: 20),
                          tooltip: 'Back',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Expanded(
                        child: Text(
                          'All Received Orders',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _isManualRefreshing ? null : _refreshOrders,
                        icon: _isManualRefreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF051C48)),
                              )
                            : const Icon(Icons.refresh_rounded, color: Color(0xFF051C48), size: 22),
                        tooltip: 'Refresh Orders from Server',
                      ),
                    ],
                  ),
                ),

                // 1) Order Type Section Chips (NO 'All' OPTION)
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: ['DineIn', 'TakeAway', 'Delivery'].map((type) {
                      final isSel = _selectedOrderTypeFilter == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(type),
                          selected: isSel,
                          selectedColor: const Color(0xFF051C48),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: isSel ? const Color(0xFF051C48) : const Color(0xFFCBD5E1), width: isSel ? 1.5 : 1),
                          labelStyle: TextStyle(color: isSel ? Colors.white : const Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 13),
                          onSelected: (_) {
                            setState(() {
                              _selectedOrderTypeFilter = type;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 10),

                // 2) Order Status Pills Row (NO 'All' OPTION)
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildStatusPill('Pending', '⏳ Pending', pendingCount, const Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      _buildStatusPill('Preparing', '👨‍🍳 Preparing', preparingCount, const Color(0xFF051C48)),
                      const SizedBox(width: 8),
                      _buildStatusPill('Ready', '🔔 Ready', readyCount, const Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      _buildStatusPill('Completed', '✅ Completed', completedCount, const Color(0xFF051C48)),
                      const SizedBox(width: 8),
                      _buildStatusPill('Cancelled', '❌ Cancelled', cancelledCount, const Color(0xFFEF4444)),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 3) Search Bar Field with Semi-Curved Corners
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search orders by Order #, Table or Address...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF051C48), size: 22),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFF051C48), width: 2),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 4) Responsive Order Cards with Pull to Refresh
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshOrders,
                    color: const Color(0xFF051C48),
                    child: filteredOrders.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.shopping_cart_outlined, size: 48, color: Color(0xFF94A3B8)),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'No $_selectedStatusFilter $_selectedOrderTypeFilter Orders',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'New active orders will automatically show here',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 650;
                            return ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: isWide
                                  ? (filteredOrders.length / 2).ceil()
                                  : filteredOrders.length,
                              itemBuilder: (context, rowIdx) {
                                Widget buildCard(OrderModel order) {
                                  final isRunningKot = order.tableNumber != null &&
                                      db.tables.any((t) =>
                                          (t.name == order.tableNumber ||
                                              t.tableNumber.toString() == order.tableNumber) &&
                                          t.status == TableStatus.runningKot);
                                  final effectiveStatus = (isRunningKot && order.status == OrderStatus.pending) ? OrderStatus.preparing : order.status;
                                  final statusColor = _getStatusColor(effectiveStatus);

                                  return InkWell(
                                    onTap: () => OrderDetailSheet.show(context, initialOrder: order),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 0),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                    padding: const EdgeInsets.all(11),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Header: Order #, Type Badge, Status Badge
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                '#${order.orderNumber}',
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF051C48).withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(7),
                                                border: Border.all(color: const Color(0xFF051C48).withOpacity(0.2)),
                                              ),
                                              child: Text(
                                                '${_getOrderTypeLabel(order.orderType)}${order.tableNumber != null && order.orderType == OrderType.dineIn ? " (${order.tableNumber})" : ""}',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF051C48)),
                                              ),
                                            ),
                                            if (order.printCount > 0) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF051C48).withOpacity(0.06),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'P#${order.printCount}',
                                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF051C48)),
                                                ),
                                              ),
                                            ],
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: order.isPaid
                                                    ? const Color(0xFF10B981).withOpacity(0.12)
                                                    : const Color(0xFFF59E0B).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(7),
                                                border: Border.all(
                                                  color: order.isPaid
                                                      ? const Color(0xFF10B981).withOpacity(0.4)
                                                      : const Color(0xFFF59E0B).withOpacity(0.4),
                                                ),
                                              ),
                                              child: Text(
                                                order.isPaid ? 'PAID' : 'UNPAID',
                                                style: TextStyle(
                                                  color: order.isPaid ? const Color(0xFF10B981) : const Color(0xFFD97706),
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(9),
                                                border: Border.all(color: statusColor.withOpacity(0.4)),
                                              ),
                                              child: Text(
                                                _getStatusLabel(effectiveStatus),
                                                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900),
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 7),
                                        const Divider(color: Color(0xFFF1F5F9), height: 1),
                                        const SizedBox(height: 7),

                                        // Items list — Column, no fixed height
                                        ...order.items.map((item) => Padding(
                                              padding: const EdgeInsets.only(bottom: 3),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    '${item.quantity}×',
                                                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF051C48), fontSize: 12),
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Expanded(
                                                    child: Text(
                                                      item.item.name,
                                                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Text(
                                                    '$currency ${item.totalPrice.toStringAsFixed(0)}',
                                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            )),

                                        const SizedBox(height: 7),
                                        const Divider(color: Color(0xFFF1F5F9), height: 1),
                                        const SizedBox(height: 7),

                                        // Footer: Total & Action Buttons
                                        Row(
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Total', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                                                Text(
                                                  '$currency ${order.totalAmount.toStringAsFixed(0)}',
                                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF051C48)),
                                                ),
                                              ],
                                            ),
                                            const Spacer(),
                                            if (order.tableNumber != null &&
                                                order.tableNumber!.trim().isNotEmpty &&
                                                (effectiveStatus == OrderStatus.pending ||
                                                    effectiveStatus == OrderStatus.preparing))
                                              Padding(
                                                padding: const EdgeInsets.only(right: 6),
                                                child: InkWell(
                                                  onTap: () {
                                                    if (widget.onOpenPosForTable != null) {
                                                      widget.onOpenPosForTable!(order.tableNumber!);
                                                    }
                                                  },
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF051C48).withOpacity(0.08),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0xFF051C48).withOpacity(0.3)),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.point_of_sale_rounded, size: 12, color: Color(0xFF051C48)),
                                                        SizedBox(width: 3),
                                                        Text('POS', style: TextStyle(color: Color(0xFF051C48), fontSize: 11, fontWeight: FontWeight.bold)),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            // KOT Button
                                            InkWell(
                                              onTap: () async {
                                                final printerService = BluetoothPrinterService();
                                                final bool isConnected = await printerService.isConnected();
                                                if (!context.mounted) return;

                                                if (isConnected) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Printing KOT Ticket...'),
                                                      backgroundColor: Color(0xFFD97706),
                                                      duration: Duration(seconds: 2),
                                                    ),
                                                  );
                                                  final rest = DatabaseService().restaurant;
                                                  final success = await printerService.printKOT(order: order, restaurant: rest);
                                                  if (context.mounted && !success) {
                                                    PrinterSelectionDialog.show(context, orderToPrint: order, currency: currency);
                                                  }
                                                } else {
                                                  final bool reconnected = await printerService.autoConnectSavedPrinter();
                                                  if (reconnected) {
                                                    final rest = DatabaseService().restaurant;
                                                    await printerService.printKOT(order: order, restaurant: rest);
                                                  } else if (context.mounted) {
                                                    PrinterSelectionDialog.show(context, orderToPrint: order, currency: currency);
                                                  }
                                                }
                                              },
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFD97706).withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: const Color(0xFFD97706).withOpacity(0.4)),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.soup_kitchen_rounded, size: 12, color: Color(0xFFD97706)),
                                                    SizedBox(width: 3),
                                                    Text('KOT', style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            // Bill Button
                                            InkWell(
                                              onTap: () => showDialog(
                                                context: context,
                                                useRootNavigator: true,
                                                barrierDismissible: true,
                                                builder: (_) => ReceiptDialog(order: order, currency: currency),
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF051C48).withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: const Color(0xFF051C48).withOpacity(0.3)),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.receipt_rounded, size: 12, color: Color(0xFF051C48)),
                                                    SizedBox(width: 3),
                                                    Text('Bill', style: TextStyle(color: Color(0xFF051C48), fontSize: 11, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            // Settle Button for Unpaid Orders
                                            if (!order.isPaid && effectiveStatus != OrderStatus.cancelled) ...[
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () => _settleOrderFromList(order),
                                                borderRadius: BorderRadius.circular(8),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                  decoration: BoxDecoration(
                                                    gradient: const LinearGradient(
                                                      colors: [Color(0xFF051C48), Color(0xFF0A2E7A)],
                                                    ),
                                                    borderRadius: BorderRadius.circular(8),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFF051C48).withOpacity(0.25),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.check_circle_outline, size: 12, color: Colors.white),
                                                      SizedBox(width: 3),
                                                      Text('Settle', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(width: 6),
                                            // Status Transition Button
                                            if (effectiveStatus == OrderStatus.pending)
                                              ElevatedButton(
                                                onPressed: () {
                                                  db.updateOrderStatus(order.id, OrderStatus.preparing);
                                                  setState(() {});
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF051C48),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  elevation: 0,
                                                ),
                                                child: const Text('Accept', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                              )
                                            else if (effectiveStatus == OrderStatus.preparing)
                                              ElevatedButton(
                                                onPressed: () {
                                                  db.updateOrderStatus(order.id, OrderStatus.ready);
                                                  setState(() {});
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF10B981),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  elevation: 0,
                                                ),
                                                child: const Text('Mark Ready', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                              )
                                            else if (effectiveStatus == OrderStatus.ready)
                                              ElevatedButton(
                                                onPressed: () {
                                                  db.updateOrderStatus(order.id, OrderStatus.completed);
                                                  setState(() {});
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF051C48),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  elevation: 0,
                                                ),
                                                child: const Text('Complete', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                                if (isWide) {
                                  final leftIdx = rowIdx * 2;
                                  final rightIdx = leftIdx + 1;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: buildCard(filteredOrders[leftIdx])),
                                        const SizedBox(width: 12),
                                        if (rightIdx < filteredOrders.length)
                                          Expanded(child: buildCard(filteredOrders[rightIdx]))
                                        else
                                          const Expanded(child: SizedBox()),
                                      ],
                                    ),
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: buildCard(filteredOrders[rowIdx]),
                                );
                              },
                            );
                          },
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusPill(String filterKey, String label, int count, Color color) {
    final isSel = _selectedStatusFilter == filterKey;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatusFilter = filterKey;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? color : Colors.white,
          borderRadius: BorderRadius.circular(12), // SEMI CURVED CORNERS BOX
          border: Border.all(color: isSel ? color : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            Text(
              '$label ($count)',
              style: TextStyle(
                color: isSel ? Colors.white : const Color(0xFF475569),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
