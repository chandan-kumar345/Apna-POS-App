import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/restaurant_model.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/storefront_model.dart';
import '../widgets/online_order_flow_widgets.dart';

class RestaurantInfoScreen extends StatelessWidget {
  final RestaurantModel restaurant;
  final StorefrontData? data;
  final Color themeColor;
  final Widget Function(String?, String, double) avatar;
  final VoidCallback onBack;

  const RestaurantInfoScreen({
    super.key,
    required this.restaurant,
    this.data,
    this.themeColor = const Color(0xFF2563EB),
    required this.avatar,
    required this.onBack,
  });

  String get _cuisines {
    if (restaurant.cuisineType.trim().isNotEmpty) {
      return restaurant.cuisineType.trim().replaceAll(',', ' •');
    }
    return 'Restaurant';
  }

  String get _address => restaurant.address.trim();

  String get _phone => restaurant.phone.trim();

  String get _hours {
    final open = restaurant.openingTime.trim().isNotEmpty
        ? restaurant.openingTime.trim()
        : '09:00 AM';
    final close = restaurant.closingTime.trim().isNotEmpty
        ? restaurant.closingTime.trim()
        : '11:00 PM';
    return '$open - $close';
  }

  String get _aboutUs {
    if (restaurant.tagline.trim().isNotEmpty) {
      return restaurant.tagline.trim();
    }
    final name = restaurant.name.trim().isNotEmpty
        ? restaurant.name.trim()
        : 'Our restaurant';
    return 'Freshly prepared dishes from $name, delivered hot to your doorstep.';
  }

  String get _deliveryFeeAmount {
    if (restaurant.deliveryBaseCharge <= 0) {
      return 'Free';
    }
    final fee = restaurant.deliveryBaseCharge;
    return '${restaurant.currencySymbol}${fee.toStringAsFixed(fee % 1 == 0 ? 0 : 2)}';
  }

  String get _deliveryFeeSubtitle {
    if (restaurant.freeDeliveryEnabled && restaurant.freeDeliveryMinOrder > 0) {
      return 'Free above ${restaurant.currencySymbol}${restaurant.freeDeliveryMinOrder.toStringAsFixed(0)}';
    }
    return 'Delivery Fee';
  }

  bool get _isOnline => data?.isOnline ?? restaurant.isStorefrontOnline;

  String get _coverImageUrl {
    final bannerImg = data?.banners
        .map((b) => b.imageUrl.trim())
        .firstWhere((u) => u.isNotEmpty, orElse: () => '');
    if (bannerImg != null && bannerImg.isNotEmpty) return bannerImg;
    final itemImg = data?.menuItems
        .map((m) => m.imageUrl.trim())
        .firstWhere((u) => u.isNotEmpty, orElse: () => '');
    return itemImg ?? '';
  }

  Widget _buildCoverImage() {
    final raw = _coverImageUrl;
    if (raw.isNotEmpty) {
      if (raw.startsWith('assets/')) {
        return Image.asset(
          raw,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => _coverFallback(),
        );
      }
      final resolved = raw.startsWith('/uploads/')
          ? ApiEndpoints.resolveMediaUrl(raw)
          : raw;
      if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
        return Image.network(
          resolved,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => _coverFallback(),
        );
      }
    }
    return _coverFallback();
  }

  Widget _coverFallback() {
    return Image.asset(
      'assets/images/storefront_promo_pizza_hd.jpg',
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFF0B0F19),
        child: const Center(
          child: Icon(
            Icons.restaurant_rounded,
            color: Colors.white54,
            size: 44,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StorefrontViewportFrame(
      child: Scaffold(
        backgroundColor: const Color(0xFFEEF2F7),
        body: SafeArea(
          child: Column(
            children: [
              // Top App Bar: <- Restaurant Info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.1),
                  ),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: onBack,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          size: 18,
                          color: Color(0xFF090D16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Restaurant Info',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF090D16),
                      ),
                    ),
                  ],
                ),
              ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover Photo
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 190,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E293B),
                          ),
                          child: _buildCoverImage(),
                        ),
                        // Dark overlay gradient
                        Container(
                          width: double.infinity,
                          height: 190,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                        ),
                        // Profile Avatar overlapping bottom
                        Positioned(
                          left: 20,
                          bottom: -28,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: avatar(restaurant.logoUrl, restaurant.name, 64),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 38),

                    // Restaurant Name & Cuisine
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            restaurant.name.isNotEmpty
                                ? restaurant.name
                                : 'Storefront',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF090D16),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _cuisines,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Metric Badges (wrap safely on tight widths)
                          Row(
                            children: [
                              if (data?.rating != null &&
                                  data!.rating! > 0) ...[
                                _buildMetricChip(
                                  icon: Icons.star_rounded,
                                  iconColor: const Color(0xFFF59E0B),
                                  title: data!.rating!.toStringAsFixed(1),
                                  subtitle: data!.reviewCount.trim().isNotEmpty
                                      ? '(${data!.reviewCount.trim()})'
                                      : 'Rating',
                                ),
                                const SizedBox(width: 8),
                              ],
                              _buildMetricChip(
                                icon: Icons.timer_outlined,
                                iconColor: themeColor,
                                title: data?.deliveryEta.trim().isNotEmpty == true
                                    ? data!.deliveryEta.trim()
                                    : '25-35 min',
                                subtitle: 'Delivery',
                              ),
                              const SizedBox(width: 8),
                              _buildMetricChip(
                                icon: Icons.delivery_dining_rounded,
                                iconColor: const Color(0xFF15803D),
                                title: _deliveryFeeAmount,
                                subtitle: _deliveryFeeSubtitle,
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Open Status Row
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: _isOnline
                                  ? const Color(0xFFDCFCE7)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isOnline
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFFFCA5A5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _isOnline
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFFDC2626),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${_isOnline ? "Open Now" : "Currently Closed"}  $_hours',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _isOnline
                                          ? const Color(0xFF14532D)
                                          : const Color(0xFF991B1B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (_address.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _buildDetailCard(
                              icon: Icons.location_on_rounded,
                              iconColor: themeColor,
                              title: _address,
                            ),
                          ],

                          if (_phone.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildDetailCard(
                              icon: Icons.phone_rounded,
                              iconColor: themeColor,
                              title: _phone,
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.copy_rounded,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _phone),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Phone number copied to clipboard',
                                      ),
                                      duration: Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // About Us Section
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.storefront_rounded,
                                      size: 16,
                                      color: themeColor,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'About Us',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF090D16),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _aboutUs,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF334155),
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 36),
                        ],
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
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF090D16),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF090D16),
                height: 1.35,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
