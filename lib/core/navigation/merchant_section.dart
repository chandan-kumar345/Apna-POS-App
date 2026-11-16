/// The merchant sidebar's tab order and the corresponding public web paths.
enum MerchantSection {
  dashboard('/dashboard'),
  pos('/pos'),
  tables('/tables'),
  orders('/orders'),
  menu('/menu'),
  inventory('/inventory'),
  reports('/reports'),
  crm('/crm'),
  loyalty('/loyalty'),
  campaign('/campaign'),
  staff('/staff'),
  settings('/settings'),
  profile('/profile'),
  deleteOrders('/delete-orders');

  const MerchantSection(this.path);

  final String path;

  static const _aliases = {
    '/my-orders': orders,
    '/products': menu,
    '/sales-report': reports,
    '/sales-reports': reports,
    '/staff-settings': staff,
    '/business-settings': settings,
    '/staff-profile': profile,
  };

  static MerchantSection? fromTabIndex(int index) =>
      index >= 0 && index < values.length ? values[index] : null;

  static MerchantSection? _forPath(String path) {
    final normalized = path.toLowerCase();
    for (final section in values) {
      if (section.path == normalized) return section;
    }
    return _aliases[normalized];
  }

  /// Whether the first path component is reserved for a merchant section.
  static bool isRouteRoot(String segment) => _forPath('/$segment') != null;

  static bool hasExplicitStore(Uri uri) => [
    'store',
    'slug',
  ].any((key) => uri.queryParameters[key]?.trim().isNotEmpty == true);

  static bool hasTableQuery(Uri uri) => [
    'T',
    't',
    'TABLE',
    'table',
    'tableNumber',
    'tableCode',
    'tableno',
  ].any((key) => uri.queryParameters[key]?.trim().isNotEmpty == true);

  /// A bare merchant path takes precedence over a matching restaurant slug.
  /// Explicit storefront URLs and existing table QR links keep their meaning.
  static MerchantSection? fromUri(Uri uri) {
    if (hasExplicitStore(uri) || hasTableQuery(uri)) return null;

    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    if (segments.length > 1) return null;

    if (segments.isEmpty || segments.single.toLowerCase() == 'index.html') {
      final fragment = uri.fragment;
      if (!fragment.startsWith('/')) return null;
      final route = Uri.tryParse(fragment);
      if (route == null || hasExplicitStore(route) || hasTableQuery(route)) {
        return null;
      }
      final fragmentSegments = route.pathSegments.where(
        (segment) => segment.isNotEmpty,
      );
      if (fragmentSegments.length != 1) return null;
      return _forPath('/${fragmentSegments.single}');
    }

    return _forPath('/${segments.single}');
  }
}
