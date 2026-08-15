import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../core/services/network_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/network/api_endpoints.dart';


import '../../core/widgets/no_internet_screen.dart';
import '../dashboard/main_layout.dart';
import 'get_started_screen.dart';
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
  late Animation<double> _scaleInAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleOutAnim;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Zoom In Entrance Animation (0.0 -> 0.5 timeline)
    _scaleInAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Zoom Out Exit Animation (0.75 -> 1.0 timeline)
    _scaleOutAnim = Tween<double>(begin: 1.0, end: 1.45).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    _animController.forward();

    // On animation complete -> Check internet connectivity before navigating
    _animController.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        
        await _proceedNextScreen();
      }
    });
  }

  Future<void> _proceedNextScreen() async {
    await ApiEndpoints.initialize();
    final hasInternet = await NetworkService().hasInternet();
    if (!mounted) return;


    if (!hasInternet) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => NoInternetScreen(
            onRetrySuccess: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const SplashScreen()),
              );
            },
          ),
        ),
      );
      return;
    }

    Widget targetScreen = const GetStartedScreen();

    try {
      final isAuth = await AuthService().isAuthenticated();
      if (isAuth) {
        final meData = await AuthService().getMe();
        final user = meData['user'] as Map<String, dynamic>?;
        final bool onboardingCompleted = user?['onboardingCompleted'] == true;
        final int currentStep = (user?['onboardingStep'] as num?)?.toInt() ?? 0;

        if (onboardingCompleted) {
          targetScreen = const MainLayout();
        } else {
          // Route to exact incomplete step
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
      }
    } catch (e) {
      debugPrint('SplashScreen auth verification error: $e');
      final db = DatabaseService();
      if (db.currentUser != null) {
        targetScreen = (db.restaurant != null && db.restaurant!.isOnboarded)
            ? const MainLayout()
            : const RestaurantOnboardingScreen();
      } else {
        targetScreen = const GetStartedScreen();
      }
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final zoomOutRouteAnim = Tween<double>(begin: 1.25, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          final fadeRouteAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          );

          return ScaleTransition(
            scale: zoomOutRouteAnim,
            child: FadeTransition(
              opacity: fadeRouteAnim,
              child: child,
            ),
          );
        },
      ),
    );
  }


  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040814),
      body: Stack(
        children: [
          // 1. Ambient Deep Glow Radial Background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.1),
                  radius: 1.25,
                  colors: [
                    Color(0x660052FF), // Deep Electric Blue Ambient Glow
                    Color(0xFF071126),
                    Color(0xFF040814),
                  ],
                  stops: [0.0, 0.65, 1.0],
                ),
              ),
            ),
          ),

          // 2. Animated Centered Logo with Zoom In & Zoom Out Transitions
          Center(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                // Combine Zoom In (0.3 -> 1.0) and Zoom Out (1.0 -> 1.45)
                final currentScale = _animController.value < 0.75
                    ? _scaleInAnim.value
                    : _scaleOutAnim.value;

                return Opacity(
                  opacity: _fadeAnim.value,
                  child: Transform.scale(
                    scale: currentScale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Glass Logo Card Container
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0052FF).withValues(alpha: 0.45),
                                blurRadius: 36,
                                spreadRadius: 4,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 120,
                            width: 130,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Subtitle Branding Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF0052FF).withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            'SMART RESTAURANT POS',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Sleek Loading Spinner
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0052FF)),
                            strokeWidth: 2.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
