import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/restaurant_model.dart';
import '../models/customer_storefront_flow_models.dart';
import '../models/storefront_model.dart';
import '../screens/restaurant_info_screen.dart';
import 'online_order_flow_widgets.dart';

const storefrontBackground = Color(0xFFF6F9FC);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

/// The modern customer storefront delivery view matching the 6-screen online order delivery flow:
/// 1. Online Order Home
/// 2. Restaurant Info (From Logo Tap)
/// 3. Our Menu (Add to Cart)
/// 4. Your Cart (Delivery Address)
/// 5. Login (Before Checkout)
/// 6. Payment Method (Popup)
class StorefrontMenuView extends StatefulWidget {
  final StorefrontData data;
  final List<MenuItemModel> items;
  final OrderType orderType;
  final String category, deliveryAddress;
  final bool favorite, preview, tableSession, refreshing;
  final String? tableCode, refreshError;
  final TextEditingController searchController;
  final PageController bannerController;
  final int bannerIndex, cartCount;
  final double cartTotal;
  final Future<void> Function() onRefresh;
  final ValueChanged<OrderType> onOrderType;
  final ValueChanged<String> onCategory, onSearch;
  final ValueChanged<int> onBannerChanged;
  final ValueChanged<StorefrontBanner> onBanner;
  final ValueChanged<MenuItemModel> onProduct;
  final VoidCallback onFavorite, onInfo, onLocation, onCart, onExitPreview;
  final Widget Function(String?, String, double) avatar;

  // Optional callbacks and data for full delivery workflow
  final List<StorefrontCartItem>? cartItems;
  final void Function(MenuItemModel)? onAddToCart;
  final void Function(StorefrontCartItem, int)? onUpdateQuantity;
  final VoidCallback? onClearCart;
  final Future<void> Function(String paymentMethod, String address, String instructions)? onPlaceOrder;
  final CustomerProfileModel? customer;
  final ValueChanged<CustomerProfileModel>? onUpdateCustomer;
  final String? restaurantCode;

  const StorefrontMenuView({
    super.key,
    required this.data,
    required this.items,
    required this.orderType,
    required this.category,
    required this.deliveryAddress,
    required this.favorite,
    required this.preview,
    required this.tableSession,
    required this.refreshing,
    this.tableCode,
    this.refreshError,
    required this.searchController,
    required this.bannerController,
    required this.bannerIndex,
    required this.cartCount,
    required this.cartTotal,
    required this.onRefresh,
    required this.onOrderType,
    required this.onCategory,
    required this.onSearch,
    required this.onBannerChanged,
    required this.onBanner,
    required this.onProduct,
    required this.onFavorite,
    required this.onInfo,
    required this.onLocation,
    required this.onCart,
    required this.onExitPreview,
    required this.avatar,
    this.cartItems,
    this.onAddToCart,
    this.onUpdateQuantity,
    this.onClearCart,
    this.onPlaceOrder,
    this.customer,
    this.onUpdateCustomer,
    this.restaurantCode,
  });

  @override
  State<StorefrontMenuView> createState() => _StorefrontMenuViewState();
}

class _StorefrontMenuViewState extends State<StorefrontMenuView> {
  int _currentTab = 0; // 0: Home, 1: Menu, 2: Cart, 3: Orders, 4: Account
  bool _showRestaurantInfoView = false;
  bool _vegOnly = false;
  final TextEditingController _cookingInstructionsController = TextEditingController();
  CustomerProfileModel? _localCustomer;
  String _localDeliveryAddress = '';

  // Order tracking history
  final List<Map<String, dynamic>> _placedOrders = [];

  Color get brand => const Color(0xFF2563EB); // Vibrant delivery blue matching design
  RestaurantModel get restaurant => widget.data.restaurant;
  bool get canOrder => widget.data.isOnline && (widget.tableSession || restaurant.services.isNotEmpty);

  String money(double amount) =>
      '${restaurant.currencySymbol}${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';

  @override
  void initState() {
    super.initState();
    _localCustomer = widget.customer;
    _localDeliveryAddress = widget.deliveryAddress.isNotEmpty
        ? widget.deliveryAddress
        : (widget.customer?.addresses.isNotEmpty == true
            ? widget.customer!.addresses.first.fullAddress
            : (restaurant.address.isNotEmpty ? restaurant.address : 'Shop No. 12, Sector 5, Dwarka, Delhi - 110075'));
  }

  @override
  void didUpdateWidget(covariant StorefrontMenuView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customer != oldWidget.customer) {
      _localCustomer = widget.customer;
    }
    if (widget.deliveryAddress != oldWidget.deliveryAddress && widget.deliveryAddress.isNotEmpty) {
      _localDeliveryAddress = widget.deliveryAddress;
    }
  }

  @override
  void dispose() {
    _cookingInstructionsController.dispose();
    super.dispose();
  }

  // Find quantity of an item in cart
  int _getItemCartQuantity(MenuItemModel item) {
    if (widget.cartItems == null) return 0;
    final found = widget.cartItems!.where((c) => c.item.id == item.id);
    return found.fold(0, (sum, i) => sum + i.quantity);
  }

  StorefrontCartItem? _getCartItem(MenuItemModel item) {
    if (widget.cartItems == null) return null;
    return widget.cartItems!.cast<StorefrontCartItem?>().firstWhere(
      (c) => c?.item.id == item.id,
      orElse: () => null,
    );
  }

  void _handleAddItem(MenuItemModel item) {
    widget.onProduct(item);
  }

  void _handleIncrementItem(MenuItemModel item) {
    final cartItem = _getCartItem(item);
    if (cartItem != null && widget.onUpdateQuantity != null) {
      widget.onUpdateQuantity!(cartItem, cartItem.quantity + 1);
    } else {
      _handleAddItem(item);
    }
  }

  void _handleDecrementItem(MenuItemModel item) {
    final cartItem = _getCartItem(item);
    if (cartItem != null && widget.onUpdateQuantity != null) {
      widget.onUpdateQuantity!(cartItem, cartItem.quantity - 1);
    }
  }

  String _getCategoryEmoji(String category) {
    final c = category.toLowerCase();
    if (c.contains('pizza')) return '🍕';
    if (c.contains('burger')) return '🍔';
    if (c.contains('side') || c.contains('bread') || c.contains('snack') || c.contains('starter')) return '🥪';
    if (c.contains('drink') || c.contains('beverage') || c.contains('shake') || c.contains('juice') || c.contains('lime')) return '🥤';
    if (c.contains('dessert') || c.contains('cake') || c.contains('sweet')) return '🍰';
    if (c.contains('pasta') || c.contains('noodle')) return '🍝';
    if (c.contains('combo') || c.contains('meal') || c.contains('box')) return '🍱';
    return '🍽️';
  }

  // Proceed to Checkout -> Trigger Screen 5 (Login) or Screen 6 (Payment)
  Future<void> _handleProceedToCheckout() async {
    if ((widget.cartItems?.isEmpty ?? true) && widget.cartCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty. Add dishes to checkout.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final subtotal = widget.cartTotal > 0 ? widget.cartTotal : 399.0;
    final tax = (subtotal * 0.05);
    final deliveryFee = widget.orderType == OrderType.delivery
        ? (restaurant.deliveryBaseCharge > 0 ? restaurant.deliveryBaseCharge : 40.0)
        : 0.0;
    final grandTotal = subtotal + tax + deliveryFee;

    CustomerProfileModel? customer = _localCustomer;

    // Step 5: If customer is not authenticated/verified, open Screen 5 Login Sheet
    if (customer == null) {
      final loggedIn = await OnlineLoginModalSheet.show(
        context,
        restaurant: restaurant,
      );
      if (loggedIn == null) return; // User closed sheet
      customer = loggedIn;
      setState(() => _localCustomer = customer);
      if (widget.onUpdateCustomer != null) {
        widget.onUpdateCustomer!(customer);
      }
    }

    if (!mounted) return;

    // Step 6: Open Screen 6 Payment Method Popup
    final paymentMethod = await OnlinePaymentModalSheet.show(
      context,
      totalAmount: grandTotal,
    );
    if (paymentMethod == null) return; // User closed sheet

    // Process order
    if (widget.onPlaceOrder != null) {
      await widget.onPlaceOrder!(
        paymentMethod,
        _localDeliveryAddress,
        _cookingInstructionsController.text.trim(),
      );
    }

    final newOrderId = '#ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    setState(() {
      _placedOrders.insert(0, {
        'orderNumber': newOrderId,
        'date': 'Today, ${TimeOfDay.now().format(context)}',
        'status': 'Awaiting restaurant acceptance',
        'total': grandTotal,
        'itemsCount': widget.cartCount > 0 ? widget.cartCount : 1,
        'paymentMethod': paymentMethod,
        'address': _localDeliveryAddress,
      });
      _currentTab = 3; // Switch to Orders tab
    });

    if (widget.onClearCart != null) {
      widget.onClearCart!();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order $newOrderId placed successfully!'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showChangeAddressDialog() {
    final controller = TextEditingController(text: _localDeliveryAddress);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Enter Delivery Address',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Enter complete house/street address',
            prefixIcon: Icon(Icons.location_on_rounded, color: Color(0xFF2563EB)),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _localDeliveryAddress = controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If Screen 2: Restaurant Info is toggled
    if (_showRestaurantInfoView) {
      return RestaurantInfoScreen(
        restaurant: restaurant,
        data: widget.data,
        themeColor: brand,
        avatar: widget.avatar,
        onBack: () => setState(() => _showRestaurantInfoView = false),
      );
    }

    return Scaffold(
      backgroundColor: storefrontBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _buildCurrentTabBody(),
          ),
        ),
      ),
      bottomNavigationBar: OnlineStorefrontBottomBar(
        currentIndex: _currentTab,
        cartCount: widget.cartCount,
        activeColor: brand,
        onTabSelected: (index) {
          setState(() => _currentTab = index);
        },
      ),
    );
  }

  Widget _buildCurrentTabBody() {
    switch (_currentTab) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildMenuTab();
      case 2:
        return _buildCartTab();
      case 3:
        return _buildOrdersTab();
      case 4:
        return _buildAccountTab();
      default:
        return _buildHomeTab();
    }
  }

  // ===========================================================================
  // SCREEN 1: ONLINE ORDER HOME TAB
  // ===========================================================================
  Widget _buildHomeTab() {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: widget.onRefresh,
          color: brand,
          child: CustomScrollView(
            key: const PageStorageKey('storefront-home-tab'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 0. Live Preview Banner
                      if (widget.preview) _previewBanner(),

                      // 1. Restaurant Header (Screen 1 header with Logo, Pizza 47, Restaurant, Open hours >)
                      _homeHeader(),

                      const SizedBox(height: 12),

                      // 2. Fulfillment Switcher (Delivery vs Pickup)
                      _fulfilmentPills(),

                      const SizedBox(height: 14),

                      // 3. Hero Promo Banner: "Order Food Online - Freshly baked, delivered to your doorstep."
                      _heroBannerCard(),

                      const SizedBox(height: 20),

                      // 4. Popular Picks Section with "View All ->" and horizontal cards
                      _popularPicksSection(),

                      const SizedBox(height: 20),

                      // 4. Search Bar
                      _searchBarField(),

                      const SizedBox(height: 14),

                      // 5. Category Pills Row (All, Paneer Pizza, etc.)
                      _categoryPillsRow(),

                      const SizedBox(height: 16),

                      // 6. Category Title & Dishes Count Row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${widget.category} (${widget.items.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (widget.items.isNotEmpty)
                            Text(
                              '${widget.items.length} dishes',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _muted,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Dishes List
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, widget.cartCount > 0 ? 80 : 30),
                sliver: SliverList.builder(
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _dishCard(widget.items[index]),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Floating Sticky Bottom Cart Bar
        if (widget.cartCount > 0)
          Positioned(
            bottom: 12,
            left: 16,
            right: 16,
            child: Material(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              elevation: 6,
              child: InkWell(
                onTap: widget.onCart,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${widget.cartCount} ${widget.cartCount == 1 ? "item" : "items"} added • ${money(widget.cartTotal)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: brand,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View Cart',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
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
    );
  }

  Widget _previewBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Storefront Live Preview',
              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: widget.onExitPreview,
            child: const Text('Exit Preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // Screen 1 Header: Logo, Pizza 47, Restaurant, Open 09:00 AM - 11:00 PM >
  Widget _homeHeader() {
    final open = restaurant.openingTime.trim().isNotEmpty ? restaurant.openingTime.trim() : '09:00 AM';
    final close = restaurant.closingTime.trim().isNotEmpty ? restaurant.closingTime.trim() : '11:00 PM';

    return InkWell(
      onTap: () => setState(() => _showRestaurantInfoView = true),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // Restaurant circular logo
            widget.avatar(restaurant.logoUrl, restaurant.name, 48),
            const SizedBox(width: 12),

            // Name, Category, Open Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name.isNotEmpty ? restaurant.name : 'Pizza 47',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'Restaurant',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _muted),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: widget.data.isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.data.isOnline ? 'Open' : 'Closed',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: widget.data.isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '$open - $close',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ],
              ),
            ),

            // Top action button: Right chevron in circle
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fulfilmentPills() {
    final isDelivery = widget.orderType == OrderType.delivery;
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFulfilmentOption(
              label: 'Delivery',
              icon: Icons.delivery_dining_rounded,
              isSelected: isDelivery,
              onTap: () => widget.onOrderType(OrderType.delivery),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildFulfilmentOption(
              label: 'Pickup',
              icon: Icons.shopping_bag_outlined,
              isSelected: !isDelivery,
              onTap: () => widget.onOrderType(OrderType.takeaway),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFulfilmentOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? brand : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? brand : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBarField() {
    return Container(
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
      child: TextField(
        controller: widget.searchController,
        onChanged: widget.onSearch,
        decoration: InputDecoration(
          hintText: 'Search pizzas, sides & drinks',
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
          suffixIcon: widget.searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    widget.searchController.clear();
                    widget.onSearch('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _categoryPillsRow() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.data.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = widget.data.categories[index];
          final isSelected = widget.category == cat;
          return InkWell(
            onTap: () => widget.onCategory(cat),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? brand : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? brand : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Hero Card matching Screen 1
  Widget _heroBannerCard() {
    // Check if banners from API exist with custom headlines
    final customBanner = widget.data.banners.isNotEmpty ? widget.data.banners[widget.bannerIndex] : null;

    return InkWell(
      onTap: () => setState(() => _currentTab = 1), // Tapping hero switches to Menu
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 120, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (customBanner != null)
                      Text(
                        customBanner.headline,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      )
                    else
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'Order Food ',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            TextSpan(
                              text: 'Online',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFF59E0B), // Golden yellow
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      customBanner?.subtitle.isNotEmpty == true
                          ? customBanner!.subtitle
                          : 'Freshly baked, delivered to your doorstep.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: -10,
                bottom: -10,
                child: SizedBox(
                  width: 140,
                  height: 130,
                  child: Image.asset(
                    'assets/images/tpl_food_diwali_pizza.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.local_pizza_rounded,
                      size: 90,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Popular Picks Section with View All ->
  Widget _popularPicksSection() {
    final isFiltering = widget.searchController.text.isNotEmpty || widget.category != 'All';
    if (isFiltering || widget.items.length <= 2) return const SizedBox.shrink();

    final picks = widget.items.take(6).toList();
    if (picks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Popular Picks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _currentTab = 1),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 15,
                      color: Color(0xFF2563EB),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: picks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = picks[index];
              final qty = _getItemCartQuantity(item);
              return Container(
                width: 165,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Food Image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: SizedBox(
                        width: double.infinity,
                        height: 98,
                        child: buildFoodThumbnail(item.imageUrl, size: 98, radius: 0),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              buildFoodTypeBadge(item.itemType),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                money(item.price),
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  color: _ink,
                                ),
                              ),
                              if (qty == 0)
                                if (!canOrder)
                                  const SizedBox.shrink()
                                else
                                  InkWell(
                                    onTap: () => _handleAddItem(item),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEFF6FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.add_rounded,
                                          size: 18,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  )
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: brand, width: 1.2),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => _handleDecrementItem(item),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          child: Icon(Icons.remove, size: 13, color: brand),
                                        ),
                                      ),
                                      Text(
                                        '$qty',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          color: brand,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _handleIncrementItem(item),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          child: Icon(Icons.add, size: 13, color: brand),
                                        ),
                                      ),
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
            },
          ),
        ),
      ],
    );
  }

  // Dish Card with thumbnail, veg badge, title, description, price, and + Add / stepper
  Widget _dishCard(MenuItemModel item) {
    final qty = _getItemCartQuantity(item);
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
          // Food Thumbnail
          buildFoodThumbnail(item.imageUrl, size: 80, radius: 12),
          const SizedBox(width: 12),

          // Details: veg badge, name, description, price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    buildFoodTypeBadge(item.itemType),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: _muted,
                      height: 1.3,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      money(item.price),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),

                    // Add or Stepper
                    if (!canOrder)
                      const SizedBox.shrink()
                    else if (qty == 0)
                      ElevatedButton(
                        onPressed: () => _handleAddItem(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          minimumSize: const Size(64, 32),
                        ),
                        child: const Text(
                          '+ ADD',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: brand, width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 16),
                              color: brand,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () => _handleDecrementItem(item),
                            ),
                            Text(
                              '$qty',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: brand,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, size: 16),
                              color: brand,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () => _handleIncrementItem(item),
                            ),
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

  // ===========================================================================
  // SCREEN 3: MENU TAB (ADD TO CART)
  // ===========================================================================
  Widget _buildMenuTab() {
    // Filter items based on veg-only toggle and search
    var menuList = widget.items;
    if (_vegOnly) {
      menuList = menuList.where((i) => i.itemType.toLowerCase() == 'veg').toList();
    }

    // Group items by category
    final Map<String, List<MenuItemModel>> grouped = {};
    for (final item in menuList) {
      final cat = item.category.isNotEmpty ? item.category : 'Dishes';
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    return Stack(
      children: [
        CustomScrollView(
          key: const PageStorageKey('storefront-menu-tab'),
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top App Bar: <- Our Menu
                    Row(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _currentTab = 0), // Back to Home
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(Icons.arrow_back_rounded, size: 20, color: _ink),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Text(
                          'Our Menu',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Search bar: Search pizzas, sides & drinks
                    _searchBarField(),

                    const SizedBox(height: 14),

                    // Category Filter Pills: All, 🍕 Pizza, 🥪 Sides, 🥤 Drinks
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: widget.data.categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = widget.data.categories[index];
                          final isSelected = widget.category == cat;
                          final emoji = cat == 'All' ? '🍽️' : _getCategoryEmoji(cat);
                          return InkWell(
                            onTap: () => widget.onCategory(cat),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? brand : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? brand : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(emoji, style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 5),
                                  Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? Colors.white : const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Veg Only Switch Toggle Row
                    Row(
                      children: [
                        const Text(
                          'Veg only',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: _vegOnly,
                            activeColor: const Color(0xFF16A34A),
                            onChanged: (val) => setState(() => _vegOnly = val),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Category Sections with item counts: Pizzas 6 items, Sides 4 items
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, widget.cartCount > 0 ? 90 : 30),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final catName = grouped.keys.elementAt(index);
                    final catDishes = grouped[catName]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                catName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: _ink,
                                ),
                              ),
                              Text(
                                '${catDishes.length} items',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...catDishes.map((dish) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _dishCard(dish),
                            )),
                      ],
                    );
                  },
                  childCount: grouped.keys.length,
                ),
              ),
            ),
          ],
        ),

        // Floating Sticky Bottom Cart Bar: 1 item • ₹399 with View Cart ->
        if (widget.cartCount > 0)
          Positioned(
            bottom: 12,
            left: 16,
            right: 16,
            child: Material(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              elevation: 6,
              child: InkWell(
                onTap: widget.onCart,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${widget.cartCount} ${widget.cartCount == 1 ? "item" : "items"} • ${money(widget.cartTotal)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: brand,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View Cart',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
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
    );
  }

  // ===========================================================================
  // SCREEN 4: YOUR CART TAB (DELIVERY ADDRESS)
  // ===========================================================================
  Widget _buildCartTab() {
    final cartList = widget.cartItems ?? [];
    final subtotal = widget.cartTotal > 0 ? widget.cartTotal : 0.0;
    final tax = (subtotal * 0.05);
    final deliveryFee = widget.orderType == OrderType.delivery
        ? (restaurant.deliveryBaseCharge > 0 ? restaurant.deliveryBaseCharge : 40.0)
        : 0.0;
    final grandTotal = subtotal + tax + deliveryFee;

    return Column(
      children: [
        // Top App Bar: <- Your Cart
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              InkWell(
                onTap: () => setState(() => _currentTab = 1), // Back to Menu
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 20, color: _ink),
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Your Cart',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink),
              ),
            ],
          ),
        ),

        // Scrollable Cart Contents
        Expanded(
          child: cartList.isEmpty && widget.cartCount == 0
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_cart_outlined, size: 56, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 16),
                        const Text(
                          'Your cart is empty',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Add tasty items from the menu to get started.',
                          style: TextStyle(fontSize: 13, color: _muted),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => setState(() => _currentTab = 1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brand,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('Explore Menu'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Delivery Address Card with Blue Circular Pin and >
                      InkWell(
                        onTap: _showChangeAddressDialog,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Enter Delivery Address',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: _ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _localDeliveryAddress,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Color(0xFF2563EB), size: 20),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 2. Cart Items List with stepper — 1 +
                      ...List.generate(cartList.length, (index) {
                        final cItem = cartList[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              buildFoodThumbnail(cItem.item.imageUrl, size: 60, radius: 10),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        buildFoodTypeBadge(cItem.item.itemType),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            cItem.item.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: _ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      money(cItem.totalPrice),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: _ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Stepper — 1 +
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        if (widget.onUpdateQuantity != null) {
                                          widget.onUpdateQuantity!(cItem, cItem.quantity - 1);
                                        }
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Icon(Icons.remove, size: 14, color: _ink),
                                      ),
                                    ),
                                    Text(
                                      '${cItem.quantity}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        if (widget.onUpdateQuantity != null) {
                                          widget.onUpdateQuantity!(cItem, cItem.quantity + 1);
                                        }
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Icon(Icons.add, size: 14, color: _ink),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // 3. + Add more items link
                      InkWell(
                        onTap: () => setState(() => _currentTab = 1), // Go to Menu
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.add_rounded, size: 18, color: Color(0xFF2563EB)),
                              SizedBox(width: 6),
                              Text(
                                '+ Add more items',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 4. Cooking instructions card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_note_rounded, size: 22, color: Color(0xFF2563EB)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _cookingInstructionsController,
                                decoration: const InputDecoration(
                                  hintText: 'Add cooking instructions (e.g., less spicy, extra cheese)',
                                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 5. Bill Summary Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bill Summary',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
                            ),
                            const SizedBox(height: 12),
                            _buildBillRow('Subtotal', money(subtotal)),
                            const SizedBox(height: 8),
                            _buildBillRow('GST (5%)', money(tax)),
                            if (deliveryFee > 0) ...[
                              const SizedBox(height: 8),
                              _buildBillRow('Delivery Fee', money(deliveryFee)),
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(color: Color(0xFFE2E8F0)),
                            ),
                            _buildBillRow('Total Amount', money(grandTotal), isBold: true),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 6. Sticky Bottom Button: Proceed to Checkout ->
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _handleProceedToCheckout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brand,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Proceed to Checkout',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBillRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w500,
            color: isBold ? _ink : const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: _ink,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 3: ORDERS TAB
  // ===========================================================================
  Widget _buildOrdersTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: Colors.white,
          child: const Row(
            children: [
              Text('My Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink)),
            ],
          ),
        ),
        Expanded(
          child: _placedOrders.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 56, color: Color(0xFF94A3B8)),
                        const SizedBox(height: 16),
                        const Text(
                          'No active orders',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Your placed orders will show real-time live status here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: _muted),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => setState(() => _currentTab = 1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brand,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('Browse Menu'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: _placedOrders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final o = _placedOrders[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                o['orderNumber'] as String,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _ink),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  o['status'] as String,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            o['date'] as String,
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${o["itemsCount"]} items • ${o["paymentMethod"]}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink),
                              ),
                              Text(
                                money(o['total'] as double),
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: brand),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 4: ACCOUNT TAB
  // ===========================================================================
  Widget _buildAccountTab() {
    final customer = _localCustomer;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('My Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink)),
          const SizedBox(height: 16),

          // Profile card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: brand.withValues(alpha: 0.15),
                  child: Icon(Icons.person_rounded, size: 28, color: brand),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer?.name ?? 'Guest Customer',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        customer?.phone ?? '+91 98765 43210',
                        style: const TextStyle(fontSize: 12.5, color: _muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Saved Address card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text(
                      'Default Delivery Address',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _localDeliveryAddress,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _showChangeAddressDialog,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(60, 32),
                  ),
                  child: const Text('Change Address', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Quick Links
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB)),
                  title: const Text('Restaurant Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => setState(() => _showRestaurantInfoView = true),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.support_agent_rounded, color: Color(0xFF10B981)),
                  title: const Text('Help & Support', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Support: Call restaurant directly or email support@apnapos.com')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StorefrontMenuLoading extends StatefulWidget {
  final RestaurantModel? restaurant;
  final Widget Function(String?, String, double) avatar;

  const StorefrontMenuLoading({
    super.key,
    this.restaurant,
    required this.avatar,
  });

  @override
  State<StorefrontMenuLoading> createState() => _StorefrontMenuLoadingState();
}

class _StorefrontMenuLoadingState extends State<StorefrontMenuLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Color get _brand =>
      Color(widget.restaurant?.storefrontThemeColor ?? 0xFFE65100);

  Widget _shimmerBox(double height, {double? width, double radius = 12}) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE2E8F0),
                Color(0xFFF1F5F9),
                Color(0xFFE2E8F0),
              ],
              stops: [
                (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                _shimmerController.value,
                (_shimmerController.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.restaurant?.name ?? '';
    final cuisine = widget.restaurant?.cuisineType ?? '';

    return Scaffold(
      backgroundColor: storefrontBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      widget.avatar(
                        widget.restaurant?.logoUrl,
                        name.isEmpty ? 'Menu' : name,
                        56,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Opening menu' : name,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              name.isEmpty ? cuisine : "Loading $name's menu...",
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      color: _brand,
                      backgroundColor: _brand.withValues(alpha: .12),
                      minHeight: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _shimmerBox(44, radius: 14),
                  const SizedBox(height: 16),
                  _shimmerBox(140, radius: 16),
                  const SizedBox(height: 20),
                  _shimmerBox(40, radius: 20),
                  const SizedBox(height: 20),
                  _shimmerBox(90, radius: 14),
                  const SizedBox(height: 12),
                  _shimmerBox(90, radius: 14),
                  const SizedBox(height: 12),
                  _shimmerBox(90, radius: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
