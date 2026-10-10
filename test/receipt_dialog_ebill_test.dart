import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/services/network_service.dart';
import 'package:apna_pos/features/pos/receipt_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    NetworkService().dispose();
  });

  tearDown(() {
    NetworkService().dispose();
  });

  final testItem = MenuItemModel(
    id: 'item_101',
    name: 'Dal Makhani',
    category: 'Main Course',
    price: 250.0,
    description: 'Creamy black lentils',
  );

  final orderWithoutPhone = OrderModel(
    id: 'ORD-901',
    orderNumber: 'INV-2026-00101',
    items: [CartItemModel(item: testItem, quantity: 2)],
    subtotal: 500.0,
    taxAmount: 25.0,
    discountAmount: 0.0,
    totalAmount: 525.0,
    paymentMethod: 'UPI',
    customerName: 'Aarav Gupta',
    customerPhone: '',
    createdAt: '10/10/2026 08:30 PM',
  );

  final orderWithPhone = OrderModel(
    id: 'ORD-902',
    orderNumber: 'INV-2026-00102',
    items: [CartItemModel(item: testItem, quantity: 1)],
    subtotal: 250.0,
    taxAmount: 12.5,
    discountAmount: 0.0,
    totalAmount: 262.5,
    paymentMethod: 'Cash',
    customerName: 'Rahul Sharma',
    customerPhone: '9876543210',
    createdAt: '10/10/2026 08:35 PM',
  );

  testWidgets('ReceiptDialog replaces Share Bill with Save & eBill and keeps Print Thermal', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReceiptDialog(
            order: orderWithPhone,
            currency: '₹',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify "Share Bill" is REMOVED
    expect(find.text('Share Bill'), findsNothing);

    // 2. Verify "Save & eBill" is PRESENT
    expect(find.text('Save & eBill'), findsOneWidget);

    // 3. Verify "Print Thermal" is PRESENT and intact
    expect(find.text('Print Thermal'), findsOneWidget);

    // 4. Verify preview bill number & totals
    expect(find.text('Bill: #INV-2026-00102'), findsOneWidget);
    expect(find.text('Total :'), findsOneWidget);

    // Flush any pending network check timers
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('ReceiptDialog disables Save & eBill and shows warning when customer phone is missing', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReceiptDialog(
            order: orderWithoutPhone,
            currency: '₹',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Check warning message for missing customer mobile
    expect(
      find.text("Please add the customer's mobile number to send the bill through WhatsApp."),
      findsOneWidget,
    );

    // Verify Save & eBill button is disabled
    final saveAndEbillButtonFinder = find.widgetWithText(ElevatedButton, 'Save & eBill');
    expect(saveAndEbillButtonFinder, findsOneWidget);

    final ElevatedButton button = tester.widget(saveAndEbillButtonFinder);
    expect(button.onPressed, isNull); // Disabled!

    // Flush any pending network check timers
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('ReceiptDialog enables Save & eBill and displays wallet info when customer phone is valid', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReceiptDialog(
            order: orderWithPhone,
            currency: '₹',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Customer mobile displayed
    expect(find.text('Mobile: 9876543210'), findsOneWidget);

    // Wallet information displayed
    expect(find.textContaining('Business Wallet:'), findsOneWidget);
    expect(find.textContaining('eBill Fee:'), findsOneWidget);

    // Save & eBill button is enabled
    final saveAndEbillButtonFinder = find.widgetWithText(ElevatedButton, 'Save & eBill');
    expect(saveAndEbillButtonFinder, findsOneWidget);

    final ElevatedButton button = tester.widget(saveAndEbillButtonFinder);
    expect(button.onPressed, isNotNull); // Enabled!

    // Flush any pending network check timers
    await tester.pump(const Duration(seconds: 2));
  });
}
