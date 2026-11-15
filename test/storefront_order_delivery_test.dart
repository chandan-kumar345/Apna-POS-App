import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/incoming_order_alert.dart';
import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/models/restaurant_model.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/features/storefront/models/customer_storefront_flow_models.dart';
import 'package:apna_pos/features/storefront/models/storefront_model.dart';
import 'package:apna_pos/features/storefront/services/customer_storefront_api_service.dart';
import 'package:apna_pos/features/storefront/services/storefront_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/storefront_order_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dio = ApiClient().dio;
  final db = DatabaseService();
  late HttpClientAdapter original;
  late List<Interceptor> interceptors;
  late StorefrontOrderAdapter adapter;
  final restaurant = RestaurantModel(
    id: StorefrontOrderAdapter.businessId,
    name: 'Test Cafe',
    slug: 'test-cafe',
    tagline: '',
    phone: '',
    address: '',
    cuisineType: 'Cafe',
  );
  final product = MenuItemModel(
    id: 'pizza',
    name: 'Pizza',
    category: 'Pizza',
    price: 379,
    description: '',
    variants: const [
      ProductVariant(name: 'Regular', price: 379),
      ProductVariant(name: 'Medium', price: 479),
    ],
  );
  final line = StorefrontCartItem(
    uid: 'line',
    item: product,
    quantity: 2,
    selectedSize: const ProductSizeOption(
      id: 'medium',
      name: 'Medium',
      description: '',
      price: 479,
    ),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = dio.httpClientAdapter;
    interceptors = List<Interceptor>.from(dio.interceptors);
    dio.interceptors.clear();
    adapter = StorefrontOrderAdapter();
    dio.httpClientAdapter = adapter;
    db.orders = [];
    db.currentUser = null;
    db.restaurant = restaurant;
  });
  tearDown(() {
    dio.httpClientAdapter = original;
    dio.interceptors.addAll(interceptors);
  });

  for (final type in [
    OrderType.dineIn,
    OrderType.delivery,
    OrderType.takeaway,
  ]) {
    test(
      'legacy checkout sends $type to the merchant with correct item prices',
      () async {
        final success = await StorefrontService().submitOrder(
          restaurant: restaurant,
          orderType: type,
          cartItems: [line],
          customerName: 'Guest',
          customerPhone: '919999999999',
          deliveryAddress: 'Test street',
          subtotal: 958,
          taxAmount: 0,
          deliveryFee: 0,
          totalAmount: 958,
          paymentMethod: 'UPI',
          tableNumber: type == OrderType.dineIn ? 'T02' : null,
        );
        expect(success, isTrue);
        final payload = adapter.requests.single;
        expect(payload['orderType'], type.name);
        expect(payload['items'][0], containsPair('price', 479.0));
        expect(payload['items'][0]['name'], contains('Medium'));
        final saved = db.orders.single;
        expect(saved.id, StorefrontOrderAdapter.orderId);
        expect(saved.status, OrderStatus.pending);
        expect(saved.isSynced, isTrue);
        expect(
          IncomingOrderAlert({
            'type': 'whatsapp_order_request',
            ...saved.toJson(),
            'orderId': saved.id,
          }).isIncoming,
          isTrue,
        );
      },
    );
  }

  for (final type in [
    OrderType.dineIn,
    OrderType.delivery,
    OrderType.takeaway,
  ]) {
    test(
      'customer checkout retains $type and the server receipt for tracking',
      () async {
        final customer = CustomerProfileModel(
          id: 'guest',
          name: 'Guest',
          phone: '919999999999',
          addresses: const [],
        );
        final result = await CustomerStorefrontApiService().placeCustomerOrder(
          restaurant: restaurant,
          customer: customer,
          selectedAddress: const CustomerAddressModel(
            id: 'address',
            label: 'Home',
            fullAddress: 'Test street',
          ),
          cartItems: [line],
          paymentMethod: 'UPI',
          subtotal: 958,
          deliveryFee: 0,
          tax: 0,
          grandTotal: 958,
          orderType: type,
          tableNumber: type == OrderType.dineIn ? 'T02' : null,
        );
        expect(result?.orderId, StorefrontOrderAdapter.orderId);
        expect(result?.status, 'pending');
        expect(adapter.requests.single['orderType'], type.name);
        expect(db.orders.single.items.single.item.effectivePrice, 479);
      },
    );
  }

  test(
    'uncertain delivery retries use the same server request identity',
    () async {
      Future<bool> send() => StorefrontService().submitOrder(
        restaurant: restaurant,
        orderType: OrderType.takeaway,
        cartItems: [line],
        customerName: 'Guest',
        customerPhone: '919999999999',
        deliveryAddress: '',
        subtotal: 958,
        taxAmount: 0,
        deliveryFee: 0,
        totalAmount: 958,
        paymentMethod: 'Cash',
      );
      adapter.statusCode = 500;
      expect(await send(), isFalse);
      adapter.statusCode = 201;
      expect(await send(), isTrue);
      expect(
        adapter.requests[1]['idempotencyKey'],
        adapter.requests[0]['idempotencyKey'],
      );
      expect(
        adapter.requests[1]['orderNumber'],
        adapter.requests[0]['orderNumber'],
      );
      expect(db.orders, hasLength(1));
    },
  );

  test(
    'server rejection keeps the cart and creates no customer success receipt',
    () async {
      adapter.statusCode = 400;
      final success = await StorefrontService().submitOrder(
        restaurant: restaurant,
        orderType: OrderType.takeaway,
        cartItems: [line],
        customerName: 'Guest',
        customerPhone: '919999999999',
        deliveryAddress: '',
        subtotal: 958,
        taxAmount: 0,
        deliveryFee: 0,
        totalAmount: 958,
        paymentMethod: 'Cash',
      );
      expect(success, isFalse);
      expect(db.orders, isEmpty);
    },
  );
}
