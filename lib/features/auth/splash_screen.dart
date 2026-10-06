import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/database/database_service.dart';
import '../../core/services/auth_service.dart';
import '../notifications/services/notification_permission_helper.dart';

import '../dashboard/main_layout.dart';
import 'get_started_screen.dart';
import 'login_screen.dart';
import 'create_profile_screen.dart';
import '../onboarding/restaurant_onboarding_screen.dart';
import '../onboarding/confirm_business_name_screen.dart';
import '../onboarding/business_details_screen.dart';
import '../onboarding/choose_business_category_screen.dart';
import '../onboarding/add_business_address_screen.dart';
import '../onboarding/confirm_business_address_screen.dart';
import '../onboarding/business_settings_screen.dart';
import '../super_admin/screens/auth/super_admin_login_screen.dart';

/// Fast, Resilient Splash Screen with Animated Apna POS Logo Zoom Effect
/// and fully wrapped responsive layout with zero startup freezing.
class SplashScreen extends StatefulWidget {
  final Widget? targetScreenOverride;

  const SplashScreen({super.key, this.targetScreenOverride});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _logoZoomAnim;
  late Animation<double> _logoGlowAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideContentAnim;

  bool _navigated = false;
  Timer? _fallbackTimer;
  Widget? _resolvedTargetScreen;

  // Premium Neumorphic Theme Palette
  static const Color _neuBg = Color(0xFFEDF3F9);
  static const Color _neuSurface = Color(0xFFF6FAFE);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF5B6B82);
  static const Color _neuShadowDark = Color(0xFFB4C8DC);
  static const Color _primaryBlue = Color(0xFF0052FF);

  @override
  void initState() {
    super.initState();

    // 1. Fire non-blocking startup permissions asynchronously
    try {
      NotificationPermissionHelper.requestAllAppPermissionsOnStartup().catchError((e) {
        debugPrint('[SplashScreen] Permission helper info: $e');
      });
    } catch (_) {}

    // 2. Pre-resolve target screen immediately from local cache (<10ms)
    _preResolveTargetScreen();

    // 3. Animated Apna POS Logo Zoom Animation Controller (~950ms)
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    // Dynamic Zoom Effect: Starts at 0.58, springs up to 1.08, settles at 1.0
    _logoZoomAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.58, end: 1.08).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 75.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 25.0,
      ),
    ]).animate(_animController);

    // Glowing Radial Ring expansion behind logo
    _logoGlowAnim = Tween<double>(begin: 0.65, end: 1.25).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.1, 0.9, curve: Curves.easeOut),
      ),
    );

    // Smooth Opacity Fade
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    // Synchronized Slogan Slide-Up
    _slideContentAnim = Tween<Offset>(
      begin: const Offset(0, 0.28),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    // Trigger navigation immediately when the zoom entrance finishes
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateImmediately();
      }
    });

    _animController.forward();

    // Guaranteed fallback timer (proceeds after 1200ms max to prevent any stuck splash)
    _fallbackTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && !_navigated) {
        _navigateImmediately();
      }
    });
  }

  /// Instantly resolves the destination screen from local storage cache
  /// without blocking on remote HTTP network roundtrips.
  void _preResolveTargetScreen() {
    if (widget.targetScreenOverride != null) {
      _resolvedTargetScreen = widget.targetScreenOverride;
      return;
    }

    final db = DatabaseService();

    // Web Super Admin routing check
    if (kIsWeb) {
      final path = Uri.base.path.toLowerCase();
      if (path.contains('admin') || path.contains('super')) {
        _resolvedTargetScreen = const SuperAdminLoginScreen();
        return;
      }
    }

    final bool isDesktopPlatform =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final Widget defaultAuthFallback =
        isDesktopPlatform ? const LoginScreen() : const GetStartedScreen();

    // 1. Not logged in locally -> Login or GetStarted
    if (db.currentUser == null) {
      _resolvedTargetScreen = defaultAuthFallback;
      // Fire non-blocking background token validation if any
      AuthService().isAuthenticated().then((isAuth) {
        if (isAuth && mounted && !_navigated) {
          AuthService().getMe().catchError((_) => <String, dynamic>{});
        }
      }).catchError((_) {});
      return;
    }

    // 2. Logged in and onboarding completed -> Direct to Main POS Dashboard
    if (db.isOnboardingCompleted || (db.restaurant != null && db.restaurant!.isOnboarded)) {
      _resolvedTargetScreen = const MainLayout();
      // Non-blocking background sync with backend server
      db.syncWithBackend().catchError((e) {
        debugPrint('[SplashScreen] Background sync note: $e');
      });
      return;
    }

    // 3. Logged in but onboarding in-progress -> Resume exact onboarding step
    final route = db.getOnboardingRoute();
    final step = db.getOnboardingStep();

    if (route == 'confirm_business_name' || step == 2) {
      _resolvedTargetScreen = const ConfirmBusinessNameScreen();
    } else if (route == 'business_details' || step == 3) {
      _resolvedTargetScreen = const BusinessDetailsScreen();
    } else if (route == 'choose_category' || step == 4) {
      _resolvedTargetScreen = const ChooseBusinessCategoryScreen();
    } else if (route == 'add_address' || step == 5) {
      _resolvedTargetScreen = const AddBusinessAddressScreen();
    } else if (route == 'confirm_address' || step == 6) {
      _resolvedTargetScreen = const ConfirmBusinessAddressScreen();
    } else if (route == 'business_settings' || step == 7) {
      _resolvedTargetScreen = const BusinessSettingsScreen();
    } else if (route == 'create_profile' ||
        (db.currentUser!.companyName == null || db.currentUser!.companyName!.isEmpty)) {
      _resolvedTargetScreen = const CreateProfileScreen();
    } else {
      _resolvedTargetScreen = const RestaurantOnboardingScreen();
    }
  }

  void _navigateImmediately() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _fallbackTimer?.cancel();

    final bool isDesktopPlatform =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    final Widget targetScreen = _resolvedTargetScreen ??
        (isDesktopPlatform ? const LoginScreen() : const GetStartedScreen());

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnim.value.clamp(0.0, 1.0),
                        child: _buildWrappedSplashScreenCard(constraints.maxWidth),
                      );
                    },
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
  // WRAPPED NEUMORPHIC CARD WITH LOGO ZOOM
  // ==========================================
  Widget _buildWrappedSplashScreenCard(double availableWidth) {
    final double cardMaxWidth = min(availableWidth * 0.94, 380.0);

    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. Ambient Expanding Radial Glow Behind Logo
        Transform.scale(
          scale: _logoGlowAnim.value,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _primaryBlue.withValues(alpha: 0.16 * (1.0 - _animController.value * 0.4)),
                  _primaryBlue.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        // 2. Outer Wrapped Neumorphic Card Enclosure
        Container(
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: cardMaxWidth),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1F9),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 1.8,
            ),
            boxShadow: [
              const BoxShadow(
                color: Colors.white,
                offset: Offset(-6, -6),
                blurRadius: 16,
              ),
              BoxShadow(
                color: _neuShadowDark.withValues(alpha: 0.55),
                offset: const Offset(6, 10),
                blurRadius: 18,
              ),
            ],
          ),
          // 3. Inner Surface Card
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
                // 4. ANIMATED APNA POS LOGO WITH DYNAMIC ZOOM EFFECT
                Transform.scale(
                  scale: _logoZoomAnim.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        const BoxShadow(
                          color: Colors.white,
                          offset: Offset(-4, -4),
                          blurRadius: 8,
                        ),
                        BoxShadow(
                          color: _neuShadowDark.withValues(alpha: 0.50),
                          offset: const Offset(4, 8),
                          blurRadius: 14,
                        ),
                        BoxShadow(
                          color: _primaryBlue.withValues(alpha: 0.10),
                          offset: const Offset(0, 4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/apna_pos_brand_logo.png',
                      height: 95,
                      width: 140,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.point_of_sale_rounded, size: 54, color: _primaryBlue),
                          SizedBox(height: 6),
                          Text(
                            'APNA POS',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _textPrimary,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // 5. SLIDING SUBTITLE PILL (WRAPPED)
                SlideTransition(
                  position: _slideContentAnim,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
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
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 6. Fast Sleek Spinner (Wrapped)
                Wrap(
                  alignment: WrapAlignment.center,
                  children: const [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_primaryBlue),
                        strokeWidth: 2.2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 7. Compact Responsive Tagline
                SlideTransition(
                  position: _slideContentAnim,
                  child: const Text(
                    'Fast • Simple • Reliable',
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                      letterSpacing: 0.4,
                    ),
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
