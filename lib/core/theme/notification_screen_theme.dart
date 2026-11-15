import 'package:flutter/material.dart';

/// Light notification surfaces must not inherit white text from the app's dark theme.
class NotificationScreenTheme extends StatelessWidget {
  final Widget child;
  const NotificationScreenTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      scaffoldBackgroundColor: const Color(0xFFF3F7F8),
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: const Color(0xFF008764),
            brightness: Brightness.light,
          ).copyWith(
            surface: Colors.white,
            onSurface: const Color(0xFF142B32),
            onSurfaceVariant: const Color(0xFF475569),
          ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          color: Color(0xFF142B32),
          fontSize: 16,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          color: Color(0xFF142B32),
          fontSize: 14,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          color: Color(0xFF475569),
          fontSize: 13,
          height: 1.4,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF031024),
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          color: Color(0xFF142B32),
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          color: Color(0xFF334155),
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF008764),
          disabledForegroundColor: const Color(0xFF475569),
          disabledBackgroundColor: const Color(0xFFE2E8F0),
          side: BorderSide.none,
          elevation: 0,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFF3F7F8),
        labelStyle: TextStyle(color: Color(0xFF334155)),
        hintStyle: TextStyle(color: Color(0xFF64748B)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF142B32),
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
      ),
    ),
    child: child,
  );
}
