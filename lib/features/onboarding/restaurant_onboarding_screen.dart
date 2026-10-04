import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import 'confirm_business_name_screen.dart';

class RestaurantOnboardingScreen extends StatefulWidget {
  const RestaurantOnboardingScreen({super.key});

  @override
  State<RestaurantOnboardingScreen> createState() => _RestaurantOnboardingScreenState();
}

class _RestaurantOnboardingScreenState extends State<RestaurantOnboardingScreen> {
  final bool _isLoading = false;
  final db = DatabaseService();

  @override
  void initState() {
    super.initState();
    db.saveOnboardingProgress(route: 'upgrade_business', step: 1);
  }

  Future<void> _completeOnboarding() async {
    await db.saveOnboardingProgress(route: 'confirm_business_name', step: 2);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConfirmBusinessNameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF021B54),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              // 1. Fixed Top Midnight Blue Header (Does NOT scroll)
              _buildTopHeroSection(),

              // 2. White Neumorphic Body (Curved top corners, scrolls internally down to the bottom)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF6F9FC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x25001C55),
                        blurRadius: 24,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    child: Column(
                      children: [
                        // Scrollable Content Sheet
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section 1: Detailed "What is Apna POS Business?" (Full width, logo removed, Chandan Yaduvanshi info)
                              _buildWhatIsBusinessCard(),

                              const SizedBox(height: 24),

                              // Section 2: Why Upgrade to Business?
                              const Text(
                                'Why Upgrade to Business?',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildWhyUpgradeGrid(),

                              const SizedBox(height: 24),

                              // Section 3: Powerful Features for Your Business
                              const Text(
                                'Powerful Features for Your Business',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Everything you need to run and scale your business efficiently',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildFeaturesGrid(),

                              const SizedBox(height: 24),

                              // Section 4: Grow Your Business Bottom Banner
                              _buildGrowYourBusinessBanner(),
                            ],
                          ),
                        ),
                      ),

                      // Sticky Bottom Action Bar with "Next" Button
                      _buildStickyBottomBar(),
                    ],
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

  // Fixed Top Dark Gradient Header Section with Title, Subtitle, and 3D Terminal Graphic
  Widget _buildTopHeroSection() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF021B54),
            Color(0xFF03318C),
            Color(0xFF011848),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Title & Subtitle on Left, 3D POS Terminal Hero on Right
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Titles
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Upgrade To\nBusiness',
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.15,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFCBD5E1),
                              height: 1.35,
                            ),
                            children: [
                              TextSpan(
                                text: 'Unlock powerful features and transform your restaurant with ',
                              ),
                              TextSpan(
                                text: 'Apna POS Business',
                                style: TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Right: 3D POS Terminal Hero Graphic with Logo Asset
                  Expanded(
                    flex: 5,
                    child: _buildPosTerminalHeroGraphic(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 3D POS Terminal Graphic with Ambient Glow, Apna POS Asset Logo, and Pedestal
  Widget _buildPosTerminalHeroGraphic() {
    return Center(
      child: SizedBox(
        height: 136,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Ambient Cyan Glow Background
            Positioned(
              bottom: 10,
              child: Container(
                width: 110,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x8800C2FF),
                      blurRadius: 30,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),
            ),

            // Sparkle Stars
            const Positioned(
              top: 8,
              left: 4,
              child: Icon(Icons.star_rounded, color: Color(0xFFBAE6FD), size: 14),
            ),
            const Positioned(
              bottom: 26,
              right: 2,
              child: Icon(Icons.star_rounded, color: Color(0xFFBAE6FD), size: 12),
            ),

            // 3D Pedestal Stand
            Positioned(
              bottom: 0,
              child: Container(
                width: 136,
                height: 20,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF60A5FA), Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF93C5FD),
                    width: 1.5,
                  ),
                ),
              ),
            ),

            // POS Terminal Machine Screen
            Positioned(
              bottom: 8,
              child: Container(
                width: 120,
                height: 96,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B192C), Color(0xFF1E3E62)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Actual Apna POS Logo from assets
                          Image.asset(
                            'assets/images/logo.png',
                            height: 40,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.cloud_rounded, color: Color(0xFF38BDF8), size: 18),
                                SizedBox(height: 2),
                                Text(
                                  'Apna POS',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'BUSINESS PRO',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF38BDF8),
                                letterSpacing: 0.8,
                              ),
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
    );
  }

  // "What is Apna POS Business?" Detailed Banner Card (Full width, logo removed, Chandan Yaduvanshi info)
  Widget _buildWhatIsBusinessCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF0F7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12002870),
            blurRadius: 14,
            offset: Offset(4, 6),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'What is Apna POS Business?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0066FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                // child: const Text(
                //   'ALL-IN-ONE',
                //   style: TextStyle(
                //     fontSize: 9.5,
                //     fontWeight: FontWeight.w800,
                //     color: Color(0xFF0066FF),
                //     letterSpacing: 0.6,
                //   ),
                // ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Detailed Information Text
          const Text(
            'Apna POS is a next-generation smart restaurant and retail operating platform founded by Chandan Yaduvanshi. Engineered for high performance, reliability, and growth, Apna POS empowers business owners with full control over daily operations.',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF334155),
              height: 1.45,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'From lightning-fast POS billing and live Kitchen Display Systems (KDS) to online food ordering, multi-terminal table sync, ingredient inventory management, customer CRM loyalty programs, and automated WhatsApp bills — Apna POS gives you everything required to run and scale your business effortlessly.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),

          const SizedBox(height: 12),

          // Owner & Vision Pill Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF0066FF),
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'Founder & Owner: Chandan Yaduvanshi',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // "Why Upgrade to Business?" 4-Pill Grid with Neumorphic Raised Effect
  Widget _buildWhyUpgradeGrid() {
    final items = [
      {
        'title': 'Run Multiple\nTerminals',
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF16A34A),
        'bg': const Color(0xFFDCFCE7),
      },
      {
        'title': 'Manage Staff\n& Roles',
        'icon': Icons.groups_rounded,
        'color': const Color(0xFF7C3AED),
        'bg': const Color(0xFFF3E8FF),
      },
      {
        'title': 'Cloud Sync\n& Backup',
        'icon': Icons.cloud_done_rounded,
        'color': const Color(0xFFEA580C),
        'bg': const Color(0xFFFFEDD5),
      },
      {
        'title': 'Detailed\nReports',
        'icon': Icons.bar_chart_rounded,
        'color': const Color(0xFFDB2777),
        'bg': const Color(0xFFFCE7F3),
      },
    ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: const [
                // Neumorphic Dark Shadow
                BoxShadow(
                  color: Color(0x10002870),
                  blurRadius: 8,
                  offset: Offset(3, 4),
                ),
                // Neumorphic Light Highlight
                BoxShadow(
                  color: Colors.white,
                  blurRadius: 6,
                  offset: Offset(-2, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item['bg'] as Color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(1, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      item['icon'] as IconData,
                      color: item['color'] as Color,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['title'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // "Powerful Features for Your Business" 2-Column Grid with Fully Elaborated Text
  Widget _buildFeaturesGrid() {
    final features = [
      {
        'title': 'POS Billing',
        'desc': 'Fast & easy billing for dine-in, takeaway, delivery & quick sales.',
        'icon': Icons.point_of_sale_rounded,
        'iconColor': const Color(0xFF0284C7),
        'iconBg': const Color(0xFFE0F2FE),
      },
      {
        'title': 'Kitchen Display (KDS)',
        'desc': 'Real-time live kitchen order tickets (KOT) and order status tracking.',
        'icon': Icons.soup_kitchen_rounded,
        'iconColor': const Color(0xFFEA580C),
        'iconBg': const Color(0xFFFFEDD5),
      },
      {
        'title': 'Online Ordering',
        'desc': 'Receive direct orders from web menu, mobile app and food channels.',
        'icon': Icons.shopping_cart_rounded,
        'iconColor': const Color(0xFF16A34A),
        'iconBg': const Color(0xFFDCFCE7),
      },
      {
        'title': 'Table Management',
        'desc': 'Interactive live table layout, guest seating and occupancy status.',
        'icon': Icons.table_restaurant_rounded,
        'iconColor': const Color(0xFF7C3AED),
        'iconBg': const Color(0xFFF3E8FF),
      },
      {
        'title': 'Inventory Management',
        'desc': 'Track ingredient stock, low-inventory alerts and vendor purchase orders.',
        'icon': Icons.inventory_2_rounded,
        'iconColor': const Color(0xFFD97706),
        'iconBg': const Color(0xFFFEF3C7),
      },
      {
        'title': 'CRM & Loyalty Program',
        'desc': 'Build customer profiles, loyalty points, cashback and rewards.',
        'icon': Icons.people_alt_rounded,
        'iconColor': const Color(0xFFDB2777),
        'iconBg': const Color(0xFFFCE7F3),
      },
      {
        'title': 'Coupons & Discounts',
        'desc': 'Create customized discounts, combo offers and promotional promo codes.',
        'icon': Icons.discount_rounded,
        'iconColor': const Color(0xFFE11D48),
        'iconBg': const Color(0xFFFFE4E6),
      },
      {
        'title': 'Reports & Analytics',
        'desc': 'Comprehensive sales analytics, revenue graphs and top-selling item insights.',
        'icon': Icons.insights_rounded,
        'iconColor': const Color(0xFF0284C7),
        'iconBg': const Color(0xFFE0F2FE),
      },
      {
        'title': 'Staff & Role Management',
        'desc': 'Add staff accounts, configure permissions, roles and shift schedules.',
        'icon': Icons.badge_rounded,
        'iconColor': const Color(0xFF0D9488),
        'iconBg': const Color(0xFFCCFBF1),
      },
      {
        'title': 'WhatsApp Automation',
        'desc': 'Automatically send digital bills, order confirmations & marketing alerts.',
        'icon': Icons.chat_rounded,
        'iconColor': const Color(0xFF16A34A),
        'iconBg': const Color(0xFFDCFCE7),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 155,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final f = features[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [
              // Neumorphic Dark Shadow
              BoxShadow(
                color: Color(0x0E002870),
                blurRadius: 10,
                offset: Offset(3, 4),
              ),
              // Neumorphic Light Highlight
              BoxShadow(
                color: Colors.white,
                blurRadius: 6,
                offset: Offset(-2, -2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon with Neumorphic circular badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: f['iconBg'] as Color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(1, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    f['icon'] as IconData,
                    color: f['iconColor'] as Color,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Title - fully visible
              Text(
                f['title'] as String,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),

              // Description - fully elaborated and visible
              Expanded(
                child: Text(
                  f['desc'] as String,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // "Grow Your Business with Apna POS" Bottom Highlight Banner
  Widget _buildGrowYourBusinessBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEBF5FF), Color(0xFFF3F8FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12002870),
            blurRadius: 12,
            offset: Offset(3, 5),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 8,
            offset: Offset(-3, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Growth Icon / Logo Badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x150066FF),
                  blurRadius: 8,
                  offset: Offset(2, 4),
                ),
                BoxShadow(
                  color: Colors.white,
                  blurRadius: 4,
                  offset: Offset(-2, -2),
                ),
              ],
              border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
            ),
            child: Center(
              child: Image.asset(
                'assets/images/logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.auto_graph_rounded,
                  color: Color(0xFF0066FF),
                  size: 26,
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Text Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Grow Your Business with Apna POS',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'More control. More customers. More growth. Upgrade now and experience the complete POS solution.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF475569),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Sticky Bottom Action Bar with Midnight Navy "Next" Pill Button (Background Box Removed)
  Widget _buildStickyBottomBar() {
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF021B54),
                Color(0xFF002B7A),
                Color(0xFF003D9E),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30021B54),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _completeOnboarding,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : const Center(
                    child: Text(
                      'Next',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
