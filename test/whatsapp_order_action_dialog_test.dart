import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/services/sound_service.dart';
import 'package:apna_pos/features/orders/whatsapp_order_action_dialog.dart';

void main() {
  setUp(() async {
    SoundService.soundEnabled = false;
    SharedPreferences.setMockInitialValues({});
    final db = DatabaseService();
    await db.init();
  });

  Widget buildTestDialog({
    String orderId = 'ord_123',
    String orderNumber = 'ORD-261023-3714',
    String customerPhone = '+91 97095 93705',
    String customerName = 'unknown',
    double totalAmount = 901.0,
    String orderType = 'takeaway',
    List<Map<String, dynamic>> items = const [
      {
        'name': 'Paneer Supreme Pizza',
        'variant': 'Medium',
        'quantity': 2,
        'price': 429.0,
        'effectivePrice': 429.0,
      }
    ],
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => WhatsAppOrderActionDialog(
            orderId: orderId,
            orderNumber: orderNumber,
            customerPhone: customerPhone,
            customerName: customerName,
            totalAmount: totalAmount,
            orderType: orderType,
            items: items,
            createdAt: DateTime(2026, 10, 23, 2, 20),
          ),
        ),
      ),
    );
  }

  testWidgets('WhatsAppOrderActionDialog renders all cards, smaller text, and wrapped layout', (tester) async {
    tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestDialog());
    await tester.pumpAndSettle();

    // 1. Top Header Card
    expect(find.text('NEW WHATSAPP ORDER'), findsOneWidget);
    expect(find.text('#ORD-261023-3714'), findsOneWidget);
    expect(find.text('TakeAway'), findsOneWidget);

    // 2. Customer Card
    expect(find.text('unknown'), findsOneWidget);
    expect(find.text('+91 97095 93705'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);

    // 3. Order Items Card
    expect(find.text('ORDER ITEMS (1)'), findsOneWidget);
    expect(find.text('02:20 AM'), findsOneWidget);
    expect(find.text('Paneer Supreme Pizza'), findsOneWidget);
    expect(find.text('(Medium)'), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);
    expect(find.text('₹858'), findsWidgets); // subtotal and item total

    // 4. Bill Breakdown Card
    expect(find.text('Items Subtotal'), findsOneWidget);
    expect(find.text('Taxes & Charges (GST)'), findsOneWidget);
    expect(find.text('+₹43'), findsOneWidget);
    expect(find.text('Grand Total'), findsOneWidget);
    expect(find.text('All items + taxes & charges included'), findsOneWidget);
    expect(find.text('₹901'), findsOneWidget);

    // 5. Kitchen Prep Time Card
    expect(find.text('ESTIMATED KITCHEN PREP TIME'), findsOneWidget);
    expect(find.text('15 mins'), findsOneWidget);
    expect(find.text('20 mins'), findsOneWidget);
    expect(find.text('30 mins'), findsOneWidget);
    expect(find.text('45 mins'), findsOneWidget);
    expect(find.text('60 mins'), findsOneWidget);

    // 6. Action Buttons
    expect(find.text('Reject'), findsOneWidget);
    expect(find.text('Accept Order'), findsOneWidget);

    // Verify prep time selection changes without error
    await tester.tap(find.text('30 mins'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('WhatsAppOrderActionDialog fits on compact mobile screen without layout overflow', (tester) async {
    tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestDialog());
    await tester.pumpAndSettle();

    // Scroll through the wrapped view
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.text('Accept Order'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('WhatsAppOrderActionDialog.dismissIfShowing automatically closes popup on multi-device event', (tester) async {
    tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  WhatsAppOrderActionDialog.show(
                    ctx,
                    orderId: 'ord_sync_999',
                    orderNumber: 'ORD-SYNC-999',
                    customerPhone: '+91 98765 43210',
                    customerName: 'MultiDevice Customer',
                    totalAmount: 499.0,
                    orderType: 'delivery',
                  );
                },
                child: const Text('Show Order Dialog'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap button to open dialog
    await tester.tap(find.text('Show Order Dialog'));
    await tester.pumpAndSettle();

    // Dialog should now be showing
    expect(find.text('NEW WHATSAPP ORDER'), findsOneWidget);
    expect(find.text('#ORD-SYNC-999'), findsOneWidget);
    expect(WhatsAppOrderActionDialog.isShowing, isTrue);
    expect(WhatsAppOrderActionDialog.currentShowingOrderId, 'ord_sync_999');

    // Trying to dismiss with a non-matching order ID should NOT close the dialog
    WhatsAppOrderActionDialog.dismissIfShowing(orderId: 'wrong_order_id', action: 'accepted');
    await tester.pumpAndSettle();
    expect(find.text('NEW WHATSAPP ORDER'), findsOneWidget);
    expect(WhatsAppOrderActionDialog.isShowing, isTrue);

    // Calling dismiss with the matching order ID should close the dialog automatically!
    WhatsAppOrderActionDialog.dismissIfShowing(orderId: 'ord_sync_999', action: 'accepted');
    await tester.pumpAndSettle();

    // Dialog must be closed now
    expect(find.text('NEW WHATSAPP ORDER'), findsNothing);
    expect(WhatsAppOrderActionDialog.isShowing, isFalse);
    expect(WhatsAppOrderActionDialog.currentShowingOrderId, isNull);
  });
}
