import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/features/storefront/models/storefront_model.dart';
import 'package:apna_pos/features/storefront/models/table_qr_bill.dart';
import 'package:apna_pos/features/storefront/screens/table_qr_order_screen.dart';
import 'package:apna_pos/features/storefront/widgets/storefront_product_detail_sheet.dart';
import 'package:apna_pos/core/models/extra_model.dart';
import 'package:apna_pos/core/services/socket_service.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/storefront_order_adapter.dart';
import 'support/storefront_customer_auth_adapter.dart';

void main() {
  final captureKey = GlobalKey();
  Future<void> capture(WidgetTester tester, String name) async {
    final directory = Platform.environment['STOREFRONT_CAPTURE_DIR'];
    if (directory == null) return;
    await tester.runAsync(() async {
      final boundary =
          captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final rendered = await boundary.toImage(pixelRatio: 1);
      final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
      Directory(directory).createSync(recursive: true);
      File('$directory/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      rendered.dispose();
    });
  }

  setUpAll(() async {
    final fontPath = Platform.environment['STOREFRONT_FONT'];
    if (fontPath != null) {
      final font = FontLoader('Roboto')
        ..addFont(
          Future.value(ByteData.sublistView(File(fontPath).readAsBytesSync())),
        );
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '${File(fontPath).parent.path}/materialicons-regular.otf',
              ).readAsBytesSync(),
            ),
          ),
        );
      await icons.load();
    }
  });
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
    List<MenuItemModel>? products,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Roboto'),
          home: TableQrOrderScreen(
            data: StorefrontData(
              restaurant: restaurant,
              menuItems: products ?? [pizza, side],
              categories: const ['All', 'Pizza', 'Sides'],
              addOns: [
                ExtraModel(
                  id: 'cheese',
                  name: 'Cheese',
                  price: 20,
                  type: 'addon',
                ),
              ],
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

  testWidgets(
    'WhatsApp login opens OTP/name sheet; wrong code stays and blank name defaults',
    (tester) async {
      final dio = ApiClient().dio;
      final old = dio.httpClientAdapter;
      final oldInterceptors = List.of(dio.interceptors);
      dio.interceptors.clear();
      final authApi = StorefrontCustomerAuthAdapter();
      dio.httpClientAdapter = authApi;
      addTearDown(() {
        dio.httpClientAdapter = old;
        dio.interceptors.addAll(oldInterceptors);
      });
      await open(tester);
      await tap(tester, find.text('Account'));
      await capture(tester, 'whatsapp-login');
      await tester.enterText(
        find.byKey(const ValueKey('table-phone')),
        '9876543210',
      );
      await tap(tester, find.text('Send OTP'));
      expect(find.text('Verify your number'), findsOneWidget);
      expect(find.byKey(const ValueKey('table-customer-name')), findsOneWidget);
      await capture(tester, 'whatsapp-otp');
      await tester.enterText(find.byKey(const ValueKey('table-otp')), '111111');
      await tap(tester, find.text('Continue'));
      expect(find.text('Code is incorrect or expired.'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('table-otp')), '654321');
      await tap(tester, find.text('Continue'));
      expect(find.text('Verify your number'), findsNothing);
      expect(authApi.requests, isEmpty);
      await tap(tester, find.text('Account'));
      expect(find.textContaining('Valued Customer'), findsOneWidget);
      expect(find.text('My orders'), findsOneWidget);
    },
  );

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
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        Theme.of(
          tester.element(find.byKey(const ValueKey('qr-guest-name'))),
        ).brightness,
        Brightness.light,
      );
      await capture(tester, 'guest-details');
      expect(api.requests, isEmpty);
      await tap(tester, find.text('Continue'));
      expect(find.text('Enter your name'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('qr-guest-name')),
        'Aman',
      );
      await tester.enterText(
        find.byKey(const ValueKey('qr-guest-phone')),
        '9876543210',
      );
      await tap(tester, find.text('Continue'));
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
      expect(order, containsPair('customerPhone', '9876543210'));
      expect(order, containsPair('customerName', 'Aman'));
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString('qr_guest_${restaurant.id}')!)['name'],
        'Aman',
      );
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

  testWidgets(
    'product tap opens details and ADD skips customization without variants',
    (tester) async {
      await open(tester);
      await tap(tester, find.text('Explore menu'));
      await tap(tester, find.text(pizza.name));
      expect(find.byType(StorefrontProductDetailSheet), findsOneWidget);
      await capture(tester, 'product-details');
      final sheet = tester.getSize(find.byType(StorefrontProductDetailSheet));
      expect(
        sheet.height,
        closeTo(
          tester.view.physicalSize.height / tester.view.devicePixelRatio * 0.6,
          1,
        ),
      );
      Navigator.of(
        tester.element(find.byType(StorefrontProductDetailSheet)),
      ).pop();
      await tester.pumpAndSettle();
      await tap(tester, find.text('+ ADD').first);
      expect(find.byType(StorefrontProductDetailSheet), findsNothing);
      expect(find.text('View cart'), findsOneWidget);
      final button = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Back',
        ),
      );
      expect(button.style, isNotNull);
    },
  );

  testWidgets(
    'popular picks includes ten products and search keyboard keeps menu size',
    (tester) async {
      await open(
        tester,
        products: List.generate(
          12,
          (i) => MenuItemModel(
            id: 'pick-$i',
            name: 'Pick ${i + 1}',
            description: '',
            category: 'Pizza',
            price: 100,
          ),
        ),
      );
      expect(find.text('Pick 10'), findsOneWidget);
      expect(find.text('Pick 11'), findsNothing);
      await tap(tester, find.text('Explore menu'));
      final before = tester.getSize(find.byType(Scaffold).first);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getSize(find.byType(Scaffold).first), before);
    },
  );

  testWidgets(
    'a returning guest is restored without a login or details popup',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'qr_guest_${restaurant.id}',
        jsonEncode({'id': 'guest', 'name': 'Aman', 'phone': '9876543210'}),
      );
      await open(tester);
      await tap(tester, find.text('Account'));
      expect(find.text('Aman • 9876543210'), findsOneWidget);
      expect(find.text('Send OTP'), findsNothing);
      expect(find.text('Your details'), findsNothing);
    },
  );

  test(
    'remote decisions are remembered even before an alert is showing',
    () async {
      await Future.wait([
        SocketService.recordHandledOrder('remote-1', 'ORD-1'),
        SocketService.recordHandledOrder('remote-2', 'ORD-2'),
      ]);
      expect(DatabaseService.isOrderDismissed('remote-1'), isTrue);
      expect(DatabaseService.isOrderDismissed('remote-2'), isTrue);
      final prefs = await SharedPreferences.getInstance();
      final keys =
          jsonDecode(prefs.getString('apna_handled_order_keys')!) as Map;
      expect(
        keys.keys,
        containsAll(['remote-1', 'remote-2', 'ORD-1', 'ORD-2']),
      );
    },
  );
}
