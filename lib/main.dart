import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/glass_theme.dart';
import 'core/database/database_service.dart';
import 'core/services/sound_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/network/api_endpoints.dart';
import 'core/widgets/sound_feedback_wrapper.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/get_started_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/main_layout.dart';
import 'features/notifications/services/notification_permission_helper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player_win/video_player_win.dart';
import 'features/super_admin/screens/auth/super_admin_login_screen.dart';
import 'features/super_admin/widgets/super_admin_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    try {
      WindowsVideoPlayer.registerWith();
    } catch (e) {
      debugPrint('WindowsVideoPlayer.registerWith error: $e');
    }
  }

  // Request permissions on startup
  NotificationPermissionHelper.requestAllAppPermissionsOnStartup().catchError((e) {
    debugPrint('Permission helper error: $e');
  });

  // Parallel asynchronous service startup
  await Future.wait([
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).catchError((e) {
      debugPrint('Firebase.initializeApp warning/info: $e');
      return Firebase.app();
    }),
    ApiEndpoints.initialize().catchError((e) {
      debugPrint('ApiEndpoints init error: $e');
    }),
    DatabaseService().init().catchError((e) {
      debugPrint('DatabaseService init error: $e');
    }),
    SoundService().init().catchError((e) {
      debugPrint('SoundService init error: $e');
    }),
    LocalNotificationService().init().catchError((e) {
      debugPrint('LocalNotificationService init error: $e');
    }),
  ]);

  // Launch via fast animated SplashScreen (or direct SuperAdmin on web)
  Widget initialHome;
  if (kIsWeb && (Uri.base.path.toLowerCase().contains('admin') || Uri.base.path.toLowerCase().contains('super'))) {
    initialHome = const SuperAdminLoginScreen();
  } else {
    initialHome = const SplashScreen();
  }

  runApp(
    ProviderScope(
      child: ApnaPosApp(initialHome: initialHome),
    ),
  );
}

class ApnaPosApp extends StatelessWidget {
  final Widget initialHome;

  const ApnaPosApp({super.key, required this.initialHome});

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
      home: initialHome,
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/get-started': (context) => const GetStartedScreen(),
        '/dashboard': (context) => const MainLayout(),
        '/admin': (context) => const SuperAdminLoginScreen(),
        '/admin/dashboard': (context) => const SuperAdminLayout(),
      },
    );
  }
}
