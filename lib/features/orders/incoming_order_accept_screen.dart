import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
/// Displays when new orders arrive via Table QR, Storefront, or WhatsApp,
/// with clean, modern, and uncluttered UI.
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
    // 1. Check if already dismissed or completed
    if (DatabaseService.isOrderDismissed(orderId, orderNumber)) {
      debugPrint('[IncomingOrderAcceptScreen] Blocked order accept screen: order #$orderNumber is already dismissed.');
      return;
    }

    final localMatch = DatabaseService().orders.where((o) =>
        (orderId.isNotEmpty && o.id == orderId) ||
        (orderNumber.isNotEmpty && o.orderNumber == orderNumber)).firstOrNull;
    if (localMatch != null && localMatch.status != OrderStatus.pending) {
      DatabaseService.markOrderDismissed(orderId, orderNumber);
      debugPrint('[IncomingOrderAcceptScreen] Blocked order accept screen: order #$orderNumber is already ${localMatch.status}.');
      return;
    }

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
      debugPrint('[IncomingOrderAcceptScreen] Blocked for in-store POS order: #$orderNumber');
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

    if (orderId.isEmpty && orderNumber.isEmpty) return;

    // Check if dismissed or non-pending
    if (DatabaseService.isOrderDismissed(orderId, orderNumber)) return;
    final localMatch = DatabaseService().orders.where((o) =>
        (orderId.isNotEmpty && o.id == orderId) ||
        (orderNumber.isNotEmpty && o.orderNumber == orderNumber)).firstOrNull;
    if (localMatch != null && localMatch.status != OrderStatus.pending) {
      DatabaseService.markOrderDismissed(orderId, orderNumber);
      return;
    }

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
        'storefront';

    // Comprehensive table number extraction
    String? tableNumber = metadata['tableNumber']?.toString() ??
        data['tableNumber']?.toString() ??
        metadata['table']?.toString() ??
        data['table']?.toString() ??
        metadata['tableNo']?.toString() ??
        data['tableNo']?.toString() ??
        metadata['tableName']?.toString() ??
        data['tableName']?.toString() ??
        metadata['table_number']?.toString() ??
        data['table_number']?.toString() ??
        metadata['tableCode']?.toString() ??
        data['tableCode']?.toString() ??
        metadata['t']?.toString() ??
        data['t']?.toString() ??
        metadata['T']?.toString() ??
        data['T']?.toString();

    final deliveryAddress = metadata['deliveryAddress']?.toString() ??
        data['deliveryAddress']?.toString() ??
        '';

    if (tableNumber == null || tableNumber.trim().isEmpty) {
      final match = RegExp(r'(?:table|tbl|t)[\s\-_]*([0-9a-zA-Z]+)', caseSensitive: false)
          .firstMatch(deliveryAddress);
      if (match != null && match.group(1) != null) {
        tableNumber = match.group(1);
      }
    }

    final orderType = (tableNumber != null && tableNumber.trim().isNotEmpty)
        ? 'dineIn'
        : rawOrderType;

    final itemsPayload = metadata['items'] ??
        data['items'] ??
        metadata['orderItems'] ??
        data['orderItems'] ??
        metadata['products'] ??
        data['products'] ??
        metadata['cartItems'] ??
        data['cartItems'];

    final createdAtStr = metadata['createdAt']?.toString() ?? data['createdAt']?.toString();
    DateTime? createdAt;
    if (createdAtStr != null && createdAtStr.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(createdAtStr);
      if (parsed != null) {
        createdAt = parsed.isUtc ? parsed.toLocal() : parsed;
      }
    }

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
  }

  @override
  State<IncomingOrderAcceptScreen> createState() => _IncomingOrderAcceptScreenState();
}

class _IncomingOrderAcceptScreenState extends State<IncomingOrderAcceptScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final DatabaseService _db = DatabaseService();

  /// Extract clean table number (e.g. "2" from "T02", "Table 2", "T-02", "2")
  String? get _resolvedTableNumber {
    String? raw = widget.tableNumber;
    if (raw == null || raw.trim().isEmpty) {
      final match = RegExp(r'(?:table|tbl|t)[\s\-_]*([0-9a-zA-Z]+)', caseSensitive: false)
          .firstMatch(widget.deliveryAddress);
      if (match != null && match.group(1) != null) {
        raw = match.group(1);
      }
    }
    if (raw == null || raw.trim().isEmpty) {
      final matchName = RegExp(r'\((?:table|tbl|t)?[\s\-_]*([0-9a-zA-Z]+)\)', caseSensitive: false)
          .firstMatch(widget.customerName);
      if (matchName != null && matchName.group(1) != null) {
        raw = matchName.group(1);
      }
    }
    if (raw == null || raw.trim().isEmpty) {
      if (widget.deliveryAddress.toLowerCase().contains('table')) {
        final cleaned = widget.deliveryAddress.replaceAll(RegExp(r'(?i)table\s*'), '').trim();
        if (cleaned.isNotEmpty) raw = cleaned;
      }
    }
    if (raw == null || raw.trim().isEmpty) {
      final local = _db.orders.where((o) =>
          (widget.orderId.isNotEmpty && o.id == widget.orderId) ||
          (widget.orderNumber.isNotEmpty && o.orderNumber == widget.orderNumber)
      ).firstOrNull;
      if (local != null && local.tableNumber != null && local.tableNumber!.trim().isNotEmpty) {
        raw = local.tableNumber;
      }
    }

    if (raw == null || raw.trim().isEmpty) return null;

    final clean = raw.trim();
    // Normalize T02, T-02, T2, Table 2 -> "2"
    final numMatch = RegExp(r'^(?:table|tbl|t)[\s\-_]*(\d+)$', caseSensitive: false).firstMatch(clean);
    if (numMatch != null && numMatch.group(1) != null) {
      final n = int.tryParse(numMatch.group(1)!);
      if (n != null) return '$n';
    }
    final pureNum = int.tryParse(clean);
    if (pureNum != null) return '$pureNum';

    return clean.replaceAll(RegExp(r'(?i)^table\s*'), '').trim();
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

  /// Resolved items list: uses widget.items or falls back to actual items from DatabaseService.orders
  List<Map<String, dynamic>> get _resolvedItems {
    if (widget.items.isNotEmpty) return widget.items;

    final local = _db.orders.where((o) =>
        (widget.orderId.isNotEmpty && o.id == widget.orderId) ||
        (widget.orderNumber.isNotEmpty && o.orderNumber == widget.orderNumber)
    ).firstOrNull;
    if (local != null && local.items.isNotEmpty) {
      return local.items.map((i) => {
        'name': i.item.name,
        'quantity': i.quantity,
        'price': i.item.effectivePrice > 0 ? i.item.effectivePrice : i.item.price,
        'isVeg': i.item.isVeg,
        'variantName': i.item.portion ?? '',
        'notes': i.note,
      }).toList();
    }

    return [];
  }

  int _selectedPrepTime = 20;
  bool _isProcessing = false;
  bool _isRingtoneMuted = false;
  bool _hasClosed = false;
  late AnimationController _pulseController;
  Timer? _countdownTimer;
  int _secondsRemaining = 90;

  final List<int> _prepTimeOptions = [10, 15, 20, 25, 30, 45];

  final List<String> _rejectionReasons = [
    'Kitchen is at maximum capacity',
    'Item(s) out of stock',
    'Restaurant is closing soon',
    'Customer requested cancellation',
    'Other reason...',
  ];

  @override
  void initState() {
    super.initState();
    IncomingOrderAcceptScreen._currentScreenContext = context;
    DatabaseService.markOrderDismissed(widget.orderId, widget.orderNumber);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    SoundService.playOrderRingtone();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncOrderToDatabase(targetStatus: OrderStatus.pending);
    });

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

    if (widget.autoAccept) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleAccept());
    } else if (widget.autoReject) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleReject());
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

    DatabaseService.markOrderDismissed(widget.orderId, widget.orderNumber);
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('pending_incoming_order_payload');
    }).catchError((_) {});

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
    super.dispose();
  }

  void _toggleRingtone() {
    setState(() => _isRingtoneMuted = !_isRingtoneMuted);
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
        if (prod != null && prod.price > 0) price = prod.price;
      }
      if (price <= 0.0) {
        final name = (actualItem['name'] ?? item['name'] ?? '').toString();
        if (name.isNotEmpty) {
          final prod = _db.getProductById(name);
          if (prod != null && prod.price > 0) price = prod.price;
        }
      }
    }

    if (price <= 0.0 && widget.items.length == 1 && widget.totalAmount > 0 && qty > 0) {
      price = widget.totalAmount / qty;
    }

    return price;
  }

  OrderModel _syncOrderToDatabase({OrderStatus targetStatus = OrderStatus.pending}) {
    final OrderType resolvedType = _isTableOrder ? OrderType.dineIn : (
      widget.orderType.toLowerCase().contains('delivery') ? OrderType.delivery : OrderType.takeaway
    );

    final String? tableNum = _resolvedTableNumber;

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

    final itemsList = _resolvedItems;
    final List<CartItemModel> cartItems = [];
    for (int i = 0; i < itemsList.length; i++) {
      final it = itemsList[i];
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
      tableNumber: tableNum,
      orderType: resolvedType,
      status: targetStatus,
      items: cartItems,
      subtotal: widget.totalAmount,
      taxAmount: 0.0,
      totalAmount: widget.totalAmount,
      orderSource: widget.source.isNotEmpty ? widget.source : (_isTableOrder ? 'storefront' : 'whatsapp'),
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

    try {
      SocketService().emitOrderModalAction(
        orderId: widget.orderId,
        orderNumber: widget.orderNumber,
        action: 'accepted',
        prepTimeMinutes: _selectedPrepTime,
      );
    } catch (_) {}

    try {
      DatabaseService.markOrderDismissed(widget.orderId, widget.orderNumber);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_incoming_order_payload');

      final updatedOrder = _syncOrderToDatabase(targetStatus: OrderStatus.preparing);

      // Handle Table KOT and Live Sync
      final String? tableRef = updatedOrder.tableNumber ?? _resolvedTableNumber;
      if (_isTableOrder && tableRef != null && tableRef.trim().isNotEmpty) {
        final cleanTableRef = tableRef.trim();

        TableModel? targetTbl = _db.tables.where((t) =>
            isSameTable(t.name, cleanTableRef) ||
            isSameTable(t.tableNumber.toString(), cleanTableRef) ||
            isSameTable('T-${t.tableNumber}', cleanTableRef) ||
            isSameTable('Table $cleanTableRef', t.name)
        ).firstOrNull;

        final nowIso = DateTime.now().toIso8601String();
        final int num = int.tryParse(cleanTableRef.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        final String autoName = 'Table $num';

        if (targetTbl == null) {
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

        // Live Table Cart sync
        _db.setLiveTableCart(targetTbl.name, updatedOrder.items);
        _db.setLiveCartTotal(targetTbl.name, updatedOrder.totalAmount);
        if (cleanTableRef != targetTbl.name) {
          _db.setLiveTableCart(cleanTableRef, updatedOrder.items);
          _db.setLiveCartTotal(cleanTableRef, updatedOrder.totalAmount);
        }

        // Live Customer Info on Table
        if (updatedOrder.customerName != null && updatedOrder.customerName!.isNotEmpty) {
          _db.setLiveCustomerInfo(
            targetTbl.name,
            name: updatedOrder.customerName!,
            phone: updatedOrder.customerPhone ?? '',
          );
        }
        _db.notifyListeners();
      }

      // Backend Acceptance Dispatch
      await _orderService.acceptWhatsAppOrder(
        widget.orderId,
        prepTimeMinutes: _selectedPrepTime,
      );

      unawaited(_db.syncOrdersOnly());

      // Auto-print KOT if printer available
      bool kotPrinted = false;
      try {
        final printer = BluetoothPrinterService();
        kotPrinted = await printer.printKOT(order: updatedOrder);
      } catch (_) {}

      // Update Firestore Storefront Order Status
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
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${tblDisplay}Order #${widget.orderNumber} Accepted!$printMsg Prep: $_selectedPrepTime mins',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
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

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                top: 18,
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
                        width: 36,
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
                            'Decline Order',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ..._rejectionReasons.map((reason) {
                      final isSelected = selectedReason == reason;
                      return InkWell(
                        onTap: () => setSheetState(() => selectedReason = reason),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                size: 18,
                                color: isSelected ? Colors.red.shade700 : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 13.5,
                                    color: isSelected ? Colors.black87 : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogCtx, false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(dialogCtx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Confirm Decline', style: TextStyle(fontWeight: FontWeight.w700)),
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

    setState(() => _isProcessing = true);

    try {
      SocketService().emitOrderModalAction(
        orderId: widget.orderId,
        orderNumber: widget.orderNumber,
        action: 'rejected',
        rejectionReason: selectedReason,
      );
    } catch (_) {}

    try {
      DatabaseService.markOrderDismissed(widget.orderId, widget.orderNumber);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_incoming_order_payload');

      _syncOrderToDatabase(targetStatus: OrderStatus.cancelled);

      await _orderService.rejectWhatsAppOrder(
        widget.orderId,
        reason: selectedReason,
      );

      try {
        FirestoreService().updateStorefrontOrderStatus(widget.orderId, 'cancelled', 0);
      } catch (_) {}

      _closeScreen();

      final navCtx = LocalNotificationService.navigatorKey.currentContext;
      if (navCtx != null && navCtx.mounted) {
        ScaffoldMessenger.of(navCtx).showSnackBar(
          SnackBar(
            content: Text('Order #${widget.orderNumber} declined: $selectedReason'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
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

  // Design constants
  static const Color _bgCanvas = Color(0xFFF8FAFC);
  static const Color _cardBg = Colors.white;
  static const Color _borderSubtle = Color(0xFFE2E8F0);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _primaryGreen = Color(0xFF059669);

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return PopScope(
      canPop: !_isProcessing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _closeScreen();
        }
      },
      child: Scaffold(
        backgroundColor: _bgCanvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 1. Sleek Modern Top Bar
              _buildTopBar(),

              // 2. Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Order & Customer Overview Card
                      _buildOrderOverviewCard(),
                      const SizedBox(height: 10),

                      // Order Items Card
                      _buildItemsCard(currencyFormatter),
                      const SizedBox(height: 10),

                      // Bill Breakdown Card
                      _buildBillCard(currencyFormatter),
                      const SizedBox(height: 10),

                      // Kitchen Preparation Time Selector Card
                      _buildPrepTimeCard(),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),

              // 3. Fixed Bottom Action Bar
              _buildBottomActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final isTable = _isTableOrder;
    final tblNum = _resolvedTableNumber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          // Close / Dismiss Button
          InkWell(
            onTap: _closeScreen,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.close_rounded, size: 20, color: _textDark),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Center: Clear, Professional Header Badge
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isTable ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isTable ? const Color(0xFFA7F3D0) : const Color(0xFFBFDBFE),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isTable ? Icons.table_restaurant_rounded : (
                          widget.orderType.toLowerCase().contains('delivery')
                              ? Icons.delivery_dining_rounded
                              : Icons.shopping_bag_outlined
                        ),
                        size: 16,
                        color: isTable ? _primaryGreen : const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isTable
                            ? 'TABLE ${tblNum ?? "DINE-IN"}'
                            : (widget.orderType.toLowerCase().contains('delivery') ? 'DELIVERY' : 'TAKEAWAY'),
                        style: TextStyle(
                          color: isTable ? const Color(0xFF065F46) : const Color(0xFF1D4ED8),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right: Countdown & Mute Button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: _secondsRemaining > 30 ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _secondsRemaining > 30 ? const Color(0xFFA7F3D0) : const Color(0xFFFECDD3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 13,
                      color: _secondsRemaining > 30 ? _primaryGreen : const Color(0xFFE11D48),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_secondsRemaining}s',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _secondsRemaining > 30 ? const Color(0xFF065F46) : const Color(0xFFBE123C),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _toggleRingtone,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(
                      _isRingtoneMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      size: 18,
                      color: _isRingtoneMuted ? Colors.grey : const Color(0xFF0F766E),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderOverviewCard() {
    final orderNumDisplay = widget.orderNumber.startsWith('#')
        ? widget.orderNumber
        : '#${widget.orderNumber}';
    final tblNum = _resolvedTableNumber;
    final isTable = _isTableOrder;

    String displayName = widget.customerName.isNotEmpty && widget.customerName != 'Customer'
        ? widget.customerName
        : (isTable ? 'Table $tblNum Customer' : 'Customer');

    if (isTable && displayName.contains('(')) {
      displayName = displayName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
      if (displayName.isEmpty) displayName = 'Table $tblNum Customer';
    }

    final hasPhone = widget.customerPhone.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderSubtle),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Number & Timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                orderNumDisplay,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                DateFormat('h:mm a • d MMM').format(widget.createdAt.toLocal()),
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Customer details row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isTable ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isTable ? Icons.table_restaurant_rounded : Icons.person_rounded,
                    size: 20,
                    color: isTable ? _primaryGreen : const Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasPhone) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatPhone(widget.customerPhone),
                        style: const TextStyle(
                          color: _textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasPhone) ...[
                InkWell(
                  onTap: _callCustomer,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.call_rounded, color: Color(0xFF2563EB), size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _openWhatsAppChat,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.chat_outlined, color: Color(0xFF16A34A), size: 18),
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (widget.orderType.toLowerCase() == 'delivery' && widget.deliveryAddress.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFFEF4444)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.deliveryAddress,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
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
    final itemsList = _resolvedItems;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderSubtle),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
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
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${itemsList.length} ${itemsList.length == 1 ? "Item" : "Items"}',
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (itemsList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Items list synchronizing...',
                style: TextStyle(color: _textMuted, fontSize: 13, fontStyle: FontStyle.italic),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: itemsList.length,
              separatorBuilder: (ctx, idx) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(color: Color(0xFFF1F5F9), height: 1),
              ),
              itemBuilder: (context, index) {
                final rawItem = itemsList[index];
                final actualItem = (rawItem['item'] is Map)
                    ? Map<String, dynamic>.from(rawItem['item'])
                    : rawItem;
                final name = (actualItem['name'] ?? rawItem['name'] ?? 'Item ${index + 1}').toString();
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
                final note = (rawItem['note'] ?? rawItem['notes'] ?? actualItem['note'] ?? actualItem['notes'])?.toString();

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Veg / Non-Veg Icon
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: _textDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          if (variant.isNotEmpty)
                            Text(
                              variant.startsWith('(') ? variant : '($variant)',
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (note != null && note.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Note: ${note.trim()}',
                              style: const TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${qty}x',
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      currencyFormatter.format(price * qty),
                      style: const TextStyle(
                        color: _textDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBillCard(NumberFormat currencyFormatter) {
    double computedSubtotal = 0.0;
    for (final rawItem in _resolvedItems) {
      final actualItem = (rawItem['item'] is Map)
          ? Map<String, dynamic>.from(rawItem['item'])
          : rawItem;
      final qty = (rawItem['quantity'] ?? actualItem['quantity'] ?? 1) as num;
      final price = _resolveItemPrice(rawItem, actualItem, qty);
      computedSubtotal += (price * qty);
    }

    if (computedSubtotal <= 0.0 && widget.totalAmount > 0.0) {
      computedSubtotal = widget.totalAmount;
    }

    final double taxes = (widget.totalAmount - computedSubtotal).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderSubtle),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Item Subtotal',
                style: TextStyle(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                currencyFormatter.format(computedSubtotal),
                style: const TextStyle(color: _textDark, fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ],
          ),
          if (taxes > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Taxes & Charges',
                  style: TextStyle(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Text(
                  '+${currencyFormatter.format(taxes)}',
                  style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          // Grand Total Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        color: Color(0xFF065F46),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _isTableOrder ? 'Pay at Counter / Table' : 'Pending Payment',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
                Text(
                  currencyFormatter.format(widget.totalAmount),
                  style: const TextStyle(
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrepTimeCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderSubtle),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.access_time_rounded, color: Color(0xFFD97706), size: 16),
              SizedBox(width: 6),
              Text(
                'ESTIMATED PREPARATION TIME',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _prepTimeOptions.map((time) {
                final isSelected = _selectedPrepTime == time;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedPrepTime = time),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryGreen : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? _primaryGreen : _borderSubtle,
                        ),
                      ),
                      child: Text(
                        '$time mins',
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12.5,
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
        left: 14,
        right: 14,
        top: 10,
        bottom: 10 + MediaQuery.paddingOf(context).bottom,
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
          // Decline Button
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: _isProcessing ? null : _handleReject,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close_rounded, color: Color(0xFFDC2626), size: 17),
                    SizedBox(width: 4),
                    Text(
                      'Decline',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Accept & Send to Kitchen Button
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: _isProcessing ? null : _handleAccept,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x35059669),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isTableOrder ? Icons.soup_kitchen_rounded : Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isTableOrder ? 'Accept & Send to Kitchen' : 'Accept Order',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
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
