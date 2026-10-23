import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
      if (price <= 0.0) {
        final name = (actualItem['name'] ?? item['name'] ?? '').toString();
        if (name.isNotEmpty) {
          final prod = _db.getProductById(name);
          if (prod != null && prod.price > 0) {
            price = prod.price;
          }
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

  String _resolveItemImage(Map<String, dynamic> item, Map<String, dynamic> actualItem) {
    String img = (actualItem['imageUrl'] ??
            actualItem['image'] ??
            actualItem['img'] ??
            actualItem['photo'] ??
            item['imageUrl'] ??
            item['image'] ??
            '')
        .toString()
        .trim();
    if (img.isNotEmpty) return img;

    final prodId = (actualItem['productId'] ?? actualItem['id'] ?? item['productId'] ?? item['id'] ?? '').toString();
    if (prodId.isNotEmpty) {
      final prod = _db.getProductById(prodId);
      if (prod != null && prod.imageUrl.trim().isNotEmpty) {
        return prod.imageUrl.trim();
      }
    }

    final name = (actualItem['name'] ?? item['name'] ?? '').toString();
    if (name.isNotEmpty) {
      final prod = _db.getProductById(name);
      if (prod != null && prod.imageUrl.trim().isNotEmpty) {
        return prod.imageUrl.trim();
      }
    }

    return '';
  }

  Widget _buildFoodThumbnail(String imgUrl) {
    const double size = 46.0;
    if (imgUrl.isNotEmpty) {
      if (imgUrl.startsWith('http://') || imgUrl.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            imgUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFoodFallbackIcon(size),
          ),
        );
      } else if (imgUrl.startsWith('assets/')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            imgUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFoodFallbackIcon(size),
          ),
        );
      } else if (!kIsWeb && File(imgUrl).existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(imgUrl),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFoodFallbackIcon(size),
          ),
        );
      }
    }

    return _buildFoodFallbackIcon(size);
  }

  Widget _buildFoodFallbackIcon(double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        'assets/images/product_placeholder.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFEDD5)),
          ),
          child: const Center(
            child: Icon(Icons.lunch_dining_rounded, color: Color(0xFFEA580C), size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool isDelivery) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF03193E),
            Color(0xFF0C2B6A),
            Color(0xFF103E8A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0C2B6A).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // WhatsApp Green Squircle Icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF25D366), Color(0xFF1EBE5D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF25D366).withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'assets/images/whatsapp_logo.png',
                width: 27,
                height: 27,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Order Subtitle & Order Number
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'NEW WHATSAPP ORDER',
                  style: TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.orderNumber.startsWith('#') ? widget.orderNumber : '#${widget.orderNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Order Type Capsule Badge (e.g. TakeAway / Delivery)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1A386D).withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDelivery ? Icons.delivery_dining_rounded : Icons.shopping_bag_rounded,
                  color: Colors.white,
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  isDelivery ? 'Delivery' : 'TakeAway',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(bool isDelivery) {
    final cleanPhone = widget.customerPhone.replaceAll(RegExp(r'\D'), '');
    final customer = _db.customers.where((c) {
      final cp = c.phone.replaceAll(RegExp(r'\D'), '');
      return cp.isNotEmpty && (cp.endsWith(cleanPhone) || cleanPhone.endsWith(cp));
    }).firstOrNull;
    final customerAvatar = customer?.avatarUrl.trim() ?? '';
    final displayName = widget.customerName.trim().isNotEmpty && widget.customerName.trim().toLowerCase() != 'customer'
        ? widget.customerName.trim()
        : 'unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Customer Avatar
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: customerAvatar.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      customerAvatar,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF475569),
                        size: 24,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF475569),
                    size: 24,
                  ),
          ),
          const SizedBox(width: 12),

          // Name, Gold Coin Badge, and Phone
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Gold Coin / Loyalty Equal Badge
                    Container(
                      width: 15,
                      height: 15,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 7, height: 1.5, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1))),
                            const SizedBox(height: 1.5),
                            Container(width: 7, height: 1.5, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatPhone(widget.customerPhone),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isDelivery && widget.deliveryAddress.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFFDC2626)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          widget.deliveryAddress,
                          style: const TextStyle(
                            fontSize: 10.5,
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

          const SizedBox(width: 8),

          // Right WhatsApp Chat Action Button
          InkWell(
            onTap: _openWhatsAppChat,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE8FDF0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0815803D),
                    blurRadius: 4,
                    offset: Offset(0, 1.5),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF15803D),
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsCard(NumberFormat currencyFormatter) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Icon + ORDER ITEMS (count) on left, timestamp on right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'ORDER ITEMS (${widget.items.length})',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('hh:mm a').format(widget.createdAt),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          if (widget.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Order items will appear upon sync.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: widget.items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final item = widget.items[idx];
                final actualItem = (item['item'] is Map)
                    ? Map<String, dynamic>.from(item['item'])
                    : item;
                final name = (actualItem['name'] ?? item['name'] ?? 'Item').toString();
                final qty = (item['quantity'] ?? actualItem['quantity'] ?? 1) as num;
                final price = _resolveItemPrice(item, actualItem, qty);
                final imgUrl = _resolveItemImage(item, actualItem);

                String variant = (actualItem['variant'] ??
                        actualItem['size'] ??
                        actualItem['portion'] ??
                        actualItem['selectedVariant'] ??
                        '')
                    .toString()
                    .trim();
                if (variant.isEmpty) {
                  final prodId = (actualItem['productId'] ?? actualItem['id'] ?? item['productId'] ?? item['id'] ?? '').toString();
                  if (prodId.isNotEmpty) {
                    final prod = _db.getProductById(prodId);
                    if (prod != null && prod.category.trim().isNotEmpty) {
                      variant = prod.category.trim();
                    }
                  }
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Food Image Thumbnail
                      _buildFoodThumbnail(imgUrl),
                      const SizedBox(width: 10),

                      // Name and Variant
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (variant.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                variant.startsWith('(') ? variant : '($variant)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Quantity Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                        ),
                        child: Text(
                          '${qty}x',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: Color(0xFF0F2B48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Item Total Price
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
          ],
        ],
      ),
    );
  }

  Widget _buildBillCard(NumberFormat currencyFormatter) {
    final double computedSubtotal = widget.items.fold<double>(0.0, (sum, rawItem) {
      final actualItem = (rawItem['item'] is Map)
          ? Map<String, dynamic>.from(rawItem['item'])
          : rawItem;
      final qty = (rawItem['quantity'] ?? actualItem['quantity'] ?? 1) as num;
      final price = _resolveItemPrice(rawItem, actualItem, qty);
      return sum + (price * qty);
    });
    final double taxesAndCharges = (widget.totalAmount - computedSubtotal).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Items Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Items Subtotal',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                currencyFormatter.format(computedSubtotal > 0 ? computedSubtotal : widget.totalAmount),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Taxes & Charges (GST)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Taxes & Charges (GST)',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '+${currencyFormatter.format(taxesAndCharges)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          // Dashed Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: CustomPaint(
              painter: const DashedDividerPainter(color: Color(0xFFE2E8F0)),
              child: const SizedBox(width: double.infinity, height: 1),
            ),
          ),

          // Grand Total Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Grand Total',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'All items + taxes & charges included',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                currencyFormatter.format(widget.totalAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Color(0xFF00A86B),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrepTimePill(int mins) {
    final isSelected = _selectedPrepTime == mins;
    return InkWell(
      onTap: () {
        SoundService.playButtonClick();
        setState(() => _selectedPrepTime = mins);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF0F2B48), Color(0xFF1E3A8A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: isSelected ? null : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$mins mins',
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF334155),
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrepTimeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Clock icon + ESTIMATED KITCHEN PREP TIME
          const Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 13,
                color: Color(0xFF64748B),
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ESTIMATED KITCHEN PREP TIME',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 1: 15 mins | 20 mins | 30 mins
          Row(
            children: [
              Expanded(child: _buildPrepTimePill(15)),
              const SizedBox(width: 8),
              Expanded(child: _buildPrepTimePill(20)),
              const SizedBox(width: 8),
              Expanded(child: _buildPrepTimePill(30)),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: 45 mins | 60 mins
          Row(
            children: [
              Expanded(child: _buildPrepTimePill(45)),
              const SizedBox(width: 8),
              Expanded(child: _buildPrepTimePill(60)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    if (_isProcessing) {
      return Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text(
                'Updating order & notifying customer...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F2B48),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        // Reject Button
        Expanded(
          flex: 2,
          child: InkWell(
            onTap: _handleReject,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 17),
                  SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Reject',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Accept Order Button
        Expanded(
          flex: 3,
          child: InkWell(
            onTap: _handleAccept,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C853), Color(0xFF00A86B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C853).withValues(alpha: 0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 17),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Accept Order',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenWidth < 380 ? 10 : 14,
        vertical: 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenWidth >= 600 ? 460 : screenWidth,
          maxHeight: screenHeight * 0.94,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEEF3F8),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.9),
                offset: const Offset(-4, -4),
                blurRadius: 14,
              ),
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.22),
                offset: const Offset(4, 6),
                blurRadius: 20,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(screenWidth < 380 ? 10 : 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. TOP HEADER FLOATING CARD
                  _buildHeaderCard(isDelivery),
                  const SizedBox(height: 10),

                  // 2. CUSTOMER INFO FLOATING CARD
                  _buildCustomerCard(isDelivery),
                  const SizedBox(height: 10),

                  // 3. ORDER ITEMS FLOATING CARD
                  _buildOrderItemsCard(currencyFormatter),
                  const SizedBox(height: 10),

                  // 4. BILL BREAKDOWN FLOATING CARD
                  _buildBillCard(currencyFormatter),
                  const SizedBox(height: 10),

                  // 5. KITCHEN PREP TIME FLOATING CARD
                  _buildPrepTimeCard(),
                  const SizedBox(height: 14),

                  // 6. BOTTOM ACTIONS (REJECT / ACCEPT)
                  _buildBottomActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashedDividerPainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const DashedDividerPainter({
    required this.color,
    this.dashWidth = 4.0,
    this.dashSpace = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
