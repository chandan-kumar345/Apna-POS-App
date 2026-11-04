import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/features/storefront/screens/customer_storefront_screen.dart';
import 'package:apna_pos/core/services/network_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    NetworkService().dispose();
  });

  testWidgets('CustomerStorefrontScreen displays cooking pan loading gif for Restaurant category', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerStorefrontScreen(
            slug: 'test-restaurant-slug',
            businessCategory: 'Restaurant',
          ),
        ),
      );
      await tester.pump();

      // Verify restaurant cooking loader is shown
      expect(find.text('Preparing Your Menu...'), findsOneWidget);
      expect(find.text('Tossing fresh ingredients & dishes'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);

      // Verify standard non-restaurant loader text is NOT shown
      expect(find.text('Loading Storefront...'), findsNothing);
    });
  });

  testWidgets('CustomerStorefrontScreen displays standard loader for non-restaurant category (e.g. Grocery Store)', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerStorefrontScreen(
            slug: 'test-grocery-slug',
            businessCategory: 'Grocery Store',
          ),
        ),
      );
      await tester.pump();

      // Verify standard circular loader is shown for retail/grocery
      expect(find.text('Loading Storefront...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Verify restaurant cooking loader text is NOT shown
      expect(find.text('Preparing Your Menu...'), findsNothing);
      expect(find.text('Tossing fresh ingredients & dishes'), findsNothing);
    });
  });
}
