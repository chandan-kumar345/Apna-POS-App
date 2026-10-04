import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../core/services/network_service.dart';
import '../../core/services/auth_service.dart';
import '../notifications/services/notification_permission_helper.dart';

import '../dashboard/main_layout.dart';
import 'get_started_screen.dart';
import 'login_screen.dart';
import 'create_profile_screen.dart';
import '../onboarding/restaurant_onboarding_screen.dart';
import '../onboarding/add_business_address_screen.dart';
import '../onboarding/business_settings_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  bool _navigated = false;
  Timer? _fallbackTimer;

  // Neumorphic Theme Palette
  static const Color _neuBg = Color(0xFFEDF3F9);
  static const Color _neuSurface = Color(0xFFF6FAFE);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF5B6B82);
  static const Color _neuShadowDark = Color(0xFFB4C8DC);
  static const Color _primaryBlue = Color(0xFF0052FF);

  @override
  void initState() {
    super.initState();

    try {
      // Trigger native Android/iOS system permission popups directly on app launch
      NotificationPermissionHelper.requestAllAppPermissionsOnStartup();
    } catch (e) {
      debugPrint('[SplashScreen] Permission helper info: $e');
    }

    // Fast, snappy entrance animation (~900ms)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnim = Tween<double>(begin: 0.1, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _proceedNextScreen();
      }
    });

    _animController.forward();

    // Guaranteed fallback timer (proceeds after 1400ms max even if animation drops frames)
    _fallbackTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted && !_navigated) {
        _proceedNextScreen();
      }
    });
  }

  Future<void> _proceedNextScreen() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    _fallbackTimer?.cancel();

    final bool isDesktopPlatform = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final Widget defaultUnauthScreen = isDesktopPlatform ? const LoginScreen() : const GetStartedScreen();
    Widget targetScreen = defaultUnauthScreen;

    try {
      final db = DatabaseService();
      // Fast parallel check of Network & Auth
      final results = await Future.wait([
        NetworkService().hasInternet().timeout(
          const Duration(milliseconds: 1200),
          onTimeout: () => true,
        ),
        AuthService().isAuthenticated().timeout(
          const Duration(milliseconds: 1200),
          onTimeout: () => false,
        ),
      ]);

      final bool hasInternet = results[0];
      final bool isAuth = results[1];

      if (!mounted) return;

      if (isAuth || db.currentUser != null) {
        if (hasInternet && isAuth) {
          try {
            final meData = await AuthService().getMe().timeout(
              const Duration(milliseconds: 1500),
            );
            final user = meData['user'] as Map<String, dynamic>?;
            final bool onboardingCompleted = user?['onboardingCompleted'] == true;
            final int currentStep = (user?['onboardingStep'] as num?)?.toInt() ?? 0;

            if (onboardingCompleted) {
              targetScreen = const MainLayout();
            } else {
              switch (currentStep) {
                case 0:
                  targetScreen = const CreateProfileScreen();
                  break;
                case 1:
                  targetScreen = const RestaurantOnboardingScreen();
                  break;
                case 2:
                  targetScreen = const AddBusinessAddressScreen();
                  break;
                case 3:
                case 4:
                  targetScreen = const BusinessSettingsScreen();
                  break;
                default:
                  targetScreen = const CreateProfileScreen();
              }
            }
          } catch (e) {
            debugPrint('SplashScreen getMe warning/fallback: $e');
            if (db.currentUser != null) {
              targetScreen = (db.restaurant != null && db.restaurant!.isOnboarded)
                  ? const MainLayout()
                  : const RestaurantOnboardingScreen();
            } else {
              targetScreen = const MainLayout();
            }
          }
        } else {
          // Offline access with local session
          if (db.currentUser != null) {
            targetScreen = (db.restaurant != null && db.restaurant!.isOnboarded)
                ? const MainLayout()
                : const RestaurantOnboardingScreen();
          } else {
            targetScreen = const MainLayout();
          }
        }
      } else {
        targetScreen = defaultUnauthScreen;
      }
    } catch (e) {
      debugPrint('SplashScreen auth verification error/fallback: $e');
      try {
        final db = DatabaseService();
        if (db.currentUser != null) {
          targetScreen = (db.restaurant != null && db.restaurant!.isOnboarded)
              ? const MainLayout()
              : const RestaurantOnboardingScreen();
        } else {
          targetScreen = defaultUnauthScreen;
        }
      } catch (_) {
        targetScreen = defaultUnauthScreen;
      }
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _neuBg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnim.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: _scaleAnim.value,
                        child: child,
                      ),
                    );
                  },
                  child: _buildWrappedSplashScreenCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // DOUBLE-WRAPPED NEUMORPHIC CARD
  // ==========================================
  Widget _buildWrappedSplashScreenCard() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Ambient soft blue circular glow behind card
        Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _primaryBlue.withValues(alpha: 0.12),
                _primaryBlue.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),

        // Outer Wrapped Enclosure Card
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 360),
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
          // Inner Neumorphic Card
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF3F8FE),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withValues(alpha: 0.06),
                  offset: const Offset(0, 4),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Neumorphic Elevated Brand Logo Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      // Subtle top light
                      const BoxShadow(
                        color: Colors.white,
                        offset: Offset(-3, -3),
                        blurRadius: 6,
                      ),
                      // Soft neumorphic bottom shadow
                      BoxShadow(
                        color: _neuShadowDark.withValues(alpha: 0.45),
                        offset: const Offset(4, 6),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/apna_pos_brand_logo.png',
                    height: 95,
                    width: 135,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Subtitle Neumorphic Branding Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _neuSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                      width: 1.2,
                    ),
                    boxShadow: [
                      const BoxShadow(
                        color: Colors.white,
                        offset: Offset(-2, -2),
                        blurRadius: 4,
                      ),
                      BoxShadow(
                        color: _neuShadowDark.withValues(alpha: 0.4),
                        offset: const Offset(2, 3),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Text(
                    'SMART RESTAURANT POS',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // 3. Fast Sleek Neumorphic Spinner
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryBlue),
                    strokeWidth: 2.2,
                  ),
                ),

                const SizedBox(height: 14),

                // 4. Compact Tagline
                const Text(
                  'Fast • Simple • Reliable',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
