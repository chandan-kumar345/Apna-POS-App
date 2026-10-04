import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
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
import 'widgets/chotu_mic_button.dart';
import '../../core/services/chotu_service.dart';

enum ManualItemPersistenceMode { temporary, permanent }

class PosRegisterScreen extends StatefulWidget {
  final String? initialTable;
  final OrderType? initialOrderType;
  final int? tableSelectionToken;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenTablesTab;
  final bool isFullScreen;
  final VoidCallback? onToggleFullScreen;
  final ValueChanged<bool>? onFullScreenChanged;

  const PosRegisterScreen({
    super.key,
    this.initialTable,
    this.initialOrderType,
    this.tableSelectionToken,
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

  // Concurrency & Debounce Locks to prevent duplicate order generation
  bool _isProcessingCheckout = false;
  bool _isProcessingSaveAndPrint = false;
  bool _isProcessingKot = false;

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

  final ChotuService _chotuService = ChotuService();

  @override
  void initState() {
    super.initState();
    db.addListener(_onDbChange);
    _chotuService.addActionListener(_onChotuCommandReceived);
    _initLoyaltyStatus();
    if (widget.initialOrderType != null && widget.initialOrderType != OrderType.dineIn) {
      _switchOrderType(widget.initialOrderType!);
    } else if (widget.initialTable != null) {
      _loadCartForTable(widget.initialTable!, openCartModal: true);
    }
  }

  @override
  void dispose() {
    _promoCodeController.dispose();
    db.removeListener(_onDbChange);
    _chotuService.removeActionListener(_onChotuCommandReceived);
    super.dispose();
  }

  void _onDbChange() {
    if (mounted) setState(() {});
  }

  void _onChotuCommandReceived(ChotuParsedCommand cmd) {
    if (!mounted) return;

    final targetTable = cmd.tableNumber;
    if (targetTable != null && targetTable.isNotEmpty && !isSameTable(_selectedTable, targetTable)) {
      _loadCartForTable(targetTable);
    }

    switch (cmd.intent) {
      case 'ADD_ITEM':
      case 'REMOVE_ITEM':
      case 'UPDATE_QUANTITY':
        if (_selectedTable != null && _selectedTable!.isNotEmpty) {
          final liveCart = db.getLiveTableCart(_selectedTable!);
          setState(() {
            _cartItems.clear();
            _cartItems.addAll(liveCart.map((i) => i.clone()));
            _syncTableStatusWithCart();
          });
        }
        break;

      case 'SEND_KOT':
        if (_cartItems.isNotEmpty) {
          _sendKotOrder();
        }
        break;

      case 'GENERATE_BILL':
        if (_cartItems.isNotEmpty) {
          _handleSaveAndPrint(null, context);
        }
        break;

      case 'CLEAR_CART':
        setState(() {
          _cartItems.clear();
          _resetDiscountAndPromoState();
          _syncTableStatusWithCart();
        });
        break;

      case 'APPLY_DISCOUNT':
        setState(() {
          if (cmd.isRemoveDiscount || (cmd.discountValue != null && cmd.discountValue == 0)) {
            _resetDiscountAndPromoState();
          } else if (cmd.discountValue != null) {
            _discountInputValue = cmd.discountValue!;
            _discountMode = cmd.discountType ?? 'percent';
            _discountAmount = 0.0;
          }
          _saveCurrentDraft();
        });
        break;

      case 'SWITCH_TABLE':
        if (cmd.tableNumber != null && cmd.tableNumber!.isNotEmpty) {
          _loadCartForTable(cmd.tableNumber!);
        }
        break;

      case 'SET_CUSTOMER_DETAILS':
        setState(() {
          if (cmd.customerName != null && cmd.customerName!.isNotEmpty) {
            _customerName = cmd.customerName!;
          }
          if (cmd.customerPhone != null && cmd.customerPhone!.isNotEmpty) {
            _customerPhone = cmd.customerPhone!;
          }
        });
        _checkCustomerLoyalty();
        break;

      case 'SET_ORDER_TYPE':
        if (cmd.orderType != null) {
          setState(() {
            if (cmd.orderType == 'takeaway') {
              _selectedOrderType = OrderType.takeaway;
            } else if (cmd.orderType == 'delivery') {
              _selectedOrderType = OrderType.delivery;
            } else {
              _selectedOrderType = OrderType.dineIn;
            }
          });
        }
        break;
    }
  }

  @override
  void didUpdateWidget(PosRegisterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialOrderType != null &&
        (widget.initialOrderType != oldWidget.initialOrderType ||
         widget.tableSelectionToken != oldWidget.tableSelectionToken)) {
      _switchOrderType(widget.initialOrderType!);
    } else if (widget.initialTable != null &&
        (widget.initialTable != oldWidget.initialTable ||
         widget.tableSelectionToken != oldWidget.tableSelectionToken ||
         _selectedTable != widget.initialTable ||
         _cartItems.isEmpty)) {
      _loadCartForTable(widget.initialTable!, openCartModal: true);
    }
  }

  void _loadCartForTable(String tableName, {bool openCartModal = false}) {
    // Save draft of current active table/context if switching to a different table
    if ((_selectedTable != null && !isSameTable(_selectedTable, tableName)) || _selectedOrderType != OrderType.dineIn) {
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

      final tbl = db.tables.where((t) =>
        isSameTable(t.name, tableName) ||
        isSameTable(t.tableNumber.toString(), tableName) ||
        isSameTable('T-${t.tableNumber}', tableName)
      ).firstOrNull;

      final activeOrder = db.orders.where((o) =>
        (isSameTable(o.tableNumber, tableName) ||
         (tbl != null && (isSameTable(o.tableNumber, tbl.name) ||
                          isSameTable(o.tableNumber, tbl.tableNumber.toString()) ||
                          isSameTable(o.tableNumber, 'T-${tbl.tableNumber}') ||
                          (tbl.currentOrderId != null && (o.id == tbl.currentOrderId || o.orderNumber == tbl.currentOrderId))))) &&
        (o.status != OrderStatus.completed && o.status != OrderStatus.cancelled)
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
        } else if (tbl != null) {
          final savedCartByName = db.getLiveTableCart(tbl.name);
          if (savedCartByName.isNotEmpty) {
            _cartItems.addAll(savedCartByName.map((i) => i.clone()));
          }
        }
      }

      final savedDiscount = db.getLiveTableDiscount(tableName) ??
          (tbl != null ? db.getLiveTableDiscount(tbl.name) : null);
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
    if (_isProcessingKot) return;
    _isProcessingKot = true;

    try {
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
          barrierColor: Colors.black.withValues(alpha: 0.35),
          builder: (_) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: KotDialog(
              order: activeOrder,
              isReprint: true,
              onLegacyPrintKot: () {
                if (_selectedOrderType == OrderType.dineIn && _selectedTable != null) {
                  final tbl = db.tables.where((t) =>
                    isSameTable(t.name, _selectedTable) ||
                    t.tableNumber.toString() == _selectedTable
                  ).firstOrNull;
                  if (tbl != null) {
                    db.updateTableStatus(tbl.id, TableStatus.runningKot, orderId: activeOrder.id, occupiedSince: tbl.occupiedSince ?? activeOrder.createdAt);
                  }
                }
                if (setStateModal != null) setStateModal(() {});
                setState(() {});
              },
            ),
          ),
        );
        return;
      }

      final calc = currentOrderCalculation;
      final tblForKot = _selectedTable != null
          ? db.tables.where((t) => isSameTable(t.name, _selectedTable)).firstOrNull
          : null;

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
        createdAt: activeOrder?.createdAt ?? tblForKot?.occupiedSince ?? DateTime.now().toIso8601String(),
        customerName: _customerName,
        customerPhone: _customerPhone,
      );

      // OPEN KOT POPUP (Table status changes to Running KOT ONLY when Print KOT succeeds)
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (_) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: KotDialog(
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
                db.updateTableStatus(
                  tbl.id,
                  TableStatus.runningKot,
                  orderId: newOrder.id,
                  occupiedSince: tbl.occupiedSince ?? tblForKot?.occupiedSince ?? newOrder.createdAt,
                );
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
      ),
    );
  } finally {
      _isProcessingKot = false;
    }
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

        // Save live table cart total & items in DB so table card and view button can load it immediately
        db.setLiveCartTotal(targetTable, cartTotal - _discountAmount.clamp(0, cartTotal));
        db.setLiveTableCart(targetTable, _cartItems);

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
              db.updateTableStatus(tbl.id, mapped, orderId: activeOrder.id, occupiedSince: tbl.occupiedSince);
            }
          } else if (_cartItems.isEmpty) {
            db.clearTableCartAndFree(targetTable);
          } else if (_cartItems.isNotEmpty && (tbl.status == TableStatus.free || tbl.occupiedSince == null)) {
            // First item added to cart on free table or table with missing start time -> instantly ensure timer is active!
            db.updateTableStatus(tbl.id, TableStatus.occupied, occupiedSince: tbl.occupiedSince ?? DateTime.now().toIso8601String());
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
    if (_cartItems.isEmpty) return 0;
    int total = 0;
    final itemId = item.id;
    final varPrefix = '${itemId}_var_';
    for (int i = 0; i < _cartItems.length; i++) {
      final cId = _cartItems[i].item.id;
      if (cId == itemId || cId.startsWith(varPrefix)) {
        total += _cartItems[i].quantity;
      }
    }
    return total;
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
    double iconSize = 16,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF3FA),
        borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
        border: Border.all(color: const Color(0xFFD6E2F0), width: 1.0),
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
                color: Color(0xFF0F2B48),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(Icons.remove_rounded, size: iconSize, color: Colors.white),
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
                color: Color(0xFF0F2B48),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(Icons.add_rounded, size: iconSize, color: Colors.white),
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
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth > 600 ? 460.0 : (screenWidth * 0.92).clamp(320.0, 460.0);

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: StatefulBuilder(
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
                          color: vQty > 0 ? const Color(0xFF051C48).withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
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
        ),
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
          color: const Color(0xFF00A3FF).withValues(alpha: 0.15),
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

    InputDecoration buildInputDecoration({
      required String hintText,
      required IconData icon,
    }) {
      return InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontSize: 11.5,
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFE5EDF6),
        prefixIcon: Container(
          margin: const EdgeInsets.fromLTRB(8, 5, 8, 5),
          padding: const EdgeInsets.all(5.5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12002870),
                blurRadius: 3,
                offset: Offset(1, 1),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 15,
            color: const Color(0xFF0F2B48),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 30),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0F2B48), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 10.0, height: 1.1),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF5FB),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x240F2B48),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 10,
                      offset: Offset(-3, -3),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Dialog Header (Compact, sleek gradient, with location badge and NO cross icon)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF0F2B48),
                              Color(0xFF1E3A8A),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(21)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                              ),
                              child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 17),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Delivery Address',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.0,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    'Enter your delivery location',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Form Fields
                    // Form Fields (Scaled down, compact gaps and elegant styling)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Address / House No / Street (Required)
                            const Text(
                              'Street Address / House No.',
                              style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: addressCtrl,
                              maxLines: 2,
                              style: const TextStyle(
                                fontSize: 12.0,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w600,
                              ),
                              cursorColor: const Color(0xFF0F2B48),
                              cursorWidth: 1.8,
                              decoration: buildInputDecoration(
                                hintText: 'e.g. House No. 25, ABC Road',
                                icon: Icons.home_rounded,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter delivery address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),

                            // Landmark
                            const Text(
                              'Landmark',
                              style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: landmarkCtrl,
                              style: const TextStyle(
                                fontSize: 12.0,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w600,
                              ),
                              cursorColor: const Color(0xFF0F2B48),
                              cursorWidth: 1.8,
                              decoration: buildInputDecoration(
                                hintText: 'e.g. Near XYZ Mall',
                                icon: Icons.apartment_rounded,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // City & State Row
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'City',
                                        style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                      ),
                                      const SizedBox(height: 4),
                                      TextFormField(
                                        controller: cityCtrl,
                                        style: const TextStyle(
                                          fontSize: 12.0,
                                          color: Color(0xFF0F172A),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        cursorColor: const Color(0xFF0F2B48),
                                        cursorWidth: 1.8,
                                        decoration: buildInputDecoration(
                                          hintText: 'City',
                                          icon: Icons.location_on_outlined,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'State',
                                        style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                      ),
                                      const SizedBox(height: 4),
                                      TextFormField(
                                        controller: stateCtrl,
                                        style: const TextStyle(
                                          fontSize: 12.0,
                                          color: Color(0xFF0F172A),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        cursorColor: const Color(0xFF0F2B48),
                                        cursorWidth: 1.8,
                                        decoration: buildInputDecoration(
                                          hintText: 'State',
                                          icon: Icons.map_outlined,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Pincode
                            const Text(
                              'Pincode',
                              style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 4),
                            TextFormField(
                              controller: pincodeCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              style: const TextStyle(
                                fontSize: 12.0,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w600,
                              ),
                              cursorColor: const Color(0xFF0F2B48),
                              cursorWidth: 1.8,
                              decoration: buildInputDecoration(
                                hintText: 'e.g. 201301',
                                icon: Icons.local_post_office_outlined,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Action Buttons (Neumorphic styled Cancel + Save Address buttons)
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5EDF6),
                                      borderRadius: BorderRadius.circular(11),
                                      border: Border.all(color: Colors.white, width: 1.2),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.white,
                                          offset: Offset(-2, -2),
                                          blurRadius: 4,
                                        ),
                                        BoxShadow(
                                          color: Color(0x1F0F2B48),
                                          offset: Offset(2, 2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(11),
                                        onTap: () => Navigator.pop(ctx),
                                        child: const Center(
                                          child: Text(
                                            'Cancel',
                                            style: TextStyle(
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    height: 38,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF0F2B48), Color(0xFF1E3A8A)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(11),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.0),
                                      boxShadow: [
                                        const BoxShadow(
                                          color: Colors.white,
                                          offset: Offset(-1.5, -1.5),
                                          blurRadius: 3,
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF0F2B48).withValues(alpha: 0.35),
                                          offset: const Offset(2, 3),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(11),
                                        onTap: () {
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
                                        child: const Center(
                                          child: Text(
                                            'Save Address',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12.0,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      ),
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

  Future<ManualItemPersistenceMode?> _showManualItemPersistenceConfirmDialog({
    required String name,
    required double price,
    required int quantity,
    required String foodType,
    required double gstPercent,
    required String currency,
  }) {
    final String priceStr = price % 1 == 0 ? price.toInt().toString() : price.toStringAsFixed(2);
    ManualItemPersistenceMode selectedMode = ManualItemPersistenceMode.permanent;

    return showGeneralDialog<ManualItemPersistenceMode>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Save Product Type',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (confirmCtx, anim1, anim2) {
        return StatefulBuilder(
          builder: (confirmCtx, setModalState) {
            final bool isTemporary = selectedMode == ManualItemPersistenceMode.temporary;
            final bool isPermanent = selectedMode == ManualItemPersistenceMode.permanent;

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                backgroundColor: Colors.transparent,
                elevation: 0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FB),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24000000),
                        offset: Offset(0, 10),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Drag Handle Pill
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD3DCE6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Header Row
                        Row(
                          children: [
                            // Neumorphic Tag Icon Box
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F6FB),
                                borderRadius: BorderRadius.circular(13),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.white,
                                    offset: Offset(-2, -2),
                                    blurRadius: 4,
                                  ),
                                  BoxShadow(
                                    color: Color(0x18000000),
                                    offset: Offset(2, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  width: 1.2,
                                ),
                              ),
                              child: const Icon(
                                Icons.local_offer_outlined,
                                color: Color(0xFF0F172A),
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Save Product Type',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            // Neumorphic Circular Close Button
                            InkWell(
                              onTap: () => Navigator.pop(confirmCtx, null),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFF4F6FB),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.white,
                                      offset: Offset(-2, -2),
                                      blurRadius: 4,
                                    ),
                                    BoxShadow(
                                      color: Color(0x14000000),
                                      offset: Offset(2, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    width: 1.2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 17,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Item Summary Box (Preview Card)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.white,
                                offset: Offset(-2, -2),
                                blurRadius: 5,
                              ),
                              BoxShadow(
                                color: Color(0x0C000000),
                                offset: Offset(2, 3),
                                blurRadius: 6,
                              ),
                            ],
                            border: Border.all(color: const Color(0xFFEDF2F7), width: 1),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: foodType.toLowerCase() == 'non-veg'
                                      ? const Color(0xFFFEE2E2)
                                      : foodType.toLowerCase() == 'egg'
                                          ? const Color(0xFFFEF3C7)
                                          : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: FoodTypeIcon(itemType: foodType, size: 16),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$currency$priceStr  •  ${gstPercent == 0 ? "0%" : "${gstPercent.toStringAsFixed(0)}%"} GST',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Option 1: Temporary Card
                        InkWell(
                          onTap: () {
                            setModalState(() {
                              selectedMode = ManualItemPersistenceMode.temporary;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isTemporary ? const Color(0xFFF0F7FF) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: isTemporary
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x1F3B82F6),
                                        offset: Offset(0, 3),
                                        blurRadius: 8,
                                      ),
                                      BoxShadow(
                                        color: Colors.white,
                                        offset: Offset(-2, -2),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : const [
                                      BoxShadow(
                                        color: Colors.white,
                                        offset: Offset(-2, -2),
                                        blurRadius: 5,
                                      ),
                                      BoxShadow(
                                        color: Color(0x0C000000),
                                        offset: Offset(2, 3),
                                        blurRadius: 6,
                                      ),
                                    ],
                              border: Border.all(
                                color: isTemporary ? const Color(0xFF3B82F6) : const Color(0xFFEDF2F7),
                                width: isTemporary ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 18,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Flexible(
                                        child: Text(
                                          'Temporary',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE2E8F0),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Cart Only',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isTemporary ? const Color(0xFF0A1931) : const Color(0xFFCBD5E1),
                                      width: isTemporary ? 2.0 : 1.6,
                                    ),
                                  ),
                                  child: isTemporary
                                      ? Center(
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0xFF0A1931),
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Option 2: Permanent Card
                        InkWell(
                          onTap: () {
                            setModalState(() {
                              selectedMode = ManualItemPersistenceMode.permanent;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isPermanent ? const Color(0xFFF0F7FF) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: isPermanent
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x1F3B82F6),
                                        offset: Offset(0, 3),
                                        blurRadius: 8,
                                      ),
                                      BoxShadow(
                                        color: Colors.white,
                                        offset: Offset(-2, -2),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : const [
                                      BoxShadow(
                                        color: Colors.white,
                                        offset: Offset(-2, -2),
                                        blurRadius: 5,
                                      ),
                                      BoxShadow(
                                        color: Color(0x0C000000),
                                        offset: Offset(2, 3),
                                        blurRadius: 6,
                                      ),
                                    ],
                              border: Border.all(
                                color: isPermanent ? const Color(0xFF3B82F6) : const Color(0xFFEDF2F7),
                                width: isPermanent ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0A1931),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.bookmark_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Flexible(
                                        child: Text(
                                          'Permanent',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Save to Menu',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF15803D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isPermanent ? const Color(0xFF0A1931) : const Color(0xFFCBD5E1),
                                      width: isPermanent ? 2.0 : 1.6,
                                    ),
                                  ),
                                  child: isPermanent
                                      ? Center(
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0xFF0A1931),
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Bottom Action Buttons (Cancel & Save)
                        Row(
                          children: [
                            // Cancel Button
                            Expanded(
                              child: InkWell(
                                onTap: () => Navigator.pop(confirmCtx, null),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F6FB),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.white,
                                        offset: Offset(-2, -2),
                                        blurRadius: 5,
                                      ),
                                      BoxShadow(
                                        color: Color(0x10000000),
                                        offset: Offset(2, 3),
                                        blurRadius: 5,
                                      ),
                                    ],
                                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Save Button
                            Expanded(
                              child: InkWell(
                                onTap: () => Navigator.pop(confirmCtx, selectedMode),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0A1931),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x3D0A1931),
                                        offset: Offset(0, 4),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Save',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curve = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curve),
          child: FadeTransition(
            opacity: curve,
            child: child,
          ),
        );
      },
    );
  }

  void _showInputManuallyDialog() {
    final currency = db.restaurant?.currencySymbol ?? '₹';
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    int quantity = 1;
    String foodType = 'Veg';
    double selectedGstRate = (db.restaurant?.billingType == 'Non-GST') ? 0.0 : (db.restaurant?.taxRate ?? 5.0);
    String? errorMessage;
    List<ManualProductHistoryItem> matchingSuggestions = [];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Add Item Manually',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                backgroundColor: Colors.transparent,
                elevation: 0,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FB),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24000000),
                        offset: Offset(0, 10),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Drag Handle Pill
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD3DCE6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Header Row: Neumorphic Cart Icon + Title + Circular Close Button
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F6FB),
                                borderRadius: BorderRadius.circular(13),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.white,
                                    offset: Offset(-3, -3),
                                    blurRadius: 6,
                                  ),
                                  BoxShadow(
                                    color: Color(0x1A000000),
                                    offset: Offset(3, 3),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.shopping_cart_outlined,
                                color: Color(0xFF0F172A),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Add Item Manually',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            Material(
                              color: const Color(0xFFF4F6FB),
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: () => Navigator.pop(dialogCtx),
                                customBorder: const CircleBorder(),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFF4F6FB),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.white,
                                        offset: Offset(-2, -2),
                                        blurRadius: 4,
                                      ),
                                      BoxShadow(
                                        color: Color(0x18000000),
                                        offset: Offset(2, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Row 1: Item Name Field
                        RichText(
                          text: const TextSpan(
                            text: 'Item Name ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                            children: [
                              TextSpan(
                                text: '*',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F6FB),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12000000),
                                offset: Offset(1.5, 1.5),
                                blurRadius: 3,
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: Colors.white,
                                offset: Offset(-1.5, -1.5),
                                blurRadius: 3,
                                spreadRadius: 0,
                              ),
                            ],
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            controller: nameController,
                            autofocus: false,
                            onChanged: (val) {
                              setDialogState(() {
                                final query = val.trim();
                                if (query.isNotEmpty) {
                                  matchingSuggestions = db.searchManualProductsHistory(query);
                                } else {
                                  matchingSuggestions = [];
                                }
                              });
                            },
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              suffixIcon: nameController.text.isNotEmpty
                                  ? InkWell(
                                      onTap: () {
                                        setDialogState(() {
                                          nameController.clear();
                                          matchingSuggestions = [];
                                        });
                                      },
                                      child: const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFF94A3B8)),
                                    )
                                  : null,
                              suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              hintText: 'e.g. Roti, Paneer...',
                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w400),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),

                        // Suggestions Chips
                        if (nameController.text.trim().isNotEmpty && matchingSuggestions.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: matchingSuggestions.take(6).map((sug) {
                              final priceStr = sug.price % 1 == 0 ? sug.price.toInt().toString() : sug.price.toStringAsFixed(2);
                              return InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    nameController.text = sug.name;
                                    nameController.selection = TextSelection.fromPosition(TextPosition(offset: sug.name.length));
                                    priceController.text = priceStr;
                                    foodType = ['Veg', 'Non-Veg', 'Egg', 'Beverage'].contains(sug.foodType) ? sug.foodType : 'Veg';
                                    selectedGstRate = sug.gstPercent;
                                    matchingSuggestions = [];
                                  });
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x0A000000),
                                        offset: Offset(0, 1),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.history_rounded, size: 11, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${sug.name} ($currency$priceStr)',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Row 2: Price and Quantity
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Price Field
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      text: 'Price ($currency) ',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                      children: const [
                                        TextSpan(
                                          text: '*',
                                          style: TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F6FB),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x12000000),
                                          offset: Offset(1.5, 1.5),
                                          blurRadius: 3,
                                          spreadRadius: 0,
                                        ),
                                        BoxShadow(
                                          color: Colors.white,
                                          offset: Offset(-1.5, -1.5),
                                          blurRadius: 3,
                                          spreadRadius: 0,
                                        ),
                                      ],
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: TextField(
                                      controller: priceController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                      decoration: InputDecoration(
                                        prefixIcon: Container(
                                          width: 32,
                                          alignment: Alignment.center,
                                          child: Text(
                                            currency,
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                                        hintText: '0.00',
                                        hintStyle: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Quantity Stepper
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Qty',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 44,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4F6FB),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x12000000),
                                          offset: Offset(1.5, 1.5),
                                          blurRadius: 3,
                                          spreadRadius: 0,
                                        ),
                                        BoxShadow(
                                          color: Colors.white,
                                          offset: Offset(-1.5, -1.5),
                                          blurRadius: 3,
                                          spreadRadius: 0,
                                        ),
                                      ],
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: quantity > 1 ? () => setDialogState(() => quantity--) : null,
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              width: 28,
                                              height: 28,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF4F6FB),
                                                borderRadius: BorderRadius.circular(8),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.white,
                                                    offset: Offset(-1.5, -1.5),
                                                    blurRadius: 3,
                                                  ),
                                                  BoxShadow(
                                                    color: Color(0x18000000),
                                                    offset: Offset(1.5, 1.5),
                                                    blurRadius: 3,
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.remove_rounded,
                                                size: 15,
                                                color: quantity > 1 ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '$quantity',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => setDialogState(() => quantity++),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              width: 28,
                                              height: 28,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF4F6FB),
                                                borderRadius: BorderRadius.circular(8),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.white,
                                                    offset: Offset(-1.5, -1.5),
                                                    blurRadius: 3,
                                                  ),
                                                  BoxShadow(
                                                    color: Color(0x18000000),
                                                    offset: Offset(1.5, 1.5),
                                                    blurRadius: 3,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.add_rounded,
                                                size: 15,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Row 3: Food Type Dropdown Selection (Veg, Non-Veg, Egg, Beverage)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Food Type',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F6FB),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x12000000),
                                    offset: Offset(1.5, 1.5),
                                    blurRadius: 3,
                                    spreadRadius: 0,
                                  ),
                                  BoxShadow(
                                    color: Colors.white,
                                    offset: Offset(-1.5, -1.5),
                                    blurRadius: 3,
                                    spreadRadius: 0,
                                  ),
                                ],
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: ['Veg', 'Non-Veg', 'Egg', 'Beverage'].contains(foodType) ? foodType : 'Veg',
                                  isExpanded: true,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: Color(0xFF64748B)),
                                  borderRadius: BorderRadius.circular(12),
                                  dropdownColor: const Color(0xFFF4F6FB),
                                  elevation: 4,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Veg',
                                      child: Row(
                                        children: [
                                          FoodTypeIcon(itemType: 'Veg', size: 14),
                                          SizedBox(width: 8),
                                          Text(
                                            'Veg',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Non-Veg',
                                      child: Row(
                                        children: [
                                          FoodTypeIcon(itemType: 'Non-Veg', size: 14),
                                          SizedBox(width: 8),
                                          Text(
                                            'Non-Veg',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Egg',
                                      child: Row(
                                        children: [
                                          FoodTypeIcon(itemType: 'Egg', size: 14),
                                          SizedBox(width: 8),
                                          Text(
                                            'Egg',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Beverage',
                                      child: Row(
                                        children: [
                                          FoodTypeIcon(itemType: 'Beverage', size: 14),
                                          SizedBox(width: 8),
                                          Text(
                                            'Beverage',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setDialogState(() => foodType = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Row 4: Tax Rate (5-Option Segmented Neumorphic Pills)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tax Rate',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [0.0, 5.0, 12.0, 18.0, 28.0].map((rate) {
                                final isSel = selectedGstRate == rate;
                                final label = rate == 0.0 ? '0%' : '${rate.toStringAsFixed(0)}%';
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: InkWell(
                                      onTap: () => setDialogState(() => selectedGstRate = rate),
                                      borderRadius: BorderRadius.circular(10),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        height: 38,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSel ? const Color(0xFF0A1931) : const Color(0xFFF4F6FB),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSel ? const Color(0xFF0A1931) : const Color(0xFFE2E8F0),
                                          ),
                                          boxShadow: isSel
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(0xFF0A1931).withValues(alpha: 0.35),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : const [
                                                  BoxShadow(
                                                    color: Colors.white,
                                                    offset: Offset(-1.5, -1.5),
                                                    blurRadius: 3,
                                                  ),
                                                  BoxShadow(
                                                    color: Color(0x14000000),
                                                    offset: Offset(1.5, 1.5),
                                                    blurRadius: 3,
                                                  ),
                                                ],
                                        ),
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                            color: isSel ? Colors.white : const Color(0xFF475569),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),

                        if (errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFCA5A5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Row 5: Action Buttons (Cancel & Add to Cart)
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: SizedBox(
                                height: 44,
                                child: Material(
                                  color: const Color(0xFFF4F6FB),
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: () => Navigator.pop(dialogCtx),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.white,
                                            offset: Offset(-2, -2),
                                            blurRadius: 4,
                                          ),
                                          BoxShadow(
                                            color: Color(0x16000000),
                                            offset: Offset(2, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 6,
                              child: SizedBox(
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final name = nameController.text.trim();
                                    final price = double.tryParse(priceController.text.trim());

                                    if (name.isEmpty) {
                                      setDialogState(() => errorMessage = 'Please enter item name');
                                      return;
                                    }
                                    if (price == null || price <= 0) {
                                      setDialogState(() => errorMessage = 'Please enter valid price');
                                      return;
                                    }

                                    // Open confirmation popup to select Temporary vs Permanent
                                    final mode = await _showManualItemPersistenceConfirmDialog(
                                      name: name,
                                      price: price,
                                      quantity: quantity,
                                      foodType: foodType,
                                      gstPercent: selectedGstRate,
                                      currency: currency,
                                    );

                                    if (mode == null) return; // Dismissed or cancelled

                                    if (mode == ManualItemPersistenceMode.temporary) {
                                      // 1. Temporary Product (Cart Only, not in POS catalog or Menu Management)
                                      final customItem = MenuItemModel(
                                        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                                        productId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                                        name: name,
                                        category: 'Custom',
                                        price: price,
                                        salePrice: null,
                                        hasDiscount: false,
                                        itemType: foodType,
                                        gstPercent: selectedGstRate,
                                        description: 'Temporary manual item',
                                      );

                                      // Save to history for fast autocomplete typing
                                      db.saveManualProductToHistory(
                                        name: name,
                                        price: price,
                                        foodType: foodType,
                                        gstPercent: selectedGstRate,
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

                                      if (dialogCtx.mounted) {
                                        Navigator.pop(dialogCtx);
                                      }

                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Added "$name" ($currency${(price * quantity).toStringAsFixed(2)}) to Cart (Temporary)'),
                                            backgroundColor: const Color(0xFF0F172A),
                                            duration: const Duration(seconds: 2),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        );
                                      }
                                    } else if (mode == ManualItemPersistenceMode.permanent) {
                                      // 2. Permanent Product (Added to Cart AND saved in POS & Menu Management)
                                      String targetCategory = 'General';
                                      if (_selectedCategory != 'All' && db.categories.any((c) => c.toLowerCase() == _selectedCategory.toLowerCase())) {
                                        targetCategory = db.categories.firstWhere((c) => c.toLowerCase() == _selectedCategory.toLowerCase());
                                      } else if (db.categories.isNotEmpty) {
                                        targetCategory = db.categories.first;
                                      }

                                      final customItem = MenuItemModel(
                                        id: 'prod_${DateTime.now().millisecondsSinceEpoch}',
                                        productId: 'prod_${DateTime.now().millisecondsSinceEpoch}',
                                        name: name,
                                        category: targetCategory,
                                        price: price,
                                        salePrice: null,
                                        hasDiscount: false,
                                        itemType: foodType,
                                        gstPercent: selectedGstRate,
                                        description: 'Added from POS',
                                        isAvailable: true,
                                      );

                                      // Save to DB (adds to menuItems, categories, SharedPreferences, and remote backend)
                                      await db.saveMenuItem(customItem);

                                      // Also save to manual history for autocomplete
                                      db.saveManualProductToHistory(
                                        name: name,
                                        price: price,
                                        foodType: foodType,
                                        gstPercent: selectedGstRate,
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

                                      if (dialogCtx.mounted) {
                                        Navigator.pop(dialogCtx);
                                      }

                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Added "$name" to Cart & saved to POS Menu (Permanent)'),
                                            backgroundColor: const Color(0xFF10B981),
                                            duration: const Duration(seconds: 2),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0A1931),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                    shadowColor: const Color(0xFF0A1931).withValues(alpha: 0.35),
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                  icon: const Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Add to Cart',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
      transitionBuilder: (dialogCtx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
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

  TableStatus _getEffectiveTableStatus(TableModel table) {
    // 1. Check if there is an active running KOT order in db.orders
    final hasRunningKot = db.orders.any((o) =>
        (isSameTable(o.tableNumber, table.name) ||
         (table.currentOrderId != null && o.id == table.currentOrderId) ||
         'T-${o.tableNumber}'.toLowerCase() == table.name.trim().toLowerCase()) &&
        (o.status == OrderStatus.pending || o.status == OrderStatus.preparing));
    if (hasRunningKot || table.status == TableStatus.runningKot) {
      return TableStatus.runningKot;
    }

    // 2. Check if there are live cart items or in-memory cart for this table
    final isCurrentSelected = isSameTable(table.name, _selectedTable);
    final liveCart = db.getLiveTableCart(table.name);
    final hasLiveCart = liveCart.isNotEmpty || (isCurrentSelected && _cartItems.isNotEmpty);
    if (table.status == TableStatus.occupied || hasLiveCart || db.getLiveCartTotal(table.name) > 0) {
      return TableStatus.occupied;
    }

    // 3. Check reserved status
    if (table.status == TableStatus.reserved) {
      return TableStatus.reserved;
    }

    return TableStatus.free;
  }

  Color _getTableStatusColor(TableStatus status) {
    switch (status) {
      case TableStatus.free:
        return const Color(0xFF10B981); // Emerald Green
      case TableStatus.occupied:
        return const Color(0xFF2563EB); // Royal Blue
      case TableStatus.runningKot:
        return const Color(0xFFEF4444); // Red / Coral
      case TableStatus.reserved:
        return const Color(0xFF8B5CF6); // Purple
    }
  }

  Color _getTableStatusBg(TableStatus status) {
    switch (status) {
      case TableStatus.free:
        return const Color(0xFFE6FDF4);
      case TableStatus.occupied:
        return const Color(0xFFEFF6FF);
      case TableStatus.runningKot:
        return const Color(0xFFFFF1F2);
      case TableStatus.reserved:
        return const Color(0xFFFAF5FF);
    }
  }

  Color _getTableStatusBorder(TableStatus status) {
    switch (status) {
      case TableStatus.free:
        return const Color(0xFF86EFAC);
      case TableStatus.occupied:
        return const Color(0xFFBFDBFE);
      case TableStatus.runningKot:
        return const Color(0xFFFECDD3);
      case TableStatus.reserved:
        return const Color(0xFFE9D5FF);
    }
  }

  IconData _getTableStatusIcon(TableStatus status) {
    switch (status) {
      case TableStatus.free:
        return Icons.chair_rounded;
      case TableStatus.occupied:
        return Icons.people_alt_rounded;
      case TableStatus.runningKot:
        return Icons.soup_kitchen_rounded;
      case TableStatus.reserved:
        return Icons.calendar_today_rounded;
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
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogCtx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: StatefulBuilder(
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
        ),
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
    if (mounted && modalContext.mounted) {
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

    _cartApiService.removeItemFromCart(
      productId: item.productId.isNotEmpty ? item.productId : item.id,
      tableNumber: _selectedTable,
      orderType: _selectedOrderType.name,
    );
  }

  Widget _buildStatusLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6.5,
          height: 6.5,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
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
          db.updateTableStatus(oldTbl.id, TableStatus.occupied, occupiedSince: oldTbl.occupiedSince ?? DateTime.now().toIso8601String());
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
      if (dialogCtx.mounted) {
        Navigator.pop(dialogCtx);
      }
      _loadCartForTable(targetTable.name, openCartModal: true);
      return;
    }

    if (dialogCtx.mounted) {
      Navigator.pop(dialogCtx);
    }

    // If target table is occupied or has running KOT/orders, switch to view that table
    // Only perform table shift if target table is completely free
    final targetIsFree = targetTable.status == TableStatus.free &&
        db.getLiveCartTotal(targetTable.name) <= 0 &&
        !db.orders.any((o) => isSameTable(o.tableNumber, targetTable.name) && o.status != OrderStatus.completed && o.status != OrderStatus.cancelled);

    if (isShiftMode && hasActiveOrderOrCart && currentTable.isNotEmpty && targetIsFree) {
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
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (modalCtx) {
        String activeFloorTab = 'All';

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: StatefulBuilder(
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
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: Color(0xFFF4F8FC),
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
                    // Top Drag Handle Pill
                    Container(
                      width: 44,
                      height: 4.5,
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    // Header Row with Icon Box, Title & Close Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
                            ),
                            child: const Center(
                              child: Icon(Icons.table_restaurant_rounded, color: Color(0xFF0284C7), size: 19),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Change Table',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => Navigator.pop(modalCtx),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(Icons.close_rounded, size: 17, color: Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),

                    // Wrapped Floor Filter Tabs & Status Legend Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Wrapped Floor Filter Tabs
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: floors.map((flr) {
                              final isSel = activeFloorTab.toLowerCase() == flr.toLowerCase();
                              return InkWell(
                                onTap: () => setFloorState(() => activeFloorTab = flr),
                                borderRadius: BorderRadius.circular(10),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFF0F2B48) : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSel ? const Color(0xFF0F2B48) : const Color(0xFFE2E8F0),
                                      width: 1.2,
                                    ),
                                    boxShadow: isSel
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF0F2B48).withValues(alpha: 0.25),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : const [
                                            BoxShadow(
                                              color: Color(0x06000000),
                                              blurRadius: 3,
                                              offset: Offset(0, 1),
                                            ),
                                          ],
                                  ),
                                  child: Text(
                                    flr,
                                    style: TextStyle(
                                      color: isSel ? Colors.white : const Color(0xFF0F172A),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 6),
                          // Wrapped Status Legend Row
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              _buildStatusLegendDot(const Color(0xFF10B981), 'Free'),
                              _buildStatusLegendDot(const Color(0xFF2563EB), 'Occupied'),
                              _buildStatusLegendDot(const Color(0xFFEF4444), 'Running KOT'),
                              _buildStatusLegendDot(const Color(0xFF8B5CF6), 'Reserved'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),

                    // Floor-wise Table Grid View
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        itemCount: tablesByFloor.keys.length,
                        itemBuilder: (context, floorIdx) {
                          final floorName = tablesByFloor.keys.elementAt(floorIdx);
                          final floorTables = tablesByFloor[floorName]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (tablesByFloor.keys.length > 1)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 6, top: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0284C7),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        floorName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 0.86,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: floorTables.length,
                                itemBuilder: (context, idx) {
                                  final table = floorTables[idx];
                                  final isCurrentSelected = isSameTable(table.name, _selectedTable);
                                  final effectiveStatus = _getEffectiveTableStatus(table);
                                  final statusColor = _getTableStatusColor(effectiveStatus);
                                  final statusBg = _getTableStatusBg(effectiveStatus);
                                  final statusBorder = _getTableStatusBorder(effectiveStatus);
                                  final statusIcon = _getTableStatusIcon(effectiveStatus);
                                  final statusLabel = _getTableStatusLabel(effectiveStatus);

                                  final activeOrder = effectiveStatus == TableStatus.free
                                      ? null
                                      : db.orders.where((o) =>
                                          (isSameTable(o.tableNumber, table.name) ||
                                           'T-${o.tableNumber}'.toLowerCase() == table.name.trim().toLowerCase() ||
                                           (table.currentOrderId != null && o.id == table.currentOrderId)) &&
                                          (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
                                        ).firstOrNull;
                                  final confirmedAmount = activeOrder?.totalAmount ?? 0.0;
                                  final liveAmount = effectiveStatus == TableStatus.free ? 0.0 : db.getLiveCartTotal(table.name);
                                  final activeAmount = effectiveStatus == TableStatus.free ? 0.0 : (confirmedAmount > 0 ? confirmedAmount : liveAmount);
                                  final hasProducts = effectiveStatus != TableStatus.free && activeAmount > 0;

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
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isCurrentSelected ? const Color(0xFFEFF6FF) : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isCurrentSelected
                                              ? const Color(0xFF0284C7)
                                              : statusBorder,
                                          width: isCurrentSelected ? 2.0 : 1.2,
                                        ),
                                        boxShadow: isCurrentSelected
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF0284C7).withValues(alpha: 0.18),
                                                  blurRadius: 5,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : [
                                                BoxShadow(
                                                  color: statusColor.withValues(alpha: 0.08),
                                                  blurRadius: 3,
                                                  offset: const Offset(0, 1.5),
                                                ),
                                              ],
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Top Row: Status Pill & Selected Checkmark
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: statusBg,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: statusBorder, width: 0.8),
                                                ),
                                                child: Text(
                                                  statusLabel,
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              if (isCurrentSelected)
                                                const Icon(Icons.check_circle_rounded, color: Color(0xFF0284C7), size: 14)
                                              else
                                                const SizedBox(width: 14),
                                            ],
                                          ),

                                          // Middle: Table Icon & Name (inside Flexible to guarantee no overflow)
                                          Flexible(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  statusIcon,
                                                  color: statusColor,
                                                  size: 20,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _getFullTableTitle(table.name),
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 11.5,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Bottom: Price Pill or placeholder spacing
                                          if (hasProducts)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: statusBg,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: statusBorder.withValues(alpha: 0.6), width: 0.6),
                                              ),
                                              child: Text(
                                                '${db.restaurant?.currencySymbol ?? "₹"}${activeAmount.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: statusColor,
                                                ),
                                              ),
                                            )
                                          else
                                            const SizedBox(height: 12),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
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
        ),
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
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogCtx) {
        String activeFloorTab = 'All';
        String searchQuery = '';
        bool isShiftMode = hasActiveOrderOrCart;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: StatefulBuilder(
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
                                      ? 'Current: Table $currentTable'
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                                        size: 17,
                                        color: isShiftMode ? Colors.white : const Color(0xFF00A86B),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Shift Order',
                                        style: TextStyle(
                                          color: isShiftMode ? Colors.white : const Color(0xFF0F172A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
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
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                                        size: 17,
                                        color: !isShiftMode ? Colors.white : const Color(0xFF051C48),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Switch Table',
                                        style: TextStyle(
                                          color: !isShiftMode ? Colors.white : const Color(0xFF0F172A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
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
                                  hintText: 'Search table...',
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
                                      showCheckmark: false,
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
                          _buildStatusLegendDot(const Color(0xFF2563EB), 'Occupied'),
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
                                    if (tablesByFloor.keys.length > 1)
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
                                            childAspectRatio: 0.98,
                                            crossAxisSpacing: 8,
                                            mainAxisSpacing: 8,
                                          ),
                                          itemCount: floorTables.length,
                                          itemBuilder: (context, idx) {
                                            final table = floorTables[idx];
                                            final isCurrentSelected = isSameTable(table.name, currentTable);
                                            final effectiveStatus = _getEffectiveTableStatus(table);
                                            final statusColor = _getTableStatusColor(effectiveStatus);
                                            final statusBg = _getTableStatusBg(effectiveStatus);
                                            final statusBorder = _getTableStatusBorder(effectiveStatus);

                                            final activeOrder = effectiveStatus == TableStatus.free
                                                ? null
                                                : db.orders.where((o) =>
                                                    (isSameTable(o.tableNumber, table.name) ||
                                                     'T-${o.tableNumber}'.toLowerCase() == table.name.trim().toLowerCase() ||
                                                     (table.currentOrderId != null && o.id == table.currentOrderId)) &&
                                                    (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
                                                  ).firstOrNull;
                                            final confirmedAmount = activeOrder?.totalAmount ?? 0.0;
                                            final liveAmount = effectiveStatus == TableStatus.free ? 0.0 : db.getLiveCartTotal(table.name);
                                            final activeAmount = effectiveStatus == TableStatus.free ? 0.0 : (confirmedAmount > 0 ? confirmedAmount : liveAmount);

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
                                                        : statusBorder,
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
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    // Header Row: Status badge & Current indicator
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                          decoration: BoxDecoration(
                                                            color: statusBg,
                                                            borderRadius: BorderRadius.circular(4),
                                                            border: Border.all(color: statusBorder, width: 0.8),
                                                          ),
                                                          child: Text(
                                                            _getTableStatusLabel(effectiveStatus),
                                                            style: TextStyle(
                                                              color: statusColor,
                                                              fontWeight: FontWeight.w800,
                                                              fontSize: 8.5,
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
                                                                fontSize: 7.5,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    // Table Name
                                                    Text(
                                                      table.name,
                                                      style: TextStyle(
                                                        fontSize: 12.5,
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
                                                            fontSize: 9,
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
                                                              fontSize: 10,
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
        ),
      );
    },
  );
  }


  void _showAddCustomerDialog(StateSetter setStateModal) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: _CustomerDetailsDialog(
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
          ),
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
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) {
        final ptsName = activeLoyalty.pointsName.isNotEmpty ? activeLoyalty.pointsName : 'Cash';
        final orderTypesList = activeLoyalty.orderTypes.isNotEmpty ? activeLoyalty.orderTypes : ['DineIn', 'Takeaway'];

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Dialog(
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
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final screenWidth = MediaQuery.of(context).size.width;
              final dialogWidth = math.min(screenWidth * 0.90, 400.0);

              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Container(
                  width: dialogWidth,
                  constraints: const BoxConstraints(maxWidth: 400, minWidth: 280),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F8FC),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        offset: const Offset(0, 8),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Header with Soft Cyan Icon Box, Title, and Circular Close (X) Button
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFBAE6FD), width: 1.0),
                                ),
                                child: const Center(
                                  child: Icon(Icons.local_offer_rounded, color: Color(0xFF0284C7), size: 18),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Extra\'s',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              // Circular Close Button (X)
                              InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x0A000000),
                                        offset: Offset(0, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.close_rounded, color: Color(0xFF475569), size: 17),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // 2. Loyalty Reward Program Banner (if customer is added)
                          if (_customerPhone.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0F2B48), Color(0xFF1E3A8A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x180F2B48),
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.cookie_outlined, color: Color(0xFFFDE68A), size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Loyalty: ${_currentCustomerLoyalty?.pointsBalance ?? 0} ${_currentCustomerLoyalty?.pointsName ?? 'Cookies'}',
                                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          _redeemedLoyaltyStageId != null
                                              ? '₹${_loyaltyDiscountAmount.toInt()} Stage Discount Applied ✓'
                                              : (_currentCustomerLoyalty?.hasUnlockedStages == true
                                                  ? '⭐ Rewards unlocked and ready!'
                                                  : 'Earn points on this order'),
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 9.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF0F2B48),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                            tempDiscountMode = 'flat';
                                            tempDiscountVal = discount;
                                            discCtrl.text = discount.toStringAsFixed(0);
                                            _discountMode = 'flat';
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
                                    child: const Text('Redeem (OTP)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 3. Add Discount Card
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x04000000),
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Row with Icon, Title, and Mode Toggle Pill (% vs ₹)
                                Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE6FDF4),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.0),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.discount_outlined, color: Color(0xFF059669), size: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Add Discount',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    // Mode Toggle Pill (% vs ₹)
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () => setDialogState(() => tempDiscountMode = 'percent'),
                                            borderRadius: BorderRadius.circular(14),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: (tempDiscountMode == 'percent' || tempDiscountMode == '%')
                                                    ? const Color(0xFF0F2B48)
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: Text(
                                                '%',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: (tempDiscountMode == 'percent' || tempDiscountMode == '%')
                                                      ? Colors.white
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () => setDialogState(() => tempDiscountMode = 'flat'),
                                            borderRadius: BorderRadius.circular(14),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: (tempDiscountMode == 'flat' || tempDiscountMode == '₹')
                                                    ? const Color(0xFF0F2B48)
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: Text(
                                                '₹',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: (tempDiscountMode == 'flat' || tempDiscountMode == '₹')
                                                      ? Colors.white
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Compact Input Field with Badge & Apply Button
                                Container(
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.horizontal(left: Radius.circular(9)),
                                        ),
                                        child: Text(
                                          (tempDiscountMode == 'percent' || tempDiscountMode == '%') ? '%' : '₹',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0F2B48),
                                          ),
                                        ),
                                      ),
                                      Container(width: 1, color: const Color(0xFFCBD5E1)),
                                      Expanded(
                                        child: TextField(
                                          controller: discCtrl,
                                          scrollPadding: const EdgeInsets.only(bottom: 90),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          cursorColor: const Color(0xFF0F2B48),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          decoration: InputDecoration(
                                            hintText: (tempDiscountMode == 'percent' || tempDiscountMode == '%') ? '10' : '50',
                                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.normal),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            border: InputBorder.none,
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.all(3),
                                        child: ElevatedButton(
                                          onPressed: () {
                                            final val = double.tryParse(discCtrl.text.trim()) ?? 0.0;
                                            setDialogState(() {
                                              tempDiscountVal = val;
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(val > 0
                                                    ? 'Discount of ${(tempDiscountMode == "percent" || tempDiscountMode == "%") ? "$val%" : "₹$val"} Applied!'
                                                    : 'Discount reset.'),
                                                duration: const Duration(seconds: 1),
                                                backgroundColor: const Color(0xFF0F2B48),
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0F2B48),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 4. Add Tip Card
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x04000000),
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Row with Icon, Title
                                Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF1F2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFECDD3), width: 1.0),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.volunteer_activism_rounded, color: Color(0xFFE11D48), size: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Add Tip',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Compact Input Field with Badge & Apply Button
                                Container(
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.horizontal(left: Radius.circular(9)),
                                        ),
                                        child: const Text(
                                          '₹',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0F2B48),
                                          ),
                                        ),
                                      ),
                                      Container(width: 1, color: const Color(0xFFCBD5E1)),
                                      Expanded(
                                        child: TextField(
                                          controller: tipCtrl,
                                          scrollPadding: const EdgeInsets.only(bottom: 90),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          cursorColor: const Color(0xFF0F2B48),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          decoration: const InputDecoration(
                                            hintText: '10',
                                            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.normal),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            border: InputBorder.none,
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.all(3),
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
                                                backgroundColor: const Color(0xFF0F2B48),
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0F2B48),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 5. Coupon Card
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x04000000),
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Row with Icon, Title
                                Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFFDE68A), width: 1.0),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.confirmation_number_outlined, color: Color(0xFFD97706), size: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        tempCoupon.isNotEmpty ? 'Coupon: $tempCoupon' : 'Have a Coupon?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: tempCoupon.isNotEmpty ? const Color(0xFF059669) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Compact Input Field with Badge & Apply Button
                                Container(
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.horizontal(left: Radius.circular(9)),
                                        ),
                                        child: const Icon(Icons.sell_outlined, size: 16, color: Color(0xFF0F2B48)),
                                      ),
                                      Container(width: 1, color: const Color(0xFFCBD5E1)),
                                      Expanded(
                                        child: TextField(
                                          controller: couponCtrl,
                                          scrollPadding: const EdgeInsets.only(bottom: 90),
                                          textCapitalization: TextCapitalization.characters,
                                          cursorColor: const Color(0xFF0F2B48),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          decoration: const InputDecoration(
                                            hintText: 'SAVE50',
                                            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.normal),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            border: InputBorder.none,
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.all(3),
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
                                                      SnackBar(
                                                        content: const Text('Coupon cleared.'),
                                                        duration: const Duration(seconds: 1),
                                                        backgroundColor: const Color(0xFF0F2B48),
                                                        behavior: SnackBarBehavior.floating,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                                                            ? const Color(0xFF0F2B48)
                                                            : const Color(0xFFDC2626),
                                                        behavior: SnackBarBehavior.floating,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                      ),
                                                    );
                                                  }
                                                },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0F2B48),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: isValidatingCoupon
                                              ? const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 6. Full Width Done Button
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F2B48),
                              borderRadius: BorderRadius.circular(21),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F2B48).withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                final discountVal = double.tryParse(discCtrl.text.trim()) ?? tempDiscountVal;
                                final tipVal = double.tryParse(tipCtrl.text.trim()) ?? tempTipVal;

                                setState(() {
                                  _appliedCoupon = tempCoupon;
                                  _promoCodeController.text = tempCoupon;
                                  _discountMode = (tempDiscountMode == '%' || tempDiscountMode == 'percent') ? 'percent' : 'flat';
                                  _discountInputValue = discountVal;
                                  _tipAmount = tipVal;
                                  _discountAmount = 0.0; // reset manual override so getter calculates
                                });
                                _saveCurrentDraft();

                                setStateModal(() {});
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(21),
                                ),
                              ),
                              child: const Text(
                                'Done',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
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
            },
          ),
        );
      },
    );
  }

  Widget _buildOrderTypeIconBox() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _selectedOrderType == OrderType.dineIn
            ? const Color(0xFFE0F2FE)
            : (_selectedOrderType == OrderType.delivery
                ? const Color(0xFFD1FAE5)
                : const Color(0xFFFEF3C7)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedOrderType == OrderType.dineIn
              ? const Color(0xFFBAE6FD)
              : (_selectedOrderType == OrderType.delivery
                  ? const Color(0xFFA7F3D0)
                  : const Color(0xFFFDE68A)),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.white,
            offset: Offset(-1.5, -1.5),
            blurRadius: 3,
          ),
          BoxShadow(
            color: Color(0xFFCAD8E8),
            offset: Offset(1.5, 1.5),
            blurRadius: 3,
          ),
        ],
      ),
      child: Center(
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
          size: 21,
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
            width: 44,
            height: 4.5,
            margin: const EdgeInsets.only(top: 6, bottom: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Top Navigation Header for mobile sheet
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.white,
                          offset: Offset(-2, -2),
                          blurRadius: 4,
                        ),
                        BoxShadow(
                          color: Color(0xFFD4E2EE),
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 19),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _buildOrderTypeIconBox(),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedOrderType == OrderType.dineIn
                        ? _getFullTableTitle()
                        : (_selectedOrderType == OrderType.takeaway ? 'Takeaway' : 'Delivery'),
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (_selectedOrderType == OrderType.dineIn)
                  InkWell(
                    onTap: () => _showChangeTableDialog(setStateCart),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white, width: 1.2),
                        boxShadow: [
                          const BoxShadow(
                            color: Colors.white,
                            offset: Offset(-3, -3),
                            blurRadius: 6,
                          ),
                          BoxShadow(
                            color: const Color(0xFFCAD8E8).withValues(alpha: 0.9),
                            offset: const Offset(3, 3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          //Icon(Icons.swap_horiz_rounded, size: 18, color: Color(0xFF0F2B48)),
                          SizedBox(width: 5),
                          Text(
                            'Change Table',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F2B48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_selectedOrderType == OrderType.delivery)
                  InkWell(
                    onTap: () => _showDeliveryAddressDialog(setStateCart),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.white,
                            offset: Offset(-2, -2),
                            blurRadius: 4,
                          ),
                          BoxShadow(
                            color: Color(0xFFD4E2EE),
                            offset: Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon(
                          //   _hasDeliveryAddress ? Icons.edit_location_alt_rounded : Icons.add_location_alt_rounded,
                          //   size: 15,
                          //   color: const Color(0xFF0F2B48),
                          // ),
                          const SizedBox(width: 4),
                          Text(
                            _hasDeliveryAddress ? 'Edit Address' : 'Add Address',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F2B48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Items (${_cartItems.fold<int>(0, (sum, i) => sum + i.quantity)})',
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                if (_cartItems.isNotEmpty)
                  InkWell(
                    onTap: () => _handleClearCartAction(context, setStateCart),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFECEC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFD5D5), width: 0.1),
                        boxShadow: [
                          const BoxShadow(
                            color: Colors.white,
                            offset: Offset(-2, -2),
                            blurRadius: 4,
                          ),
                          BoxShadow(
                            color: const Color(0xFFE8C8C8).withValues(alpha: 0.6),
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          //Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                          SizedBox(width: 5),
                          Text(
                            'Clear Cart',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
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
                      Icon(Icons.shopping_cart_outlined, size: isDesktopPanel ? 36 : 52, color: const Color(0xFFCBD5E1)),
                      const SizedBox(height: 8),
                      Text(
                        isDesktopPanel ? 'No items in cart.\nClick products to add.' : 'Your cart is empty',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: isDesktopPanel ? 12 : 16, vertical: 4),
                  itemCount: _cartItems.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final cItem = _cartItems[idx];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.8)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.white,
                            offset: Offset(-2, -2),
                            blurRadius: 4,
                          ),
                          BoxShadow(
                            color: Color(0xFFD4E2EE),
                            offset: Offset(2, 2.5),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Food Type Veg/Nonveg Icon
                          FoodTypeIcon(itemType: cItem.item.itemType, size: 10.5),
                          const SizedBox(width: 8),

                          // Item Title & Price (No Product Image on Cart Screen)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cItem.item.name,
                                  style: TextStyle(
                                    fontSize: isDesktopPanel ? 11.5 : 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    if (cItem.item.hasDiscount && cItem.item.discountPercent > 0) ...[
                                      Text(
                                        '$currency${cItem.item.effectivePrice.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          fontSize: isDesktopPanel ? 11.5 : 13.5,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$currency${cItem.item.price.toStringAsFixed(1)}',
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF94A3B8),
                                          decoration: TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        '$currency${cItem.item.price.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          fontSize: isDesktopPanel ? 11.5 : 13.5,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 6),
                                    Builder(
                                      builder: (context) {
                                        final double effectiveGst = cItem.item.gstPercent ?? ((db.restaurant?.billingType == 'Non-GST') ? 0.0 : (db.restaurant?.taxRate ?? 5.0));
                                        if (effectiveGst <= 0) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            child: const Text(
                                              'No GST',
                                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                            ),
                                          );
                                        }
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            'GST ${effectiveGst.toStringAsFixed(0)}%',
                                            style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Quantity Stepper Enclosed Capsule (- QTY +)
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.white,
                                  offset: Offset(-1.5, -1.5),
                                  blurRadius: 3,
                                ),
                                BoxShadow(
                                  color: Color(0xFFCAD8E8),
                                  offset: Offset(1.5, 1.5),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    _decrementCartItem(cItem.item);
                                    setStateCart(() {});
                                    setState(() {});
                                    if (!isDesktopPanel) {
                                      _checkAndCloseEmptyCart(context, setStateCart);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(13),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F2B48),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF0F2B48).withValues(alpha: 0.25),
                                          offset: const Offset(0, 1.5),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.remove_rounded, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '${cItem.quantity}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    _addToCart(cItem.item);
                                    setStateCart(() {});
                                    setState(() {});
                                  },
                                  borderRadius: BorderRadius.circular(13),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F2B48),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF0F2B48).withValues(alpha: 0.25),
                                          offset: const Offset(0, 1.5),
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.add_rounded, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Trash Delete Button (Pink/red circle)
                          InkWell(
                            onTap: () {
                              _removeCartItem(cItem.item);
                              setStateCart(() {});
                              setState(() {});
                              if (!isDesktopPanel) {
                                _checkAndCloseEmptyCart(context, setStateCart);
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFECEC),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFFFD5D5), width: 1.0),
                                boxShadow: [
                                  const BoxShadow(
                                    color: Colors.white,
                                    offset: Offset(-1.5, -1.5),
                                    blurRadius: 3,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFFE8C8C8).withValues(alpha: 0.5),
                                    offset: const Offset(1.5, 1.5),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 16,
                                ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1.5),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showAddCustomerDialog(setStateCart),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F2B48),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F2B48).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 17),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _customerName.isNotEmpty
                                  ? (_customerPhone.isNotEmpty ? '$_customerName ($_customerPhone)' : _customerName)
                                  : 'Add Customer',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.0,
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

                Expanded(
                  child: InkWell(
                    onTap: () => _showExtraBenefitDialog(setStateCart),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.white,
                            offset: Offset(-2, -2),
                            blurRadius: 4,
                          ),
                          BoxShadow(
                            color: Color(0xFFD3E0EA),
                            offset: Offset(2, 2),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_offer_rounded, color: Color(0xFF0F2B48), size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              (computedDiscountAmount > 0 || _tipAmount > 0)
                                  ? 'Extra\'s (₹${(computedDiscountAmount + _tipAmount).toStringAsFixed(0)})'
                                  : 'Extra\'s',
                              style: const TextStyle(
                                color: Color(0xFF0F2B48),
                                fontWeight: FontWeight.w800,
                                fontSize: 13.0,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1.5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.8)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.white,
                  offset: Offset(-2, -2),
                  blurRadius: 5,
                ),
                BoxShadow(
                  color: Color(0xFFD3E0EA),
                  offset: Offset(2, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sub total',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '$currency${cartSubtotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                if (computedDiscountAmount > 0) ...[
                  const SizedBox(height: 2.5),
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
                        style: const TextStyle(fontSize: 12.0, color: Color(0xFF10B981), fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '- $currency${computedDiscountAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ],
                if (_tipAmount > 0) ...[
                  const SizedBox(height: 2.5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tip:', style: TextStyle(fontSize: 12.0, color: Color(0xFF00A896), fontWeight: FontWeight.w700)),
                      Text(
                        '+ $currency${_tipAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF00A896)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 2.5),
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
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '+ $currency${cartTax.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1.2),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total amount',
                      style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      '$currency${cartTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Color(0xFF0F2B48)),
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
                      onPressed: (_cartItems.isEmpty || _isProcessingCheckout)
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
                              color: _cartItems.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF0F2B48),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            'Print KOT',
                            style: TextStyle(
                              color: _cartItems.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F2B48),
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
                              color: _cartItems.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF0F2B48),
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            backgroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                          ),
                          // icon: Icon(
                          //   //Icons.print_outlined,
                          //   size: 14,
                          //   color: _cartItems.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F2B48),
                          // ),
                          label: Text(
                            'Save & Print',
                            style: TextStyle(
                              color: _cartItems.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F2B48),
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                // 1) KOT Button
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(23),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.white,
                          offset: Offset(-2, -2),
                          blurRadius: 4,
                        ),
                        BoxShadow(
                          color: Color(0xFFD4E2EE),
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: OutlinedButton(
                      onPressed: _cartItems.isEmpty
                          ? null
                          : () async {
                              await _sendKotOrder(setStateCart);
                            },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'KOT',
                              style: TextStyle(
                                color: _cartItems.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F2B48),
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 2) Save & Print Button (Between KOT and Settle)
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(23),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.white,
                          offset: Offset(-2, -2),
                          blurRadius: 4,
                        ),
                        BoxShadow(
                          color: Color(0xFFD4E2EE),
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: OutlinedButton(
                      onPressed: _cartItems.isEmpty
                          ? null
                          : () async {
                              await _handleSaveAndPrint(setStateCart, context);
                            },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
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
                              color: _cartItems.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F2B48),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Save & Print',
                              style: TextStyle(
                                color: _cartItems.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F2B48),
                                fontWeight: FontWeight.w800,
                                fontSize: 13.0,
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
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: _cartItems.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0F2B48),
                      borderRadius: BorderRadius.circular(23),
                      boxShadow: _cartItems.isEmpty
                          ? []
                          : [
                              BoxShadow(
                                color: const Color(0xFF0F2B48).withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: ElevatedButton(
                      onPressed: (_cartItems.isEmpty || _isProcessingCheckout)
                          ? null
                          : () {
                              _checkoutOrder(cartContext: context);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Settle',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5),
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
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: StatefulBuilder(
            builder: (context, setStateModal) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.70,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F8FC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F2B48).withValues(alpha: 0.18),
                      blurRadius: 25,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  bottom: true,
                  child: _buildCartPanelContent(setStateCart: setStateModal, isDesktopPanel: false),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handleSaveAndPrint([StateSetter? setStateModal, BuildContext? callerContext]) async {
    if (_isProcessingSaveAndPrint) return;
    _isProcessingSaveAndPrint = true;

    try {
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
      if (mounted && targetContext.mounted) {
        showDialog(
          context: targetContext,
          barrierColor: Colors.black.withValues(alpha: 0.35),
          builder: (_) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: ReceiptDialog(
              order: savedOrder,
              currency: currency,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(callerContext ?? context).showSnackBar(
          SnackBar(
            content: Text('Save & Print error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      _isProcessingSaveAndPrint = false;
    }
  }

  Future<void> _checkoutOrder({BuildContext? cartContext}) async {
    if (_isProcessingCheckout || _cartItems.isEmpty) return;
    _isProcessingCheckout = true;

    try {
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
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (_) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: PaymentModal(
            order: previewOrder,
            currency: currency,
          ),
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
              customerName: _customerName.isNotEmpty ? _customerName : targetKotOrder.customerName,
              customerPhone: _customerPhone.isNotEmpty ? _customerPhone : targetKotOrder.customerPhone,
              deliveryAddress: _selectedOrderType == OrderType.delivery ? _formattedDeliveryAddress : targetKotOrder.deliveryAddress,
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
              barrierColor: Colors.black.withValues(alpha: 0.35),
              transitionDuration: const Duration(milliseconds: 100),
              pageBuilder: (ctx, anim1, anim2) => BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: ReceiptDialog(order: completedOrder, currency: currency),
              ),
            );
          }
        }
      }
    } finally {
      _isProcessingCheckout = false;
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
              if (db.isChotuVoiceEnabled) ...[
                const SizedBox(width: 8),
                // Chotu AI Voice Assistant Button
                ChotuMicButton(
                  tableNumber: _selectedTable,
                  isCompact: true,
                  onTranscriptionUpdated: () => setState(() {}),
                ),
              ],
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
              ElevatedButton(
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
                child: const Text(
                  'Add Items',
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
              if (db.isChotuVoiceEnabled) ...[
                const SizedBox(width: 8),
                // Chotu Voice Search Button
                ChotuMicButton(
                  tableNumber: _selectedTable,
                  isCompact: true,
                  onTranscriptionUpdated: () => setState(() {}),
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // Categories Filter Row
          SizedBox(
            height: 32,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              itemCount: allCategories.length,
              itemBuilder: (context, index) {
                final cat = allCategories[index];
                final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategory = cat),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF051C48) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF051C48) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 11.5,
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
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogCtx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
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
                        _loadCartForTable(tableName, openCartModal: true);
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
                      onTakeOrderForType: (orderType) {
                        _switchOrderType(orderType, setStateCart);
                        Navigator.pop(dialogCtx);
                      },
                    ),
                  ),
                ),
              ],
            ),
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
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F2B48), size: 24),
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
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: 0.2,
              ),
            ),
            if (_selectedTable != null && _selectedTable!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.white,
                      offset: Offset(-2, -2),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Color(0xFFC0D2E6),
                      offset: Offset(2, 2),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  _selectedTable!,
                  style: const TextStyle(
                    color: Color(0xFF0F2B48),
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
            const Spacer(),
            // TABLES BUTTON (Deep Navy Pill matching reference UI)
            SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: () => _openTablesSelectionDialog(),
                icon: const Icon(Icons.table_restaurant_outlined, color: Colors.white, size: 18),
                label: const Text(
                  'Tables',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2B48),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  elevation: 2,
                  shadowColor: const Color(0xFF0F2B48).withValues(alpha: 0.35),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // ADD ITEM BUTTON (Soft Neumorphic Pill button matching reference UI)
            InkWell(
              onTap: _showInputManuallyDialog,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFD),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.white,
                      offset: Offset(-2.5, -2.5),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Color(0xFFC0D2E6),
                      offset: Offset(2.5, 2.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle, size: 18, color: Color(0xFF0F2B48)),
                    SizedBox(width: 5),
                    Text(
                      'Add Item',
                      style: TextStyle(
                        color: Color(0xFF0F2B48),
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
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
  }

  Widget _buildSearchAndCategoriesBar(List<String> allCategories, {bool isDesktop = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search Bar & Chotu Voice Button (Android / Mobile View)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Neumorphic Inset Search Bar
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF3FA),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFD6E2F0), width: 1.2),
                    boxShadow: [
                      const BoxShadow(
                        color: Colors.white,
                        offset: Offset(-2, -2),
                        blurRadius: 4,
                        spreadRadius: 0.5,
                      ),
                      BoxShadow(
                        color: const Color(0xFFB8CCE4).withValues(alpha: 0.6),
                        offset: const Offset(2, 2),
                        blurRadius: 5,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                  child: TextField(
                    scrollPadding: const EdgeInsets.only(bottom: 90),
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: 'Search products by name or category...',
                      hintStyle: TextStyle(color: Color(0xFF8898AA), fontSize: 13.0, fontWeight: FontWeight.normal),
                      prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF0F2B48), size: 22),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                  ),
                ),
              ),
              if (db.isChotuVoiceEnabled) ...[
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFD),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.white,
                        offset: Offset(-2.5, -2.5),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Color(0xFFC0D2E6),
                        offset: Offset(2.5, 2.5),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ChotuMicButton(
                    tableNumber: _selectedTable,
                    isCompact: false,
                    onTranscriptionUpdated: () => setState(() {}),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Categories Row
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: allCategories.length,
            itemBuilder: (context, index) {
              final cat = allCategories[index];
              final isSelected = _selectedCategory.toLowerCase() == cat.toLowerCase();

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => _selectedCategory = cat),
                  borderRadius: BorderRadius.circular(22),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0F2B48) : const Color(0xFFF7FAFD),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF0F2B48) : Colors.white,
                        width: isSelected ? 1.4 : 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF0F2B48).withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : const [
                              BoxShadow(
                                color: Colors.white,
                                offset: Offset(-2, -2),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: Color(0xFFC0D2E6),
                                offset: Offset(2, 2),
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                        fontSize: 12.0,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWithoutImageTopRightBadge({
    required int qty,
    required bool hasVariants,
    required int variantsCount,
    required bool isDiscounted,
    required double discountPct,
  }) {
    if (qty > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF0F2B48),
          borderRadius: BorderRadius.circular(5),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 2),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 8.5),
            const SizedBox(width: 2),
            Text(
              '$qty',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.0,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    if (hasVariants) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        decoration: BoxDecoration(
          color: const Color(0xFF051C48).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$variantsCount Variants',
          style: const TextStyle(
            color: Color(0xFF051C48),
            fontSize: 8.0,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    if (isDiscounted && discountPct > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${discountPct.toStringAsFixed(0)}% OFF',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 7.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
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

    // ──────────────────────────────────────────────────────────────────────────
    // 1) WITHOUT IMAGE COMPACT CARD (Neumorphic 3-Tier Layout)
    // ──────────────────────────────────────────────────────────────────────────
    if (!showImages) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF9FBFE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F2B48) : Colors.white,
            width: isSelected ? 1.5 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F2B48).withValues(alpha: 0.18),
                    offset: const Offset(0, 3),
                    blurRadius: 6,
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-3, -3),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: Color(0xFFCAD8E8),
                    offset: Offset(3, 3),
                    blurRadius: 7,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: handleItemTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 1. Top Header: Veg/Non-Veg Icon + Qty/Variant/Discount Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildFoodTypeIcon(item.itemType),
                      const Spacer(),
                      _buildWithoutImageTopRightBadge(
                        qty: qty,
                        hasVariants: hasVariants,
                        variantsCount: item.variants.length,
                        isDiscounted: isDiscounted,
                        discountPct: displayDiscountPct,
                      ),
                    ],
                  ),

                  // 2. Center: Product Name (Multi-line with smaller readable typography)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.name,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isDesktop ? 12.0 : 11.5,
                            color: const Color(0xFF0F172A),
                            height: 1.15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),

                  // 3. Bottom: Price and Variant indicator
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (isDiscounted) ...[
                        Text(
                          '$currency${displaySalePrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: const Color(0xFF0F2B48),
                            fontWeight: FontWeight.w900,
                            fontSize: isDesktop ? 12.5 : 12.0,
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
                            color: const Color(0xFF0F2B48),
                            fontWeight: FontWeight.w900,
                            fontSize: isDesktop ? 12.5 : 12.0,
                          ),
                        ),
                      ],
                      if (hasVariants) ...[
                        const SizedBox(width: 3),
                        const Text(
                          'onwards',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 2) WITH IMAGE CARD LAYOUT (Neumorphism Design matching reference UI)
    // ──────────────────────────────────────────────────────────────────────────
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? const Color(0xFF60A5FA) : Colors.white,
          width: isSelected ? 1.8 : 1.2,
        ),
        boxShadow: isSelected
            ? const [
                BoxShadow(
                  color: Color(0x3338BDF8),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ]
            : const [
                BoxShadow(
                  color: Colors.white,
                  offset: Offset(-3, -3),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Color(0xFFCAD8E8),
                  offset: Offset(3, 3),
                  blurRadius: 7,
                  spreadRadius: 1,
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isDesktop ? handleItemTap : null,
          child: Padding(
            padding: const EdgeInsets.all(7),
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
                        // Image fills upper space
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDF3FA),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _buildPosProductImage(item),
                                ),
                              ),
                              // FoodType Badge (Top Right)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(2.5),
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
                                  top: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F2B48),
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
                                        const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 8.5),
                                        const SizedBox(width: 2),
                                        Text(
                                          '$qty',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.0,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (hasVariants)
                                Positioned(
                                  top: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F2B48).withValues(alpha: 0.88),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      '${item.variants.length} Variants',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.0,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                )
                              else if (isDiscounted && displayDiscountPct > 0)
                                Positioned(
                                  top: 4,
                                  left: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      '${displayDiscountPct.toStringAsFixed(0)}% OFF',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Product Name (2 Lines for full display)
                        Text(
                          item.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isDesktop ? 11.0 : 11.5,
                            color: const Color(0xFF0F172A),
                            height: 1.15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 2),

                        // Price Section
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (isDiscounted) ...[
                              Text(
                                '$currency${displaySalePrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: const Color(0xFF0F2B48),
                                  fontWeight: FontWeight.w900,
                                  fontSize: isDesktop ? 11.5 : 12.0,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$currency${displayOriginalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 9.0,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ] else ...[
                              Text(
                                '$currency${(hasVariants ? (firstVariant?.price ?? 0.0) : item.price).toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: const Color(0xFF0F2B48),
                                  fontWeight: FontWeight.w900,
                                  fontSize: isDesktop ? 11.5 : 12.0,
                                ),
                              ),
                            ],
                            if (hasVariants) ...[
                              const SizedBox(width: 3),
                              const Text(
                                'onwards',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 8.0,
                                  fontWeight: FontWeight.w500,
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
                          backgroundColor: const Color(0xFF0F2B48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: EdgeInsets.zero,
                          elevation: 0,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 15.0),
                              const SizedBox(width: 4),
                              Text(
                                qty > 0 ? '$qty Added' : 'Add',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.0),
                              ),
                            ],
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
                        iconSize: 16,
                        fontSize: 13.5,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: ElevatedButton(
                        onPressed: () => _addToCart(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F2B48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: EdgeInsets.zero,
                          elevation: 0,
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 15.0),
                              SizedBox(width: 4),
                              Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5)),
                            ],
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
    );
  }

  Widget _buildEmptyProductsIllustration() {
    return SizedBox(
      width: 175,
      height: 155,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. Soft Circular Background Halo with subtle gradient & shadow
          Container(
            width: 135,
            height: 135,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xFFEAF3FE),
                  Color(0xFFD8E9FE),
                  Color(0xFFC7DEFD),
                ],
                stops: [0.35, 0.75, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0038A8).withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),

          // 2. Floating decorative sparkle/bubbles
          Positioned(
            top: 24,
            left: 20,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF93C5FD).withValues(alpha: 0.8),
              ),
            ),
          ),
          Positioned(
            top: 36,
            right: 22,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF93C5FD).withValues(alpha: 0.6),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 16,
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF60A5FA).withValues(alpha: 0.75),
              ),
            ),
          ),
          Positioned(
            bottom: 22,
            right: 20,
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF93C5FD).withValues(alpha: 0.8),
              ),
            ),
          ),

          // 3. Sparkle burst rays above the box
          Positioned(
            top: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.rotate(
                  angle: -0.4,
                  child: Container(
                    width: 3,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 3,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Transform.rotate(
                  angle: 0.4,
                  child: Container(
                    width: 3,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Neumorphic 3D Open Food Box Container
          Positioned(
            bottom: 12,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // Open Lid Left Flap
                Positioned(
                  top: -10,
                  left: -6,
                  child: Transform.rotate(
                    angle: -0.28,
                    child: Container(
                      width: 28,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6FD),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        border: Border.all(color: const Color(0xFFD6E3F4), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF002266).withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(-2, -1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Open Lid Right Flap
                Positioned(
                  top: -10,
                  right: -6,
                  child: Transform.rotate(
                    angle: 0.28,
                    child: Container(
                      width: 28,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6FD),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        border: Border.all(color: const Color(0xFFD6E3F4), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF002266).withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(2, -1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Inner Box Cavity (Darker soft-blue/slate depth)
                Container(
                  width: 82,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD3E4F8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBDD4EE), width: 1.0),
                  ),
                ),
                // Main Box Front Body (Soft white-blue Neumorphic Cube)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 90,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFF4F8FD),
                        Color(0xFFE5EFFB),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDFECFB), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF002D80).withValues(alpha: 0.14),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.9),
                        blurRadius: 8,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4F0FD),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD3E5F9),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        color: Color(0xFF6287B8),
                        size: 20,
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
  }

  Widget _buildProductGrid(List<MenuItemModel> filteredItems, {bool isDesktop = false, required String currency}) {
    if (filteredItems.isEmpty) {
      final isSearching = _searchQuery.trim().isNotEmpty;
      final String titleText;
      final String subtitleText;

      if (isSearching) {
        titleText = 'No products found for "$_searchQuery"';
        subtitleText = 'Try searching with a different name or clear the search filter.';
      } else if (_selectedCategory != 'All') {
        titleText = 'No products found in this category';
        subtitleText = 'Start building your menu by adding your first item.';
      } else {
        titleText = 'No products found in this category';
        subtitleText = 'Start building your menu by adding your first item.';
      }

      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildEmptyProductsIllustration(),
              const SizedBox(height: 18),
              Text(
                titleText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0F1E36),
                  fontWeight: FontWeight.w800,
                  fontSize: 16.5,
                  letterSpacing: -0.2,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 290),
                child: Text(
                  subtitleText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF7E8EA4),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF003882).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _showAddItemDialog,
                  icon: const Icon(Icons.add_rounded, size: 19, color: Colors.white),
                  label: const Text(
                    'Add Your First Item',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      letterSpacing: 0.1,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00337A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              if (isSearching) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => setState(() => _searchQuery = ''),
                  icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF0066FF)),
                  label: const Text(
                    'Clear Search',
                    style: TextStyle(
                      color: Color(0xFF0066FF),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final bool showImages = (db.restaurant?.posViewMode ?? 'with_image') != 'without_image' &&
        (db.restaurant?.showItemImages ?? true);

    // ANDROID / MOBILE / TABLET: Grid layout for Without Images mode (Fully virtualized & recycled)
    if (!isDesktop && !showImages) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final double availableWidth = constraints.maxWidth;
          final int cols = ResponsiveLayoutHelper.getPosGridColumnCount(availableWidth, showImages: false);
          final double aspectRatio = ResponsiveLayoutHelper.getPosChildAspectRatio(availableWidth, false, false);

          return GridView.builder(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
            // ignore: deprecated_member_use
            cacheExtent: 600.0,
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 90),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: aspectRatio,
            ),
            itemCount: filteredItems.length,
            itemBuilder: (context, index) {
              final item = filteredItems[index];
              return _buildProductCard(
                item,
                showImages: false,
                currency: currency,
                isDesktop: false,
              );
            },
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final int columnCount = ResponsiveLayoutHelper.getPosGridColumnCount(constraints.maxWidth, showImages: showImages);
        final double aspectRatio = ResponsiveLayoutHelper.getPosChildAspectRatio(constraints.maxWidth, showImages, isDesktop);

        return GridView.builder(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          // ignore: deprecated_member_use
          cacheExtent: 600.0,
          padding: EdgeInsets.fromLTRB(4, 4, 4, isDesktop ? 10 : 90),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: aspectRatio,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return RepaintBoundary(
              key: ValueKey('prod_img_${item.id}_${item.productId}'),
              child: _buildProductCard(
                item,
                showImages: showImages,
                currency: currency,
                isDesktop: isDesktop,
              ),
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
        resizeToAvoidBottomInset: false,
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

    // ANDROID / MOBILE TOUCH LAYOUT (Neumorphism Design matching reference UI)
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFEAF1F8),
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

          // 4) VIEW CART FLOATING BUTTON & BAR (Mobile only - Neumorphic Capsule)
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
                  borderRadius: BorderRadius.circular(34),
                  child: Container(
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F9FE),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                      boxShadow: [
                        const BoxShadow(
                          color: Colors.white,
                          offset: Offset(-4, -4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: const Color(0xFFB8CCE4).withValues(alpha: 0.8),
                          offset: const Offset(4, 4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F2B48),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x330F2B48),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 1.2,
                          height: 26,
                          color: const Color(0xFFD6E2F0),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$totalCartItemCount ${totalCartItemCount == 1 ? "Item" : "Items"} Added',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Total: $currency ${cartTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F2B48),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x330F2B48),
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View Cart',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14.0,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                            ],
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
    final dialogWidth = math.min(screenWidth * 0.90, 420.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxWidth: 440, minWidth: 280),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8FC),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              offset: const Offset(0, 8),
              blurRadius: 24,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Cyan Icon Box, Title, and Circular Close (X) Button
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_add_alt_1_rounded,
                          color: Color(0xFF0F2B48),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Add Customer Details',
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // Mobile Number * Label
                RichText(
                  text: const TextSpan(
                    text: 'Mobile Number ',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    children: [
                      TextSpan(
                        text: '*',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Mobile Number Capsule Input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _phoneCtrl,
                    focusNode: _phoneFocusNode,
                    scrollPadding: const EdgeInsets.only(bottom: 90),
                    keyboardType: TextInputType.phone,
                    cursorColor: const Color(0xFF0F2B48),
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
                                  color: Color(0xFF0F2B48),
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
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),

                // Suggestions List
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0C000000),
                          offset: Offset(0, 3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
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
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE0F2FE),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person_rounded,
                                      size: 16,
                                      color: Color(0xFF0F2B48),
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
                                      color: const Color(0xFF0F2B48).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.touch_app_rounded, size: 12, color: Color(0xFF0F2B48)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Select',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F2B48),
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

                const SizedBox(height: 16),

                // Name (Optional) Label
                RichText(
                  text: const TextSpan(
                    text: 'Name ',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    children: [
                      TextSpan(
                        text: '(Optional)',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Name Capsule Input Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        offset: Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _nameCtrl,
                    focusNode: _nameFocusNode,
                    scrollPadding: const EdgeInsets.only(bottom: 90),
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    cursorColor: const Color(0xFF0F2B48),
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
                      prefixIcon: Container(
                        padding: const EdgeInsets.only(left: 14, right: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline_rounded, color: Color(0xFF0F2B48), size: 20),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Save Customer Button
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F2B48),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F2B48).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: const Text(
                      'Save Customer',
                      style: TextStyle(
                        fontSize: 15.5,
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

