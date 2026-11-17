import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/database/database_service.dart';
import '../../core/services/local_notification_service.dart';

import 'startup_destination.dart';
import 'widgets/logo_writing_reveal.dart';
import 'widgets/splash_brand_view.dart';

/// Writes the brand, then opens the destination for the restored session.
class SplashScreen extends StatefulWidget {
  static const writingDuration = LogoWritingReveal.duration;
  static const completedLogoHoldDuration = Duration(milliseconds: 650);
  final Widget? targetScreenOverride;
  final Future<void> Function()? initialize;
  final bool openLoginWhenSignedOut;
  static bool isSplashActive = true;

  const SplashScreen({
    super.key,
    this.targetScreenOverride,
    this.initialize,
    this.openLoginWhenSignedOut = false,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _startupChannel = MethodChannel('com.apnapos.app/startup_brand');
  late AnimationController _animController;
  bool _navigated = false;
  bool _startupComplete = false;
  bool _writingComplete = false;
  bool _completedLogoHeld = false;
  bool _navigationScheduled = false;
  Timer? _fallbackTimer;
  Timer? _logoHoldTimer;

  @override
  void initState() {
    super.initState();
    SplashScreen.isSplashActive = true;

    _animController = AnimationController(
      vsync: this,
      duration: SplashScreen.writingDuration,
      value: 0.04,
    );
    _startupChannel.setMethodCallHandler((call) async {
      if (call.method == 'continueWriting' && mounted && !_writingComplete) {
        final elapsed = (call.arguments as num).toDouble();
        final nativeProgress = math.min(
          elapsed / SplashScreen.writingDuration.inMilliseconds,
          LogoWritingReveal.fullLogoRevealStartProgress,
        );
        final progress = nativeProgress.clamp(_animController.value, 1.0);
        _animController.value = progress;
        if (progress < 1) _animController.forward();
      }
    });

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_writingComplete) return;
        _writingComplete = true;
        _fallbackTimer?.cancel();
        // Start the hold after the final frame has painted, rather than pushing
        // the next route from the same tick that completes the artwork.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final skipHold =
              MediaQuery.disableAnimationsOf(context) ||
              !TickerMode.valuesOf(context).enabled;
          _logoHoldTimer = Timer(
            skipHold ? Duration.zero : SplashScreen.completedLogoHoldDuration,
            () {
              if (!mounted) return;
              _completedLogoHeld = true;
              _continueWhenReady();
            },
          );
        });
        WidgetsBinding.instance.scheduleFrame();
        _continueWhenReady();
      }
    });

    // Even slow SDK/storage initialization starts after branding has painted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_checkChotuFastPath());
        unawaited(_start());
      }
    });
  }

  Future<void> _checkChotuFastPath() async {
    try {
      const channel = MethodChannel('com.apnapos.app/chotu_activation');
      final isPending =
          await channel.invokeMethod<bool>('isPendingActivation') ?? false;
      if (isPending && mounted) {
        // Fast path: skip the 4.2-second logo writing animation when opened via power button / assistant!
        _animController.value = 1.0;
        _writingComplete = true;
        _completedLogoHeld = true;
        _fallbackTimer?.cancel();
        _logoHoldTimer?.cancel();
        _continueWhenReady();
      }
    } catch (_) {}
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
    setState(() => _startupComplete = true);
    _continueWhenReady();
  }

  void _continueWhenReady() {
    if (!_startupComplete ||
        !_writingComplete ||
        !_completedLogoHeld ||
        _navigationScheduled ||
        !mounted) {
      return;
    }
    _navigationScheduled = true;
    // Present the complete logo and final text before starting the transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _navigateImmediately();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _navigateImmediately() {
    if (_navigated || !mounted) return;
    _navigated = true;
    _fallbackTimer?.cancel();

    final db = DatabaseService();
    final destination = resolveStartupDestination(
      user: db.currentUser,
      businessOnboarded: db.restaurant?.isOnboarded ?? false,
      openLoginWhenSignedOut: widget.openLoginWhenSignedOut,
    );
    final targetScreen = widget.targetScreenOverride ?? destination.screen;

    Navigator.of(context)
        .pushReplacement(
          PageRouteBuilder(
            settings: RouteSettings(
              name: widget.targetScreenOverride == null
                  ? destination.routeName
                  : null,
            ),
            transitionDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 320),
            pageBuilder: (context, animation, secondaryAnimation) =>
                targetScreen,
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOutCubic,
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
    _logoHoldTimer?.cancel();
    _startupChannel.setMethodCallHandler(null);
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the completed brand painted underneath the incoming route. Fading it
    // out first exposed the plain window background between the two screens.
    return SplashBrandView(
      animation: _animController,
      isPreparing: !_startupComplete,
    );
  }
}
