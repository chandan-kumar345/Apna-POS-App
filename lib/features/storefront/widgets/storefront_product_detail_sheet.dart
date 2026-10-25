import 'package:flutter/material.dart';
import '../../../core/models/menu_item_model.dart';
import '../../pos/widgets/pos_product_media_box.dart';
import '../models/storefront_model.dart';

class StorefrontProductDetailSheet extends StatefulWidget {
  final MenuItemModel item;
  final Function(StorefrontCartItem cartItem, {bool openCartImmediately}) onAddToCart;
  final Color themeColor;
  final Color? themeColorEnd;
  final bool isOnline;

  const StorefrontProductDetailSheet({
    super.key,
    required this.item,
    required this.onAddToCart,
    this.themeColor = const Color(0xFFE65100),
    this.themeColorEnd,
    this.isOnline = true,
  });

  @override
  State<StorefrontProductDetailSheet> createState() => _StorefrontProductDetailSheetState();
}

class _StorefrontProductDetailSheetState extends State<StorefrontProductDetailSheet> {
  late List<ProductSizeOption> _sizes;
  ProductSizeOption? _selectedSize;
  late List<StorefrontAddonItem> _addons;
  final TextEditingController _instructionsController = TextEditingController();
  int _quantity = 1;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _initSizes();
    _initAddons();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  void _initSizes() {
    if (widget.item.variants.length > 1) {
      _sizes = widget.item.variants.map((v) {
        String desc = 'Standard serving';
        final lower = v.name.toLowerCase();
        if (lower.contains('reg') || lower.contains('small') || lower.contains('7')) {
          desc = '7" (1-2 servings)';
        } else if (lower.contains('med') || lower.contains('10')) {
          desc = '10" (2-3 servings)';
        } else if (lower.contains('large') || lower.contains('12')) {
          desc = '12" (3-4 servings)';
        }
        return ProductSizeOption(
          id: v.name,
          name: v.name.replaceAll(RegExp(r'\(.*\)'), '').trim(),
          description: desc,
          price: v.effectivePrice > 0 ? v.effectivePrice : v.price,
        );
      }).toList();
      _selectedSize = _sizes.length > 1 ? _sizes[1] : _sizes.first;
    } else {
      // Default 3 standard sizes matching pizza screenshot if pizza/dish
      final basePrice = widget.item.effectivePrice > 0 ? widget.item.effectivePrice : 249.0;
      _sizes = [
        ProductSizeOption(
          id: 'size_reg',
          name: 'Regular',
          description: '7" (1-2 servings)',
          price: (basePrice * 0.85).roundToDouble(),
        ),
        ProductSizeOption(
          id: 'size_med',
          name: 'Medium',
          description: '10" (2-3 servings)',
          price: basePrice,
        ),
        ProductSizeOption(
          id: 'size_lrg',
          name: 'Large',
          description: '12" (3-4 servings)',
          price: (basePrice * 1.45).roundToDouble(),
        ),
      ];
      _selectedSize = _sizes[1]; // default medium selected matching screenshot
    }
  }

  void _initAddons() {
    _addons = [
      StorefrontAddonItem(
        id: 'add_cheese',
        name: 'Extra Cheese',
        price: 40.0,
        imageUrl: 'https://images.unsplash.com/photo-1552767059-ce182ead8c1b?auto=format&fit=crop&w=200&q=80',
      ),
      StorefrontAddonItem(
        id: 'add_paneer',
        name: 'Extra Paneer',
        price: 50.0,
        imageUrl: 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=200&q=80',
      ),
      StorefrontAddonItem(
        id: 'add_jalapeno',
        name: 'Jalapeños',
        price: 30.0,
        imageUrl: 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?auto=format&fit=crop&w=200&q=80',
      ),
      StorefrontAddonItem(
        id: 'add_olives',
        name: 'Black Olives',
        price: 35.0,
        imageUrl: 'https://images.unsplash.com/photo-1563861826100-9cb868fdbe1c?auto=format&fit=crop&w=200&q=80',
      ),
    ];
  }

  double get _unitPrice {
    final base = _selectedSize != null ? _selectedSize!.price : widget.item.effectivePrice;
    final addonsTotal = _addons.where((a) => a.isSelected).fold(0.0, (sum, a) => sum + a.price);
    return base + addonsTotal;
  }

  double get _totalPrice => _unitPrice * _quantity;

  Widget _buildVegBadge() {
    final isVeg = widget.item.itemType.toLowerCase().contains('veg') &&
        !widget.item.itemType.toLowerCase().contains('non');
    final color = isVeg ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFFEFF3F8), // Neumorphic base
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HERO FOOD IMAGE WITH TOP CONTROLS & BESTSELLER BADGE
                  Stack(
                    children: [
                      Container(
                        height: 250,
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: PosProductMediaBox(
                            key: ValueKey('detail_media_${widget.item.id}_${widget.item.imageUrl}'),
                            item: widget.item,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(22),
                            showDots: true,
                            autoSlide: true,
                          ),
                        ),
                      ),

                      // Top Nav Buttons (Back and Favorite)
                      Positioned(
                        top: 10,
                        left: 24,
                        child: _buildCircularButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 24,
                        child: _buildCircularButton(
                          icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          iconColor: _isFavorite ? Colors.red : const Color(0xFF0F172A),
                          onTap: () => setState(() => _isFavorite = !_isFavorite),
                        ),
                      ),

                      // Bestseller Badge (bottom-left overlay on hero)
                      Positioned(
                        bottom: 12,
                        left: 26,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF5722), size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Bestseller',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 2. PRODUCT TITLE, RATINGS & DESCRIPTION
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildVegBadge(),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.item.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Rating & Bestseller row
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 18),
                            const SizedBox(width: 4),
                            const Text(
                              '4.7',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            const Text(
                              ' (320+)',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 10),
                            Container(width: 1, height: 12, color: const Color(0xFFCBD5E1)),
                            const SizedBox(width: 10),
                            const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF5722), size: 16),
                            const SizedBox(width: 3),
                            const Text(
                              'Bestseller',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF5722),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Text(
                          widget.item.description.isNotEmpty
                              ? widget.item.description
                              : 'Paneer, onion, capsicum, and tangy achari seasoning.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. SELECT SIZE SECTION (3 horizontal cards)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Size',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: _sizes.map((size) {
                            final isSelected = _selectedSize?.id == size.id;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedSize = size),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? widget.themeColor.withValues(alpha: 0.08)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected ? widget.themeColor : const Color(0xFFE2E8F0),
                                      width: isSelected ? 2.0 : 1.2,
                                    ),
                                    boxShadow: [
                                      const BoxShadow(
                                        color: Colors.white,
                                        offset: Offset(-2, -2),
                                        blurRadius: 4,
                                      ),
                                      BoxShadow(
                                        color: isSelected
                                            ? widget.themeColor.withValues(alpha: 0.25)
                                            : const Color(0xFF94A3B8).withValues(alpha: 0.15),
                                        offset: const Offset(2, 2.5),
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            size.name,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                              color: isSelected ? widget.themeColor : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            size.description,
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '₹${size.price.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: isSelected ? widget.themeColor : const Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Selected Checkmark Badge on Top Right
                                      if (isSelected)
                                        Positioned(
                                          top: -4,
                                          right: -2,
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              color: widget.themeColor,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.check, size: 12, color: Colors.white),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. ADD ONS (OPTIONAL) SECTION
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Add Ons (Optional)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'View All',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: widget.themeColor,
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 10, color: widget.themeColor),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 72,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _addons.length,
                            separatorBuilder: (ctx, idx) => const SizedBox(width: 10),
                            itemBuilder: (ctx, idx) {
                              final addon = _addons[idx];
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    addon.isSelected = !addon.isSelected;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: addon.isSelected
                                        ? widget.themeColor.withValues(alpha: 0.08)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: addon.isSelected ? widget.themeColor : const Color(0xFFE2E8F0),
                                      width: addon.isSelected ? 1.8 : 1.2,
                                    ),
                                    boxShadow: [
                                      const BoxShadow(
                                        color: Colors.white,
                                        offset: Offset(-2, -2),
                                        blurRadius: 4,
                                      ),
                                      BoxShadow(
                                        color: const Color(0xFF94A3B8).withValues(alpha: 0.15),
                                        offset: const Offset(2, 2.5),
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          addon.imageUrl,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => Container(
                                            width: 44,
                                            height: 44,
                                            color: const Color(0xFFE2E8F0),
                                            child: const Icon(Icons.fastfood_rounded, size: 20, color: Color(0xFF94A3B8)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            addon.name,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '+₹${addon.price.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: widget.themeColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          color: addon.isSelected ? widget.themeColor : const Color(0xFFF1F5F9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          addon.isSelected ? Icons.check : Icons.add,
                                          size: 16,
                                          color: addon.isSelected ? Colors.white : widget.themeColor,
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
                  ),

                  const SizedBox(height: 20),

                  // 5. SPECIAL INSTRUCTIONS BOX (Sunken rounded)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEF5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDDE3EC)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF94A3B8).withValues(alpha: 0.22),
                            offset: const Offset(1.5, 1.5),
                            blurRadius: 3,
                            spreadRadius: -0.5,
                          ),
                          const BoxShadow(
                            color: Colors.white,
                            offset: Offset(-1.5, -1.5),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_note_rounded, color: Color(0xFF94A3B8), size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _instructionsController,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                              decoration: const InputDecoration(
                                hintText: 'Add special instructions (optional)',
                                hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),
                ],
              ),
            ),
          ),

          // 6. STICKY BOTTOM BAR (Stepper & Add to Cart button)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.18),
                  offset: const Offset(0, -4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Stepper (- 1 +)
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EEF5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFDDE3EC)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF94A3B8).withValues(alpha: 0.2),
                          offset: const Offset(1.5, 1.5),
                          blurRadius: 3,
                        ),
                        const BoxShadow(
                          color: Colors.white,
                          offset: Offset(-1.5, -1.5),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 18),
                          color: const Color(0xFF0F172A),
                          onPressed: () {
                            if (_quantity > 1) {
                              setState(() => _quantity--);
                            }
                          },
                        ),
                        SizedBox(
                          width: 24,
                          child: Text(
                            '$_quantity',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 18),
                          color: const Color(0xFF0F172A),
                          onPressed: () {
                            setState(() => _quantity++);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Primary Button "Add to Cart • ₹Price"
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final cartItem = StorefrontCartItem(
                            uid: 'cart_${DateTime.now().millisecondsSinceEpoch}',
                            item: widget.item,
                            selectedSize: _selectedSize,
                            selectedAddons: _addons.where((a) => a.isSelected).toList(),
                            instructions: _instructionsController.text.trim(),
                            quantity: _quantity,
                          );

                          widget.onAddToCart(cartItem, openCartImmediately: false);
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: widget.themeColor.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: Text(
                          'Add to Cart • ₹${_totalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
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
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    Color iconColor = const Color(0xFF0F172A),
    required VoidCallback onTap,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          const BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
          BoxShadow(
            color: const Color(0xFF94A3B8).withValues(alpha: 0.3),
            offset: const Offset(2, 2.5),
            blurRadius: 5,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Icon(icon, size: 20, color: iconColor),
          ),
        ),
      ),
    );
  }
}
