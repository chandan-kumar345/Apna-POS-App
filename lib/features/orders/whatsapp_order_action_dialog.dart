import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_service.dart';
import '../../core/services/order_service.dart';
import '../../core/services/sound_service.dart';
import '../chat/meta_whatsapp_chat_screen.dart';

class WhatsAppOrderActionDialog extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final String customerPhone;
  final String customerName;
  final double totalAmount;
  final String orderType;
  final String deliveryAddress;
  final List<Map<String, dynamic>> items;
  final DateTime createdAt;

  const WhatsAppOrderActionDialog({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.customerPhone,
    required this.customerName,
    required this.totalAmount,
    this.orderType = 'takeaway',
    this.deliveryAddress = '',
    this.items = const [],
    required this.createdAt,
  });

  static bool _isShowing = false;
  static String? _currentShowingOrderId;

  /// Show the interactive WhatsApp Order Accept / Reject dialog
  static Future<void> show(
    BuildContext context, {
    required String orderId,
    required String orderNumber,
    required String customerPhone,
    String? customerName,
    required double totalAmount,
    String? orderType,
    String? deliveryAddress,
    dynamic itemsPayload,
    DateTime? createdAt,
  }) async {
    if (_isShowing && _currentShowingOrderId == orderId) return;

    List<Map<String, dynamic>> parsedItems = [];
    if (itemsPayload is List) {
      for (final item in itemsPayload) {
        if (item is Map) {
          parsedItems.add(Map<String, dynamic>.from(item));
        }
      }
    } else if (itemsPayload is String && itemsPayload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(itemsPayload);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              parsedItems.add(Map<String, dynamic>.from(item));
            }
          }
        }
      } catch (_) {}
    }

    _isShowing = true;
    _currentShowingOrderId = orderId;

    try {
      SoundService.playNotificationSound();
    } catch (_) {}

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WhatsAppOrderActionDialog(
        orderId: orderId,
        orderNumber: orderNumber,
        customerPhone: customerPhone,
        customerName: customerName ?? 'Customer',
        totalAmount: totalAmount,
        orderType: orderType ?? 'takeaway',
        deliveryAddress: deliveryAddress ?? '',
        items: parsedItems,
        createdAt: createdAt ?? DateTime.now(),
      ),
    );

    _isShowing = false;
    _currentShowingOrderId = null;
  }

  @override
  State<WhatsAppOrderActionDialog> createState() => _WhatsAppOrderActionDialogState();
}

class _WhatsAppOrderActionDialogState extends State<WhatsAppOrderActionDialog> {
  final OrderService _orderService = OrderService();
  final DatabaseService _db = DatabaseService();

  int _selectedPrepTime = 20;
  bool _isProcessing = false;

  final List<int> _prepTimeOptions = [15, 20, 30, 45, 60];

  final List<String> _rejectionReasons = [
    'Kitchen is at maximum capacity',
    'Item(s) out of stock',
    'Restaurant is closing soon',
    'Delivery address is out of range',
    'Other reason...',
  ];

  String _formatPhone(String raw) {
    var clean = raw.trim().replaceAll('+', '').replaceAll(' ', '');
    if (clean.startsWith('91') && clean.length == 12) {
      return '+91 ${clean.substring(2, 7)} ${clean.substring(7)}';
    }
    return raw;
  }

  Future<void> _handleAccept() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final success = await _orderService.acceptWhatsAppOrder(
        widget.orderId,
        prepTimeMinutes: _selectedPrepTime,
      );

      if (mounted) {
        if (success) {
          _db.syncTablesAndOrdersSilently().catchError((_) {});
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Order #${widget.orderNumber} Accepted! Confirmation sent to customer on WhatsApp.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0F9D58),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to accept order. Please check network connection.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting order: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleReject() async {
    if (_isProcessing) return;

    String selectedReason = _rejectionReasons.first;
    final customReasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isOther = selectedReason == 'Other reason...';
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 26),
                  SizedBox(width: 8),
                  Text('Decline WhatsApp Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a reason to send to the customer on WhatsApp for Order #${widget.orderNumber}:',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    ..._rejectionReasons.map((reason) {
                      final isSelected = selectedReason == reason;
                      return InkWell(
                        onTap: () {
                          setDialogState(() => selectedReason = reason);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                size: 20,
                                color: isSelected ? Colors.red.shade700 : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: isSelected ? Colors.red.shade900 : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (isOther) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: customReasonController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Enter reason for cancellation...',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Back', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Confirm & Notify Customer'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final finalReason = selectedReason == 'Other reason...'
        ? (customReasonController.text.trim().isNotEmpty
            ? customReasonController.text.trim()
            : 'Restaurant unavailable')
        : selectedReason;

    setState(() => _isProcessing = true);

    try {
      final success = await _orderService.rejectWhatsAppOrder(
        widget.orderId,
        reason: finalReason,
      );

      if (mounted) {
        if (success) {
          _db.syncTablesAndOrdersSilently().catchError((_) {});
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Order #${widget.orderNumber} declined. Customer notified on WhatsApp.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.blueGrey.shade800,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to decline order. Please check network connection.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining order: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _openWhatsAppChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MetaWhatsAppChatScreen(
          initialPhone: widget.customerPhone,
          initialCustomerName: widget.customerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final isDelivery = widget.orderType.toLowerCase() == 'delivery';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER BANNER ---
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xFF075E54),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NEW WHATSAPP ORDER',
                          style: TextStyle(
                            color: Color(0xFF25D366),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.orderNumber.startsWith('#') ? widget.orderNumber : '#${widget.orderNumber}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDelivery ? Icons.delivery_dining_rounded : Icons.takeout_dining_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isDelivery ? 'Delivery' : 'Takeaway',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // --- CONTENT BODY ---
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Customer Info Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF25D366),
                            child: const Icon(Icons.person, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.customerName.isNotEmpty ? widget.customerName : 'WhatsApp Customer',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatPhone(widget.customerPhone),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (isDelivery && widget.deliveryAddress.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '📍 ${widget.deliveryAddress}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade800,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chat_outlined, color: Color(0xFF075E54)),
                            tooltip: 'Chat on WhatsApp',
                            onPressed: _openWhatsAppChat,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Order Items Card
                    Text(
                      'ORDER ITEMS (${widget.items.length})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: widget.items.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Order items will be displayed upon sync.', textAlign: TextAlign.center),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: widget.items.length,
                              separatorBuilder: (ctx, idx) => Divider(height: 1, color: Colors.grey.shade200),
                              itemBuilder: (context, idx) {
                                final item = widget.items[idx];
                                final name = item['name']?.toString() ?? 'Item';
                                final qty = item['quantity'] ?? 1;
                                final price = (item['price'] is num)
                                    ? (item['price'] as num).toDouble()
                                    : (double.tryParse(item['price']?.toString() ?? '0') ?? 0.0);
                                final isVeg = item['foodType']?.toString().toLowerCase() != 'non_veg';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: isVeg ? const Color(0xFF0F9D58) : const Color(0xFFD93025),
                                            width: 1.5,
                                          ),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Center(
                                          child: Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isVeg ? const Color(0xFF0F9D58) : const Color(0xFFD93025),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${qty}x',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        currencyFormatter.format(price * (qty as num)),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: 14),

                    // Total Amount Highlight
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Grand Total Amount:',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey),
                        ),
                        Text(
                          currencyFormatter.format(widget.totalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            color: Color(0xFF0F9D58),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Preparation Time Selector
                    Text(
                      'ESTIMATED KITCHEN PREP TIME',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _prepTimeOptions.map((mins) {
                        final isSelected = _selectedPrepTime == mins;
                        return ChoiceChip(
                          label: Text('$mins mins'),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedPrepTime = mins);
                          },
                          selectedColor: const Color(0xFF075E54),
                          backgroundColor: Colors.grey.shade100,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // --- BOTTOM ACTIONS ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: _isProcessing
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Updating order & notifying customer on WhatsApp...', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        // Reject Order Button
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            onPressed: _handleReject,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD93025),
                              side: const BorderSide(color: Color(0xFFD93025), width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Accept Order Button
                        Expanded(
                          flex: 3,
                          child: ElevatedButton.icon(
                            onPressed: _handleAccept,
                            icon: const Icon(Icons.check_circle_rounded, size: 20),
                            label: const Text('Accept Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F9D58),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
