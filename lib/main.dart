import 'package:flutter/material.dart';
import 'core/theme/glass_theme.dart';
import 'core/database/database_service.dart';
import 'features/auth/get_started_screen.dart';
import 'features/onboarding/restaurant_onboarding_screen.dart';
import 'features/dashboard/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseService();
  await db.init();
  runApp(const ApnaPosApp());
}

class ApnaPosApp extends StatelessWidget {
  const ApnaPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apna POS - Smart Restaurant Billing',
      debugShowCheckedModeBanner: false,
      theme: GlassTheme.themeData,
      home: const GetStartedScreen(),
    );
  }
}
