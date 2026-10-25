import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/coupon_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/features/coupon/dialogs/promotional_banner_dialog.dart';
import 'package:apna_pos/features/coupon/screens/coupon_management_screen.dart';
import 'package:apna_pos/features/storefront/models/storefront_model.dart';
import 'package:apna_pos/features/storefront/services/storefront_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Promotional Banner Section & Storefront Dynamic Integration', () {
    final db = DatabaseService();

    setUp(() {
      db.restaurant = RestaurantModel(
        id: 'rest_test',
        name: 'Pizza Hub',
        companyName: 'Pizza Hub Ltd',
        slug: 'pizza-hub',
        tagline: 'Fresh & Crisp Pizzas',
        phone: '+91 98765 43210',
        address: 'Sector 62, Noida',
        cuisineType: 'Pizzas & Fast Food',
      );
    });

    test('DatabaseService saves, toggles, and deletes promotional storefront banners', () async {
      const banner1 = StorefrontBanner(
        id: 'b_test_1',
        tag: 'HOT & SPICY',
        headline: 'PERI PERI DELIGHT',
        subtitle: 'Extra spicy chicken & capsicum',
        ctaText: 'ORDER NOW ➔',
        imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591',
        accentColorHex: 0xFFE65100,
        couponCode: 'PERI50',
        discountText: 'FLAT 50% OFF',
        isActive: true,
      );

      await db.saveStorefrontBanner(banner1);
      expect(db.storefrontBanners.any((b) => b.id == 'b_test_1'), isTrue);

      // Verify toggle
      await db.toggleStorefrontBanner('b_test_1');
      final toggled = db.storefrontBanners.firstWhere((b) => b.id == 'b_test_1');
      expect(toggled.isActive, isFalse);

      // Toggle back to active
      await db.toggleStorefrontBanner('b_test_1');
      expect(db.storefrontBanners.firstWhere((b) => b.id == 'b_test_1').isActive, isTrue);

      // Verify StorefrontService loads dynamic banner
      final storefrontData = await StorefrontService().loadStorefront('pizza-hub');
      expect(storefrontData.banners.any((b) => b.id == 'b_test_1'), isTrue);
      expect(storefrontData.banners.firstWhere((b) => b.id == 'b_test_1').couponCode, equals('PERI50'));

      // Verify delete
      await db.deleteStorefrontBanner('b_test_1');
      expect(db.storefrontBanners.any((b) => b.id == 'b_test_1'), isFalse);
    });

    testWidgets('PromotionalBannerDialog allows designing and saving banner offer', (tester) async {
      StorefrontBanner? savedBanner;

      final List<CouponModel> testCoupons = [
        const CouponModel(
          id: 'c_1',
          code: 'SUPER30',
          title: '30% Super Discount',
          discountType: 'percentage',
          discountValue: 30,
          isActive: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PromotionalBannerDialog(
              availableCoupons: testCoupons,
              onSave: (b) {
                savedBanner = b;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify dialog renders
      expect(find.text('Create Promotional Banner'), findsOneWidget);
      expect(find.text('LIVE STOREFRONT PREVIEW'), findsOneWidget);

      // Tap on Save Banner button
      final saveBtn = find.text('Save Banner');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(savedBanner, isNotNull);
      expect(savedBanner!.headline, isNotEmpty);
      expect(savedBanner!.isActive, isTrue);
    });

    testWidgets('CouponManagementScreen switches between Coupons and Promotional Banners tabs', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: CouponManagementScreen(),
          ),
        );

        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 100));
        await tester.pump();

        // Check segmented switcher tabs
        expect(find.text('Coupons & Codes'), findsOneWidget);
        expect(find.text('Promotional Banners'), findsOneWidget);

        // Switch to Promotional Banners tab
        await tester.tap(find.text('Promotional Banners'));
        await tester.pumpAndSettle();

        // Verify promotional banners section is visible
        expect(find.text('Live Customer Profile Header'), findsOneWidget);
        expect(find.text('Total Banners'), findsOneWidget);
        expect(find.text('Live on Web'), findsNWidgets(2));
        expect(find.text('With Coupons'), findsOneWidget);
        expect(find.text('Search banners by headline, tag or coupon...'), findsOneWidget);
      });
    });
  });
}
