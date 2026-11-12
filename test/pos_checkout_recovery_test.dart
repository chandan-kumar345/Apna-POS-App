import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/models/user_model.dart';
import 'package:apna_pos/core/services/network_service.dart';
import 'package:apna_pos/core/services/socket_service.dart';
import 'package:apna_pos/features/pos/payment_modal.dart';
import 'package:apna_pos/features/pos/pos_register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseService();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await db.init();
    db.menuItems.clear();
    db.categories.clear();
    db.orders.clear();
    db.currentUser = UserModel(
      id: 'checkout-owner', name: 'Owner', email: 'checkout@example.test',
      phone: '', role: 'Owner', pin: '', restaurantId: 'checkout-business',
    );
    db.restaurant = RestaurantModel(
      id: 'checkout-business', name: 'Checkout Cafe', tagline: '', phone: '',
      address: '', cuisineType: 'Cafe', currencySymbol: '\u20b9',
      billingType: 'Non-GST', posViewMode: 'with_image',
    );
    db.categories.add('Drinks');
    db.menuItems.add(MenuItemModel(
      id: 'checkout-tea', productId: 'checkout-tea', name: 'Test Tea',
      description: '', price: 25, category: 'Drinks',
    ));
  });

  tearDown(() {
    db.stopAutoSync();
    SocketService().disconnect();
    NetworkService().dispose();
  });

  testWidgets('desktop checkout stays usable after cancellation during database sync', (tester) async {
    tester.view.physicalSize = const Size(2400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: PosRegisterScreen(initialOrderType: OrderType.takeaway),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Test Tea'));
    await tester.pump(const Duration(milliseconds: 400));

    final paymentButton = find.ancestor(
      of: find.textContaining('Proceed payment', skipOffstage: false),
      matching: find.byType(ElevatedButton, skipOffstage: false),
    );
    expect(tester.widget<ElevatedButton>(paymentButton).onPressed, isNotNull);
    await tester.tap(paymentButton);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PaymentModal), findsOneWidget);

    // Incoming order/table updates rebuild the POS while payment is still open.
    db.setLiveCartTotal('unrelated-table-update', 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<ElevatedButton>(paymentButton).onPressed, isNull);
    Navigator.of(tester.element(find.byType(PaymentModal))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(PaymentModal), findsNothing);
    expect(tester.widget<ElevatedButton>(paymentButton).onPressed, isNotNull);
    await tester.tap(paymentButton);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PaymentModal), findsOneWidget);
    Navigator.of(tester.element(find.byType(PaymentModal))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
