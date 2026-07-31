import 'package:flutter/material.dart';

class GlassTheme {
  // Background gradient colors
  static const Color bgDark1 = Color(0xFF040814);
  static const Color bgDark2 = Color(0xFF071126);
  static const Color bgDark3 = Color(0xFF03060F);

  // Glass card fill colors
  static const Color glassBase = Color(0x18FFFFFF); // ~9% white translucent
  static const Color glassHover = Color(0x28FFFFFF);
  static const Color glassHeader = Color(0x20FFFFFF);
  static const Color glassInput = Color(0x12FFFFFF);

  // Accent & Brand Colors (Matching Apna POS Logo)
  static const Color primaryBlue = Color(0xFF0052FF); // Vibrant POS Blue from logo
  static const Color primaryNavy = Color(0xFF0A1435); // Deep Navy from logo
  static const Color primaryViolet = Color(0xFF0052FF);
  static const Color primaryCyan = Color(0xFF00C2FF);
  static const Color accentNeonGreen = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentRose = Color(0xFFF43F5E);
  static const Color accentBlue = Color(0xFF0052FF);

  // Text Colors
  static const Color textHigh = Color(0xFFF8FAFC);
  static const Color textMedium = Color(0xFF94A3B8);
  static const Color textLow = Color(0xFF64748B);

  // Border Colors
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassBorderGlow = Color(0x660052FF);

  // Table Status Colors
  static const Color statusFree = Color(0xFF10B981);      // Emerald
  static const Color statusOccupied = Color(0xFFF59E0B);  // Amber
  static const Color statusBilled = Color(0xFF06B6D4);    // Cyan
  static const Color statusReserved = Color(0xFFF43F5E);  // Rose

  // Global Midnight Hero Radial Glow (Shared across Auth Screens)
  static RadialGradient get heroRadialGlow => const RadialGradient(
        center: Alignment(0.0, -0.35),
        radius: 1.25,
        colors: [
          Color(0x550052FF), // Logo Electric Blue ambient glow
          Color(0xFF071126),
          Color(0xFF03060F),
        ],
        stops: [0.0, 0.6, 1.0],
      );

  // Global Background Linear Gradient
  static BoxDecoration get backgroundDecoration => const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, -0.35),
          radius: 1.3,
          colors: [
            Color(0x440052FF),
            Color(0xFF071126),
            Color(0xFF03060F),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      );

  // Linear Gradient for Glow Borders
  static LinearGradient get borderGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x660052FF),
          Color(0x3300C2FF),
          Color(0x1AFFFFFF),
        ],
      );

  // Primary Button Gradient (Logo Electric Blue)
  static LinearGradient get primaryButtonGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0052FF),
          Color(0xFF0038E0),
        ],
      );

  // Cyan Button Gradient
  static LinearGradient get cyanButtonGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF00C2FF),
          Color(0xFF0088FF),
        ],
      );

  // Card Box Shadow
  static List<BoxShadow> get glassShadow => const [
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 20,
          spreadRadius: 2,
          offset: Offset(0, 8),
        ),
        BoxShadow(
          color: Color(0x0C0052FF),
          blurRadius: 30,
          spreadRadius: 0,
          offset: Offset(0, 0),
        ),
      ];

  static ThemeData get themeData {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: bgDark1,
      primaryColor: primaryBlue,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: primaryCyan,
        surface: glassBase,
        error: accentRose,
      ),
      cardTheme: const CardThemeData(
        color: glassBase,
        elevation: 0,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.transparent,
      ),
    );
  }
}

/// Custom Motion Slide-Up from Bottom Page Route Transition
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideUpPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 450),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 1.0), // Full slide up from bottom
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            );
          },
        );
}

/// Custom Motion Ease-In Page Route Transition
class EaseInPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  EaseInPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.08),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        );
}
