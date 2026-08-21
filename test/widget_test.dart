import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/main.dart';

void main() {
  testWidgets('Apna POS app test', (WidgetTester tester) async {
    await tester.pumpWidget(const ApnaPosApp());
    await tester.pump(const Duration(milliseconds: 500));
  });
}
