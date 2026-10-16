import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/services/sound_service.dart';
import 'package:apna_pos/core/widgets/liquid_wallet_balance_popup.dart';
import 'package:apna_pos/features/dashboard/main_layout.dart';
import 'package:apna_pos/features/wallet/wallet_screen.dart';
import 'package:apna_pos/core/services/network_service.dart';

void main() {
  final testRestaurant = RestaurantModel(
    id: 'test_rest_1',
    name: 'Shri Sai Cafe',
    companyName: 'Shri Sai Cafe',
    tagline: 'Best Cafe',
    phone: '+91 9709593705',
    address: '123 Market Street',
    cuisineType: 'Cafe',
    taxRate: 5.0,
    upiId: '9709593705@ybl',
    posViewMode: 'with_image',
  );

  setUp(() async {
    SoundService.soundEnabled = false;
    SharedPreferences.setMockInitialValues({
      'apna_pos_wallet_balance': 78.01,
    });
    final db = DatabaseService();
    await db.init();
    db.restaurant = testRestaurant;
    db.currentUser = UserModel(
      id: 'owner_01',
      name: 'Owner',
      email: 'owner@apnapos.com',
      phone: '9709593705',
      role: 'Owner',
      pin: '1234',
      restaurantId: 'test_rest_1',
      companyName: 'Shri Sai Cafe',
    );
    await db.setWalletBalance(78.01);
  });

  tearDown(() {
    NetworkService().dispose();
  });

  testWidgets('LiquidWalletBalancePopup renders dynamic balance and liquid iOS 27 design', (tester) async {
    bool closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiquidWalletBalancePopup(
            balance: 78.01,
            onClose: () => closed = true,
          ),
        ),
      ),
    );

    // Initial frame
    await tester.pump();
    // Finish entrance animation (320ms)
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Available Balance'), findsOneWidget);
    expect(find.text('₹78.01'), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsNothing);

    // Tap outside to trigger close
    final outside = find.byType(GestureDetector).first;
    await tester.tap(outside);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(closed, isTrue);
  });

  testWidgets('MainLayout top header has smaller icons and tapping wallet toggles liquid popup', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: MainLayout(),
        ),
      );
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 300));
      await tester.pump();

      // Verify company name badge and top header icons exist
      expect(find.text('Shri Sai Cafe'), findsWidgets);
      expect(find.byTooltip('Khazana Wallet'), findsOneWidget);
      expect(find.byTooltip('Notifications'), findsOneWidget);

      // Initially, popup is not open
      expect(find.text('Available Balance'), findsNothing);

      // Tap on top wallet button
      final walletButton = find.byTooltip('Khazana Wallet');
      await tester.tap(walletButton);
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 350));
      await tester.pump();

      // Liquid iOS 27 Available Balance popup should now be displayed
      expect(find.text('Available Balance'), findsOneWidget);
      expect(find.text('₹78.01'), findsOneWidget);

      // Tapping the card opens the full WalletScreen
      final cardContent = find.text('Available Balance');
      await tester.tap(cardContent);
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.byType(WalletScreen), findsOneWidget);
      expect(find.text('Wallet'), findsWidgets);
    });
  });

  testWidgets('Tapping wallet button a second time plays smooth closing transition and dismisses popup', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: MainLayout(),
        ),
      );
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 300));
      await tester.pump();

      // 1. Open popup
      final walletButton = find.byTooltip('Khazana Wallet');
      await tester.tap(walletButton);
      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.text('Available Balance'), findsOneWidget);

      // 2. Tap wallet button again to close
      await tester.tap(walletButton);
      await tester.pump();
      // During and after closing transition
      await Future.delayed(const Duration(milliseconds: 350));
      await tester.pump();

      // After closing transition completes, popup is dismissed
      expect(find.text('Available Balance'), findsNothing);
    });
  });
}
