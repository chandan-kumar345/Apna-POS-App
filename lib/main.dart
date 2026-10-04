import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/glass_theme.dart';
import 'core/database/database_service.dart';
import 'core/services/sound_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/network/api_endpoints.dart';
import 'core/widgets/sound_feedback_wrapper.dart';
import 'features/auth/get_started_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/create_profile_screen.dart';
import 'features/dashboard/main_layout.dart';
import 'features/onboarding/restaurant_onboarding_screen.dart';
import 'features/onboarding/confirm_business_name_screen.dart';
import 'features/onboarding/business_details_screen.dart';
import 'features/onboarding/choose_business_category_screen.dart';
import 'features/onboarding/add_business_address_screen.dart';
import 'features/onboarding/confirm_business_address_screen.dart';
import 'features/onboarding/business_settings_screen.dart';
import 'features/notifications/services/notification_permission_helper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_player_win/video_player_win.dart';
import 'features/super_admin/screens/auth/super_admin_login_screen.dart';
import 'features/super_admin/widgets/super_admin_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && Platform.isWindows) {
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

  // Determine initial home screen with onboarding resumption
  final defaultHome = _getInitialHomeScreen();

  runApp(
    ProviderScope(
      child: ApnaPosApp(initialHome: defaultHome),
    ),
  );
}

Widget _getInitialHomeScreen() {
  final db = DatabaseService();

  if (kIsWeb) {
    final path = Uri.base.path.toLowerCase();
    if (path.contains('admin') || path.contains('super')) {
      return const SuperAdminLoginScreen();
    }
    if (db.currentUser != null && db.isOnboardingCompleted) {
      return const MainLayout();
    }
    if (db.currentUser == null) {
      return const LoginScreen();
    }
  }

  // 1. If not logged in -> Show Login or GetStarted
  if (db.currentUser == null) {
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return const LoginScreen();
    }
    return const GetStartedScreen();
  }

  // 2. If logged in and onboarding is completely finished -> Show POS Dashboard
  if (db.isOnboardingCompleted) {
    return const MainLayout();
  }

  // 3. User is logged in but onboarding is in progress:
  // Resume at the exact screen where the user left off!
  final route = db.getOnboardingRoute();
  final step = db.getOnboardingStep();

  if (route == 'confirm_business_name' || step == 2) {
    return const ConfirmBusinessNameScreen();
  } else if (route == 'business_details' || step == 3) {
    return const BusinessDetailsScreen();
  } else if (route == 'choose_category' || step == 4) {
    return const ChooseBusinessCategoryScreen();
  } else if (route == 'add_address' || step == 5) {
    return const AddBusinessAddressScreen();
  } else if (route == 'confirm_address' || step == 6) {
    return const ConfirmBusinessAddressScreen();
  } else if (route == 'business_settings' || step == 7) {
    return const BusinessSettingsScreen();
  } else if (route == 'create_profile' ||
      (db.currentUser!.companyName == null || db.currentUser!.companyName!.isEmpty)) {
    return const CreateProfileScreen();
  } else {
    // Default to Upgrade to Business screen
    return const RestaurantOnboardingScreen();
  }
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
        '/login': (context) => const LoginScreen(),
        '/get-started': (context) => const GetStartedScreen(),
        '/dashboard': (context) => const MainLayout(),
        '/admin': (context) => const SuperAdminLoginScreen(),
        '/admin/dashboard': (context) => const SuperAdminLayout(),
      },
    );
  }
}
