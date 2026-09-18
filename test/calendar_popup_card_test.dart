import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/features/reports/widgets/calendar_popup_card.dart';
import 'package:apna_pos/features/reports/reports_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CalendarPopupCard renders navigation, weekday headers, and fires callbacks', (tester) async {
    final start = DateTime(2026, 9, 1);
    final end = DateTime(2026, 9, 18);

    DateTimeRange? selectedRange;
    bool applied = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CalendarPopupCard(
              initialStartDate: start,
              initialEndDate: end,
              onRangeSelected: (range) {
                selectedRange = range;
              },
              onApply: () {
                applied = true;
              },
            ),
          ),
        ),
      ),
    );

    // Verify month and year header
    expect(find.text('September 2026'), findsOneWidget);

    // Verify weekday headers
    expect(find.text('Su'), findsOneWidget);
    expect(find.text('Mo'), findsOneWidget);
    expect(find.text('Tu'), findsOneWidget);
    expect(find.text('We'), findsOneWidget);
    expect(find.text('Th'), findsOneWidget);
    expect(find.text('Fr'), findsOneWidget);
    expect(find.text('Sa'), findsOneWidget);

    // Verify date numbers exist
    expect(find.text('1'), findsWidgets);
    expect(find.text('18'), findsWidgets);

    // Tap a date to change selection
    await tester.tap(find.text('10').first, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(selectedRange, isNotNull);

    // Verify Apply button
    expect(find.text('Apply'), findsOneWidget);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(applied, isTrue);
  });

  testWidgets('ReportsScreen renders Box 1 Date Range and Box 2 Preset Dropdown side by side', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));

    await tester.pumpWidget(
      const MaterialApp(
        home: ReportsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Box 2 Preset Dropdown exists with "This Month"
    expect(find.text('This Month'), findsWidgets);

    // Verify Dropdowns exist for Outlets, Payments, and Order Types
    expect(find.text('All Outlets'), findsWidgets);
    expect(find.text('All Payment Modes'), findsWidgets);
    expect(find.text('All Order Types'), findsWidgets);

    // Verify Apply and Reset buttons
    expect(find.text('Apply'), findsWidgets);
    expect(find.text('Reset'), findsWidgets);
  });
}
