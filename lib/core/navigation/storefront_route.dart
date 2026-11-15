// Public restaurant URLs are a web entry point. Native order intents use the
// notification bridge and must never be interpreted as restaurant slugs.
class StorefrontRouteParams {
  final String slug;
  final String? restaurantCode;
  final String? tableCode;

  const StorefrontRouteParams({
    required this.slug,
    this.restaurantCode,
    this.tableCode,
  });
}

StorefrontRouteParams? parseStorefrontRoute(Uri uri, {required bool isWeb}) {
  if (!isWeb) return null;

  String? slug;
  String? rCode =
      uri.queryParameters['R'] ??
      uri.queryParameters['r'] ??
      uri.queryParameters['restaurant'];
  String? tCode =
      uri.queryParameters['T'] ??
      uri.queryParameters['t'] ??
      uri.queryParameters['table'] ??
      uri.queryParameters['tableNumber'];

  void parseSegmentForParams(String seg) {
    try {
      final decoded = Uri.decodeComponent(seg).trim();
      final pairs = decoded.split(RegExp(r'[&,]'));
      for (final pair in pairs) {
        final kv = pair.split('=');
        if (kv.length == 2) {
          final k = kv[0].trim().toUpperCase();
          final v = kv[1].trim();
          if (k == 'R') rCode ??= v;
          if (k == 'T' || k == 'TABLE') tCode ??= v;
        } else if (pair.toUpperCase().startsWith('T') && pair.length >= 2) {
          tCode ??= pair.trim();
        }
      }
    } catch (_) {}
  }

  // 1. Query parameter: ?store=company-name or ?slug=company-name, ?table=T02, ?t=2, etc.
  final querySlug = uri.queryParameters['store'] ?? uri.queryParameters['slug'];
  if (querySlug != null && querySlug.trim().isNotEmpty) {
    slug = querySlug.trim().toLowerCase();
  }
  final queryTable =
      uri.queryParameters['table'] ??
      uri.queryParameters['t'] ??
      uri.queryParameters['tableNumber'] ??
      uri.queryParameters['tableCode'] ??
      uri.queryParameters['tableno'] ??
      uri.queryParameters['T'];
  if (queryTable != null && queryTable.trim().isNotEmpty) {
    tCode ??= queryTable.trim();
  }
  final queryRestaurant =
      uri.queryParameters['restaurant'] ??
      uri.queryParameters['r'] ??
      uri.queryParameters['restaurantCode'] ??
      uri.queryParameters['R'];
  if (queryRestaurant != null && queryRestaurant.trim().isNotEmpty) {
    rCode ??= queryRestaurant.trim();
  }

  // 2. Direct Path: /company-name or /company-name/R=R1&T=T01
  final pathSegments = uri.pathSegments
      .where((s) => s.trim().isNotEmpty)
      .toList();
  if (pathSegments.isNotEmpty) {
    final first = pathSegments.first.toLowerCase();
    if (![
      'admin',
      'super',
      'login',
      'splash',
      'dashboard',
      'get-started',
      'index.html',
    ].contains(first)) {
      if (first == 'store' && pathSegments.length > 1) {
        slug = pathSegments[1].toLowerCase();
        if (pathSegments.length > 2) {
          parseSegmentForParams(pathSegments[2]);
        }
      } else {
        slug = first;
        if (pathSegments.length > 1) {
          parseSegmentForParams(pathSegments[1]);
        }
      }
    }
  }

  // 3. Fragment: #/company-name/R=R1&T=T01
  final fragment = uri.fragment.replaceAll(RegExp(r'^[/#]+'), '').trim();
  if (fragment.isNotEmpty) {
    final fragParts = fragment.split('?');
    final fragPath = fragParts[0];
    if (fragParts.length > 1) {
      final qPairs = fragParts[1].split('&');
      for (final qp in qPairs) {
        final kv = qp.split('=');
        if (kv.length == 2) {
          final k = kv[0].trim().toUpperCase();
          final v = kv[1].trim();
          if (k == 'R') rCode ??= v;
          if (k == 'T' || k == 'TABLE') tCode ??= v;
        }
      }
    }
    final fragSegments = fragPath
        .split('/')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (fragSegments.isNotEmpty) {
      final first = fragSegments.first.toLowerCase();
      if (![
        'admin',
        'super',
        'login',
        'splash',
        'dashboard',
        'get-started',
      ].contains(first)) {
        if (first == 'store' && fragSegments.length > 1) {
          slug ??= fragSegments[1].toLowerCase();
          if (fragSegments.length > 2) {
            parseSegmentForParams(fragSegments[2]);
          }
        } else {
          slug ??= first;
          if (fragSegments.length > 1) {
            parseSegmentForParams(fragSegments[1]);
          }
        }
      }
    }
  }

  if (slug == null || slug.isEmpty) return null;

  return StorefrontRouteParams(
    slug: slug,
    restaurantCode: rCode,
    tableCode: tCode,
  );
}
