import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/models/coupon_model.dart';
import 'package:apna_pos/core/services/coupon_service.dart';
import 'package:apna_pos/features/coupon/screens/coupon_form_screen.dart';
import 'package:apna_pos/features/coupon/screens/coupon_management_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CouponService Offline Caching & Fallback Tests', () {
    test('CouponService provides cachedCoupons list without throwing', () {
      final service = CouponService();
      expect(service.cachedCoupons, isA<List<CouponModel>>());
    });

    test('CouponService validateCoupon falls back gracefully when offline', () async {
      final service = CouponService();
      final res = await service.validateCoupon(code: 'TESTCODE', cartSubtotal: 500);
      expect(res.valid, isFalse);
      expect(res.message, isNotEmpty);
    });
  });

  group('CouponFormScreen Keyboard & Layout Tests', () {
    testWidgets('Scaffold in CouponFormScreen has resizeToAvoidBottomInset: false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CouponFormScreen(
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsOneWidget);
      final scaffoldWidget = tester.widget<Scaffold>(scaffoldFinder);
      expect(scaffoldWidget.resizeToAvoidBottomInset, isFalse,
          reason: 'resizeToAvoidBottomInset must be false so white container does not jump up when keyboard opens');
    });

    testWidgets('CouponFormScreen has header quick-save action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CouponFormScreen(
            onSaved: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check for checkmark icon in header
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('When keyboard is simulated (viewInsets.bottom > 0), bottom sticky bar is hidden', (tester) async {
      // 1. Initial render with keyboard closed
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844), viewInsets: EdgeInsets.zero),
            child: CouponFormScreen(
              onSaved: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cancel button should be visible when keyboard is closed
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create Coupon'), findsOneWidget);

      // 2. Simulate soft keyboard open (viewInsets.bottom: 320)
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844), viewInsets: EdgeInsets.only(bottom: 320)),
            child: CouponFormScreen(
              onSaved: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The bottom sticky bar should be hidden (returning SizedBox.shrink()) so no white background jumps up
      expect(find.text('Cancel'), findsNothing,
          reason: 'Bottom sticky bar must be hidden when keyboard opens to prevent white background jump');
    });
  });

  group('CouponManagementScreen Performance & Search Tests', () {
    testWidgets('CouponManagementScreen renders instantly with cache support', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CouponManagementScreen(),
        ),
      );
      await tester.pump();

      // Screen renders top header without crashing
      expect(find.text('Coupons & Offers'), findsOneWidget);
      expect(find.text('Coupons & Codes'), findsOneWidget);
      expect(find.text('Promotional Banners'), findsOneWidget);
    });
  });
}