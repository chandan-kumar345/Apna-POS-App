import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/features/storefront/models/customer_storefront_flow_models.dart';
import 'package:apna_pos/features/storefront/screens/customer_my_orders_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testRestaurant = RestaurantModel(
    id: 'rest_test_47',
    name: 'Pizza 47',
    companyName: 'Pizza 47 Inc',
    slug: 'pizza-47',
    tagline: 'Fresh Ingredients Bigger Happiness',
    address: 'Sector 62, Noida',
    phone: '+919709593705',
    cuisineType: 'Pizzas & Fast Food',
    taxRate: 5.0,
    deliveryBaseCharge: 40.0,
    isStorefrontOnline: true,
    likesCount: 1248,
  );

  final testOrder = CustomerOrderTrackingModel(
    orderId: 'ord_test_table_001',
    orderNumber: '#ORD-261109-1234',
    restaurantId: 'rest_test_47',
    restaurantName: 'Pizza 47',
    status: 'confirmed',
    currentStepIndex: 1, // Cooking in Kitchen
    estimatedDeliveryMinutes: '15 - 20 mins',
    items: const [
      CustomerOrderItemSummary(
        name: 'Achari Paneer Pizza',
        size: 'Medium (10")',
        quantity: 2,
        price: 309.0,
        addons: ['Extra Cheese'],
        instructions: 'Crispy crust please',
      ),
    ],
    subtotal: 618.0,
    deliveryFee: 0.0,
    tax: 30.9,
    discount: 50.0,
    grandTotal: 598.9,
    paymentMethod: 'Cash on Table',
    paymentStatus: 'Pending',
    deliveryAddress: 'Table T03',
    deliveryInstructions: 'Serve extra oregano packets',
    createdAt: DateTime(2026, 11, 9, 21, 30),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Table Ordering Flow & My Orders Screen Tests', () {
    testWidgets('CustomerMyOrdersScreen displays table number, status, items and bill', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerMyOrdersScreen(
            order: testOrder,
            restaurant: testRestaurant,
            tableCode: 'T03',
            themeColor: const Color(0xFF065F46),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert Header & Order Number
      expect(find.text('My Orders'), findsOneWidget);
      expect(find.text('#ORD-261109-1234'), findsOneWidget);

      // Assert Table Badges
      expect(find.textContaining('T03'), findsWidgets);

      // Assert Status is 'Cooking in Kitchen'
      expect(find.text('Cooking in Kitchen'), findsWidgets);

      // Assert Item breakdown
      expect(find.text('Achari Paneer Pizza'), findsOneWidget);
      expect(find.text('Qty: 2'), findsOneWidget);
      expect(find.text('Add-ons: Extra Cheese'), findsOneWidget);

      // Assert Bill Breakdown
      expect(find.text('Bill Summary'), findsOneWidget);
      expect(find.text('Dining Table Service'), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('Order More Items'), findsOneWidget);
    });

    test('MenuItemModel has rating and ratingsCount defaults', () {
      final item = MenuItemModel(
        id: 'item_1',
        name: 'Margherita Pizza',
        category: 'Pizzas',
        price: 199.0,
      );

      expect(item.rating, 4.8);
      expect(item.ratingsCount, 85);
    });

    test('RestaurantModel has likesCount default and serialization', () {
      final rest = RestaurantModel(
        id: 'r_1',
        name: 'Pizza 47',
        companyName: 'Pizza 47 LLC',
        likesCount: 1520,
      );

      expect(rest.likesCount, 1520);
      final json = rest.toJson();
      expect(json['likesCount'], 1520);

      final fromJson = RestaurantModel.fromJson(json);
      expect(fromJson.likesCount, 1520);
    });
  });
}
