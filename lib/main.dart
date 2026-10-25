import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/glass_theme.dart';
import 'core/database/database_service.dart';
import 'core/services/sound_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/fcm_service.dart';
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
import 'features/storefront/screens/customer_storefront_screen.dart';

String? _extractStorefrontSlug() {
  if (!kIsWeb) return null;

  // 1. Query parameter: ?store=company-name or ?slug=company-name
  final querySlug = Uri.base.queryParameters['store'] ?? Uri.base.queryParameters['slug'];
  if (querySlug != null && querySlug.trim().isNotEmpty) {
    return querySlug.trim().toLowerCase();
  }

  // 2. Direct Path: /company-name or /store/company-name
  final pathSegments = Uri.base.pathSegments.where((s) => s.trim().isNotEmpty).toList();
  if (pathSegments.isNotEmpty) {
    final first = pathSegments.first.toLowerCase();
    if (!['admin', 'super', 'login', 'splash', 'dashboard', 'get-started', 'index.html'].contains(first)) {
      if (first == 'store' && pathSegments.length > 1) {
        return pathSegments[1].toLowerCase();
      }
      return first;
    }
  }

  // 3. Fragment: #/company-name
  final fragment = Uri.base.fragment.replaceAll(RegExp(r'^[/#]+'), '').trim();
  if (fragment.isNotEmpty) {
    final fragSegments = fragment.split('/').where((s) => s.trim().isNotEmpty).toList();
    if (fragSegments.isNotEmpty) {
      final first = fragSegments.first.toLowerCase();
      if (!['admin', 'super', 'login', 'splash', 'dashboard', 'get-started'].contains(first)) {
        if (first == 'store' && fragSegments.length > 1) {
          return fragSegments[1].toLowerCase();
        }
        return first;
      }
    }
  }

  return null;
}

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
    ).then((_) {
      FcmService().init().catchError((e) {
        debugPrint('FcmService init error: $e');
      });
    }).catchError((e) {
      debugPrint('Firebase.initializeApp warning/info: $e');
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

  // Launch via Customer Storefront (if web store URL), SuperAdmin on web, or fast animated SplashScreen
  Widget initialHome;
  final webStoreSlug = _extractStorefrontSlug();
  if (kIsWeb && webStoreSlug != null && webStoreSlug.isNotEmpty) {
    initialHome = CustomerStorefrontScreen(slug: webStoreSlug);
  } else if (kIsWeb && (Uri.base.path.toLowerCase().contains('admin') || Uri.base.path.toLowerCase().contains('super'))) {
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
      navigatorKey: LocalNotificationService.navigatorKey,
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
      onGenerateRoute: (settings) {
        final rawName = settings.name ?? '';
        final uri = Uri.tryParse(rawName);
        if (uri != null) {
          final segments = uri.pathSegments.where((s) => s.trim().isNotEmpty).toList();
          if (segments.isNotEmpty) {
            final first = segments.first.toLowerCase();
            if (!['admin', 'super', 'login', 'splash', 'dashboard', 'get-started', 'index.html'].contains(first)) {
              final slug = (first == 'store' && segments.length > 1) ? segments[1] : first;
              return MaterialPageRoute(
                builder: (_) => CustomerStorefrontScreen(slug: slug),
                settings: settings,
              );
            }
          }
        }
        return null;
      },
    );
  }
}
