import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../core/models/menu_item_model.dart';
import '../../core/models/order_model.dart';
import '../../core/models/table_model.dart';
import '../../core/services/cart_api_service.dart';
import '../../core/services/customer_service.dart';
import '../../core/widgets/food_type_icon.dart';
import '../menu/add_product_screen.dart';
import '../tables/table_management_screen.dart';
import 'payment_modal.dart';
import 'receipt_dialog.dart';
import 'kot_dialog.dart';
import '../../core/utils/order_calculator.dart';
import '../../core/utils/responsive_layout_helper.dart';
import '../../core/models/loyalty_program_model.dart';
import '../../core/services/loyalty_service.dart';
import '../../core/services/table_service.dart';
import '../loyalty/widgets/loyalty_redemption_dialog.dart';
import 'widgets/pos_product_media_box.dart';

class PosRegisterScreen extends StatefulWidget {
  final String? initialTable;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenTablesTab;
  final bool isFullScreen;
  final VoidCallback? onToggleFullScreen;
  final ValueChanged<bool>? onFullScreenChanged;

  const PosRegisterScreen({
    super.key,
    this.initialTable,
    this.onOpenDrawer,
    this.onOpenTablesTab,
    this.isFullScreen = false,
    this.onToggleFullScreen,
    this.onFullScreenChanged,
  });

  @override
  State<PosRegisterScreen> createState() => _PosRegisterScreenState();
}

class _PosRegisterScreenState extends State<PosRegisterScreen> {
  final db = DatabaseService();
  final _cartApiService = CartApiService();

  String _selectedCategory = 'All';
  String _searchQuery = '';
  OrderType _selectedOrderType = OrderType.dineIn;
  String? _selectedTable;

  final List<CartItemModel> _cartItems = [];
  double _discountAmount = 0.0;
  double _tipAmount = 0.0;
  String _appliedCoupon = '';
  final TextEditingController _promoCodeController = TextEditingController();

  void _resetDiscountAndPromoState() {
    _appliedCoupon = '';
    _promoCodeController.clear();
    _discountInputValue = 0.0;
    _discountAmount = 0.0;
    _discountMode = 'percent';
    _selectedDiscountProductType = null;
    _loyaltyDiscountAmount = 0.0;
    _redeemedLoyaltyStageId = null;
    _redeemedLoyaltyPoints = 0;
    _tipAmount = 0.0;
  }

  void _saveCurrentDraft() {
    String? draftKey;
    if (_selectedOrderType == OrderType.dineIn) {
      if (_selectedTable != null && _selectedTable!.isNotEmpty) {
        draftKey = _selectedTable!;
      }
    } else if (_selectedOrderType == OrderType.takeaway) {
      draftKey = _activeRunningOrderId ?? 'Takeaway';
    } else if (_selectedOrderType == OrderType.delivery) {
      draftKey = _activeRunningOrderId ?? 'Delivery';
    }

    if (draftKey != null && draftKey.isNotEmpty) {
      if (_cartItems.isNotEmpty) {
        db.setLiveTableCart(draftKey, List.from(_cartItems));
        db.setLiveCartTotal(draftKey, cartTotal);
      } else {
        db.setLiveTableCart(draftKey, []);
        db.setLiveCartTotal(draftKey, 0.0);
      }
      db.setLiveTableDiscount(
        draftKey,
        coupon: _appliedCoupon,
        discountInput: _discountInputValue,
        discountMode: _discountMode,
        discountAmount: computedDiscountAmount,
      );
    }
  }

  void _saveCurrentTableDraft() => _saveCurrentDraft();
  String _discountMode = 'percent';
  double _discountInputValue = 0.0;
  String? _selectedDiscountProductType;
  String _customerPhone = '';
  String _customerName = '';

  // Loyalty Program & Points State
  final LoyaltyService _loyaltyService = LoyaltyService();
  bool _isLoyaltyActive = false;
  CustomerLoyaltyModel? _currentCustomerLoyalty;
  String? _redeemedLoyaltyStageId;
  int _redeemedLoyaltyPoints = 0;
  double _loyaltyDiscountAmount = 0.0;

  Future<void> _initLoyaltyStatus() async {
    try {
      final config = await _loyaltyService.getVisitRewardConfig();
      final branding = await _loyaltyService.fetchLoyaltyPrograms();
      final hasActive = (config.isActive && config.status != 'inactive' && config.status != 'draft') ||
          branding.programs.any((p) => p.isActive);
      if (mounted) {
        setState(() {
          _isLoyaltyActive = hasActive || config.isActive;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoyaltyActive = true;
        });
      }
    }
  }

  Future<void> _checkCustomerLoyalty() async {
    if (_customerPhone.trim().isEmpty && _customerName.trim().isEmpty) {
      if (mounted) setState(() => _currentCustomerLoyalty = null);
      return;
    }
    try {
      final loyalty = await _loyaltyService.getCustomerLoyalty(
        _customerPhone.trim(),
        name: _customerName.trim(),
      );
      if (mounted) {
        setState(() {
          _currentCustomerLoyalty = loyalty;
          _isLoyaltyActive = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoyaltyActive = true;
        });
      }
    }
  }

  String _deliveryAddress = '';
  String _deliveryLandmark = '';
  String _deliveryCity = '';
  String _deliveryState = '';
  String _deliveryPincode = '';
  String? _activeRunningOrderId;
  String? _activeRunningOrderNumber;

  String get _formattedDeliveryAddress {
    final parts = <String>[];
    if (_deliveryAddress.trim().isNotEmpty) parts.add(_deliveryAddress.trim());
    if (_deliveryLandmark.trim().isNotEmpty) parts.add('Near ${_deliveryLandmark.trim()}');
    final cityState = <String>[];
    if (_deliveryCity.trim().isNotEmpty) cityState.add(_deliveryCity.trim());
    if (_deliveryState.trim().isNotEmpty) cityState.add(_deliveryState.trim());
    if (cityState.isNotEmpty) {
      if (_deliveryPincode.trim().isNotEmpty) {
        parts.add('${cityState.join(', ')} - ${_deliveryPincode.trim()}');
      } else {
        parts.add(cityState.join(', '));
      }
    } else if (_deliveryPincode.trim().isNotEmpty) {
      parts.add(_deliveryPincode.trim());
    }
    return parts.join('\n');
  }

  bool get _hasDeliveryAddress => _deliveryAddress.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    db.addListener(_onDbChange);
    _initLoyaltyStatus();
    if (widget.initialTable != null) {
      _loadCartForTable(widget.initialTable!, openCartModal: true);
    }
  }

  @override
  void dispose() {
    _promoCodeController.dispose();
    db.removeListener(_onDbChange);
    super.dispose();
  }

  void _onDbChange() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(PosRegisterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTable != null && widget.initialTable != oldWidget.initialTable) {
      _loadCartForTable(widget.initialTable!, openCartModal: true);
    }
  }

  void _loadCartForTable(String tableName, {bool openCartModal = false}) {
    // Save draft of current active table/context if switching
    if (_selectedTable != tableName || _selectedOrderType != OrderType.dineIn) {
      _saveCurrentDraft();
    }

    setState(() {
      _selectedTable = tableName;
      _selectedOrderType = OrderType.dineIn;
      _cartItems.clear();
      _resetDiscountAndPromoState();
      _activeRunningOrderId = null;
      _activeRunningOrderNumber = null;
      _customerName = '';
      _customerPhone = '';

      final activeOrder = db.orders.where((o) =>
        isSameTable(o.tableNumber, tableName) &&
        (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
      ).firstOrNull;

      if (activeOrder != null && activeOrder.items.isNotEmpty) {
        _cartItems.addAll(activeOrder.items.map((i) => i.clone()));
        _activeRunningOrderId = activeOrder.id;
        _activeRunningOrderNumber = activeOrder.orderNumber;
        _customerName = activeOrder.customerName ?? '';
        _customerPhone = activeOrder.customerPhone ?? '';
      } else {
        final savedCart = db.getLiveTableCart(tableName);
        if (savedCart.isNotEmpty) {
          _cartItems.addAll(savedCart.map((i) => i.clone()));
        }
      }

      final savedDiscount = db.getLiveTableDiscount(tableName);
      if (savedDiscount != null) {
        _appliedCoupon = savedDiscount['coupon']?.toString() ?? '';
        _promoCodeController.text = _appliedCoupon;
        _discountInputValue = (savedDiscount['discountInput'] as num?)?.toDouble() ?? 0.0;
        _discountMode = savedDiscount['discountMode']?.toString() ?? 'percent';
        _discountAmount = (savedDiscount['discountAmount'] as num?)?.toDouble() ?? 0.0;
      } else if (activeOrder != null && activeOrder.discountAmount > 0) {
        _discountAmount = activeOrder.discountAmount;
      }
    });

    if (openCartModal && _cartItems.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openCartScreenModal();
        }
      });
    }
  }

  Future<void> _sendKotOrder([StateSetter? setStateModal]) async {
    // Check if table or takeaway/delivery already has a Running KOT active order in DB
    final activeOrder = (_activeRunningOrderId != null && _activeRunningOrderId!.isNotEmpty)
        ? db.orders.where((o) => o.id == _activeRunningOrderId || o.orderNumber == _activeRunningOrderId).firstOrNull
        : (_selectedOrderType == OrderType.dineIn && _selectedTable != null
            ? db.orders.where((o) =>
                isSameTable(o.tableNumber, _selectedTable) &&
                (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
              ).firstOrNull
            : db.orders.where((o) =>
                o.orderType == _selectedOrderType &&
                (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
              ).firstOrNull);

    if (_cartItems.isEmpty && activeOrder == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add items to cart to view/generate KOT!')),
      );
      return;
    }

    // If order is already active Running KOT and cart is empty, show KotDialog in reprint mode
    if (activeOrder != null && _cartItems.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => KotDialog(
          order: activeOrder,
          isReprint: true,
          onLegacyPrintKot: () {
            if (_selectedOrderType == OrderType.dineIn && _selectedTable != null) {
              final tbl = db.tables.where((t) =>
                isSameTable(t.name, _selectedTable) ||
                t.tableNumber.toString() == _selectedTable
              ).firstOrNull;
              if (tbl != null) {
                db.updateTableStatus(tbl.id, TableStatus.runningKot, orderId: activeOrder.id);
              }
            }
            if (setStateModal != null) setStateModal(() {});
            setState(() {});
          },
        ),
      );
      return;
    }

    final calc = currentOrderCalculation;

    // Preview OrderModel (Table status is NOT updated yet upon clicking KOT button)
    final tempOrder = OrderModel(
      id: _activeRunningOrderId ?? (activeOrder?.id ?? 'KOT-${DateTime.now().millisecondsSinceEpoch}'),
      orderNumber: _activeRunningOrderNumber ?? (activeOrder?.orderNumber ?? 'KOT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'),
      items: _cartItems.map((i) => i.clone()).toList(),
      subtotal: calc.subtotal,
      taxAmount: calc.taxAmount,
      discountAmount: calc.orderDiscount,
      tipAmount: calc.tipAmount,
      deliveryCharge: calc.deliveryCharge,
      totalAmount: calc.totalPayableAmount,
      tableNumber: _selectedOrderType == OrderType.dineIn ? (_selectedTable ?? 'T1') : null,
      deliveryAddress: _selectedOrderType == OrderType.delivery ? _formattedDeliveryAddress : null,
      orderType: _selectedOrderType,
      paymentMethod: 'KOT Pending',
      status: OrderStatus.preparing,
      createdAt: activeOrder?.createdAt ?? DateTime.now().toIso8601String(),
      customerName: _customerName,
      customerPhone: _customerPhone,
    );

    // OPEN KOT POPUP (Table status changes to Running KOT ONLY when Print KOT succeeds)
    showDialog(
      context: context,
      builder: (_) => KotDialog(
        order: tempOrder,
        onPrintKot: (updatedOrder) async {
          // Sync sent kotQuantity back to in-memory cart items
          for (int i = 0; i < _cartItems.length; i++) {
            final match = updatedOrder.items.where((ui) => ui.item.id == _cartItems[i].item.id || ui.item.name == _cartItems[i].item.name).firstOrNull;
            if (match != null) {
              _cartItems[i].kotQuantity = match.kotQuantity;
            } else {
              _cartItems[i].kotQuantity = _cartItems[i].quantity;
            }
          }

          // If active order already exists, update in-place with status: preparing. Else create new order.
          OrderModel newOrder;
          if (_activeRunningOrderId != null || activeOrder != null) {
            final orderIdToUpdate = _activeRunningOrderId ?? activeOrder?.id;
            final orderNumToUpdate = _activeRunningOrderNumber ?? activeOrder?.orderNumber;

            newOrder = await db.saveAndPrintOrder(
              items: _cartItems.map((i) => i.clone()).toList(),
              tableNumber: _selectedOrderType == OrderType.dineIn ? (_selectedTable ?? 'T1') : null,
              deliveryAddress: _selectedOrderType == OrderType.delivery ? _formattedDeliveryAddress : null,
              orderType: _selectedOrderType,
              subtotalOverride: calc.subtotal,
              discountAmount: calc.orderDiscount,
              taxAmountOverride: calc.taxAmount,
              tipAmount: calc.tipAmount,
              deliveryCharge: calc.deliveryCharge,
              totalAmount: calc.totalPayableAmount,
              existingOrderId: orderIdToUpdate,
              existingOrderNumber: orderNumToUpdate,
              customerName: _customerName,
              customerPhone: _customerPhone,
            );
            db.updateOrderStatus(newOrder.id, OrderStatus.preparing);
          } else {
            newOrder = await db.createOrder(
              items: _cartItems.map((i) => i.clone()).toList(),
              tableNumber: _selectedOrderType == OrderType.dineIn ? (_selectedTable ?? 'T1') : null,
              deliveryAddress: _selectedOrderType == OrderType.delivery ? _formattedDeliveryAddress : null,
              orderType: _selectedOrderType,
              subtotalOverride: calc.subtotal,
              discountAmount: calc.orderDiscount,
              taxAmountOverride: calc.taxAmount,
              tipAmount: calc.tipAmount,
              deliveryCharge: calc.deliveryCharge,
              totalAmount: calc.totalPayableAmount,
              paymentMethod: 'KOT Pending',
              status: OrderStatus.preparing,
              customerName: _customerName,
              customerPhone: _customerPhone,
            );
          }

          if (_selectedOrderType == OrderType.dineIn && _selectedTable != null) {
            final tbl = db.tables.where((t) =>
              isSameTable(t.name, _selectedTable) ||
              t.tableNumber.toString() == _selectedTable
            ).firstOrNull;

            if (tbl != null) {
              db.updateTableStatus(tbl.id, TableStatus.runningKot, orderId: newOrder.id);
            }

            db.setLiveTableCart(_selectedTable!, _cartItems);
            db.setLiveCartTotal(_selectedTable!, newOrder.totalAmount);
          }

          setState(() {
            _activeRunningOrderId = newOrder.id;
            _activeRunningOrderNumber = newOrder.orderNumber;
          });
          if (setStateModal != null) setStateModal(() {});
          setState(() {});
        },
      ),
    );
  }

  void _syncTableStatusWithCart() {
    if (_selectedOrderType == OrderType.dineIn) {
      if (_selectedTable == null || _selectedTable!.isEmpty) {
        final freeT = db.getNextAvailableTableSequence();
        if (freeT != null) {
          _selectedTable = freeT.name;
        }
      }

      if (_selectedTable != null && _selectedTable!.isNotEmpty) {
        final targetTable = _selectedTable!;

        // Compute current cart total (subtotal) using effective sale price
        final cartTotal = _cartItems.fold<double>(
          0.0,
          (sum, e) => sum + (e.item.effectivePrice * e.quantity),
        );

        // Save live table cart items & total in DB so table card and view button can load it
        db.setLiveTableCart(targetTable, _cartItems);
        db.setLiveCartTotal(targetTable, cartTotal - _discountAmount.clamp(0, cartTotal));

        final tbl = db.tables.where((t) => isSameTable(t.name, targetTable)).firstOrNull;
        if (tbl != null) {
          final activeOrder = db.orders.where((o) =>
            isSameTable(o.tableNumber, targetTable) &&
            (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
          ).firstOrNull;

          if (activeOrder != null) {
            final mapped = (activeOrder.status == OrderStatus.preparing || tbl.status == TableStatus.runningKot)
                ? TableStatus.runningKot
                : TableStatus.occupied;
            if (tbl.status != mapped) {
              db.updateTableStatus(tbl.id, mapped, orderId: activeOrder.id);
            }
          } else if (_cartItems.isEmpty) {
            db.clearTableCartAndFree(targetTable);
          } else if (_cartItems.isNotEmpty && tbl.status == TableStatus.free) {
            db.updateTableStatus(tbl.id, TableStatus.occupied);
          }
        }
      }
    }
  }

  void _addToCart(MenuItemModel item, {String? variantName}) {
    setState(() {
      final existingIndex = _cartItems.indexWhere((e) => e.item.id == item.id);
      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity++;
      } else {
        _cartItems.add(CartItemModel(item: item, quantity: 1));
      }
      _syncTableStatusWithCart();
    });

    // Fire-and-sync server-side Cart API in background for seamless real-time syncing
    _cartApiService.addToCart(
      item: item,
      tableNumber: _selectedTable,
      orderType: _selectedOrderType.name,
      quantity: 1,
      variantName: variantName,
    );
  }

  void _decrementCartItem(MenuItemModel item, {String? variantName}) {
    setState(() {
      final existingIndex = _cartItems.indexWhere((e) => e.item.id == item.id);
      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity--;
        if (_cartItems[existingIndex].quantity <= 0) {
          _cartItems.removeAt(existingIndex);
        } else if (_cartItems[existingIndex].kotQuantity > _cartItems[existingIndex].quantity) {
          _cartItems[existingIndex].kotQuantity = _cartItems[existingIndex].quantity;
        }
      }
      _syncTableStatusWithCart();
    });

    // Fire-and-sync server-side Cart reduction in background
    _cartApiService.reduceProductFromCart(
      productId: item.productId.isNotEmpty ? item.productId : item.id,
      variantName: variantName,
      tableNumber: _selectedTable,
      orderType: _selectedOrderType.name,
      quantity: 1,
    );
  }

  int _getItemCartQuantity(MenuItemModel item) {
    return _cartItems
        .where((e) => e.item.id == item.id || e.item.id.startsWith('${item.id}_var_'))
        .fold(0, (sum, e) => sum + e.quantity);
  }

  /// Reusable Pill-shaped Quantity Stepper matching user design (Light container + Dark circular buttons)
  Widget _buildPillQuantityStepper({
    required int quantity,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    double height = 28,
    double? width,
    double buttonSize = 24,
    double fontSize = 14,
    double iconSize = 14,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF5), // Light blue-grey container as shown in user reference
        borderRadius: borderRadius ?? BorderRadius.circular(height / 2), // Full capsule pill shape
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
      ),
      child: Row(
        mainAxisSize: width != null ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Circular Solid Dark Blue Minus Button
          GestureDetector(
            onTap: onDecrement,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: const BoxDecoration(
                color: Color(0xFF051C48), // Dark Navy Blue
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(Icons.remove, size: iconSize, color: Colors.white),
              ),
            ),
          ),

          // Bold Quantity Value
          if (width != null)
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$quantity',
                    style: TextStyle(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w900,
                      fontSize: fontSize,
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$quantity',
                  style: TextStyle(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                    fontSize: fontSize,
                  ),
                ),
              ),
            ),

          // Circular Solid Dark Blue Plus Button
          GestureDetector(
            onTap: onIncrement,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: const BoxDecoration(
                color: Color(0xFF051C48), // Dark Navy Blue
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(Icons.add, size: iconSize, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVariantsSelectionDialog(MenuItemModel item) {
    final currency = db.restaurant?.currencySymbol ?? '₹';

    showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth > 600 ? 460.0 : (screenWidth * 0.92).clamp(320.0, 460.0);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              title: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Select Variant & Quantity',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _buildFoodTypeIcon(item.itemType),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: SizedBox(
                width: dialogWidth,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: item.variants.map((v) {
                      final effectivePrice = v.effectivePrice;
                      final bool variantHasDisc = v.hasDiscount || v.discountPercent > 0 || (v.salePrice != null && v.salePrice! > 0 && v.salePrice! < v.price);
                      final double vDiscPercent = v.discountPercent > 0
                          ? v.discountPercent
                          : (v.price > 0 && v.salePrice != null && v.salePrice! < v.price ? ((v.price - v.salePrice!) / v.price * 100) : 0.0);

                      final defaultGstRate = (db.restaurant?.billingType == 'Non-GST') ? 0.0 : (db.restaurant?.taxRate ?? 5.0);
                      final variantId = '${item.id}_var_${v.name}';
                      final variantItem = MenuItemModel(
                        id: variantId,
                        productId: item.productId.isNotEmpty ? item.productId : item.id,
                        name: '${item.name} (${v.name})',
                        category: item.category,
                        price: v.price,
                        salePrice: variantHasDisc ? effectivePrice : null,
                        hasDiscount: variantHasDisc,
                        discountPercent: vDiscPercent,
                        description: item.description,
                        imageUrl: item.imageUrl,
                        images: item.images,
                        videoUrl: item.videoUrl,
                        emoji: item.emoji,
                        itemType: item.itemType,
                        gstPercent: item.gstPercent ?? defaultGstRate,
                        trackInventory: item.trackInventory,
                      );

                      final vQty = _getItemCartQuantity(variantItem);

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: vQty > 0 ? const Color(0xFF051C48).withOpacity(0.04) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: vQty > 0 ? const Color(0xFF051C48) : const Color(0xFFE2E8F0),
                            width: vQty > 0 ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    v.name,
                                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  if (variantHasDisc && vDiscPercent > 0)
                                    Row(
                                      children: [
                                        // First: Strike out main price (bold & struck out)
                                        Text(
                                          '$currency ${v.price.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            decoration: TextDecoration.lineThrough,
                                            decorationThickness: 3.0,
                                            decorationColor: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        // Second: How much discount applied
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            '${vDiscPercent.toStringAsFixed(0)}% OFF',
                                            style: const TextStyle(
                                              color: Color(0xFF10B981),
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        // Last: Sale Price
                                        Text(
                                          '$currency ${effectivePrice.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            color: Color(0xFF051C48),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Text(
                                      '$currency ${effectivePrice.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Color(0xFF051C48),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Quantity Stepper for Variant matching reference image
                            if (vQty > 0)
                              _buildPillQuantityStepper(
                                quantity: vQty,
                                onDecrement: () {
                                  _decrementCartItem(variantItem, variantName: v.name);
                                  setModalState(() {});
                                  setState(() {});
                                },
                                onIncrement: () {
                                  _addToCart(variantItem, variantName: v.name);
                                  setModalState(() {});
                                  setState(() {});
                                },
                                height: 30,
                                buttonSize: 24,
                                fontSize: 13.5,
                              )
                            else
                              SizedBox(
                                height: 30,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _addToCart(variantItem, variantName: v.name);
                                    setModalState(() {});
                                    setState(() {});
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF051C48),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                                  label: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF051C48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  OrderCalculationResult get currentOrderCalculation => OrderCalculator.calculate(
    items: _cartItems,
    defaultTaxRate: (db.restaurant?.billingType == 'Non-GST') ? 0.0 : (db.restaurant?.taxRate ?? 5.0),
    appliedCoupon: _appliedCoupon,
    availableCoupons: db.extras,
    discountInputValue: _discountInputValue,
    discountMode: _discountMode,
    selectedDiscountProductType: _selectedDiscountProductType,
    manualDiscountOverride: _discountAmount,
    tipAmount: _tipAmount,
    deliveryCharge: 0.0,
  );

  void _applyPromoCode(String code, StateSetter setStateCart) {
    final currency = db.restaurant?.currencySymbol ?? '₹';
    final clean = code.trim();
    if (clean.isEmpty) {
      setStateCart(() {
        _appliedCoupon = '';
        _promoCodeController.clear();
        _discountInputValue = 0.0;
        _discountAmount = 0.0;
      });
      setState(() {
        _appliedCoupon = '';
        _discountInputValue = 0.0;
        _discountAmount = 0.0;
      });
      _saveCurrentDraft();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Promo code cleared.'),
          duration: Duration(seconds: 1),
          backgroundColor: Color(0xFF051C48),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final percent = OrderCalculator.parsePromoDiscountPercent(clean, availableCoupons: db.extras);
    final isFlat = clean.toUpperCase().startsWith('FLAT') && !clean.endsWith('%');

    if (percent > 0 || isFlat) {
      setStateCart(() {
        _appliedCoupon = clean;
        _promoCodeController.text = clean;
        _discountInputValue = percent;
        _discountMode = isFlat ? 'flat' : 'percent';
        _discountAmount = 0.0;
      });
      setState(() {
        _appliedCoupon = clean;
        _discountInputValue = percent;
        _discountMode = isFlat ? 'flat' : 'percent';
        _discountAmount = 0.0;
      });
      _saveCurrentDraft();
      final discount = computedDiscountAmount;
      final percentFormatted = percent.truncateToDouble() == percent
          ? percent.toStringAsFixed(0)
          : percent.toStringAsFixed(1);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            percent > 0
                ? 'Promo code "$clean" applied: $percentFormatted% off (-$currency${discount.toStringAsFixed(2)}) before GST'
                : 'Promo code "$clean" applied! (-$currency${discount.toStringAsFixed(2)})',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF051C48),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid promo code. Enter a percentage (e.g. 10%, 20%) or coupon code.'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int get totalCartItemCount => _cartItems.fold(0, (sum, i) => sum + i.quantity);
  double get cartSubtotal => currentOrderCalculation.subtotal;
  double get computedDiscountAmount => currentOrderCalculation.orderDiscount;
  double get cartTax => currentOrderCalculation.taxAmount;
  double get cartTotal => currentOrderCalculation.totalPayableAmount;

  Widget _buildFoodTypeIcon(String itemType) {
    if (itemType == 'Non-Veg') {
      return Container(
        width: 15,
        height: 15,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFEF4444),
            shape: BoxShape.circle,
          ),
        ),
      );
    } else if (itemType == 'Egg') {
      return Container(
        width: 15,
        height: 15,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFB45309), width: 1.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFB45309),
            shape: BoxShape.circle,
          ),
        ),
      );
    } else if (itemType == 'Beverage') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF00A3FF).withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF00A3FF), width: 1),
        ),
        child: const Icon(Icons.local_drink_rounded, color: Color(0xFF00A3FF), size: 10),
      );
    } else {
      // Default Veg
      return Container(
        width: 15,
        height: 15,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF10B981),
            shape: BoxShape.circle,
          ),
        ),
      );
    }
  }

  void _setDeliveryAddressFromCustomer(String fullAddress) {
    if (fullAddress.trim().isEmpty) return;
    final lines = fullAddress.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (lines.isEmpty) return;

    _deliveryAddress = lines[0];
    _deliveryLandmark = '';
    _deliveryCity = '';
    _deliveryState = '';
    _deliveryPincode = '';

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.toLowerCase().startsWith('near ')) {
        _deliveryLandmark = line.substring(5).trim();
      } else if (line.contains('-')) {
        final dashParts = line.split('-');
        if (dashParts.length >= 2) {
          _deliveryPincode = dashParts.last.trim();
          final cs = dashParts.first.split(',');
          if (cs.length >= 2) {
            _deliveryCity = cs[0].trim();
            _deliveryState = cs[1].trim();
          } else if (cs.isNotEmpty) {
            _deliveryCity = cs[0].trim();
          }
        }
      } else if (line.contains(',')) {
        final cs = line.split(',');
        if (cs.isNotEmpty) _deliveryCity = cs[0].trim();
        if (cs.length > 1) _deliveryState = cs[1].trim();
      } else {
        if (_deliveryCity.isEmpty) {
          _deliveryCity = line;
        }
      }
    }
  }

  void _showDeliveryAddressDialog([StateSetter? setStateModal]) {
    final formKey = GlobalKey<FormState>();
    final addressCtrl = TextEditingController(text: _deliveryAddress);
    final landmarkCtrl = TextEditingController(text: _deliveryLandmark);
    final cityCtrl = TextEditingController(text: _deliveryCity);
    final stateCtrl = TextEditingController(text: _deliveryState);
    final pincodeCtrl = TextEditingController(text: _deliveryPincode);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dialog Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF051C48),
                            Color(0xFF0A2B66),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Delivery Address',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // Form Fields
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Address / House No / Street (Required)
                            const Text(
                              'Street Address / House No.',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: addressCtrl,
                              maxLines: 2,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w600,
                              ),
                              cursorColor: const Color(0xFF051C48),
                              cursorWidth: 2.0,
                              decoration: InputDecoration(
                                hintText: 'e.g. House No. 25, ABC Road',
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.5),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter delivery address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Landmark
                            const Text(
                              'Landmark',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: landmarkCtrl,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w600,
                              ),
                              cursorColor: const Color(0xFF051C48),
                              cursorWidth: 2.0,
                              decoration: InputDecoration(
                                hintText: 'e.g. Near XYZ Mall',
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // City & State Row
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'City',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: cityCtrl,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          color: Color(0xFF0F172A),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        cursorColor: const Color(0xFF051C48),
                                        cursorWidth: 2.0,
                                        decoration: InputDecoration(
                                          hintText: 'City',
                                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'State',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: stateCtrl,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          color: Color(0xFF0F172A),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        cursorColor: const Color(0xFF051C48),
                                        cursorWidth: 2.0,
                                        decoration: InputDecoration(
                                          hintText: 'State',
                                          hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Pincode
                            const Text(
                              'Pincode',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: pincodeCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w600,
                              ),
                              cursorColor: const Color(0xFF051C48),
                              cursorWidth: 2.0,
                              decoration: InputDecoration(
                                hintText: 'e.g. 201301',
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                                counterText: '',
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (formKey.currentState?.validate() == true) {
                                        setState(() {
                                          _deliveryAddress = addressCtrl.text.trim();
                                          _deliveryLandmark = landmarkCtrl.text.trim();
                                          _deliveryCity = cityCtrl.text.trim();
                                          _deliveryState = stateCtrl.text.trim();
                                          _deliveryPincode = pincodeCtrl.text.trim();
                                        });
                                        if (setStateModal != null) {
                                          setStateModal(() {});
                                        }
                                        Navigator.pop(ctx);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF051C48),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: const Text(
                                      'Save Address',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPosProductImage(MenuItemModel item) {
    return PosProductMediaBox(
      key: ValueKey('media_${item.id}_${item.imageUrl}_${item.videoUrl}_${item.images.length}'),
      item: item,
      fit: BoxFit.cover,
      showDots: true,
      borderRadius: BorderRadius.circular(10),
    );
  }

  void _showAddItemDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddProductScreen()),
    ).then((val) {
      if (val == true) {
        setState(() {});
      }
    });
  }

  void _showInputManuallyDialog() {
    final currency = db.restaurant?.currencySymbol ?? '₹';
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    int quantity = 1;
    String foodType = 'Veg';
    double selectedGstRate = (db.restaurant?.billingType == 'Non-GST') ? 0.0 : (db.restaurant?.taxRate ?? 5.0);
    String? errorMessage;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            elevation: 16,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF051C48).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.edit_note_rounded, color: Color(0xFF051C48), size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Input Product Manually',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Add custom item directly to active cart',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF94A3B8)),
                          onPressed: () => Navigator.pop(dialogCtx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 16),

                    // Product Name Field
                    const Text(
                      'Product Name *',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'e.g. Special Chef Combo / Extra Item',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.8)),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Price & Food Type Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Price Field
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Price *',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: priceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF051C48)),
                                decoration: InputDecoration(
                                  prefixText: '$currency ',
                                  prefixStyle: const TextStyle(color: Color(0xFF051C48), fontWeight: FontWeight.bold, fontSize: 14),
                                  hintText: '0.00',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.8)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Food Type (Veg / Non-Veg / Egg)
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Food Type',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 46,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: foodType,
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                                    items: const [
                                      DropdownMenuItem(value: 'Veg', child: Text('🟢 Veg', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                                      DropdownMenuItem(value: 'Non-Veg', child: Text('🔴 Non-Veg', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                                      DropdownMenuItem(value: 'Egg', child: Text('🟡 Egg', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setDialogState(() => foodType = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // GST Selection Row
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tax / GST',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 34,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            children: [0.0, 5.0, 12.0, 18.0, 28.0].map((rate) {
                              final isSel = selectedGstRate == rate;
                              final label = rate == 0.0 ? 'No GST (0%)' : '${rate.toStringAsFixed(0)}%';
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(label, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : const Color(0xFF475569), fontWeight: FontWeight.bold)),
                                  selected: isSel,
                                  selectedColor: const Color(0xFF051C48),
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  onSelected: (_) {
                                    setDialogState(() => selectedGstRate = rate);
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Quantity Stepper
                    Row(
                      children: [
                        const Text(
                          'Quantity:',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_rounded, size: 16, color: Color(0xFF051C48)),
                                onPressed: quantity > 1 ? () => setDialogState(() => quantity--) : null,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '$quantity',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF051C48)),
                                onPressed: () => setDialogState(() => quantity++),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Dialog Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final name = nameController.text.trim();
                              final price = double.tryParse(priceController.text.trim());

                              if (name.isEmpty) {
                                setDialogState(() => errorMessage = 'Please enter a product name');
                                return;
                              }
                              if (price == null || price <= 0) {
                                setDialogState(() => errorMessage = 'Please enter a valid price');
                                return;
                              }

                              final customItem = MenuItemModel(
                                id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                                productId: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                                name: name,
                                category: 'Manual / Custom',
                                price: price,
                                salePrice: null,
                                hasDiscount: false,
                                itemType: foodType,
                                gstPercent: selectedGstRate,
                                description: 'Custom manual item',
                              );

                              setState(() {
                                _cartItems.add(CartItemModel(item: customItem, quantity: quantity));
                                _syncTableStatusWithCart();
                              });

                              _cartApiService.addToCart(
                                item: customItem,
                                tableNumber: _selectedTable,
                                orderType: _selectedOrderType.name,
                                quantity: quantity,
                              );

                              Navigator.pop(dialogCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added "$name" ($currency${(price * quantity).toStringAsFixed(2)}) to Cart'),
                                  backgroundColor: const Color(0xFF10B981),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF051C48),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.add_shopping_cart_rounded, size: 17, color: Colors.white),
                            label: const Text(
                              'Add to Cart',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getFullTableTitle([String? tableName]) {
    final target = tableName ?? _selectedTable;
    if (target == null || target.isEmpty) {
      return 'Table 04';
    }
    if (target.toLowerCase().startsWith('table')) {
      return target;
    }
    final numOnly = target.replaceAll(RegExp(r'[^0-9]'), '');
    if (numOnly.isNotEmpty) {
      return 'Table ${numOnly.padLeft(2, '0')}';
    }
    return target;
  }

  Color _getTableStatusColor(TableStatus status) {
    switch (status) {
      case TableStatus.free:
        return const Color(0xFF10B981);
      case TableStatus.occupied:
        return const Color(0xFF051C48);
      case TableStatus.runningKot:
        return const Color(0xFFEF4444);
      case TableStatus.reserved:
        return const Color(0xFF8B5CF6);
    }
  }

  String _getTableStatusLabel(TableStatus status) {
    switch (status) {
      case TableStatus.free:
        return 'Free';
      case TableStatus.occupied:
        return 'Occupied';
      case TableStatus.runningKot:
        return 'Running KOT';
      case TableStatus.reserved:
        return 'Reserved';
    }
  }

  bool _isTableRunningKot(String tableName) {
    if (_selectedOrderType != OrderType.dineIn || tableName.isEmpty) return false;

    // 1. Check in-memory active order indicators
    if (_activeRunningOrderId != null || _activeRunningOrderNumber != null) {
      return true;
    }

    // 2. Check table status in db.tables
    final tbl = db.tables.where((t) =>
      isSameTable(t.name, tableName) ||
      isSameTable(t.tableNumber.toString(), tableName) ||
      'T-${t.tableNumber}'.toLowerCase() == tableName.trim().toLowerCase()
    ).firstOrNull;

    if (tbl != null && tbl.status == TableStatus.runningKot) {
      return true;
    }

    // 3. Check active preparing / pending order in db.orders
    final hasActiveOrder = db.orders.any((o) =>
      isSameTable(o.tableNumber, tableName) &&
      (o.status == OrderStatus.preparing || (o.status == OrderStatus.pending && o.items.isNotEmpty))
    );

    return hasActiveOrder;
  }

  Future<bool> _promptManagerPinForClearCart({
    required BuildContext modalContext,
    required String tableName,
  }) async {
    final pinController = TextEditingController();
    String? pinError;
    bool obscure = true;

    final authorized = await showDialog<bool>(
      context: modalContext,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              elevation: 16,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header with Shield Icon & Alert styling
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: const Icon(Icons.shield_rounded, color: Color(0xFFDC2626), size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Security PIN Required',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Running KOT in Kitchen',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(false),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(color: Color(0xFFE2E8F0), height: 1),
                      const SizedBox(height: 14),

                      // Warning explanation
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Table $tableName has an active Running KOT in the kitchen. Clearing the cart will void this order and mark Table $tableName as Free.',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF991B1B),
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // PIN input field
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Enter Manager Security PIN',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          InkWell(
                            onTap: () => setDialogState(() => obscure = !obscure),
                            child: Text(
                              obscure ? 'Show' : 'Hide',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF051C48)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: pinController,
                        scrollPadding: const EdgeInsets.only(bottom: 90),
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: obscure,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: 6,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          counterText: '',
                          errorText: pinError,
                          hintText: '••••',
                          hintStyle: const TextStyle(letterSpacing: 4, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.8)),
                        ),
                        onSubmitted: (val) {
                          if (db.verifyManagerPin(val)) {
                            Navigator.of(dialogCtx, rootNavigator: true).pop(true);
                          } else {
                            setDialogState(() {
                              pinError = 'Incorrect Security PIN. Try again or check Settings.';
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 6),
                      const Center(
                        child: Text(
                          '(PIN can be changed in Business Setting Hub)',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(false),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Keep Cart', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final entered = pinController.text.trim();
                                if (db.verifyManagerPin(entered)) {
                                  Navigator.of(dialogCtx, rootNavigator: true).pop(true);
                                } else {
                                  setDialogState(() {
                                    pinError = 'Incorrect Security PIN. Please try again.';
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                              child: const Text('Void & Clear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    return authorized == true;
  }

  Future<void> _handleClearCartAction(BuildContext modalContext, [StateSetter? setStateModal]) async {
    final targetTable = _selectedTable;
    final isDineIn = _selectedOrderType == OrderType.dineIn;

    if (isDineIn && targetTable != null && targetTable.isNotEmpty && _isTableRunningKot(targetTable)) {
      final authorized = await _promptManagerPinForClearCart(
        modalContext: modalContext,
        tableName: targetTable,
      );

      if (!authorized) {
        return; // User cancelled or failed PIN
      }
    }

    // Capture snapshot for Print Logs BEFORE clearing
    final snapshotItems = List<CartItemModel>.from(_cartItems);
    final snapshotTotal = cartTotal;
    final activeId = _activeRunningOrderId;
    final activeNum = _activeRunningOrderNumber;
    final cName = _customerName;
    final cPhone = _customerPhone;

    // Execute Clear
    _clearCart();

    // Log cleared cart snapshot to Print Logs
    if (snapshotItems.isNotEmpty || snapshotTotal > 0) {
      await db.logClearedCart(
        tableNumber: targetTable ?? '',
        items: snapshotItems,
        totalAmount: snapshotTotal,
        orderId: activeId,
        orderNumber: activeNum,
        customerName: cName,
        customerPhone: cPhone,
        reason: 'Cleared Cart & Freed Table via Manager Security PIN',
      );
    }

    if (setStateModal != null) {
      setStateModal(() {});
    }
    if (mounted) {
      _checkAndCloseEmptyCart(modalContext, setStateModal);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                targetTable != null && targetTable.isNotEmpty
                    ? 'Table $targetTable cart cleared & freed successfully'
                    : 'Cart cleared successfully',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF051C48),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _clearCart() {
    setState(() {
      final targetTable = _selectedTable;
      final activeId = _activeRunningOrderId;

      _cartItems.clear();
      _resetDiscountAndPromoState();
      _activeRunningOrderId = null;
      _activeRunningOrderNumber = null;
      _customerName = '';
      _customerPhone = '';
      _deliveryAddress = '';
      _deliveryLandmark = '';
      _deliveryCity = '';
      _deliveryState = '';
      _deliveryPincode = '';

      if (targetTable != null && targetTable.isNotEmpty && _selectedOrderType == OrderType.dineIn) {
        // Void any active preparing/pending orders in memory & backend, and mark table as Free
        db.voidTableOrderAndFree(targetTable, orderId: activeId, reason: 'Cart Cleared by POS Staff');

        // Clean up backend cart asynchronously
        try {
          CartApiService().clearCart(tableNumber: targetTable, orderType: 'dineIn');
        } catch (_) {}
      }
    });
  }

  void _checkAndCloseEmptyCart(BuildContext modalContext, [StateSetter? setStateModal]) {
    if (_cartItems.isEmpty) {
      if (_selectedTable != null && _selectedTable!.isNotEmpty && _selectedOrderType == OrderType.dineIn) {
        final targetTable = _selectedTable!;
        db.voidTableOrderAndFree(targetTable);
      }

      if (setStateModal != null) {
        setStateModal(() {});
      }
      setState(() {});

      if (Navigator.canPop(modalContext)) {
        Navigator.pop(modalContext);
      }
    }
  }

  void _removeCartItem(MenuItemModel item) {
    setState(() {
      _cartItems.removeWhere((i) => i.item.id == item.id);
      _syncTableStatusWithCart();
    });
  }

  Widget _buildStatusLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  /// Dynamically shift all cart items, orders, and details from current table to new table
  Future<void> _shiftTable(String newTableName, [StateSetter? setStateModal]) async {
    final oldTable = _selectedTable;
    if (oldTable == null || oldTable.isEmpty || isSameTable(oldTable, newTableName)) {
      _switchTable(newTableName, setStateModal);
      return;
    }

    // 1. Sync any active in-memory cart items & discount to old table first
    _saveCurrentTableDraft();

    // 2. Perform full data migration in local database
    db.shiftTableData(oldTable, newTableName);

    // 3. Trigger cloud API sync for multi-device synchronization
    try {
      final tableService = TableService();
      await tableService.shiftTable(sourceTable: oldTable, targetTable: newTableName);
    } catch (e) {
      debugPrint('[POS._shiftTable] API sync notice: $e');
    }

    // 4. Update selected table and load the shifted cart
    setState(() {
      _selectedTable = newTableName;
    });
    _loadCartForTable(newTableName);

    if (setStateModal != null) {
      setStateModal(() {});
    }
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Table shifted from $oldTable to $newTableName with all items & discounts'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF00A86B),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _switchTable(String newTableName, [StateSetter? setStateModal]) {
    final oldTable = _selectedTable;

    if (oldTable != null && oldTable.isNotEmpty && !isSameTable(oldTable, newTableName)) {
      _saveCurrentDraft();
      if (_cartItems.isNotEmpty) {
        final oldTbl = db.tables.where((t) => isSameTable(t.name, oldTable)).firstOrNull;
        if (oldTbl != null && oldTbl.status == TableStatus.free) {
          db.updateTableStatus(oldTbl.id, TableStatus.occupied);
        }
      }
    }

    _loadCartForTable(newTableName);
    if (setStateModal != null) {
      setStateModal(() {});
    }
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Switched to Table $newTableName'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF051C48),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleTableSelection({
    required BuildContext dialogCtx,
    required TableModel targetTable,
    required bool isShiftMode,
    required bool hasActiveOrderOrCart,
    required String currentTable,
    StateSetter? setStateCart,
  }) async {
    if (isSameTable(targetTable.name, currentTable)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Table ${targetTable.name} is already active'),
          backgroundColor: const Color(0xFF051C48),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    if (dialogCtx.mounted) {
      Navigator.pop(dialogCtx);
    }

    // Direct shift/switch without confirmation popup
    if (isShiftMode && hasActiveOrderOrCart && currentTable.isNotEmpty) {
      await _shiftTable(targetTable.name, setStateCart);
    } else {
      _switchTable(targetTable.name, setStateCart);
    }
  }

  void _showChangeTableFloorWiseModal([StateSetter? setStateModal]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        String activeFloorTab = 'All';

        return StatefulBuilder(
          builder: (context, setFloorState) {
            final floors = ['All', ...db.tables.map((t) => t.floor.trim()).where((f) => f.isNotEmpty).toSet()];
            final filteredTables = activeFloorTab == 'All'
                ? db.tables
                : db.tables.where((t) => t.floor.trim().toLowerCase() == activeFloorTab.trim().toLowerCase()).toList();

            final Map<String, List<TableModel>> tablesByFloor = {};
            for (var t in filteredTables) {
              tablesByFloor.putIfAbsent(t.floor.trim().isEmpty ? 'General' : t.floor.trim(), () => []).add(t);
            }
            for (var floorList in tablesByFloor.values) {
              floorList.sort((a, b) {
                final numA = a.tableNumber > 0
                    ? a.tableNumber
                    : (int.tryParse(a.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 9999);
                final numB = b.tableNumber > 0
                    ? b.tableNumber
                    : (int.tryParse(b.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 9999);
                if (numA != numB) {
                  return numA.compareTo(numB);
                }
                return a.name.compareTo(b.name);
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 25, offset: Offset(0, -8)),
                ],
              ),
              child: SafeArea(
                top: false,
                bottom: true,
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF051C48).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.table_restaurant_rounded, color: Color(0xFF051C48), size: 18),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Select / Change Table',
                            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(modalCtx),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xFFE2E8F0), height: 1),

                    // Floor Filter Tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Text(
                            'Floor:',
                            style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          ...floors.map((flr) {
                            final isSel = activeFloorTab == flr;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(flr),
                                labelStyle: TextStyle(
                                  color: isSel ? Colors.white : const Color(0xFF475569),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                selected: isSel,
                                selectedColor: const Color(0xFF051C48),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: isSel ? const Color(0xFF051C48) : const Color(0xFFCBD5E1)),
                                onSelected: (_) => setFloorState(() => activeFloorTab = flr),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    // Floor-wise Table Grid View
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        itemCount: tablesByFloor.keys.length,
                        itemBuilder: (context, floorIdx) {
                          final floorName = tablesByFloor.keys.elementAt(floorIdx);
                          final floorTables = tablesByFloor[floorName]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 6, top: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 15,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF051C48),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      floorName,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${floorTables.length} Tables)',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),

                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 0.92,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: floorTables.length,
                                itemBuilder: (context, idx) {
                                  final table = floorTables[idx];
                                  final isCurrentSelected = _selectedTable == table.name;
                                  final validStatus = TableStatus.values.contains(table.status) ? table.status : TableStatus.free;
                                  final statusColor = _getTableStatusColor(validStatus);

                                  final activeOrder = validStatus == TableStatus.free
                                      ? null
                                      : db.orders.where((o) => ((o.tableNumber?.trim().toLowerCase() ?? '') == table.name.trim().toLowerCase() || 'T-${o.tableNumber}'.toLowerCase() == table.name.trim().toLowerCase()) && (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)).firstOrNull;
                                  final confirmedAmount = activeOrder?.totalAmount ?? 0.0;
                                  final liveAmount = validStatus == TableStatus.free ? 0.0 : db.getLiveCartTotal(table.name);
                                  final activeAmount = validStatus == TableStatus.free ? 0.0 : (confirmedAmount > 0 ? confirmedAmount : liveAmount);
                                  final hasProducts = validStatus != TableStatus.free && activeAmount > 0;

                                  return InkWell(
                                    onTap: () {
                                      final currentTable = _selectedTable ?? '';
                                      final hasActiveOrderOrCart = _cartItems.isNotEmpty ||
                                          _activeRunningOrderId != null ||
                                          (currentTable.isNotEmpty && _isTableRunningKot(currentTable)) ||
                                          (currentTable.isNotEmpty && db.getLiveTableCart(currentTable).isNotEmpty) ||
                                          (currentTable.isNotEmpty && db.orders.any((o) => isSameTable(o.tableNumber, currentTable) && (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)));

                                      _handleTableSelection(
                                        dialogCtx: modalCtx,
                                        targetTable: table,
                                        isShiftMode: hasActiveOrderOrCart,
                                        hasActiveOrderOrCart: hasActiveOrderOrCart,
                                        currentTable: currentTable,
                                        setStateCart: setStateModal,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isCurrentSelected ? const Color(0xFFE0F2FE) : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isCurrentSelected ? const Color(0xFF0284C7) : statusColor,
                                          width: isCurrentSelected ? 2.5 : 2.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: statusColor.withValues(alpha: 0.12),
                                            blurRadius: 5,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(6),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Status Pill Badge (Top)
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    _getTableStatusLabel(validStatus),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: statusColor,
                                                      fontSize: 9.5,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (isCurrentSelected)
                                                const Icon(Icons.check_circle_rounded, color: Color(0xFF0284C7), size: 14),
                                            ],
                                          ),

                                          // Middle Table Icon & Title
                                          Expanded(
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.table_restaurant_rounded, color: statusColor, size: 22),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _getFullTableTitle(table.name),
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12.5,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Bottom Amount Text
                                          if (hasProducts)
                                            Center(
                                              child: Text(
                                                '${db.restaurant?.currencySymbol ?? "₹"}${activeAmount.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF051C48),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showChangeTableDialog([StateSetter? setStateCart]) {
    final mediaWidth = MediaQuery.of(context).size.width;
    if (mediaWidth < 768) {
      _showChangeTableFloorWiseModal(setStateCart ?? setState);
      return;
    }

    final currentTable = _selectedTable ?? '';
    final hasActiveOrderOrCart = _cartItems.isNotEmpty ||
        _activeRunningOrderId != null ||
        (currentTable.isNotEmpty && _isTableRunningKot(currentTable));

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        String activeFloorTab = 'All';
        String searchQuery = '';
        bool isShiftMode = hasActiveOrderOrCart;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final allFloors = [
              'All',
              ...db.tables.map((t) => t.floor.trim()).where((f) => f.isNotEmpty).toSet(),
            ];

            final filteredTables = db.tables.where((t) {
              final matchesFloor = activeFloorTab == 'All' || t.floor.trim().toLowerCase() == activeFloorTab.toLowerCase();
              final matchesSearch = searchQuery.isEmpty ||
                  t.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  t.tableNumber.toString().contains(searchQuery);
              return matchesFloor && matchesSearch;
            }).toList();

            // Sort tables numerically and alphabetically
            filteredTables.sort((a, b) {
              final numA = a.tableNumber > 0
                  ? a.tableNumber
                  : (int.tryParse(a.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 9999);
              final numB = b.tableNumber > 0
                  ? b.tableNumber
                  : (int.tryParse(b.name.replaceAll(RegExp(r'[^0-9]'), '')) ?? 9999);
              if (numA != numB) return numA.compareTo(numB);
              return a.name.compareTo(b.name);
            });

            // Group by floor for clean sections
            final Map<String, List<TableModel>> tablesByFloor = {};
            for (var t in filteredTables) {
              tablesByFloor.putIfAbsent(t.floor.trim().isEmpty ? 'General' : t.floor.trim(), () => []).add(t);
            }

            final mediaWidth = MediaQuery.of(context).size.width;
            final isDesktop = mediaWidth >= 768;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 12,
                vertical: isDesktop ? 24 : 16,
              ),
              child: Container(
                width: isDesktop ? 920 : double.infinity,
                height: isDesktop ? 700 : MediaQuery.of(context).size.height * 0.88,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 30,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 1. Header Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFF051C48),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.table_restaurant_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Change / Shift Table',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentTable.isNotEmpty
                                      ? (hasActiveOrderOrCart
                                          ? 'Current: Table $currentTable • ${_cartItems.length} items (₹${cartTotal.toStringAsFixed(0)})'
                                          : 'Current: Table $currentTable (Empty)')
                                      : 'No table currently selected',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                            onPressed: () => Navigator.pop(dialogCtx),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),

                    // 2. Action Mode Selector (When active items or active orders exist)
                    if (hasActiveOrderOrCart && currentTable.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEFF6FF),
                          border: Border(bottom: BorderSide(color: Color(0xFFDBEAFE))),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setModalState(() => isShiftMode = true),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isShiftMode ? const Color(0xFF00A86B) : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isShiftMode ? const Color(0xFF00A86B) : const Color(0xFFCBD5E1),
                                      width: isShiftMode ? 1.5 : 1.0,
                                    ),
                                    boxShadow: isShiftMode
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF00A86B).withValues(alpha: 0.25),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.drive_file_move_rounded,
                                        size: 16,
                                        color: isShiftMode ? Colors.white : const Color(0xFF00A86B),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Shift Order to New Table',
                                              style: TextStyle(
                                                color: isShiftMode ? Colors.white : const Color(0xFF0F172A),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.5,
                                              ),
                                              maxLines: 1,
                                            ),
                                            Text(
                                              'Moves active cart & KOT, frees Table $currentTable',
                                              style: TextStyle(
                                                color: isShiftMode ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF64748B),
                                                fontSize: 10.5,
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
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () => setModalState(() => isShiftMode = false),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !isShiftMode ? const Color(0xFF051C48) : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: !isShiftMode ? const Color(0xFF051C48) : const Color(0xFFCBD5E1),
                                      width: !isShiftMode ? 1.5 : 1.0,
                                    ),
                                    boxShadow: !isShiftMode
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF051C48).withValues(alpha: 0.25),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.swap_horiz_rounded,
                                        size: 16,
                                        color: !isShiftMode ? Colors.white : const Color(0xFF051C48),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Switch Table (Keep Order)',
                                              style: TextStyle(
                                                color: !isShiftMode ? Colors.white : const Color(0xFF0F172A),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.5,
                                              ),
                                              maxLines: 1,
                                            ),
                                            Text(
                                              'Saves Table $currentTable draft, views new table',
                                              style: TextStyle(
                                                color: !isShiftMode ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF64748B),
                                                fontSize: 10.5,
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
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 3. Search & Floor Filters
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          // Search Box
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 36,
                              child: TextField(
                                onChanged: (v) => setModalState(() => searchQuery = v.trim()),
                                decoration: InputDecoration(
                                  hintText: 'Search table name or number...',
                                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.5),
                                  ),
                                ),
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Floor Chips
                          Expanded(
                            flex: 3,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: allFloors.map((flr) {
                                  final isSel = activeFloorTab == flr;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(flr),
                                      labelStyle: TextStyle(
                                        color: isSel ? Colors.white : const Color(0xFF475569),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11.5,
                                      ),
                                      selected: isSel,
                                      selectedColor: const Color(0xFF051C48),
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      side: BorderSide(color: isSel ? const Color(0xFF051C48) : const Color(0xFFCBD5E1)),
                                      visualDensity: VisualDensity.compact,
                                      onSelected: (_) => setModalState(() => activeFloorTab = flr),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status Legend Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      child: Row(
                        children: [
                          _buildStatusLegendDot(const Color(0xFF10B981), 'Free'),
                          const SizedBox(width: 12),
                          _buildStatusLegendDot(const Color(0xFF051C48), 'Occupied'),
                          const SizedBox(width: 12),
                          _buildStatusLegendDot(const Color(0xFFEF4444), 'Running KOT'),
                          const SizedBox(width: 12),
                          _buildStatusLegendDot(const Color(0xFF8B5CF6), 'Reserved'),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xFFE2E8F0), height: 1),

                    // 4. Tables List / Grid
                    Expanded(
                      child: filteredTables.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.table_restaurant_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No tables found matching criteria',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              itemCount: tablesByFloor.keys.length,
                              itemBuilder: (context, floorIdx) {
                                final floorName = tablesByFloor.keys.elementAt(floorIdx);
                                final floorTables = tablesByFloor[floorName]!;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF051C48),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            floorName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '(${floorTables.length} Tables)',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final width = constraints.maxWidth;
                                        final cols = width >= 800 ? 6 : width >= 600 ? 5 : width >= 440 ? 4 : 3;
                                        return GridView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: cols,
                                            childAspectRatio: 1.12,
                                            crossAxisSpacing: 8,
                                            mainAxisSpacing: 8,
                                          ),
                                          itemCount: floorTables.length,
                                          itemBuilder: (context, idx) {
                                            final table = floorTables[idx];
                                            final isCurrentSelected = isSameTable(table.name, currentTable);
                                            final validStatus = TableStatus.values.contains(table.status)
                                                ? table.status
                                                : TableStatus.free;
                                            final statusColor = _getTableStatusColor(validStatus);

                                            final activeOrder = validStatus == TableStatus.free
                                                ? null
                                                : db.orders.where((o) =>
                                                    (isSameTable(o.tableNumber, table.name) ||
                                                     'T-${o.tableNumber}'.toLowerCase() == table.name.trim().toLowerCase()) &&
                                                    (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
                                                  ).firstOrNull;
                                            final confirmedAmount = activeOrder?.totalAmount ?? 0.0;
                                            final liveAmount = validStatus == TableStatus.free ? 0.0 : db.getLiveCartTotal(table.name);
                                            final activeAmount = validStatus == TableStatus.free ? 0.0 : (confirmedAmount > 0 ? confirmedAmount : liveAmount);

                                            return InkWell(
                                              onTap: () => _handleTableSelection(
                                                dialogCtx: dialogCtx,
                                                targetTable: table,
                                                isShiftMode: isShiftMode,
                                                hasActiveOrderOrCart: hasActiveOrderOrCart,
                                                currentTable: currentTable,
                                                setStateCart: setStateCart,
                                              ),
                                              borderRadius: BorderRadius.circular(14),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: isCurrentSelected ? const Color(0xFFEFF6FF) : Colors.white,
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: isCurrentSelected
                                                        ? const Color(0xFF0284C7)
                                                        : statusColor.withValues(alpha: 0.65),
                                                    width: isCurrentSelected ? 2.2 : 1.4,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: statusColor.withValues(alpha: 0.1),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                padding: const EdgeInsets.all(7),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    // Header Row: Status badge & Current indicator
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: statusColor.withValues(alpha: 0.12),
                                                            borderRadius: BorderRadius.circular(5),
                                                          ),
                                                          child: Text(
                                                            _getTableStatusLabel(validStatus),
                                                            style: TextStyle(
                                                              color: statusColor,
                                                              fontWeight: FontWeight.w900,
                                                              fontSize: 9.5,
                                                            ),
                                                          ),
                                                        ),
                                                        if (isCurrentSelected)
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFF0284C7),
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: const Text(
                                                              'CURRENT',
                                                              style: TextStyle(
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 8,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    // Table Name
                                                    Text(
                                                      table.name,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                        color: isCurrentSelected ? const Color(0xFF0369A1) : const Color(0xFF0F172A),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    // Table Info / Active Amount
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          table.floor.isNotEmpty ? table.floor : 'Floor',
                                                          style: const TextStyle(
                                                            fontSize: 9.5,
                                                            color: Color(0xFF64748B),
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        if (activeAmount > 0)
                                                          Text(
                                                            '₹${activeAmount.toStringAsFixed(0)}',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.w900,
                                                              color: statusColor,
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
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  void _showAddCustomerDialog(StateSetter setStateModal) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _CustomerDetailsDialog(
          initialName: _customerName,
          initialPhone: _customerPhone,
          onSave: (name, phone, [address]) {
            setState(() {
              _customerName = name;
              _customerPhone = phone;
              _isLoyaltyActive = true;
              if (address != null && address.trim().isNotEmpty) {
                _setDeliveryAddressFromCustomer(address);
              }
            });
            setStateModal(() {});
            _checkCustomerLoyalty();
          },
        );
      },
    );
  }

  Future<void> _showLoyaltyPopupDialog(StateSetter setStateModal) async {
    CustomerLoyaltyModel? loyalty = _currentCustomerLoyalty;
    if (loyalty == null && _customerPhone.trim().isNotEmpty) {
      loyalty = await _loyaltyService.getCustomerLoyalty(
        _customerPhone.trim(),
        name: _customerName,
      );
      if (mounted && loyalty != null) {
        setState(() {
          _currentCustomerLoyalty = loyalty;
        });
      }
    }
    if (loyalty == null) {
      if (_customerPhone.trim().isEmpty) {
        _showAddCustomerDialog(setStateModal);
      }
      return;
    }

    final activeLoyalty = loyalty;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final ptsName = activeLoyalty.pointsName.isNotEmpty ? activeLoyalty.pointsName : 'Cash';
        final orderTypesList = activeLoyalty.orderTypes.isNotEmpty ? activeLoyalty.orderTypes : ['DineIn', 'Takeaway'];

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00A86B), Color(0xFF008B58)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Top-Right Large Translucent Circle Watermark with Currency Name ("Cash" / "Cookie")
                Positioned(
                  top: -25,
                  right: -25,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20, left: 10),
                      child: Text(
                        ptsName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),

                // Main Content Column
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Left Order Types Pill Tags
                    Row(
                      children: orderTypesList.map((ot) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            ot,
                            style: const TextStyle(
                              color: Color(0xFF059669),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Available Balance / Cashback Label with Info Icon
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Available Cashback',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.info_outline, color: Colors.white, size: 14),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Large Balance & Currency
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${activeLoyalty.pointsBalance}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ptsName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Earned & Redeemed Points stats and View Loyalty button Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Left: Earned & Redeemed stats
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Earned: ${activeLoyalty.totalPointsEarned}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Redeemed: ${activeLoyalty.totalPointsRedeemed}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Right: View Loyalty Button
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            LoyaltyRedemptionDialog.show(
                              context,
                              customerPhone: _customerPhone,
                              customerName: _customerName,
                              currentOrderTotal: cartSubtotal,
                              onDiscountApplied: (discountAmount, stageId, pointsToRedeem) {
                                setState(() {
                                  _redeemedLoyaltyStageId = stageId;
                                  _redeemedLoyaltyPoints = pointsToRedeem;
                                  _loyaltyDiscountAmount = discountAmount;
                                });
                                setStateModal(() {});
                                _checkCustomerLoyalty();
                              },
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF059669),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                            elevation: 3,
                          ),
                          child: const Text(
                            'View Loyalty',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showExtraBenefitDialog(StateSetter setStateModal) {
    db.syncExtrasFromBackend();

    final couponCtrl = TextEditingController(text: _appliedCoupon);
    final discCtrl = TextEditingController(text: _discountInputValue > 0 ? _discountInputValue.toStringAsFixed(0) : '');
    final tipCtrl = TextEditingController(text: _tipAmount > 0 ? _tipAmount.toStringAsFixed(0) : '');

    String tempDiscountMode = _discountMode;
    String tempCoupon = _appliedCoupon;
    double tempDiscountVal = _discountInputValue;
    double tempTipVal = _tipAmount;
    bool isValidatingCoupon = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, 8)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Title (Extra's) & Close Button (X)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Extra\'s',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A), size: 22),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xFFE2E8F0), height: 1),

                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 0. Loyalty Reward Program Section
                            if (_customerPhone.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF082559), Color(0xFF1E3A8A)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.18),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.cookie_outlined, color: Color(0xFFFDE68A), size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Loyalty: ${_currentCustomerLoyalty?.pointsBalance ?? 0} ${_currentCustomerLoyalty?.pointsName ?? 'Cookies'}',
                                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            _redeemedLoyaltyStageId != null
                                                ? '₹${_loyaltyDiscountAmount.toInt()} Stage Discount Applied ✓'
                                                : (_currentCustomerLoyalty?.hasUnlockedStages == true
                                                    ? '⭐ Rewards unlocked and ready!'
                                                    : 'Earn points on this completed order'),
                                            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 10.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF082559),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        elevation: 0,
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () {
                                        LoyaltyRedemptionDialog.show(
                                          context,
                                          customerPhone: _customerPhone,
                                          customerName: _customerName,
                                          currentOrderTotal: cartSubtotal,
                                          onDiscountApplied: (discount, stageId, points) {
                                            setDialogState(() {
                                              tempDiscountMode = '₹';
                                              tempDiscountVal = discount;
                                              discCtrl.text = discount.toStringAsFixed(0);
                                              _discountMode = '₹';
                                              _discountInputValue = discount;
                                              _loyaltyDiscountAmount = discount;
                                              _redeemedLoyaltyStageId = stageId;
                                              _redeemedLoyaltyPoints = points;
                                            });
                                            setState(() {});
                                            setStateModal(() {});
                                          },
                                        );
                                      },
                                      child: const Text('Redeem (OTP)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // 1. Coupon Section
                            const Text(
                              'Coupon',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),

                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: couponCtrl,
                                      scrollPadding: const EdgeInsets.only(bottom: 90),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      decoration: const InputDecoration(
                                        hintText: 'SAVE50',
                                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.all(4),
                                    child: ElevatedButton(
                                      onPressed: isValidatingCoupon
                                          ? null
                                          : () async {
                                              final rawCode = couponCtrl.text.trim();
                                              if (rawCode.isEmpty) {
                                                setDialogState(() {
                                                  tempCoupon = '';
                                                });
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Coupon cleared.'),
                                                    duration: Duration(seconds: 1),
                                                    backgroundColor: Color(0xFF051C48),
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                                return;
                                              }

                                              setDialogState(() => isValidatingCoupon = true);
                                              final result = await db.extraService.validateCoupon(
                                                code: rawCode,
                                                subtotal: cartSubtotal,
                                                availableCoupons: db.extras,
                                              );
                                              if (context.mounted) {
                                                setDialogState(() {
                                                  isValidatingCoupon = false;
                                                  if (result.isValid) {
                                                    tempCoupon = rawCode.toUpperCase();
                                                  }
                                                });
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(result.message),
                                                    duration: const Duration(seconds: 2),
                                                    backgroundColor: result.isValid
                                                        ? const Color(0xFF051C48)
                                                        : const Color(0xFFDC2626),
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF051C48),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                      ),
                                      child: isValidatingCoupon
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // 2. Add Discount Card Container
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Add Discount',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),

                                      // Mode Toggle Pill (% vs ₹)
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE2E8F0),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          children: [
                                            InkWell(
                                              onTap: () => setDialogState(() => tempDiscountMode = 'percent'),
                                              borderRadius: BorderRadius.circular(16),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: tempDiscountMode == 'percent' ? Colors.white : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(16),
                                                  boxShadow: tempDiscountMode == 'percent'
                                                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                                                      : [],
                                                ),
                                                child: Text(
                                                  '%',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: tempDiscountMode == 'percent' ? const Color(0xFF051C48) : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () => setDialogState(() => tempDiscountMode = 'flat'),
                                              borderRadius: BorderRadius.circular(16),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: tempDiscountMode == 'flat' ? Colors.white : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(16),
                                                  boxShadow: tempDiscountMode == 'flat'
                                                      ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                                                      : [],
                                                ),
                                                child: Text(
                                                  '₹',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: tempDiscountMode == 'flat' ? const Color(0xFF051C48) : const Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),

                                  // Input Box with Apply Button
                                  Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: discCtrl,
                                            scrollPadding: const EdgeInsets.only(bottom: 90),
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                            decoration: InputDecoration(
                                              hintText: tempDiscountMode == 'percent' ? '10' : '50',
                                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              border: InputBorder.none,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          margin: const EdgeInsets.all(4),
                                          child: ElevatedButton(
                                            onPressed: () {
                                              final val = double.tryParse(discCtrl.text.trim()) ?? 0.0;
                                              setDialogState(() {
                                                tempDiscountVal = val;
                                              });
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(val > 0
                                                      ? 'Discount of ${tempDiscountMode == "percent" ? "$val%" : "₹$val"} Applied!'
                                                      : 'Discount reset.'),
                                                  duration: const Duration(seconds: 1),
                                                  backgroundColor: const Color(0xFF051C48),
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF051C48),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                            ),
                                            child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // 3. Add Tip Section
                            const Text(
                              'Add Tip',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),

                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: tipCtrl,
                                      scrollPadding: const EdgeInsets.only(bottom: 90),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      decoration: const InputDecoration(
                                        hintText: '10',
                                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.all(4),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        final val = double.tryParse(tipCtrl.text.trim()) ?? 0.0;
                                        setDialogState(() {
                                          tempTipVal = val;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(val > 0 ? 'Tip of ₹${val.toStringAsFixed(0)} Added!' : 'Tip cleared.'),
                                            duration: const Duration(seconds: 1),
                                            backgroundColor: const Color(0xFF051C48),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF051C48),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                      ),
                                      child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // 4. Done Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () {
                                  final discountVal = double.tryParse(discCtrl.text.trim()) ?? tempDiscountVal;
                                  final tipVal = double.tryParse(tipCtrl.text.trim()) ?? tempTipVal;

                                  setState(() {
                                    _appliedCoupon = tempCoupon;
                                    _promoCodeController.text = tempCoupon;
                                    _discountMode = tempDiscountMode;
                                    _discountInputValue = discountVal;
                                    _tipAmount = tipVal;
                                    _discountAmount = 0.0; // reset manual override so getter calculates
                                  });
                                  _saveCurrentDraft();

                                  setStateModal(() {});
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF051C48),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                ),
                                child: const Text(
                                  'Done',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrderTypeIconBox() {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: _selectedOrderType == OrderType.dineIn
            ? const Color(0xFFE0F2FE)
            : (_selectedOrderType == OrderType.delivery
                ? const Color(0xFFD1FAE5)
                : const Color(0xFFFEF3C7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        _selectedOrderType == OrderType.dineIn
            ? Icons.table_restaurant_rounded
            : (_selectedOrderType == OrderType.delivery
                ? Icons.local_shipping_outlined
                : Icons.shopping_bag_outlined),
        color: _selectedOrderType == OrderType.dineIn
            ? const Color(0xFF0284C7)
            : (_selectedOrderType == OrderType.delivery
                ? const Color(0xFF059669)
                : const Color(0xFFD97706)),
        size: 19,
      ),
    );
  }

  Widget _buildOrderTypeInfo(StateSetter setStateCart) {
    if (_selectedOrderType == OrderType.dineIn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getFullTableTitle(),
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: () => _showChangeTableDialog(setStateCart),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00A896), width: 1.2),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Change Table',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00A896),
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 12, color: Color(0xFF00A896)),
                ],
              ),
            ),
          ),
        ],
      );
    } else if (_selectedOrderType == OrderType.takeaway) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Takeaway Order',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2),
          Text(
            'Pickup at Counter',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _hasDeliveryAddress
                ? (_deliveryLandmark.isNotEmpty
                    ? '$_deliveryAddress (Near $_deliveryLandmark)'
                    : _deliveryAddress)
                : 'Delivery Order',
            style: const TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: () => _showDeliveryAddressDialog(setStateCart),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _hasDeliveryAddress ? const Color(0xFF00A896) : const Color(0xFF051C48),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _hasDeliveryAddress ? Icons.edit_location_alt_rounded : Icons.add_location_alt_rounded,
                    size: 12,
                    color: _hasDeliveryAddress ? const Color(0xFF00A896) : const Color(0xFF051C48),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _hasDeliveryAddress ? 'Edit Address' : 'Add Address',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: _hasDeliveryAddress ? const Color(0xFF00A896) : const Color(0xFF051C48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildOrderTypeDropdown(StateSetter setStateCart) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF051C48), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<OrderType>(
          value: _selectedOrderType,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(16),
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF051C48), size: 18),
          items: OrderType.values.map((type) {
            final label = type == OrderType.dineIn
                ? 'DineIn'
                : type == OrderType.takeaway
                    ? 'Takeaway'
                    : 'Delivery';
            return DropdownMenuItem(
              value: type,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF051C48),
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              _switchOrderType(val, setStateCart);
              if (val == OrderType.delivery && !_hasDeliveryAddress) {
                if (_customerPhone.isNotEmpty) {
                  final cust = db.getCustomerByPhone(_customerPhone);
                  if (cust != null && cust.address.isNotEmpty) {
                    _setDeliveryAddressFromCustomer(cust.address);
                  }
                }
                if (!_hasDeliveryAddress) {
                  _showDeliveryAddressDialog(setStateCart);
                }
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildCartPanelContent({required StateSetter setStateCart, bool isDesktopPanel = false}) {
    final currency = db.restaurant?.currencySymbol ?? '₹';

    return Column(
      children: [
        if (!isDesktopPanel) ...[
          // Handle Bar for mobile sheet
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Top Navigation Header for mobile sheet
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                _buildOrderTypeIconBox(),
                const SizedBox(width: 8),
                Expanded(child: _buildOrderTypeInfo(setStateCart)),
                const SizedBox(width: 6),
                _buildOrderTypeDropdown(setStateCart),
              ],
            ),
          ),
        ] else ...[
          // Desktop "Cart Details" Header (Curved Reference UI)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                const Text(
                  'Cart Details',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                if (_cartItems.isNotEmpty)
                  InkWell(
                    onTap: () => _handleClearCartAction(context, setStateCart),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 13),
                          SizedBox(width: 3),
                          Text('Clear all', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 3-Way Segmented Switcher: Dine in | Takeaway | Delivery
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(2.5),
              child: Row(
                children: [
                  _buildDesktopSegmentItem('Dine in', OrderType.dineIn, setStateCart),
                  _buildDesktopSegmentItem('Takeaway', OrderType.takeaway, setStateCart),
                  _buildDesktopSegmentItem('Delivery', OrderType.delivery, setStateCart),
                ],
              ),
            ),
          ),

          // Customer Information & Table Selector Card
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Customer information',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      if (_isLoyaltyActive || _currentCustomerLoyalty?.isProgramActive == true || _customerPhone.isNotEmpty || _customerName.isNotEmpty)
                        InkWell(
                          onTap: () {
                            if (_customerPhone.isNotEmpty || _customerName.isNotEmpty) {
                              _showLoyaltyPopupDialog(setStateCart);
                            } else {
                              _showAddCustomerDialog(setStateCart);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: (_customerPhone.isNotEmpty || _customerName.isNotEmpty) ? const Color(0xFF00A86B) : const Color(0xFF051C48).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Loyalty',
                              style: TextStyle(
                                color: (_customerPhone.isNotEmpty || _customerName.isNotEmpty) ? Colors.white : const Color(0xFF051C48),
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Customer Name Field
                  InkWell(
                    onTap: () => _showAddCustomerDialog(setStateCart),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _customerName.isNotEmpty
                                  ? '$_customerName${_customerPhone.isNotEmpty ? " ($_customerPhone)" : ""}'
                                  : 'Enter customer name',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: _customerName.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                fontWeight: _customerName.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ),

                  // Table Location (Dine-In) or Delivery Address (Delivery)
                  if (_selectedOrderType == OrderType.dineIn) ...[
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: () => _showChangeTableDialog(setStateCart),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.table_restaurant_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _selectedTable != null && _selectedTable!.isNotEmpty ? 'Table: $_selectedTable' : 'Select table location',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: _selectedTable != null && _selectedTable!.isNotEmpty ? const Color(0xFF051C48) : const Color(0xFF94A3B8),
                                  fontWeight: _selectedTable != null && _selectedTable!.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ] else if (_selectedOrderType == OrderType.delivery) ...[
                    const SizedBox(height: 5),
                    InkWell(
                      onTap: () => _showDeliveryAddressDialog(setStateCart),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _hasDeliveryAddress ? _deliveryAddress : 'Enter delivery address',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: _hasDeliveryAddress ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                  fontWeight: _hasDeliveryAddress ? FontWeight.w600 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],

        // Items Header
        if (!isDesktopPanel)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Items (${_cartItems.fold<int>(0, (sum, i) => sum + i.quantity)})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (_cartItems.isNotEmpty)
                  InkWell(
                    onTap: () => _handleClearCartAction(context, setStateCart),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Clear Cart',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order items (${_cartItems.fold<int>(0, (sum, i) => sum + i.quantity)})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),

        // Cart Item Cards List
        Expanded(
          child: _cartItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: isDesktopPanel ? 36 : 56, color: const Color(0xFFCBD5E1)),
                      const SizedBox(height: 6),
                      Text(
                        isDesktopPanel ? 'No items in cart.\nClick products to add.' : 'Your cart is empty',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: isDesktopPanel ? 12 : 16, vertical: 3),
                  itemCount: _cartItems.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 5),
                  itemBuilder: (context, idx) {
                    final cItem = _cartItems[idx];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Item Title & Price (No Product Image on Cart Screen)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    FoodTypeIcon(itemType: cItem.item.itemType, size: 9),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        cItem.item.name,
                                        style: TextStyle(
                                          fontSize: isDesktopPanel ? 12.0 : 14.0,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (cItem.item.hasDiscount && cItem.item.discountPercent > 0) ...[
                                      Text(
                                        '$currency${cItem.item.effectivePrice.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          fontSize: isDesktopPanel ? 12.0 : 14,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF051C48),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$currency${cItem.item.price.toStringAsFixed(1)}',
                                        style: const TextStyle(
                                          fontSize: 10.0,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF64748B),
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        '$currency${cItem.item.price.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          fontSize: isDesktopPanel ? 12.0 : 14,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF051C48),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 6),
                                    Builder(
                                      builder: (context) {
                                        final double effectiveGst = cItem.item.gstPercent ?? ((db.restaurant?.billingType == 'Non-GST') ? 0.0 : (db.restaurant?.taxRate ?? 5.0));
                                        if (effectiveGst <= 0) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'No GST',
                                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                            ),
                                          );
                                        }
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'GST ${effectiveGst.toStringAsFixed(0)}%',
                                            style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Pill Quantity Stepper (- QTY +)
                          _buildPillQuantityStepper(
                            quantity: cItem.quantity,
                            onDecrement: () {
                              _decrementCartItem(cItem.item);
                              setStateCart(() {});
                              setState(() {});
                              if (!isDesktopPanel) {
                                _checkAndCloseEmptyCart(context, setStateCart);
                              }
                            },
                            onIncrement: () {
                              _addToCart(cItem.item);
                              setStateCart(() {});
                              setState(() {});
                            },
                            height: 28,
                            buttonSize: 22,
                            fontSize: 12.5,
                          ),
                          const SizedBox(width: 6),

                          // Trash Delete Button
                          InkWell(
                            onTap: () {
                              _removeCartItem(cItem.item);
                              setStateCart(() {});
                              setState(() {});
                              if (!isDesktopPanel) {
                                _checkAndCloseEmptyCart(context, setStateCart);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFEF4444),
                                size: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Add Customer & Extra's Buttons (Mobile only)
        if (!isDesktopPanel)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showAddCustomerDialog(setStateCart),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF051C48),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF051C48).withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_circle_outlined, color: Colors.white, size: 18),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _customerName.isNotEmpty ? _customerName : 'Add Customer',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_customerPhone.isNotEmpty)
                                  Text(
                                    _customerPhone,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 9.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          if (_isLoyaltyActive || _currentCustomerLoyalty?.isProgramActive == true || _customerPhone.isNotEmpty || _customerName.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                if (_customerPhone.isNotEmpty || _customerName.isNotEmpty) {
                                  _showLoyaltyPopupDialog(setStateCart);
                                } else {
                                  _showAddCustomerDialog(setStateCart);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: (_customerPhone.isNotEmpty || _customerName.isNotEmpty)
                                      ? const Color(0xFF00A86B)
                                      : Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: (_customerPhone.isNotEmpty || _customerName.isNotEmpty)
                                        ? const Color(0xFF5EEAD4)
                                        : Colors.white24,
                                    width: 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'L',
                                    style: TextStyle(
                                      color: (_customerPhone.isNotEmpty || _customerName.isNotEmpty)
                                          ? Colors.white
                                          : Colors.white38,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                Expanded(
                  child: InkWell(
                    onTap: () => _showExtraBenefitDialog(setStateCart),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF051C48), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFF051C48),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.sell_outlined, color: Colors.white, size: 10),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              (computedDiscountAmount > 0 || _tipAmount > 0)
                                  ? 'Extra\'s (₹${(computedDiscountAmount + _tipAmount).toStringAsFixed(0)})'
                                  : 'Extra\'s',
                              style: const TextStyle(
                                color: Color(0xFF051C48),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
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
            ),
          ),

        // Price Summary Card
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktopPanel ? 14 : 14, vertical: 3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sub total',
                      style: const TextStyle(fontSize: 12.0, color: Color(0xFF64748B)),
                    ),
                    Text(
                      '$currency${cartSubtotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                if (computedDiscountAmount > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _appliedCoupon.isNotEmpty
                            ? (currentOrderCalculation.appliedCouponPercent > 0
                                ? 'Discount (${_appliedCoupon.toUpperCase()} • ${currentOrderCalculation.appliedCouponPercent.toStringAsFixed(currentOrderCalculation.appliedCouponPercent.truncateToDouble() == currentOrderCalculation.appliedCouponPercent ? 0 : 1)}%):'
                                : 'Discount (${_appliedCoupon.toUpperCase()}):')
                            : (_discountMode == 'percent' && _discountInputValue > 0
                                ? 'Discount (${_discountInputValue.toStringAsFixed(0)}%):'
                                : 'Discount:'),
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '- $currency${computedDiscountAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ],
                if (_tipAmount > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tip:', style: TextStyle(fontSize: 11.5, color: Color(0xFF00A896), fontWeight: FontWeight.bold)),
                      Text(
                        '+ $currency${_tipAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF00A896)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 2),
                Builder(
                  builder: (context) {
                    final bool isNonGst = db.restaurant?.billingType == 'Non-GST';
                    final nonZeroRates = currentOrderCalculation.taxBreakupByRate.keys.where((r) => r > 0).toList();
                    final String taxLabel = isNonGst
                        ? 'Tax (Non-GST):'
                        : (cartTax <= 0
                            ? 'Tax (0% / Exempt):'
                            : (nonZeroRates.length == 1
                                ? 'GST (${nonZeroRates.first.toStringAsFixed(0)}%):'
                                : 'GST (Dynamic):'));

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          taxLabel,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                        Text(
                          '+ $currency${cartTax.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Divider(color: Color(0xFFE2E8F0), height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total amount',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '$currency${cartTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: Color(0xFF051C48)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Promo Code Row (Desktop Only)
        if (isDesktopPanel)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _appliedCoupon.isNotEmpty ? const Color(0xFF0066FF) : const Color(0xFFCBD5E1),
                      width: _appliedCoupon.isNotEmpty ? 1.4 : 1.0,
                    ),
                    boxShadow: _appliedCoupon.isNotEmpty
                        ? [
                            BoxShadow(
                              color: const Color(0xFF0066FF).withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Icon(
                        Icons.sell_outlined,
                        size: 15,
                        color: _appliedCoupon.isNotEmpty ? const Color(0xFF0066FF) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _promoCodeController,
                          onChanged: (val) {
                            if (val.trim().isEmpty && _appliedCoupon.isNotEmpty) {
                              setStateCart(() => _appliedCoupon = '');
                              setState(() => _appliedCoupon = '');
                            }
                          },
                          onSubmitted: (val) => _applyPromoCode(val, setStateCart),
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Enter promo code (e.g. 10%, SAVE20)',
                            hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            suffixIcon: _appliedCoupon.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFF94A3B8)),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    onPressed: () {
                                      _promoCodeController.clear();
                                      setStateCart(() => _appliedCoupon = '');
                                      setState(() => _appliedCoupon = '');
                                    },
                                    tooltip: 'Remove promo code',
                                  )
                                : null,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _applyPromoCode(_promoCodeController.text, setStateCart),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          margin: const EdgeInsets.only(right: 3),
                          decoration: BoxDecoration(
                            color: _appliedCoupon.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFF051C48),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _appliedCoupon.isNotEmpty ? 'Applied' : 'Apply',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _showExtraBenefitDialog(setStateCart),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Center(
                    child: Text(
                      (computedDiscountAmount > 0 || _tipAmount > 0)
                          ? 'Extra\'s (₹${(computedDiscountAmount + _tipAmount).toStringAsFixed(0)})'
                          : 'Extra\'s',
                      style: const TextStyle(color: Color(0xFF051C48), fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bottom Action Buttons
        if (isDesktopPanel)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Primary "Proceed payment" Action Button (Matching Reference UI)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _cartItems.isEmpty
                            ? [const Color(0xFF94A3B8), const Color(0xFF64748B)]
                            : [const Color(0xFF051C48), const Color(0xFF0A2E7A)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _cartItems.isEmpty
                          ? []
                          : [
                              BoxShadow(
                                color: const Color(0xFF051C48).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: ElevatedButton(
                      onPressed: _cartItems.isEmpty
                          ? null
                          : () {
                              _checkoutOrder(cartContext: null);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.payment_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Proceed payment ($currency${cartTotal.toStringAsFixed(2)})',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // KOT Button
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: _cartItems.isEmpty
                              ? null
                              : () async {
                                  await _sendKotOrder(setStateCart);
                                },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: _cartItems.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF051C48),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            'Print KOT',
                            style: TextStyle(
                              color: _cartItems.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF051C48),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Save & Print Button
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton.icon(
                          onPressed: _cartItems.isEmpty
                              ? null
                              : () async {
                                  await _handleSaveAndPrint(setStateCart, null);
                                },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: _cartItems.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF051C48),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                          ),
                          icon: Icon(
                            Icons.print_outlined,
                            size: 14,
                            color: _cartItems.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF051C48),
                          ),
                          label: Text(
                            'Save & Print',
                            style: TextStyle(
                              color: _cartItems.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF051C48),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          // Mobile Action Buttons: KOT | Save & Print | Settle
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                // 1) KOT Button
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: _cartItems.isEmpty
                          ? null
                          : () async {
                              await _sendKotOrder(setStateCart);
                            },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _cartItems.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF051C48),
                          width: 1.4,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'KOT',
                          style: TextStyle(
                            color: _cartItems.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF051C48),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 2) Save & Print Button (Between KOT and Settle)
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: _cartItems.isEmpty
                          ? null
                          : () async {
                              await _handleSaveAndPrint(setStateCart, context);
                            },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _cartItems.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF051C48),
                          width: 1.4,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.print_outlined,
                              size: 16,
                              color: _cartItems.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF051C48),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Save & Print',
                              style: TextStyle(
                                color: _cartItems.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF051C48),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 3) Settle Button
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 46,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _cartItems.isEmpty
                              ? [const Color(0xFF94A3B8), const Color(0xFF64748B)]
                              : [const Color(0xFF051C48), const Color(0xFF0A2E7A)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _cartItems.isEmpty
                            ? []
                            : [
                                BoxShadow(
                                  color: const Color(0xFF051C48).withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: ElevatedButton(
                        onPressed: _cartItems.isEmpty
                            ? null
                            : () {
                                _checkoutOrder(cartContext: context);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Settle',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _switchOrderType(OrderType type, [StateSetter? setStateCart]) {
    if (_selectedOrderType == type) return;
    _saveCurrentDraft();

    void updateState() {
      _selectedOrderType = type;
      _activeRunningOrderId = null;
      _activeRunningOrderNumber = null;
      _cartItems.clear();
      _resetDiscountAndPromoState();

      if (type == OrderType.dineIn) {
        if (_selectedTable == null || _selectedTable!.isEmpty) {
          final nextTable = db.getNextAvailableTableSequence();
          _selectedTable = nextTable?.name ?? 'T-1';
        }
        final targetTable = _selectedTable!;
        final activeOrder = db.orders.where((o) =>
          isSameTable(o.tableNumber, targetTable) &&
          (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
        ).firstOrNull;
        if (activeOrder != null && activeOrder.items.isNotEmpty) {
          _cartItems.addAll(activeOrder.items);
          _activeRunningOrderId = activeOrder.id;
          _activeRunningOrderNumber = activeOrder.orderNumber;
          _customerName = activeOrder.customerName ?? '';
          _customerPhone = activeOrder.customerPhone ?? '';
        } else {
          final savedCart = db.getLiveTableCart(targetTable);
          if (savedCart.isNotEmpty) {
            _cartItems.addAll(savedCart);
          }
        }
        final savedDiscount = db.getLiveTableDiscount(targetTable);
        if (savedDiscount != null) {
          _appliedCoupon = savedDiscount['coupon']?.toString() ?? '';
          _promoCodeController.text = _appliedCoupon;
          _discountInputValue = (savedDiscount['discountInput'] as num?)?.toDouble() ?? 0.0;
          _discountMode = savedDiscount['discountMode']?.toString() ?? 'percent';
          _discountAmount = (savedDiscount['discountAmount'] as num?)?.toDouble() ?? 0.0;
        } else if (activeOrder != null && activeOrder.discountAmount > 0) {
          _discountAmount = activeOrder.discountAmount;
        }
      } else {
        _selectedTable = null;
        final key = type == OrderType.takeaway ? 'Takeaway' : 'Delivery';
        final savedCart = db.getLiveTableCart(key);
        if (savedCart.isNotEmpty) {
          _cartItems.addAll(savedCart);
        }
        final savedDiscount = db.getLiveTableDiscount(key);
        if (savedDiscount != null) {
          _appliedCoupon = savedDiscount['coupon']?.toString() ?? '';
          _promoCodeController.text = _appliedCoupon;
          _discountInputValue = (savedDiscount['discountInput'] as num?)?.toDouble() ?? 0.0;
          _discountMode = savedDiscount['discountMode']?.toString() ?? 'percent';
          _discountAmount = (savedDiscount['discountAmount'] as num?)?.toDouble() ?? 0.0;
        }
      }
    }

    if (setStateCart != null) {
      setStateCart(updateState);
    }
    setState(updateState);
  }

  Widget _buildDesktopSegmentItem(String title, OrderType type, StateSetter setStateCart) {
    final isSelected = _selectedOrderType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchOrderType(type, setStateCart),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    const BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? const Color(0xFF051C48) : const Color(0xFF64748B),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _openCartScreenModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, -10)),
                ],
              ),
              child: SafeArea(
                top: false,
                bottom: true,
                child: _buildCartPanelContent(setStateCart: setStateModal, isDesktopPanel: false),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSaveAndPrint([StateSetter? setStateModal, BuildContext? callerContext]) async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add items to cart before Save & Print!'),
          backgroundColor: Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final currency = db.restaurant?.currencySymbol ?? '₹';
    final calc = currentOrderCalculation;
    final targetContext = callerContext ?? context;

    // Resolve existing active table / takeaway / delivery order ID if not in state
    if (_activeRunningOrderId == null) {
      if (_selectedOrderType == OrderType.dineIn && _selectedTable != null) {
        final activeOrder = db.orders.where((o) =>
          isSameTable(o.tableNumber, _selectedTable) &&
          (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
        ).firstOrNull;
        if (activeOrder != null) {
          _activeRunningOrderId = activeOrder.id;
          _activeRunningOrderNumber = activeOrder.orderNumber;
        }
      } else {
        final activeOrder = db.orders.where((o) =>
          o.orderType == _selectedOrderType &&
          (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
        ).firstOrNull;
        if (activeOrder != null) {
          _activeRunningOrderId = activeOrder.id;
          _activeRunningOrderNumber = activeOrder.orderNumber;
        }
      }
    }

    try {
      final savedOrder = await db.saveAndPrintOrder(
        existingOrderId: _activeRunningOrderId,
        existingOrderNumber: _activeRunningOrderNumber,
        items: List.from(_cartItems),
        tableNumber: _selectedOrderType == OrderType.dineIn ? (_selectedTable ?? 'T1') : null,
        deliveryAddress: _selectedOrderType == OrderType.delivery ? _formattedDeliveryAddress : null,
        orderType: _selectedOrderType,
        subtotalOverride: calc.subtotal,
        discountAmount: calc.orderDiscount,
        taxAmountOverride: calc.taxAmount,
        tipAmount: calc.tipAmount,
        deliveryCharge: calc.deliveryCharge,
        totalAmount: calc.totalPayableAmount,
        customerName: _customerName.trim().isNotEmpty ? _customerName.trim() : null,
        customerPhone: _customerPhone.trim().isNotEmpty ? _customerPhone.trim() : null,
      );

      // Track active running order ID & number for future edits / settle
      setState(() {
        _activeRunningOrderId = savedOrder.id;
        _activeRunningOrderNumber = savedOrder.orderNumber;
      });
      if (setStateModal != null) {
        setStateModal(() {});
      }

      // DO NOT clear cart, DO NOT mark as paid, DO NOT close modal.
      // Instantly show ReceiptDialog with generated invoice and dynamic QR
      showDialog(
        context: targetContext,
        builder: (_) => ReceiptDialog(
          order: savedOrder,
          currency: currency,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(targetContext).showSnackBar(
          SnackBar(
            content: Text('Save & Print error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _checkoutOrder({BuildContext? cartContext}) async {
    if (_cartItems.isEmpty) return;

    final currency = db.restaurant?.currencySymbol ?? '₹';
    final calc = currentOrderCalculation;
    final tempOrderId = _activeRunningOrderId ?? 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final tempOrderNumber = _activeRunningOrderNumber ?? (db.orders.length + 1).toString().padLeft(4, '0');

    final previewOrder = OrderModel(
      id: tempOrderId,
      orderNumber: tempOrderNumber,
      items: List.from(_cartItems),
      tableNumber: _selectedOrderType == OrderType.dineIn ? (_selectedTable ?? 'T1') : null,
      deliveryAddress: _selectedOrderType == OrderType.delivery ? _formattedDeliveryAddress : null,
      orderType: _selectedOrderType,
      subtotal: calc.subtotal,
      discountAmount: calc.orderDiscount,
      taxAmount: calc.taxAmount,
      tipAmount: calc.tipAmount,
      deliveryCharge: calc.deliveryCharge,
      totalAmount: calc.totalPayableAmount,
      paymentMethod: 'Cash',
      paymentStatus: 'pending',
      isPaid: false,
      status: OrderStatus.pending,
      customerName: _customerName,
      customerPhone: _customerPhone,
      createdAt: DateTime.now().toIso8601String(),
    );

    final modalResult = await showDialog<dynamic>(
      context: context,
      useRootNavigator: true,
      builder: (_) => PaymentModal(
        order: previewOrder,
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
        // If order was already saved in DB (via KOT or Save&Print), settle it; otherwise create completed order
        final existingKotIndex = db.orders.indexWhere((o) =>
          (_activeRunningOrderId != null && (o.id == _activeRunningOrderId || o.orderNumber == _activeRunningOrderId)) ||
          (_selectedOrderType == OrderType.dineIn && _selectedTable != null &&
           isSameTable(o.tableNumber, _selectedTable) &&
           (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)) ||
          (_selectedOrderType != OrderType.dineIn &&
           o.orderType == _selectedOrderType &&
           (o.status == OrderStatus.pending || o.status == OrderStatus.preparing))
        );

        OrderModel completedOrder;
        if (existingKotIndex >= 0) {
          final targetKotOrder = db.orders[existingKotIndex];
          completedOrder = await db.settleOrder(
            orderId: targetKotOrder.id,
            paymentMethod: resultMethod,
            totalAmount: totalAmount ?? calc.totalPayableAmount,
            roundOff: roundOff ?? 0.0,
          );
        } else {
          // CREATE FINALIZED COMPLETED ORDER ATOMICALLY
          completedOrder = await db.createOrder(
            items: List.from(_cartItems),
            tableNumber: _selectedOrderType == OrderType.dineIn ? (_selectedTable ?? 'T1') : null,
            deliveryAddress: _selectedOrderType == OrderType.delivery ? _formattedDeliveryAddress : null,
            orderType: _selectedOrderType,
            subtotalOverride: calc.subtotal,
            discountAmount: calc.orderDiscount,
            taxAmountOverride: calc.taxAmount,
            tipAmount: calc.tipAmount,
            deliveryCharge: calc.deliveryCharge,
            paymentMethod: resultMethod,
            status: OrderStatus.completed,
            customerName: _customerName,
            customerPhone: _customerPhone,
            roundOff: roundOff ?? 0.0,
            totalAmount: totalAmount ?? calc.totalPayableAmount,
          );
        }

        // Robustly free table on settlement
        final targetTableStr = _selectedTable ?? completedOrder.tableNumber;
        if (targetTableStr != null && targetTableStr.isNotEmpty) {
          db.clearTableCartAndFree(targetTableStr);
        }

        // Deduct redeemed loyalty points asynchronously in background (non-blocking)
        if (_redeemedLoyaltyStageId != null && _redeemedLoyaltyPoints > 0 && _customerPhone.isNotEmpty) {
          _loyaltyService.redeemLoyaltyPoints(
            phone: _customerPhone,
            stageId: _redeemedLoyaltyStageId!,
            discountAmount: _loyaltyDiscountAmount,
            pointsToRedeem: _redeemedLoyaltyPoints,
            orderId: completedOrder.id,
            orderNumber: completedOrder.orderNumber,
          ).catchError((e) {
            debugPrint('[_checkoutOrder] Loyalty redemption sync error: $e');
            return null;
          });
        }

        // Reset cart state and promo discount state immediately for the next order
        setState(() {
          _cartItems.clear();
          _resetDiscountAndPromoState();
          _currentCustomerLoyalty = null;
          _selectedTable = null;
          _customerName = '';
          _customerPhone = '';
          _deliveryAddress = '';
          _deliveryLandmark = '';
          _deliveryCity = '';
          _deliveryState = '';
          _deliveryPincode = '';
          _activeRunningOrderId = null;
          _activeRunningOrderNumber = null;
        });

        // Close the cart screen modal when payment is successfully done
        if (cartContext != null && cartContext.mounted) {
          Navigator.pop(cartContext);
        }

        // Instantly display the thermal receipt dialog with zero latency
        if (mounted) {
          showGeneralDialog(
            context: context,
            useRootNavigator: true,
            barrierDismissible: true,
            barrierLabel: 'Thermal Bill Receipt',
            barrierColor: Colors.black54,
            transitionDuration: const Duration(milliseconds: 100),
            pageBuilder: (ctx, anim1, anim2) => ReceiptDialog(order: completedOrder, currency: currency),
          );
        }
      }
    }
  }

  Widget _buildDesktopOrderQueuesCard() {
    final activeOrders = db.orders.where((o) =>
      o.status == OrderStatus.pending ||
      o.status == OrderStatus.preparing ||
      o.status == OrderStatus.ready
    ).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            children: [
              const Text(
                'Order queues',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
              if (activeOrders.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF051C48).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${activeOrders.length}',
                    style: const TextStyle(
                      color: Color(0xFF051C48),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // New Order Button (Opens Table Layout / Selection Dialog)
              ElevatedButton.icon(
                onPressed: () => _openTablesSelectionDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF051C48),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  visualDensity: VisualDensity.compact,
                  elevation: 1,
                ),
                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'New Order',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Active Orders Carousel / Empty State
          if (activeOrders.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 20, color: Color(0xFF94A3B8)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No active orders in queue. New running KOTs and table orders will show up here.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: activeOrders.length,
                separatorBuilder: (_, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final order = activeOrders[index];
                  final isSelected = (_activeRunningOrderId == order.id || _activeRunningOrderNumber == order.orderNumber);

                  Color statusBg;
                  Color statusText;
                  String statusLabel;
                  if (order.status == OrderStatus.ready) {
                    statusBg = const Color(0xFFDCFCE7);
                    statusText = const Color(0xFF15803D);
                    statusLabel = 'Ready to serve';
                  } else if (order.status == OrderStatus.preparing) {
                    statusBg = const Color(0xFFFEF3C7);
                    statusText = const Color(0xFFB45309);
                    statusLabel = 'Cooking';
                  } else if (order.status == OrderStatus.cancelled) {
                    statusBg = const Color(0xFFFEE2E2);
                    statusText = const Color(0xFFB91C1C);
                    statusLabel = 'Canceled';
                  } else {
                    statusBg = const Color(0xFFE0F2FE);
                    statusText = const Color(0xFF0369A1);
                    statusLabel = 'Pending';
                  }

                  final itemCount = order.items.fold(0, (sum, i) => sum + i.quantity);
                  final locationLabel = order.orderType == OrderType.dineIn
                      ? (order.tableNumber?.isNotEmpty == true ? 'Table ${order.tableNumber}' : 'Dine In')
                      : (order.orderType == OrderType.takeaway ? 'Takeaway' : 'Delivery');

                  return InkWell(
                    onTap: () {
                      _saveCurrentDraft();
                      if (order.tableNumber != null && order.tableNumber!.isNotEmpty) {
                        _loadCartForTable(order.tableNumber!);
                      } else {
                        setState(() {
                          _selectedOrderType = order.orderType;
                          _selectedTable = order.tableNumber;
                          _cartItems.clear();
                          _resetDiscountAndPromoState();
                          _cartItems.addAll(order.items);
                          _activeRunningOrderId = order.id;
                          _activeRunningOrderNumber = order.orderNumber;
                          _customerName = order.customerName ?? '';
                          _customerPhone = order.customerPhone ?? '';
                          _deliveryAddress = order.deliveryAddress ?? '';

                          final draftKey = order.id;
                          final typeKey = order.orderType == OrderType.takeaway ? 'Takeaway' : 'Delivery';
                          final savedDiscount = db.getLiveTableDiscount(draftKey) ?? db.getLiveTableDiscount(typeKey);
                          if (savedDiscount != null) {
                            _appliedCoupon = savedDiscount['coupon']?.toString() ?? '';
                            _promoCodeController.text = _appliedCoupon;
                            _discountInputValue = (savedDiscount['discountInput'] as num?)?.toDouble() ?? 0.0;
                            _discountMode = savedDiscount['discountMode']?.toString() ?? 'percent';
                            _discountAmount = (savedDiscount['discountAmount'] as num?)?.toDouble() ?? 0.0;
                          } else if (order.discountAmount > 0) {
                            _discountAmount = order.discountAmount;
                          }
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF051C48).withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF051C48) : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.6 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top row: #OrderNumber + Status Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '#${order.orderNumber}',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusText,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Customer Name
                          Text(
                            (order.customerName?.isNotEmpty == true) ? order.customerName! : 'Walk-in Customer',
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Bottom Row: Items count + Table location
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 3),
                              Text(
                                '$itemCount Items',
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.table_restaurant_outlined, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  locationLabel,
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopProductListsCard(List<MenuItemModel> filteredItems, List<String> allCategories, String currency) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row: "Product Lists" + "Add Item" + Search
          Row(
            children: [
              const Text(
                'Product Lists',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              // Input manually / Custom Item Button
              ElevatedButton.icon(
                onPressed: _showInputManuallyDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF051C48).withValues(alpha: 0.08),
                  foregroundColor: const Color(0xFF051C48),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFF051C48), width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 15, color: Color(0xFF051C48)),
                label: const Text(
                  'Input manually',
                  style: TextStyle(color: Color(0xFF051C48), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),

              // Search Box
              Container(
                width: 240,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(
                    hintText: 'Search for food',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 17),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Categories Filter Row
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: allCategories.length,
              itemBuilder: (context, index) {
                final cat = allCategories[index];
                final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategory = cat),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF051C48) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // Product Grid
          Expanded(
            child: _buildProductGrid(filteredItems, isDesktop: true, currency: currency),
          ),
        ],
      ),
    );
  }

  void _openTablesSelectionDialog([StateSetter? setStateCart]) {
    if (widget.onOpenTablesTab != null) {
      widget.onOpenTablesTab!();
      return;
    }
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: const Color(0xFFF8FAFC),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 780),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF051C48),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.table_restaurant_rounded, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Dining Tables Layout',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.5),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(dialogCtx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TableManagementScreen(
                    onTakeOrder: (tableName) {
                      if (_selectedTable != tableName) {
                        _loadCartForTable(tableName);
                      }
                      setState(() {
                        _selectedTable = tableName;
                        _selectedOrderType = OrderType.dineIn;
                      });
                      if (setStateCart != null) {
                        setStateCart(() {
                          _selectedTable = tableName;
                          _selectedOrderType = OrderType.dineIn;
                        });
                      }
                      Navigator.pop(dialogCtx);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) => setState(() {}));
  }

  Widget _buildTopActionBar({bool isDesktop = false}) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: isDesktop
          ? null
          : (details) {
              if (details.primaryDelta != null) {
                if (details.primaryDelta! < -4) {
                  widget.onFullScreenChanged?.call(true);
                } else if (details.primaryDelta! > 4) {
                  widget.onFullScreenChanged?.call(false);
                }
              }
            },
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, isDesktop ? 10 : 4, 16, 8),
        child: Row(
          children: [
            if (widget.onOpenDrawer != null && isDesktop) ...[
              IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF051C48), size: 24),
                onPressed: widget.onOpenDrawer,
                tooltip: 'Menu',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 6),
            ],
            const Text(
              'POS',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: 0.5,
              ),
            ),
            if (_selectedTable != null && _selectedTable!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF051C48).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF051C48).withOpacity(0.3)),
                ),
                child: Text(
                  _selectedTable!,
                  style: const TextStyle(
                    color: Color(0xFF051C48),
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
            const Spacer(),
            // TABLES BUTTON
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: () => _openTablesSelectionDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF051C48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  elevation: 2,
                ),
                child: const Text('Tables', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ),
            const SizedBox(width: 8),
            // ADD ITEM BUTTON
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: _showAddItemDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF051C48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  elevation: 2,
                ),
                child: const Text('Add Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndCategoriesBar(List<String> allCategories, {bool isDesktop = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: TextField(
              scrollPadding: const EdgeInsets.only(bottom: 90),
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Search products by name or category...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF051C48), size: 22),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: Color(0xFF051C48), width: 2),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Categories Row
        SizedBox(
          height: 42,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: allCategories.length,
            itemBuilder: (context, index) {
              final cat = allCategories[index];
              final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: const Color(0xFF051C48),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF051C48) : const Color(0xFFCBD5E1),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(MenuItemModel item, {required bool showImages, required String currency, bool isDesktop = false}) {
    final qty = _getItemCartQuantity(item);
    final isSelected = qty > 0;
    final hasVariants = item.variants.isNotEmpty;

    // Check regular item discount
    final bool itemHasDisc = !hasVariants &&
        (item.hasDiscount || item.discountPercent > 0 || (item.salePrice != null && item.salePrice! > 0 && item.salePrice! < item.price));
    final double itemDiscPct = item.discountPercent > 0
        ? item.discountPercent
        : (item.price > 0 && item.salePrice != null && item.salePrice! < item.price
            ? ((item.price - item.salePrice!) / item.price * 100)
            : 0.0);

    // Check variant discount
    final bool variantHasDisc = hasVariants &&
        item.variants.any((v) => v.hasDiscount || v.discountPercent > 0 || (v.salePrice != null && v.salePrice! > 0 && v.salePrice! < v.price));

    // Determine starting variant
    final firstVariant = hasVariants ? item.variants.first : null;
    final double varDiscPct = (firstVariant != null)
        ? (firstVariant.discountPercent > 0
            ? firstVariant.discountPercent
            : (firstVariant.price > 0 && firstVariant.salePrice != null && firstVariant.salePrice! < firstVariant.price
                ? ((firstVariant.price - firstVariant.salePrice!) / firstVariant.price * 100)
                : 0.0))
        : 0.0;

    final isDiscounted = itemHasDisc || variantHasDisc;
    final double displaySalePrice = hasVariants ? (firstVariant?.effectivePrice ?? 0.0) : item.effectivePrice;
    final double displayOriginalPrice = hasVariants ? (firstVariant?.price ?? 0.0) : item.price;
    final double displayDiscountPct = hasVariants ? varDiscPct : itemDiscPct;

    void handleItemTap() {
      if (item.variants.isNotEmpty) {
        _showVariantsSelectionDialog(item);
      } else {
        _addToCart(item);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? const Color(0xFF051C48) : const Color(0xFFE2E8F0),
          width: isSelected ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected ? const Color(0x1F051C48) : const Color(0x08000000),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isDesktop ? handleItemTap : null,
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 6 : 7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Clickable Upper Card
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: !isDesktop ? handleItemTap : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showImages) ...[
                          // Image fills upper space
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: _buildPosProductImage(item),
                                  ),
                                ),
                                // FoodType Badge (Top Right)
                                Positioned(
                                  top: 3,
                                  right: 3,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(5),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: _buildFoodTypeIcon(item.itemType),
                                  ),
                                ),
                                // In-Cart Qty Badge (Desktop), Variants Badge or Discount Ribbon (Top Left)
                                if (qty > 0 && isDesktop)
                                  Positioned(
                                    top: 3,
                                    left: 3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF051C48),
                                        borderRadius: BorderRadius.circular(5),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 3,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 9),
                                          const SizedBox(width: 2),
                                          Text(
                                            '$qty',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else if (hasVariants)
                                  Positioned(
                                    top: 3,
                                    left: 3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF051C48).withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${item.variants.length} Var',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  )
                                else if (isDiscounted && displayDiscountPct > 0)
                                  Positioned(
                                    top: 3,
                                    left: 3,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${displayDiscountPct.toStringAsFixed(0)}% OFF',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                        ] else ...[
                          // Non-image top row
                          Row(
                            children: [
                              _buildFoodTypeIcon(item.itemType),
                              const Spacer(),
                              if (qty > 0 && isDesktop)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF051C48),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${qty}x in cart',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                              else if (hasVariants)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF051C48).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${item.variants.length} Var',
                                    style: const TextStyle(
                                      color: Color(0xFF051C48),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                )
                              else if (isDiscounted && displayDiscountPct > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${displayDiscountPct.toStringAsFixed(0)}% OFF',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                        ],

                        // Product Name
                        Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isDesktop ? 11.5 : 12.5,
                            color: const Color(0xFF0F172A),
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 2),

                        // Price Section & Category Tag
                        Row(
                          children: [
                            if (isDiscounted) ...[
                              Text(
                                '$currency${displaySalePrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: const Color(0xFF051C48),
                                  fontWeight: FontWeight.w900,
                                  fontSize: isDesktop ? 11.5 : 12.5,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$currency${displayOriginalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 9.5,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ] else ...[
                              Text(
                                '$currency${(hasVariants ? (firstVariant?.price ?? 0.0) : item.price).toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: const Color(0xFF051C48),
                                  fontWeight: FontWeight.w900,
                                  fontSize: isDesktop ? 11.5 : 12.5,
                                ),
                              ),
                            ],
                            if (isDesktop && item.category.isNotEmpty) ...[
                              const Spacer(),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Text(
                                    item.category,
                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 9.0, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Add / Stepper Button Row (Mobile Only)
                if (!isDesktop) ...[
                  const SizedBox(height: 4),
                  if (item.variants.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: ElevatedButton(
                        onPressed: () => _showVariantsSelectionDialog(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF051C48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: EdgeInsets.zero,
                          elevation: 0,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            qty > 0 ? '$qty Added' : 'Add',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ),
                    )
                  else if (qty > 0)
                    SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: _buildPillQuantityStepper(
                        quantity: qty,
                        onDecrement: () => _decrementCartItem(item),
                        onIncrement: () => _addToCart(item),
                        width: double.infinity,
                        height: 28,
                        buttonSize: 24,
                        iconSize: 15,
                        fontSize: 14,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: ElevatedButton(
                        onPressed: () => _addToCart(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF051C48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: EdgeInsets.zero,
                          elevation: 0,
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid(List<MenuItemModel> filteredItems, {bool isDesktop = false, required String currency}) {
    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_menu_rounded, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text(
              'No products found in this category',
              style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _showAddItemDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Your First Item'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF051C48)),
            ),
          ],
        ),
      );
    }

    final bool showImages = (db.restaurant?.posViewMode ?? 'with_image') != 'without_image' &&
        (db.restaurant?.showItemImages ?? true);

    return LayoutBuilder(
      builder: (context, constraints) {
        final int columnCount = isDesktop
            ? ResponsiveLayoutHelper.getPosGridColumnCount(constraints.maxWidth, showImages: showImages)
            : 3;
        final double aspectRatio = isDesktop
            ? ResponsiveLayoutHelper.getPosChildAspectRatio(constraints.maxWidth, showImages)
            : (showImages ? 0.60 : 0.82);

        return GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(4, 4, 4, isDesktop ? 10 : 90),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: aspectRatio,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            return RepaintBoundary(
              child: _buildProductCard(filteredItems[index], showImages: showImages, currency: currency, isDesktop: isDesktop),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = db.restaurant?.currencySymbol ?? '₹';

    // Deduplicate in-memory items safely for display & fast O(N) category lookup
    final seenProductNames = <String>{};
    final uniqueItems = <MenuItemModel>[];
    final activeCategoriesSet = <String>{};

    for (final item in db.menuItems) {
      final key = item.name.trim().toLowerCase();
      if (key.isNotEmpty && !seenProductNames.contains(key)) {
        seenProductNames.add(key);
        uniqueItems.add(item);
        final cat = item.category.trim();
        if (cat.isNotEmpty) {
          activeCategoriesSet.add(cat.toLowerCase());
        }
      }
    }

    // Only display categories that have products assigned to them
    final categoriesWithProducts = <String>[];
    for (final cat in db.categories) {
      final catTrim = cat.trim();
      if (catTrim.isNotEmpty && activeCategoriesSet.contains(catTrim.toLowerCase()) && !categoriesWithProducts.contains(catTrim)) {
        categoriesWithProducts.add(catTrim);
      }
    }

    // Include any categories directly present in uniqueItems
    for (final item in uniqueItems) {
      final catTrim = item.category.trim();
      if (catTrim.isNotEmpty && !categoriesWithProducts.any((c) => c.toLowerCase() == catTrim.toLowerCase())) {
        categoriesWithProducts.add(catTrim);
      }
    }

    final allCategories = ['All', ...categoriesWithProducts];

    // Ensure selected category is valid
    if (_selectedCategory != 'All' && !allCategories.any((c) => c.toLowerCase() == _selectedCategory.toLowerCase())) {
      _selectedCategory = 'All';
    }

    final filteredItems = uniqueItems.where((item) {
      final matchesCat = _selectedCategory == 'All' || item.category.toLowerCase() == _selectedCategory.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty || item.name.toLowerCase().contains(_searchQuery.toLowerCase()) || item.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    final bool isDesktop = ResponsiveLayoutHelper.isWindowsDesktop(context);

    if (isDesktop) {
      // DESKTOP WIDESCREEN 3-PANEL CURVED LAYOUT (Windows Executable Matching Reference UI)
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left & Middle Column (Order queues + Product lists)
              Expanded(
                child: Column(
                  children: [
                    // 1) "Order queues" Card
                    _buildDesktopOrderQueuesCard(),

                    const SizedBox(height: 12),

                    // 2) "Product Lists" Card
                    Expanded(
                      child: _buildDesktopProductListsCard(filteredItems, allCategories, currency),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Right Persistent "Cart Details" / Billing Panel
              Container(
                width: 410,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 12,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: _buildCartPanelContent(
                    setStateCart: (fn) => setState(fn),
                    isDesktopPanel: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ANDROID / MOBILE TOUCH LAYOUT (Strictly untouched & preserved)
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Column(
            children: [
              // TOP ADJUSTER PILL (SLIDE UP TO HIDE HEADER & ENTER FULLSCREEN / SLIDE DOWN TO RESTORE)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  if (details.primaryDelta != null) {
                    if (details.primaryDelta! < -3) {
                      widget.onFullScreenChanged?.call(true);
                    } else if (details.primaryDelta! > 3) {
                      widget.onFullScreenChanged?.call(false);
                    }
                  }
                },
                onTap: () {
                  widget.onToggleFullScreen?.call();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  color: Colors.transparent,
                  alignment: Alignment.center,
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: widget.isFullScreen ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              // 1) TOP ACTION BAR: "Tables" Button & Modified "Add Item" Button
              _buildTopActionBar(isDesktop: false),

              // 2) MODIFIED SEARCH BAR & CATEGORIES ROW
              _buildSearchAndCategoriesBar(allCategories, isDesktop: false),

              const SizedBox(height: 10),

              // 3) HIGHLIGHTED PRODUCT BOXES
              Expanded(
                child: _buildProductGrid(filteredItems, isDesktop: false, currency: currency),
              ),
            ],
          ),

          // 4) VIEW CART FLOATING BUTTON & BAR (Mobile only)
          if (_cartItems.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 300),
                offset: Offset.zero,
                child: InkWell(
                  onTap: _openCartScreenModal,
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF051C48),
                          Color(0xFF0A2B66),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x330052FF),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$totalCartItemCount ${totalCartItemCount == 1 ? "Item" : "Items"} Added',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                            ),
                            Text(
                              'Total: $currency ${cartTotal.toStringAsFixed(2)}',
                              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Text(
                          'View Cart',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
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

/// Redesigned Add Name & Number Dialog with Indian Flag prefix and 2-3 digit auto-suggestions
class _CustomerDetailsDialog extends StatefulWidget {
  final String initialName;
  final String initialPhone;
  final Function(String name, String phone, [String? address]) onSave;

  const _CustomerDetailsDialog({
    required this.initialName,
    required this.initialPhone,
    required this.onSave,
  });

  @override
  State<_CustomerDetailsDialog> createState() => _CustomerDetailsDialogState();
}

class _CustomerDetailsDialogState extends State<_CustomerDetailsDialog> {
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _nameCtrl;
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();

  final DatabaseService _db = DatabaseService();
  List<CustomerModel> _suggestions = [];
  bool _isSearchingRemote = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
    _nameCtrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _phoneFocusNode.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    final query = value.trim();
    if (_errorMsg != null) {
      setState(() => _errorMsg = null);
    }

    if (query.length >= 2) {
      // 1. Instant local search from DatabaseService
      final localMatches = _db.searchCustomers(query);
      setState(() {
        _suggestions = localMatches;
      });

      // If user typed 10 digits and matches known customer, auto-fill name if empty
      final cleanDigits = query.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.length >= 10 && _nameCtrl.text.trim().isEmpty) {
        final match = _db.getCustomerByPhone(cleanDigits);
        if (match != null && match.name.isNotEmpty) {
          _nameCtrl.text = match.name;
        }
      }

      // 2. Fetch fresh suggestions from server in background
      _fetchRemoteSuggestions(query);
    } else {
      if (_suggestions.isNotEmpty) {
        setState(() {
          _suggestions = [];
          _isSearchingRemote = false;
        });
      }
    }
  }

  Future<void> _fetchRemoteSuggestions(String query) async {
    _isSearchingRemote = true;
    try {
      final remoteList = await _db.customerService.fetchSuggestions(query);
      if (mounted && _phoneCtrl.text.trim() == query) {
        final Map<String, CustomerModel> map = {
          for (var c in _suggestions) c.phone.trim(): c,
        };
        for (var rc in remoteList) {
          map[rc.phone.trim()] = rc;
        }
        setState(() {
          _suggestions = map.values.take(10).toList();
          _isSearchingRemote = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearchingRemote = false);
      }
    }
  }

  void _selectSuggestion(CustomerModel customer) {
    setState(() {
      _phoneCtrl.text = customer.phone;
      _nameCtrl.text = customer.name;
      _suggestions = [];
    });
    widget.onSave(customer.name, customer.phone, customer.address);
    Navigator.pop(context);
  }

  void _submit() {
    final phone = _phoneCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    if (phone.isEmpty && name.isEmpty) {
      widget.onSave('', '', '');
      Navigator.pop(context);
      return;
    }

    if (phone.isNotEmpty && phone.replaceAll(RegExp(r'[^0-9]'), '').length < 3) {
      setState(() => _errorMsg = 'Please enter a valid phone number');
      return;
    }

    final match = _db.getCustomerByPhone(phone);
    final finalAddress = match?.address;
    final finalName = name;
    _db.saveCustomer(name: finalName, phone: phone);
    widget.onSave(finalName, phone, finalAddress);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = math.min(screenWidth * 0.94, 560.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxWidth: 560, minWidth: 320),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with App Theme Badge (Close/X removed, barrierDismissible enabled)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF051C48).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Color(0xFF051C48),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Customer Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 18),

                // Mobile Number* Label
                const Text(
                  'Mobile Number*',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),

                // Mobile Number Input Field with Indian Flag
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _phoneCtrl,
                    focusNode: _phoneFocusNode,
                    scrollPadding: const EdgeInsets.only(bottom: 90),
                    keyboardType: TextInputType.phone,
                    cursorColor: const Color(0xFF051C48),
                    onChanged: _onPhoneChanged,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter Mobile Number',
                      hintStyle: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      prefixIcon: Container(
                        padding: const EdgeInsets.only(left: 14, right: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '🇮🇳',
                              style: TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 1,
                              height: 22,
                              color: const Color(0xFFCBD5E1),
                            ),
                          ],
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      suffixIcon: _isSearchingRemote
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF051C48),
                                ),
                              ),
                            )
                          : (_phoneCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                                  onPressed: () {
                                    _phoneCtrl.clear();
                                    _onPhoneChanged('');
                                  },
                                )
                              : null),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF051C48), width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),

                // Auto-Suggestions List (when user types 2-3 starting numbers)
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 190),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF051C48).withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (ctx, idx) {
                          final cust = _suggestions[idx];
                          return InkWell(
                            onTap: () => _selectSuggestion(cust),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF051C48).withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person_rounded,
                                      size: 16,
                                      color: Color(0xFF051C48),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cust.phone,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (cust.name.isNotEmpty)
                                          Text(
                                            cust.name,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF051C48).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.touch_app_rounded, size: 12, color: Color(0xFF051C48)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Select',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF051C48),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                if (_errorMsg != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _errorMsg!,
                    style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],

                const SizedBox(height: 18),

                // Name Label (Optional)
                const Text(
                  'Name',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),

                // Name Input Field
                TextField(
                  controller: _nameCtrl,
                  focusNode: _nameFocusNode,
                  scrollPadding: const EdgeInsets.only(bottom: 90),
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  cursorColor: const Color(0xFF051C48),
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter Name (Optional)',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF051C48), size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF051C48), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Save Button (Full Width, Single Primary Action)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF051C48).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF051C48),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Save Customer',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
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

