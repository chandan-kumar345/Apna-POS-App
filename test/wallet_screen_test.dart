import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/features/wallet/wallet_screen.dart';

void main() {
  testWidgets('WalletScreen renders all neumorphic cards, smaller typography, and wrapped sections', (WidgetTester tester) async {
    // Provide sufficient surface height for full scrollable view
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: WalletScreen(),
      ),
    );

    // Initial pump and settle
    await tester.pumpAndSettle();

    // 1. Header Verification
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    // 2. Card 1: Primary Balance Card
    expect(find.text('AVAILABLE NOW'), findsOneWidget);
    expect(find.text('Usable balance after hold amount'), findsOneWidget);
    expect(find.text('Used Balance'), findsWidgets);
    expect(find.text('Total Spent'), findsOneWidget);
    expect(find.text('Minimum balance to maintain: Rs. 100'), findsOneWidget);
    expect(find.text('View Transactions'), findsOneWidget);

    // 4. Card 3: 6-Metric Neumorphic Grid
    expect(find.text('Khazana Balance'), findsOneWidget);
    expect(find.text('Bonus Amount'), findsOneWidget);
    expect(find.text('Amount on Hold'), findsOneWidget);
    expect(find.text('Used Balance'), findsNWidgets(2));
    expect(find.text('Commission Amount'), findsOneWidget);
    expect(find.text('Cashback Amount'), findsOneWidget);

    // 5. Card 4: Add Amount (Recharge Section)
    expect(find.text('Add Amount'), findsOneWidget);
    expect(find.text('Instant recharge'), findsOneWidget);
    expect(find.text('Top up your Khazana instantly and keep operations uninterrupted.'), findsOneWidget);
    expect(find.text('Add Money'), findsOneWidget);
    expect(find.text('Minimum recharge value is Rs. 100'), findsOneWidget);

    // Quick recharge pills
    expect(find.text('+ ₹100'), findsOneWidget);
    expect(find.text('+ ₹200'), findsOneWidget);
    expect(find.text('+ ₹500'), findsOneWidget);
    expect(find.text('+ ₹1000'), findsOneWidget);

    // 6. Test interaction: tap quick pill '+ ₹500' and verify TextField updates
    await tester.tap(find.text('+ ₹500'));
    await tester.pumpAndSettle();
    expect(find.text('500'), findsOneWidget);

    // 7. Card 5: Communication Pricing Table
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Communication Pricing'), findsOneWidget);
    expect(find.text('SMS, Email, WhatsApp Auth & Utility rates (Pull down to refresh)'), findsOneWidget);
    expect(find.text('Channel'), findsOneWidget);
    expect(find.text('Credit'), findsOneWidget);
    expect(find.text('Price (₹)'), findsOneWidget);

    // Verify all 6 communication items
    expect(find.text('GST Supplier Lookup'), findsOneWidget);
    expect(find.text('WhatsApp Marketing'), findsOneWidget);
    expect(find.text('SMS'), findsOneWidget);
    expect(find.text('WhatsApp Utility'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('WhatsApp Authentication'), findsOneWidget);

    // Verify prices from reference image
    expect(find.text('₹2'), findsOneWidget);
    expect(find.text('₹1.09'), findsOneWidget);
    expect(find.text('₹0.16'), findsOneWidget);
    expect(find.text('₹0.215'), findsNWidgets(2)); // WhatsApp Utility & WhatsApp Authentication

    // Flush any pending network retry/timeout timers
    await tester.pump(const Duration(seconds: 5));
  });
}
