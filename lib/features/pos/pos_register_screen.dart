import 'dart:async';
import 'dart:io';
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
import '../../core/models/loyalty_program_model.dart';
import '../../core/services/loyalty_service.dart';
import '../loyalty/widgets/loyalty_redemption_dialog.dart';

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
      if (mounted) {
        setState(() {
          _isLoyaltyActive = config.isActive && config.status != 'inactive' && config.status != 'draft';
        });
      }
    } catch (_) {}
  }

  Future<void> _checkCustomerLoyalty() async {
    if (_customerPhone.trim().isEmpty) {
      if (mounted) setState(() => _currentCustomerLoyalty = null);
      return;
    }
    try {
      final loyalty = await _loyaltyService.getCustomerLoyalty(
        _customerPhone.trim(),
        name: _customerName,
      );
      if (mounted) {
        setState(() {
          _currentCustomerLoyalty = loyalty;
          if (loyalty != null) {
            _isLoyaltyActive = loyalty.isProgramActive;
          }
        });
      }
    } catch (_) {}
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
    setState(() {
      _selectedTable = tableName;
      _selectedOrderType = OrderType.dineIn;
      _cartItems.clear();
      _discountAmount = 0.0;
      _activeRunningOrderId = null;
      _activeRunningOrderNumber = null;
      _customerName = '';
      _customerPhone = '';

      final activeOrder = db.orders.where((o) =>
        isSameTable(o.tableNumber, tableName) &&
        (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
      ).firstOrNull;

      if (activeOrder != null && activeOrder.items.isNotEmpty) {
        _cartItems.addAll(activeOrder.items);
        _discountAmount = activeOrder.discountAmount;
        _activeRunningOrderId = activeOrder.id;
        _activeRunningOrderNumber = activeOrder.orderNumber;
        _customerName = activeOrder.customerName ?? '';
        _customerPhone = activeOrder.customerPhone ?? '';
      } else {
        final tbl = db.tables.where((t) => isSameTable(t.name, tableName)).firstOrNull;
        if (tbl != null && tbl.status != TableStatus.free) {
          final savedCart = db.getLiveTableCart(tableName);
          if (savedCart.isNotEmpty) {
            _cartItems.addAll(savedCart);
          }
        }
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

    // If order is already active Running KOT, show KotDialog directly
    if (activeOrder != null && _cartItems.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => KotDialog(
          order: activeOrder,
          onPrintKot: () {
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
      items: List.from(_cartItems),
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

    // OPEN KOT POPUP (Table status changes to Running KOT ONLY when Print KOT is clicked)
    showDialog(
      context: context,
      builder: (_) => KotDialog(
        order: tempOrder,
        onPrintKot: () async {
          // WHEN USER CLICKS PRINT KOT IN POPUP:
          // If active order already exists, update in-place with status: preparing. Else create new order.
          OrderModel newOrder;
          if (_activeRunningOrderId != null || activeOrder != null) {
            final orderIdToUpdate = _activeRunningOrderId ?? activeOrder?.id;
            final orderNumToUpdate = _activeRunningOrderNumber ?? activeOrder?.orderNumber;

            newOrder = await db.saveAndPrintOrder(
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
              existingOrderId: orderIdToUpdate,
              existingOrderNumber: orderNumToUpdate,
              customerName: _customerName,
              customerPhone: _customerPhone,
            );
            db.updateOrderStatus(newOrder.id, OrderStatus.preparing);
          } else {
            newOrder = await db.createOrder(
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
          } else if (tbl.status == TableStatus.runningKot) {
            // Maintain runningKot (RED) state for active KOT
          } else if (_cartItems.isNotEmpty && tbl.status == TableStatus.free) {
            db.updateTableStatus(tbl.id, TableStatus.occupied);
          } else if (_cartItems.isEmpty && tbl.status == TableStatus.occupied) {
            db.updateTableStatus(tbl.id, TableStatus.free);
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
                        emoji: item.emoji,
                        itemType: item.itemType,
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
    defaultTaxRate: db.restaurant?.taxRate ?? 5.0,
    appliedCoupon: _appliedCoupon,
    discountInputValue: _discountInputValue,
    discountMode: _discountMode,
    selectedDiscountProductType: _selectedDiscountProductType,
    manualDiscountOverride: _discountAmount,
    tipAmount: _tipAmount,
    deliveryCharge: 0.0,
  );

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
    String imagePath = item.imageUrl.trim();
    if (imagePath.isEmpty && item.images.isNotEmpty) {
      imagePath = item.images.first.trim();
    }

    final String fallbackEmoji = item.emoji.trim().isNotEmpty ? item.emoji.trim() : '🥘';

    if (imagePath.isNotEmpty) {
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        return Image.network(
          imagePath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => Center(child: Text(fallbackEmoji, style: const TextStyle(fontSize: 24))),
        );
      } else {
        final file = File(imagePath);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => Center(child: Text(fallbackEmoji, style: const TextStyle(fontSize: 24))),
          );
        }
      }
    }
    return Center(child: Text(fallbackEmoji, style: const TextStyle(fontSize: 24)));
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

  void _clearCart() {
    setState(() {
      _cartItems.clear();
      _discountAmount = 0.0;
      _activeRunningOrderId = null;
      _activeRunningOrderNumber = null;
      _customerName = '';
      _customerPhone = '';
      _deliveryAddress = '';
      _deliveryLandmark = '';
      _deliveryCity = '';
      _deliveryState = '';
      _deliveryPincode = '';

      if (_selectedTable != null && _selectedTable!.isNotEmpty && _selectedOrderType == OrderType.dineIn) {
        final targetTable = _selectedTable!;

        // 1. Delete active preparing/pending order from db.orders (removes it from 'Preparing' in My Orders)
        db.orders.removeWhere((o) =>
          ((o.tableNumber?.trim().toLowerCase() ?? '') == targetTable.trim().toLowerCase() ||
           'T-${o.tableNumber}'.toLowerCase() == targetTable.trim().toLowerCase()) &&
          (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
        );

        // 2. Reset live cart items and total amount to 0
        db.setLiveTableCart(targetTable, []);
        db.setLiveCartTotal(targetTable, 0);

        // 3. Free table status
        final tbl = db.tables.where((t) =>
          t.name.trim().toLowerCase() == targetTable.trim().toLowerCase() ||
          t.tableNumber.toString() == targetTable ||
          'T-${t.tableNumber}'.toLowerCase() == targetTable.trim().toLowerCase()
        ).firstOrNull;

        if (tbl != null) {
          db.updateTableStatus(tbl.id, TableStatus.free);
        }
      }
    });
  }

  void _checkAndCloseEmptyCart(BuildContext modalContext, [StateSetter? setStateModal]) {
    if (_cartItems.isEmpty) {
      if (_selectedTable != null && _selectedTable!.isNotEmpty) {
        final targetTable = _selectedTable!;

        db.setLiveTableCart(targetTable, []);
        db.setLiveCartTotal(targetTable, 0);

        final tbl = db.tables.where((t) =>
          t.name.trim().toLowerCase() == targetTable.trim().toLowerCase() ||
          t.tableNumber.toString() == targetTable ||
          'T-${t.tableNumber}'.toLowerCase() == targetTable.trim().toLowerCase()
        ).firstOrNull;

        if (tbl != null) {
          db.updateTableStatus(tbl.id, TableStatus.free);
        }

        db.orders.removeWhere((o) =>
          ((o.tableNumber?.trim().toLowerCase() ?? '') == targetTable.trim().toLowerCase() ||
           'T-${o.tableNumber}'.toLowerCase() == targetTable.trim().toLowerCase()) &&
          (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
        );
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

  void _switchTable(String newTableName, StateSetter setStateModal) {
    final oldTable = _selectedTable;

    if (oldTable != null && oldTable.isNotEmpty && oldTable.trim().toLowerCase() != newTableName.trim().toLowerCase()) {
      final oldActiveOrder = db.orders.where((o) =>
        ((o.tableNumber?.trim().toLowerCase() ?? '') == oldTable.trim().toLowerCase() ||
         'T-${o.tableNumber}'.toLowerCase() == oldTable.trim().toLowerCase()) &&
        (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
      ).firstOrNull;

      if (oldActiveOrder == null && _cartItems.isNotEmpty) {
        db.setLiveTableCart(oldTable, List.from(_cartItems));
        db.setLiveCartTotal(oldTable, cartTotal);
        final oldTbl = db.tables.where((t) => isSameTable(t.name, oldTable)).firstOrNull;
        if (oldTbl != null && oldTbl.status == TableStatus.free) {
          db.updateTableStatus(oldTbl.id, TableStatus.occupied);
        }
      }
    }

    _loadCartForTable(newTableName);
    setStateModal(() {});
    setState(() {});
  }

  void _showChangeTableFloorWiseModal(StateSetter setStateModal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String activeFloorTab = 'All';

        return StatefulBuilder(
          builder: (context, setFloorState) {
            final floors = ['All', ...db.tables.map((t) => t.floor).toSet()];
            final filteredTables = activeFloorTab == 'All'
                ? db.tables
                : db.tables.where((t) => t.floor == activeFloorTab).toList();

            final Map<String, List<TableModel>> tablesByFloor = {};
            for (var t in filteredTables) {
              tablesByFloor.putIfAbsent(t.floor, () => []).add(t);
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
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 25, offset: Offset(0, -8)),
                ],
              ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.table_restaurant_rounded, color: Color(0xFF051C48)),
                        const SizedBox(width: 8),
                        const Text(
                          'Select Table (Floor-Wise)',
                          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(context),
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

                  // Floor-wise Table Grid View (Seat text removed, amount displayed as plain text without button)
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
                                    _switchTable(table.name, setStateModal);
                                    Navigator.pop(context);
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

                                        // Middle Table Icon & Title (Flexible / Expanded)
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
                                    _discountMode = tempDiscountMode;
                                    _discountInputValue = discountVal;
                                    _tipAmount = tipVal;
                                    _discountAmount = 0.0; // reset manual override so getter calculates
                                  });

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

  void _openCartScreenModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final currency = db.restaurant?.currencySymbol ?? '₹';

            return Container(
              height: MediaQuery.of(context).size.height * 0.80, // Cart screen slid down slightly for comfortable top spacing
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, -10)),
                ],
              ),
              child: Column(
                children: [
                  // Handle Bar
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(top: 12, bottom: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  // Top Navigation Header
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

                        // Icon Box based on Order Type
                        Container(
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
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_selectedOrderType == OrderType.dineIn) ...[
                                Text(
                                  _getFullTableTitle(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                // CHANGE TABLE BUTTON WITH BORDER
                                InkWell(
                                  onTap: () => _showChangeTableFloorWiseModal(setStateModal),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF00A896), width: 1.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Text(
                                          'Change Table',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF00A896),
                                          ),
                                        ),
                                        SizedBox(width: 2),
                                        Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF00A896)),
                                      ],
                                    ),
                                  ),
                                ),
                              ] else if (_selectedOrderType == OrderType.takeaway) ...[
                                const Text(
                                  'Takeaway Order',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Pickup at Counter',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ] else ...[
                                // Delivery
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _hasDeliveryAddress
                                            ? (_deliveryLandmark.isNotEmpty
                                                ? '$_deliveryAddress (Near $_deliveryLandmark)'
                                                : _deliveryAddress)
                                            : 'Delivery Order',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                InkWell(
                                  onTap: () => _showDeliveryAddressDialog(setStateModal),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _hasDeliveryAddress ? const Color(0xFF00A896) : const Color(0xFF051C48),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _hasDeliveryAddress ? Icons.edit_location_alt_rounded : Icons.add_location_alt_rounded,
                                          size: 13,
                                          color: _hasDeliveryAddress ? const Color(0xFF00A896) : const Color(0xFF051C48),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          _hasDeliveryAddress ? 'Edit Address' : 'Add Address',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _hasDeliveryAddress ? const Color(0xFF00A896) : const Color(0xFF051C48),
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 14,
                                          color: _hasDeliveryAddress ? const Color(0xFF00A896) : const Color(0xFF051C48),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Order Type Dropdown (Curved Corners Box & Curved Popup Menu)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF051C48), width: 1.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<OrderType>(
                              value: _selectedOrderType,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              isDense: true,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF051C48), size: 20),
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
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF051C48),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  if (val != _selectedOrderType) {
                                    if (val == OrderType.takeaway) {
                                      _selectedTable = null;
                                    } else if (val == OrderType.delivery) {
                                      _selectedTable = null;
                                      if (_customerPhone.isNotEmpty && !_hasDeliveryAddress) {
                                        final cust = db.getCustomerByPhone(_customerPhone);
                                        if (cust != null && cust.address.isNotEmpty) {
                                          _setDeliveryAddressFromCustomer(cust.address);
                                        }
                                      }
                                    } else if (val == OrderType.dineIn) {
                                      if (_selectedTable == null || _selectedTable!.isEmpty) {
                                        final nextTable = db.getNextAvailableTableSequence();
                                        _selectedTable = nextTable?.name ?? 'T-1';
                                      }
                                    }
                                  }
                                  setStateModal(() {
                                    _selectedOrderType = val;
                                  });
                                  setState(() {
                                    _selectedOrderType = val;
                                  });
                                  if (val == OrderType.delivery && !_hasDeliveryAddress) {
                                    _showDeliveryAddressDialog(setStateModal);
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Items Header with Clear Cart Button
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
                            onTap: () {
                              _clearCart();
                              _checkAndCloseEmptyCart(context, setStateModal);
                            },
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
                  ),

                  // Cart Item Cards List (Compact Box: Description & QTY label removed)
                  Expanded(
                    child: _cartItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.shopping_cart_outlined, size: 56, color: Color(0xFFCBD5E1)),
                                SizedBox(height: 10),
                                Text(
                                  'Your cart is empty',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            itemCount: _cartItems.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final cItem = _cartItems[idx];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Item Title & Price
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              FoodTypeIcon(itemType: cItem.item.itemType, size: 11),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  cItem.item.name,
                                                  style: const TextStyle(
                                                    fontSize: 14.0,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          if (cItem.item.hasDiscount && cItem.item.discountPercent > 0)
                                            Row(
                                              children: [
                                                Text(
                                                  '$currency${cItem.item.effectivePrice.toStringAsFixed(1)}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFF051C48),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '$currency${cItem.item.price.toStringAsFixed(1)}',
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF64748B),
                                                    decoration: TextDecoration.lineThrough,
                                                    decorationThickness: 2.0,
                                                    decorationColor: Color(0xFF64748B),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '(${cItem.item.discountPercent.toStringAsFixed(0)}% OFF)',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF10B981),
                                                  ),
                                                ),
                                              ],
                                            )
                                          else
                                            Text(
                                              '$currency${cItem.item.price.toStringAsFixed(1)}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF051C48),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    // Pill Quantity Stepper (- QTY +)
                                    _buildPillQuantityStepper(
                                      quantity: cItem.quantity,
                                      onDecrement: () {
                                        _decrementCartItem(cItem.item);
                                        setStateModal(() {});
                                        setState(() {});
                                        _checkAndCloseEmptyCart(context, setStateModal);
                                      },
                                      onIncrement: () {
                                        _addToCart(cItem.item);
                                        setStateModal(() {});
                                        setState(() {});
                                      },
                                      height: 32,
                                      buttonSize: 26,
                                      fontSize: 14,
                                    ),
                                    const SizedBox(width: 8),

                                    // Trash Delete Button
                                    InkWell(
                                      onTap: () {
                                        _removeCartItem(cItem.item);
                                        setStateModal(() {});
                                        setState(() {});
                                        _checkAndCloseEmptyCart(context, setStateModal);
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Color(0xFFEF4444),
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Add Customer & Extra's Buttons Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _showAddCustomerDialog(setStateModal),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF051C48),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF051C48).withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.account_circle_outlined, color: Colors.white, size: 22),
                                  const SizedBox(width: 6),
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
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (_customerPhone.isNotEmpty)
                                          Text(
                                            _customerPhone,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 10.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (_isLoyaltyActive || _currentCustomerLoyalty?.isProgramActive == true) ...[
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () {
                                        if (_customerPhone.isNotEmpty || _customerName.isNotEmpty) {
                                          _showLoyaltyPopupDialog(setStateModal);
                                        } else {
                                          _showAddCustomerDialog(setStateModal);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: (_customerPhone.isNotEmpty || _customerName.isNotEmpty)
                                              ? const Color(0xFF00A86B)
                                              : Colors.white.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: (_customerPhone.isNotEmpty || _customerName.isNotEmpty)
                                                ? const Color(0xFF5EEAD4)
                                                : Colors.white24,
                                            width: 1.5,
                                          ),
                                          boxShadow: (_customerPhone.isNotEmpty || _customerName.isNotEmpty)
                                              ? const [
                                                  BoxShadow(
                                                    color: Color(0x3300A86B),
                                                    blurRadius: 6,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Center(
                                          child: Text(
                                            'L',
                                            style: TextStyle(
                                              color: (_customerPhone.isNotEmpty || _customerName.isNotEmpty)
                                                  ? Colors.white
                                                  : Colors.white38,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
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
                        const SizedBox(width: 10),

                        Expanded(
                          child: InkWell(
                            onTap: () => _showExtraBenefitDialog(setStateModal),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF051C48), width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF051C48),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.sell_outlined, color: Colors.white, size: 12),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      (computedDiscountAmount > 0 || _tipAmount > 0)
                                          ? 'Extra\'s (₹${(computedDiscountAmount + _tipAmount).toStringAsFixed(0)})'
                                          : 'Extra\'s',
                                      style: const TextStyle(
                                        color: Color(0xFF051C48),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
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

                  // Price Summary Card with GST TAX Amount Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Price (${_cartItems.fold<int>(0, (sum, i) => sum + i.quantity)} Items)',
                                style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
                              ),
                              Text(
                                '$currency${cartSubtotal.toStringAsFixed(1)}',
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          if (computedDiscountAmount > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _appliedCoupon.isNotEmpty ? 'Discount (${_appliedCoupon.toUpperCase()}):' : 'Discount:',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '- $currency${computedDiscountAmount.toStringAsFixed(1)}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                ),
                              ],
                            ),
                          ],
                          if (_tipAmount > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tip:', style: TextStyle(fontSize: 13, color: Color(0xFF00A896), fontWeight: FontWeight.bold)),
                                Text(
                                  '+ $currency${_tipAmount.toStringAsFixed(1)}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF00A896)),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tax (GST ${db.restaurant?.taxRate ?? 5.0}%):',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                              ),
                              Text(
                                '+ $currency${cartTax.toStringAsFixed(1)}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Divider(color: Color(0xFFE2E8F0), height: 1),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Pay',
                                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                              ),
                              Text(
                                '$currency${cartTotal.toStringAsFixed(1)}',
                                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFFEF4444)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Buttons: KOT | Save & Print | Settle
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                    child: Row(
                      children: [
                        // 1) KOT Button
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _cartItems.isEmpty
                                  ? null
                                  : () async {
                                      await _sendKotOrder(setStateModal);
                                    },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: _cartItems.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF051C48),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                    fontSize: 14.5,
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
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _cartItems.isEmpty
                                  ? null
                                  : () async {
                                      await _handleSaveAndPrint(setStateModal, context);
                                    },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: _cartItems.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF051C48),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                              ),
                              icon: Icon(
                                Icons.print_outlined,
                                size: 17,
                                color: _cartItems.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF051C48),
                              ),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Save & Print',
                                  style: TextStyle(
                                    color: _cartItems.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF051C48),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 3) Settle Button (Changed from Pay)
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 48,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _cartItems.isEmpty
                                      ? [const Color(0xFF94A3B8), const Color(0xFF64748B)]
                                      : [const Color(0xFF051C48), const Color(0xFF0A2E7A)],
                                ),
                                borderRadius: BorderRadius.circular(16),
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
                                        _checkoutOrder(cartContext: context);
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                ),
                                child: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Settle',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
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

        // Reset cart state immediately
        setState(() {
          _cartItems.clear();
          _discountAmount = 0.0;
          _tipAmount = 0.0;
          _appliedCoupon = '';
          _discountInputValue = 0.0;
          _redeemedLoyaltyStageId = null;
          _redeemedLoyaltyPoints = 0;
          _loyaltyDiscountAmount = 0.0;
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

  @override
  Widget build(BuildContext context) {
    final currency = db.restaurant?.currencySymbol ?? '₹';

    // Deduplicate in-memory items safely for display
    final seenProductNames = <String>{};
    final uniqueItems = <MenuItemModel>[];
    for (final item in db.menuItems) {
      final key = item.name.trim().toLowerCase();
      if (key.isNotEmpty && !seenProductNames.contains(key)) {
        seenProductNames.add(key);
        uniqueItems.add(item);
      }
    }

    // Only display categories that have products assigned to them
    final categoriesWithProducts = db.categories.where((cat) {
      return uniqueItems.any((item) => item.category.trim().toLowerCase() == cat.trim().toLowerCase());
    }).toList();

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
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: (details) {
                  if (details.primaryDelta != null) {
                    if (details.primaryDelta! < -4) {
                      widget.onFullScreenChanged?.call(true);
                    } else if (details.primaryDelta! > 4) {
                      widget.onFullScreenChanged?.call(false);
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
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
                          onPressed: () {
                            if (widget.onOpenTablesTab != null) {
                              widget.onOpenTablesTab!();
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    backgroundColor: const Color(0xFFF8FAFC),
                                    appBar: AppBar(
                                      backgroundColor: const Color(0xFF051C48),
                                      elevation: 0,
                                      leading: IconButton(
                                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                      title: const Text(
                                        'Dining Tables Layout',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                    ),
                                    body: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      child: TableManagementScreen(
                                        onTakeOrder: (tableName) {
                                          if (_selectedTable != tableName) {
                                            _loadCartForTable(tableName);
                                          }
                                          setState(() {
                                            _selectedTable = tableName;
                                            _selectedOrderType = OrderType.dineIn;
                                          });
                                          Navigator.pop(context);
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ).then((_) => setState(() {}));
                            }
                          },
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
              ),

              // 2) MODIFIED SEARCH BAR
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

              // 3) CATEGORIES ROW (THEME COLOR CHOICE CHIPS)
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

              const SizedBox(height: 10),

              // 4) HIGHLIGHTED PRODUCT BOXES (NO CATEGORY NAME, CENTERED IMAGE WITH SEMI-CURVED CORNERS, FOOD TYPE ICON, VARIANTS LABEL)
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
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
                      )
                    : Builder(
                        builder: (context) {
                          final bool showImages = (db.restaurant?.posViewMode ?? 'with_image') != 'without_image' &&
                              (db.restaurant?.showItemImages ?? true);

                          return GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 90),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: showImages ? 0.60 : 0.82,
                            ),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                          final item = filteredItems[index];
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
                          final bool hasItemDiscount = itemHasDisc;
                          final bool hasVariantDiscount = variantHasDisc;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF051C48) : const Color(0xFFCBD5E1),
                                width: isSelected ? 2.0 : 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected ? const Color(0x33051C48) : const Color(0x0F000000),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Clickable Upper Card (Opens variants dialog if variants exist, else adds to cart)
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        if (item.variants.isNotEmpty) {
                                          _showVariantsSelectionDialog(item);
                                        } else {
                                          _addToCart(item);
                                        }
                                      },
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
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withOpacity(0.15),
                                                            blurRadius: 3,
                                                          ),
                                                        ],
                                                      ),
                                                      child: _buildFoodTypeIcon(item.itemType),
                                                    ),
                                                  ),
                                                  // Variants Badge or Discount Ribbon (Top Left)
                                                  if (hasVariants)
                                                    Positioned(
                                                      top: 3,
                                                      left: 3,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF051C48),
                                                          borderRadius: BorderRadius.circular(5),
                                                        ),
                                                        child: Text(
                                                          hasVariantDiscount
                                                              ? '${item.variants.length} Var • ${displayDiscountPct > 0 ? "${displayDiscountPct.toStringAsFixed(0)}% OFF" : "Sale"}'
                                                              : '${item.variants.length} Variants',
                                                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                                                        ),
                                                      ),
                                                    )
                                                  else if (hasItemDiscount)
                                                    Positioned(
                                                      top: 3,
                                                      left: 3,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF10B981),
                                                          borderRadius: BorderRadius.circular(5),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.black.withOpacity(0.15),
                                                              blurRadius: 3,
                                                            ),
                                                          ],
                                                        ),
                                                        child: Text(
                                                          '${item.discountPercent.toStringAsFixed(0)}% OFF',
                                                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                                                       const SizedBox(height: 2),

                                             // Product Name (arranged higher up)
                                             Text(
                                               item.name,
                                               style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.1),
                                               maxLines: 1,
                                               overflow: TextOverflow.ellipsis,
                                               textAlign: TextAlign.center,
                                             ),

                                             const SizedBox(height: 2),

                                             // Price & Discount Hierarchy
                                             if (isDiscounted && displayDiscountPct > 0) ...[
                                               // First: Strike out main price + Second: Discount applied
                                               FittedBox(
                                                 fit: BoxFit.scaleDown,
                                                 child: Row(
                                                   mainAxisAlignment: MainAxisAlignment.center,
                                                   children: [
                                                     Text(
                                                       '$currency ${displayOriginalPrice.toStringAsFixed(0)}',
                                                       style: const TextStyle(
                                                         fontSize: 10,
                                                         fontWeight: FontWeight.w700,
                                                         color: Color(0xFF64748B),
                                                         decoration: TextDecoration.lineThrough,
                                                         decorationThickness: 2.0,
                                                         decorationColor: Color(0xFF64748B),
                                                       ),
                                                     ),
                                                     const SizedBox(width: 4),
                                                     Container(
                                                       padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1),
                                                       decoration: BoxDecoration(
                                                         color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                                         borderRadius: BorderRadius.circular(3),
                                                       ),
                                                       child: Text(
                                                         '${displayDiscountPct.toStringAsFixed(0)}% OFF',
                                                         style: const TextStyle(
                                                           fontSize: 8.5,
                                                           fontWeight: FontWeight.w900,
                                                           color: Color(0xFF10B981),
                                                         ),
                                                       ),
                                                     ),
                                                   ],
                                                 ),
                                               ),
                                               // Last: Sale Price
                                               FittedBox(
                                                 fit: BoxFit.scaleDown,
                                                 child: Text(
                                                   hasVariants
                                                       ? 'From $currency ${displaySalePrice.toStringAsFixed(0)}'
                                                       : '$currency ${displaySalePrice.toStringAsFixed(0)}',
                                                   style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF051C48)),
                                                   textAlign: TextAlign.center,
                                                 ),
                                               ),
                                             ] else ...[
                                               FittedBox(
                                                 fit: BoxFit.scaleDown,
                                                 child: Text(
                                                   hasVariants
                                                       ? 'From $currency ${displaySalePrice.toStringAsFixed(0)}'
                                                       : '$currency ${displaySalePrice.toStringAsFixed(0)}',
                                                   style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF051C48)),
                                                   textAlign: TextAlign.center,
                                                 ),
                                               ),
                                             ],

                                             const SizedBox(height: 2),
                                           ] else ...[
                                             // Compact Text-Only View (Without Image)
                                             Row(
                                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                               children: [
                                                 _buildFoodTypeIcon(item.itemType),
                                                 const SizedBox(width: 4),
                                                 if (hasVariants)
                                                   Flexible(
                                                     child: Container(
                                                       padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                                       decoration: BoxDecoration(
                                                         color: const Color(0xFF051C48),
                                                         borderRadius: BorderRadius.circular(4),
                                                       ),
                                                       child: Text(
                                                         hasVariantDiscount
                                                             ? '${item.variants.length} Var • ${displayDiscountPct.toStringAsFixed(0)}% OFF'
                                                             : '${item.variants.length} Variants',
                                                         style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                                                         maxLines: 1,
                                                         overflow: TextOverflow.ellipsis,
                                                       ),
                                                     ),
                                                   )
                                                 else
                                                   Flexible(
                                                     child: Row(
                                                       mainAxisSize: MainAxisSize.min,
                                                       children: [
                                                         Flexible(
                                                           child: Container(
                                                             padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                                             decoration: BoxDecoration(
                                                               color: const Color(0xFFF1F5F9),
                                                               borderRadius: BorderRadius.circular(4),
                                                             ),
                                                             child: Text(
                                                               item.category,
                                                               style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                                               maxLines: 1,
                                                               overflow: TextOverflow.ellipsis,
                                                             ),
                                                           ),
                                                         ),
                                                         if (hasItemDiscount) ...[
                                                           const SizedBox(width: 3),
                                                           Container(
                                                             padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                                             decoration: BoxDecoration(
                                                               color: const Color(0xFF10B981),
                                                               borderRadius: BorderRadius.circular(3),
                                                             ),
                                                             child: Text(
                                                               '${item.discountPercent.toStringAsFixed(0)}%',
                                                               style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white),
                                                             ),
                                                           ),
                                                         ],
                                                       ],
                                                     ),
                                                   ),
                                               ],
                                             ),
                                             const Spacer(),
                                             // Product Name (arranged higher up)
                                             Text(
                                               item.name,
                                               style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), height: 1.15),
                                               maxLines: 2,
                                               overflow: TextOverflow.ellipsis,
                                             ),
                                             const SizedBox(height: 2),
                                             // Price & Discount Hierarchy in text-only card
                                             if (isDiscounted && displayDiscountPct > 0) ...[
                                               // First: Strike out main price + Second: Discount applied
                                               FittedBox(
                                                 fit: BoxFit.scaleDown,
                                                 alignment: Alignment.centerLeft,
                                                 child: Row(
                                                   children: [
                                                     Text(
                                                       '$currency ${displayOriginalPrice.toStringAsFixed(0)}',
                                                       style: const TextStyle(
                                                         fontSize: 10,
                                                         fontWeight: FontWeight.w700,
                                                         color: Color(0xFF64748B),
                                                         decoration: TextDecoration.lineThrough,
                                                         decorationThickness: 2.0,
                                                         decorationColor: Color(0xFF64748B),
                                                       ),
                                                     ),
                                                     const SizedBox(width: 4),
                                                     Container(
                                                       padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                                       decoration: BoxDecoration(
                                                         color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                                         borderRadius: BorderRadius.circular(3),
                                                       ),
                                                       child: Text(
                                                         '${displayDiscountPct.toStringAsFixed(0)}% OFF',
                                                         style: const TextStyle(
                                                           fontSize: 8.5,
                                                           fontWeight: FontWeight.w900,
                                                           color: Color(0xFF10B981),
                                                         ),
                                                       ),
                                                     ),
                                                   ],
                                                 ),
                                               ),
                                               // Last: Sale Price
                                               Text(
                                                 hasVariants
                                                     ? 'From $currency ${displaySalePrice.toStringAsFixed(0)}'
                                                     : '$currency ${displaySalePrice.toStringAsFixed(0)}',
                                                 style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF051C48)),
                                               ),
                                             ] else ...[
                                               Text(
                                                 hasVariants
                                                     ? 'From $currency ${displaySalePrice.toStringAsFixed(0)}'
                                                     : '$currency ${displaySalePrice.toStringAsFixed(0)}',
                                                 style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF051C48)),
                                               ),
                                             ],
                                             const Spacer(),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Add Button or Pill Quantity Stepper
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
                              ),
                            ),
                          );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),

          // 7) VIEW CART FLOATING BUTTON & BAR
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

