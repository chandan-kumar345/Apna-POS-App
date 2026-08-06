import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/glass_theme.dart';
import 'core/database/database_service.dart';
import 'features/auth/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseService();
  await db.init();
  runApp(
    const ProviderScope(
      child: ApnaPosApp(),
    ),
  );
}

class ApnaPosApp extends StatelessWidget {
  const ApnaPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apna POS - Smart Restaurant Billing',
      debugShowCheckedModeBanner: false,
      theme: GlassTheme.themeData,
      home: const SplashScreen(),
    );
  }
}
