import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/features/orders/incoming_order_accept_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('IncomingOrderAcceptScreen renders properly with all cards and actions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final sampleItems = [
      {
        'name': 'Paneer Butter Masala',
        'quantity': 2,
        'price': 240.0,
        'isVeg': true,
      },
      {
        'name': 'Butter Naan',
        'quantity': 4,
        'price': 40.0,
        'isVeg': true,
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: IncomingOrderAcceptScreen(
          orderId: 'ord_test_101',
          orderNumber: 'ORD-101',
          customerPhone: '9876543210',
          customerName: 'Rahul Sharma',
          totalAmount: 640.0,
          orderType: 'delivery',
          deliveryAddress: 'Flat 402, Green Park Residency, Sector 12',
          items: sampleItems,
          createdAt: DateTime.now(),
          source: 'whatsapp',
        ),
      ),
    );

    await tester.pump();

    // Verify Title & Header
    expect(find.text('NEW INCOMING ORDER'), findsOneWidget);
    expect(find.text('#ORD-101'), findsOneWidget);
    expect(find.text('DELIVERY'), findsOneWidget);

    // Verify Customer Info
    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.textContaining('98765'), findsOneWidget);
    expect(find.textContaining('Green Park Residency'), findsOneWidget);

    // Verify Items List
    expect(find.text('Paneer Butter Masala'), findsOneWidget);
    expect(find.text('Butter Naan'), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);
    expect(find.text('4x'), findsOneWidget);

    // Verify Preparation Time Chips
    expect(find.text('20 mins'), findsOneWidget);
    expect(find.text('30 mins'), findsOneWidget);

    // Verify Accept and Reject Buttons
    expect(find.text('ACCEPT ORDER'), findsOneWidget);
    expect(find.text('REJECT'), findsOneWidget);
  });

  testWidgets('IncomingOrderAcceptScreen prep time selection updates state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: IncomingOrderAcceptScreen(
          orderId: 'ord_test_102',
          orderNumber: 'ORD-102',
          customerPhone: '9876543210',
          customerName: 'Amit Verma',
          totalAmount: 350.0,
          orderType: 'takeaway',
          items: const [
            {'name': 'Veg Biryani', 'quantity': 1, 'price': 350.0}
          ],
          createdAt: DateTime.now(),
        ),
      ),
    );

    await tester.pump();

    // Tap '30 mins' chip
    final chip30 = find.text('30 mins');
    expect(chip30, findsOneWidget);
    await tester.tap(chip30);
    await tester.pump();

    // Verify 30 mins chip text color changed to white (active state)
    final textWidget = tester.widget<Text>(chip30);
    expect(textWidget.style?.color, equals(Colors.white));
  });
}
