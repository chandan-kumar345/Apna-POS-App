import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/core/models/order_model.dart';
import 'package:apna_pos/core/models/table_model.dart';
import 'package:apna_pos/core/services/chotu_service.dart';
import 'package:apna_pos/core/network/api_client.dart';
import 'package:apna_pos/core/network/api_endpoints.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';

class HealthOriginAdapter implements HttpClientAdapter {
  var posts = 0;
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (options.method == 'POST') posts++;
    await ApiEndpoints.setCustomBaseUrl('https://discovered.invalid/api/v1');
    return ResponseBody.fromString(
      '{"data":{"automationAgent":{"enabled":true}}}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseService();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db.orders = [];
    db.tables = [];
  });

  test(
    'origin changed by health discovery cannot receive this pending order',
    () async {
      final dio = ApiClient().dio;
      final priorAdapter = dio.httpClientAdapter;
      final priorInterceptors = List<Interceptor>.from(dio.interceptors);
      final priorOrigin = ApiEndpoints.baseUrl;
      final adapter = HealthOriginAdapter();
      dio.interceptors.clear();
      dio.httpClientAdapter = adapter;
      try {
        await ApiEndpoints.setCustomBaseUrl(
          'https://before-health.invalid/api/v1',
        );
        final result = await ChotuService().processAutomationTurn(
          speechText: 'Table 5 pe ek naan',
        );
        expect(result?['status'], 'unconfirmed');
        expect(adapter.posts, 0);
      } finally {
        dio.httpClientAdapter = priorAdapter;
        dio.interceptors.addAll(priorInterceptors);
        await ApiEndpoints.setCustomBaseUrl(priorOrigin);
      }
    },
  );

  Map<String, dynamic> snapshot({bool paid = false}) => {
    'stage': paid ? 'completed' : 'kitchen',
    'tableNumber': 'T-5',
    'table': {
      'id': 'table-5',
      'name': 'T-5',
      'tableNumber': 5,
      'status': paid ? 'free' : 'runningKot',
    },
    'cart': {
      'items': paid
          ? []
          : [
              {
                'productId': 'product-1',
                'name': 'Butter Naan',
                'price': 40,
                'effectivePrice': 40,
                'quantity': 2,
                'kotQuantity': 2,
              },
            ],
    },
    'order': {
      'id': 'order-1',
      'orderNumber': 'ORD-1',
      'tableNumber': 'T-5',
      'orderType': 'dineIn',
      'status': paid ? 'completed' : 'preparing',
      'paymentStatus': paid ? 'paid' : 'pending',
      'isPaid': paid,
      'kotStatus': 'sent',
      'subtotal': 80,
      'taxAmount': 4,
      'totalAmount': 84,
      'createdAt': '2026-11-12T12:00:00.000Z',
      'items': [
        {
          'productId': 'product-1',
          'name': 'Butter Naan',
          'price': 40,
          'quantity': 2,
          'kotQuantity': 2,
        },
      ],
    },
  };

  test(
    'installs kitchen snapshot as already synced with sent KOT quantities',
    () async {
      await db.applyChotuAutomationSnapshot(snapshot());
      expect(db.tables.single.status, TableStatus.runningKot);
      expect(db.getLiveTableCart('T-5').single.quantity, 2);
      expect(db.getLiveTableCart('T-5').single.kotQuantity, 2);
      expect(db.orders.single.isSynced, true);
      expect(db.orders.single.items.single.pendingKotQuantity, 0);
      await db.applyChotuAutomationSnapshot(snapshot());
      expect(db.orders, hasLength(1));
      expect(db.getLiveTableCart('T-5').single.quantity, 2);
    },
  );

  test(
    'settlement snapshot clears cached cart and replaces the same order',
    () async {
      await db.applyChotuAutomationSnapshot(snapshot());
      await db.applyChotuAutomationSnapshot(snapshot(paid: true));
      expect(db.tables.single.status, TableStatus.free);
      expect(db.orders, hasLength(1));
      expect(db.orders.single.status, OrderStatus.completed);
      expect(db.orders.single.isPaid, true);
      expect(db.getLiveTableCart('T-5'), isEmpty);
    },
  );

  test(
    'new draft additions remain visible over the older kitchen order',
    () async {
      final updated = snapshot();
      (updated['cart'] as Map)['items'] = [
        {
          'productId': 'product-1',
          'name': 'Butter Naan',
          'price': 40,
          'effectivePrice': 40,
          'quantity': 3,
          'kotQuantity': 2,
        },
      ];
      await db.applyChotuAutomationSnapshot(updated);
      expect(db.orders.single.items.single.quantity, 2);
      expect(db.getChotuDraftCart('T-5').single.quantity, 3);
      expect(db.getChotuDraftCart('T-5').single.pendingKotQuantity, 1);
      expect(db.getLiveTableCart('T-5').single.quantity, 3);
      db.orders[0] = db.orders.single.copyWith(status: OrderStatus.ready);
      expect(db.getLiveTableCart('T-5').single.quantity, 3);
    },
  );

  test(
    'resolved zero and twelve percent product tax survive cart installation',
    () async {
      final data = snapshot();
      (data['cart'] as Map)['items'] = [
        {
          'productId': 'p0',
          'name': 'Tax Free',
          'price': 100,
          'effectivePrice': 100,
          'quantity': 1,
          'gstPercent': 0,
        },
        {
          'productId': 'p12',
          'name': 'Taxed',
          'price': 100,
          'effectivePrice': 100,
          'quantity': 1,
          'gstPercent': 12,
        },
      ];
      await db.applyChotuAutomationSnapshot(data);
      final items = db.getLiveTableCart('T-5');
      expect(items[0].effectiveGstRate, 0);
      expect(items[1].effectiveGstRate, 12);
    },
  );
}
