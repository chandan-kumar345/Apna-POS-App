import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/models/loyalty_program_model.dart';
import 'package:apna_pos/features/loyalty/screens/loyalty_landing_screen.dart';
import 'package:apna_pos/features/loyalty/screens/create_loyalty_program_screen.dart';
import 'package:apna_pos/features/loyalty/screens/loyalty_program_details_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('Loyalty Cashback Screens Tests', () {
    testWidgets('Screen 1: LoyaltyLandingScreen renders dashboard with header, hero card, metrics and programs', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(const LoyaltyLandingScreen()));
      await tester.pumpAndSettle();

      // Top bar elements
      expect(find.text('APNA'), findsOneWidget);
      expect(find.text('POS'), findsOneWidget);
      expect(find.text('Pizza 47'), findsWidgets);

      // Header title & subtitle
      expect(find.text('Loyalty Program'), findsOneWidget);
      expect(find.text('Build customer loyalty with cashback, points & rewards.'), findsOneWidget);

      // Hero card
      expect(find.text('Cashback Rewards'), findsOneWidget);
      expect(find.text('Give instant or future cashback on every order.'), findsOneWidget);

      // 3 Stat Cards
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('3,420'), findsOneWidget);
      expect(find.text('Total Cashback'), findsOneWidget);
      expect(find.text('₹1,24,560'), findsOneWidget);
      expect(find.text('Redemptions'), findsOneWidget);
      expect(find.text('2,860'), findsOneWidget);

      // Active programs
      expect(find.text('Active Programs (2)'), findsOneWidget);
      expect(find.text('5% Cashback Program'), findsOneWidget);
      expect(find.text('Get 5% cashback on all orders'), findsOneWidget);
      expect(find.text('₹50 Cashback on ₹500'), findsOneWidget);

      // Action button
      expect(find.text('Create Loyalty Program'), findsOneWidget);

      // Bottom nav bar
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Campaigns'), findsOneWidget);
      expect(find.text('Loyalty'), findsOneWidget);
      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
    });

    testWidgets('Screen 2: CreateLoyaltyProgramScreen renders stepper wizard and interactive steps', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(const CreateLoyaltyProgramScreen()));
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Create Loyalty Program'), findsOneWidget);

      // Stepper
      expect(find.text('1 Reward'), findsOneWidget);
      expect(find.text('2 Rules'), findsOneWidget);
      expect(find.text('3 Message'), findsOneWidget);
      expect(find.text('4 Review'), findsOneWidget);

      // Program types
      expect(find.text('Program type'), findsOneWidget);
      expect(find.text('Cashback'), findsOneWidget);
      expect(find.text('Points'), findsOneWidget);
      expect(find.text('Discount'), findsOneWidget);
      expect(find.text('Rewards'), findsOneWidget);

      // Program name & description inputs
      expect(find.text('Cashback on Every Order'), findsOneWidget);
      expect(find.text('Give cashback to customers on every purchase to build long-term loyalty.'), findsOneWidget);

      // Cashback type radios
      expect(find.text('Percentage Cashback (%)'), findsOneWidget);
      expect(find.text('Fixed Cashback (₹)'), findsOneWidget);

      // Example info callout
      expect(find.text('Example: On a bill of ₹1,000, customer will get ₹50 cashback.'), findsOneWidget);

      // Footer
      expect(find.text('Save Draft'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Tap Next to advance to Step 2 (Rules)
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Earning Rules & Limits'), findsOneWidget);
      expect(find.text('Minimum Order Value (₹)'), findsOneWidget);
      expect(find.text('Maximum Cashback per Order (₹)'), findsOneWidget);
      expect(find.text('Validity Period'), findsOneWidget);
      expect(find.text('Dine-In'), findsOneWidget);
      expect(find.text('Takeaway'), findsOneWidget);
      expect(find.text('Delivery'), findsOneWidget);
    });

    testWidgets('Screen 3: LoyaltyProgramDetailsScreen renders cashback details, performance, and actions', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final program = LoyaltyProgramModel(
        id: 'prog_cashback_5',
        type: LoyaltyType.cashback,
        title: '5% Cashback Program',
        description: 'Get 5% cashback on all orders',
        earningRule: 'Get 5% cashback on all orders',
        cashbackType: 'percentage',
        cashbackPercentage: 5.0,
        minimumOrder: 499.0,
        maximumCashback: 150.0,
        validity: '01 Nov 2026 – 31 Dec 2026',
        eligibleCustomers: 'All Customers',
        orderTypes: const ['Dine-In', 'Takeaway', 'Delivery'],
        ordersCount: 2860,
        cashbackGiven: 124560.0,
        redemptionRate: 78.4,
        membersCount: 3420,
        isActive: true,
      );

      await tester.pumpWidget(buildTestWidget(LoyaltyProgramDetailsScreen(program: program)));
      await tester.pumpAndSettle();

      // Top bar
      expect(find.text('Cashback Program'), findsOneWidget);

      // Program hero card
      expect(find.text('5% Cashback Program'), findsOneWidget);
      expect(find.text('Get 5% cashback on all orders'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);

      // Program details card
      expect(find.text('Program Details'), findsOneWidget);
      expect(find.text('5% of order value'), findsOneWidget);
      expect(find.text('₹499'), findsOneWidget);
      expect(find.text('₹150 per order'), findsOneWidget);
      expect(find.text('01 Nov 2026 – 31 Dec 2026'), findsOneWidget);
      expect(find.text('All Customers'), findsOneWidget);

      // Program performance card
      expect(find.text('Program Performance'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('2,860'), findsOneWidget);
      expect(find.text('Cashback Given'), findsOneWidget);
      expect(find.text('₹1,24,560'), findsOneWidget);
      expect(find.text('Redemption Rate'), findsOneWidget);
      expect(find.text('78.4%'), findsOneWidget);

      // 4 Action buttons
      expect(find.text('Edit\nProgram'), findsOneWidget);
      expect(find.text('View\nReports'), findsOneWidget);
      expect(find.text('Eligible\nCustomers'), findsOneWidget);
      expect(find.text('Deactivate'), findsOneWidget);
    });
  });
}
