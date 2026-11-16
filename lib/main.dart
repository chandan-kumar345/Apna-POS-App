import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/widgets/chotu_activation_host.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/glass_theme.dart';
import 'core/navigation/storefront_route.dart';
import 'core/navigation/merchant_section.dart';
import 'core/navigation/merchant_web_router.dart';
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

  // Resolve public, admin, and merchant entry points before starting Flutter's
  // navigation. A protected merchant URL must never skip session restoration.
  final entryUri = Uri.base;
  Uri? merchantWebLocation;
  Widget initialHome;
  final webStoreParams = parseStorefrontRoute(entryUri, isWeb: kIsWeb);
  if (kIsWeb && webStoreParams != null && webStoreParams.slug.isNotEmpty) {
    await _initializeAppServices(waitForEndpoint: true);
    initialHome = CustomerStorefrontScreen(
      slug: webStoreParams.slug,
      tableCode: webStoreParams.tableCode,
      restaurantCode: webStoreParams.restaurantCode,
    );
  } else if (kIsWeb && _isAdminEntry(entryUri)) {
    await _initializeAppServices(waitForEndpoint: true);
    initialHome = const SuperAdminLoginScreen();
  } else {
    // Paint the branded first frame before any asynchronous service setup.
    if (kIsWeb) {
      usePathUrlStrategy();
      merchantWebLocation = entryUri;
    }
    initialHome = SplashScreen(
      initialize: _initializeAppServices,
      openLoginWhenSignedOut:
          kIsWeb &&
          (MerchantSection.fromUri(entryUri) != null ||
              entryUri.path == '/login'),
    );
  }

  runApp(
    ProviderScope(
      child: ApnaPosApp(
        initialHome: initialHome,
        merchantWebLocation: merchantWebLocation,
      ),
    ),
  );
}

bool _isAdminEntry(Uri uri) {
  final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
  final namespace =
      segments.isNotEmpty && segments.first.toLowerCase() != 'index.html'
      ? segments.first
      : uri.fragment
            .replaceFirst(RegExp(r'^/+'), '')
            .split(RegExp(r'[/\?]'))
            .first;
  return const {
    'admin',
    'super',
    'superadmin',
    'super-admin',
  }.contains(namespace.toLowerCase());
}

class ApnaPosApp extends StatefulWidget {
  final Widget initialHome;
  final Uri? merchantWebLocation;

  const ApnaPosApp({
    super.key,
    required this.initialHome,
    this.merchantWebLocation,
  });

  @override
  State<ApnaPosApp> createState() => _ApnaPosAppState();
}

class _ApnaPosAppState extends State<ApnaPosApp> {
  final _permissionObserver = PostLoginPermissionObserver();
  MerchantWebRouterDelegate? _merchantRouter;
  PlatformRouteInformationProvider? _merchantRouteInformation;

  @override
  void initState() {
    super.initState();
    final location = widget.merchantWebLocation;
    if (location == null) return;
    final relative = MerchantRouteParser.relativeUri(location);
    _merchantRouteInformation = PlatformRouteInformationProvider(
      initialRouteInformation: RouteInformation(uri: relative),
    );
    _merchantRouter = MerchantWebRouterDelegate(
      navigatorKey: LocalNotificationService.navigatorKey,
      initialUri: relative,
      initialHome: widget.initialHome,
      onGenerateRoute: _onGenerateRoute,
      observers: [_permissionObserver, chotuRouteObserver],
    );
  }

  @override
  void dispose() {
    _merchantRouteInformation?.dispose();
    _merchantRouter?.dispose();
    super.dispose();
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    final page = switch (name) {
      '/splash' => const SplashScreen(),
      '/login' => const LoginScreen(),
      '/get-started' => const GetStartedScreen(),
      // Route names can also arrive from browser history. Never use them to
      // construct an authenticated shell without running the startup guard.
      '/dashboard' =>
        kIsWeb
            ? const SplashScreen(
                initialize: _initializeAppServices,
                openLoginWhenSignedOut: true,
              )
            : const MainLayout(),
      '/admin' => const SuperAdminLoginScreen(),
      '/admin/dashboard' =>
        _merchantRouter == null
            ? const SuperAdminLayout()
            : const SuperAdminLoginScreen(),
      _ => null,
    };
    if (page != null) {
      return MaterialPageRoute(builder: (_) => page, settings: settings);
    }
    if (!kIsWeb) {
      return MaterialPageRoute(
        builder: (_) => widget.initialHome,
        settings: settings,
      );
    }
    final uri = Uri.tryParse(name ?? '');
    final storefront = uri == null
        ? null
        : parseStorefrontRoute(uri, isWeb: true);
    if (storefront == null) return null;
    return MaterialPageRoute(
      builder: (_) => CustomerStorefrontScreen(
        slug: storefront.slug,
        restaurantCode: storefront.restaurantCode,
        tableCode: storefront.tableCode,
      ),
      settings: settings,
    );
  }

  Widget _wrapApp(BuildContext context, Widget? child) =>
      SoundFeedbackWrapper(child: child ?? const SizedBox.shrink());

  @override
  Widget build(BuildContext context) {
    final merchantRouter = _merchantRouter;
    if (merchantRouter != null) {
      return MaterialApp.router(
        routeInformationProvider: _merchantRouteInformation,
        routeInformationParser: const MerchantRouteParser(),
        routerDelegate: merchantRouter,
        title: 'Apna POS - Smart Restaurant Billing',
        debugShowCheckedModeBanner: false,
        theme: GlassTheme.themeData,
        builder: _wrapApp,
      );
    }
    return MaterialApp(
      navigatorKey: LocalNotificationService.navigatorKey,
      navigatorObservers: [_permissionObserver, chotuRouteObserver],
      title: 'Apna POS - Smart Restaurant Billing',
      debugShowCheckedModeBanner: false,
      theme: GlassTheme.themeData,
      builder: _wrapApp,
      // Native notification intents are consumed by LocalNotificationService.
      // Do not let a platform route bypass splash/session restoration.
      initialRoute: kIsWeb ? null : Navigator.defaultRouteName,
      home: widget.initialHome,
      onGenerateRoute: _onGenerateRoute,
    );
  }
}
