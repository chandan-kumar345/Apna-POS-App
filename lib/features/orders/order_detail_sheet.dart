import 'dart:convert';
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

  /// Show the compact, wrapped Order Detail Bottom Sheet dialog
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
      barrierColor: Colors.black.withValues(alpha: 0.55),
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
        return const Color(0xFFEA580C);
      case OrderStatus.ready:
        return const Color(0xFF10B981);
      case OrderStatus.completed:
        return const Color(0xFF2563EB);
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

  Widget _buildItemImage(CartItemModel cartItem) {
    String? img = cartItem.item.imageUrl;
    if ((img.isEmpty) && cartItem.item.images.isNotEmpty) {
      img = cartItem.item.images.first;
    }
    if (img.isEmpty) {
      final dbItem = _db.menuItems
          .where((m) =>
              m.id == cartItem.item.id ||
              m.name.toLowerCase() == cartItem.item.name.toLowerCase())
          .firstOrNull;
      if (dbItem != null) {
        img = dbItem.imageUrl.isNotEmpty
            ? dbItem.imageUrl
            : (dbItem.images.isNotEmpty ? dbItem.images.first : null);
      }
    }

    Widget? imageWidget;
    if (img != null && img.isNotEmpty) {
      if (img.startsWith('data:image') ||
          (img.length > 100 &&
              !img.startsWith('http') &&
              !img.startsWith('assets/'))) {
        try {
          final cleanBase64 =
              img.contains(',') ? img.split(',').last.trim() : img.trim();
          final bytes = base64Decode(cleanBase64);
          imageWidget = Image.memory(
            bytes,
            width: 38,
            height: 38,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildDefaultProductImage(),
          );
        } catch (_) {}
      } else if (img.startsWith('http')) {
        imageWidget = Image.network(
          img,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildDefaultProductImage(),
        );
      } else if (img.startsWith('assets/')) {
        imageWidget = Image.asset(
          img,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildDefaultProductImage(),
        );
      }
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageWidget ?? _buildDefaultProductImage(),
    );
  }

  Widget _buildDefaultProductImage() {
    return Image.asset(
      'assets/images/product_placeholder.png',
      width: 38,
      height: 38,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFFE2E8F0),
        alignment: Alignment.center,
        child: const Icon(Icons.fastfood_rounded, size: 18, color: Color(0xFF94A3B8)),
      ),
    );
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
          totalAmount: totalAmount ?? _order!.effectiveTotalAmount,
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

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Top Drag Handle Pill
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // 2. Top Header Bar: Document Icon, Order # & Subtitle
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    // Light Blue Document Icon Box
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Order Number and Subtitle
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
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          if (_order != null && _order!.id.isNotEmpty)
                            Text(
                              '${_getOrderTypeLabel(_order!.orderType)}${_order!.tableNumber != null && _order!.tableNumber!.isNotEmpty ? " • Table ${_order!.tableNumber}" : ""}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

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
                                  Icon(Icons.receipt_long_outlined, size: 42, color: Colors.grey.shade400),
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

              // 4. Compact Bottom Actions Bar (Receipt & Close/Settle, Download Removed)
              if (_order != null && _order!.id.isNotEmpty)
                _buildBottomActions(currency),
            ],
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Status Badges & Timestamp Row (Wrapped)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              // Status & Paid Badges
              Wrap(
                spacing: 5,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Status Pill (Completed, Preparing, Ready, Pending, Cancelled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: effectiveStatus == OrderStatus.completed
                          ? const Color(0xFFEFF6FF)
                          : (effectiveStatus == OrderStatus.cancelled
                              ? const Color(0xFFFEE2E2)
                              : statusColor.withValues(alpha: 0.12)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: effectiveStatus == OrderStatus.completed
                            ? const Color(0xFFBFDBFE)
                            : (effectiveStatus == OrderStatus.cancelled
                                ? const Color(0xFFFECACA)
                                : statusColor.withValues(alpha: 0.4)),
                      ),
                    ),
                    child: Text(
                      _getStatusLabel(effectiveStatus),
                      style: TextStyle(
                        color: effectiveStatus == OrderStatus.completed
                            ? const Color(0xFF2563EB)
                            : (effectiveStatus == OrderStatus.cancelled ? const Color(0xFFDC2626) : statusColor),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),

                  // PAID / UNPAID Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: order.isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: order.isPaid ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Text(
                      order.isPaid ? 'PAID' : 'UNPAID',
                      style: TextStyle(
                        color: order.isPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),

              // Timestamp
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, size: 12.5, color: Color(0xFF64748B)),
                  const SizedBox(width: 3.5),
                  Text(
                    _formatDateTime(order.createdDateTime),
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

          // 2. Customer details (if available)
          if ((order.customerName != null && order.customerName!.isNotEmpty) ||
              (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ||
              (order.customerPhone != null && order.customerPhone!.isNotEmpty)) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
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

          // 3. Items Ordered Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Items Ordered',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                '${order.items.length} ${order.items.length == 1 ? "Item" : "Items"}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 4. Items List Cards (Clean, Compact, Wrapped)
          ...order.items.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                children: [
                  // Quantity Capsule (e.g. 2 ×)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Text(
                      '${item.quantity} ×',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Product Image
                  _buildItemImage(item),
                  const SizedBox(width: 9),

                  // Item Name & Unit Price
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.item.name,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '$currency ${item.item.effectivePrice.toStringAsFixed(0)} each',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (item.note != null && item.note!.trim().isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            'Note: ${item.note}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFD97706),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Total Price for Line Item
                  Text(
                    '$currency ${(item.totalPrice).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),

          // 5. Financial Bill Summary Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    Text('$currency ${order.effectiveSubtotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  ],
                ),
                if (order.taxAmount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Taxes (GST)', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      Text('$currency ${order.taxAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    ],
                  ),
                ],
                if (order.discountAmount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Discount', style: TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                      Text('-$currency ${order.discountAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                    ],
                  ),
                ],
                if (order.deliveryCharge > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Delivery Charge', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      Text('$currency ${order.deliveryCharge.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    ],
                  ),
                ],
                if (order.tipAmount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tip', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      Text('$currency ${order.tipAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    ],
                  ),
                ],
                if (order.roundOff != 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Round Off', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      Text('${order.roundOff > 0 ? "+" : ""}$currency ${order.roundOff.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    ],
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Grand Total',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '$currency ${order.effectiveTotalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                if (order.paymentMethod.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Method', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      Text(
                        order.paymentMethod.toUpperCase(),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
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
            // Receipt Button (Outlined / Neumorphic, Full 50% flex)
            Expanded(
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    useRootNavigator: true,
                    barrierDismissible: true,
                    builder: (_) => ReceiptDialog(order: order, currency: currency),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.95),
                        offset: const Offset(-2, -2),
                        blurRadius: 3,
                      ),
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                        offset: const Offset(2, 3),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.print_rounded, size: 16, color: Color(0xFF082559)),
                      SizedBox(width: 6),
                      Text(
                        'Receipt',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF082559),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Settle / Pay Button (if unpaid) or Close Button (Solid Navy Blue, Full 50% flex)
            if (!order.isPaid && effectiveStatus != OrderStatus.cancelled) ...[
              Expanded(
                child: InkWell(
                  onTap: _settleOrder,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          offset: const Offset(0, 3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.payment_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Settle / Pay',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF082559),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF082559).withValues(alpha: 0.25),
                          offset: const Offset(0, 3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
