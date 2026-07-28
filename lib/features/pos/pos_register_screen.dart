import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/database/database_service.dart';
import '../../core/models/menu_item_model.dart';
import '../../core/models/order_model.dart';
import '../../core/models/table_model.dart';
import 'payment_modal.dart';

class PosRegisterScreen extends StatefulWidget {
  const PosRegisterScreen({super.key});

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
  final List<CartItemModel> _cartItems = [];
  double _discountAmount = 0.0;
  final _discountController = TextEditingController();

  List<String> get allCategories => ['All', ...db.categories];

  List<MenuItemModel> get filteredItems {
    return db.menuItems.where((item) {
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _addToCart(MenuItemModel item) {
    if (!item.isAvailable || item.stockQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.name} is out of stock!')),
      );
      return;
    }

    setState(() {
      final existingIndex = _cartItems.indexWhere((c) => c.item.id == item.id);
      if (existingIndex >= 0) {
        _cartItems[existingIndex].quantity++;
      } else {
        _cartItems.add(CartItemModel(item: item, quantity: 1));
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${item.name} to cart!'),
        duration: const Duration(seconds: 1),
        backgroundColor: GlassTheme.primaryViolet,
      ),
    );
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
      _discountController.clear();
    });
  }

  // --- DYNAMIC CATEGORY MODALS ---
  void _showAddCategoryModal() {
    final catCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: GlassContainer(
          padding: const EdgeInsets.all(20),
          borderRadius: 20,
          blurStrength: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add New Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 14),
              GlassTextField(controller: catCtrl, labelText: 'Category Name', hintText: 'e.g. Starters, Smoothies'),
              const SizedBox(height: 18),
              GlassButton(
                label: 'Add Category',
                icon: Icons.check,
                onPressed: () {
                  if (catCtrl.text.trim().isNotEmpty) {
                    db.addCategory(catCtrl.text.trim());
                    setState(() {});
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManageCategoriesModal() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: 20,
            blurStrength: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Manage Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    IconButton(icon: const Icon(Icons.close, color: GlassTheme.textMedium), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 240,
                  child: ListView.builder(
                    itemCount: db.categories.length,
                    itemBuilder: (context, idx) {
                      final cat = db.categories[idx];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(child: Text(cat, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: GlassTheme.primaryCyan, size: 18),
                                onPressed: () {
                                  final editCtrl = TextEditingController(text: cat);
                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      backgroundColor: Colors.transparent,
                                      content: GlassContainer(
                                        padding: const EdgeInsets.all(18),
                                        borderRadius: 18,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text('Edit Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 10),
                                            GlassTextField(controller: editCtrl, hintText: 'Name'),
                                            const SizedBox(height: 14),
                                            GlassButton(
                                              label: 'Update',
                                              onPressed: () {
                                                db.editCategory(cat, editCtrl.text.trim());
                                                setState(() {});
                                                Navigator.pop(context);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: GlassTheme.accentRose, size: 18),
                                onPressed: () {
                                  db.deleteCategory(cat);
                                  setState(() {});
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
      ),
    );
  }

  // --- DYNAMIC PRODUCT MODALS ---
  void _showAddEditProductModal([MenuItemModel? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? (_selectedCategory == 'All' ? 'Main Course' : _selectedCategory));
    final priceCtrl = TextEditingController(text: existing?.price.toString() ?? '150');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '🍱');
    final stockCtrl = TextEditingController(text: existing?.stockQuantity.toString() ?? '50');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: GlassContainer(
              padding: const EdgeInsets.all(22),
              borderRadius: 22,
              blurStrength: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existing == null ? 'Add Product to POS' : 'Edit Product',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      IconButton(icon: const Icon(Icons.close, color: GlassTheme.textMedium), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  GlassTextField(controller: nameCtrl, labelText: 'Product Name', hintText: 'Paneer Butter Masala'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: GlassTextField(controller: catCtrl, labelText: 'Category', hintText: 'Main Course')),
                      const SizedBox(width: 10),
                      Expanded(child: GlassTextField(controller: emojiCtrl, labelText: 'Emoji Icon', hintText: '🥘')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: GlassTextField(controller: priceCtrl, labelText: 'Price', hintText: '190', keyboardType: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: GlassTextField(controller: stockCtrl, labelText: 'Stock Qty', hintText: '50', keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GlassTextField(controller: descCtrl, labelText: 'Description', hintText: 'Tasty dish ingredients', maxLines: 2),

                  const SizedBox(height: 20),
                  GlassButton(
                    label: existing == null ? 'Save Product' : 'Update Product',
                    icon: Icons.check,
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) return;

                      final newItem = MenuItemModel(
                        id: existing?.id ?? 'prod_${DateTime.now().millisecondsSinceEpoch}',
                        name: nameCtrl.text.trim(),
                        category: catCtrl.text.trim(),
                        price: double.tryParse(priceCtrl.text) ?? 100.0,
                        description: descCtrl.text.trim(),
                        emoji: emojiCtrl.text.trim().isEmpty ? '🍲' : emojiCtrl.text.trim(),
                        stockQuantity: int.tryParse(stockCtrl.text) ?? 50,
                        isAvailable: existing?.isAvailable ?? true,
                      );

                      await db.saveMenuItem(newItem);
                      if (!mounted) return;
                      setState(() {});
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

  // --- FULL CART MODAL / SCREEN ---
  void _openCartModal() {
    final currency = db.restaurant?.currencySymbol ?? '₹';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return FractionallySizedBox(
              heightFactor: 0.85,
              child: Container(
                margin: const EdgeInsets.all(12),
                child: GlassContainer(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 24,
                  blurStrength: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cart Modal Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shopping_bag, color: GlassTheme.primaryCyan, size: 24),
                              const SizedBox(width: 8),
                              const Text(
                                'Order Cart Details',
                                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              GlassBadge(label: '${_cartItems.length} items', color: GlassTheme.primaryViolet),
                            ],
                          ),
                          Row(
                            children: [
                              if (_cartItems.isNotEmpty)
                                TextButton.icon(
                                  icon: const Icon(Icons.delete_sweep, color: GlassTheme.accentRose, size: 18),
                                  label: const Text('Clear', style: TextStyle(color: GlassTheme.accentRose)),
                                  onPressed: () {
                                    _clearCart();
                                    Navigator.pop(context);
                                  },
                                ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white),
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

                      GlassButton(
                        label: 'Proceed to Checkout & Pay',
                        icon: Icons.payments_rounded,
                        onPressed: () {
                          Navigator.pop(context);
                          _proceedToCheckout();
                        },
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
              Text(title, style: TextStyle(color: isSel ? Colors.white : GlassTheme.textMedium, fontSize: 11, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final currency = db.restaurant?.currencySymbol ?? '₹';

    return SafeArea(
      child: Stack(
        children: [
          Column(
            children: [
              // Search, Categories, and Action Buttons Bar
              GlassContainer(
                padding: const EdgeInsets.all(12),
                borderRadius: 16,
                blurStrength: 14,
                child: Column(
                  children: [
                    // Search Bar & Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GlassTextField(
                            hintText: 'Search product or category...',
                            prefixIcon: Icons.search_rounded,
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.category_rounded, color: GlassTheme.primaryCyan, size: 22),
                          tooltip: 'Manage Categories',
                          onPressed: _showManageCategoriesModal,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_box_rounded, color: GlassTheme.primaryViolet, size: 24),
                          tooltip: 'Add New Product',
                          onPressed: () => _showAddEditProductModal(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Categories Bar with + Add Category pill
                    SizedBox(
                      height: 36,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: allCategories.length + 1,
                        itemBuilder: (context, idx) {
                          if (idx == allCategories.length) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: ActionChip(
                                avatar: const Icon(Icons.add, size: 14, color: GlassTheme.primaryCyan),
                                label: const Text('New Category', style: TextStyle(color: GlassTheme.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold)),
                                backgroundColor: GlassTheme.glassInput,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: GlassTheme.primaryCyan.withOpacity(0.5)),
                                onPressed: _showAddCategoryModal,
                              ),
                            );
                          }

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

              // Dynamic Products Grid
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.no_food_outlined, color: GlassTheme.textLow, size: 44),
                            const SizedBox(height: 8),
                            const Text('No products found', style: TextStyle(color: GlassTheme.textMedium)),
                            const SizedBox(height: 12),
                            GlassButton(
                              label: 'Add Product to Store',
                              icon: Icons.add,
                              width: 180,
                              height: 38,
                              onPressed: () => _showAddEditProductModal(),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          childAspectRatio: 0.82,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'View Cart Order',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5),
                      ),
                      const Spacer(),
                      Text(
                        '$currency${cartTotal.toStringAsFixed(2)}',
                        style: TextStyle(color: GlassTheme.accentNeonGreen, fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDishCard(MenuItemModel dish, String currency) {
    return GlassCard(
      padding: const EdgeInsets.all(10),
      onTap: () => _addToCart(dish),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dish.emoji, style: const TextStyle(fontSize: 26)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: GlassTheme.primaryCyan, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Edit Product',
                    onPressed: () => _showAddEditProductModal(dish),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: GlassTheme.accentRose, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Delete Product',
                    onPressed: () async {
                      await db.deleteMenuItem(dish.id);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Text(
            dish.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            dish.category,
            style: const TextStyle(color: GlassTheme.textMedium, fontSize: 10),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$currency${dish.price.toStringAsFixed(0)}',
                style: const TextStyle(color: GlassTheme.accentNeonGreen, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: GlassTheme.primaryButtonGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_shopping_cart, size: 12, color: Colors.white),
                    SizedBox(width: 2),
                    Text('ADD', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
