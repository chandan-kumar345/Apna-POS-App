import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/services/location_service.dart';
import 'package:apna_pos/core/services/network_service.dart';
import 'package:apna_pos/features/storefront/screens/customer_storefront_screen.dart';

Map<String, dynamic> _addressAndMediaMenuFixture({
  List<Map<String, dynamic>>? products,
  List<String>? categories,
}) => {
  'restaurant': {
    'id': 'river',
    'slug': 'river-kitchen',
    'name': 'River Kitchen',
    'tagline': 'Made fresh, every day',
    'cuisineType': 'Indian & Continental',
    'phone': '9876543210',
    'address': '12 River Road, Delhi',
    'currencySymbol': '₹',
    'services': ['Delivery', 'Takeaway'],
    'openingTime': '09:00 AM',
    'closingTime': '11:00 PM',
    'taxRate': 5,
    'tableCount': 0,
    'logoUrl': '',
    'isStorefrontOnline': true,
    'storefrontThemeColor': 0xFFE65100,
  },
  'isOnline': true,
  'themeColorHex': 0xFFE65100,
  'deliveryEta': '25–35 min',
  'categories': categories ?? ['Paneer Pizza', 'Drinks'],
  'products':
      products ??
      [
        {
          'id': 'p1',
          'name': 'Achari Paneer Pizza',
          'category': 'Paneer Pizza',
          'description': 'Paneer, onion, capsicum and tangy achari sauce',
          'price': 249,
          'image': 'assets/images/tpl_food_diwali_pizza.png',
          'foodType': 'veg',
        },
        {
          'id': 'p2',
          'name': 'Fresh Lime',
          'category': 'Drinks',
          'description': 'Fresh lime with sparkling water',
          'price': 79,
          'foodType': 'beverage',
        },
      ],
  'addons': [],
  'banners': [
    {
      'id': 'offer',
      'tag': 'LUNCH SPECIAL',
      'headline': 'COMBO DELIGHT BOX',
      'subtitle': 'Pizza + drink, made for your lunch break',
      'ctaText': 'EXPLORE MENU',
      'imageUrl': 'assets/images/tpl_food_bogo_pizza.png',
      'couponCode': 'LUNCH',
      'discountText': 'SAVE ₹100',
      'isActive': true,
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Interceptor> originals;
  late Map<String, dynamic> response;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    response = _addressAndMediaMenuFixture();
    final dio = ApiClient().dio;
    originals = List.of(dio.interceptors);
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.endsWith('/coupons')) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'success': true, 'data': const []},
              ),
            );
            return;
          }
          final branding = options.queryParameters['brandingOnly'] == 'true';
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': branding
                    ? {'restaurant': response['restaurant']}
                    : response,
              },
            ),
          );
        },
      ),
    );
  });

  tearDown(() {
    ApiClient().dio.interceptors
      ..clear()
      ..addAll(originals);
    NetworkService().dispose();
    LocationService.debugAddressSearchOverride = null;
    LocationService.debugCurrentLocationOverride = null;
    LocationService.debugResolveDetailsOverride = null;
    LocationService.debugPincodeLookupOverride = null;
  });

  Future<void> mount(
    WidgetTester tester, {
    required String slug,
    String? tableCode,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: Platform.environment['STOREFRONT_CAPTURE_DIR'] != null
              ? 'StorefrontReview'
              : null,
        ),
        home: CustomerStorefrontScreen(slug: slug, tableCode: tableCode),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openDeliveryAddressSheet(
    WidgetTester tester, {
    required String slug,
    Size size = const Size(390, 844),
  }) async {
    await mount(tester, slug: slug, size: size);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View All'));
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Achari Paneer Pizza').first);
    await tester.tap(find.text('Achari Paneer Pizza').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Add to Cart').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Cart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter Delivery Address'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'google address search autocomplete auto-fills address, landmark, and mandatory pincode',
    (tester) async {
      const suggestion = LocationAddressResult(
        fullAddress: 'Connaught Place, New Delhi, Delhi 110001',
        mainText: 'Connaught Place',
        secondaryText: 'New Delhi, Delhi',
        houseNo: '',
        landmark: 'Near Rajiv Chowk Metro',
        pincode: '110001',
        city: 'New Delhi',
        state: 'Delhi',
        country: 'India',
        placeId: 'cp-1',
      );
      LocationService.debugAddressSearchOverride = (query) async {
        return query.toLowerCase().contains('connaught')
            ? const [suggestion]
            : const [];
      };
      LocationService.debugResolveDetailsOverride = (_) async => suggestion;

      await openDeliveryAddressSheet(tester, slug: 'google-search-autofill');

      await tester.enterText(
        find.byKey(const ValueKey('google-address-search-input')),
        'Connaught Place',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('New Delhi, Delhi'));
      await tester.tap(find.text('New Delhi, Delhi'));
      await tester.pumpAndSettle();

      final addressField = tester.widget<TextField>(
        find.byKey(const ValueKey('delivery-address-input')),
      );
      final landmarkField = tester.widget<TextField>(
        find.byKey(const ValueKey('delivery-landmark-input')),
      );
      final pincodeField = tester.widget<TextField>(
        find.byKey(const ValueKey('delivery-pincode-input')),
      );

      expect(addressField.controller?.text, contains('Connaught Place'));
      expect(landmarkField.controller?.text, 'Near Rajiv Chowk Metro');
      expect(pincodeField.controller?.text, '110001');

      await tester.ensureVisible(find.text('Confirm Delivery Address'));
      await tester.tap(find.text('Confirm Delivery Address'));
      await tester.pumpAndSettle();

      expect(find.textContaining('110001'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'auto-fill button populates address, landmark, and mandatory pincode from location service',
    (tester) async {
      LocationService.debugCurrentLocationOverride = () async {
        return const LocationAddressResult(
          fullAddress: 'Sector 62, Noida, Uttar Pradesh 201309',
          mainText: 'Sector 62',
          secondaryText: 'Noida, Uttar Pradesh',
          houseNo: 'B-14',
          landmark: 'Near Stellar IT Park',
          pincode: '201309',
          city: 'Noida',
          state: 'Uttar Pradesh',
          country: 'India',
        );
      };

      await openDeliveryAddressSheet(tester, slug: 'gps-autofill');

      await tester.ensureVisible(
        find.byKey(const ValueKey('delivery-autofill-location-btn')),
      );
      await tester.tap(
        find.byKey(const ValueKey('delivery-autofill-location-btn')),
      );
      await tester.pumpAndSettle();

      final addressField = tester.widget<TextField>(
        find.byKey(const ValueKey('delivery-address-input')),
      );
      final landmarkField = tester.widget<TextField>(
        find.byKey(const ValueKey('delivery-landmark-input')),
      );
      final pincodeField = tester.widget<TextField>(
        find.byKey(const ValueKey('delivery-pincode-input')),
      );

      expect(addressField.controller?.text, isNotEmpty);
      expect(landmarkField.controller?.text, 'Near Stellar IT Park');
      expect(pincodeField.controller?.text, '201309');

      await tester.ensureVisible(find.text('Confirm Delivery Address'));
      await tester.tap(find.text('Confirm Delivery Address'));
      await tester.pumpAndSettle();

      expect(find.textContaining('201309'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    '6-digit pincode lookup auto-fills area when street is empty without compact overflow',
    (tester) async {
      LocationService.debugPincodeLookupOverride = (pin) async {
        if (pin != '560038') return null;
        return const LocationAddressResult(
          fullAddress: 'Indiranagar, Bengaluru, Karnataka 560038',
          mainText: 'Indiranagar',
          secondaryText: 'Bengaluru, Karnataka',
          houseNo: '',
          landmark: '',
          pincode: '560038',
          city: 'Bengaluru',
          state: 'Karnataka',
          country: 'India',
        );
      };

      await openDeliveryAddressSheet(
        tester,
        slug: 'pincode-lookup-compact',
        size: const Size(320, 760),
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('delivery-pincode-input')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('delivery-pincode-input')),
        '560038',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final addressField = tester.widget<TextField>(
        find.byKey(const ValueKey('delivery-address-input')),
      );
      expect(addressField.controller?.text, contains('Indiranagar'));
      expect(find.textContaining('Bengaluru'), findsWidgets);

      await tester.ensureVisible(find.text('Confirm Delivery Address'));
      await tester.tap(find.text('Confirm Delivery Address'));
      await tester.pumpAndSettle();

      expect(find.textContaining('560038'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'product list streams video media, shows category product image, variant labels, and wider bottom buttons',
    (tester) async {
      response = _addressAndMediaMenuFixture(
        categories: ['Paneer Pizza', 'Drinks'],
        products: [
          {
            'id': 'p1',
            'name': 'Achari Paneer Pizza',
            'category': 'Paneer Pizza',
            'description': 'Loaded paneer pizza with tangy sauce',
            'price': 249,
            'image': 'assets/images/tpl_food_diwali_pizza.png',
            'videoUrl': 'https://cdn.example.com/achari-pizza.mp4',
            'foodType': 'veg',
            'variants': [
              {'name': 'Regular', 'price': 249},
              {'name': 'Medium', 'price': 399},
              {'name': 'Large', 'price': 549},
            ],
          },
          {
            'id': 'p2',
            'name': 'Fresh Lime',
            'category': 'Drinks',
            'description': 'Chilled sparkling lime',
            'price': 79,
            'image': 'assets/images/tpl_food_diwali_pizza.png',
            'foodType': 'beverage',
          },
        ],
      );

      await mount(tester, slug: 'video-category-variants');
      await tester.pumpAndSettle();

      expect(find.textContaining('Variants: Regular'), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsWidgets);

      final homeNavContainer = tester.getSize(
        find.ancestor(
          of: find.text('Home'),
          matching: find.byType(Container),
        ).first,
      );
      expect(homeNavContainer.width, greaterThanOrEqualTo(68));

      await tester.tap(find.text('Menu'));
      await tester.pumpAndSettle();

      expect(find.byType(ClipOval), findsAtLeastNWidgets(2));
      expect(find.text('Variants:'), findsOneWidget);
      expect(find.text('Regular'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Large'), findsOneWidget);
      expect(find.byIcon(Icons.videocam_rounded), findsWidgets);

      final addButtonSize = tester.getSize(
        find.ancestor(
          of: find.text('Add').first,
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(addButtonSize.width, greaterThanOrEqualTo(98));

      await tester.ensureVisible(find.text('Fresh Lime').first);
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();

      final viewCartButtonSize = tester.getSize(
        find.ancestor(
          of: find.text('View Cart'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(viewCartButtonSize.width, greaterThanOrEqualTo(132));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
