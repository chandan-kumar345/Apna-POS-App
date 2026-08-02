import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/database/database_service.dart';
import '../../core/models/menu_item_model.dart';
import '../../core/models/order_model.dart';
import '../../core/models/table_model.dart';
import '../menu/add_product_screen.dart';
import '../tables/table_management_screen.dart';
import 'payment_modal.dart';
import 'receipt_dialog.dart';
import 'kot_dialog.dart';
import '../../core/widgets/glass_company_name_badge.dart';

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
  String _customerPhone = '';
  String _customerName = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialTable != null) {
      _loadCartForTable(widget.initialTable!);
    }
  }

  @override
  void didUpdateWidget(PosRegisterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTable != null && widget.initialTable != oldWidget.initialTable && widget.initialTable != _selectedTable) {
      _loadCartForTable(widget.initialTable!);
    }
  }

  void _loadCartForTable(String tableName) {
    setState(() {
      _selectedTable = tableName;
      _selectedOrderType = OrderType.dineIn;
      _cartItems.clear();
      _discountAmount = 0.0;
      final activeOrder = db.orders.where((o) => o.tableNumber == tableName && (o.status == OrderStatus.pending || o.status == OrderStatus.preparing)).firstOrNull;
      if (activeOrder != null) {
        _cartItems.addAll(activeOrder.items);
        _discountAmount = activeOrder.discountAmount;
      }
    });
  }

  Future<void> _sendKotOrder() async {
    if (_cartItems.isEmpty) return;

    final targetTable = _selectedOrderType == OrderType.dineIn ? (_selectedTable ?? 'T1') : 'Takeaway';

    final newOrder = await db.createOrder(
      items: List.from(_cartItems),
      tableNumber: targetTable,
      orderType: _selectedOrderType,
      discountAmount: _discountAmount,
      paymentMethod: 'KOT Pending',
      status: OrderStatus.preparing,
    );

    final tbl = db.tables.where((t) => t.name == targetTable || t.tableNumber.toString() == targetTable).firstOrNull;
    if (tbl != null) {
      db.updateTableStatus(tbl.id, TableStatus.runningKot, orderId: newOrder.id);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => KotDialog(order: newOrder),
    );

    // Clear live cart total - order is now in DB
    db.setLiveCartTotal(targetTable, 0);

    // PRESERVE CART ITEMS SO PRODUCTS STAY IN CART UNTIL NEW TABLE IS SELECTED OR PAID
    setState(() {});
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

        // Publish live cart total to DB so table card shows it immediately
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
  double get cartTax {
    final subtotal = cartSubtotal;
    if (subtotal <= 0) return 0.0;

    final discountRatio = _discountAmount > 0 ? (1 - (_discountAmount / subtotal).clamp(0.0, 1.0)) : 1.0;
    double totalTax = 0.0;

    for (final cartItem in _cartItems) {
      final itemPriceAfterOrderDiscount = cartItem.totalPrice * discountRatio;
      final itemGst = cartItem.item.gstPercent ?? db.restaurant?.taxRate ?? 5.0;
      totalTax += itemPriceAfterOrderDiscount * (itemGst / 100.0);
    }
    return totalTax;
  }
  double get cartTotal => (cartSubtotal - _discountAmount).clamp(0, 99999) + cartTax;

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

  void _showDiscountDialog(StateSetter setStateModal) {
    final discCtrl = TextEditingController(text: _discountAmount > 0 ? _discountAmount.toStringAsFixed(0) : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Apply Order Discount', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Quick Discount (%):', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [5, 10, 15, 20, 25].map((pct) {
                final calcAmt = (cartSubtotal * pct / 100).roundToDouble();
                return ChoiceChip(
                  label: Text('$pct%'),
                  selected: false,
                  backgroundColor: const Color(0xFFF1F5F9),
                  labelStyle: const TextStyle(color: Color(0xFF051C48), fontWeight: FontWeight.bold),
                  onSelected: (_) {
                    discCtrl.text = calcAmt.toStringAsFixed(0);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: discCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Discount Amount (${db.restaurant?.currencySymbol ?? "₹"})',
                prefixIcon: const Icon(Icons.discount_outlined, color: Color(0xFF051C48)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF051C48), width: 2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _discountAmount = 0.0);
              setStateModal(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Color(0xFFEF4444))),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(discCtrl.text.trim()) ?? 0.0;
              setState(() => _discountAmount = val);
              setStateModal(() {});
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF051C48)),
            child: const Text('Apply Discount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
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
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 30, offset: Offset(0, -10)),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_bag_outlined, color: Color(0xFF051C48)),
                        const SizedBox(width: 8),
                        const Text(
                          'Your Order Cart',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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

                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _cartItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final cItem = _cartItems[idx];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Text(cItem.item.emoji, style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(cItem.item.name, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text('$currency ${cItem.item.price.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF051C48), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF051C48), size: 20),
                                    onPressed: () {
                                      _decrementCartItem(cItem.item);
                                      setStateModal(() {});
                                      setState(() {});
                                    },
                                  ),
                                  Text('${cItem.quantity}', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF051C48), size: 20),
                                    onPressed: () {
                                      _addToCart(cItem.item);
                                      setStateModal(() {});
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Order Summary with Discount Flow
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, -4))],
                    ),
                    child: Column(
                      children: [
                        // Subtotal
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:', style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B))),
                            Text('$currency ${cartSubtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Discount Row with Interactive Apply Discount
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text('Discount: ', style: TextStyle(fontSize: 13.5, color: Color(0xFF64748B))),
                                InkWell(
                                  onTap: () => _showDiscountDialog(setStateModal),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF051C48).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF051C48).withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      _discountAmount > 0 ? 'Edit Discount' : '+ Add Discount',
                                      style: const TextStyle(color: Color(0xFF051C48), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '- $currency ${_discountAmount.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: _discountAmount > 0 ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // GST Tax Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Tax (${db.restaurant?.taxRate ?? 5.0}%):', style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B))),
                            Text('+ $currency ${cartTax.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(color: Color(0xFFE2E8F0), height: 1),
                        ),

                        // Final Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            Text('$currency ${cartTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF051C48))),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            // Send KOT Button (Red Color for Running KOT)
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    await _sendKotOrder();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 2,
                                  ),
                                  //icon: const Icon(Icons.soup_kitchen_rounded, color: Colors.white, size: 18),
                                  label: const Text('KOT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Proceed to Checkout
                            Expanded(
                              flex: 1,
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _checkoutOrder();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF051C48),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 2,
                                  ),
                                  child: const Text('Checkout', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                ),
                              ),
                            ),
                          ],
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



  Future<void> _checkoutOrder() async {
    if (_cartItems.isEmpty) return;

    final currency = db.restaurant?.currencySymbol ?? '₹';
    final newOrder = await db.createOrder(
      items: List.from(_cartItems),
      tableNumber: _selectedOrderType == OrderType.dineIn ? (_selectedTable ?? 'T1') : 'Takeaway',
      orderType: _selectedOrderType,
      discountAmount: _discountAmount,
      paymentMethod: 'Cash',
    );

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => PaymentModal(
        order: newOrder,
        currency: currency,
      ),
    );

    if (result == true) {
      // AUTOMATICALLY UPDATE ORDER STATUS TO COMPLETED WHEN PAID
      db.updateOrderStatus(newOrder.id, OrderStatus.completed);

      final targetTable = _selectedOrderType == OrderType.dineIn ? (_selectedTable ?? 'T1') : 'Takeaway';
      final tbl = db.tables.where((t) => t.name == targetTable).firstOrNull;
      if (tbl != null) {
        db.updateTableStatus(tbl.id, TableStatus.free);
      }

      showDialog(
        context: context,
        builder: (_) => ReceiptDialog(order: newOrder, currency: currency),
      );

      setState(() {
        _cartItems.clear();
        _discountAmount = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = db.restaurant?.currencySymbol ?? '₹';
    final allCategories = ['All', ...db.categories];
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
                    : GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(10, 6, 10, 90),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.60,
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
                                                '${item.variants.length}V',
                                                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
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
                                    '$currency ${item.price.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF051C48)),
                                    textAlign: TextAlign.center,
                                  ),

                                  const SizedBox(height: 4),

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
