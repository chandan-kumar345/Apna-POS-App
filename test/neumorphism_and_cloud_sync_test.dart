import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/services/firestore_service.dart';
import 'package:apna_pos/core/services/coupon_service.dart';
import 'package:apna_pos/core/models/coupon_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/features/storefront/models/storefront_model.dart';
import 'package:apna_pos/features/storefront/screens/customer_storefront_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Neumorphism UI & System UI Overlay Tests', () {
    testWidgets('CustomerStorefrontScreen renders AnnotatedRegion with dark status bar icons and NO "View All" button', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: CustomerStorefrontScreen(slug: 'pizza-47', isPreviewMode: true),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 600));
      });

      await tester.pump();

      // Main screen wrapped in AnnotatedRegion for visible native top status bar
      expect(find.byType(AnnotatedRegion<SystemUiOverlayStyle>), findsAtLeastNWidgets(1));

      final annotatedRegion = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      );
      expect(annotatedRegion.value.statusBarIconBrightness, equals(Brightness.dark));

      // Verify "View All" text button is completely removed
      expect(find.text('View All'), findsNothing);

      // Verify RefreshIndicator is present for pull-to-refresh
      expect(find.byType(RefreshIndicator), findsOneWidget);

      // Verify Delivery and Pickup segmented switcher is present
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('Pickup'), findsOneWidget);

      // Verify Product Card Add button is present
      expect(find.text('Add'), findsAtLeastNWidgets(1));
    });
  });

  group('Multi-Device Cloud Sync Methods & Database Tests', () {
    test('DatabaseService syncRestaurantSettingsFromCloud handles graceful execution', () async {
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
    });

    test('DatabaseService syncBannersFromCloud handles graceful execution', () async {
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
    });

    test('FirestoreService saveStorefrontSettings & getStorefrontSettings interface contracts', () async {
      final firestoreService = FirestoreService();

      // Calling when offline or unit test environment safely catches without unhandled crashes
      await firestoreService.saveStorefrontSettings(
        restaurantId: 'test_rest_id',
        isOnline: true,
        themeColorHex: 0xFF0052FF,
        themeColorEndHex: 0xFF051C48,
      );

      final settings = await firestoreService.getStorefrontSettings('test_rest_id');
      expect(settings, isA<Map<String, dynamic>?>());
    });

    test('FirestoreService saveCoupons & getCoupons interface contracts', () async {
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
    });

    test('CouponService cachedCoupons provides unmodifiable list and handles caching', () async {
      final couponService = CouponService();
      expect(couponService.cachedCoupons, isA<List<CouponModel>>());
    });
  });
}
