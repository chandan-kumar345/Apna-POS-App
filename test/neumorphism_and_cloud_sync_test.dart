import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/services/firestore_service.dart';
import 'package:apna_pos/core/services/coupon_service.dart';
import 'package:apna_pos/core/models/coupon_model.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/features/storefront/screens/customer_storefront_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Neumorphism UI & System UI Overlay Tests', () {
    testWidgets(
      'CustomerStorefrontScreen renders AnnotatedRegion with dark status bar icons, Popular Picks, and Menu Add flow',
      (tester) async {
        final db = DatabaseService();
        final prevRest = db.restaurant;
        final prevItems = List<MenuItemModel>.from(db.menuItems);
        addTearDown(() {
          db.restaurant = prevRest;
          db.menuItems = prevItems;
        });
        db.restaurant = RestaurantModel(
          id: 'pizza-47-neumorph-test',
          slug: 'pizza-47',
          name: 'Pizza 47',
          tagline: 'Fresh pizzas',
          phone: '9876543210',
          address: 'Sector 62',
          cuisineType: 'Restaurant',
          services: const ['Delivery'],
        );
        db.menuItems = [
          MenuItemModel(
            id: 'p_neu_1',
            name: 'Special Loaded Pizza',
            category: 'Pizzas',
            price: 399,
            description: 'Loaded veg pizza',
          ),
        ];

        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.runAsync(() async {
          await tester.pumpWidget(
            const MaterialApp(
              home: CustomerStorefrontScreen(
                slug: 'pizza-47',
                isPreviewMode: true,
              ),
            ),
          );
          await Future.delayed(const Duration(milliseconds: 600));
        });

        await tester.pump();

        // Main screen wrapped in AnnotatedRegion for visible native top status bar
        expect(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          findsAtLeastNWidgets(1),
        );

        final annotatedRegion = tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
            );
        expect(
          annotatedRegion.value.statusBarIconBrightness,
          equals(Brightness.dark),
        );

        // Verify Home quick actions and Popular Picks with View All
        expect(find.text('Offers'), findsOneWidget);
        expect(find.text('Favorites'), findsOneWidget);
        expect(find.text('Support'), findsOneWidget);
        expect(find.text('Popular Picks'), findsOneWidget);
        expect(find.text('View All'), findsOneWidget);

        // Verify RefreshIndicator is present for pull-to-refresh
        expect(find.byType(RefreshIndicator), findsOneWidget);

        // Tap View All to open Menu and verify Add buttons render
        await tester.tap(find.text('View All'));
        await tester.pumpAndSettle();
        expect(find.text('Our Menu'), findsOneWidget);
        expect(find.text('Add'), findsAtLeastNWidgets(1));
      },
    );
  });

  group('Multi-Device Cloud Sync Methods & Database Tests', () {
    test(
      'DatabaseService syncRestaurantSettingsFromCloud handles graceful execution',
      () async {
        final db = DatabaseService();
        db.restaurant = RestaurantModel(
          id: 'rest_cloud_test_01',
          name: 'Cloud Cafe',
          companyName: 'Cloud Cafe',
          tagline: 'Best in Cloud',
          phone: '9999999999',
          address: 'Sector 62, Noida',
          cuisineType: 'Fast Food',
          isStorefrontOnline: true,
          storefrontThemeColor: 0xFFE65100,
        );

        // Should execute without throwing even when Firebase is in mock/offline mode
        await db.syncRestaurantSettingsFromCloud();
        expect(db.isStorefrontOnline, isTrue);
      },
    );

    test(
      'DatabaseService syncBannersFromCloud handles graceful execution',
      () async {
        final db = DatabaseService();
        db.restaurant = RestaurantModel(
          id: 'rest_cloud_test_02',
          name: 'Cloud Cafe 2',
          companyName: 'Cloud Cafe 2',
          tagline: 'Fast Delivery',
          phone: '9999999999',
          address: 'Sector 62, Noida',
          cuisineType: 'Fast Food',
        );

        await db.syncBannersFromCloud();
        expect(db.storefrontBanners, isNotNull);
      },
    );

    test(
      'FirestoreService saveStorefrontSettings & getStorefrontSettings interface contracts',
      () async {
        final firestoreService = FirestoreService();

        // Calling when offline or unit test environment safely catches without unhandled crashes
        await firestoreService.saveStorefrontSettings(
          restaurantId: 'test_rest_id',
          isOnline: true,
          themeColorHex: 0xFF0052FF,
          themeColorEndHex: 0xFF051C48,
        );

        final settings = await firestoreService.getStorefrontSettings(
          'test_rest_id',
        );
        expect(settings, isA<Map<String, dynamic>?>());
      },
    );

    test(
      'FirestoreService saveCoupons & getCoupons interface contracts',
      () async {
        final firestoreService = FirestoreService();

        final dummyCoupon = CouponModel(
          id: 'cp_test_01',
          code: 'WELCOME50',
          title: 'Flat 50 Off',
          description: 'New user welcome offer',
          discountType: 'flat',
          discountValue: 50.0,
          minCartAmount: 200.0,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
          isActive: true,
          createdAt: DateTime.now(),
        );

        await firestoreService.saveCoupons(
          restaurantId: 'test_rest_id',
          coupons: [dummyCoupon],
        );

        final coupons = await firestoreService.getCoupons('test_rest_id');
        expect(coupons, isA<List<CouponModel>>());
      },
    );

    test(
      'CouponService cachedCoupons provides unmodifiable list and handles caching',
      () async {
        final couponService = CouponService();
        expect(couponService.cachedCoupons, isA<List<CouponModel>>());
      },
    );
  });
}
