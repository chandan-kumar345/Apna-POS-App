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
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = screenHeight * 0.65;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 1. Top Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Large Food Image with Bestseller Badge and Close (X) Button
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 135,
                          width: double.infinity,
                          color: const Color(0xFFF1F5F9),
                          child: (widget.item.imageUrl.isNotEmpty)
                              ? Image.network(
                                  ApiEndpoints.resolveMediaUrl(widget.item.imageUrl),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _buildFallbackBannerImage(),
                                )
                              : _buildFallbackBannerImage(),
                        ),
                      ),

                      // Veg Badge (Top-Left)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                              )
                            ],
                          ),
                          child: _buildVegNonVegBadge(widget.item.itemType),
                        ),
                      ),

                      // Close Button (Top-Right)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.95),
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close_rounded, size: 18, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                      ),

                      // Bestseller pill (Bottom-Left)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🔥', style: TextStyle(fontSize: 11)),
                              SizedBox(width: 3),
                              Text(
                                'Bestseller',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 3. Title & Info
                  Text(
                    widget.item.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    widget.item.description.isNotEmpty
                        ? widget.item.description
                        : 'Handcrafted with fresh gourmet ingredients, signature sauce, and melted mozzarella.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Color(0xFF64748B),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Rating & Bestseller row
                  const Row(
                    children: [
                      Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                      SizedBox(width: 3),
                      Text(
                        '4.7',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(width: 3),
                      Text(
                        '(320+)',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                      SizedBox(width: 8),
                      Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                      SizedBox(width: 8),
                      Text('🔥', style: TextStyle(fontSize: 11)),
                      SizedBox(width: 3),
                      Text(
                        'Bestseller',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 4. Select Size Section
                  const Text(
                    'Select Size',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: _sizes.map((sizeOpt) {
                      final isSelected = _selectedSize?.id == sizeOpt.id;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                _selectedSize = sizeOpt;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFFF3E0) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFE65100) : const Color(0xFFE2E8F0),
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sizeOpt.name,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected ? const Color(0xFFE65100) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    sizeOpt.description,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      height: 1.25,
                                      color: isSelected ? const Color(0xFFE65100).withValues(alpha: 0.85) : const Color(0xFF64748B),
                                    ),
                                    softWrap: true,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '₹${sizeOpt.price.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 13.5,
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

                  const SizedBox(height: 16),

                  // 5. Add Ons (Optional) Section
                  const Text(
                    'Add Ons (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),

                  SizedBox(
                    height: 54,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _addons.length,
                      separatorBuilder: (_, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final addon = _addons[index];
                        final isAdded = addon.isSelected;

                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setState(() {
                              addon.isSelected = !addon.isSelected;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: isAdded ? const Color(0xFFFFF3E0) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isAdded ? const Color(0xFFE65100) : const Color(0xFFE2E8F0),
                                width: isAdded ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    color: const Color(0xFFE2E8F0),
                                    child: Image.network(
                                      addon.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Center(
                                        child: Text('🧀', style: TextStyle(fontSize: 16)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      addon.name,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: isAdded ? const Color(0xFFE65100) : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      '+₹${addon.price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFE65100),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: isAdded ? const Color(0xFFE65100) : const Color(0xFFE65100).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isAdded ? Icons.check_rounded : Icons.add_rounded,
                                    color: isAdded ? Colors.white : const Color(0xFFE65100),
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 6. Special Instructions Field
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, color: Color(0xFF64748B), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _instructionsController,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                            decoration: const InputDecoration(
                              hintText: 'Add special instructions (optional)',
                              hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // 7. Sticky Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  offset: const Offset(0, -4),
                  blurRadius: 12,
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            if (_quantity > 1) {
                              setState(() => _quantity--);
                            }
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            child: const Icon(Icons.remove_rounded, size: 16, color: Color(0xFF334155)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '$_quantity',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            setState(() => _quantity++);
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            child: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_cart_rounded, size: 16),
                          const SizedBox(width: 5),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Add to Cart • ₹${_currentTotalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
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
