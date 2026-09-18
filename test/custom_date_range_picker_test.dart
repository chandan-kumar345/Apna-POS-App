import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/features/reports/widgets/custom_date_range_picker_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CustomDateRangePickerDialog renders From/To boxes and dual months', (tester) async {
    final start = DateTime(2025, 9, 1);
    final end = DateTime(2025, 9, 17);

    DateTimeRange? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await CustomDateRangePickerDialog.show(
                    context,
                    initialStartDate: start,
                    initialEndDate: end,
                  );
                },
                child: const Text('Open Picker'),
              );
            },
          ),
        ),
      ),
    );

    // Open the dialog
    await tester.tap(find.text('Open Picker'));
    await tester.pumpAndSettle();

    // Verify From Date and To Date labels and text
    expect(find.text('From Date'), findsOneWidget);
    expect(find.text('To Date'), findsOneWidget);
    expect(find.text('01 Sep 2025'), findsOneWidget);
    expect(find.text('17 Sep 2025'), findsOneWidget);

    // Verify month titles (e.g. September 2025)
    expect(find.text('September 2025'), findsOneWidget);

    // Verify Apply Range button
    expect(find.text('Apply Range'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Tap Apply Range
    await tester.tap(find.text('Apply Range'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.start.year, 2025);
    expect(result!.start.month, 9);
    expect(result!.start.day, 1);
    expect(result!.end.day, 17);
  });
}
