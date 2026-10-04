import 'package:flutter/material.dart';

/// Design System & Theme constants for Apna POSS Web Super Admin Dashboard
class SuperAdminTheme {
  // Brand & Accent Colors
  static const Color primary = Color(0xFF0052FF);
  static const Color primaryBlue = primary;
  static const Color primaryDark = Color(0xFF003EC4);
  static const Color primaryLight = Color(0xFFE6EFFF);
  static const Color accent = Color(0xFF0EA5E9);
  static const Color accentCyan = accent;
  static const Color purpleAccent = Color(0xFF8B5CF6);
  
  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color successGreen = success;
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningAmber = warning;
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFEF4444);
  static const Color errorRed = danger;
  static const Color dangerLight = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF6366F1);
  static const Color infoLight = Color(0xFFEEF2FF);

  // Background & Surface Neutrals
  static const Color bg = Color(0xFFF0F4F8);
  static const Color background = bg;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = surface;
  static const Color surfaceElevated = Color(0xFFF8FAFC);
  static const Color surfaceInset = Color(0xFFE2E8F0);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textDisabled = Color(0xFFCBD5E1);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);

  // Neumorphic Soft Shadows
  static List<BoxShadow> get cardShadow => [
    const BoxShadow(
      color: Colors.white,
      offset: Offset(-3, -3),
      blurRadius: 8,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: const Color(0xFFB4C8DC).withValues(alpha: 0.4),
      offset: const Offset(4, 6),
      blurRadius: 12,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get flatCardShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.04),
      offset: const Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
      offset: const Offset(0, 1),
      blurRadius: 3,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get raisedButtonShadow => [
    const BoxShadow(
      color: Colors.white,
      offset: Offset(-2, -2),
      blurRadius: 4,
    ),
    BoxShadow(
      color: primary.withValues(alpha: 0.35),
      offset: const Offset(0, 4),
      blurRadius: 10,
    ),
  ];

  static List<BoxShadow> get modalShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: 0.16),
      offset: const Offset(0, 16),
      blurRadius: 36,
      spreadRadius: -4,
    ),
  ];

  // Common Container Decorations
  static BoxDecoration cardDecoration([BuildContext? context]) {
    return neumorphicBox();
  }

  static BoxDecoration neumorphicBox({
    Color color = surface,
    double radius = 14,
    Border? border,
    List<BoxShadow>? customShadow,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.2),
      boxShadow: customShadow ?? cardShadow,
    );
  }

  static BoxDecoration insetBox({
    Color color = const Color(0xFFF1F5F9),
    double radius = 10,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFCBD5E1).withValues(alpha: 0.6), width: 1.0),
    );
  }

  // Typography Styles
  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.4,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.45,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
    color: textMuted,
  );

  static const TextStyle kpiValue = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -0.5,
  );
}
