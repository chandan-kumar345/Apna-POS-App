import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/database/database_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/fcm_service.dart';
import '../../core/services/local_notification_service.dart';

import '../dashboard/main_layout.dart';
import 'get_started_screen.dart';
import 'widgets/splash_brand_view.dart';
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

/// Paints immediately, then restores the session while the logo is written.
class SplashScreen extends StatefulWidget {
  static const writingDuration = Duration(milliseconds: 2600);
  final Widget? targetScreenOverride;
  final Future<void> Function()? initialize;
  static bool isSplashActive = true;

  const SplashScreen({super.key, this.targetScreenOverride, this.initialize});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _navigated = false;
  bool _startupComplete = false;
  bool _writingComplete = false;
  bool _navigationScheduled = false;
  Timer? _fallbackTimer;
  Widget? _resolvedTargetScreen;

  @override
  void initState() {
    super.initState();
    SplashScreen.isSplashActive = true;

    _animController = AnimationController(
      vsync: this,
      duration: SplashScreen.writingDuration,
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _writingComplete = true;
        _fallbackTimer?.cancel();
        _continueWhenReady();
      }
    });

    // Even slow SDK/storage initialization starts after branding has painted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  Future<void> _start() async {
    // If ticking is muted, finish the artwork instead of cutting off the text.
    _fallbackTimer = Timer(
      SplashScreen.writingDuration + const Duration(milliseconds: 500),
      () {
        if (mounted && !_writingComplete) _animController.value = 1;
      },
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      _animController.value = 1;
    } else {
      _animController.forward();
    }

    try {
      await widget.initialize?.call();
    } catch (e) {
      debugPrint('[SplashScreen] Local startup recovery: $e');
    }
    if (!mounted) return;
    _preResolveTargetScreen();
    setState(() => _startupComplete = true);
    _continueWhenReady();
  }

  void _continueWhenReady() {
    if (!_startupComplete ||
        !_writingComplete ||
        _navigationScheduled ||
        !mounted) {
      return;
    }
    _navigationScheduled = true;
    // Present the complete logo and final text before starting the transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _navigateImmediately();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
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
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final Widget defaultAuthFallback = isDesktopPlatform
        ? const LoginScreen()
        : const GetStartedScreen();

    // 1. Not logged in locally -> Login or GetStarted
    if (db.currentUser == null) {
      _resolvedTargetScreen = defaultAuthFallback;
      // Fire non-blocking background token validation if any
      AuthService()
          .isAuthenticated()
          .then((isAuth) {
            if (isAuth && mounted && !_navigated) {
              AuthService().getMe().catchError((_) => <String, dynamic>{});
            }
          })
          .catchError((_) {});
      return;
    }

    // 2. Logged in and onboarding completed -> Direct to Main POS Dashboard
    if (db.isOnboardingCompleted ||
        (db.restaurant != null && db.restaurant!.isOnboarded)) {
      _resolvedTargetScreen = const MainLayout();
      // Non-blocking background sync with backend server
      db.syncWithBackend().catchError((e) {
        debugPrint('[SplashScreen] Background sync note: $e');
      });
      // Ensure current device push token is registered with backend
      FcmService().registerTokenWithBackend().catchError((e) {
        debugPrint('[SplashScreen] Push token registration notice: $e');
        return false;
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
        (db.currentUser!.companyName == null ||
            db.currentUser!.companyName!.isEmpty)) {
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
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final Widget targetScreen =
        _resolvedTargetScreen ??
        (isDesktopPlatform ? const LoginScreen() : const GetStartedScreen());

    Navigator.of(context)
        .pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (context, animation, secondaryAnimation) =>
                targetScreen,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    ),
                    child: child,
                  );
                },
          ),
        )
        .then((_) {
          SplashScreen.isSplashActive = false;
          LocalNotificationService.checkAndShowPendingIncomingOrder();
        });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SplashScreen.isSplashActive = false;
      LocalNotificationService.checkAndShowPendingIncomingOrder();
    });
  }

  @override
  void dispose() {
    SplashScreen.isSplashActive = false;
    _fallbackTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SplashBrandView(
      animation: _animController,
      isPreparing: !_startupComplete,
    );
  }
}
