import 'dart:async';

import 'package:flutter/material.dart';

import '../notifications/services/notification_permission_helper.dart';

/// Starts permission setup once the destination after login has rendered.
class PostLoginPermissionObserver extends NavigatorObserver {
  void _requestForRoute(Route<dynamic>? route) {
    if (route is! PageRoute<dynamic>) return;
    // Welcome is for signed-out users; restored sessions go straight to the app.
    if (route.settings.name == '/get-started') return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!route.isCurrent) return;
      unawaited(
        NotificationPermissionHelper.requestAllAppPermissionsAfterLogin(),
      );
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // The initial route is the splash screen, before session routing resolves.
    if (previousRoute != null) _requestForRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _requestForRoute(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _requestForRoute(previousRoute);
  }
}
