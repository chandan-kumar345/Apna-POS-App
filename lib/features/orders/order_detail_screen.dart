import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';
import '../../core/models/table_model.dart';
import '../../core/services/bluetooth_printer_service.dart';
import '../../core/widgets/printer_selection_dialog.dart';
import '../pos/payment_modal.dart';
import '../pos/receipt_dialog.dart';

class OrderDetailScreen extends StatefulWidget {
  final String? orderId;
  final String? orderNumber;
  final OrderModel? initialOrder;

  const OrderDetailScreen({
    super.key,
    this.orderId,
    this.orderNumber,
    this.initialOrder,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final DatabaseService _db = DatabaseService();
  OrderModel? _order;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _db.addListener(_onDbChange);
    _loadOrder();
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChange);
    super.dispose();
  }

  void _onDbChange() {
    if (mounted) _loadOrder(syncFromDbOnly: true);
  }

  Future<void> _loadOrder({bool syncFromDbOnly = false}) async {
    // 1. Check initial order
    if (widget.initialOrder != null && _order == null) {
      _order = widget.initialOrder;
    }

    final targetId = widget.orderId?.trim().toLowerCase();
    final targetNum = widget.orderNumber?.trim().toLowerCase();

    // 2. Search local database
    final matched = _db.orders.firstWhere(
      (o) =>
          (targetId != null &&
              (o.id.toLowerCase() == targetId || o.orderNumber.toLowerCase() == targetId)) ||
          (targetNum != null && o.orderNumber.toLowerCase() == targetNum),
      orElse: () => _order ??
          OrderModel(
            id: '',
            orderNumber: '',
            items: const [],
            subtotal: 0,
            taxAmount: 0,
            totalAmount: 0,
            createdAt: '',
          ),
    );

    if (matched.id.isNotEmpty) {
      if (mounted) {
        setState(() {
          _order = matched;
        });
      }
    }

    // 3. Sync with backend if needed
    if (!syncFromDbOnly && (_order == null || _order!.id.isEmpty)) {
      if (mounted) setState(() => _isLoading = true);
      await _db.syncWithBackend();
      if (mounted) {
        final recheck = _db.orders.firstWhere(
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
        setState(() {
          _isLoading = false;
          if (recheck.id.isNotEmpty) _order = recheck;
        });
      }
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

  IconData _getOrderTypeIcon(OrderType type) {
    switch (type) {
      case OrderType.dineIn:
        return Icons.table_restaurant_rounded;
      case OrderType.takeaway:
        return Icons.shopping_bag_outlined;
      case OrderType.delivery:
        return Icons.delivery_dining_rounded;
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.preparing:
        return const Color(0xFF082559);
      case OrderStatus.ready:
        return const Color(0xFF10B981);
      case OrderStatus.completed:
        return const Color(0xFF082559);
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }

  String _getStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'PENDING';
      case OrderStatus.preparing:
        return 'PREPARING';
      case OrderStatus.ready:
        return 'READY';
      case OrderStatus.completed:
        return 'COMPLETED';
      case OrderStatus.cancelled:
        return 'CANCELLED';
    }
  }

  Future<void> _settleOrder() async {
    if (_order == null) return;
    final currency = _db.restaurant?.currencySymbol ?? '₹';

    final modalResult = await showDialog<dynamic>(
      context: context,
      builder: (_) => PaymentModal(
        order: _order!,
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
        final completedOrder = await _db.settleOrder(
          orderId: _order!.id,
          paymentMethod: resultMethod,
          totalAmount: totalAmount ?? _order!.totalAmount,
          roundOff: roundOff ?? 0.0,
        );

        if (!mounted) return;
        setState(() {
          _order = completedOrder;
        });

        showDialog(
          context: context,
          useRootNavigator: true,
          barrierDismissible: true,
          builder: (_) => ReceiptDialog(order: completedOrder, currency: currency),
        );
      }
    }
  }

  Future<void> _printKOT() async {
    if (_order == null) return;
    final printerService = BluetoothPrinterService();
    final currency = _db.restaurant?.currencySymbol ?? '₹';
    final bool isConnected = await printerService.isConnected();

    if (!mounted) return;

    if (isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printing KOT Ticket...'),
          backgroundColor: Color(0xFFD97706),
          duration: Duration(seconds: 2),
        ),
      );
      final rest = _db.restaurant;
      final success = await printerService.printKOT(order: _order!, restaurant: rest);
      if (mounted && !success) {
        PrinterSelectionDialog.show(context, orderToPrint: _order!, currency: currency);
      }
    } else {
      final bool reconnected = await printerService.autoConnectSavedPrinter();
      if (reconnected) {
        final rest = _db.restaurant;
        await printerService.printKOT(order: _order!, restaurant: rest);
      } else if (mounted) {
        PrinterSelectionDialog.show(context, orderToPrint: _order!, currency: currency);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = _db.restaurant?.currencySymbol ?? '₹';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF082559),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Text(
          _order != null && _order!.orderNumber.isNotEmpty
              ? 'Order #${_order!.orderNumber}'
              : 'Order Details',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _loadOrder(),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            tooltip: 'Refresh',
          ),
          if (_order != null)
            IconButton(
              onPressed: () => showDialog(
                context: context,
                useRootNavigator: true,
                barrierDismissible: true,
                builder: (_) => ReceiptDialog(order: _order!, currency: currency),
              ),
              icon: const Icon(Icons.print_rounded, color: Colors.white, size: 22),
              tooltip: 'Print Receipt',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF082559)))
          : _order == null || _order!.id.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Order Details Not Found',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.orderNumber != null
                              ? 'Could not load order #${widget.orderNumber}.'
                              : 'Order information is currently unavailable.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _loadOrder(),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Try Refreshing'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF082559),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildOrderContent(currency),
    );
  }

  Widget _buildOrderContent(String currency) {
    final order = _order!;
    final isRunningKot = order.tableNumber != null &&
        _db.tables.any((t) =>
            (t.name == order.tableNumber || t.tableNumber.toString() == order.tableNumber) &&
            t.status == TableStatus.runningKot);
    final effectiveStatus = (isRunningKot && order.status == OrderStatus.pending)
        ? OrderStatus.preparing
        : order.status;
    final statusColor = _getStatusColor(effectiveStatus);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Order Status & Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF082559).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(_getOrderTypeIcon(order.orderType),
                                color: const Color(0xFF082559), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#${order.orderNumber}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_getOrderTypeLabel(order.orderType)}${order.tableNumber != null && order.tableNumber!.isNotEmpty ? " • Table ${order.tableNumber}" : ""}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFFF1F5F9), height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusColor.withOpacity(0.4)),
                            ),
                            child: Text(
                              _getStatusLabel(effectiveStatus),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: order.isPaid
                                  ? const Color(0xFF10B981).withOpacity(0.12)
                                  : const Color(0xFFF59E0B).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
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
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                _formatDateTime(order.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Customer & Delivery Info (if applicable)
                if ((order.customerName != null && order.customerName!.isNotEmpty) ||
                    (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ||
                    (order.customerPhone != null && order.customerPhone!.isNotEmpty)) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (order.customerName != null && order.customerName!.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.person_rounded, size: 16, color: Color(0xFF082559)),
                              const SizedBox(width: 8),
                              Text(
                                order.customerName!,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        if (order.customerPhone != null && order.customerPhone!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF082559)),
                              const SizedBox(width: 8),
                              Text(
                                order.customerPhone!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF082559)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order.deliveryAddress!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 3. Items Ordered Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Items Ordered',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '${order.items.length} ${order.items.length == 1 ? "Item" : "Items"}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFFF1F5F9), height: 1),
                      const SizedBox(height: 12),

                      ...order.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF082559).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${item.quantity}×',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF082559),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.item.name,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (item.note != null && item.note!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Note: ${item.note}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xFFD97706),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 2),
                                    Text(
                                      '$currency ${item.item.effectivePrice.toStringAsFixed(0)} each',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '$currency ${item.totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Payment & Bill Breakdown Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bill Summary',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          Text('$currency ${order.subtotal.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                        ],
                      ),
                      if (order.taxAmount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Taxes (GST)', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            Text('$currency ${order.taxAmount.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                          ],
                        ),
                      ],
                      if (order.discountAmount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Discount', style: TextStyle(fontSize: 13, color: Color(0xFF10B981))),
                            Text('-$currency ${order.discountAmount.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                          ],
                        ),
                      ],
                      if (order.deliveryCharge > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Delivery Charge', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            Text('$currency ${order.deliveryCharge.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                          ],
                        ),
                      ],
                      const Divider(height: 20, color: Color(0xFFE2E8F0)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Grand Total',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF082559),
                            ),
                          ),
                          Text(
                            '$currency ${order.totalAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF082559),
                            ),
                          ),
                        ],
                      ),
                      if (order.paymentMethod.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Payment Method', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            Text(
                              order.paymentMethod,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 5. Fixed Bottom Actions Bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // KOT Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _printKOT,
                    icon: const Icon(Icons.soup_kitchen_rounded, size: 16),
                    label: const Text('KOT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD97706),
                      side: const BorderSide(color: Color(0xFFD97706)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Receipt Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      useRootNavigator: true,
                      barrierDismissible: true,
                      builder: (_) => ReceiptDialog(order: order, currency: currency),
                    ),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Receipt'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF082559),
                      side: const BorderSide(color: Color(0xFF082559)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Settle / Pay Button (if unpaid and not cancelled)
                if (!order.isPaid && effectiveStatus != OrderStatus.cancelled) ...[
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _settleOrder,
                      icon: const Icon(Icons.payment_rounded, size: 18),
                      label: const Text('Settle / Pay'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF082559),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
