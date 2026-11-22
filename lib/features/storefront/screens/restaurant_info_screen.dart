import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/restaurant_model.dart';
import '../models/storefront_model.dart';

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
    return 'Italian • Pizza • Fast Food';
  }

  String get _address {
    if (restaurant.address.trim().isNotEmpty) {
      return restaurant.address.trim();
    }
    return 'Shop No. 12, Sector 5, Dwarka, Delhi - 110075';
  }

  String get _phone {
    if (restaurant.phone.trim().isNotEmpty) {
      return restaurant.phone.trim();
    }
    return '+91 98765 43210';
  }

  String get _hours {
    final open = restaurant.openingTime.trim().isNotEmpty ? restaurant.openingTime.trim() : '09:00 AM';
    final close = restaurant.closingTime.trim().isNotEmpty ? restaurant.closingTime.trim() : '11:00 PM';
    return '$open - $close';
  }

  String get _aboutUs {
    if (restaurant.tagline.trim().isNotEmpty) {
      return restaurant.tagline.trim();
    }
    return 'Authentic Italian pizzas, freshly baked with premium ingredients and a wide range of sides and beverages.';
  }

  String get _deliveryFeeAmount {
    final fee = restaurant.deliveryBaseCharge > 0 ? restaurant.deliveryBaseCharge : 40.0;
    return '₹${fee.toStringAsFixed(fee % 1 == 0 ? 0 : 2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar: <- Restaurant Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Row(
                children: [
                  InkWell(
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Restaurant Info',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
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
                          child: Image.asset(
                            'assets/images/tpl_food_diwali_pizza.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF1E293B),
                              child: const Center(
                                child: Icon(
                                  Icons.restaurant_rounded,
                                  color: Colors.white38,
                                  size: 48,
                                ),
                              ),
                            ),
                          ),
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
                            restaurant.name.isNotEmpty ? restaurant.name : 'Pizza 47',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _cuisines,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3 Metric Badges Row
                          Row(
                            children: [
                              _buildMetricChip(
                                icon: Icons.star_rounded,
                                iconColor: const Color(0xFFF59E0B),
                                title: '4.6',
                                subtitle: '(2.4K+)',
                              ),
                              const SizedBox(width: 8),
                              _buildMetricChip(
                                icon: Icons.timer_outlined,
                                iconColor: const Color(0xFF2563EB),
                                title: '25-35 min',
                                subtitle: 'Delivery',
                              ),
                              const SizedBox(width: 8),
                              _buildMetricChip(
                                icon: Icons.delivery_dining_rounded,
                                iconColor: const Color(0xFF10B981),
                                title: _deliveryFeeAmount,
                                subtitle: 'Delivery Fee',
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Open Status Row
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Open Now $_hours',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF15803D),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Location Card
                          _buildDetailCard(
                            icon: Icons.location_on_rounded,
                            iconColor: const Color(0xFF2563EB),
                            title: _address,
                          ),

                          const SizedBox(height: 12),

                          // Phone with Copy
                          _buildDetailCard(
                            icon: Icons.phone_rounded,
                            iconColor: const Color(0xFF2563EB),
                            title: _phone,
                            trailing: IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF64748B)),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _phone));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Phone number copied to clipboard'),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 20),

                          // About Us Section
                          Container(
                            width: double.infinity,
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
                                    Icon(
                                      Icons.storefront_rounded,
                                      size: 18,
                                      color: Color(0xFF2563EB),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'About Us',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _aboutUs,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF475569),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: iconColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
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
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
                height: 1.4,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
