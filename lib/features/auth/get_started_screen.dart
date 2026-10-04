import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/utils/responsive_layout_helper.dart';
import 'login_screen.dart';

class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _motionController;

  // Neumorphic Theme Palette
  static const Color _neuBg = Color(0xFFEDF3F9);
  static const Color _neuSurface = Color(0xFFF6FAFE);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF5B6B82);
  static const Color _neuShadowDark = Color(0xFFB4C8DC);

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _motionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ResponsiveLayoutHelper.isDesktop(context) || (!kIsWeb && Platform.isWindows)) {
      return const LoginScreen();
    }

    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _neuBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5F9FD),
              Color(0xFFEDF3F9),
              Color(0xFFE5EDF6),
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: true,
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          SizedBox(height: topPadding + 50),

                          // 1. Interactive Hero Section with Neumorphic Squircle & Floating Badges
                          _buildHeroSection(),

                          const SizedBox(height: 22),

                          // 2. Headline & Subtitle Text
                          const Text(
                            "Everything You\nNeed, in one App.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: _textPrimary,
                              height: 1.22,
                              letterSpacing: -0.5,
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            "Smart Restaurant Billing, KDS & Analytics",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _textSecondary,
                              letterSpacing: -0.1,
                            ),
                          ),

                          const Spacer(),
                          const SizedBox(height: 5),

                          // 3. Double-Wrapped Neumorphic Bottom Enclosure ("Grow Without Limits")
                          _buildWrappedBottomCard(),

                          const SizedBox(height: 25),

                          // 4. Vibrant Electric Blue "Get Started" Button
                          _buildGetStartedButton(),

                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. HERO SECTION (Logo + 4 Badges)
  // ==========================================
  Widget _buildHeroSection() {
    return SizedBox(
      height: 280,
      child: AnimatedBuilder(
        animation: _motionController,
        builder: (context, child) {
          final val = _motionController.value;
          final float1 = math.sin(val * math.pi * 2) * 6;
          final float2 = math.cos(val * math.pi * 2) * 6;
          final float3 = math.sin(val * math.pi * 2 + 1.2) * 5;
          final float4 = math.cos(val * math.pi * 2 + 1.2) * 5;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Background Ambient Glow behind logo
              Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF0052FF).withValues(alpha: 0.12),
                      const Color(0xFF0052FF).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),

              // Central Neumorphic Logo Squircle Card
              Center(
                child: Container(
                  width: 210,
                  height: 200,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(42),
                    border: Border.all(
                      color: Colors.white,
                      width: 2.0,
                    ),
                    boxShadow: [
                      // Top-Left Light Highlight
                      const BoxShadow(
                        color: Colors.white,
                        offset: Offset(-8, -8),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                      // Bottom-Right Dark Neumorphic Shadow
                      BoxShadow(
                        color: _neuShadowDark.withValues(alpha: 0.65),
                        offset: const Offset(8, 12),
                        blurRadius: 24,
                        spreadRadius: 0,
                      ),
                      // Soft Blue Ambient Diffuse Glow
                      BoxShadow(
                        color: const Color(0xFF0052FF).withValues(alpha: 0.10),
                        offset: const Offset(0, 10),
                        blurRadius: 32,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/apna_pos_brand_logo.png',
                      height: 145,
                      width: 175,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // Badge 1: Top-Left "Fast Billing"
              Positioned(
                top: 4 + float1,
                left: 0,
                child: _buildNeuBadge(
                  icon: _buildFastBillingIcon(),
                  label: 'Fast Billing',
                  glowColor: const Color(0xFF0052FF).withValues(alpha: 0.22),
                ),
              ),

              // Badge 2: Top-Right "Loyalty"
              Positioned(
                top: 4 + float2,
                right: 0,
                child: _buildNeuBadge(
                  icon: _buildLoyaltyCrownIcon(),
                  label: 'Loyalty',
                  glowColor: const Color(0xFFFF9500).withValues(alpha: 0.25),
                ),
              ),

              // Badge 3: Mid-Left "Campaigns"
              Positioned(
                bottom: 8 + float3,
                left: 0,
                child: _buildNeuBadge(
                  icon: _buildCampaignsIcon(),
                  label: 'Campaigns',
                  glowColor: const Color(0xFF10B981).withValues(alpha: 0.25),
                ),
              ),

              // Badge 4: Mid-Right "Reports"
              Positioned(
                bottom: 8 + float4,
                right: 0,
                child: _buildNeuBadge(
                  icon: _buildReportsIcon(),
                  label: 'Reports',
                  glowColor: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // BADGE ICONS WITH 3D DETAIL
  // ==========================================

  // 1. Fast Billing Icon (Blue receipt with lines)
  Widget _buildFastBillingIcon() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 10, height: 1.6, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1))),
            const SizedBox(height: 2),
            Container(width: 7, height: 1.6, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(1))),
            const SizedBox(height: 2),
            Container(width: 9, height: 1.6, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1))),
          ],
        ),
      ),
    );
  }

  // 2. Loyalty Crown Icon (Golden Crown)
  Widget _buildLoyaltyCrownIcon() {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      child: const Text(
        '👑',
        style: TextStyle(fontSize: 13.5),
      ),
    );
  }

  // 3. Campaigns Megaphone Icon (Teal/Green 3D Megaphone)
  Widget _buildCampaignsIcon() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: const Icon(
        Icons.campaign_rounded,
        color: Colors.white,
        size: 13,
      ),
    );
  }

  // 4. Reports Bar Chart Icon (Purple 3D Bar Chart)
  Widget _buildReportsIcon() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(width: 2.2, height: 5.5, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(1))),
            const SizedBox(width: 1.5),
            Container(width: 2.2, height: 8.5, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1))),
            const SizedBox(width: 1.5),
            Container(width: 2.2, height: 11.5, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1))),
          ],
        ),
      ),
    );
  }

  // --- Neumorphic Motion Pill Badge Template ---
  Widget _buildNeuBadge({
    required Widget icon,
    required String label,
    required Color glowColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
      decoration: BoxDecoration(
        color: _neuSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 1.2,
        ),
        boxShadow: [
          // Light top-left reflection
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-2.5, -2.5),
            blurRadius: 6,
            spreadRadius: 0,
          ),
          // Dark bottom-right neumorphic shadow
          BoxShadow(
            color: _neuShadowDark.withValues(alpha: 0.55),
            offset: const Offset(3, 4),
            blurRadius: 7,
            spreadRadius: 0,
          ),
          // Ambient soft colored glow
          BoxShadow(
            color: glowColor,
            offset: const Offset(0, 3),
            blurRadius: 9,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 2. WRAPPED BOTTOM CONTAINER (Double Neumorphic Enclosure)
  // ==========================================
  Widget _buildWrappedBottomCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1F9),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 2.0,
        ),
        boxShadow: [
          // Outer White Top-Left Highlight
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-6, -6),
            blurRadius: 16,
            spreadRadius: 0,
          ),
          // Outer Dark Bottom-Right Shadow
          BoxShadow(
            color: _neuShadowDark.withValues(alpha: 0.55),
            offset: const Offset(6, 10),
            blurRadius: 18,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFF3F8FE),
              Color(0xFFE5EFFB),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.8),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0052FF).withValues(alpha: 0.06),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    "Grow Without Limits",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Everything you need to manage orders, billing, inventory, staff, and customers in one powerful platform.",
                    style: TextStyle(
                      fontSize: 11,
                      color: _textSecondary,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Right 3D Document / Chart Illustration Badge
            _buildGrowth3DGraphic(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 3. 3D GROWTH DOCUMENT / CHART BADGE
  // ==========================================
  Widget _buildGrowth3DGraphic() {
    return Container(
      width: 86,
      height: 86,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient soft blue circular glow behind card
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF0052FF).withValues(alpha: 0.22),
                  const Color(0xFF0052FF).withValues(alpha: 0.0),
                ],
              ),
            ),
          ),

          // 3D Tilted Floating White Card
          Transform.rotate(
            angle: 0.06,
            child: Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFF0F6FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white,
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0052FF).withValues(alpha: 0.26),
                    offset: const Offset(4, 8),
                    blurRadius: 14,
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    offset: Offset(-2, -2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top placeholder document lines
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF93C5FD),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 18,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFBFDBFE),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),

                  // Ascending Bar Chart + Rising Blue Arrow
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildChartBar(13, const Color(0xFF93C5FD)),
                      _buildChartBar(18, const Color(0xFF60A5FA)),
                      _buildChartBar(24, const Color(0xFF2563EB)),
                      _buildChartBar(30, const Color(0xFF0052FF)),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 11),
                        child: Icon(
                          Icons.trending_up_rounded,
                          color: Color(0xFF0052FF),
                          size: 16,
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
    );
  }

  Widget _buildChartBar(double height, Color color) {
    return Container(
      width: 5.5,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 4. "GET STARTED" ELECTRIC BLUE BUTTON
  // ==========================================
  Widget _buildGetStartedButton() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 480),
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0066FF),
            Color(0xFF0044EB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          // Primary Blue Glow Shadow
          BoxShadow(
            color: const Color(0xFF0052FF).withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          // Top Surface Highlight
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, -1.5),
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
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'Get Started',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}


