import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/features/storefront/widgets/storefront_menu_view.dart';

void main() {
  testWidgets(
    'loading uses restaurant identity and theme without a fullscreen spinner',
    (tester) async {
      final restaurant = RestaurantModel(
        id: 'river',
        name: 'River Kitchen',
        tagline: '',
        phone: '',
        address: '',
        cuisineType: 'Indian',
        storefrontThemeColor: 0xFF187C65,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: StorefrontMenuLoading(
            restaurant: restaurant,
            avatar: (_, name, size) => CircleAvatar(child: Text(name[0])),
          ),
        ),
      );
      expect(find.text('River Kitchen'), findsOneWidget);
      expect(find.textContaining('Loading River Kitchen'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .color,
        const Color(0xFF187C65),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
