import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/features/crm/screens/crm_leads_screen.dart';

void main() {
  testWidgets('CrmLeadsScreen renders and handles interactions without throwing null type errors', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CrmLeadsScreen(),
        ),
      ),
    );

    // Initial pump and settling
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify UI components exist
    expect(find.text('CRM'), findsOneWidget);
    expect(find.text('Add Lead'), findsOneWidget);
    expect(find.text('Total Contacts'), findsOneWidget);

    // Tap on metric cards
    await tester.tap(find.text('Leads').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Prospects').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Deals').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Won Customers').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Open and close Add Lead Dialog
    await tester.tap(find.text('Add Lead'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Add New Lead'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Open and close Import Dialog
    await tester.tap(find.text('Import'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Import Customers'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Test mobile layout
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CRM'), findsOneWidget);
  });
}


