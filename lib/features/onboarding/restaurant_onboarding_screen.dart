import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/database/database_service.dart';
import 'confirm_business_name_screen.dart';


class RestaurantOnboardingScreen extends StatefulWidget {
  const RestaurantOnboardingScreen({super.key});

  @override
  State<RestaurantOnboardingScreen> createState() => _RestaurantOnboardingScreenState();
}

class _RestaurantOnboardingScreenState extends State<RestaurantOnboardingScreen> {
  bool _isLoading = false;
  final db = DatabaseService();

  Future<void> _completeOnboarding() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConfirmBusinessNameScreen()),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Deep Midnight Background Gradient matching Auth & Profile Screens
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.4),
                  radius: 1.25,
                  colors: [
                    Color(0x550052FF), // Logo Electric Blue Ambient Glow
                    Color(0xFF071126),
                    Color(0xFF03060F),
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // 2. Decorative Glass Background Orbs / Ambient Glow Shapes
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00C2FF).withOpacity(0.18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C2FF).withOpacity(0.18),
                    blurRadius: 80,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 160,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4F46E5).withOpacity(0.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.2),
                    blurRadius: 90,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // 3. Main Screen Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Section on Dark Gradient
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back Button
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Screen Header Title
                      const Text(
                        'Upgrade To Business',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),

                      const SizedBox(height: 6),

                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                            height: 1.4,
                            fontFamily: 'Roboto',
                          ),
                          children: [
                            TextSpan(
                              text:
                                  'Explore amazing features of upgrading your POS terminal to ',
                            ),
                            TextSpan(
                              text: 'Apna POS Business',
                              style: TextStyle(
                                color: Color(0xFF00C2FF), // Bright Cyan Highlight
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. White Bottom Curved Card Container
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 30,
                          offset: Offset(0, -10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Overlapping Floating Feature Cards Stack for Apna POS
                                SizedBox(
                                  height: 220,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Right Slate Card (Restaurant Manager Profile Card)
                                      Positioned(
                                        right: 0,
                                        top: 16,
                                        child: Container(
                                          width: 170,
                                          height: 190,
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF475569), // Slate Card Color
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 16,
                                                offset: Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            children: [
                                              // Gold Crown Badge
                                              Positioned(
                                                right: 0,
                                                top: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.all(5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.25),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.workspace_premium_rounded,
                                                    color: Colors.amber,
                                                    size: 14,
                                                  ),
                                                ),
                                              ),
                                              Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration: const BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.storefront_rounded,
                                                        color: Color(0xFF00C2FF),
                                                        size: 26,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  const Text(
                                                    'Apna POS Diner',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  const Text(
                                                    'Manager POS Profile',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF38BDF8),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  const Text(
                                                    'Authentic Flavors & Swift Billing!',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      color: Colors.white70,
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Left Floating Overlapping Card (Dark Business Card for Apna POS)
                                      Positioned(
                                        left: 5,
                                        top: 0,
                                        child: Container(
                                          width: 190,
                                          height: 205,
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A), // Dark Midnight
                                            borderRadius: BorderRadius.circular(24),
                                            border: Border.all(
                                              color: const Color(0xFF00C2FF).withOpacity(0.3),
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 20,
                                                offset: Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            children: [
                                              // Gold Crown Badge
                                              Positioned(
                                                right: 0,
                                                top: 0,
                                                child: Container(
                                                  padding: const EdgeInsets.all(5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.2),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.workspace_premium_rounded,
                                                    color: Colors.amber,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                              Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  // Brand Logo Icon for Apna POS
                                                  Container(
                                                    width: 52,
                                                    height: 52,
                                                    decoration: const BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.point_of_sale_rounded,
                                                        color: Color(0xFF00C2FF),
                                                        size: 28,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  const Text(
                                                    'ApnaPOS.com',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  const Text(
                                                    'Owner / CEO Profile',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF00C2FF),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  const Text(
                                                    'Empowering Restaurants & Retail POS!!',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w500,
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 28),

                                // 2. Second Section Title & Subtitle for Apna POS
                                const Text(
                                  'Manage Up To 5 POS Terminals',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.4,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                const Text(
                                  'Connect Cashier Counters, Kitchen Displays (KDS), Waiter Tablets & Online Orders Seamlessly',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    height: 1.35,
                                  ),
                                ),

                                const SizedBox(height: 22),

                                // 3. Cascading Stacked Cards Graphic Illustration for Apna POS
                                Center(
                                  child: SizedBox(
                                    height: 180,
                                    width: double.infinity,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Terminal Card 5
                                        Positioned(
                                          top: 0,
                                          child: Container(
                                            width: 220,
                                            height: 100,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF0284C7), Color(0xFF0284C7)],
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                                            ),
                                          ),
                                        ),

                                        // Terminal Card 4
                                        Positioned(
                                          top: 16,
                                          child: Container(
                                            width: 240,
                                            height: 105,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                                            ),
                                          ),
                                        ),

                                        // Terminal Card 3
                                        Positioned(
                                          top: 32,
                                          child: Container(
                                            width: 260,
                                            height: 110,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                                            ),
                                          ),
                                        ),

                                        // Terminal Card 2
                                        Positioned(
                                          top: 48,
                                          child: Container(
                                            width: 280,
                                            height: 115,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF00C2FF), Color(0xFF0284C7)],
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12)],
                                            ),
                                          ),
                                        ),

                                        // Terminal Card 1 (Frontmost Main Card)
                                        Positioned(
                                          top: 64,
                                          child: Container(
                                            width: 300,
                                            height: 120,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              gradient: GlassTheme.primaryButtonGradient,
                                              borderRadius: BorderRadius.circular(18),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x3300C2FF),
                                                  blurRadius: 18,
                                                  offset: Offset(0, 8),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: const BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.receipt_long_rounded,
                                                      color: Color(0xFF00C2FF),
                                                      size: 26,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                                const Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      'APNA POS TERMINAL #1',
                                                      style: TextStyle(
                                                        fontSize: 13.5,
                                                        fontWeight: FontWeight.w800,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      'Main Counter & Billing Unit',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const Spacer(),
                                                Container(
                                                  padding: const EdgeInsets.all(7),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: const Icon(
                                                    Icons.qr_code_2_rounded,
                                                    color: Colors.white,
                                                    size: 18,
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

                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ),

                        // 4. Primary Bottom "Next" Button
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              gradient: GlassTheme.primaryButtonGradient,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x3300C2FF),
                                  blurRadius: 14,
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
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Next',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
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
          ),
        ],
      ),
    );
  }
}
