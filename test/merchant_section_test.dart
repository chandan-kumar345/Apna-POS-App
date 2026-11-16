import 'package:apna_pos/core/navigation/merchant_section.dart';
import 'package:apna_pos/core/navigation/storefront_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all sidebar tabs have a unique canonical merchant web path', () {
    final paths = [
      '/dashboard',
      '/pos',
      '/tables',
      '/orders',
      '/menu',
      '/inventory',
      '/reports',
      '/crm',
      '/loyalty',
      '/campaign',
      '/staff',
      '/settings',
      '/profile',
      '/delete-orders',
    ];
    expect(MerchantSection.values.map((section) => section.path), paths);
    for (var i = 0; i < paths.length; i++) {
      final section = MerchantSection.fromTabIndex(i);
      expect(section?.path, paths[i]);
      final uri = Uri.parse('https://apnaposs.vercel.app${paths[i]}');
      expect(MerchantSection.fromUri(uri), section);
      expect(parseStorefrontRoute(uri, isWeb: true), isNull);
    }
    expect(MerchantSection.fromTabIndex(-1), isNull);
    expect(MerchantSection.fromTabIndex(paths.length), isNull);
  });

  test('normalizes case, trailing slashes and supported legacy aliases', () {
    final examples = {
      '/DASHBOARD/?source=saved': MerchantSection.dashboard,
      '/#/pos': MerchantSection.pos,
      '/index.html#/SALES-REPORTS/': MerchantSection.reports,
      '/business-settings': MerchantSection.settings,
      '/staff-profile': MerchantSection.profile,
      '/my-orders': MerchantSection.orders,
      '/products': MerchantSection.menu,
    };
    for (final entry in examples.entries) {
      final uri = Uri.parse(entry.key);
      expect(MerchantSection.fromUri(uri), entry.value, reason: entry.key);
      expect(parseStorefrontRoute(uri, isWeb: true), isNull);
    }
    expect(MerchantSection.fromUri(Uri.parse('/pos/child')), isNull);
    expect(MerchantSection.fromUri(Uri.parse('/admin/dashboard')), isNull);
  });

  test('public storefronts and QR links can still use protected names', () {
    final examples = {
      '/store/pos?R=R1&T=T04': 'pos',
      '/pos?store=pizza-47&R=R1&T=T04': 'pizza-47',
      '/dashboard?slug=pizza-47&restaurantCode=R1&tableCode=T04': 'pizza-47',
      '/tables?R=R1&T=T04': 'tables',
      '/orders/R=R1&T=T04': 'orders',
      '/#/menu?R=R1&TABLE=T04': 'menu',
      '/#/pos?store=pizza-47&R=R1&tableCode=T04': 'pizza-47',
      '/store/admin?R=R1&T=T04': 'admin',
      '/super-sushi?R=R1&T=T04': 'super-sushi',
    };
    for (final entry in examples.entries) {
      final uri = Uri.parse(entry.key);
      expect(MerchantSection.fromUri(uri), isNull, reason: entry.key);
      final storefront = parseStorefrontRoute(uri, isWeb: true);
      expect(storefront?.slug, entry.value, reason: entry.key);
      expect(storefront?.tableCode, 'T04', reason: entry.key);
      expect(storefront?.restaurantCode, 'R1', reason: entry.key);
      expect(parseStorefrontRoute(uri, isWeb: false), isNull);
    }
  });

  test('admin namespace cannot be reclassified as a storefront', () {
    for (final value in [
      '/admin/dashboard',
      '/super',
      '/superadmin',
      '/super-admin',
      '/admin?store=pizza-47',
      '/#/admin/dashboard?store=pizza-47',
    ]) {
      final uri = Uri.parse(value);
      expect(MerchantSection.fromUri(uri), isNull, reason: value);
      expect(parseStorefrontRoute(uri, isWeb: true), isNull, reason: value);
    }
  });
}
