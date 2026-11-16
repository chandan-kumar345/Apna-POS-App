import 'merchant_section.dart';

const _adminRoots = {'admin', 'super', 'superadmin', 'super-admin'};
const _protectedRoots = {
  ..._adminRoots,
  'login',
  'splash',
  'get-started',
  'index.html',
  'onboarding',
};

/// Builds a public link without mistaking a business name for an app section.
/// Ordinary slugs keep their existing URLs, while reserved slugs use /store/.
Uri buildPublicStorefrontUri(
  String slug, {
  String? restaurantCode,
  String? tableCode,
}) {
  final cleanSlug = slug.trim().isEmpty ? 'store' : slug.trim();
  final root = cleanSlug.toLowerCase();
  final reserved =
      _protectedRoots.contains(root) || MerchantSection.isRouteRoot(root);
  final query = {
    if (restaurantCode?.trim().isNotEmpty == true) 'R': restaurantCode!.trim(),
    if (tableCode?.trim().isNotEmpty == true) 'T': tableCode!.trim(),
  };
  return Uri(
    scheme: 'https',
    host: 'apnaposs.vercel.app',
    pathSegments: [if (reserved) 'store', cleanSlug],
    queryParameters: query.isEmpty ? null : query,
  );
}

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
  if (!isWeb || MerchantSection.fromUri(uri) != null) return null;

  final pathTableMarker = RegExp(
    r'(?:^|[&,])(?:T|TABLE)\s*=\s*[^&,]+|^T[0-9]+$',
    caseSensitive: false,
  );
  final pathSegments = uri.pathSegments
      .where((s) => s.trim().isNotEmpty)
      .toList();
  final root = pathSegments.firstOrNull?.toLowerCase();
  final fragment = uri.fragment.replaceAll(RegExp(r'^[/#]+'), '').trim();
  if (_adminRoots.contains(root)) return null;
  if (root == null || root == 'index.html') {
    final fragmentRoot = fragment.split(RegExp(r'[/\?]')).first.toLowerCase();
    if (_adminRoots.contains(fragmentRoot)) return null;
  }

  String? slug;
  String? rCode =
      uri.queryParameters['R'] ??
      uri.queryParameters['r'] ??
      uri.queryParameters['restaurant'];
  String? tCode =
      uri.queryParameters['T'] ??
      uri.queryParameters['t'] ??
      uri.queryParameters['table'] ??
      uri.queryParameters['TABLE'] ??
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

  bool canUseBareSlug(List<String> segments) {
    final first = segments.first.toLowerCase();
    if (_protectedRoots.contains(first)) return false;
    if (!MerchantSection.isRouteRoot(first)) return true;
    // Preserve existing QR links for a restaurant whose name collides with a
    // new merchant route. A plain path without a table stays reserved.
    if (slug != null) return false;
    if (tCode?.trim().isNotEmpty == true) return true;
    return segments.length > 1 && pathTableMarker.hasMatch(segments[1]);
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
  if (pathSegments.isNotEmpty) {
    final first = pathSegments.first.toLowerCase();
    if (canUseBareSlug(pathSegments)) {
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
  if (fragment.isNotEmpty) {
    final queryStart = fragment.indexOf('?');
    final fragPath = queryStart >= 0
        ? fragment.substring(0, queryStart)
        : fragment;
    if (queryStart >= 0) {
      final query = Uri.tryParse('/${fragment.substring(queryStart)}');
      final params = (query?.queryParameters ?? const <String, String>{}).map(
        (name, value) => MapEntry(name.toLowerCase(), value),
      );
      final fragmentSlug = params['store'] ?? params['slug'];
      if (fragmentSlug?.trim().isNotEmpty == true) {
        slug ??= fragmentSlug!.trim().toLowerCase();
      }
      rCode ??= params['r'] ?? params['restaurant'] ?? params['restaurantcode'];
      tCode ??=
          params['t'] ??
          params['table'] ??
          params['tablenumber'] ??
          params['tablecode'] ??
          params['tableno'];
    }
    final fragSegments = fragPath
        .split('/')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (fragSegments.isNotEmpty) {
      final first = fragSegments.first.toLowerCase();
      if (canUseBareSlug(fragSegments)) {
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
