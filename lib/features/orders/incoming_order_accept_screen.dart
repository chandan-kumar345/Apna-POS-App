import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';
import '../../core/models/incoming_order_payload.dart';
import '../../core/models/menu_item_model.dart';
import '../../core/models/table_model.dart';
import '../../core/services/order_service.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/local_notification_service.dart';
import '../../core/services/bluetooth_printer_service.dart';
import '../../core/services/firestore_service.dart';
import '../chat/meta_whatsapp_chat_screen.dart';
import 'widgets/incoming_order_accept_view.dart';

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
  static _IncomingOrderAcceptScreenState? _activeState;

  /// An action on the notification can arrive after its review screen opened.
  /// Forward it to that screen instead of treating the user action as a duplicate.
  static bool handleNotificationAction({
    required String orderId,
    required String orderNumber,
    required bool accept,
    required bool reject,
  }) {
    final state = _activeState;
    if (!_isShowing || state == null || !state.mounted || (!accept && !reject)) {
      return false;
    }
    if ((orderId.isEmpty || orderId != _currentShowingOrderId) &&
        (orderNumber.isEmpty || orderNumber != _currentShowingOrderNumber)) {
      return false;
    }
    if (reject) {
      unawaited(state._handleReject());
    } else {
      unawaited(state._handleAccept());
    }
    return true;
  }

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
      debugPrint(
        '[IncomingOrderAcceptScreen] Blocked order accept screen: order #$orderNumber is already dismissed.',
      );
      return;
    }

    final localMatch = DatabaseService().orders
        .where(
          (o) =>
              (orderId.isNotEmpty && o.id == orderId) ||
              (orderNumber.isNotEmpty && o.orderNumber == orderNumber),
        )
        .firstOrNull;
    if (localMatch != null && localMatch.status != OrderStatus.pending) {
      DatabaseService.markOrderDismissed(orderId, orderNumber);
      debugPrint(
        '[IncomingOrderAcceptScreen] Blocked order accept screen: order #$orderNumber is already ${localMatch.status}.',
      );
      return;
    }

    final cleanType = (orderType ?? '').toLowerCase().replaceAll(
      RegExp(r'[-_\s]'),
      '',
    );
    final cleanSource = (source ?? '').toLowerCase().trim();
    final bool isTable =
        (tableNumber != null && tableNumber.trim().isNotEmpty) ||
        cleanSource.contains('qr') ||
        cleanSource.contains('table') ||
        cleanType.contains('table') ||
        cleanType.contains('dine') ||
        (deliveryAddress != null &&
            deliveryAddress.toLowerCase().contains('table'));

    final bool isExplicitExternal =
        cleanSource == 'whatsapp' ||
        cleanSource == 'profile' ||
        cleanSource == 'storefront' ||
        cleanSource == 'online' ||
        cleanSource == 'qr' ||
        isTable ||
        cleanType.contains('whatsapp') ||
        cleanType.contains('profile');

    final bool isPosOrder =
        !isExplicitExternal &&
        (cleanSource == 'pos' ||
            cleanSource == 'counter' ||
            cleanSource == 'local' ||
            DatabaseService.isKnownPosOrder(orderId) ||
            DatabaseService.isKnownPosOrder(orderNumber));

    if (isPosOrder) {
      debugPrint(
        '[IncomingOrderAcceptScreen] Blocked for in-store POS order: #$orderNumber',
      );
      return;
    }

    if (_isShowing &&
        (_currentShowingOrderId == orderId ||
            _currentShowingOrderNumber == orderNumber)) {
      debugPrint(
        '[IncomingOrderAcceptScreen] Already presenting order $orderId (#$orderNumber)',
      );
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

    final effectiveCreatedAt = (createdAt != null
        ? (createdAt.isUtc ? createdAt.toLocal() : createdAt)
        : DateTime.now());

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
    data = IncomingOrderPayload.normalize(data);
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};

    final orderId =
        metadata['orderId']?.toString() ??
        data['orderId']?.toString() ??
        data['entityId']?.toString() ??
        data['_id']?.toString() ??
        data['id']?.toString() ??
        '';
    final orderNumber =
        metadata['orderNumber']?.toString() ??
        data['orderNumber']?.toString() ??
        '';

    if (orderId.isEmpty && orderNumber.isEmpty) return;

    // Check if dismissed or non-pending
    if (DatabaseService.isOrderDismissed(orderId, orderNumber)) return;
    final localMatch = DatabaseService().orders
        .where(
          (o) =>
              (orderId.isNotEmpty && o.id == orderId) ||
              (orderNumber.isNotEmpty && o.orderNumber == orderNumber),
        )
        .firstOrNull;
    if (localMatch != null && localMatch.status != OrderStatus.pending) {
      DatabaseService.markOrderDismissed(orderId, orderNumber);
      return;
    }

    final phone =
        metadata['customerPhone']?.toString() ??
        data['customerPhone']?.toString() ??
        '';
    final name =
        metadata['customerName']?.toString() ??
        data['customerName']?.toString() ??
        'Customer';
    final totalAmount =
        double.tryParse(
          metadata['totalAmount']?.toString() ??
              data['totalAmount']?.toString() ??
              '0',
        ) ??
        0.0;
    final rawOrderType =
        metadata['orderType']?.toString() ??
        data['orderType']?.toString() ??
        metadata['type']?.toString() ??
        data['type']?.toString() ??
        'takeaway';
    final source =
        metadata['orderSource']?.toString() ??
        data['orderSource']?.toString() ??
        metadata['source']?.toString() ??
        data['source']?.toString() ??
        'storefront';

    final tableNumber = IncomingOrderPayload.tableNumber(data);
    final deliveryAddress = (data['deliveryAddress'] ?? '').toString();

    final orderType = (tableNumber != null && tableNumber.trim().isNotEmpty)
        ? 'dineIn'
        : rawOrderType;

    final itemsPayload =
        metadata['items'] ??
        data['items'] ??
        metadata['orderItems'] ??
        data['orderItems'] ??
        metadata['products'] ??
        data['products'] ??
        metadata['cartItems'] ??
        data['cartItems'];

    final createdAtStr =
        metadata['createdAt']?.toString() ?? data['createdAt']?.toString();
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
    if ((targetId == null || targetId.isEmpty) &&
        (targetNum == null || targetNum.isEmpty)) {
      isMatch = true;
    } else {
      if (targetId != null &&
          targetId.isNotEmpty &&
          (targetId == currentId || targetId == currentNum)) {
        isMatch = true;
      }
      if (targetNum != null &&
          targetNum.isNotEmpty &&
          (targetNum == currentId || targetNum == currentNum)) {
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
        debugPrint(
          '[IncomingOrderAcceptScreen] Error popping screen context: $e',
        );
      }
    }

    _isShowing = false;
    _currentShowingOrderId = null;
    _currentShowingOrderNumber = null;
    _currentScreenContext = null;
  }

  @override
  State<IncomingOrderAcceptScreen> createState() =>
      _IncomingOrderAcceptScreenState();
}

class _IncomingOrderAcceptScreenState extends State<IncomingOrderAcceptScreen> {
  final OrderService _orderService = OrderService();
  final DatabaseService _db = DatabaseService();

  OrderModel? get _matchingOrder => _db.orders
      .where(
        (order) =>
            (widget.orderId.isNotEmpty && order.id == widget.orderId) ||
            (widget.orderNumber.isNotEmpty &&
                order.orderNumber == widget.orderNumber),
      )
      .firstOrNull;

  String? get _resolvedTableNumber =>
      IncomingOrderPayload.normalizeTableNumber(widget.tableNumber) ??
      IncomingOrderPayload.normalizeTableNumber(_matchingOrder?.tableNumber) ??
      IncomingOrderPayload.tableFromText(widget.deliveryAddress) ??
      IncomingOrderPayload.tableFromText(widget.customerName);

  OrderModel? _lastObservedOrder;
  void _onOrderChanged() {
    final order = _matchingOrder;
    if (!identical(order, _lastObservedOrder)) {
      _lastObservedOrder = order;
      if (mounted) setState(() {});
    }
  }

  bool get _isTableOrder {
    final cleanType = widget.orderType.toLowerCase();
    final cleanSource = widget.source.toLowerCase();
    return cleanType.contains('dine') ||
        cleanType.contains('table') ||
        cleanSource.contains('qr') ||
        cleanSource.contains('table') ||
        _resolvedTableNumber != null;
  }

  /// Resolved items list: uses widget.items or falls back to actual items from DatabaseService.orders
  List<Map<String, dynamic>> get _resolvedItems {
    if (widget.items.isNotEmpty) return widget.items;

    final local = _db.orders
        .where(
          (o) =>
              (widget.orderId.isNotEmpty && o.id == widget.orderId) ||
              (widget.orderNumber.isNotEmpty &&
                  o.orderNumber == widget.orderNumber),
        )
        .firstOrNull;
    if (local != null && local.items.isNotEmpty) {
      return local.items
          .map(
            (i) => {
              'name': i.item.name,
              'quantity': i.quantity,
              'price': i.item.effectivePrice > 0
                  ? i.item.effectivePrice
                  : i.item.price,
              'isVeg': i.item.isVeg,
              'notes': i.note,
            },
          )
          .toList();
    }

    return [];
  }

  int _selectedPrepTime = 20;
  bool _isProcessing = false;
  bool _isRingtoneMuted = false;
  bool _hasClosed = false;
  Timer? _countdownTimer;
  final ValueNotifier<int> _secondsRemaining = ValueNotifier(90);

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
    IncomingOrderAcceptScreen._activeState = this;
    IncomingOrderAcceptScreen._currentScreenContext = context;
    DatabaseService.markOrderDismissed(widget.orderId, widget.orderNumber);

    _lastObservedOrder = _matchingOrder;
    _db.addListener(_onOrderChanged);

    SoundService.playOrderRingtone();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncOrderToDatabase(targetStatus: OrderStatus.pending);
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining.value > 0) {
        _secondsRemaining.value--;
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
    SharedPreferences.getInstance()
        .then((prefs) {
          prefs.remove('pending_incoming_order_payload');
        })
        .catchError((_) {});

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
    if (identical(IncomingOrderAcceptScreen._activeState, this)) {
      IncomingOrderAcceptScreen._activeState = null;
    }
    _db.removeListener(_onOrderChanged);
    _secondsRemaining.dispose();
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

  double _resolveItemPrice(
    Map<String, dynamic> item,
    Map<String, dynamic> actualItem,
    num qty,
  ) {
    double price = 0.0;
    if (actualItem['effectivePrice'] is num &&
        (actualItem['effectivePrice'] as num) > 0) {
      price = (actualItem['effectivePrice'] as num).toDouble();
    } else if (actualItem['price'] is num && (actualItem['price'] as num) > 0) {
      price = (actualItem['price'] as num).toDouble();
    } else if (item['price'] is num && (item['price'] as num) > 0) {
      price = (item['price'] as num).toDouble();
    } else if (actualItem['rate'] is num && (actualItem['rate'] as num) > 0) {
      price = (actualItem['rate'] as num).toDouble();
    } else if (item['rate'] is num && (item['rate'] as num) > 0) {
      price = (item['rate'] as num).toDouble();
    } else if (actualItem['unitPrice'] is num &&
        (actualItem['unitPrice'] as num) > 0) {
      price = (actualItem['unitPrice'] as num).toDouble();
    } else if (item['unitPrice'] is num && (item['unitPrice'] as num) > 0) {
      price = (item['unitPrice'] as num).toDouble();
    } else if (actualItem['totalPrice'] is num &&
        (actualItem['totalPrice'] as num) > 0 &&
        qty > 0) {
      price = (actualItem['totalPrice'] as num).toDouble() / qty;
    } else if (item['totalPrice'] is num &&
        (item['totalPrice'] as num) > 0 &&
        qty > 0) {
      price = (item['totalPrice'] as num).toDouble() / qty;
    } else {
      price =
          double.tryParse(
            actualItem['price']?.toString() ?? item['price']?.toString() ?? '0',
          ) ??
          0.0;
    }

    if (price <= 0.0) {
      final prodId =
          (actualItem['productId'] ??
                  actualItem['id'] ??
                  item['productId'] ??
                  item['id'] ??
                  '')
              .toString();
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

    if (price <= 0.0 &&
        widget.items.length == 1 &&
        widget.totalAmount > 0 &&
        qty > 0) {
      price = widget.totalAmount / qty;
    }

    return price;
  }

  OrderModel _syncOrderToDatabase({
    OrderStatus targetStatus = OrderStatus.pending,
  }) {
    final OrderType resolvedType = _isTableOrder
        ? OrderType.dineIn
        : (widget.orderType.toLowerCase().contains('delivery')
              ? OrderType.delivery
              : OrderType.takeaway);

    final String? tableNum = _resolvedTableNumber;

    final existingIdx = _db.orders.indexWhere(
      (o) =>
          (widget.orderId.isNotEmpty && o.id == widget.orderId) ||
          (widget.orderNumber.isNotEmpty &&
              o.orderNumber == widget.orderNumber),
    );

    if (existingIdx >= 0) {
      final existing = _db.orders[existingIdx];
      final updated = existing.copyWith(
        status: targetStatus,
        isPaid: resolvedType == OrderType.dineIn ? false : existing.isPaid,
        paymentStatus: resolvedType == OrderType.dineIn
            ? 'pending'
            : existing.paymentStatus,
        paymentMethod: resolvedType == OrderType.dineIn
            ? 'Pay at Counter / Table'
            : existing.paymentMethod,
        tableNumber: tableNum ?? existing.tableNumber,
        deliveryAddress: widget.deliveryAddress.isNotEmpty
            ? widget.deliveryAddress
            : existing.deliveryAddress,
        customerName: widget.customerName.isNotEmpty
            ? widget.customerName
            : existing.customerName,
        customerPhone: widget.customerPhone.isNotEmpty
            ? widget.customerPhone
            : existing.customerPhone,
      );
      _db.upsertOrderLocally(updated);
      return updated;
    }

    final itemsList = _resolvedItems;
    final List<CartItemModel> cartItems = [];
    for (int i = 0; i < itemsList.length; i++) {
      final it = itemsList[i];
      final actualItem = it['item'] is Map
          ? Map<String, dynamic>.from(it['item'] as Map)
          : it;
      final name =
          (actualItem['name'] ??
                  actualItem['title'] ??
                  it['name'] ??
                  'Item ${i + 1}')
              .toString();
      final qty = (it['quantity'] is num)
          ? (it['quantity'] as num).toInt()
          : (int.tryParse(it['quantity']?.toString() ?? '1') ?? 1);
      final price = _resolveItemPrice(it, actualItem, qty);

      final menuItem = MenuItemModel(
        id:
            (actualItem['id'] ??
                    actualItem['productId'] ??
                    it['productId'] ??
                    'item_$i')
                .toString(),
        name: name,
        price: price,
        category: (actualItem['category'] ?? it['category'] ?? 'General')
            .toString(),
        description: name,
        itemType: (actualItem['isVeg'] == true || it['isVeg'] == true)
            ? 'Veg'
            : 'Non-Veg',
      );
      cartItems.add(
        CartItemModel(
          item: menuItem,
          quantity: qty,
          note:
              (it['notes'] ??
                      it['note'] ??
                      actualItem['notes'] ??
                      actualItem['note'])
                  ?.toString(),
        ),
      );
    }

    final newOrder = OrderModel(
      id: widget.orderId.isNotEmpty
          ? widget.orderId
          : 'ord_${DateTime.now().millisecondsSinceEpoch}',
      orderNumber: widget.orderNumber.isNotEmpty
          ? widget.orderNumber
          : '${DateTime.now().millisecondsSinceEpoch.remainder(10000)}',
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
      orderSource: widget.source.isNotEmpty
          ? widget.source
          : (_isTableOrder ? 'storefront' : 'whatsapp'),
      createdAt: widget.createdAt.toIso8601String(),
      isPaid: false,
      paymentStatus: 'pending',
      paymentMethod: resolvedType == OrderType.dineIn
          ? 'Pay at Counter / Table'
          : 'Pending',
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

      final updatedOrder = _syncOrderToDatabase(
        targetStatus: OrderStatus.preparing,
      );

      // Handle Table KOT and Live Sync
      final String? tableRef = updatedOrder.tableNumber ?? _resolvedTableNumber;
      if (_isTableOrder && tableRef != null && tableRef.trim().isNotEmpty) {
        final cleanTableRef = tableRef.trim();

        TableModel? targetTbl = _db.tables
            .where(
              (t) =>
                  isSameTable(t.name, cleanTableRef) ||
                  isSameTable(t.tableNumber.toString(), cleanTableRef) ||
                  isSameTable('T-${t.tableNumber}', cleanTableRef) ||
                  isSameTable('Table $cleanTableRef', t.name),
            )
            .firstOrNull;

        final nowIso = DateTime.now().toIso8601String();
        final int num =
            int.tryParse(cleanTableRef.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
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
        if (updatedOrder.customerName != null &&
            updatedOrder.customerName!.isNotEmpty) {
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
        FirestoreService().updateStorefrontOrderStatus(
          widget.orderId,
          'preparing',
          1,
        );
      } catch (_) {}

      _closeScreen();

      final navCtx = LocalNotificationService.navigatorKey.currentContext;
      if (navCtx != null && navCtx.mounted) {
        final String tblDisplay = tableRef != null && tableRef.isNotEmpty
            ? 'Table $tableRef • '
            : '';
        final String printMsg = kotPrinted ? ' (KOT Printed)' : '';
        ScaffoldMessenger.of(navCtx).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${tblDisplay}Order #${widget.orderNumber} Accepted!$printMsg Prep: $_selectedPrepTime mins',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
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
                          child: const Icon(
                            Icons.cancel_rounded,
                            color: Colors.redAccent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Decline Order',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ..._rejectionReasons.map((reason) {
                      final isSelected = selectedReason == reason;
                      return InkWell(
                        onTap: () =>
                            setSheetState(() => selectedReason = reason),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: 18,
                                color: isSelected
                                    ? Colors.red.shade700
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 13.5,
                                    color: isSelected
                                        ? Colors.black87
                                        : Colors.grey.shade700,
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Back',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Confirm Decline',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
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
        reason: selectedReason,
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
        FirestoreService().updateStorefrontOrderStatus(
          widget.orderId,
          'cancelled',
          0,
        );
      } catch (_) {}

      _closeScreen();

      final navCtx = LocalNotificationService.navigatorKey.currentContext;
      if (navCtx != null && navCtx.mounted) {
        ScaffoldMessenger.of(navCtx).showSnackBar(
          SnackBar(
            content: Text(
              'Order #${widget.orderNumber} declined: $selectedReason',
            ),
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
          SnackBar(
            content: Text('Error declining order: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Design constants

  @override
  Widget build(BuildContext context) {
    final lines = _resolvedItems.map((raw) {
      final item = raw['item'] is Map
          ? Map<String, dynamic>.from(raw['item'])
          : raw;
      final quantity =
          num.tryParse((raw['quantity'] ?? item['quantity'] ?? 1).toString()) ??
          1;
      final rawVariant =
          item['variantName'] ??
          item['selectedVariant'] ??
          item['variant'] ??
          item['portion'] ??
          item['size'] ??
          raw['variantName'] ??
          raw['variant'];
      final variant = rawVariant is Map
          ? (rawVariant['name'] ?? rawVariant['title'] ?? '').toString()
          : (rawVariant ?? '').toString();
      final foodType =
          (item['foodType'] ?? item['itemType'] ?? raw['foodType'] ?? '')
              .toString()
              .toLowerCase();
      final isVeg = item['isVeg'] is bool
          ? item['isVeg'] as bool
          : foodType.isEmpty
          ? null
          : !(foodType.contains('non') || foodType == 'egg');
      return IncomingOrderLine(
        name: (item['name'] ?? raw['name'] ?? 'Item').toString(),
        variant: variant,
        note:
            (raw['note'] ?? raw['notes'] ?? item['note'] ?? item['notes'] ?? '')
                .toString()
                .trim(),
        quantity: quantity,
        unitPrice: _resolveItemPrice(raw, item, quantity),
        isVeg: isVeg,
      );
    }).toList();
    return PopScope(
      canPop: !_isProcessing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _closeScreen();
      },
      child: IncomingOrderAcceptView(
        orderNumber: widget.orderNumber,
        customerName: widget.customerName,
        customerPhone: _formatPhone(widget.customerPhone),
        address: widget.deliveryAddress,
        orderType: widget.orderType,
        source: widget.source,
        currency: _db.restaurant?.currencySymbol ?? '₹',
        tableNumber: _resolvedTableNumber,
        tableOrder: _isTableOrder,
        muted: _isRingtoneMuted,
        processing: _isProcessing,
        createdAt: widget.createdAt,
        totalAmount: widget.totalAmount,
        items: lines,
        prepTimes: _prepTimeOptions,
        selectedPrepTime: _selectedPrepTime,
        secondsRemaining: _secondsRemaining,
        onPrepTime: (time) => setState(() => _selectedPrepTime = time),
        onClose: _closeScreen,
        onMute: _toggleRingtone,
        onCall: _callCustomer,
        onChat: _openWhatsAppChat,
        onAccept: _handleAccept,
        onDecline: _handleReject,
      ),
    );
  }
}
