import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/glass_theme.dart';
import 'core/database/database_service.dart';
import 'core/services/sound_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/network/api_endpoints.dart';
import 'core/widgets/sound_feedback_wrapper.dart';
import 'features/auth/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_player_win/video_player_win.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && Platform.isWindows) {
    try {
      WindowsVideoPlayer.registerWith();
    } catch (e) {
      debugPrint('WindowsVideoPlayer.registerWith error: $e');
    }
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase.initializeApp warning/info: $e');
  }

  try {
    await ApiEndpoints.initialize();
  } catch (e) {
    debugPrint('ApiEndpoints init error: $e');
  }

  try {
    final db = DatabaseService();
    await db.init();
  } catch (e) {
    debugPrint('DatabaseService init error: $e');
  }

  try {
    await SoundService().init();
  } catch (e) {
    debugPrint('SoundService init error: $e');
  }

  try {
    await LocalNotificationService().init();
  } catch (e) {
    debugPrint('LocalNotificationService init error: $e');
  }

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
