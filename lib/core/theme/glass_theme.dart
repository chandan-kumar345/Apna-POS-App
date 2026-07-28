import 'package:flutter/material.dart';

class GlassTheme {
  // Background gradient colors
  static const Color bgDark1 = Color(0xFF0F0C20);
  static const Color bgDark2 = Color(0xFF161233);
  static const Color bgDark3 = Color(0xFF0A0E1A);

  // Glass card fill colors
  static const Color glassBase = Color(0x18FFFFFF); // ~9% white translucent
  static const Color glassHover = Color(0x28FFFFFF);
  static const Color glassHeader = Color(0x20FFFFFF);
  static const Color glassInput = Color(0x12FFFFFF);

  // Accent & Brand Colors
  static const Color primaryViolet = Color(0xFF8B5CF6);
  static const Color primaryCyan = Color(0xFF06B6D4);
  static const Color accentNeonGreen = Color(0xFF10B981);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentRose = Color(0xFFF43F5E);
  static const Color accentBlue = Color(0xFF3B82F6);

  // Text Colors
  static const Color textHigh = Color(0xFFF8FAFC);
  static const Color textMedium = Color(0xFF94A3B8);
  static const Color textLow = Color(0xFF64748B);

  // Border Colors
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassBorderGlow = Color(0x668B5CF6);

  // Table Status Colors
  static const Color statusFree = Color(0xFF10B981);      // Emerald
  static const Color statusOccupied = Color(0xFFF59E0B);  // Amber
  static const Color statusBilled = Color(0xFF06B6D4);    // Cyan
  static const Color statusReserved = Color(0xFFF43F5E);  // Rose

  // Main Dark Glassmorphism Background Decoration
  static BoxDecoration get backgroundDecoration => const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.6, -0.6),
          radius: 1.4,
          colors: [
            Color(0xFF1E1548),
            Color(0xFF0F0C20),
            Color(0xFF070913),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      );

  // Linear Gradient for Glow Borders
  static LinearGradient get borderGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x668B5CF6),
          Color(0x3306B6D4),
          Color(0x1AFFFFFF),
        ],
      );

  // Primary Button Gradient
  static LinearGradient get primaryButtonGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF8B5CF6),
          Color(0xFF6D28D9),
        ],
      );

  // Cyan Button Gradient
  static LinearGradient get cyanButtonGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF06B6D4),
          Color(0xFF0891B2),
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
          color: Color(0x0C8B5CF6),
          blurRadius: 30,
          spreadRadius: 0,
          offset: Offset(0, 0),
        ),
      ];

  static ThemeData get themeData {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: bgDark1,
      primaryColor: primaryViolet,
      colorScheme: const ColorScheme.dark(
        primary: primaryViolet,
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
