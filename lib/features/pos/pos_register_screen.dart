import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/database/database_service.dart';
import '../../core/models/menu_item_model.dart';
import '../../core/models/order_model.dart';
import '../../core/models/table_model.dart';
import 'payment_modal.dart';
import 'kot_dialog.dart';

class PosRegisterScreen extends StatefulWidget {
  final String? initialTable;

  const PosRegisterScreen({super.key, this.initialTable});

  @override
  State<PosRegisterScreen> createState() => _PosRegisterScreenState();
}

class _PosRegisterScreenState extends State<PosRegisterScreen> {
  final db = DatabaseService();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  // Cart State
  OrderType _selectedOrderType = OrderType.dineIn;
  String? _selectedTable;
  String? _deliveryAddressText;
  final List<CartItemModel> _cartItems = [];
  double _discountAmount = 0.0;
  final _discountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialTable != null) {
      _selectedTable = widget.initialTable;
    }
  }

  List<String> get allCategories {
    final activeCategories = db.categories.where((cat) => db.menuItems.any((item) => item.category == cat)).toList();
    return ['All', ...activeCategories];
  }

  List<MenuItemModel> get filteredItems {
    return db.menuItems.where((item) {
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _addToCart(MenuItemModel item) {
    setState(() {
      final existingIndex = _cartItems.indexWhere((element) => element.item.id == item.id);
      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity++;
      } else {
        _cartItems.add(CartItemModel(item: item, quantity: 1));
      }

      // Auto select sequence-wise free table & mark occupied for Dine-in
      if (_selectedOrderType == OrderType.dineIn) {
        if (_selectedTable == null) {
          final freeT = db.getNextAvailableTableSequence();
          if (freeT != null) {
            _selectedTable = freeT.name;
            db.updateTableStatus(freeT.id, TableStatus.occupied);
          }
        } else {
          final tMatch = db.tables.where((t) => t.name == _selectedTable).firstOrNull;
          if (tMatch != null && tMatch.status == TableStatus.free) {
            db.updateTableStatus(tMatch.id, TableStatus.occupied);
          }
        }
      }
    });
  }

  void _decrementCartItem(MenuItemModel item) {
    setState(() {
      final existingIndex = _cartItems.indexWhere((element) => element.item.id == item.id);
      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity--;
        if (_cartItems[existingIndex].quantity <= 0) {
          _cartItems.removeAt(existingIndex);
        }
      }
    });
  }

  int _getItemCartQuantity(MenuItemModel item) {
    final idx = _cartItems.indexWhere((e) => e.item.id == item.id);
    return idx >= 0 ? _cartItems[idx].quantity : 0;
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      _cartItems[index].quantity += delta;
      if (_cartItems[index].quantity <= 0) {
        _cartItems.removeAt(index);
      }
    });
  }

  double get cartSubtotal => _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get cartTax => (cartSubtotal - _discountAmount).clamp(0, 99999) * ((db.restaurant?.taxRate ?? 5.0) / 100.0);
  double get cartTotal => (cartSubtotal - _discountAmount).clamp(0, 99999) + cartTax;

  void _clearCart() {
    setState(() {
      _cartItems.clear();
      _discountAmount = 0.0;
      _deliveryAddressText = null;
      _discountController.clear();
    });
  }

  void _showAddDeliveryAddressDialog(StateSetter setStateModal) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: SingleChildScrollView(
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              borderRadius: 20,
              blurStrength: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.delivery_dining_rounded, color: GlassTheme.primaryCyan, size: 24),
                      SizedBox(width: 8),
                      Text('Customer Delivery Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GlassTextField(controller: nameCtrl, hintText: 'Customer Name', prefixIcon: Icons.person_outline),
                  const SizedBox(height: 10),
                  GlassTextField(controller: phoneCtrl, hintText: 'Phone Number', prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                  const SizedBox(height: 10),
                  GlassTextField(controller: addressCtrl, hintText: 'Full Address & Landmark', prefixIcon: Icons.home_outlined, maxLines: 2),
                  const SizedBox(height: 16),
                  GlassButton(
                    label: 'Save Address',
                    icon: Icons.check,
                    onPressed: () {
                      final full = '${nameCtrl.text.trim()} (${phoneCtrl.text.trim()}) - ${addressCtrl.text.trim()}';
                      if (addressCtrl.text.trim().isNotEmpty) {
                        setState(() => _deliveryAddressText = full);
                        setStateModal(() {});
                      }
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- DYNAMIC CATEGORY MODALS ---
  // --- FULL CART MODAL / SCREEN ---
  void _openCartModal() {
    final currency = db.restaurant?.currencySymbol ?? '₹';

    if (_selectedTable == null && _selectedOrderType == OrderType.dineIn) {
      final freeTables = db.tables.where((t) => t.status == TableStatus.free).toList();
      if (freeTables.isNotEmpty) {
        _selectedTable = freeTables.first.name;
      } else if (db.tables.isNotEmpty) {
        _selectedTable = db.tables.first.name;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return FractionallySizedBox(
              heightFactor: 0.88,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(22),
                      borderRadius: 24,
                      blurStrength: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      // Cart Modal Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.shopping_bag, color: GlassTheme.primaryCyan, size: 20),
                                const SizedBox(width: 6),
                                const Flexible(
                                  child: Text(
                                    'Order Cart',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GlassBadge(label: '${_cartItems.length}', color: GlassTheme.primaryViolet, fontSize: 10),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              if (_cartItems.isNotEmpty)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.delete_sweep, color: GlassTheme.accentRose, size: 16),
                                  label: const Text('Clear', style: TextStyle(color: GlassTheme.accentRose, fontSize: 11)),
                                  onPressed: () {
                                    _clearCart();
                                    Navigator.pop(context);
                                  },
                                ),
                              const SizedBox(width: 4),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Order Type Switcher
                      Row(
                        children: [
                          _buildModalOrderType(OrderType.dineIn, 'Dine-In', Icons.restaurant, setStateModal),
                          const SizedBox(width: 6),
                          _buildModalOrderType(OrderType.takeaway, 'Takeaway', Icons.takeout_dining, setStateModal),
                          const SizedBox(width: 6),
                          _buildModalOrderType(OrderType.delivery, 'Delivery', Icons.two_wheeler, setStateModal),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_selectedOrderType == OrderType.dineIn) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          decoration: BoxDecoration(
                            color: GlassTheme.glassInput,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: GlassTheme.glassBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedTable,
                              hint: const Text('Select Dine-In Table', style: TextStyle(color: GlassTheme.textMedium, fontSize: 13)),
                              dropdownColor: const Color(0xFF161233),
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down, color: GlassTheme.primaryCyan),
                              items: db.tables.map((t) {
                                return DropdownMenuItem<String>(
                                  value: t.name,
                                  child: Text('${t.name} (${t.capacity} Seats)', style: const TextStyle(color: Colors.white, fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) => setStateModal(() => _selectedTable = val),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (_selectedOrderType == OrderType.delivery) ...[
                        GlassCard(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_rounded, color: GlassTheme.primaryCyan, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _deliveryAddressText ?? 'No Delivery Address Added',
                                  style: TextStyle(
                                    color: _deliveryAddressText != null ? Colors.white : GlassTheme.textMedium,
                                    fontSize: 12,
                                    fontWeight: _deliveryAddressText != null ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GlassButton(
                                label: _deliveryAddressText == null ? 'Add Address' : 'Edit',
                                icon: Icons.edit_location_alt_rounded,
                                height: 30,
                                onPressed: () => _showAddDeliveryAddressDialog(setStateModal),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      const Divider(color: GlassTheme.glassBorder, height: 1),
                      const SizedBox(height: 8),

                      // Cart List
                      Expanded(
                        child: ListView.builder(
                          itemCount: _cartItems.length,
                          itemBuilder: (context, idx) {
                            final cItem = _cartItems[idx];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: GlassCard(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    Text(cItem.item.emoji, style: const TextStyle(fontSize: 22)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(cItem.item.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text('$currency${cItem.item.price.toStringAsFixed(0)} each', style: const TextStyle(color: GlassTheme.textMedium, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            _updateQuantity(idx, -1);
                                            setStateModal(() {});
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(color: GlassTheme.glassHover, borderRadius: BorderRadius.circular(6)),
                                            child: const Icon(Icons.remove, size: 14, color: Colors.white),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text('${cItem.quantity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                        ),
                                        InkWell(
                                          onTap: () {
                                            _updateQuantity(idx, 1);
                                            setStateModal(() {});
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(color: GlassTheme.primaryViolet, borderRadius: BorderRadius.circular(6)),
                                            child: const Icon(Icons.add, size: 14, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 10),
                                    Text('$currency${cItem.totalPrice.toStringAsFixed(0)}', style: const TextStyle(color: GlassTheme.accentNeonGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const Divider(color: GlassTheme.glassBorder, height: 1),
                      const SizedBox(height: 8),

                      _buildBillRow('Subtotal', '$currency${cartSubtotal.toStringAsFixed(2)}'),
                      _buildBillRow('GST Tax (${db.restaurant?.taxRate ?? 5.0}%)', '$currency${cartTax.toStringAsFixed(2)}'),
                      const SizedBox(height: 8),

                      GlassContainer(
                        padding: const EdgeInsets.all(12),
                        backgroundColor: GlassTheme.primaryViolet.withOpacity(0.2),
                        borderColor: GlassTheme.primaryViolet.withOpacity(0.6),
                        borderRadius: 14,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount Payable', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(
                              '$currency${cartTotal.toStringAsFixed(2)}',
                              style: TextStyle(color: GlassTheme.accentNeonGreen, fontWeight: FontWeight.w800, fontSize: 20),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: GlassButton(
                              label: 'Print KOT',
                              icon: Icons.soup_kitchen_outlined,
                              isPrimary: false,
                              onPressed: () {
                                final now = DateTime.now();
                                final tempOrder = OrderModel(
                                  id: 'TEMP-KOT',
                                  orderNumber: 'KOT-PREVIEW',
                                  tableNumber: _selectedOrderType == OrderType.dineIn ? _selectedTable : 'Takeaway',
                                  orderType: _selectedOrderType,
                                  status: OrderStatus.pending,
                                  items: List.from(_cartItems),
                                  subtotal: cartSubtotal,
                                  taxAmount: cartTax,
                                  totalAmount: cartTotal,
                                  paymentMethod: 'KOT',
                                  createdAt: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                                );
                                showDialog(
                                  context: context,
                                  builder: (_) => KotDialog(order: tempOrder),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GlassButton(
                              label: 'Hold Bill',
                              icon: Icons.pause_circle_outline,
                              isPrimary: false,
                              onPressed: () {
                                if (_cartItems.isEmpty) return;
                                final now = DateTime.now();
                                final year = now.year.toString();
                                final month = now.month.toString().padLeft(2, '0');
                                final day = now.day.toString().padLeft(2, '0');
                                final hour = now.hour.toString().padLeft(2, '0');
                                final min = now.minute.toString().padLeft(2, '0');
                                String tSuffix = 'TK';
                                if (_selectedTable != null && _selectedTable!.isNotEmpty) {
                                  final cleanNum = _selectedTable!.replaceAll(RegExp(r'[^0-9]'), '');
                                  tSuffix = cleanNum.isNotEmpty ? 'T$cleanNum' : _selectedTable!;
                                }
                                final heldOrder = OrderModel(
                                  id: 'HOLD-${DateTime.now().millisecondsSinceEpoch}',
                                  orderNumber: '$year$month$day-$hour$min-$tSuffix',
                                  tableNumber: _selectedOrderType == OrderType.dineIn ? _selectedTable : 'Takeaway',
                                  orderType: _selectedOrderType,
                                  status: OrderStatus.pending,
                                  items: List.from(_cartItems),
                                  subtotal: cartSubtotal,
                                  taxAmount: cartTax,
                                  totalAmount: cartTotal,
                                  paymentMethod: 'Hold',
                                  createdAt: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                                );
                                db.holdOrder(heldOrder);
                                _clearCart();
                                Navigator.pop(context);
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Bill put on hold successfully!'),
                                    backgroundColor: GlassTheme.accentAmber,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GlassButton(
                              label: 'Pay Bill',
                              icon: Icons.payments_rounded,
                              isPrimary: true,
                              onPressed: () {
                                Navigator.pop(context);
                                _proceedToCheckout();
                              },
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
);
}

  Widget _buildModalOrderType(OrderType type, String title, IconData icon, StateSetter setStateModal) {
    final isSel = _selectedOrderType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedOrderType = type);
          setStateModal(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? GlassTheme.primaryViolet.withOpacity(0.3) : GlassTheme.glassInput,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSel ? GlassTheme.primaryViolet : GlassTheme.glassBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSel ? GlassTheme.primaryCyan : GlassTheme.textMedium),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(color: isSel ? Colors.white : GlassTheme.textMedium, fontSize: 11, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _proceedToCheckout() async {
    if (_cartItems.isEmpty) return;

    if (_selectedOrderType == OrderType.dineIn && _selectedTable == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Table for Dine-In order!')),
      );
      return;
    }

    final currency = db.restaurant?.currencySymbol ?? '₹';

    final createdOrder = await db.createOrder(
      items: List.from(_cartItems),
      tableNumber: _selectedOrderType == OrderType.dineIn ? _selectedTable : 'Takeaway',
      orderType: _selectedOrderType,
      discountAmount: _discountAmount,
      paymentMethod: 'UPI',
      deliveryAddress: _selectedOrderType == OrderType.delivery ? _deliveryAddressText : null,
    );

    if (!mounted) return;

    _clearCart();

    showDialog(
      context: context,
      builder: (_) => PaymentModal(
        order: createdOrder,
        currency: currency,
      ),
    );
  }

  void _showHoldBillsModal() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650, maxHeight: 600),
            child: GlassContainer(
              padding: const EdgeInsets.all(22),
              borderRadius: 22,
              blurStrength: 24,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.pause_circle_filled, color: GlassTheme.accentAmber, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Hold Bills (${db.holdOrders.length})',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: GlassTheme.textMedium),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: GlassTheme.glassBorder, height: 1),
                  const SizedBox(height: 12),

                  Expanded(
                    child: db.holdOrders.isEmpty
                        ? const Center(
                            child: Text('No bills currently on hold', style: TextStyle(color: GlassTheme.textMedium)),
                          )
                        : ListView.builder(
                            itemCount: db.holdOrders.length,
                            itemBuilder: (context, idx) {
                              final order = db.holdOrders[idx];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: GlassContainer(
                                  padding: const EdgeInsets.all(14),
                                  borderRadius: 14,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Order: ${order.orderNumber} • ${order.tableNumber ?? "Takeaway"}',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Items: ${order.items.map((e) => "${e.quantity}x ${e.item.name}").join(", ")}',
                                              style: const TextStyle(color: GlassTheme.textMedium, fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Time: ${order.createdAt} • Total: ₹${order.totalAmount.toStringAsFixed(2)}',
                                              style: const TextStyle(color: GlassTheme.accentNeonGreen, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GlassButton(
                                        label: 'Unhold & Resume',
                                        icon: Icons.play_arrow_rounded,
                                        onPressed: () {
                                          final unheld = db.unholdOrder(order.id);
                                          if (unheld != null) {
                                            setState(() {
                                              _cartItems.clear();
                                              _cartItems.addAll(unheld.items);
                                              _selectedTable = unheld.tableNumber;
                                              _selectedOrderType = unheld.orderType;
                                            });
                                          }
                                          Navigator.pop(context);
                                        },
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
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: db,
      builder: (context, _) {
        final currency = db.restaurant?.currencySymbol ?? '₹';

        return SafeArea(
          child: Stack(
            children: [
          Column(
            children: [
              // Search and Categories Bar
              GlassContainer(
                padding: const EdgeInsets.all(12),
                borderRadius: 16,
                blurStrength: 14,
                child: Column(
                  children: [
                    // Search Bar & Hold Bills Quick Button
                    Row(
                      children: [
                        if (db.holdOrders.isNotEmpty) ...[
                          GestureDetector(
                            onTap: _showHoldBillsModal,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: GlassTheme.accentAmber.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: GlassTheme.accentAmber),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.pause_circle_filled, color: GlassTheme.accentAmber, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Hold Bills (${db.holdOrders.length})',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: GlassTextField(
                            hintText: 'Search product or category...',
                            prefixIcon: Icons.search_rounded,
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Categories Bar
                    SizedBox(
                      height: 36,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: allCategories.length,
                        itemBuilder: (context, idx) {
                          final cat = allCategories[idx];
                          final isSel = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(cat),
                              labelStyle: TextStyle(
                                color: isSel ? Colors.white : GlassTheme.textMedium,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                fontSize: 12,
                              ),
                              selected: isSel,
                              selectedColor: GlassTheme.primaryViolet,
                              backgroundColor: GlassTheme.glassInput,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide(
                                color: isSel ? GlassTheme.primaryViolet : GlassTheme.glassBorder,
                              ),
                              onSelected: (_) => setState(() => _selectedCategory = cat),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Dynamic Compact Products Grid
              Expanded(
                child: filteredItems.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.no_food_outlined, color: GlassTheme.textLow, size: 44),
                            SizedBox(height: 8),
                            Text('No products found', style: TextStyle(color: GlassTheme.textMedium)),
                            SizedBox(height: 4),
                            Text('Go to Menu & Category to add products', style: TextStyle(color: GlassTheme.textLow, fontSize: 12)),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 145,
                          childAspectRatio: 0.68,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, idx) {
                          final dish = filteredItems[idx];
                          return _buildDishCard(dish, currency);
                        },
                      ),
              ),
            ],
          ),

          // FLOATING "VIEW CART" BUTTON (ENABLED WHEN ITEMS IN CART)
          if (_cartItems.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: GestureDetector(
                onTap: _openCartModal,
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  borderRadius: 20,
                  blurStrength: 24,
                  backgroundColor: GlassTheme.primaryViolet.withOpacity(0.85),
                  borderColor: GlassTheme.primaryCyan,
                  boxShadow: [
                    BoxShadow(
                      color: GlassTheme.primaryViolet.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_cartItems.fold(0, (sum, i) => sum + i.quantity)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'View Cart Order',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$currency${cartTotal.toStringAsFixed(2)}',
                        style: TextStyle(color: GlassTheme.accentNeonGreen, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildDishCard(MenuItemModel dish, String currency) {
    final hasImage = dish.imageUrl.isNotEmpty;
    final inCartQty = _getItemCartQuantity(dish);

    return GlassCard(
      padding: const EdgeInsets.all(8),
      onTap: inCartQty == 0 ? () => _addToCart(dish) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: hasImage
                    ? Image.network(
                        dish.imageUrl,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildFallbackEmoji(dish.emoji),
                      )
                    : _buildFallbackEmoji(dish.emoji),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currency${dish.price.toStringAsFixed(0)}',
                    style: const TextStyle(color: GlassTheme.accentNeonGreen, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  if (dish.stockQuantity <= 10)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: GlassTheme.accentRose.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: GlassTheme.accentRose.withOpacity(0.5)),
                      ),
                      child: Text(
                        '${dish.stockQuantity} left',
                        style: const TextStyle(color: GlassTheme.accentRose, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            dish.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            dish.category,
            style: const TextStyle(color: GlassTheme.textMedium, fontSize: 9),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Bottom Action Row: Inline Stepper or Prominent ADD button
          if (inCartQty > 0)
            Container(
              height: 26,
              decoration: BoxDecoration(
                color: GlassTheme.primaryViolet.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GlassTheme.primaryViolet),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => _decrementCartItem(dish),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Icon(Icons.remove, size: 14, color: Colors.white),
                    ),
                  ),
                  Text(
                    '$inCartQty',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  InkWell(
                    onTap: () => _addToCart(dish),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Icon(Icons.add, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: () => _addToCart(dish),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  gradient: GlassTheme.primaryButtonGradient,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: GlassTheme.primaryViolet.withOpacity(0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_shopping_cart, size: 12, color: Colors.white),
                    SizedBox(width: 3),
                    Text('ADD', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFallbackEmoji(String emoji) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: GlassTheme.glassInput,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    );
  }

  Widget _buildBillRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: GlassTheme.textMedium, fontSize: 11)),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
