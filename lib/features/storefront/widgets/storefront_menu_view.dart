import 'package:flutter/material.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/restaurant_model.dart';
import '../../../core/network/api_endpoints.dart';
import '../../pos/widgets/pos_product_media_box.dart';
import '../models/storefront_model.dart';

const storefrontBackground = Color(0xFFF6F9FC);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

/// The customer storefront menu view, strictly data-driven and pixel-matched
/// to the modern high-conversion online ordering layout.
class StorefrontMenuView extends StatelessWidget {
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
  });

  Color get brand => Color(data.themeColorHex);
  RestaurantModel get restaurant => data.restaurant;
  bool get canOrder =>
      data.isOnline && (tableSession || restaurant.services.isNotEmpty);

  String money(double amount) =>
      '${restaurant.currencySymbol}${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: storefrontBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: onRefresh,
                  color: brand,
                  child: CustomScrollView(
                    key: const PageStorageKey('storefront-menu'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 0. Preview Banner
                              if (preview)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _ink,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.visibility_outlined,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Storefront Live Preview',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: onExitPreview,
                                        child: const Text(
                                          'Exit Preview',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // 1. Restaurant Top Header
                              _header(),
                              const SizedBox(height: 16),

                              // 2. Fulfillment Pill Selector (Delivery vs Pickup)
                              _fulfilment(),
                              const SizedBox(height: 12),

                              // 3. Address & Delivery ETA Bar
                              _location(),

                              if (refreshing)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: LinearProgressIndicator(
                                    color: brand,
                                    backgroundColor: brand.withValues(
                                      alpha: .12,
                                    ),
                                    minHeight: 2.5,
                                  ),
                                ),

                              if (refreshError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    refreshError!,
                                    style: const TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),

                              if (!data.isOnline)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(top: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFFCA5A5),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        color: Color(0xFFDC2626),
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'This restaurant is currently closed and not accepting online orders.',
                                          style: TextStyle(
                                            color: Color(0xFF991B1B),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // 4. Hero Promo Banner Carousel
                              if (data.banners.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _banners(),
                              ],

                              // 5. Circular Category Avatars Row
                              const SizedBox(height: 20),
                              _categories(),

                              // 6. Search Bar
                              const SizedBox(height: 16),
                              _searchBar(),

                              // 7. Category Title & Dish Count
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$category (${items.length})',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: _ink,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                  if (items.isNotEmpty)
                                    Text(
                                      '${items.length} ${items.length == 1 ? 'dish' : 'dishes'}',
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

                      // Empty state
                      if (items.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.restaurant_menu_rounded,
                                  color: brand.withValues(alpha: .5),
                                  size: 44,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  data.menuItems.isEmpty
                                      ? 'The menu is being updated'
                                      : 'No matching dishes found',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: _ink,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  data.menuItems.isEmpty
                                      ? 'Please check back in a few minutes.'
                                      : 'Try searching with another keyword or pick a different category.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // 8. Products List
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          cartCount > 0 ? 110 : 30,
                        ),
                        sliver: SliverList.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _product(items[index]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 9. Bottom Floating Cart Bar
                if (cartCount > 0)
                  Positioned(
                    bottom: 14,
                    left: 16,
                    right: 16,
                    child: SafeArea(
                      top: false,
                      child: Material(
                        color: _ink,
                        borderRadius: BorderRadius.circular(20),
                        elevation: 8,
                        shadowColor: Colors.black38,
                        child: InkWell(
                          onTap: canOrder ? onCart : null,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$cartCount ${cartCount == 1 ? 'item' : 'items'} added',
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        money(cartTotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          fontSize: 17,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: brand,
                                    borderRadius: BorderRadius.circular(12),
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
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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

  // --- 1. RESTAURANT TOP HEADER ---
  Widget _header() {
    final cuisines = restaurant.cuisineType.trim().isNotEmpty
        ? restaurant.cuisineType.trim()
        : (restaurant.tagline.trim().isNotEmpty
              ? restaurant.tagline.trim()
              : '');

    final opening = restaurant.openingTime.trim().isNotEmpty
        ? restaurant.openingTime.trim()
        : '';
    final closing = restaurant.closingTime.trim().isNotEmpty
        ? restaurant.closingTime.trim()
        : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Avatar Logo
        avatar(restaurant.logoUrl, restaurant.name, 56),
        const SizedBox(width: 12),

        // Center Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                restaurant.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                cuisines,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if ((data.rating ?? 0) > 0) ...[
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 15,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      data.rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      data.reviewCount.isEmpty ? '' : '(${data.reviewCount})',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: data.isOnline
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      data.isOnline ? 'Open' : 'Closed',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: data.isOnline
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              if (opening.isNotEmpty || closing.isNotEmpty)
                Text(
                  [opening, closing].where((s) => s.isNotEmpty).join(' - '),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
            ],
          ),
        ),

        // Right Action Buttons (Favorite + More 3-Dots)
        const SizedBox(width: 6),
        _circleButton(
          icon: favorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          color: favorite ? const Color(0xFFEF4444) : _ink,
          onTap: onFavorite,
          tooltip: 'Favorite restaurant',
        ),
        const SizedBox(width: 8),
        _circleButton(
          icon: Icons.more_vert_rounded,
          color: _ink,
          onTap: onInfo,
          tooltip: 'Restaurant details',
        ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  // --- 2. FULFILLMENT SELECTOR (DELIVERY VS PICKUP) ---
  Widget _fulfilment() {
    final options = <OrderType, (String, IconData)>{
      if (!tableSession && restaurant.services.contains('Delivery'))
        OrderType.delivery: ('Delivery', Icons.delivery_dining_rounded),
      if (!tableSession && restaurant.services.contains('Takeaway'))
        OrderType.takeaway: ('Pickup', Icons.storefront_rounded),
      if (tableSession || restaurant.services.contains('Dine In'))
        OrderType.dineIn: ('Dine-in', Icons.table_restaurant_rounded),
    };

    if (options.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: options.entries.map((entry) {
          final selected = orderType == entry.key;
          return Expanded(
            child: Material(
              color: selected ? brand : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              elevation: selected ? 2 : 0,
              shadowColor: brand.withValues(alpha: 0.4),
              child: InkWell(
                onTap: () => onOrderType(entry.key),
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        entry.value.$2,
                        size: 17,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          entry.value.$1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF64748B),
                          ),
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
    );
  }

  // --- 3. ADDRESS & LIVE TRACKING BAR ---
  Widget _location() {
    final delivery = orderType == OrderType.delivery;
    final address = tableSession
        ? 'Table ${tableCode ?? ''}'
        : delivery
        ? (deliveryAddress.isNotEmpty
              ? deliveryAddress
              : 'Choose your delivery location')
        : (restaurant.address.isNotEmpty
              ? restaurant.address
              : 'Restaurant address');

    final eta = delivery ? data.deliveryEta : data.pickupEta;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      child: InkWell(
        onTap: delivery && !tableSession ? onLocation : onInfo,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(
                tableSession
                    ? Icons.table_restaurant_rounded
                    : Icons.location_on_rounded,
                color: brand,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (eta.isNotEmpty && !tableSession)
                      Text(
                        delivery ? 'Delivery in $eta' : 'Pickup ready in $eta',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (delivery && !tableSession) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Change',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: brand,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: brand, size: 16),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- 4. HERO PROMO BANNER CAROUSEL ---

  Widget _banners() => Column(
    children: [
      SizedBox(
        height: 175,
        child: PageView.builder(
          controller: bannerController,
          itemCount: data.banners.length,
          onPageChanged: onBannerChanged,
          itemBuilder: (_, index) {
            final banner = data.banners[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(
                color: Color(banner.accentColorHex),
                child: InkWell(
                  onTap: () => onBanner(banner),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (banner.imageUrl.isNotEmpty) _image(banner.imageUrl),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xDD101010),
                              Color(0x88101010),
                              Color(0x33101010),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (banner.tag.isNotEmpty)
                                  Expanded(
                                    child: Text(
                                      banner.tag.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFFFCD34D),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                if (banner.discountText?.isNotEmpty == true)
                                  Flexible(
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        banner.discountText!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            if (banner.headline.isNotEmpty)
                              Text(
                                banner.headline,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  height: 1.05,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            if (banner.subtitle.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  banner.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            Row(
                              children: [
                                if (banner.ctaText.isNotEmpty)
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: brand,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        banner.ctaText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (banner.couponCode?.isNotEmpty == true)
                                  Flexible(
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'CODE: ' + banner.couponCode!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
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
                ),
              ),
            );
          },
        ),
      ),
      if (data.banners.length > 1)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              data.banners.length,
              (i) => Container(
                width: i == bannerIndex ? 18 : 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == bannerIndex ? brand : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
    ],
  );

  // --- 5. CIRCULAR FOOD CATEGORY AVATARS ---
  String _categoryImage(String name) {
    for (final item in data.menuItems) {
      if (name == 'All' || item.category.toLowerCase() == name.toLowerCase()) {
        if (item.imageUrl.isNotEmpty) return item.imageUrl;
        if (item.images.isNotEmpty) return item.images.first;
      }
    }
    return '';
  }

  Widget _categories() => SizedBox(
    height: 98,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: data.categories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (_, index) {
        final name = data.categories[index];
        final selected = category == name;
        final imagePath = _categoryImage(name);

        return InkWell(
          onTap: () => onCategory(name),
          borderRadius: BorderRadius.circular(35),
          child: SizedBox(
            width: 68,
            child: Column(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: selected ? brand : const Color(0xFFE2E8F0),
                      width: selected ? 2.5 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: brand.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipOval(child: _image(imagePath, fit: BoxFit.cover)),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                    color: selected ? brand : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  // --- 6. SEARCH BAR ---
  Widget _searchBar() {
    return TextField(
      controller: searchController,
      onChanged: onSearch,
      style: const TextStyle(
        fontSize: 13,
        color: _ink,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: 'Search for pizzas, burgers, drinks...',
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 21,
          color: Color(0xFF94A3B8),
        ),
        suffixIcon: searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  searchController.clear();
                  onSearch('');
                },
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
        filled: true,
        fillColor: const Color(0xFFEEF2F6),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: brand, width: 1.5),
        ),
      ),
    );
  }

  // --- 7. DISH PRODUCT CARD ---
  Widget _product(MenuItemModel item) => RepaintBoundary(
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      child: InkWell(
        onTap: () => onProduct(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Dish Media Box
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: PosProductMediaBox(
                        key: ValueKey('storefront-product-${item.id}'),
                        item: item,
                        autoPlayVideo: false,
                        showDots: false,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    if (item.variants.length > 1)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xCC000000),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${item.variants.length} sizes',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Right Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Veg/Non-Veg + Title + Rating Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _vegBadge(item.itemType),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (item.rating > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 12,
                                  color: Color(0xFFD97706),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  item.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    // Description
                    if (item.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: _muted,
                          ),
                        ),
                      ),

                    const SizedBox(height: 10),

                    // Price and Add Button Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                money(item.effectivePrice),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: _ink,
                                ),
                              ),
                              if (item.hasDiscount)
                                Text(
                                  money(item.price),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: _muted,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: canOrder && item.isAvailable
                              ? brand.withValues(alpha: 0.08)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: canOrder && item.isAvailable
                                ? () => onProduct(item)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6.5,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: canOrder && item.isAvailable
                                      ? brand
                                      : const Color(0xFFCBD5E1),
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                canOrder && item.isAvailable
                                    ? '+ ADD'
                                    : 'Unavailable',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: canOrder && item.isAvailable
                                      ? brand
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
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
        ),
      ),
    ),
  );

  Widget _vegBadge(String itemType) {
    final isNonVeg = itemType.toLowerCase().contains('non');
    final isEgg = itemType.toLowerCase().contains('egg');
    final color = isNonVeg
        ? const Color(0xFFDC2626)
        : (isEgg ? const Color(0xFFD97706) : const Color(0xFF16A34A));

    return Container(
      width: 14,
      height: 14,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(3.5),
      ),
      child: Center(
        child: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _image(String path, {BoxFit fit = BoxFit.cover}) {
    final url = ApiEndpoints.resolveMediaUrl(path);
    final fallback = ColoredBox(
      color: brand.withValues(alpha: .08),
      child: Icon(
        Icons.restaurant_rounded,
        color: brand.withValues(alpha: .4),
        size: 24,
      ),
    );
    if (url.isEmpty) return fallback;
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: fit,
        cacheWidth: 512,
        errorBuilder: (_, error, stack) => fallback,
      );
    }
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: fit,
        cacheWidth: 768,
        errorBuilder: (_, error, stack) => fallback,
      );
    }
    return fallback;
  }
}

/// Dynamic, restaurant-branded skeleton loading view that smoothly animates
/// while the API menu is loaded, avoiding any jarring screen jumps or blocking spinners.
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
                  // 1. Restaurant Header
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

                  // Linear Brand Progress Indicator
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      color: _brand,
                      backgroundColor: _brand.withValues(alpha: .12),
                      minHeight: 3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Fulfillment Toggle Skeleton
                  _shimmerBox(46, radius: 24),
                  const SizedBox(height: 12),

                  // 3. Address Bar Skeleton
                  _shimmerBox(48, radius: 16),
                  const SizedBox(height: 16),

                  // 4. Hero Banner Skeleton
                  _shimmerBox(175, radius: 20),
                  const SizedBox(height: 20),

                  // 5. Circular Categories Skeleton
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      4,
                      (_) => Column(
                        children: [
                          _shimmerBox(60, width: 60, radius: 30),
                          const SizedBox(height: 6),
                          _shimmerBox(10, width: 44, radius: 5),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 6. Search Bar Skeleton
                  _shimmerBox(46, radius: 24),
                  const SizedBox(height: 20),

                  // 7. Dish Cards Skeletons
                  for (var i = 0; i < 3; i++) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            _shimmerBox(92, width: 92, radius: 14),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _shimmerBox(16, width: 140, radius: 6),
                                  const SizedBox(height: 8),
                                  _shimmerBox(12, width: 180, radius: 6),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _shimmerBox(18, width: 60, radius: 6),
                                      _shimmerBox(28, width: 70, radius: 8),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
