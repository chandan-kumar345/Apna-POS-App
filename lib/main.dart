import 'dart:async';

import 'package:flutter/material.dart';
import 'core/widgets/chotu_activation_host.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/glass_theme.dart';
import 'core/navigation/storefront_route.dart';
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
import 'features/auth/post_login_permission_observer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player_win/video_player_win.dart';
import 'features/super_admin/screens/auth/super_admin_login_screen.dart';
import 'features/super_admin/widgets/super_admin_layout.dart';
import 'features/storefront/screens/customer_storefront_screen.dart';

/// Restore the local session behind the already visible splash. Server probing,
/// audio and notifications do not hold up entry into an offline-ready POS.
Future<void> _initializeAppServices({bool waitForEndpoint = false}) async {
  final endpointReady = ApiEndpoints.initialize().catchError((e) {
    debugPrint('ApiEndpoints init error: $e');
  });
  unawaited(endpointReady);
  unawaited(
    SoundService().init().catchError((e) {
      debugPrint('SoundService init error: $e');
    }),
  );
  unawaited(
    LocalNotificationService().init().catchError((e) {
      debugPrint('LocalNotificationService init error: $e');
    }),
  );

  // The database's cloud listeners need Firebase configured, but no remote
  // session validation or server response is required to restore local data.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase.initializeApp warning/info: $e');
  }
  await DatabaseService().init().catchError((e) {
    debugPrint('DatabaseService init error: $e');
  });
  unawaited(
    FcmService().init().catchError((e) {
      debugPrint('FcmService init error: $e');
    }),
  );
  if (waitForEndpoint) await endpointReady;
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

  // Launch via Customer Storefront (if web store URL), SuperAdmin on web, or fast animated SplashScreen
  Widget initialHome;
  final webStoreParams = parseStorefrontRoute(Uri.base, isWeb: kIsWeb);
  if (kIsWeb && webStoreParams != null && webStoreParams.slug.isNotEmpty) {
    await _initializeAppServices(waitForEndpoint: true);
    initialHome = CustomerStorefrontScreen(
      slug: webStoreParams.slug,
      tableCode: webStoreParams.tableCode,
      restaurantCode: webStoreParams.restaurantCode,
    );
  } else if (kIsWeb &&
      (Uri.base.path.toLowerCase().contains('admin') ||
          Uri.base.path.toLowerCase().contains('super'))) {
    await _initializeAppServices(waitForEndpoint: true);
    initialHome = const SuperAdminLoginScreen();
  } else {
    // Paint the branded first frame before any asynchronous service setup.
    initialHome = const SplashScreen(initialize: _initializeAppServices);
  }

  runApp(ProviderScope(child: ApnaPosApp(initialHome: initialHome)));
}

class ApnaPosApp extends StatefulWidget {
  final Widget initialHome;

  const ApnaPosApp({super.key, required this.initialHome});

  @override
  State<ApnaPosApp> createState() => _ApnaPosAppState();
}

class _ApnaPosAppState extends State<ApnaPosApp> {
  final _permissionObserver = PostLoginPermissionObserver();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: LocalNotificationService.navigatorKey,
      navigatorObservers: [_permissionObserver, chotuRouteObserver],
      title: 'Apna POS - Smart Restaurant Billing',
      debugShowCheckedModeBanner: false,
      theme: GlassTheme.themeData,
      builder: (context, child) {
        return SoundFeedbackWrapper(child: child ?? const SizedBox.shrink());
      },
      // Native notification intents are consumed by LocalNotificationService.
      // Do not let a platform route bypass splash/session restoration.
      initialRoute: kIsWeb ? null : Navigator.defaultRouteName,
      home: widget.initialHome,
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/get-started': (context) => const GetStartedScreen(),
        '/dashboard': (context) => const MainLayout(),
        '/admin': (context) => const SuperAdminLoginScreen(),
        '/admin/dashboard': (context) => const SuperAdminLayout(),
      },
      onGenerateRoute: (settings) {
        if (!kIsWeb) {
          return MaterialPageRoute(
            builder: (_) => widget.initialHome,
            settings: settings,
          );
        }
        final uri = Uri.tryParse(settings.name ?? '');
        final storefront = uri == null
            ? null
            : parseStorefrontRoute(uri, isWeb: kIsWeb);
        if (storefront == null) return null;
        return MaterialPageRoute(
          builder: (_) => CustomerStorefrontScreen(
            slug: storefront.slug,
            restaurantCode: storefront.restaurantCode,
            tableCode: storefront.tableCode,
          ),
          settings: settings,
        );
      },
    );
  }
}
