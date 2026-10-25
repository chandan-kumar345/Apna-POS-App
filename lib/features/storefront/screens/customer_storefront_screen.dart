import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/storefront_model.dart';
import '../services/storefront_service.dart';
import '../widgets/item_customization_sheet.dart';
import '../widgets/storefront_cart_sheet.dart';

class CustomerStorefrontScreen extends StatefulWidget {
  final String slug;
  final bool isPreviewMode;

  const CustomerStorefrontScreen({
    super.key,
    required this.slug,
    this.isPreviewMode = false,
  });

  @override
  State<CustomerStorefrontScreen> createState() => _CustomerStorefrontScreenState();
}

class _CustomerStorefrontScreenState extends State<CustomerStorefrontScreen> {
  final StorefrontService _service = StorefrontService();
  final TextEditingController _searchController = TextEditingController();
  final PageController _bannerController = PageController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isLoading = true;
  StorefrontData? _data;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  OrderType _orderType = OrderType.delivery;
  String _deliveryAddress = 'Sector 62, Noida';
  bool _isFavorite = false;
  int _activeBannerIndex = 0;
  Timer? _bannerTimer;

  // In-memory cart
  final List<StorefrontCartItem> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _startBannerTimer();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _startBannerTimer() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_bannerController.hasClients && (_data?.banners.length ?? 0) > 1) {
        final next = (_activeBannerIndex + 1) % _data!.banners.length;
        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _service.loadStorefront(widget.slug);
    if (mounted) {
      setState(() {
        _data = data;
        _deliveryAddress = data.restaurant.address.isNotEmpty ? data.restaurant.address : 'Sector 62, Noida';
        _isLoading = false;
      });
    }
  }

  List<MenuItemModel> get _filteredItems {
    if (_data == null) return [];
    var list = _data!.menuItems;

    // Filter by Category
    if (_selectedCategory != 'All') {
      list = list.where((item) {
        final cat = item.category.trim().toLowerCase();
        final sel = _selectedCategory.trim().toLowerCase();
        return cat == sel || cat.contains(sel) || sel.contains(cat);
      }).toList();
    }

    // Filter by Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((item) {
        return item.name.toLowerCase().contains(q) ||
            item.description.toLowerCase().contains(q) ||
            item.category.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  int get _totalCartCount => _cartItems.fold(0, (sum, i) => sum + i.quantity);
  double get _totalCartAmount => _cartItems.fold(0.0, (sum, i) => sum + i.totalPrice);

  void _openCustomizationModal(MenuItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ItemCustomizationSheet(
        item: item,
        onAddToCart: (cartItem) {
          setState(() {
            final existingIdx = _cartItems.indexWhere(
              (c) =>
                  c.item.id == cartItem.item.id &&
                  c.selectedSize?.id == cartItem.selectedSize?.id &&
                  c.instructions == cartItem.instructions,
            );
            if (existingIdx >= 0) {
              _cartItems[existingIdx].quantity += cartItem.quantity;
            } else {
              _cartItems.add(cartItem);
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added "${item.name}" to cart'),
              backgroundColor: const Color(0xFFE65100),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _openCartModal() {
    if (_data == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StorefrontCartSheet(
        restaurant: _data!.restaurant,
        cartItems: _cartItems,
        initialOrderType: _orderType,
        deliveryAddress: _deliveryAddress,
        onUpdateQuantity: (item, newQty) {
          setState(() {
            if (newQty <= 0) {
              _cartItems.removeWhere((i) => i.uid == item.uid);
            } else {
              item.quantity = newQty;
            }
          });
        },
        onClearCart: () {
          setState(() {
            _cartItems.clear();
          });
        },
      ),
    );
  }

  void _showChangeLocationDialog() {
    final controller = TextEditingController(text: _deliveryAddress);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Delivery Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter area or city',
            prefixIcon: Icon(Icons.location_on_rounded, color: Color(0xFFE65100)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _deliveryAddress = controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRestaurantInfo() {
    if (_data == null) return;
    final rest = _data!.restaurant;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildRestaurantAvatar(rest.logoUrl, rest.name, size: 50),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rest.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(rest.cuisineType, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            _buildInfoRow(Icons.phone_rounded, rest.phone),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.location_on_rounded, rest.address),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.access_time_rounded, '${rest.openingTime} - ${rest.closingTime}'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final phoneClean = rest.phone.replaceAll(RegExp(r'[^0-9+]'), '');
                  launchUrl(Uri.parse('tel:$phoneClean'));
                },
                icon: const Icon(Icons.call_rounded),
                label: const Text('Call Outlet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFE65100)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)))),
      ],
    );
  }

  Widget _buildRestaurantAvatar(String? logo, String name, {double size = 48}) {
    final effectiveLogo = (logo != null && logo.trim().isNotEmpty)
        ? logo.trim()
        : DatabaseService().companyLogoPath?.trim();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE65100), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: _buildAvatarImage(effectiveLogo, name, size),
      ),
    );
  }

  Widget _buildAvatarImage(String? path, String name, double size) {
    if (path != null && path.isNotEmpty) {
      // 1. Data URI / Base64 image
      if (path.startsWith('data:image') ||
          path.startsWith('data:') ||
          (path.length > 80 && !path.startsWith('http') && !path.startsWith('assets/'))) {
        try {
          final clean = path.contains(',') ? path.split(',').last : path;
          final bytes = base64Decode(clean.replaceAll('\n', '').replaceAll('\r', '').trim());
          return Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackImage(name, size),
          );
        } catch (_) {}
      } else if (path.startsWith('http://') || path.startsWith('https://')) {
        return Image.network(
          ApiEndpoints.resolveMediaUrl(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackImage(name, size),
        );
      } else if (path.startsWith('assets/')) {
        return Image.asset(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackImage(name, size),
        );
      } else if (!kIsWeb) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            return Image.file(
              file,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallbackImage(name, size),
            );
          }
        } catch (_) {}
      }
    }
    return _buildFallbackImage(name, size);
  }

  Widget _buildFallbackImage(String name, double size) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildEmblemLogo(name, size),
    );
  }

  Widget _buildEmblemLogo(String name, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE65100), width: 1.5),
      ),
      child: Center(
        child: Text(
          name.length > 2 ? name.substring(0, 2).toUpperCase() : 'POS',
          style: TextStyle(
            color: const Color(0xFFE65100),
            fontSize: size * 0.38,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('all')) return Icons.local_pizza_rounded;
    if (lower.contains('piz')) return Icons.local_pizza_rounded;
    if (lower.contains('burg')) return Icons.lunch_dining_rounded;
    if (lower.contains('past') || lower.contains('nood')) return Icons.ramen_dining_rounded;
    if (lower.contains('side') || lower.contains('frie') || lower.contains('snack')) return Icons.fastfood_rounded;
    if (lower.contains('bev') || lower.contains('drink') || lower.contains('shake') || lower.contains('juice')) {
      return Icons.local_cafe_rounded;
    }
    if (lower.contains('dessert') || lower.contains('cake') || lower.contains('ice')) return Icons.icecream_rounded;
    return Icons.restaurant_rounded;
  }

  Widget _buildVegNonVegBadge(String itemType) {
    final isVeg = itemType.toLowerCase().contains('veg') && !itemType.toLowerCase().contains('non');
    final color = isVeg ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Container(
          width: 6.5,
          height: 6.5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFE65100), strokeWidth: 3),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Loading Storefront...',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
      );
    }

    final restaurant = _data!.restaurant;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 12, 16, _cartItems.isNotEmpty ? 94 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Preview Mode Bar (if inside POS app preview)
                      if (widget.isPreviewMode)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF051C48), Color(0xFF0052FF)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Customer Live Web Preview • Takeaway & Delivery',
                                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                              InkWell(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Exit Preview', style: TextStyle(color: Colors.white, fontSize: 11.5)),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 1. TOP HEADER (Restaurant Logo, Name, Cuisines, Rating, Timing & Action Icons)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRestaurantAvatar(restaurant.logoUrl, restaurant.name, size: 50),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  restaurant.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  restaurant.cuisineType,
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    // Rating
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                                        const SizedBox(width: 2),
                                        const Text(
                                          '4.6',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(width: 2),
                                        const Text('(1.2k+)', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                      ],
                                    ),

                                    // Open status badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Open',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ),

                                    // Timing
                                    Text(
                                      '${restaurant.openingTime} - ${restaurant.closingTime}',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Top-Right Action Buttons (Search, Heart, More)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildCircularHeaderButton(
                                icon: Icons.search_rounded,
                                onTap: () => _searchFocusNode.requestFocus(),
                              ),
                              const SizedBox(width: 5),
                              _buildCircularHeaderButton(
                                icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                iconColor: _isFavorite ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                                onTap: () {
                                  setState(() => _isFavorite = !_isFavorite);
                                },
                              ),
                              const SizedBox(width: 5),
                              _buildCircularHeaderButton(
                                icon: Icons.more_vert_rounded,
                                onTap: _showRestaurantInfo,
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // 2. ORDER TYPE SWITCHER & LOCATION / ETA BAR
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 2.1 Segmented Delivery / Pickup Switcher (Clean, compact tab bar)
                          Container(
                            height: 38,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () => setState(() => _orderType = OrderType.delivery),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      decoration: BoxDecoration(
                                        color: _orderType == OrderType.delivery ? const Color(0xFFE65100) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: _orderType == OrderType.delivery
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFFE65100).withValues(alpha: 0.25),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.two_wheeler_rounded,
                                              size: 16,
                                              color: _orderType == OrderType.delivery ? Colors.white : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Delivery',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: _orderType == OrderType.delivery ? Colors.white : const Color(0xFF475569),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () => setState(() => _orderType = OrderType.takeaway),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      decoration: BoxDecoration(
                                        color: _orderType == OrderType.takeaway ? const Color(0xFFE65100) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: _orderType == OrderType.takeaway
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFFE65100).withValues(alpha: 0.25),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                )
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.store_mall_directory_rounded,
                                              size: 16,
                                              color: _orderType == OrderType.takeaway ? Colors.white : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Pickup',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: _orderType == OrderType.takeaway ? Colors.white : const Color(0xFF475569),
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
                          ),
                          const SizedBox(height: 8),

                          // 2.2 Location & ETA Bar (Full width, wrapped and visible address)
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _showChangeLocationDialog,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFE65100)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _deliveryAddress,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          _orderType == OrderType.delivery
                                              ? 'Delivery in 25–35 mins • Live tracking'
                                              : 'Ready for pickup in 15–20 mins',
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Change', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFE65100))),
                                        Icon(Icons.keyboard_arrow_right_rounded, size: 14, color: Color(0xFFE65100)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 3. PROMOTIONAL CAROUSEL BANNER
                      if (_data!.banners.isNotEmpty) ...[
                        SizedBox(
                          height: 156,
                          child: PageView.builder(
                            controller: _bannerController,
                            itemCount: _data!.banners.length,
                            onPageChanged: (idx) => setState(() => _activeBannerIndex = idx),
                            itemBuilder: (context, index) {
                              final b = _data!.banners[index];
                              return InkWell(
                                onTap: () {
                                  if (b.couponCode != null && b.couponCode!.isNotEmpty) {
                                    Clipboard.setData(ClipboardData(text: b.couponCode!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Promo Code "${b.couponCode}" copied! Use at checkout.'),
                                        backgroundColor: const Color(0xFF051C48),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: (b.imageUrl.isNotEmpty)
                                              ? Image.network(
                                                  b.imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                    color: Color(b.accentColorHex),
                                                  ),
                                                )
                                              : Container(color: Color(b.accentColorHex)),
                                        ),
                                        Positioned.fill(
                                          child: Container(
                                            color: Colors.black.withValues(alpha: 0.45),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(18),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    b.tag,
                                                    style: const TextStyle(
                                                      color: Color(0xFFFFB74D),
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: 1.1,
                                                    ),
                                                  ),
                                                  if (b.discountText != null && b.discountText!.isNotEmpty) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFEF4444),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        b.discountText!,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.w900,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                b.headline,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -0.2,
                                                  height: 1.1,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                b.subtitle,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFE65100),
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                      b.ctaText,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                  if (b.couponCode != null && b.couponCode!.isNotEmpty) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withValues(alpha: 0.22),
                                                        borderRadius: BorderRadius.circular(16),
                                                        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 12),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            'CODE: ${b.couponCode}',
                                                            style: const TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w900,
                                                              letterSpacing: 0.4,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Carousel Dots Indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_data!.banners.length, (dotIdx) {
                            final isActive = dotIdx == _activeBannerIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: isActive ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFFE65100) : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 4. CATEGORIES HORIZONTAL CIRCLE ICONS ROW
                      SizedBox(
                        height: 94,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _data!.categories.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (context, catIdx) {
                            final cat = _data!.categories[catIdx];
                            final isSelected = _selectedCategory == cat;

                            return InkWell(
                              borderRadius: BorderRadius.circular(30),
                              onTap: () {
                                setState(() {
                                  _selectedCategory = cat;
                                });
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFE65100) : const Color(0xFFFFF3E0),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: isSelected
                                              ? const Color(0xFFE65100).withValues(alpha: 0.3)
                                              : Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Icon(
                                        _getCategoryIcon(cat),
                                        color: isSelected ? Colors.white : const Color(0xFFE65100),
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? const Color(0xFFE65100) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 5. SEARCH INPUT BAR
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                onChanged: (val) => setState(() => _searchQuery = val),
                                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                                decoration: const InputDecoration(
                                  hintText: 'Search for pizzas, burgers, drinks...',
                                  hintStyle: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 6. SECTION HEADER & ITEM COUNT
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_selectedCategory (${_filteredItems.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCategory = 'All';
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                            child: const Row(
                              children: [
                                Text(
                                  'View All',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFE65100),
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFE65100)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 7. PRODUCT ITEMS LIST (Matching screenshot cards)
                      if (_filteredItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: const Column(
                            children: [
                              Text('🔍', style: TextStyle(fontSize: 40)),
                              SizedBox(height: 12),
                              Text(
                                'No matching items found',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                              ),
                              SizedBox(height: 4),
                              Text('Try checking another category or different search terms.', style: TextStyle(color: Color(0xFF64748B))),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, itemIdx) {
                            final item = _filteredItems[itemIdx];
                            return _buildProductCard(item);
                          },
                        ),
                    ],
                  ),
                ),

                // 8. FLOATING STICKY BOTTOM CART BAR
                if (_cartItems.isNotEmpty)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 768),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                offset: const Offset(0, 6),
                                blurRadius: 18,
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE65100),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$_totalCartCount ${_totalCartCount == 1 ? "Item" : "Items"} in Cart',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '₹${_totalCartAmount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _openCartModal,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE65100),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('View Cart', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_rounded, size: 16),
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
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(MenuItemModel item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food Image on Left
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 96,
              height: 96,
              color: const Color(0xFFF1F5F9),
              child: (item.imageUrl.isNotEmpty)
                  ? Image.network(
                      ApiEndpoints.resolveMediaUrl(item.imageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(item.emoji.isNotEmpty ? item.emoji : '🍕', style: const TextStyle(fontSize: 32)),
                      ),
                    )
                  : Center(
                      child: Text(item.emoji.isNotEmpty ? item.emoji : '🍕', style: const TextStyle(fontSize: 32)),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Content in Middle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildVegNonVegBadge(item.itemType),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
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
                  item.description.isNotEmpty
                      ? item.description
                      : 'Delightful chef specialty prepared with fresh ingredients.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${item.effectivePrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),

                    // Add + Button
                    ElevatedButton(
                      onPressed: () => _openCustomizationModal(item),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          SizedBox(width: 4),
                          Icon(Icons.add_rounded, size: 16),
                        ],
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
  }

  Widget _buildCircularHeaderButton({
    required IconData icon,
    Color iconColor = const Color(0xFF0F172A),
    required VoidCallback onTap,
    double size = 32,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Center(
          child: Icon(icon, size: size * 0.52, color: iconColor),
        ),
      ),
    );
  }
}
