import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _motionController;

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040814),
      body: Stack(
        children: [
          // 1. Deep Midnight Background Gradient with Ambient Glow
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.2),
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

          // 2. Animated Floating Motion Badges (Non-overlapping positions)
          AnimatedBuilder(
            animation: _motionController,
            builder: (context, child) {
              final val = _motionController.value;
              final float1 = math.sin(val * math.pi * 2) * 8;
              final float2 = math.cos(val * math.pi * 2) * 8;
              final float3 = math.sin(val * math.pi * 2 + 1) * 7;
              final float4 = math.cos(val * math.pi * 2 + 1) * 7;

              return Stack(
                children: [
                  // Badge 1: Top-Left "Fast Billing"
                  Positioned(
                    top: 80 + float1,
                    left: 18,
                    child: _buildMotionBadge(
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFF0052FF),
                      label: 'Fast Billing',
                    ),
                  ),

                  // Badge 2: Top-Right "KDS Kitchen"
                  Positioned(
                    top: 80 + float2,
                    right: 18,
                    child: _buildMotionBadge(
                      icon: Icons.soup_kitchen_rounded,
                      color: const Color(0xFFFF6B00),
                      label: 'KDS Kitchen',
                    ),
                  ),

                  // Badge 3: Mid-Left "Tables"
                  Positioned(
                    top: 290 + float3,
                    left: 16,
                    child: _buildMotionBadge(
                      icon: Icons.table_restaurant_rounded,
                      color: const Color(0xFF10B981),
                      label: 'Tables',
                    ),
                  ),

                  // Badge 4: Mid-Right "Reports"
                  Positioned(
                    top: 290 + float4,
                    right: 16,
                    child: _buildMotionBadge(
                      icon: Icons.insights_rounded,
                      color: const Color(0xFF8B5CF6),
                      label: 'Reports',
                    ),
                  ),
                ],
              );
            },
          ),

          // 3. Main Content Layer (Logo & Title downside slightly + Headline + Bottom Sheet Card)
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Positioned downside with generous top spacing to avoid any overlapping
                        const SizedBox(height: 110),

                        // Centered Logo Container
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0052FF).withOpacity(0.35),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 110,
                              width: 110,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        const SizedBox(height: 80),

                        // Headline Title Text
                        const Text(
                          "Everything You\nNeed, in one App.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 31,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.25,
                            letterSpacing: -0.4,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Subtitle Text
                        Text(
                          "Smart Restaurant Billing, KDS & Analytics",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.75),
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),

                // 4. Clean Bottom White Sheet Card with Premium Business Growth Highlight & Get Started Button
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(36),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // "Grow Without Limits" Soft Translucent Blue Glass Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF0B132B).withOpacity(0.92), // Dark Navy Blue
                              const Color(0xFF1C325B).withOpacity(0.75), // Deep Translucent Blue
                              const Color(0xFF0052FF).withOpacity(0.40), // Low Opacity Logo Blue
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFF0052FF).withOpacity(0.25),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0052FF).withOpacity(0.15),
                              blurRadius: 16,
                              spreadRadius: 1,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Grow Without Limits",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Everything you need to manage orders, billing, inventory, staff, and customers in one powerful platform.",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.88),
                                fontSize: 12.5,
                                height: 1.45,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Single Prominent "Get Started" Button
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0052FF), // Logo Electric Blue
                              Color(0xFF0038E0),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0052FF).withOpacity(0.4),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              SlideUpPageRoute(
                                page: const LoginScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 22,
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
          ),
        ],
      ),
    );
  }

  // Helper Widget for Motion Floating Badges
  Widget _buildMotionBadge({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x28FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget for Premium Tags
  Widget _premiumTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
