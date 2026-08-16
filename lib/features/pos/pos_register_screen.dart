import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../core/models/menu_item_model.dart';
import '../../core/models/order_model.dart';
import '../../core/models/table_model.dart';
import '../../core/services/sound_service.dart';
import '../../core/widgets/food_type_icon.dart';
import '../menu/add_product_screen.dart';
import '../tables/table_management_screen.dart';
import 'payment_modal.dart';
import 'receipt_dialog.dart';
import 'kot_dialog.dart';

class PosRegisterScreen extends StatefulWidget {
  final String? initialTable;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenTablesTab;

  const PosRegisterScreen({
    super.key,
    this.initialTable,
    this.onOpenDrawer,
    this.onOpenTablesTab,
  });

  @override
  State<PosRegisterScreen> createState() => _PosRegisterScreenState();
}

class _PosRegisterScreenState extends State<PosRegisterScreen> {
  final db = DatabaseService();

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

  @override
  void initState() {
    super.initState();
    db.addListener(_onDbChange);
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
    if (widget.initialTable != null && (widget.initialTable != oldWidget.initialTable || widget.initialTable != _selectedTable)) {
      _loadCartForTable(widget.initialTable!, openCartModal: true);
    }
  }

  void _loadCartForTable(String tableName, {bool openCartModal = false}) {
    setState(() {
      _selectedTable = tableName;
      _selectedOrderType = OrderType.dineIn;
      _cartItems.clear();
      _discountAmount = 0.0;
      final activeOrder = db.orders.where((o) => o.tableNumber == tableName && (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)).firstOrNull;
      if (activeOrder != null) {
        _cartItems.addAll(activeOrder.items);
        _discountAmount = activeOrder.discountAmount;
      } else {
        final savedCart = db.getLiveTableCart(tableName);
        if (savedCart.isNotEmpty) {
          _cartItems.addAll(savedCart);
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
    final targetTable = _selectedOrderType == OrderType.dineIn ? (_selectedTable ?? 'T1') : 'Takeaway';

    // Check if table already has a Running KOT active order in DB
    final activeOrder = db.orders.where((o) =>
      ((o.tableNumber?.trim().toLowerCase() ?? '') == targetTable.trim().toLowerCase() ||
       'T-${o.tableNumber}'.toLowerCase() == targetTable.trim().toLowerCase()) &&
      (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
    ).firstOrNull;

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
            final tbl = db.tables.where((t) =>
              t.name.trim().toLowerCase() == targetTable.trim().toLowerCase() ||
              t.tableNumber.toString() == targetTable ||
              'T-${t.tableNumber}'.toLowerCase() == targetTable.trim().toLowerCase()
            ).firstOrNull;
            if (tbl != null) {
              db.updateTableStatus(tbl.id, TableStatus.runningKot, orderId: activeOrder.id);
            }
            if (setStateModal != null) setStateModal(() {});
            setState(() {});
          },
        ),
      );
      return;
    }

    final subtotalVal = _cartItems.fold<double>(0.0, (s, i) => s + (i.item.price * i.quantity));
    final taxVal = _cartItems.fold<double>(0.0, (s, i) => s + ((i.item.price * ((i.item.gstPercent ?? 0.0) / 100)) * i.quantity));

    // Preview OrderModel (Table status is NOT updated yet upon clicking KOT button)
    final tempOrder = OrderModel(
      id: 'KOT-${DateTime.now().millisecondsSinceEpoch}',
      orderNumber: 'KOT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      items: List.from(_cartItems),
      subtotal: subtotalVal,
      taxAmount: taxVal,
      totalAmount: cartTotal,
      tableNumber: targetTable,
      orderType: _selectedOrderType,
      discountAmount: _discountAmount,
      paymentMethod: 'KOT Pending',
      status: OrderStatus.preparing,
      createdAt: DateTime.now().toIso8601String(),
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
          // NOW save order to DB and update table status to Running KOT!
          final newOrder = await db.createOrder(
            items: List.from(_cartItems),
            tableNumber: targetTable,
            orderType: _selectedOrderType,
            discountAmount: _discountAmount,
            paymentMethod: 'KOT Pending',
            status: OrderStatus.preparing,
            customerName: _customerName,
            customerPhone: _customerPhone,
          );

          final tbl = db.tables.where((t) =>
            t.name.trim().toLowerCase() == targetTable.trim().toLowerCase() ||
            t.tableNumber.toString() == targetTable ||
            'T-${t.tableNumber}'.toLowerCase() == targetTable.trim().toLowerCase()
          ).firstOrNull;

          if (tbl != null) {
            db.updateTableStatus(tbl.id, TableStatus.runningKot, orderId: newOrder.id);
          }

          db.setLiveCartTotal(targetTable, newOrder.totalAmount);
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

        // Compute current cart total (subtotal)
        final cartTotal = _cartItems.fold<double>(
          0.0,
          (sum, e) => sum + (e.item.price * e.quantity),
        );

        // Save live table cart items & total in DB so table card and view button can load it
        db.setLiveTableCart(targetTable, _cartItems);
        db.setLiveCartTotal(targetTable, cartTotal - _discountAmount.clamp(0, cartTotal));

        final tbl = db.tables.where((t) => t.name == targetTable || t.tableNumber.toString() == targetTable).firstOrNull;
        if (tbl != null) {
          if (_cartItems.isNotEmpty && tbl.status == TableStatus.free) {
            db.updateTableStatus(tbl.id, TableStatus.occupied);
          } else if (_cartItems.isEmpty && tbl.status == TableStatus.occupied) {
            db.updateTableStatus(tbl.id, TableStatus.free);
          }
        }
      }
    }
  }

  void _addToCart(MenuItemModel item) {
    setState(() {
      final existingIndex = _cartItems.indexWhere((e) => e.item.id == item.id);
      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity++;
      } else {
        _cartItems.add(CartItemModel(item: item, quantity: 1));
      }
      _syncTableStatusWithCart();
    });
  }

  void _decrementCartItem(MenuItemModel item) {
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
  }

  int _getItemCartQuantity(MenuItemModel item) {
    return _cartItems
        .where((e) => e.item.id == item.id || e.item.id.startsWith('${item.id}_var_'))
        .fold(0, (sum, e) => sum + e.quantity);
  }

  void _showVariantsSelectionDialog(MenuItemModel item) {
    final currency = db.restaurant?.currencySymbol ?? '₹';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
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
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: item.variants.map((v) {
                      final effectivePrice = v.hasDiscount && v.discountPercent > 0
                          ? v.price * (1 - v.discountPercent / 100)
                          : v.price;

                      final variantId = '${item.id}_var_${v.name}';
                      final variantItem = MenuItemModel(
                        id: variantId,
                        name: '${item.name} (${v.name})',
                        category: item.category,
                        price: effectivePrice,
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
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        '$currency ${effectivePrice.toStringAsFixed(0)}',
                                        style: const TextStyle(color: Color(0xFF051C48), fontWeight: FontWeight.w900, fontSize: 13),
                                      ),
                                      if (v.hasDiscount && v.discountPercent > 0) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '$currency ${v.price.toStringAsFixed(0)}',
                                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, decoration: TextDecoration.lineThrough),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '(${v.discountPercent.toStringAsFixed(0)}% OFF)',
                                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Quantity Stepper for Variant (Matching Glassy Circular Buttons UI)
                            if (vQty > 0)
                              Container(
                                height: 30,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF051C48).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF051C48).withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        _decrementCartItem(variantItem);
                                        setModalState(() {});
                                        setState(() {});
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF051C48), Color(0xFF0A2B66)],
                                          ),
                                          border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
                                        ),
                                        child: const Icon(Icons.remove, size: 12, color: Colors.white),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        '$vQty',
                                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900, fontSize: 14),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        _addToCart(variantItem);
                                        setModalState(() {});
                                        setState(() {});
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF051C48), Color(0xFF0A2B66)],
                                          ),
                                          border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
                                        ),
                                        child: const Icon(Icons.add, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              SizedBox(
                                height: 30,
                                child: ElevatedButton(
                                  onPressed: () {
                                    _addToCart(variantItem);
                                    setModalState(() {});
                                    setState(() {});
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF051C48),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    elevation: 1,
                                  ),
                                  child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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

  int get totalCartItemCount => _cartItems.fold(0, (sum, i) => sum + i.quantity);
  double get cartSubtotal => _cartItems.fold(0.0, (sum, i) => sum + i.totalPrice);

  double get computedDiscountAmount {
    if (_discountAmount > 0) return _discountAmount;

    final subtotal = cartSubtotal;
    if (subtotal <= 0) return 0.0;

    double calculated = 0.0;

    // 1. Coupon Codes
    final coupon = _appliedCoupon.trim().toUpperCase();
    if (coupon == 'SAVE50') {
      return (subtotal * 0.50).clamp(0.0, subtotal);
    } else if (coupon == 'FLAT100') {
      return 100.0.clamp(0.0, subtotal);
    } else if (coupon == 'WELCOME10') {
      return (subtotal * 0.10).clamp(0.0, subtotal);
    } else if (coupon.isNotEmpty) {
      return 50.0.clamp(0.0, subtotal);
    }

    // 2. Manual Discount Input
    if (_discountInputValue > 0) {
      if (_selectedDiscountProductType == null ||
          _selectedDiscountProductType == 'Select Product Type' ||
          _selectedDiscountProductType == 'All Products') {
        if (_discountMode == 'percent') {
          calculated = subtotal * (_discountInputValue / 100.0);
        } else {
          calculated = _discountInputValue;
        }
      } else {
        double eligibleSubtotal = 0.0;
        final target = _selectedDiscountProductType!.toLowerCase();
        for (final cItem in _cartItems) {
          final itemType = cItem.item.itemType.toLowerCase();
          final category = cItem.item.category.toLowerCase();
          if (itemType == target || category == target || (target == 'food' && itemType != 'beverage')) {
            eligibleSubtotal += cItem.totalPrice;
          }
        }
        if (_discountMode == 'percent') {
          calculated = eligibleSubtotal * (_discountInputValue / 100.0);
        } else {
          calculated = math.min(_discountInputValue, eligibleSubtotal);
        }
      }
    }

    return calculated.clamp(0.0, subtotal);
  }

  double get cartTax {
    final subtotal = cartSubtotal;
    if (subtotal <= 0) return 0.0;

    final disc = computedDiscountAmount;
    final discountRatio = disc > 0 ? (1 - (disc / subtotal).clamp(0.0, 1.0)) : 1.0;
    double totalTax = 0.0;

    for (final cartItem in _cartItems) {
      final itemPriceAfterOrderDiscount = cartItem.totalPrice * discountRatio;
      final itemGst = cartItem.item.gstPercent ?? db.restaurant?.taxRate ?? 5.0;
      totalTax += itemPriceAfterOrderDiscount * (itemGst / 100.0);
    }
    return totalTax;
  }

  double get cartTotal => (cartSubtotal - computedDiscountAmount).clamp(0, 99999) + cartTax + _tipAmount;

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
      if (_selectedTable != null && _selectedTable!.isNotEmpty) {
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
      // Check if oldTable has a Running KOT active order
      final oldActiveOrder = db.orders.where((o) =>
        ((o.tableNumber?.trim().toLowerCase() ?? '') == oldTable.trim().toLowerCase() ||
         'T-${o.tableNumber}'.toLowerCase() == oldTable.trim().toLowerCase()) &&
        (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
      ).firstOrNull;

      final oldTbl = db.tables.where((t) =>
        t.name.trim().toLowerCase() == oldTable.trim().toLowerCase() ||
        t.tableNumber.toString() == oldTable ||
        'T-${t.tableNumber}'.toLowerCase() == oldTable.trim().toLowerCase()
      ).firstOrNull;

      final newTbl = db.tables.where((t) =>
        t.name.trim().toLowerCase() == newTableName.trim().toLowerCase() ||
        t.tableNumber.toString() == newTableName ||
        'T-${t.tableNumber}'.toLowerCase() == newTableName.trim().toLowerCase()
      ).firstOrNull;

      if (oldActiveOrder != null) {
        // 1. Move Running KOT order & products from oldTable to newTableName
        final orderIdx = db.orders.indexWhere((o) => o.id == oldActiveOrder.id);
        if (orderIdx != -1) {
          db.orders[orderIdx] = oldActiveOrder.copyWith(tableNumber: newTableName);
        }

        if (newTbl != null) {
          db.updateTableStatus(newTbl.id, TableStatus.runningKot, orderId: oldActiveOrder.id);
        }

        // Free Table A
        if (oldTbl != null) {
          db.updateTableStatus(oldTbl.id, TableStatus.free);
        }
        db.setLiveTableCart(oldTable, []);
        db.setLiveCartTotal(oldTable, 0);
      } else {
        // 2. Move draft cart products from oldTable to newTableName
        if (_cartItems.isNotEmpty) {
          db.setLiveTableCart(newTableName, List.from(_cartItems));
          db.setLiveCartTotal(newTableName, cartTotal);

          if (newTbl != null && newTbl.status == TableStatus.free) {
            db.updateTableStatus(newTbl.id, TableStatus.occupied);
          }
        }

        // Free Table A
        if (oldTbl != null) {
          db.updateTableStatus(oldTbl.id, TableStatus.free);
        }
        db.setLiveTableCart(oldTable, []);
        db.setLiveCartTotal(oldTable, 0);
      }
    }

    // Switch selected table
    _selectedTable = newTableName;
    _selectedOrderType = OrderType.dineIn;
    _cartItems.clear();
    _discountAmount = 0.0;

    // Load active order or live table cart for newly selected table
    final newActiveOrder = db.orders.where((o) =>
      ((o.tableNumber?.trim().toLowerCase() ?? '') == newTableName.trim().toLowerCase() ||
       'T-${o.tableNumber}'.toLowerCase() == newTableName.trim().toLowerCase()) &&
      (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)
    ).firstOrNull;

    if (newActiveOrder != null) {
      _cartItems.addAll(newActiveOrder.items);
      _discountAmount = newActiveOrder.discountAmount;
    } else {
      final savedCart = db.getLiveTableCart(newTableName);
      if (savedCart.isNotEmpty) {
        _cartItems.addAll(savedCart);
      }
    }

    db.setLiveTableCart(newTableName, List.from(_cartItems));
    db.setLiveCartTotal(newTableName, cartTotal);

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
    final nameCtrl = TextEditingController(text: _customerName);
    final phoneCtrl = TextEditingController(text: _customerPhone);

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF051C48).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_add_rounded, color: Color(0xFF051C48), size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Add Customer Info',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Customer Number',
                    labelStyle: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600, fontSize: 13),
                    hintText: 'Enter phone number',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF051C48)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF051C48), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: nameCtrl,
                  keyboardType: TextInputType.name,
                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Customer Name',
                    labelStyle: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600, fontSize: 13),
                    hintText: 'Enter customer name',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF051C48)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF051C48), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _customerName = nameCtrl.text.trim();
                            _customerPhone = phoneCtrl.text.trim();
                          });
                          setStateModal(() {});
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF051C48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
  }

  void _showExtraBenefitDialog(StateSetter setStateModal) {
    final couponCtrl = TextEditingController(text: _appliedCoupon);
    final discCtrl = TextEditingController(text: _discountInputValue > 0 ? _discountInputValue.toStringAsFixed(0) : '');
    final tipCtrl = TextEditingController(text: _tipAmount > 0 ? _tipAmount.toStringAsFixed(0) : '');

    String tempDiscountMode = _discountMode;
    String tempCoupon = _appliedCoupon;
    double tempDiscountVal = _discountInputValue;
    double tempTipVal = _tipAmount;

    showDialog(
      context: context,
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
                                      onPressed: () {
                                        setDialogState(() {
                                          tempCoupon = couponCtrl.text.trim();
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(tempCoupon.isNotEmpty ? 'Coupon "$tempCoupon" Applied!' : 'Coupon cleared.'),
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

                        // Table Icon Box
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.table_restaurant_rounded, color: Color(0xFF0284C7), size: 20),
                        ),
                        const SizedBox(width: 8),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                  setStateModal(() {
                                    _selectedOrderType = val;
                                  });
                                  setState(() {
                                    _selectedOrderType = val;
                                  });
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

                                    // Stepper (- QTY +)
                                    Container(
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF051C48),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF051C48).withValues(alpha: 0.2),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove, color: Colors.white, size: 15),
                                            constraints: const BoxConstraints(minWidth: 28, minHeight: 34),
                                            padding: EdgeInsets.zero,
                                            onPressed: () {
                                              _decrementCartItem(cItem.item);
                                              setStateModal(() {});
                                              setState(() {});
                                              _checkAndCloseEmptyCart(context, setStateModal);
                                            },
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6),
                                            child: Text(
                                              '${cItem.quantity}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add, color: Colors.white, size: 15),
                                            constraints: const BoxConstraints(minWidth: 28, minHeight: 34),
                                            padding: EdgeInsets.zero,
                                            onPressed: () {
                                              _addToCart(cItem.item);
                                              setStateModal(() {});
                                              setState(() {});
                                            },
                                          ),
                                        ],
                                      ),
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

                  // Bottom Action Buttons (KOT & Pay — Hold Button Removed as requested)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () async {
                                await _sendKotOrder(setStateModal);
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF051C48), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                backgroundColor: Colors.white,
                              ),
                              child: const Text(
                                'KOT',
                                style: TextStyle(color: Color(0xFF051C48), fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          flex: 2,
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
                                ),
                                child: const Text(
                                  'Pay',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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

  Future<void> _checkoutOrder({BuildContext? cartContext}) async {
    if (_cartItems.isEmpty) return;

    final currency = db.restaurant?.currencySymbol ?? '₹';
    final newOrder = await db.createOrder(
      items: List.from(_cartItems),
      tableNumber: _selectedOrderType == OrderType.dineIn ? (_selectedTable ?? 'T1') : 'Takeaway',
      orderType: _selectedOrderType,
      discountAmount: computedDiscountAmount,
      paymentMethod: 'Cash',
      customerName: _customerName,
      customerPhone: _customerPhone,
    );

    if (!mounted) return;

    final resultMethod = await showDialog<String>(
      context: context,
      builder: (_) => PaymentModal(
        order: newOrder,
        currency: currency,
      ),
    );

    if (resultMethod != null && resultMethod.isNotEmpty) {
      final targetTable = _selectedOrderType == OrderType.dineIn ? (_selectedTable ?? 'T1') : 'Takeaway';

      // Remove any existing active order for this table to prevent zombie KOT orders
      db.orders.removeWhere((o) =>
        ((o.tableNumber?.trim().toLowerCase() ?? '') == targetTable.trim().toLowerCase() ||
         'T-${o.tableNumber}'.toLowerCase() == targetTable.trim().toLowerCase()) &&
        (o.status == OrderStatus.pending || o.status == OrderStatus.preparing) &&
        o.id != newOrder.id
      );

      final completedOrder = newOrder.copyWith(paymentMethod: resultMethod);

      // AUTOMATICALLY UPDATE ORDER STATUS TO COMPLETED & SETTLE PAYMENT WHEN PAID
      await db.completeOrderPayment(completedOrder.id, resultMethod);

      final tbl = db.tables.where((t) =>
        t.name.trim().toLowerCase() == targetTable.trim().toLowerCase() ||
        t.tableNumber.toString() == targetTable ||
        'T-${t.tableNumber}'.toLowerCase() == targetTable.trim().toLowerCase()
      ).firstOrNull;

      if (tbl != null) {
        db.updateTableStatus(tbl.id, TableStatus.free);
      }
      db.setLiveTableCart(targetTable, []);
      db.setLiveCartTotal(targetTable, 0);

      // Close the cart screen modal ONLY when payment is successfully done
      if (cartContext != null && cartContext.mounted) {
        Navigator.pop(cartContext);
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => ReceiptDialog(order: completedOrder, currency: currency),
      );

      setState(() {
        _cartItems.clear();
        _discountAmount = 0.0;
        _tipAmount = 0.0;
        _appliedCoupon = '';
        _discountInputValue = 0.0;
        _selectedDiscountProductType = null;
        _selectedTable = null;
      });
    } else {
      // User cancelled the payment popup, delete the newly created pending order
      db.orders.removeWhere((o) => o.id == newOrder.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = db.restaurant?.currencySymbol ?? '₹';

    // Only display categories that have products assigned to them
    final categoriesWithProducts = db.categories.where((cat) {
      return db.menuItems.any((item) => item.category.trim().toLowerCase() == cat.trim().toLowerCase());
    }).toList();

    // Include any categories directly present in menuItems
    for (final item in db.menuItems) {
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

    final filteredItems = db.menuItems.where((item) {
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
              // 1) TOP ACTION BAR: "Tables" Button & Modified "Add Item" Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
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
                    // NEW "TABLES" BUTTON
                    SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
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
                        //icon: const Icon(Icons.table_restaurant_rounded, color: Colors.white, size: 16),
                        label: const Text('Tables', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // DECREASED SIZE "ADD ITEM" BUTTON (NO PLUS ICON)
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
                          final bool showImages = db.restaurant?.showItemImages ?? true;

                          return GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 90),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: showImages ? 0.60 : 0.88,
                            ),
                            itemCount: filteredItems.length,
                            itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final qty = _getItemCartQuantity(item);
                          final isSelected = qty > 0;

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
                                  if (showImages) ...[
                                    // Image fills remaining space (Expanded = no overflow)
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
                                              child: item.imageUrl.isNotEmpty
                                                  ? Image.file(
                                                      File(item.imageUrl),
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                      errorBuilder: (_, __, ___) => Center(child: Text(item.emoji, style: const TextStyle(fontSize: 22))),
                                                    )
                                                  : Center(child: Text(item.emoji, style: const TextStyle(fontSize: 22))),
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
                                          // Variants Badge (Top Left)
                                          if (item.variants.isNotEmpty)
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
                                                  '${item.variants.length} Variants',
                                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 4),

                                    // Product Name
                                    Text(
                                      item.name,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),

                                    // Price
                                    Text(
                                      '$currency ${(item.variants.isNotEmpty ? item.variants.first.price : item.price).toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF051C48)),
                                      textAlign: TextAlign.center,
                                    ),

                                    const SizedBox(height: 4),
                                  ] else ...[
                                    // Compact Text-Only View (Without Image)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildFoodTypeIcon(item.itemType),
                                        if (item.variants.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF051C48),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${item.variants.length} Var',
                                              style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          )
                                        else
                                          Container(
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
                                      ],
                                    ),
                                    const Spacer(),
                                    Text(
                                      item.name,
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), height: 1.15),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$currency ${(item.variants.isNotEmpty ? item.variants.first.price : item.price).toStringAsFixed(0)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF051C48)),
                                    ),
                                    const Spacer(),
                                  ],

                                  // Add Button or Quantity Stepper
                                  if (item.variants.isNotEmpty)
                                    SizedBox(
                                      width: double.infinity,
                                      height: 26,
                                      child: ElevatedButton(
                                        onPressed: () => _showVariantsSelectionDialog(item),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF051C48),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                                      height: 26,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => _decrementCartItem(item),
                                              child: Container(
                                                height: 26,
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [Color(0xFF051C48), Color(0xFF0A2B66)],
                                                  ),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(Icons.remove, size: 13, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Center(
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  '$qty',
                                                  style: const TextStyle(
                                                    color: Color(0xFF0F172A),
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () => _addToCart(item),
                                              child: Container(
                                                height: 26,
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [Color(0xFF051C48), Color(0xFF0A2B66)],
                                                  ),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(Icons.add, size: 13, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    SizedBox(
                                      width: double.infinity,
                                      height: 26,
                                      child: ElevatedButton(
                                        onPressed: () => _addToCart(item),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF051C48),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: EdgeInsets.zero,
                                          elevation: 0,
                                        ),
                                        child: const FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
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
