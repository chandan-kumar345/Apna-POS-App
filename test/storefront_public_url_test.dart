import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/navigation/merchant_section.dart';
import 'package:apna_pos/core/navigation/storefront_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normal public storefront and table links retain their addresses', () {
    expect(
      buildPublicStorefrontUri('pizza-47').toString(),
      'https://apnaposs.vercel.app/pizza-47',
    );
    expect(
      buildPublicStorefrontUri(
        'pizza-47',
        restaurantCode: 'R1',
        tableCode: 'T01',
      ).toString(),
      'https://apnaposs.vercel.app/pizza-47?R=R1&T=T01',
    );
  });

  test('storefronts with reserved slugs get an explicit public URL', () {
    for (final slug in ['dashboard', 'pos', 'my-orders', 'admin', 'login']) {
      final restaurant = RestaurantModel(
        id: 'restaurant-1',
        name: 'Example Outlet',
        slug: slug,
        tagline: '',
        phone: '',
        address: '',
        cuisineType: '',
      );
      final url = Uri.parse(restaurant.storefrontUrl);
      expect(url.path, '/store/$slug');
      expect(MerchantSection.fromUri(url), isNull);
      expect(parseStorefrontRoute(url, isWeb: true)?.slug, slug);
    }
  });

  test('new and already printed colliding QR links resolve to their table', () {
    final current = buildPublicStorefrontUri(
      'pos',
      restaurantCode: 'R1',
      tableCode: 'T02',
    );
    expect(current.path, '/store/pos');
    for (final uri in [current, Uri.parse('/pos?R=R1&T=T02')]) {
      final route = parseStorefrontRoute(uri, isWeb: true);
      expect(route?.slug, 'pos');
      expect(route?.restaurantCode, 'R1');
      expect(route?.tableCode, 'T02');
    }
  });
}
