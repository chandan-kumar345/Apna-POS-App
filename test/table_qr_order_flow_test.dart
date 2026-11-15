import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/features/storefront/models/storefront_model.dart';
import 'package:apna_pos/features/storefront/models/table_qr_bill.dart';
import 'package:apna_pos/features/storefront/screens/table_qr_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/storefront_order_adapter.dart';

void main() {
  final restaurant = RestaurantModel(
    id: StorefrontOrderAdapter.businessId,
    slug: 'pizza-47',
    name: 'Pizza 47',
    tagline: '',
    phone: '',
    address: '',
    cuisineType: 'Restaurant',
  );
  final pizza = MenuItemModel(
    id: 'pizza',
    name: 'Special Loaded Pizza',
    category: 'Pizza',
    price: 399,
    description: 'House-special pizza with vegetables and mozzarella.',
  );
  final side = MenuItemModel(
    id: 'side',
    name: 'Garlic Bread',
    category: 'Sides',
    price: 149,
    description: 'Oven-baked garlic bread.',
    itemType: 'Non-Veg',
  );

  Future<void> open(
    WidgetTester tester, {
    bool valid = true,
    bool preview = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: TableQrOrderScreen(
          data: StorefrontData(
            restaurant: restaurant,
            menuItems: [pizza, side],
            categories: const ['All', 'Pizza', 'Sides'],
            addOns: const [],
            banners: const [],
            isOnline: true,
            themeColorHex: 0xFF064CF5,
            tableInfo: StorefrontTableInfo(
              isValid: valid,
              tableCode: 'T01',
              isTableOrdering: true,
            ),
          ),
          tableCode: 'T01',
          preview: preview,
          onRefresh: () async {},
          avatar: (_, _, size) => SizedBox(
            width: size,
            height: size,
            child: const Icon(Icons.local_pizza),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'table bill rounds to paise and does not charge tax for a non-GST outlet',
    () {
      final lines = [
        StorefrontCartItem(uid: '1', item: pizza),
        StorefrontCartItem(uid: '2', item: side),
      ];
      final bill = TableQrBill.calculate(lines, restaurant);
      expect((bill.subtotal, bill.tax, bill.total), (548, 27.4, 575.4));
      final nonGst = TableQrBill.calculate(
        lines,
        restaurant.copyWith(billingType: 'Non-GST'),
      );
      expect((nonGst.tax, nonGst.total), (0, 548));
    },
  );

  testWidgets(
    'QR home, filters, cart, OTP validation and guest order share one table and bill',
    (tester) async {
      final dio = ApiClient().dio;
      final original = dio.httpClientAdapter;
      final interceptors = List.of(dio.interceptors);
      final api = StorefrontOrderAdapter();
      dio.interceptors.clear();
      dio.httpClientAdapter = api;
      addTearDown(() {
        dio.httpClientAdapter = original;
        dio.interceptors.addAll(interceptors);
      });
      await open(tester);
      expect(find.text('Welcome to Table T01'), findsOneWidget);
      await tap(tester, find.text('Explore menu'));
      expect(find.text('Our menu'), findsOneWidget);
      await tap(tester, find.byType(Switch));
      expect(find.text(side.name), findsNothing);
      await tap(tester, find.byType(Switch));
      await tester.enterText(find.byType(TextField), 'garlic');
      await tester.pumpAndSettle();
      expect(find.text(pizza.name), findsNothing);
      await tap(tester, find.text('+ ADD'));
      await tester.enterText(find.byType(TextField), 'loaded');
      await tester.pumpAndSettle();
      await tap(tester, find.text('+ ADD'));
      await tap(tester, find.text('View cart'));
      expect(find.text('Table T01 • Dine-in'), findsOneWidget);
      expect(find.text('₹27.40'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Less spicy');
      await tap(tester, find.text('Place order • ₹575.40'));
      expect(find.text('Welcome to Pizza 47'), findsOneWidget);
      await tap(tester, find.text('Send OTP'));
      expect(
        find.text('Enter a valid 10-digit Indian mobile number.'),
        findsOneWidget,
      );
      expect(api.requests, isEmpty);
      await tap(tester, find.text('Continue as guest'));
      expect(api.requests, hasLength(1));
      final order = api.requests.single;
      expect(order, containsPair('tableNumber', 'T01'));
      expect(order, containsPair('orderType', 'dineIn'));
      expect(order, containsPair('subtotal', 548.0));
      expect(order, containsPair('taxAmount', 27.40));
      expect(order, containsPair('totalAmount', 575.40));
      expect(order, containsPair('deliveryCharge', 0));
      expect(order, containsPair('notes', 'Less spicy'));
      expect(order, containsPair('paymentMethod', 'Pay at Counter / Table'));
      expect(order, containsPair('customerPhone', ''));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('an invalid QR can browse but cannot add food', (tester) async {
    await open(tester, valid: false);
    expect(find.text('Check your table QR'), findsOneWidget);
    await tap(tester, find.text('Explore menu'));
    expect(find.text('Scan a valid table QR to order.'), findsOneWidget);
    final add = tester.widgetList<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '+ ADD'),
    );
    expect(add, isNotEmpty);
    expect(add.every((button) => button.onPressed == null), isTrue);
    expect(find.text('View cart'), findsNothing);
  });
}
