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
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';

  static const List<Map<String, String>> _presetImages = [
    {'label': 'Paneer', 'url': 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=400&q=80', 'emoji': '🥘'},
    {'label': 'Dal Makhani', 'url': 'https://images.unsplash.com/photo-1546833999-b9f581a1996d?auto=format&fit=crop&w=400&q=80', 'emoji': '🍲'},
    {'label': 'Naan / Roti', 'url': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?auto=format&fit=crop&w=400&q=80', 'emoji': '🫓'},
    {'label': 'Biryani', 'url': 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=400&q=80', 'emoji': '🍚'},
    {'label': 'Burger', 'url': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=400&q=80', 'emoji': '🍔'},
    {'label': 'Fries', 'url': 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?auto=format&fit=crop&w=400&q=80', 'emoji': '🍟'},
    {'label': 'Coffee', 'url': 'https://images.unsplash.com/photo-1517701604599-bb29b565090c?auto=format&fit=crop&w=400&q=80', 'emoji': '🥤'},
    {'label': 'Lassi / Shake', 'url': 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?auto=format&fit=crop&w=400&q=80', 'emoji': '🥭'},
    {'label': 'Brownie', 'url': 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?auto=format&fit=crop&w=400&q=80', 'emoji': '🍨'},
    {'label': 'Sweets', 'url': 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?auto=format&fit=crop&w=400&q=80', 'emoji': '🍡'},
    {'label': 'Pizza', 'url': 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=400&q=80', 'emoji': '🍕'},
    {'label': 'Sandwich', 'url': 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?auto=format&fit=crop&w=400&q=80', 'emoji': '🥪'},
  ];

  List<MenuItemModel> get filteredProducts {
    return db.menuItems.where((item) {
      final matchesCat = _selectedCategoryFilter == 'All' || item.category == _selectedCategoryFilter;
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();
  }

  void _showAddEditDishModal([MenuItemModel? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? (db.categories.isNotEmpty ? db.categories.first : 'Main Course'));
    final priceCtrl = TextEditingController(text: existing?.price != null ? existing!.price.toStringAsFixed(0) : '150');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final imageCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '🍲');
    final stockCtrl = TextEditingController(text: existing?.stockQuantity.toString() ?? '50');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentImage = imageCtrl.text.trim();

            return AlertDialog(
              backgroundColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
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
                            existing == null ? 'Add Product to Menu' : 'Edit Product',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: GlassTheme.textMedium),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product Image Preview & Picker
                              Center(
                                child: Column(
                                  children: [
                                    Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        color: GlassTheme.glassInput,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: GlassTheme.primaryCyan.withOpacity(0.5)),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: currentImage.isNotEmpty
                                            ? Image.network(
                                                currentImage,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => _buildModalEmojiFallback(emojiCtrl.text),
                                              )
                                            : _buildModalEmojiFallback(emojiCtrl.text),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text('Product Photo Preview', style: TextStyle(color: GlassTheme.textMedium, fontSize: 11)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Quick Preset Image Selectors
                              const Text('Quick Preset Photos:', style: TextStyle(color: GlassTheme.textMedium, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 60,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _presetImages.length,
                                  itemBuilder: (context, idx) {
                                    final preset = _presetImages[idx];
                                    final isSelected = imageCtrl.text.trim() == preset['url'];

                                    return GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          imageCtrl.text = preset['url']!;
                                          emojiCtrl.text = preset['emoji']!;
                                        });
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        width: 54,
                                        decoration: BoxDecoration(
                                          color: GlassTheme.glassInput,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSelected ? GlassTheme.accentNeonGreen : GlassTheme.glassBorder,
                                            width: isSelected ? 2 : 1,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Image.network(
                                                preset['url']!,
                                                width: 32,
                                                height: 32,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => Text(preset['emoji']!, style: const TextStyle(fontSize: 16)),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(preset['label']!, style: const TextStyle(color: Colors.white, fontSize: 8), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),

                              GlassTextField(
                                controller: imageCtrl,
                                labelText: 'Custom Image URL / Path',
                                hintText: 'https://example.com/photo.jpg',
                                prefixIcon: Icons.image_outlined,
                                onChanged: (val) => setModalState(() {}),
                              ),
                              const SizedBox(height: 12),

                              GlassTextField(
                                controller: nameCtrl,
                                labelText: 'Product Name',
                                hintText: 'e.g. Paneer Butter Masala',
                                prefixIcon: Icons.fastfood_outlined,
                              ),
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: GlassTextField(
                                      controller: catCtrl,
                                      labelText: 'Category',
                                      hintText: 'Main Course',
                                      prefixIcon: Icons.category_outlined,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: GlassTextField(
                                      controller: emojiCtrl,
                                      labelText: 'Fallback Emoji',
                                      hintText: '🍲',
                                      prefixIcon: Icons.emoji_emotions_outlined,
                                      onChanged: (val) => setModalState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: GlassTextField(
                                      controller: priceCtrl,
                                      labelText: 'Price',
                                      hintText: '190',
                                      prefixIcon: Icons.currency_rupee_rounded,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: GlassTextField(
                                      controller: stockCtrl,
                                      labelText: 'Initial Stock Qty',
                                      hintText: '50',
                                      prefixIcon: Icons.inventory_2_outlined,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              GlassTextField(
                                controller: descCtrl,
                                labelText: 'Product Description',
                                hintText: 'Delicious ingredients and blend details',
                                prefixIcon: Icons.description_outlined,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      GlassButton(
                        label: existing == null ? 'Save Product' : 'Update Product',
                        icon: Icons.check_circle_rounded,
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) return;

                          final newItem = MenuItemModel(
                            id: existing?.id ?? 'prod_${DateTime.now().millisecondsSinceEpoch}',
                            name: nameCtrl.text.trim(),
                            category: catCtrl.text.trim(),
                            price: double.tryParse(priceCtrl.text) ?? 100.0,
                            description: descCtrl.text.trim(),
                            imageUrl: imageCtrl.text.trim(),
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
            );
          },
        );
      },
    );
  }

  Widget _buildModalEmojiFallback(String emoji) {
    return Container(
      color: GlassTheme.glassInput,
      alignment: Alignment.center,
      child: Text(
        emoji.isEmpty ? '🍲' : emoji,
        style: const TextStyle(fontSize: 36),
      ),
    );
  }

  void _showAddCategoryModal() {
    final catCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: GlassContainer(
              padding: const EdgeInsets.all(22),
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
        ),
      ),
    );
  }

  void _confirmDeleteProduct(MenuItemModel dish) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: GlassContainer(
          padding: const EdgeInsets.all(20),
          borderRadius: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: GlassTheme.accentRose, size: 40),
              const SizedBox(height: 10),
              Text(
                'Delete "${dish.name}"?',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Are you sure you want to delete this product from the menu?',
                textAlign: TextAlign.center,
                style: TextStyle(color: GlassTheme.textMedium, fontSize: 12),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: 'Cancel',
                      isPrimary: false,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassButton(
                      label: 'Delete',
                      icon: Icons.delete_outline,
                      onPressed: () async {
                        await db.deleteMenuItem(dish.id);
                        if (!mounted) return;
                        setState(() {});
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCategory(String categoryName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: GlassContainer(
          padding: const EdgeInsets.all(20),
          borderRadius: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: GlassTheme.accentRose, size: 40),
              const SizedBox(height: 10),
              Text(
                'Delete Category "$categoryName"?',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Deleting a category will remove it from the menu filters.',
                textAlign: TextAlign.center,
                style: TextStyle(color: GlassTheme.textMedium, fontSize: 12),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: 'Cancel',
                      isPrimary: false,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassButton(
                      label: 'Delete',
                      icon: Icons.delete_outline,
                      onPressed: () async {
                        await db.deleteCategory(categoryName);
                        if (!mounted) return;
                        setState(() {});
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
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
    final categoriesList = ['All', ...db.categories];

    return SafeArea(
      child: Column(
        children: [
          // Header & Tab Switcher
          GlassContainer(
            padding: const EdgeInsets.all(12),
            borderRadius: 16,
            blurStrength: 12,
            child: Row(
              children: [
                // Tab Selection Pills
                Row(
                  children: [
                    ChoiceChip(
                      label: Text('Products (${db.menuItems.length})'),
                      selected: _selectedTab == 0,
                      selectedColor: GlassTheme.primaryViolet,
                      backgroundColor: GlassTheme.glassInput,
                      labelStyle: TextStyle(
                        color: _selectedTab == 0 ? Colors.white : GlassTheme.textMedium,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (_) => setState(() => _selectedTab = 0),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Categories (${db.categories.length})'),
                      selected: _selectedTab == 1,
                      selectedColor: GlassTheme.primaryViolet,
                      backgroundColor: GlassTheme.glassInput,
                      labelStyle: TextStyle(
                        color: _selectedTab == 1 ? Colors.white : GlassTheme.textMedium,
                        fontWeight: FontWeight.bold,
                      ),
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
          const SizedBox(height: 10),

          // Filters for Products Tab
          if (_selectedTab == 0) ...[
            GlassContainer(
              padding: const EdgeInsets.all(10),
              borderRadius: 14,
              blurStrength: 10,
              child: Column(
                children: [
                  GlassTextField(
                    hintText: 'Search product or description...',
                    prefixIcon: Icons.search_rounded,
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: categoriesList.length,
                      itemBuilder: (context, idx) {
                        final cat = categoriesList[idx];
                        final isSel = _selectedCategoryFilter == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(cat, style: const TextStyle(fontSize: 11)),
                            selected: isSel,
                            selectedColor: GlassTheme.primaryViolet.withOpacity(0.8),
                            backgroundColor: GlassTheme.glassInput,
                            onSelected: (_) => setState(() => _selectedCategoryFilter = cat),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Content Area
          Expanded(
            child: _selectedTab == 0
                ? (filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.restaurant_menu_rounded, color: GlassTheme.textLow, size: 48),
                            const SizedBox(height: 10),
                            const Text('No menu products found', style: TextStyle(color: GlassTheme.textMedium, fontSize: 14)),
                            const SizedBox(height: 12),
                            GlassButton(
                              label: 'Add First Product',
                              icon: Icons.add,
                              width: 170,
                              height: 38,
                              onPressed: () => _showAddEditDishModal(),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, idx) {
                          final dish = filteredProducts[idx];
                          final hasImage = dish.imageUrl.isNotEmpty;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassCard(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: hasImage
                                            ? Image.network(
                                                dish.imageUrl,
                                                width: 44,
                                                height: 44,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => _buildItemEmojiFallback(dish.emoji),
                                              )
                                            : _buildItemEmojiFallback(dish.emoji),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    dish.name,
                                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                GlassBadge(
                                                  label: dish.category,
                                                  color: GlassTheme.primaryViolet,
                                                  fontSize: 9,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              dish.description.isEmpty ? 'No description' : dish.description,
                                              style: const TextStyle(color: GlassTheme.textMedium, fontSize: 11),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$currency${dish.price.toStringAsFixed(0)}',
                                        style: const TextStyle(color: GlassTheme.accentNeonGreen, fontWeight: FontWeight.w800, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(color: GlassTheme.glassBorder, height: 1),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          GlassBadge(
                                            label: '${dish.stockQuantity} qty',
                                            color: dish.stockQuantity <= 10 ? GlassTheme.accentRose : GlassTheme.primaryCyan,
                                            fontSize: 9,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('Active:', style: TextStyle(color: GlassTheme.textMedium, fontSize: 11)),
                                          const SizedBox(width: 2),
                                          Transform.scale(
                                            scale: 0.8,
                                            child: Switch(
                                              value: dish.isAvailable,
                                              activeThumbColor: GlassTheme.primaryViolet,
                                              onChanged: (val) {
                                                db.toggleMenuItemAvailability(dish.id);
                                                setState(() {});
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, color: GlassTheme.primaryCyan, size: 18),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(6),
                                            tooltip: 'Edit Product',
                                            onPressed: () => _showAddEditDishModal(dish),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: GlassTheme.accentRose, size: 18),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(6),
                                            tooltip: 'Delete Product',
                                            onPressed: () => _confirmDeleteProduct(dish),
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
                      ))
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
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: GlassTheme.primaryCyan.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.category_rounded, color: GlassTheme.primaryCyan, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(cat, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                                    Text('$itemCount Products in category', style: const TextStyle(color: GlassTheme.textMedium, fontSize: 11)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: GlassTheme.primaryCyan, size: 18),
                                tooltip: 'Edit Category Name',
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
                                tooltip: 'Delete Category',
                                onPressed: () => _confirmDeleteCategory(cat),
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

  Widget _buildItemEmojiFallback(String emoji) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: GlassTheme.glassInput,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(emoji.isEmpty ? '🍲' : emoji, style: const TextStyle(fontSize: 22)),
    );
  }
}
