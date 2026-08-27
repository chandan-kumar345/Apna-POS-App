import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';
import '../../core/models/table_model.dart';
import '../pos/payment_modal.dart';
import '../pos/receipt_dialog.dart';

class OrderDetailSheet extends StatefulWidget {
  final String? orderId;
  final String? orderNumber;
  final OrderModel? initialOrder;

  const OrderDetailSheet({
    super.key,
    this.orderId,
    this.orderNumber,
    this.initialOrder,
  });

  /// Show the compact Order Detail Bottom Sheet dialog
  static Future<void> show(
    BuildContext context, {
    String? orderId,
    String? orderNumber,
    OrderModel? initialOrder,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => OrderDetailSheet(
        orderId: orderId,
        orderNumber: orderNumber,
        initialOrder: initialOrder,
      ),
    );
  }

  @override
  State<OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<OrderDetailSheet> {
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
    if (widget.initialOrder != null && _order == null) {
      _order = widget.initialOrder;
    }

    final targetId = widget.orderId?.trim().toLowerCase();
    final targetNum = widget.orderNumber?.trim().toLowerCase();

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
      return DateFormat('dd MMM, hh:mm a').format(parsed);
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

  @override
  Widget build(BuildContext context) {
    final currency = _db.restaurant?.currencySymbol ?? '₹';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Compact Drag Handle
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 2. Compact Top Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF082559).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF082559), size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _order != null && _order!.orderNumber.isNotEmpty
                            ? '#${_order!.orderNumber}'
                            : 'Order Details',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (_order != null && _order!.id.isNotEmpty)
                        Text(
                          '${_getOrderTypeLabel(_order!.orderType)}${_order!.tableNumber != null && _order!.tableNumber!.isNotEmpty ? " • Table ${_order!.tableNumber}" : ""}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Divider(color: Color(0xFFE2E8F0), height: 1),

          // 3. Main Scrollable Content
          Flexible(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: Color(0xFF082559), strokeWidth: 2.5),
                    ),
                  )
                : _order == null || _order!.id.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 44, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                'Order Not Found',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.orderNumber != null
                                    ? 'Could not load order #${widget.orderNumber}.'
                                    : 'Order details are unavailable.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => _loadOrder(),
                                icon: const Icon(Icons.refresh_rounded, size: 14),
                                label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF082559),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildOrderBody(currency),
          ),

          // 4. Compact Bottom Actions Bar
          if (_order != null && _order!.id.isNotEmpty)
            _buildBottomActions(currency),
        ],
      ),
    );
  }

  Widget _buildOrderBody(String currency) {
    final order = _order!;
    final isRunningKot = order.tableNumber != null &&
        _db.tables.any((t) =>
            (t.name == order.tableNumber || t.tableNumber.toString() == order.tableNumber) &&
            t.status == TableStatus.runningKot);
    final effectiveStatus = (isRunningKot && order.status == OrderStatus.pending)
        ? OrderStatus.preparing
        : order.status;
    final statusColor = _getStatusColor(effectiveStatus);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status & Paid Badges Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  _getStatusLabel(effectiveStatus),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: order.isPaid
                      ? const Color(0xFF10B981).withOpacity(0.12)
                      : const Color(0xFFF59E0B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
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
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 3),
                  Text(
                    _formatDateTime(order.createdAt),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Customer details (if available)
          if ((order.customerName != null && order.customerName!.isNotEmpty) ||
              (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ||
              (order.customerPhone != null && order.customerPhone!.isNotEmpty)) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (order.customerName != null && order.customerName!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.person_rounded, size: 13, color: Color(0xFF082559)),
                        const SizedBox(width: 5),
                        Text(
                          order.customerName!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                          Text(
                            ' (${order.customerPhone})',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ...[
                    if (order.customerName != null && order.customerName!.isNotEmpty)
                      const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF082559)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            order.deliveryAddress!,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Items Ordered Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Items Ordered',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                '${order.items.length} ${order.items.length == 1 ? "Item" : "Items"}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Items List
          ...order.items.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF082559).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${item.quantity}×',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF082559),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.item.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (item.note != null && item.note!.trim().isNotEmpty)
                          Text(
                            'Note: ${item.note}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFD97706),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        Text(
                          '$currency ${item.item.effectivePrice.toStringAsFixed(0)} each',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$currency ${item.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),

          // Bill Summary
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    Text('$currency ${order.subtotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  ],
                ),
                if (order.taxAmount > 0) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Taxes (GST)', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      Text('$currency ${order.taxAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                    ],
                  ),
                ],
                if (order.discountAmount > 0) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Discount', style: TextStyle(fontSize: 11.5, color: Color(0xFF10B981))),
                      Text('-$currency ${order.discountAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                    ],
                  ),
                ],
                if (order.deliveryCharge > 0) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Delivery Charge', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      Text('$currency ${order.deliveryCharge.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                    ],
                  ),
                ],
                const Divider(height: 12, color: Color(0xFFCBD5E1)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grand Total',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF082559),
                      ),
                    ),
                    Text(
                      '$currency ${order.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF082559),
                      ),
                    ),
                  ],
                ),
                if (order.paymentMethod.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Method', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                      Text(
                        order.paymentMethod,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildBottomActions(String currency) {
    final order = _order!;
    final isRunningKot = order.tableNumber != null &&
        _db.tables.any((t) =>
            (t.name == order.tableNumber || t.tableNumber.toString() == order.tableNumber) &&
            t.status == TableStatus.runningKot);
    final effectiveStatus = (isRunningKot && order.status == OrderStatus.pending)
        ? OrderStatus.preparing
        : order.status;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Receipt Button (No KOT button)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    useRootNavigator: true,
                    barrierDismissible: true,
                    builder: (_) => ReceiptDialog(order: order, currency: currency),
                  );
                },
                icon: const Icon(Icons.print_rounded, size: 14),
                label: const Text('Receipt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF082559),
                  side: const BorderSide(color: Color(0xFF082559)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Settle / Pay Button (if unpaid) or Close Button
            if (!order.isPaid && effectiveStatus != OrderStatus.cancelled) ...[
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _settleOrder,
                  icon: const Icon(Icons.payment_rounded, size: 15),
                  label: const Text('Settle / Pay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Close', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
