import 'package:flutter/material.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/storefront_model.dart';

class ItemCustomizationSheet extends StatefulWidget {
  final MenuItemModel item;
  final Function(StorefrontCartItem cartItem) onAddToCart;

  const ItemCustomizationSheet({
    super.key,
    required this.item,
    required this.onAddToCart,
  });

  @override
  State<ItemCustomizationSheet> createState() => _ItemCustomizationSheetState();
}

class _ItemCustomizationSheetState extends State<ItemCustomizationSheet> {
  late List<ProductSizeOption> _sizes;
  ProductSizeOption? _selectedSize;
  late List<StorefrontAddonItem> _addons;
  final TextEditingController _instructionsController = TextEditingController();
  int _quantity = 1;

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
    // If the item has variants, map from variants
    if (widget.item.variants.isNotEmpty) {
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
    } else {
      // Intelligent Pizza / Food sizes based on category
      final basePrice = widget.item.effectivePrice > 0 ? widget.item.effectivePrice : 249.0;
      final isPizza = widget.item.category.toLowerCase().contains('piz') ||
          widget.item.name.toLowerCase().contains('pizza');

      if (isPizza) {
        _sizes = [
          ProductSizeOption(
            id: 'reg',
            name: 'Regular',
            description: '7" (1-2 servings)',
            price: basePrice,
          ),
          ProductSizeOption(
            id: 'med',
            name: 'Medium',
            description: '10" (2-3 servings)',
            price: (basePrice * 1.4).roundToDouble(),
          ),
          ProductSizeOption(
            id: 'large',
            name: 'Large',
            description: '12" (3-4 servings)',
            price: (basePrice * 1.8).roundToDouble(),
          ),
        ];
      } else {
        _sizes = [
          ProductSizeOption(
            id: 'reg',
            name: 'Regular',
            description: 'Single portion',
            price: basePrice,
          ),
          ProductSizeOption(
            id: 'large',
            name: 'Large',
            description: 'Sharing portion',
            price: (basePrice * 1.5).roundToDouble(),
          ),
        ];
      }
    }

    // Default select Medium (as seen in image) or first available
    if (_sizes.length > 1) {
      _selectedSize = _sizes[1];
    } else if (_sizes.isNotEmpty) {
      _selectedSize = _sizes.first;
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
      StorefrontAddonItem(
        id: 'add_mushroom',
        name: 'Fresh Mushrooms',
        price: 45.0,
        imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=200&q=80',
      ),
    ];
  }

  double get _currentUnitPrice {
    double base = _selectedSize != null ? _selectedSize!.price : widget.item.effectivePrice;
    double addonsTotal = _addons.where((a) => a.isSelected).fold(0.0, (sum, a) => sum + a.price);
    return base + addonsTotal;
  }

  double get _currentTotalPrice => _currentUnitPrice * _quantity;

  Widget _buildVegNonVegBadge(String itemType) {
    final isVeg = itemType.toLowerCase().contains('veg') && !itemType.toLowerCase().contains('non');
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
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVeg = widget.item.itemType.toLowerCase().contains('veg') &&
        !widget.item.itemType.toLowerCase().contains('non');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Top Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Large Food Image with Bestseller Badge and Close (X) Button
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          height: 220,
                          width: double.infinity,
                          color: const Color(0xFFF1F5F9),
                          child: (widget.item.imageUrl.isNotEmpty)
                              ? Image.network(
                                  ApiEndpoints.resolveMediaUrl(widget.item.imageUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildFallbackBannerImage(),
                                )
                              : _buildFallbackBannerImage(),
                        ),
                      ),

                      // Veg Badge (Top-Left)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                              )
                            ],
                          ),
                          child: _buildVegNonVegBadge(widget.item.itemType),
                        ),
                      ),

                      // Close Button (Top-Right)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.close_rounded, size: 20, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                      ),

                      // Bestseller pill (Bottom-Left)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🔥', style: TextStyle(fontSize: 12)),
                              SizedBox(width: 4),
                              Text(
                                'Bestseller',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 3. Title & Info
                  Text(
                    widget.item.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    widget.item.description.isNotEmpty
                        ? widget.item.description
                        : 'Handcrafted with fresh gourmet ingredients, signature sauce, and melted mozzarella.',
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: Color(0xFF64748B),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Rating & Bestseller row
                  const Row(
                    children: [
                      Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
                      SizedBox(width: 4),
                      Text(
                        '4.7',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(width: 3),
                      Text(
                        '(320+)',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                      SizedBox(width: 8),
                      Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                      SizedBox(width: 8),
                      Text('🔥', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 4),
                      Text(
                        'Bestseller',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 4. Select Size Section
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
                    children: _sizes.map((sizeOpt) {
                      final isSelected = _selectedSize?.id == sizeOpt.id;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              setState(() {
                                _selectedSize = sizeOpt;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFFF3E0) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFE65100) : const Color(0xFFE2E8F0),
                                  width: isSelected ? 2 : 1.2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sizeOpt.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? const Color(0xFFE65100) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    sizeOpt.description,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isSelected ? const Color(0xFFE65100).withValues(alpha: 0.8) : const Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '₹${sizeOpt.price.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? const Color(0xFFE65100) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 22),

                  // 5. Add Ons (Optional) Section
                  const Text(
                    'Add Ons (Optional)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _addons.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final addon = _addons[index];
                        final isAdded = addon.isSelected;

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setState(() {
                              addon.isSelected = !addon.isSelected;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isAdded ? const Color(0xFFFFF3E0) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAdded ? const Color(0xFFE65100) : const Color(0xFFE2E8F0),
                                width: isAdded ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    color: const Color(0xFFE2E8F0),
                                    child: Image.network(
                                      addon.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Text('🧀', style: TextStyle(fontSize: 18)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      addon.name,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: isAdded ? const Color(0xFFE65100) : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '+₹${addon.price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFE65100),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: isAdded ? const Color(0xFFE65100) : const Color(0xFFE65100).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isAdded ? Icons.check_rounded : Icons.add_rounded,
                                    color: isAdded ? Colors.white : const Color(0xFFE65100),
                                    size: 17,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 6. Special Instructions Field
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, color: Color(0xFF64748B), size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _instructionsController,
                            style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                            decoration: const InputDecoration(
                              hintText: 'Add special instructions (optional)',
                              hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),

          // 7. Sticky Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  offset: const Offset(0, -4),
                  blurRadius: 16,
                )
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Quantity Stepper [-] 1 [+]
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            if (_quantity > 1) {
                              setState(() => _quantity--);
                            }
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            child: const Icon(Icons.remove_rounded, size: 18, color: Color(0xFF334155)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '$_quantity',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setState(() => _quantity++);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            child: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Add to Cart Button (Large Vibrant Orange)
                  Expanded(
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
                        widget.onAddToCart(cartItem);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_cart_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Add to Cart • ₹${_currentTotalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
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

  Widget _buildFallbackBannerImage() {
    return Container(
      color: const Color(0xFF262626),
      child: Center(
        child: Text(
          widget.item.emoji.isNotEmpty ? widget.item.emoji : '🍕',
          style: const TextStyle(fontSize: 72),
        ),
      ),
    );
  }
}
