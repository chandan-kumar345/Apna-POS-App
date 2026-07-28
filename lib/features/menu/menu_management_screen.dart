import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/database/database_service.dart';
import '../../core/models/menu_item_model.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final db = DatabaseService();
  int _selectedTab = 0; // 0: Products, 1: Categories

  void _showAddEditDishModal([MenuItemModel? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? 'Main Course');
    final priceCtrl = TextEditingController(text: existing?.price.toString() ?? '150');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '🍱');
    final stockCtrl = TextEditingController(text: existing?.stockQuantity.toString() ?? '50');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
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
                        existing == null ? 'Add New Product' : 'Edit Product',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      IconButton(icon: const Icon(Icons.close, color: GlassTheme.textMedium), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  GlassTextField(controller: nameCtrl, labelText: 'Product Name', hintText: 'e.g. Paneer Butter Masala'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: GlassTextField(controller: catCtrl, labelText: 'Category', hintText: 'Main Course')),
                      const SizedBox(width: 10),
                      Expanded(child: GlassTextField(controller: emojiCtrl, labelText: 'Emoji Icon', hintText: '🧆')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: GlassTextField(controller: priceCtrl, labelText: 'Price', hintText: '190', keyboardType: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: GlassTextField(controller: stockCtrl, labelText: 'Initial Stock Qty', hintText: '50', keyboardType: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GlassTextField(controller: descCtrl, labelText: 'Short Description', hintText: 'Description of ingredients and taste', maxLines: 2),

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
              GlassTextField(controller: catCtrl, labelText: 'Category Name', hintText: 'e.g. Starters, Milkshakes'),
              const SizedBox(height: 18),
              GlassButton(
                label: 'Save Category',
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

  @override
  Widget build(BuildContext context) {
    final currency = db.restaurant?.currencySymbol ?? '₹';

    return SafeArea(
      child: Column(
        children: [
          // Action & Tab Bar
          GlassContainer(
            padding: const EdgeInsets.all(12),
            borderRadius: 16,
            blurStrength: 12,
            child: Row(
              children: [
                // Tab Selector
                Row(
                  children: [
                    ChoiceChip(
                      label: Text('Products (${db.menuItems.length})'),
                      selected: _selectedTab == 0,
                      selectedColor: GlassTheme.primaryViolet,
                      backgroundColor: GlassTheme.glassInput,
                      onSelected: (_) => setState(() => _selectedTab = 0),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Categories (${db.categories.length})'),
                      selected: _selectedTab == 1,
                      selectedColor: GlassTheme.primaryViolet,
                      backgroundColor: GlassTheme.glassInput,
                      onSelected: (_) => setState(() => _selectedTab = 1),
                    ),
                  ],
                ),
                const Spacer(),
                GlassButton(
                  label: _selectedTab == 0 ? '+ Add Product' : '+ Add Category',
                  icon: Icons.add_rounded,
                  height: 38,
                  onPressed: () {
                    if (_selectedTab == 0) {
                      _showAddEditDishModal();
                    } else {
                      _showAddCategoryModal();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Content Tab View
          Expanded(
            child: _selectedTab == 0
                ? ListView.builder(
                    itemCount: db.menuItems.length,
                    itemBuilder: (context, idx) {
                      final dish = db.menuItems[idx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Text(dish.emoji, style: const TextStyle(fontSize: 28)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(dish.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                                    Text('${dish.category} • ${dish.description}', style: const TextStyle(color: GlassTheme.textMedium, fontSize: 11)),
                                  ],
                                ),
                              ),
                              GlassBadge(
                                label: '${dish.stockQuantity} stock',
                                color: dish.stockQuantity <= 10 ? GlassTheme.accentRose : GlassTheme.primaryCyan,
                              ),
                              const SizedBox(width: 12),
                              Text('$currency${dish.price.toStringAsFixed(2)}', style: const TextStyle(color: GlassTheme.accentNeonGreen, fontWeight: FontWeight.w800, fontSize: 15)),
                              const SizedBox(width: 10),
                              Switch(
                                value: dish.isAvailable,
                                activeThumbColor: GlassTheme.primaryViolet,
                                onChanged: (val) {
                                  db.toggleMenuItemAvailability(dish.id);
                                  setState(() {});
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: GlassTheme.primaryCyan, size: 18),
                                onPressed: () => _showAddEditDishModal(dish),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: GlassTheme.accentRose, size: 18),
                                onPressed: () async {
                                  await db.deleteMenuItem(dish.id);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    itemCount: db.categories.length,
                    itemBuilder: (context, idx) {
                      final cat = db.categories[idx];
                      final itemCount = db.menuItems.where((m) => m.category == cat).length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const Icon(Icons.category_rounded, color: GlassTheme.primaryCyan, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(cat, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                    Text('$itemCount Products linked', style: const TextStyle(color: GlassTheme.textMedium, fontSize: 11)),
                                  ],
                                ),
                              ),
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
                                            const Text('Edit Category Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                                onPressed: () async {
                                  await db.deleteCategory(cat);
                                  setState(() {});
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
    );
  }
}
