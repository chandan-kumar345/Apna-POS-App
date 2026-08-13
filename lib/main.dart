import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/glass_theme.dart';
import 'core/database/database_service.dart';
import 'core/services/sound_service.dart';
import 'core/widgets/sound_feedback_wrapper.dart';
import 'features/auth/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final db = DatabaseService();
  await db.init();
  await SoundService().init();
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
      builder: (context, child) {
        return SoundFeedbackWrapper(
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
    );
  }
}
