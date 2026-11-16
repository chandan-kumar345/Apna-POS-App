import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'merchant_section.dart';

/// Keeps the address intact until the authenticated shell selects a section.
/// That lets a legacy alias be replaced by the actual section on entry, while
/// preserving public storefront and QR query parameters during app startup.
class MerchantRouteParser extends RouteInformationParser<Uri> {
  const MerchantRouteParser();

  static Uri relativeUri(Uri uri) => Uri(
    path: uri.path.isEmpty ? '/' : uri.path,
    query: uri.hasQuery ? uri.query : null,
    fragment: uri.hasFragment ? uri.fragment : null,
  );

  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) =>
      SynchronousFuture(relativeUri(routeInformation.uri));

  @override
  RouteInformation restoreRouteInformation(Uri configuration) =>
      RouteInformation(uri: configuration);
}

/// A Router manages browser history, and one Navigator manages the existing
/// imperative auth, onboarding, dialogs, and nested screen transitions.
/// Browser navigation only requests tabs; it never creates a merchant shell.
class MerchantWebRouterDelegate extends RouterDelegate<Uri>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Uri> {
  MerchantWebRouterDelegate({
    required this.navigatorKey,
    required Uri initialUri,
    required this.initialHome,
    required this.onGenerateRoute,
    this.observers = const [],
  }) : _configuration = MerchantRouteParser.relativeUri(initialUri),
       _requestedSection = MerchantSection.fromUri(initialUri);

  @override
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget initialHome;
  final RouteFactory onGenerateRoute;
  final List<NavigatorObserver> observers;

  Uri _configuration;
  MerchantSection? _requestedSection;
  ValueChanged<MerchantSection>? _shellListener;

  static MerchantWebRouterDelegate? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_MerchantRouterScope>()
      ?.delegate;

  @override
  Uri get currentConfiguration => _configuration;

  MerchantSection? get requestedSection => _requestedSection;

  MerchantSection? consumeRequestedSection() {
    final section = _requestedSection;
    _requestedSection = null;
    return section;
  }

  void attach(ValueChanged<MerchantSection> listener) {
    _shellListener = listener;
  }

  void detach(ValueChanged<MerchantSection> listener) {
    if (_shellListener == listener) _shellListener = null;
  }

  /// Updates browser history after access checks and actual tab selection.
  void reportSection(MerchantSection section) {
    final uri = Uri(path: section.path);
    if (_configuration == uri) return;
    _configuration = uri;
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(Uri configuration) {
    final uri = MerchantRouteParser.relativeUri(configuration);
    if (_configuration == uri) return SynchronousFuture(null);
    _configuration = uri;
    final section = MerchantSection.fromUri(uri);
    final listener = _shellListener;
    if (listener == null) {
      // A link opened before login stays pending until the shell mounts.
      _requestedSection = section;
    } else {
      _requestedSection = null;
      if (section != null) {
        listener(section);
      } else if (uri.path == '/' && !uri.hasQuery && !uri.hasFragment) {
        // The original document entry may be root, before any tab was chosen.
        // The shell is still responsible for applying roles and preferences.
        final root = MerchantSection.fromUri(Uri(path: '/pos'));
        if (root != null) listener(root);
      }
    }
    // Router rebuilds after a platform URI is applied. Avoid notifying here:
    // an already recorded browser entry must not create new history entries.
    return SynchronousFuture(null);
  }

  Route<dynamic>? _route(RouteSettings settings) {
    if (settings.name == Navigator.defaultRouteName) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => initialHome,
      );
    }
    return onGenerateRoute(settings);
  }

  @override
  Widget build(BuildContext context) => _MerchantRouterScope(
    delegate: this,
    child: Navigator(
      key: navigatorKey,
      initialRoute: Navigator.defaultRouteName,
      onGenerateRoute: _route,
      observers: observers,
    ),
  );
}

class _MerchantRouterScope extends InheritedWidget {
  const _MerchantRouterScope({required this.delegate, required super.child});

  final MerchantWebRouterDelegate delegate;

  @override
  bool updateShouldNotify(_MerchantRouterScope oldWidget) =>
      oldWidget.delegate != delegate;
}
