import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/features/storefront/models/customer_order_status.dart';
import 'package:apna_pos/features/storefront/models/customer_storefront_flow_models.dart';
import 'package:apna_pos/features/storefront/screens/customer_my_orders_screen.dart';
import 'package:apna_pos/features/storefront/services/customer_storefront_api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final restaurant = RestaurantModel(
    id: 'tracking-business',
    slug: 'tracking-cafe',
    name: 'Tracking Cafe',
    tagline: '',
    phone: '',
    address: '',
    cuisineType: '',
  );
  final receipt = CustomerOrderTrackingModel(
    orderId: 'aaaaaaaaaaaaaaaaaaaaaaaa',
    orderNumber: 'QR-001',
    restaurantId: restaurant.id,
    restaurantName: restaurant.name,
    status: 'pending',
    currentStepIndex: 0,
    subtotal: 100,
    tax: 5,
    deliveryFee: 0,
    grandTotal: 105,
    paymentMethod: 'Pay at counter',
    deliveryAddress: 'Table T01',
    items: const [
      CustomerOrderItemSummary(name: 'Pizza', quantity: 1, price: 100),
    ],
    createdAt: DateTime(2026, 11, 20),
  );

  test('tracking status prioritizes terminal decisions over KOT state', () {
    expect(
      CustomerOrderStatus.resolve({'status': 'pending'}),
      CustomerOrderStatus.pending,
    );
    expect(
      CustomerOrderStatus.resolve({
        'status': 'preparing',
        'acceptanceStatus': 'accepted',
      }),
      CustomerOrderStatus.confirmed,
    );
    expect(
      CustomerOrderStatus.resolve({
        'status': 'preparing',
        'acceptanceStatus': 'accepted',
        'kotStatus': 'sent',
      }),
      CustomerOrderStatus.preparing,
    );
    expect(
      CustomerOrderStatus.resolve({'status': 'cancelled', 'kotStatus': 'sent'}),
      CustomerOrderStatus.cancelled,
    );
    expect(
      CustomerOrderStatus.resolve({'status': 'completed', 'kotStatus': 'sent'}),
      CustomerOrderStatus.completed,
    );
    expect(
      receipt.copyWith(status: 'cancelled').timelineSteps.single.title,
      'Cancelled',
    );
  });

  testWidgets(
    'live receipt advances and completed orders move into Completed without losing lines',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      DatabaseService().orders = [];
      final dio = ApiClient().dio;
      final old = List<Interceptor>.of(dio.interceptors);
      var state = <String, dynamic>{'status': 'pending'};
      dio.interceptors
        ..clear()
        ..add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'data': state},
                ),
              );
            },
          ),
        );
      addTearDown(() {
        dio.interceptors
          ..clear()
          ..addAll(old);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerMyOrdersScreen(
            order: receipt,
            restaurant: restaurant,
            tableCode: 'T01',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Awaiting acceptance'), findsWidgets);

      Future<void> change(Map<String, dynamic> update) async {
        state = update;
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      }

      await change({'status': 'preparing', 'acceptanceStatus': 'accepted'});
      expect(find.text('Confirmed'), findsWidgets);
      await change({
        'status': 'preparing',
        'acceptanceStatus': 'accepted',
        'kotStatus': 'printed',
      });
      expect(find.text('Preparing'), findsWidgets);
      await change({'status': 'completed', 'paymentStatus': 'paid'});
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Completed'),
      );
      expect(chip.selected, isTrue);
      expect(find.text('Pizza'), findsOneWidget);
      final history = await CustomerStorefrontApiService().orderHistory(
        restaurant.id,
      );
      expect(history.single.status, 'completed');
      await change({'status': 'pending'});
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Completed'))
            .selected,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'cancelled receipt shows cancellation instead of kitchen progress',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerMyOrdersScreen(
            order: receipt.copyWith(status: 'cancelled', currentStepIndex: 0),
            tableCode: 'T01',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('This order was cancelled. It will not be prepared.'),
        findsOneWidget,
      );
      expect(find.text('Kitchen Preparation Timeline'), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Cancelled'))
            .selected,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
