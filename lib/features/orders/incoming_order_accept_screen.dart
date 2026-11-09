import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';
import '../../core/models/menu_item_model.dart';
import '../../core/models/table_model.dart';
import '../../core/services/order_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/local_notification_service.dart';
import '../../core/services/bluetooth_printer_service.dart';
import '../../core/services/firestore_service.dart';
import '../chat/meta_whatsapp_chat_screen.dart';

/// Full-screen high-priority Incoming Order Acceptance Screen.
/// Displays when new orders arrive via WhatsApp, Online Storefront, or POS,
/// even when the phone was locked or the app was closed.
class IncomingOrderAcceptScreen extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final String customerPhone;
  final String customerName;
  final double totalAmount;
  final String orderType;
  final String deliveryAddress;
  final String? tableNumber;
  final List<Map<String, dynamic>> items;
  final DateTime createdAt;
  final String source;
  final bool autoAccept;
  final bool autoReject;

  const IncomingOrderAcceptScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.customerPhone,
    required this.customerName,
    required this.totalAmount,
    this.orderType = 'takeaway',
    this.deliveryAddress = '',
    this.tableNumber,
    this.items = const [],
    required this.createdAt,
    this.source = 'whatsapp',
    this.autoAccept = false,
    this.autoReject = false,
  });

  static bool _isShowing = false;
  static String? _currentShowingOrderId;
  static String? _currentShowingOrderNumber;
  static BuildContext? _currentScreenContext;

  static bool get isShowing => _isShowing;
  static String? get currentShowingOrderId => _currentShowingOrderId;
  static String? get currentShowingOrderNumber => _currentShowingOrderNumber;

  /// Open the full-screen Incoming Order Accept Screen safely from anywhere
  static Future<void> open(
    BuildContext context, {
    required String orderId,
    required String orderNumber,
    required String customerPhone,
    String? customerName,
    required double totalAmount,
    String? orderType,
    String? deliveryAddress,
    String? tableNumber,
    dynamic itemsPayload,
    DateTime? createdAt,
    String? source,
    bool autoAccept = false,
    bool autoReject = false,
  }) async {
    final cleanType = (orderType ?? '').toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
    final cleanSource = (source ?? '').toLowerCase().trim();
    final bool isTable = (tableNumber != null && tableNumber.trim().isNotEmpty) ||
        cleanSource.contains('qr') ||
        cleanSource.contains('table') ||
        cleanType.contains('table') ||
        cleanType.contains('dine') ||
        (deliveryAddress != null && deliveryAddress.toLowerCase().contains('table'));

    final bool isExplicitExternal = cleanSource == 'whatsapp' ||
        cleanSource == 'profile' ||
        cleanSource == 'storefront' ||
        cleanSource == 'online' ||
        cleanSource == 'qr' ||
        isTable ||
        cleanType.contains('whatsapp') ||
        cleanType.contains('profile');

    final bool isPosOrder = !isExplicitExternal && (
        cleanSource == 'pos' ||
        cleanSource == 'counter' ||
        cleanSource == 'local' ||
        DatabaseService.isKnownPosOrder(orderId) ||
        DatabaseService.isKnownPosOrder(orderNumber));

    if (isPosOrder) {
      debugPrint('[IncomingOrderAcceptScreen] Blocked order accept screen for in-store POS order: $orderNumber / $orderId (source: $source, type: $orderType)');
      return;
    }

    if (_isShowing && (_currentShowingOrderId == orderId || _currentShowingOrderNumber == orderNumber)) {
      debugPrint('[IncomingOrderAcceptScreen] Already presenting order $orderId (#$orderNumber)');
      return;
    }

    final List<Map<String, dynamic>> parsedItems = [];
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
    _currentShowingOrderNumber = orderNumber;

    try {
      SoundService.playOrderRingtone();
    } catch (_) {}

    final effectiveCreatedAt = (createdAt != null ? (createdAt.isUtc ? createdAt.toLocal() : createdAt) : DateTime.now());

    try {
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (screenCtx) {
            _currentScreenContext = screenCtx;
            return IncomingOrderAcceptScreen(
              orderId: orderId,
              orderNumber: orderNumber,
              customerPhone: customerPhone,
              customerName: customerName ?? 'Customer',
              totalAmount: totalAmount,
              orderType: orderType ?? 'takeaway',
              deliveryAddress: deliveryAddress ?? '',
              tableNumber: tableNumber,
              items: parsedItems,
              createdAt: effectiveCreatedAt,
              source: source ?? 'whatsapp',
              autoAccept: autoAccept,
              autoReject: autoReject,
            );
          },
        ),
      );
    } finally {
      SoundService.stopOrderRingtone();
      _isShowing = false;
      _currentShowingOrderId = null;
      _currentShowingOrderNumber = null;
      _currentScreenContext = null;
    }
  }

  /// Launch directly from a decoded data map payload (from FCM, socket, or local prefs)
  static Future<void> openFromPayload(
    BuildContext context,
    Map<String, dynamic> data, {
    bool autoAccept = false,
    bool autoReject = false,
  }) async {
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};

    final orderId = metadata['orderId']?.toString() ??
        data['orderId']?.toString() ??
        data['entityId']?.toString() ??
        '';
    final orderNumber = metadata['orderNumber']?.toString() ??
        data['orderNumber']?.toString() ??
        '';
    final phone = metadata['customerPhone']?.toString() ??
        data['customerPhone']?.toString() ??
        '';
    final name = metadata['customerName']?.toString() ??
        data['customerName']?.toString() ??
        'Customer';
    final totalAmount = double.tryParse(
            metadata['totalAmount']?.toString() ??
                data['totalAmount']?.toString() ??
                '0') ??
        0.0;
    final rawOrderType = metadata['orderType']?.toString() ??
        data['orderType']?.toString() ??
        metadata['type']?.toString() ??
        data['type']?.toString() ??
        'takeaway';
    final source = metadata['orderSource']?.toString() ??
        data['orderSource']?.toString() ??
        metadata['source']?.toString() ??
        data['source']?.toString() ??
        (rawOrderType.toLowerCase().contains('whatsapp') ? 'whatsapp' : null) ??
        (rawOrderType.toLowerCase().contains('profile') ? 'profile' : null) ??
        (rawOrderType.toLowerCase().contains('storefront') ? 'storefront' : null) ??
        'whatsapp';
    final orderType = (rawOrderType.toLowerCase().contains('whatsapp') || rawOrderType.toLowerCase().contains('profile'))
        ? ((metadata['tableNumber'] != null || data['tableNumber'] != null) ? 'dineIn' : 'takeaway')
        : rawOrderType;
    final deliveryAddress = metadata['deliveryAddress']?.toString() ??
        data['deliveryAddress']?.toString() ??
        '';
    final tableNumber = metadata['tableNumber']?.toString() ??
        data['tableNumber']?.toString() ??
        metadata['table']?.toString() ??
        data['table']?.toString();
    final itemsPayload = metadata['items'] ?? data['items'];
    final createdAtStr = metadata['createdAt']?.toString() ?? data['createdAt']?.toString();
    DateTime? createdAt;
    if (createdAtStr != null && createdAtStr.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(createdAtStr);
      if (parsed != null) {
        if (createdAtStr.endsWith('Z') || createdAtStr.contains('+') || (createdAtStr.length > 19 && createdAtStr[19] == '-')) {
          createdAt = parsed.toLocal();
        } else if (createdAtStr.contains('T') && !parsed.isUtc) {
          createdAt = DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute, parsed.second, parsed.millisecond).toLocal();
        } else {
          createdAt = parsed.toLocal();
        }
      }
    }

    if (orderId.isEmpty && orderNumber.isEmpty) return;

    await open(
      context,
      orderId: orderId,
      orderNumber: orderNumber,
      customerPhone: phone,
      customerName: name,
      totalAmount: totalAmount,
      orderType: orderType,
      deliveryAddress: deliveryAddress,
      tableNumber: tableNumber,
      itemsPayload: itemsPayload,
      createdAt: createdAt,
      source: source,
      autoAccept: autoAccept,
      autoReject: autoReject,
    );
  }

  /// Dismiss the accept screen if accepted or handled on another device
  static void dismissIfShowing({
    String? orderId,
    String? orderNumber,
    String? action,
    String? reason,
  }) {
    if (!_isShowing) return;

    final targetId = orderId?.trim().toLowerCase();
    final targetNum = orderNumber?.trim().toLowerCase();
    final currentId = _currentShowingOrderId?.trim().toLowerCase();
    final currentNum = _currentShowingOrderNumber?.trim().toLowerCase();

    bool isMatch = false;
    if ((targetId == null || targetId.isEmpty) && (targetNum == null || targetNum.isEmpty)) {
      isMatch = true;
    } else {
      if (targetId != null && targetId.isNotEmpty && (targetId == currentId || targetId == currentNum)) {
        isMatch = true;
      }
      if (targetNum != null && targetNum.isNotEmpty && (targetNum == currentId || targetNum == currentNum)) {
        isMatch = true;
      }
    }

    if (!isMatch) return;

    DatabaseService.markOrderDismissed(orderId, orderNumber);
    debugPrint('[IncomingOrderAcceptScreen] Auto-dismissing for order $orderId (#$orderNumber) due to remote action ($action)');
    SoundService.stopOrderRingtone();

    final ctx = _currentScreenContext;
    if (ctx != null && ctx.mounted) {
      try {
        final route = ModalRoute.of(ctx);
        if (route != null && route.isCurrent) {
          final nav = Navigator.of(ctx, rootNavigator: true);
          if (nav.canPop()) {
            nav.pop();
          } else {
            nav.pushReplacementNamed('/dashboard');
          }
        }
      } catch (e) {
        debugPrint('[IncomingOrderAcceptScreen] Error popping screen context: $e');
      }
    }

    _isShowing = false;
    _currentShowingOrderId = null;
    _currentShowingOrderNumber = null;
    _currentScreenContext = null;

    final navCtx = LocalNotificationService.navigatorKey.currentContext;
    if (navCtx != null && navCtx.mounted) {
      final isAccepted = action == 'accepted' || action == 'preparing' || action == 'confirmed';
      ScaffoldMessenger.of(navCtx).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isAccepted ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAccepted
                      ? 'Order #${orderNumber ?? ""} was accepted on another device'
                      : 'Order #${orderNumber ?? ""} was handled on another device',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: isAccepted ? const Color(0xFF0F9D58) : const Color(0xFF334155),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  State<IncomingOrderAcceptScreen> createState() => _IncomingOrderAcceptScreenState();
}

class _IncomingOrderAcceptScreenState extends State<IncomingOrderAcceptScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final DatabaseService _db = DatabaseService();

  String? get _resolvedTableNumber {
    if (widget.tableNumber != null && widget.tableNumber!.trim().isNotEmpty) {
      final clean = widget.tableNumber!.trim();
      return clean.replaceAll(RegExp(r'(?i)table\s*'), '').trim().toUpperCase();
    }
    if (widget.deliveryAddress.isNotEmpty) {
      final match = RegExp(r'(?:table|tbl|t)\s*[:#\-]?\s*([0-9a-zA-Z]+)', caseSensitive: false)
          .firstMatch(widget.deliveryAddress);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.toUpperCase();
      }
      if (widget.deliveryAddress.toLowerCase().contains('table')) {
        final cleaned = widget.deliveryAddress.replaceAll(RegExp(r'(?i)table\s*'), '').trim();
        if (cleaned.isNotEmpty) return cleaned.toUpperCase();
      }
    }
    final matchName = RegExp(r'\((?:table|tbl|t)?\s*([0-9a-zA-Z]+)\)', caseSensitive: false)
        .firstMatch(widget.customerName);
    if (matchName != null && matchName.group(1) != null) {
      return matchName.group(1)!.toUpperCase();
    }
    return null;
  }

  bool get _isTableOrder {
    final cleanType = widget.orderType.toLowerCase();
    final cleanSource = widget.source.toLowerCase();
    return cleanType.contains('dine') ||
        cleanType.contains('table') ||
        cleanSource.contains('qr') ||
        cleanSource.contains('table') ||
        widget.deliveryAddress.toLowerCase().contains('table') ||
        _resolvedTableNumber != null;
  }

  int _selectedPrepTime = 20;
  bool _isProcessing = false;
  bool _isRingtoneMuted = false;
  bool _hasClosed = false;
  late AnimationController _pulseController;
  Timer? _countdownTimer;
  int _secondsRemaining = 90;

  final List<int> _prepTimeOptions = [10, 15, 20, 25, 30, 45, 60];

  final List<String> _rejectionReasons = [
    'Kitchen is at maximum capacity',
    'Item(s) out of stock',
    'Restaurant is closing soon',
    'Delivery address is out of range',
    'Customer cancelled the request',
    'Other reason...',
  ];

  @override
  void initState() {
    super.initState();
    IncomingOrderAcceptScreen._currentScreenContext = context;
    DatabaseService.markOrderDismissed(widget.orderId, widget.orderNumber);

    // Start pulsing alert glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Play incoming order ringtone
    SoundService.playOrderRingtone();

    // Guarantee that this order is seeded into DatabaseService as 'pending' immediately.
    // If the user ignores it, closes the screen, or navigates away without accepting/rejecting,
    // the order will safely exist in DatabaseService in 'pending' status!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncOrderToDatabase(targetStatus: OrderStatus.pending);
    });

    // 90-second countdown for accepting order
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });

    // Check if auto-accept was triggered from background notification action button
    if (widget.autoAccept) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAccept();
      });
    } else if (widget.autoReject) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleReject();
      });
    }
  }

  void _closeScreen() {
    if (_hasClosed) return;
    _hasClosed = true;
    SoundService.stopOrderRingtone();
    IncomingOrderAcceptScreen._isShowing = false;
    IncomingOrderAcceptScreen._currentShowingOrderId = null;
    IncomingOrderAcceptScreen._currentShowingOrderNumber = null;
    IncomingOrderAcceptScreen._currentScreenContext = null;

    if (!mounted) return;
    try {
      final route = ModalRoute.of(context);
      if (route != null && route.isCurrent) {
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) {
          nav.pop();
        } else {
          nav.pushReplacementNamed('/dashboard');
        }
      }
    } catch (e) {
      debugPrint('[IncomingOrderAcceptScreen] Error closing screen: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    SoundService.stopOrderRingtone();
    IncomingOrderAcceptScreen._isShowing = false;
    IncomingOrderAcceptScreen._currentShowingOrderId = null;
    IncomingOrderAcceptScreen._currentShowingOrderNumber = null;
    if (IncomingOrderAcceptScreen._currentScreenContext == context) {
      IncomingOrderAcceptScreen._currentScreenContext = null;
    }
    final existing = _db.orders.where((o) => (widget.orderId.isNotEmpty && o.id == widget.orderId) || (widget.orderNumber.isNotEmpty && o.orderNumber == widget.orderNumber)).firstOrNull;
    if (existing == null) {
      _syncOrderToDatabase(targetStatus: OrderStatus.pending);
    }
    super.dispose();
  }

  void _toggleRingtone() {
    setState(() {
      _isRingtoneMuted = !_isRingtoneMuted;
    });
    if (_isRingtoneMuted) {
      SoundService.stopOrderRingtone();
    } else {
      SoundService.playOrderRingtone();
    }
  }

  String _formatPhone(String raw) {
    var clean = raw.trim().replaceAll('+', '').replaceAll(' ', '');
    if (clean.startsWith('91') && clean.length == 12) {
      return '+91 ${clean.substring(2, 7)} ${clean.substring(7)}';
    }
    return raw;
  }

  Future<void> _callCustomer() async {
    final cleanPhone = widget.customerPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openWhatsAppChat() {
    SoundService.stopOrderRingtone();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MetaWhatsAppChatScreen(
          initialPhone: widget.customerPhone,
          initialCustomerName: widget.customerName,
        ),
      ),
    );
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

  /// Ensures this incoming order exists in DatabaseService.orders with the specified status.
  /// If the order already exists, updates its status and details.
  /// If it does not exist, parses and inserts it as a first-class OrderModel.
  OrderModel _syncOrderToDatabase({OrderStatus targetStatus = OrderStatus.pending}) {
    // Resolve order type
    final cleanType = widget.orderType.toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');
    final OrderType resolvedType;
    if (cleanType.contains('delivery')) {
      resolvedType = OrderType.delivery;
    } else if (cleanType.contains('takeaway') || cleanType.contains('pickup') || cleanType.contains('parcel')) {
      resolvedType = OrderType.takeaway;
    } else if (cleanType.contains('dine') || cleanType.contains('table') || widget.deliveryAddress.toLowerCase().contains('table')) {
      resolvedType = OrderType.dineIn;
    } else {
      resolvedType = OrderType.takeaway;
    }

    // Resolve table number if dine-in
    String? tableNum = _resolvedTableNumber;
    if (tableNum == null && resolvedType == OrderType.dineIn) {
      final match = RegExp(r'(?:table|tbl|t)\s*[:#\-]?\s*([0-9a-zA-Z]+)', caseSensitive: false)
          .firstMatch('${widget.deliveryAddress} ${widget.orderNumber}');
      if (match != null) {
        tableNum = match.group(1);
      } else if (widget.deliveryAddress.trim().isNotEmpty) {
        tableNum = widget.deliveryAddress.trim();
      }
    }
    if (tableNum != null && !tableNum.toLowerCase().startsWith('table') && !tableNum.toLowerCase().startsWith('t')) {
      final existingTable = _db.tables.where((t) => isSameTable(t.name, tableNum)).firstOrNull;
      if (existingTable != null) {
        tableNum = existingTable.name;
      }
    }
    final existingIdx = _db.orders.indexWhere(
      (o) => (widget.orderId.isNotEmpty && o.id == widget.orderId) ||
             (widget.orderNumber.isNotEmpty && o.orderNumber == widget.orderNumber),
    );

    if (existingIdx >= 0) {
      final existing = _db.orders[existingIdx];
      final updated = existing.copyWith(
        status: targetStatus,
        isPaid: resolvedType == OrderType.dineIn ? false : existing.isPaid,
        paymentStatus: resolvedType == OrderType.dineIn ? 'pending' : existing.paymentStatus,
        paymentMethod: resolvedType == OrderType.dineIn ? 'Pay at Counter / Table' : existing.paymentMethod,
        tableNumber: tableNum ?? existing.tableNumber,
        deliveryAddress: widget.deliveryAddress.isNotEmpty ? widget.deliveryAddress : existing.deliveryAddress,
        customerName: widget.customerName.isNotEmpty ? widget.customerName : existing.customerName,
        customerPhone: widget.customerPhone.isNotEmpty ? widget.customerPhone : existing.customerPhone,
      );
      _db.upsertOrderLocally(updated);
      return updated;
    }

    final List<CartItemModel> cartItems = [];
    for (int i = 0; i < widget.items.length; i++) {
      final it = widget.items[i];
      final actualItem = it['item'] is Map ? Map<String, dynamic>.from(it['item'] as Map) : it;
      final name = (actualItem['name'] ?? actualItem['title'] ?? it['name'] ?? 'Item ${i + 1}').toString();
      final qty = (it['quantity'] is num)
          ? (it['quantity'] as num).toInt()
          : (int.tryParse(it['quantity']?.toString() ?? '1') ?? 1);
      final price = _resolveItemPrice(it, actualItem, qty);

      final menuItem = MenuItemModel(
        id: (actualItem['id'] ?? actualItem['productId'] ?? it['productId'] ?? 'item_$i').toString(),
        name: name,
        price: price,
        category: (actualItem['category'] ?? it['category'] ?? 'General').toString(),
        description: name,
        itemType: (actualItem['isVeg'] == true || it['isVeg'] == true) ? 'Veg' : 'Non-Veg',
      );
      cartItems.add(CartItemModel(
        item: menuItem,
        quantity: qty,
        note: (it['notes'] ?? it['note'] ?? actualItem['notes'] ?? actualItem['note'])?.toString(),
      ));
    }

    final newOrder = OrderModel(
      id: widget.orderId.isNotEmpty ? widget.orderId : 'ord_${DateTime.now().millisecondsSinceEpoch}',
      orderNumber: widget.orderNumber.isNotEmpty ? widget.orderNumber : '${DateTime.now().millisecondsSinceEpoch.remainder(10000)}',
      customerName: widget.customerName,
      customerPhone: widget.customerPhone,
      deliveryAddress: widget.deliveryAddress,
      tableNumber: tableNum ?? _resolvedTableNumber,
      orderType: resolvedType,
      status: targetStatus,
      items: cartItems,
      subtotal: widget.totalAmount,
      taxAmount: 0.0,
      totalAmount: widget.totalAmount,
      orderSource: widget.source.isNotEmpty ? widget.source : 'whatsapp',
      createdAt: widget.createdAt.toIso8601String(),
      isPaid: false,
      paymentStatus: 'pending',
      paymentMethod: resolvedType == OrderType.dineIn ? 'Pay at Counter / Table' : 'Pending',
      isSynced: true,
    );

    _db.upsertOrderLocally(newOrder);
    return newOrder;
  }

  Future<void> _handleAccept() async {
    if (_isProcessing) return;
    SoundService.stopOrderRingtone();
    SoundService.playButtonClick();
    setState(() => _isProcessing = true);

    // 0. Notify other devices via WebSocket to dismiss popup instantly
    try {
      SocketService().emitOrderModalAction(
        orderId: widget.orderId,
        orderNumber: widget.orderNumber,
        action: 'accepted',
        prepTimeMinutes: _selectedPrepTime,
      );
    } catch (e) {
      debugPrint('[IncomingOrderAcceptScreen] Error emitting socket action: $e');
    }

    try {
      // 1. Immediately update order in DatabaseService to 'OrderStatus.preparing'
      final updatedOrder = _syncOrderToDatabase(targetStatus: OrderStatus.preparing);

      // If Dine-In with table, update table status to runningKot and populate cart & customer info
      final isTableOrderActive = updatedOrder.orderType == OrderType.dineIn || _isTableOrder;
      final String? tableRef = updatedOrder.tableNumber ?? _resolvedTableNumber;
      if (isTableOrderActive && tableRef != null && tableRef.trim().isNotEmpty) {
        final cleanTableRef = tableRef.trim();

        // 1. Locate existing table or create it dynamically (e.g. Table 8)
        TableModel? targetTbl = _db.tables.where((t) =>
            isSameTable(t.name, cleanTableRef) ||
            isSameTable(t.tableNumber.toString(), cleanTableRef) ||
            isSameTable('T-${t.tableNumber}', cleanTableRef) ||
            t.tableNumber.toString() == cleanTableRef.replaceAll(RegExp(r'[^0-9]'), '')
        ).firstOrNull;

        final nowIso = DateTime.now().toIso8601String();
        if (targetTbl == null) {
          final int num = int.tryParse(cleanTableRef.replaceAll(RegExp(r'[^0-9]'), '')) ?? 8;
          final String autoName = cleanTableRef.toLowerCase().startsWith('t') || cleanTableRef.toLowerCase().startsWith('table')
              ? cleanTableRef
              : 'T-$num';
          targetTbl = TableModel(
            id: 'table_${num}_${DateTime.now().millisecondsSinceEpoch}',
            tableNumber: num,
            name: autoName,
            floor: 'Ground Floor',
            capacity: 4,
            status: TableStatus.runningKot,
            currentOrderId: updatedOrder.id,
            occupiedSince: nowIso,
            activeOrderNumber: updatedOrder.orderNumber,
            activeOrderTotal: updatedOrder.totalAmount,
            activeItemCount: updatedOrder.items.length,
          );
          _db.tables.add(targetTbl);
          await _db.saveTablesToPrefs();
        } else {
          final tblOccupiedSince = targetTbl.occupiedSince ?? nowIso;
          await _db.updateTableStatus(
            targetTbl.id,
            TableStatus.runningKot,
            orderId: updatedOrder.id,
            occupiedSince: tblOccupiedSince,
          );

          final idx = _db.tables.indexWhere((t) => t.id == targetTbl!.id);
          if (idx >= 0) {
            _db.tables[idx] = _db.tables[idx].copyWith(
              status: TableStatus.runningKot,
              currentOrderId: updatedOrder.id,
              activeOrderNumber: updatedOrder.orderNumber,
              activeOrderTotal: updatedOrder.totalAmount,
              activeItemCount: updatedOrder.items.length,
              occupiedSince: tblOccupiedSince,
            );
            await _db.saveTablesToPrefs();
          }
        }

        // 2. Store live cart items & totals for instantaneous POS and table grid sync
        _db.setLiveTableCart(targetTbl.name, updatedOrder.items);
        _db.setLiveCartTotal(targetTbl.name, updatedOrder.totalAmount);
        if (cleanTableRef != targetTbl.name) {
          _db.setLiveTableCart(cleanTableRef, updatedOrder.items);
          _db.setLiveCartTotal(cleanTableRef, updatedOrder.totalAmount);
        }

        // 3. Store filled customer name and mobile number on the table
        if (updatedOrder.customerName != null && updatedOrder.customerName!.isNotEmpty) {
          _db.setLiveCustomerInfo(
            targetTbl.name,
            name: updatedOrder.customerName!,
            phone: updatedOrder.customerPhone ?? '',
          );
          if (cleanTableRef != targetTbl.name) {
            _db.setLiveCustomerInfo(
              cleanTableRef,
              name: updatedOrder.customerName!,
              phone: updatedOrder.customerPhone ?? '',
            );
          }
        }
        _db.notifyListeners();
      }

      // 2. Dispatch backend acceptance
      await _orderService.acceptWhatsAppOrder(
        widget.orderId,
        prepTimeMinutes: _selectedPrepTime,
      );

      // 3. Proactively sync orders in background to keep all fields fresh
      unawaited(_db.syncOrdersOnly());

      // 4. Auto-print KOT if thermal printer configured
      bool kotPrinted = false;
      try {
        final printer = BluetoothPrinterService();
        kotPrinted = await printer.printKOT(order: updatedOrder);
        if (kotPrinted) {
          debugPrint('[IncomingOrderAcceptScreen] KOT successfully auto-printed for Table #${updatedOrder.tableNumber ?? _resolvedTableNumber}');
        } else {
          debugPrint('[IncomingOrderAcceptScreen] Thermal printer not connected or unavailable. Skipping auto-print gracefully.');
        }
      } catch (printErr) {
        debugPrint('[IncomingOrderAcceptScreen] Auto-print KOT notice (non-fatal): $printErr');
      }

      // 5. Update storefront order status in Firestore for real-time customer tracking
      try {
        FirestoreService().updateStorefrontOrderStatus(widget.orderId, 'preparing', 1);
      } catch (_) {}

      _closeScreen();

      final navCtx = LocalNotificationService.navigatorKey.currentContext;
      if (navCtx != null && navCtx.mounted) {
        final String tblDisplay = tableRef != null && tableRef.isNotEmpty ? 'Table $tableRef • ' : '';
        final String printMsg = kotPrinted ? ' (KOT Printed)' : '';
        ScaffoldMessenger.of(navCtx).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${tblDisplay}Order #${widget.orderNumber} Accepted & Sent to KOT!$printMsg Prep: $_selectedPrepTime mins.',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
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
    final customController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            final isOther = selectedReason == 'Other reason...';
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Decline Incoming Order',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Choose a reason to notify customer for Order #${widget.orderNumber}:',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    ..._rejectionReasons.map((reason) {
                      final isSelected = selectedReason == reason;
                      return InkWell(
                        onTap: () => setSheetState(() => selectedReason = reason),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                size: 20,
                                color: isSelected ? Colors.red.shade700 : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 12),
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
                      const SizedBox(height: 10),
                      TextField(
                        controller: customController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Enter reason to send to customer...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetCtx).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(sheetCtx).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Confirm Decline', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final finalReason = (selectedReason == 'Other reason...' && customController.text.trim().isNotEmpty)
        ? customController.text.trim()
        : selectedReason;

    setState(() => _isProcessing = true);

    try {
      SocketService().emitOrderModalAction(
        orderId: widget.orderId,
        orderNumber: widget.orderNumber,
        action: 'rejected',
        reason: finalReason,
      );
    } catch (_) {}

    try {
      _syncOrderToDatabase(targetStatus: OrderStatus.cancelled);
      await _orderService.rejectWhatsAppOrder(widget.orderId, reason: finalReason);
      unawaited(_db.syncOrdersOnly());

      _closeScreen();

      final navCtx = LocalNotificationService.navigatorKey.currentContext;
      if (navCtx != null && navCtx.mounted) {
        ScaffoldMessenger.of(navCtx).showSnackBar(
          SnackBar(
            content: Text('Order #${widget.orderNumber} declined: $finalReason'),
            backgroundColor: const Color(0xFF334155),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error declining order: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // Design system constants matching media_1793469958616_efecc446.png
  static const Color _bgCanvas = Color(0xFFF1F5F9);
  static const Color _cardBg = Colors.white;
  static const Color _borderSubtle = Color(0xFFE2E8F0);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _primaryGreen = Color(0xFF00A859);
  static const Color _mintBadgeBg = Color(0xFFDCFCE7);
  static const Color _mintBadgeText = Color(0xFF15803D);
  static const Color _cyanBadgeBg = Color(0xFFCCFBF1);
  static const Color _cyanBadgeText = Color(0xFF0F766E);

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final isDelivery = widget.orderType.toLowerCase() == 'delivery';

    return PopScope(
      canPop: !_isProcessing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _hasClosed = true;
          SoundService.stopOrderRingtone();
          IncomingOrderAcceptScreen._isShowing = false;
          IncomingOrderAcceptScreen._currentShowingOrderId = null;
          IncomingOrderAcceptScreen._currentShowingOrderNumber = null;
          IncomingOrderAcceptScreen._currentScreenContext = null;
        }
      },
      child: Scaffold(
        backgroundColor: _bgCanvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 1. Top Bar (< Back, Green Dot + NEW INCOMING ORDER, Sound Toggle Button)
              _buildTopBar(),
              const SizedBox(height: 4),

              // 2. High Priority Alert Banner with Countdown (Incoming order requires action + 52s)
              _buildTopAlertBar(),
              const SizedBox(height: 8),

              // 3. Scrollable Cards
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Order Header Card (WhatsApp, #ORD-..., NEW ORDER, Received timestamp)
                      _buildOrderHeaderCard(),
                      const SizedBox(height: 8),

                      // Customer Information Card (Avatar U, unknown, verified, call, chat)
                      _buildCustomerCard(isDelivery),
                      const SizedBox(height: 8),

                      // Order Items Card (ORDER ITEMS, 1 Item, veg/non-veg, item title, (Medium), 4x, price)
                      _buildItemsCard(currencyFormatter),
                      const SizedBox(height: 8),

                      // Bill Breakdown Card (Item Subtotal, Taxes & Charges, Grand Total in mint box)
                      _buildBillCard(currencyFormatter),
                      const SizedBox(height: 8),

                      // Kitchen Preparation Time Selector Card (🕒 PREPARATION TIME)
                      _buildPrepTimeCard(),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),

              // 4. Fixed Bottom Action Bar (✕ REJECT & ✔ ACCEPT ORDER)
              _buildBottomActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Left: Rounded squarish Back Button
          InkWell(
            onTap: () {
              DatabaseService.markOrderDismissed(widget.orderId, widget.orderNumber);
              _closeScreen();
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderSubtle),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.chevron_left_rounded, size: 22, color: _textDark),
              ),
            ),
          ),

          const Spacer(),

          // Center: Green dot + NEW INCOMING ORDER
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF10B981),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.5 * _pulseController.value + 0.3),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              Text(
                _isTableOrder ? 'TABLE QR INCOMING ORDER' : 'NEW INCOMING ORDER',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: _textDark,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Right: Rounded squarish Sound Button
          InkWell(
            onTap: _toggleRingtone,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderSubtle),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _isRingtoneMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  size: 17,
                  color: const Color(0xFF0D9488),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAlertBar() {
    final isTable = _isTableOrder;
    final tblNum = _resolvedTableNumber;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isTable
                ? const [Color(0xFFECFDF5), Color(0xFFD1FAE5)]
                : const [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isTable ? const Color(0xFFA7F3D0) : const Color(0xFFFFCDD3),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 6,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isTable ? Icons.table_restaurant_rounded : Icons.notifications_active_rounded,
              color: isTable ? const Color(0xFF059669) : const Color(0xFFE11D48),
              size: 17,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  isTable
                      ? 'Table ${tblNum ?? "Dine-In"} QR order requires your action'
                      : 'Incoming order requires your action',
                  style: TextStyle(
                    color: isTable ? const Color(0xFF065F46) : const Color(0xFFB91C1C),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isTable ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isTable ? const Color(0xFF6EE7B7) : const Color(0xFFFDA4AF),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.alarm_rounded,
                    color: isTable ? const Color(0xFF059669) : const Color(0xFFE11D48),
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${_secondsRemaining}s',
                    style: TextStyle(
                      color: isTable ? const Color(0xFF065F46) : const Color(0xFFB91C1C),
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
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

  Widget _buildOrderHeaderCard() {
    final orderNumDisplay = widget.orderNumber.startsWith('#')
        ? widget.orderNumber
        : '#${widget.orderNumber}';
    final isTable = _isTableOrder;
    final tblNum = _resolvedTableNumber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderSubtle.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x03000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Order Type / Channel Emblem
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isTable
                    ? const [Color(0xFF0D9488), Color(0xFF059669)]
                    : const [Color(0xFF25D366), Color(0xFF1EBE5D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isTable ? const Color(0x330D9488) : const Color(0x2825D366),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: isTable
                  ? const Icon(
                      Icons.table_restaurant_rounded,
                      color: Colors.white,
                      size: 24,
                    )
                  : Image.asset(
                      'assets/images/whatsapp_logo.png',
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, st) => const Icon(
                        Icons.chat_bubble_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isTable)
                  Row(
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, size: 12, color: Color(0xFF0D9488)),
                      const SizedBox(width: 4),
                      const Text(
                        'TABLE QR DINE-IN',
                        style: TextStyle(
                          color: Color(0xFF0D9488),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    widget.source.toUpperCase(),
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      orderNumDisplay,
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _mintBadgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'NEW ORDER',
                        style: TextStyle(
                          color: _mintBadgeText,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    if (isTable)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF059669), Color(0xFF047857)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [
                            BoxShadow(color: Color(0x22059669), blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.table_bar_rounded, size: 11, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              'TABLE ${tblNum ?? "DINE-IN"}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: widget.orderType.toLowerCase() == 'delivery'
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.orderType.toUpperCase(),
                          style: TextStyle(
                            color: widget.orderType.toLowerCase() == 'delivery'
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF7E22CE),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Received : ${DateFormat('h:mm a • d MMM, yyyy').format(widget.createdAt.toLocal())}',
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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
    final isTable = _isTableOrder;
    final tblNum = _resolvedTableNumber;

    String displayName = widget.customerName.isNotEmpty && widget.customerName != 'Customer'
        ? widget.customerName
        : (isTable ? 'Guest Customer' : 'unknown');

    if (isTable && displayName.contains('(')) {
      displayName = displayName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
      if (displayName.isEmpty) displayName = 'Guest Customer';
    }

    final customerInitial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'G';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderSubtle.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x03000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table QR Highlight Banner
          if (isTable) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.table_restaurant_rounded, color: Color(0xFF16A34A), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'DINING AT TABLE ${tblNum ?? "DINE-IN"}',
                              style: const TextStyle(
                                color: Color(0xFF15803D),
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: const Text(
                                'QR SCAN',
                                style: TextStyle(
                                  color: Color(0xFF166534),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Customer scanned table QR code & ordered live',
                          style: TextStyle(
                            color: Color(0xFF4B5563),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              // Avatar circle with mint/cyan background
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: _cyanBadgeBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    customerInitial,
                    style: const TextStyle(
                      color: _cyanBadgeText,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              color: _textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFFEAB308),
                          size: 15,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.customerPhone.isNotEmpty
                          ? _formatPhone(widget.customerPhone)
                          : (isTable ? 'Self-Service Table Customer' : 'No Phone Provided'),
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Call Button
              if (widget.customerPhone.isNotEmpty) ...[
                InkWell(
                  onTap: _callCustomer,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _borderSubtle),
                      boxShadow: const [
                        BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.call_rounded, color: Color(0xFF2563EB), size: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // WhatsApp Chat Button
                InkWell(
                  onTap: _openWhatsAppChat,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _borderSubtle),
                      boxShadow: const [
                        BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.chat_outlined, color: Color(0xFF16A34A), size: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (isDelivery && widget.deliveryAddress.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.deliveryAddress,
                      style: const TextStyle(color: Color(0xFF334155), fontSize: 11.5, fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsCard(NumberFormat currencyFormatter) {
    final itemsList = widget.items.isNotEmpty
        ? widget.items
        : [
            {
              'name': 'Classic Chicken Pizza',
              'variantName': 'Medium',
              'quantity': 4,
              'price': 429.0,
              'isVeg': false,
            }
          ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderSubtle.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x03000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ORDER ITEMS',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${itemsList.length} ${itemsList.length == 1 ? "Item" : "Items"}',
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemsList.length,
            separatorBuilder: (ctx, idx) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 5),
              child: Divider(color: Color(0xFFF1F5F9), height: 1),
            ),
            itemBuilder: (context, index) {
              final rawItem = itemsList[index];
              final actualItem = (rawItem['item'] is Map)
                  ? Map<String, dynamic>.from(rawItem['item'])
                  : rawItem;
              final name = (actualItem['name'] ?? rawItem['name'] ?? 'Item').toString();
              final variant = (actualItem['variantName'] ??
                  actualItem['selectedVariant'] ??
                  actualItem['variant'] ??
                  actualItem['portion'] ??
                  actualItem['size'] ??
                  rawItem['variantName'] ??
                  rawItem['variant'] ??
                  '').toString();
              final qty = (rawItem['quantity'] ?? actualItem['quantity'] ?? 1) as num;
              final price = _resolveItemPrice(rawItem, actualItem, qty);
              final isVeg = (actualItem['isVeg'] == true) ||
                  (actualItem['foodType'] == 'veg') ||
                  (rawItem['foodType'] == 'veg');

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Veg / Non-Veg Indicator
                  Container(
                    width: 14,
                    height: 14,
                    padding: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: isVeg ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isVeg ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: _textDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        if (variant.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            variant.startsWith('(') ? variant : '($variant)',
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Quantity Badge (4x)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _cyanBadgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${qty}x',
                      style: const TextStyle(
                        color: _cyanBadgeText,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Item Price
                  Text(
                    currencyFormatter.format(price * qty),
                    style: const TextStyle(
                      color: _textDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              );
            },
          ),
          if (_isTableOrder) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.soup_kitchen_rounded, size: 16, color: Color(0xFF059669)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Table order items will be auto-routed to Kitchen Display (KOT) upon acceptance',
                      style: TextStyle(
                        color: Color(0xFF065F46),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBillCard(NumberFormat currencyFormatter) {
    double computedSubtotal = 0.0;
    for (final rawItem in widget.items) {
      final actualItem = (rawItem['item'] is Map)
          ? Map<String, dynamic>.from(rawItem['item'])
          : rawItem;
      final qty = (rawItem['quantity'] ?? actualItem['quantity'] ?? 1) as num;
      final price = _resolveItemPrice(rawItem, actualItem, qty);
      computedSubtotal += (price * qty);
    }

    if (computedSubtotal <= 0.0 && widget.totalAmount > 0.0) {
      computedSubtotal = (widget.totalAmount / 1.05).roundToDouble();
    }

    double taxes = (widget.totalAmount - computedSubtotal);
    if (taxes < 0) taxes = 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderSubtle.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x03000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Item Subtotal',
                style: TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                currencyFormatter.format(computedSubtotal > 0 ? computedSubtotal : widget.totalAmount),
                style: const TextStyle(color: _textDark, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
          if (taxes > 0) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Taxes & Charges',
                  style: TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  '+${currencyFormatter.format(taxes)}',
                  style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ],
            ),
          ],
          if (_isTableOrder) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.table_restaurant_outlined, size: 13, color: _textMuted),
                    const SizedBox(width: 4),
                    const Text(
                      'Dining Table Service',
                      style: TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Text(
                  'FREE',
                  style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          // Grand Total Container in Mint Green
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F9F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Grand Total',
                  style: TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  currencyFormatter.format(widget.totalAmount),
                  style: const TextStyle(
                    color: _primaryGreen,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          if (_isTableOrder) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 5),
                const Expanded(
                  child: Text(
                    'Payment Mode: Pay at Counter / Table after dining',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrepTimeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderSubtle.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x03000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.access_time_filled_rounded, color: Color(0xFFF59E0B), size: 15),
              SizedBox(width: 6),
              Text(
                'PREPARATION TIME',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _prepTimeOptions.map((time) {
                final isSelected = _selectedPrepTime == time;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => setState(() => _selectedPrepTime = time),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryGreen : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? _primaryGreen : _borderSubtle,
                          width: isSelected ? 1.2 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? const [
                                BoxShadow(color: Color(0x2800A859), blurRadius: 4, offset: Offset(0, 1)),
                              ]
                            : null,
                      ),
                      child: Text(
                        '$time mins',
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: REJECT Button
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: _isProcessing ? null : _handleReject,
              borderRadius: BorderRadius.circular(21),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 15),
                    SizedBox(width: 4),
                    Text(
                      'REJECT',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Right: ACCEPT ORDER / ACCEPT & SEND TO KOT Button
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: _isProcessing ? null : _handleAccept,
              borderRadius: BorderRadius.circular(21),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isTableOrder
                        ? const [Color(0xFF059669), Color(0xFF047857)]
                        : const [Color(0xFF00B050), Color(0xFF009640)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(21),
                  boxShadow: [
                    BoxShadow(
                      color: _isTableOrder
                          ? const Color(0x35059669)
                          : const Color(0x3500A859),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isTableOrder ? Icons.soup_kitchen_rounded : Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isTableOrder ? 'ACCEPT & SEND TO KOT' : 'ACCEPT ORDER',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
