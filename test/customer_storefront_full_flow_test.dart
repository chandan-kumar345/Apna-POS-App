import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/features/storefront/models/customer_storefront_flow_models.dart';
import 'package:apna_pos/features/storefront/models/storefront_model.dart';
import 'package:apna_pos/features/storefront/screens/customer_storefront_screen.dart';
import 'package:apna_pos/features/storefront/services/customer_storefront_api_service.dart';
import 'package:apna_pos/features/storefront/widgets/storefront_product_detail_sheet.dart';
import 'package:apna_pos/features/storefront/widgets/storefront_checkout_flow_sheet.dart';

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
  );

  final testPizzaItem = MenuItemModel(
    id: 'piz_achari',
    name: 'Achari Paneer Pizza',
    category: 'Pizzas',
    price: 309.0,
    salePrice: 309.0,
    description: 'Paneer, onion, capsicum, and tangy achari seasoning.',
    itemType: 'Veg',
    imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=400&q=80',
    variants: const [
      ProductVariant(name: 'Regular (7")', price: 249.0),
      ProductVariant(name: 'Medium (10")', price: 309.0),
      ProductVariant(name: 'Large (12")', price: 449.0),
    ],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Customer Storefront Flow & API Services Tests', () {
    test('CustomerStorefrontApiService generates and verifies OTP with dynamic profile', () async {
      final service = CustomerStorefrontApiService();
      const phone = '9709593705';

      final otp = await service.sendOtp(phone);
      expect(otp.length, 6);

      // Verify OTP and assert profile creation
      final profile = await service.verifyOtp(phone, otp);
      expect(profile, isNotNull);
      expect(profile!.name, 'Chandan Kumar');
      expect(profile.phone.contains('9709593705'), isTrue);
      expect(profile.addresses.length, greaterThanOrEqualTo(2));
      expect(profile.addresses.first.label, 'Home');
      expect(profile.addresses.last.label, 'Work');

      // Assert local session caching
      final current = await service.getCurrentCustomer();
      expect(current, isNotNull);
      expect(current!.id, profile.id);
    });

    test('CustomerStorefrontApiService places order to DatabaseService and tracks status', () async {
      final service = CustomerStorefrontApiService();
      final customer = CustomerProfileModel(
        id: 'cust_test_1',
        name: 'Chandan Kumar',
        phone: '+91 97095 93705',
        addresses: const [
          CustomerAddressModel(
            id: 'addr_1',
            label: 'Home',
            fullAddress: '34, 34, Chanakya Place, Delhi, Delhi - 110021',
            isDefault: true,
          ),
        ],
      );

      final cartItem = StorefrontCartItem(
        uid: 'cart_1',
        item: testPizzaItem,
        selectedSize: const ProductSizeOption(
          id: 'size_med',
          name: 'Medium',
          description: '10" (2-3 servings)',
          price: 309.0,
        ),
        quantity: 1,
      );

      final order = await service.placeCustomerOrder(
        restaurant: testRestaurant,
        customer: customer,
        selectedAddress: customer.addresses.first,
        cartItems: [cartItem],
        paymentMethod: 'Cash on Delivery',
        subtotal: 309.0,
        deliveryFee: 40.0,
        tax: 28.0,
        grandTotal: 377.0,
      );

      expect(order, isNotNull);
      expect(order!.orderNumber.startsWith('#ORD-'), isTrue);
      expect(order.grandTotal, 377.0);
      expect(order.currentStepIndex, 0);
      expect(order.timelineSteps.length, 4);
      expect(order.timelineSteps[0].title, 'Order Confirmed');
      expect(order.timelineSteps[0].isCompleted, isTrue);

      // Verify POS integration: DatabaseService should contain the new order
      final posOrders = DatabaseService().orders;
      expect(posOrders.any((o) => o.id == order.orderId || o.orderNumber == order.orderNumber), isTrue);
    });
  });

  group('Customer 10-Step UI Widget Flow Tests', () {
    testWidgets('Step 1: CustomerStorefrontScreen renders neumorphic base, header, and categories', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: CustomerStorefrontScreen(slug: 'preview', isPreviewMode: true),
          ),
        );

        // Allow initial loading
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Assert screen structure
        expect(find.byType(CustomerStorefrontScreen), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
      });
    });

    testWidgets('Step 2: StorefrontProductDetailSheet renders hero, bestseller badge, sizes, addons and add-to-cart', (tester) async {
      StorefrontCartItem? addedCartItem;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorefrontProductDetailSheet(
              item: testPizzaItem,
              themeColor: const Color(0xFFE65100),
              onAddToCart: (item, {bool openCartImmediately = false}) {
                addedCartItem = item;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert Bestseller badge
      expect(find.text('Bestseller'), findsWidgets);

      // Assert Title & Description
      expect(find.text('Achari Paneer Pizza'), findsOneWidget);
      expect(find.text('Paneer, onion, capsicum, and tangy achari seasoning.'), findsOneWidget);

      // Assert Sizes (Regular, Medium, Large)
      expect(find.text('Select Size'), findsOneWidget);
      expect(find.text('Regular'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Large'), findsOneWidget);

      // Assert Addons
      expect(find.text('Add Ons (Optional)'), findsOneWidget);
      expect(find.text('Extra Cheese'), findsOneWidget);
      expect(find.text('Extra Paneer'), findsOneWidget);

      // Assert Special instructions
      expect(find.text('Add special instructions (optional)'), findsOneWidget);

      // Assert Add to Cart Button
      expect(find.textContaining('Add to Cart'), findsOneWidget);

      // Tap Add to Cart
      await tester.tap(find.textContaining('Add to Cart'));
      await tester.pumpAndSettle();
      expect(addedCartItem, isNotNull);
      expect(addedCartItem!.item.name, 'Achari Paneer Pizza');
    });

    testWidgets('Step 3: StorefrontCheckoutFlowSheet renders Cart View with Bill Details and Cross-sells', (tester) async {
      final cartItem = StorefrontCartItem(
        uid: 'cart_test_1',
        item: testPizzaItem,
        selectedSize: const ProductSizeOption(
          id: 'size_med',
          name: 'Medium',
          description: '10" (2-3 servings)',
          price: 309.0,
        ),
        quantity: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorefrontCheckoutFlowSheet(
              restaurant: testRestaurant,
              cartItems: [cartItem],
              allMenuItems: [testPizzaItem],
              initialStep: 3,
              themeColor: const Color(0xFFE65100),
              onUpdateQuantity: (i, q) {},
              onAddCrossSellItem: (i) {},
              onClearCart: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert Cart Header
      expect(find.text('Your Cart'), findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);
      expect(find.text('Clear All'), findsOneWidget);

      // Assert Item Card
      expect(find.text('Achari Paneer Pizza'), findsOneWidget);
      expect(find.text('Medium (10" (2-3 servings))'), findsOneWidget);

      // Assert Apply Coupon
      expect(find.text('Apply Coupon'), findsOneWidget);

      // Assert Bill Details Breakdown
      expect(find.text('Bill Details'), findsOneWidget);
      expect(find.text('Item Total'), findsOneWidget);
      expect(find.text('Delivery Charge'), findsOneWidget);
      expect(find.text('Taxes & Charges (GST)'), findsOneWidget);
      expect(find.text('Grand Total'), findsOneWidget);

      // Assert Proceed to Checkout CTA
      expect(find.text('Proceed to Checkout'), findsOneWidget);

      // Assert You may also like cross-sell
      expect(find.text('You may also like'), findsOneWidget);
    });

    testWidgets('Steps 4-7: Auth gate, Mobile entry, OTP verification, and Welcome Profile transitions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorefrontCheckoutFlowSheet(
              restaurant: testRestaurant,
              cartItems: [
                StorefrontCartItem(uid: 'c1', item: testPizzaItem, quantity: 1)
              ],
              allMenuItems: [testPizzaItem],
              initialStep: 4, // Step 4 Auth Gate
              themeColor: const Color(0xFFE65100),
              onUpdateQuantity: (i, q) {},
              onAddCrossSellItem: (i) {},
              onClearCart: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // --- STEP 4 ASSERTIONS ---
      expect(find.text('Login to Continue'), findsOneWidget);
      expect(find.text('Save your delivery addresses'), findsOneWidget);
      expect(find.text('Track your orders in real-time'), findsOneWidget);
      expect(find.text('Get exclusive offers & rewards'), findsOneWidget);
      expect(find.text('Login with Mobile Number'), findsOneWidget);

      // Tap Login with Mobile Number -> Advance to Step 5
      await tester.tap(find.text('Login with Mobile Number'));
      await tester.pumpAndSettle();

      // --- STEP 5 ASSERTIONS ---
      expect(find.text('Enter Your Mobile Number'), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      expect(find.text('Send OTP'), findsOneWidget);

      // Tap Send OTP -> Advance to Step 6
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();

      // --- STEP 6 ASSERTIONS ---
      expect(find.text('Enter Verification Code'), findsOneWidget);
      expect(find.text('Verify & Login'), findsOneWidget);

      // Enter 6-digit OTP (e.g. 1, 2, 3, 4, 5, 6)
      final textFields = find.byType(TextField);
      for (int i = 0; i < 6 && i < textFields.evaluate().length; i++) {
        await tester.enterText(textFields.at(i), '${i + 1}');
      }
      await tester.pumpAndSettle();

      // Tap Verify & Login -> Advance to Step 7
      await tester.tap(find.text('Verify & Login'));
      await tester.pumpAndSettle();

      // --- STEP 7 ASSERTIONS ---
      expect(find.textContaining('Welcome to Pizza 47!'), findsOneWidget);
      expect(find.text('Chandan Kumar'), findsOneWidget);
      expect(find.text('Continue to Order'), findsOneWidget);
    });

    testWidgets('Steps 8-10: Delivery Details, Payment Method, and Order Confirmation & Live Tracking', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorefrontCheckoutFlowSheet(
              restaurant: testRestaurant,
              cartItems: [
                StorefrontCartItem(uid: 'c1', item: testPizzaItem, quantity: 1)
              ],
              allMenuItems: [testPizzaItem],
              initialStep: 8, // Step 8 Delivery Details
              themeColor: const Color(0xFFE65100),
              onUpdateQuantity: (i, q) {},
              onAddCrossSellItem: (i) {},
              onClearCart: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // --- STEP 8 ASSERTIONS ---
      expect(find.text('Delivery Details'), findsOneWidget);
      expect(find.text('Saved Addresses'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('+ Add New Address'), findsOneWidget);
      expect(find.text('Continue to Payment'), findsOneWidget);

      // Tap Continue to Payment -> Advance to Step 9
      await tester.ensureVisible(find.text('Continue to Payment'));
      await tester.tap(find.text('Continue to Payment'));
      await tester.pumpAndSettle();

      // --- STEP 9 ASSERTIONS ---
      expect(find.text('Select Payment Method'), findsOneWidget);
      expect(find.text('Cash on Delivery'), findsOneWidget);
      expect(find.text('UPI (Google Pay, PhonePe, etc.)'), findsOneWidget);
      expect(find.text('Credit / Debit Card'), findsOneWidget);
      expect(find.text('Wallets'), findsOneWidget);
      expect(find.text('Bill Summary'), findsOneWidget);
      expect(find.textContaining('Place Order'), findsOneWidget);

      // Tap Place Order -> Advance to Step 10
      await tester.ensureVisible(find.textContaining('Place Order'));
      await tester.tap(find.textContaining('Place Order'));
      await tester.pumpAndSettle();

      // --- STEP 10 ASSERTIONS ---
      expect(find.text('Order Placed Successfully! 🎉'), findsOneWidget);
      expect(find.textContaining('Order #ORD-'), findsOneWidget);
      expect(find.text('Estimated Delivery'), findsOneWidget);
      expect(find.text('25 - 35 mins'), findsOneWidget);
      expect(find.text('Order Confirmed'), findsOneWidget);
      expect(find.text('Preparing Your Food'), findsOneWidget);
      expect(find.text('Out for Delivery'), findsOneWidget);
      expect(find.text('Delivered'), findsOneWidget);
      expect(find.text('View Order Details'), findsOneWidget);
      expect(find.text('Back to Home'), findsOneWidget);
    });
  });
}
