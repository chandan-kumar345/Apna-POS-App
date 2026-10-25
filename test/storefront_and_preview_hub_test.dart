import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/features/storefront/models/storefront_model.dart';
import 'package:apna_pos/features/storefront/services/storefront_service.dart';
import 'package:apna_pos/features/storefront/screens/customer_storefront_screen.dart';

void main() {
  group('Storefront & Company Slug Algorithms', () {
    test('slugify converts company names into clean URL slugs', () {
      expect(RestaurantModel.slugify('Pizza 47'), equals('pizza-47'));
      expect(RestaurantModel.slugify('Apna POS & Cafe!'), equals('apna-pos-cafe'));
      expect(RestaurantModel.slugify('Burger King Noida-62'), equals('burger-king-noida-62'));
      expect(RestaurantModel.slugify('   My Store   '), equals('my-store'));
      expect(RestaurantModel.slugify(''), equals('store'));
    });

    test('storefrontSlug and storefrontUrl fallback logically', () {
      final rest1 = RestaurantModel(
        id: 'rest_01',
        name: 'Pizza 47',
        companyName: 'Pizza 47',
        tagline: 'Best Pizza in Town',
        phone: '9876543210',
        address: 'Sector 62, Noida',
        cuisineType: 'Pizzas • Burgers • Fast Food',
      );

      expect(rest1.storefrontSlug, equals('pizza-47'));
      expect(rest1.storefrontUrl, equals('https://apnaposs.vercel.app/pizza-47'));

      final restCustomSlug = rest1.copyWith(slug: 'pizza-47-express');
      expect(restCustomSlug.storefrontSlug, equals('pizza-47-express'));
      expect(restCustomSlug.storefrontUrl, equals('https://apnaposs.vercel.app/pizza-47-express'));
    });

    test('StorefrontCartItem calculates price with size and addons dynamically', () {
      final item = MenuItemModel(
        id: 'p1',
        name: 'Paneer Supreme Pizza',
        category: 'Pizzas',
        price: 249.0,
        salePrice: 249.0,
        description: 'Loaded with fresh paneer & mozzarella',
      );

      final size = const ProductSizeOption(
        id: 'med',
        name: 'Medium',
        description: '10" (2-3 servings)',
        price: 349.0,
      );

      final addon1 = StorefrontAddonItem(
        id: 'a1',
        name: 'Extra Cheese',
        price: 40.0,
        isSelected: true,
      );

      final addon2 = StorefrontAddonItem(
        id: 'a2',
        name: 'Jalapeños',
        price: 30.0,
        isSelected: false, // Not selected
      );

      final cartItem = StorefrontCartItem(
        uid: 'c1',
        item: item,
        selectedSize: size,
        selectedAddons: [addon1, addon2],
        quantity: 2,
        instructions: 'Less spicy',
      );

      // Unit price = 349 (Medium) + 40 (Cheese) = 389
      expect(cartItem.unitPrice, equals(389.0));
      // Total price = 389 * 2 = 778
      expect(cartItem.totalPrice, equals(778.0));

      final convertedOrder = cartItem.toCartItemModel();
      expect(convertedOrder.quantity, equals(2));
      expect(convertedOrder.item.price, equals(389.0));
      expect(convertedOrder.note?.contains('Medium'), isTrue);
      expect(convertedOrder.note?.contains('Extra Cheese'), isTrue);
      expect(convertedOrder.note?.contains('Less spicy'), isTrue);
    });

    test('StorefrontService loads fallback data with banners and menu items', () async {
      final service = StorefrontService();
      final data = await service.loadStorefront('pizza-47');

      expect(data.restaurant.name.isNotEmpty, isTrue);
      expect(data.categories.contains('Pizzas') || data.categories.contains('All'), isTrue);
      expect(data.menuItems.isNotEmpty, isTrue);
      expect(data.banners.isNotEmpty, isTrue);
    });
  });

  group('CustomerStorefrontScreen UI Rendering', () {
    testWidgets('renders storefront screen components', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: CustomerStorefrontScreen(
              slug: 'pizza-47',
              isPreviewMode: true,
            ),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));
        await tester.pump();
      });

      // Verify that Delivery and Pickup switcher pills appear
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('Pickup'), findsOneWidget);

      // Verify search field exists
      expect(find.byType(TextField), findsWidgets);
    });
  });
}
