import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';
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
      SoundService.playOrderRingtone();
    } catch (_) {}

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
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
    } finally {
      SoundService.stopOrderRingtone();
      _isShowing = false;
      _currentShowingOrderId = null;
    }
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

  @override
  void initState() {
    super.initState();
    SoundService.playOrderRingtone();
  }

  @override
  void dispose() {
    SoundService.stopOrderRingtone();
    super.dispose();
  }

  String _formatPhone(String raw) {
    var clean = raw.trim().replaceAll('+', '').replaceAll(' ', '');
    if (clean.startsWith('91') && clean.length == 12) {
      return '+91 ${clean.substring(2, 7)} ${clean.substring(7)}';
    }
    return raw;
  }

  double _resolveItemPrice(Map<String, dynamic> item, Map<String, dynamic> actualItem, num qty) {
    double price = 0.0;
    if (actualItem['effectivePrice'] is num && (actualItem['effectivePrice'] as num) > 0) {
      price = (actualItem['effectivePrice'] as num).toDouble();
    } else if (actualItem['price'] is num && (actualItem['price'] as num) > 0) {
      price = (actualItem['price'] as num).toDouble();
    } else if (item['price'] is num && (item['price'] as num) > 0) {
      price = (item['price'] as num).toDouble();
    } else if (actualItem['rate'] is num && (actualItem['rate'] as num) > 0) {
      price = (actualItem['rate'] as num).toDouble();
    } else if (item['rate'] is num && (item['rate'] as num) > 0) {
      price = (item['rate'] as num).toDouble();
    } else if (actualItem['unitPrice'] is num && (actualItem['unitPrice'] as num) > 0) {
      price = (actualItem['unitPrice'] as num).toDouble();
    } else if (item['unitPrice'] is num && (item['unitPrice'] as num) > 0) {
      price = (item['unitPrice'] as num).toDouble();
    } else if (actualItem['totalPrice'] is num && (actualItem['totalPrice'] as num) > 0 && qty > 0) {
      price = (actualItem['totalPrice'] as num).toDouble() / qty;
    } else if (item['totalPrice'] is num && (item['totalPrice'] as num) > 0 && qty > 0) {
      price = (item['totalPrice'] as num).toDouble() / qty;
    } else {
      price = double.tryParse(actualItem['price']?.toString() ?? item['price']?.toString() ?? '0') ?? 0.0;
    }

    if (price <= 0.0) {
      final prodId = (actualItem['productId'] ?? actualItem['id'] ?? item['productId'] ?? item['id'] ?? '').toString();
      if (prodId.isNotEmpty) {
        final prod = _db.getProductById(prodId);
        if (prod != null && prod.price > 0) {
          price = prod.price;
        }
      }
    }

    if (price <= 0.0 && widget.items.length == 1 && widget.totalAmount > 0 && qty > 0) {
      price = widget.totalAmount / qty;
    }

    return price;
  }

  Future<void> _handleAccept() async {
    if (_isProcessing) return;
    SoundService.stopOrderRingtone();
    SoundService.playButtonClick();
    setState(() => _isProcessing = true);

    try {
      // 1. Optimistic instant local status change to preparing (0ms!)
      _db.updateOrderStatusLocally(widget.orderId, OrderStatus.preparing);

      // 2. Dispatch backend acceptance in parallel
      await _orderService.acceptWhatsAppOrder(
        widget.orderId,
        prepTimeMinutes: _selectedPrepTime,
      );

      if (mounted) {
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
    SoundService.stopOrderRingtone();
    SoundService.playButtonClick();

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
      // 1. Optimistic instant local status change to cancelled (0ms!)
      _db.updateOrderStatusLocally(widget.orderId, OrderStatus.cancelled);

      // 2. Dispatch backend rejection in parallel
      await _orderService.rejectWhatsAppOrder(
        widget.orderId,
        reason: finalReason,
      );

      if (mounted) {
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
    SoundService.playButtonClick();
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenWidth >= 600 ? 500 : screenWidth * 0.94,
          maxHeight: screenHeight * 0.88,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2F6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.95),
                offset: const Offset(-6, -6),
                blurRadius: 16,
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.16),
                offset: const Offset(6, 6),
                blurRadius: 20,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- 1. NEUMORPHIC HEADER BANNER ---
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F5132), Color(0xFF073B22)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF25D366).withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
                                color: Color(0xFF4ADE80),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.orderNumber.startsWith('#') ? widget.orderNumber : '#${widget.orderNumber}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDelivery ? Icons.delivery_dining_rounded : Icons.takeout_dining_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isDelivery ? 'Delivery' : 'Takeaway',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // --- 2. WRAPPED SCROLLABLE CONTENT BODY ---
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Customer Info Neumorphic Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.white,
                                offset: Offset(-2, -2),
                                blurRadius: 4,
                              ),
                              BoxShadow(
                                color: Color(0xFFDCE4EC),
                                offset: Offset(2, 2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE6F4EA),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(Icons.person_rounded, color: Color(0xFF137333), size: 22),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.customerName.isNotEmpty ? widget.customerName : 'WhatsApp Customer',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatPhone(widget.customerPhone),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF475569),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (isDelivery && widget.deliveryAddress.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFFDC2626)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              widget.deliveryAddress,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF334155),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: _openWhatsAppChat,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6F4EA),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFCEEAD6)),
                                  ),
                                  child: const Icon(Icons.chat_outlined, color: Color(0xFF137333), size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Section Label: Order Items
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ORDER ITEMS (${widget.items.length})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              DateFormat('hh:mm a').format(widget.createdAt),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Order Items Neumorphic Card
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.white,
                                offset: Offset(-2, -2),
                                blurRadius: 4,
                              ),
                              BoxShadow(
                                color: Color(0xFFDCE4EC),
                                offset: Offset(2, 2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: widget.items.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: Text(
                                      'Order items will appear upon sync.',
                                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  itemCount: widget.items.length,
                                  separatorBuilder: (ctx, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  itemBuilder: (context, idx) {
                                    final item = widget.items[idx];
                                    final actualItem = (item['item'] is Map)
                                        ? Map<String, dynamic>.from(item['item'])
                                        : item;
                                    final name = (actualItem['name'] ?? item['name'] ?? 'Item').toString();
                                    final qty = (item['quantity'] ?? actualItem['quantity'] ?? 1) as num;
                                    final price = _resolveItemPrice(item, actualItem, qty);
                                    final isVeg = actualItem['foodType']?.toString().toLowerCase() != 'non_veg';

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
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: Color(0xFF0F172A),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: Text(
                                              '${qty}x',
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: Color(0xFF0F2B48)),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            currencyFormatter.format(price * qty),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
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

                        // Grand Total Amount Highlight Neumorphic Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.white,
                                offset: Offset(-2, -2),
                                blurRadius: 4,
                              ),
                              BoxShadow(
                                color: Color(0xFFDCE4EC),
                                offset: Offset(2, 2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Grand Total',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'All items + taxes & charges included',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                currencyFormatter.format(widget.totalAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  color: Color(0xFF0F9D58),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Preparation Time Selector
                        const Text(
                          'ESTIMATED KITCHEN PREP TIME',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _prepTimeOptions.map((mins) {
                            final isSelected = _selectedPrepTime == mins;
                            return InkWell(
                              onTap: () {
                                SoundService.playButtonClick();
                                setState(() => _selectedPrepTime = mins);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF0F5132) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF0F5132) : const Color(0xFFCBD5E1),
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF0F5132).withValues(alpha: 0.35),
                                            offset: const Offset(0, 2),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : const [
                                          BoxShadow(
                                            color: Color(0x06000000),
                                            offset: Offset(0, 1),
                                            blurRadius: 2,
                                          ),
                                        ],
                                ),
                                child: Text(
                                  '$mins mins',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : const Color(0xFF334155),
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- 3. BOTTOM ACTIONS ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
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
                                Text(
                                  'Updating order & notifying customer on WhatsApp...',
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F2B48)),
                                ),
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
                                label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                  side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                label: const Text('Accept Order', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F9D58),
                                  foregroundColor: Colors.white,
                                  elevation: 3,
                                  shadowColor: const Color(0xFF0F9D58).withValues(alpha: 0.4),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
