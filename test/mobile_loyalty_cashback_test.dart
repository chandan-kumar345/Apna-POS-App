import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    testWidgets('Screen 1: LoyaltyLandingScreen renders redesigned dashboard with dynamic metrics and programs', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dynamicBranding = LoyaltyBrandingModel(
        companyName: 'Pizza 47',
        companyLogo: '',
        members: 7,
        totalCashback: 156,
        redemptions: 3,
        revenue: 5420,
        revenueGrowthPercent: 18,
        programs: [
          LoyaltyProgramModel(
            id: 'prog_cashback_1',
            type: LoyaltyType.cashback,
            title: 'Cashback on Every Order',
            description: 'Give cashback to customers on their orders.',
            earningRule: 'Get 5% cashback on all orders',
            validity: '01 Oct 2026 – 23 Nov 2026',
            startedDate: '01 Oct 2026',
            membersCount: 5,
            ordersCount: 6,
            cashbackGiven: 156,
            isActive: true,
          ),
          LoyaltyProgramModel(
            id: 'prog_inactive_1',
            type: LoyaltyType.cashback,
            title: 'Weekend Bonus Cashback',
            description: 'Extra rewards on weekend orders.',
            earningRule: 'Get ₹50 cashback',
            validity: '31 Dec 2026',
            membersCount: 2,
            isActive: false,
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestWidget(
          LoyaltyLandingScreen(
            showHeader: false,
            initialBranding: dynamicBranding,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hero Banner Header title & subtitle
      expect(find.text('Loyalty Program'), findsOneWidget);
      expect(
        find.text('Boost customer loyalty with cashback,\nrewards & more.'),
        findsOneWidget,
      );

      // Cashback Rewards Banner Card
      expect(find.text('Cashback Rewards'), findsOneWidget);
      expect(
        find.text('Give instant or future cashback on every order.'),
        findsOneWidget,
      );

      // 4 Dynamic Metric Cards
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Total Cashback'), findsOneWidget);
      expect(find.text('₹156'), findsOneWidget);
      expect(find.text('Redemptions'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Revenue'), findsOneWidget);
      expect(find.text('₹5,420'), findsOneWidget);
      expect(find.text('+18%'), findsOneWidget);

      // Programs section & dynamic metadata (without View All)
      expect(find.text('All Programs (2)'), findsOneWidget);
      expect(find.text('View All'), findsNothing);
      expect(find.text('Cashback on Every Order'), findsOneWidget);
      expect(find.text('Give cashback to customers on their orders.'), findsOneWidget);
      expect(find.text('Valid till: 23 Nov 2026'), findsOneWidget);
      expect(find.text('Used by: 5 customers'), findsOneWidget);
      expect(find.text('Weekend Bonus Cashback'), findsOneWidget);

      // Revenue info dialog opens cleanly
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Loyalty Revenue'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Bottom CTA Button
      expect(find.text('Create Loyalty Program'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Screen 1b: LoyaltyLandingScreen handles desktop width (showHeader: false) and zero empty metrics gracefully', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final emptyBranding = LoyaltyBrandingModel(
        companyName: 'Pizza 47',
        companyLogo: '',
        members: 0,
        totalCashback: 0,
        redemptions: 0,
        revenue: 0,
        revenueGrowthPercent: null,
        programs: const [],
      );

      await tester.pumpWidget(
        buildTestWidget(
          LoyaltyLandingScreen(
            showHeader: false,
            initialBranding: emptyBranding,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Loyalty Program'), findsOneWidget);
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(2)); // Members and Redemptions
      expect(find.text('₹0'), findsNWidgets(2)); // Total Cashback and Revenue
      expect(find.text('Active Programs (0)'), findsOneWidget);
      expect(find.text('No active programs yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

      // KPI Metrics Grid
      expect(find.text('Total Customers'), findsOneWidget);
      expect(find.text('3,420'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('2,860'), findsOneWidget);
      expect(find.text('Cashback Given'), findsOneWidget);
      expect(find.text('₹1,24,560'), findsOneWidget);
      expect(find.text('Redemption Rate'), findsOneWidget);
      expect(find.text('78.40%'), findsOneWidget);
      expect(find.text('Revenue'), findsOneWidget);
      expect(find.text('Avg. Revenue / Redemption'), findsOneWidget);

      // Recent Transactions table
      expect(find.text('Recent Transactions'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);

      // 3 Action buttons
      expect(find.text('Edit Program'), findsOneWidget);
      expect(find.text('Eligible Customers'), findsWidgets);
      expect(find.text('Deactivate'), findsOneWidget);
    });

    testWidgets('Loyalty screens stay fixed when keyboard opens', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      final branding = LoyaltyBrandingModel(
        companyName: 'Pizza 47',
        companyLogo: '',
        members: 1,
        totalCashback: 10,
        redemptions: 1,
        revenue: 100,
        programs: const [],
      );

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpWidget(
        buildTestWidget(
          LoyaltyLandingScreen(
            showHeader: false,
            initialBranding: branding,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(scaffold.resizeToAvoidBottomInset, isFalse);
      final beforeTop = tester.getTopLeft(find.text('Create Loyalty Program')).dy;

      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pump();

      final afterTop = tester.getTopLeft(find.text('Create Loyalty Program')).dy;
      expect(afterTop, equals(beforeTop));
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(520, 915);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpWidget(buildTestWidget(const CreateLoyaltyProgramScreen()));
      await tester.pumpAndSettle();

      final createScaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(createScaffold.resizeToAvoidBottomInset, isFalse);
      final beforeNext = tester.getTopLeft(find.text('Next')).dy;

      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.text('Next')).dy, equals(beforeNext));
      expect(tester.takeException(), isNull);
    });

    testWidgets('LoyaltyLandingScreen shows complete texts without truncation or View All at 360px width', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final branding = LoyaltyBrandingModel(
        companyName: 'Pizza 47',
        companyLogo: '',
        members: 7,
        totalCashback: 521,
        redemptions: 3,
        revenue: 8711,
        revenueGrowthPercent: 414,
        programs: [
          LoyaltyProgramModel(
            id: 'prog_cashback_1',
            type: LoyaltyType.cashback,
            title: 'Cashback on Every Order',
            description: 'Give cashback to customers on every purchase to build long-term loyalty.',
            earningRule: 'Get 5% cashback on all orders',
            validity: '20 Feb 2027',
            membersCount: 2,
            isActive: true,
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestWidget(
          LoyaltyLandingScreen(
            showHeader: false,
            initialBranding: branding,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Programs (1)'), findsOneWidget);
      expect(find.text('View All'), findsNothing);

      for (final expectedText in const [
        'Members',
        'Total Cashback',
        'Redemptions',
        'Revenue',
        '₹8,711',
        '+414%',
        'Cashback on Every Order',
        'Give cashback to customers on every purchase to build long-term loyalty.',
        'Valid till: 20 Feb 2027',
        'Used by: 2 customers',
      ]) {
        final finder = find.text(expectedText);
        expect(finder, findsOneWidget, reason: '$expectedText should be displayed');
        final paragraph = tester.renderObject<RenderParagraph>(finder);
        expect(paragraph.didExceedMaxLines, isFalse, reason: '$expectedText must not truncate');
      }

      expect(tester.takeException(), isNull);
    });
  });
}
