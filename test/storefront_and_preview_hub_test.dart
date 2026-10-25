import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/features/storefront/models/storefront_model.dart';
import 'package:apna_pos/features/storefront/services/storefront_service.dart';
import 'package:apna_pos/features/storefront/screens/customer_storefront_screen.dart';
import 'package:apna_pos/features/storefront/widgets/item_customization_sheet.dart';
import 'package:apna_pos/features/storefront/widgets/storefront_cart_sheet.dart';
import 'package:apna_pos/features/pos/widgets/pos_product_media_box.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

    test('Storefront online toggle and theme color defaults and updating', () async {
      final db = DatabaseService();
      expect(db.isStorefrontOnline, isTrue);
      expect(db.storefrontThemeColor, equals(0xFFE65100));

      await db.setStorefrontOnline(false);
      expect(db.isStorefrontOnline, isFalse);

      await db.setStorefrontThemeColor(0xFF10B981, 0xFF059669);
      expect(db.storefrontThemeColor, equals(0xFF10B981));
      expect(db.storefrontThemeColorEnd, equals(0xFF059669));

      // Reset
      await db.setStorefrontOnline(true);
      await db.setStorefrontThemeColor(0xFFE65100, null);
      expect(db.storefrontThemeColorEnd, isNull);
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

    test('StorefrontService loads fallback data with banners, online status, and theme', () async {
      final service = StorefrontService();
      final data = await service.loadStorefront('pizza-47');

      expect(data.restaurant.name.isNotEmpty, isTrue);
      expect(data.categories.contains('Pizzas') || data.categories.contains('All'), isTrue);
      expect(data.menuItems.isNotEmpty, isTrue);
      expect(data.banners.isNotEmpty, isTrue);
      expect(data.isOnline, isTrue);
      expect(data.themeColorHex, equals(0xFFE65100));
    });
  });

  group('CustomerStorefrontScreen UI Rendering', () {
    testWidgets('renders storefront screen components on 360px viewport without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FlutterErrorDetails? caughtDetails;
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) {
          caughtDetails = details;
        }
      };

      try {
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
      } finally {
        FlutterError.onError = oldHandler;
      }

      // Verify that Delivery and Pickup switcher pills appear
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.text('Pickup'), findsOneWidget);

      // Verify search field exists below header
      expect(find.byType(TextField), findsWidgets);

      // Zero RenderFlex overflows
      expect(caughtDetails, isNull);
    });

    testWidgets('ItemCustomizationSheet HIDES variant/size section when product has NO variants', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Product with NO variants
      final itemNoVariants = MenuItemModel(
        id: 'p_no_var',
        name: 'Classic Garlic Bread',
        category: 'Sides',
        price: 129.0,
        salePrice: 129.0,
        description: 'Toasted baguette with garlic butter and herbs.',
        variants: const [], // NO variants!
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemCustomizationSheet(
              item: itemNoVariants,
              onAddToCart: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "Select Size" must NOT be shown!
      expect(find.text('Select Size'), findsNothing);

      // Check height is still 65% of screen height (800 * 0.65 = 520)
      final sheetFinder = find.byType(ItemCustomizationSheet);
      expect(sheetFinder, findsOneWidget);
      final size = tester.getSize(sheetFinder);
      expect(size.height, closeTo(520, 1.0));
    });

    testWidgets('ItemCustomizationSheet SHOWS variant/size section when product has multiple variants', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Product with multiple variants
      final itemWithVariants = MenuItemModel(
        id: 'p_var',
        name: 'Margherita Pizza',
        category: 'Pizzas',
        price: 199.0,
        salePrice: 199.0,
        description: 'Classic delight with 100% real mozzarella cheese.',
        variants: [
          ProductVariant(name: 'Regular (7")', price: 199.0),
          ProductVariant(name: 'Medium (10")', price: 299.0),
          ProductVariant(name: 'Large (12")', price: 399.0),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemCustomizationSheet(
              item: itemWithVariants,
              onAddToCart: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "Select Size" MUST be shown when variants are present!
      expect(find.text('Select Size'), findsOneWidget);
      expect(find.textContaining('7" (1-2 servings)'), findsOneWidget);
      expect(find.textContaining('10" (2-3 servings)'), findsOneWidget);
    });

    testWidgets('ItemCustomizationSheet renders PosProductMediaBox for product media with auto-playing video', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final itemWithVideo = MenuItemModel(
        id: 'p_vid',
        name: 'Sizzling Brownie',
        category: 'Desserts',
        price: 180.0,
        salePrice: 180.0,
        description: 'Hot brownie topped with vanilla ice cream and melted chocolate.',
        videoUrl: 'https://example.com/brownie.mp4',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemCustomizationSheet(
              item: itemWithVideo,
              onAddToCart: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Slidable mixed-media box must be present and video label removed!
      expect(find.byType(PosProductMediaBox), findsOneWidget);
      expect(find.text('Watch Video'), findsNothing);
    });

    testWidgets('ItemCustomizationSheet and StorefrontCartSheet disable checkout when store is offline', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = MenuItemModel(
        id: 'p1',
        name: 'Paneer Pizza',
        category: 'Pizzas',
        price: 249.0,
        salePrice: 249.0,
        description: 'Fresh spiced paneer pizza with mozzarella.',
      );

      // Offline ItemCustomizationSheet
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemCustomizationSheet(
              item: item,
              isOnline: false,
              onAddToCart: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Store Offline • Orders Paused'), findsOneWidget);

      // Offline StorefrontCartSheet
      final rest = RestaurantModel(
        id: 'pizza-47',
        name: 'Pizza 47',
        tagline: 'Best Pizza',
        phone: '9876543210',
        address: 'Sector 62, Noida',
        cuisineType: 'Pizzas',
        isStorefrontOnline: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorefrontCartSheet(
              cartItems: [StorefrontCartItem(uid: 'c1', item: item, quantity: 1)],
              initialOrderType: OrderType.delivery,
              deliveryAddress: 'Sector 62, Noida',
              restaurant: rest,
              isOnline: false,
              onUpdateQuantity: (_, qty) {},
              onClearCart: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Store is Offline • Ordering Paused'), findsOneWidget);
    });
  });
}
