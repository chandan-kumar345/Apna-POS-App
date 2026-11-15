import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_pos/core/models/incoming_order_payload.dart';
import 'package:apna_pos/core/models/order_model.dart';

void main() {
  test('stored order parsing retains QR codes and ignores street-name table guesses', () {
    final base = {'id': 'qr-order', 'orderNumber': 'ORD-1', 'items': [], 'totalAmount': 100, 'createdAt': '2026-11-15T13:02:00Z'};
    final table = OrderModel.fromJson({...base, 'orderType': 'dineIn', 'tableNumber': '', 'tableCode': 'T04'});
    expect(table.tableNumber, 'T04');
    expect(table.orderType, OrderType.dineIn);
    final delivery = OrderModel.fromJson({...base, 'orderType': 'delivery', 'deliveryAddress': '12 Stable Road, Delhi'});
    expect(delivery.tableNumber, isNull);
    expect(delivery.orderType, OrderType.delivery);
  });
  test(
    'empty outer fields do not hide a table in nested socket order data',
    () {
      final data = IncomingOrderPayload.normalize({
        'type': 'new_order',
        'tableNumber': '',
        'items': [],
        'metadata': {'tableNumber': '', 'orderId': ''},
        'order': {
          '_id': 'order-12',
          'tableNumber': 'T-012',
          'orderType': 'dineIn',
          'items': [
            {'name': 'Pizza'},
          ],
        },
      });
      expect(data['tableNumber'], '12');
      expect(data['_id'], 'order-12');
      expect((data['items'] as List).single['name'], 'Pizza');
      expect((data['metadata'] as Map).containsKey('orderId'), isFalse);
    },
  );
  test('JSON-encoded FCM metadata and nested table objects are supported', () {
    expect(
      IncomingOrderPayload.tableNumber({
        'metadata': jsonEncode({'tableCode': 'T07'}),
      }),
      '7',
    );
    expect(
      IncomingOrderPayload.tableNumber({
        'order': {
          'table': {'number': 4, '_id': 'not-a-number'},
        },
      }),
      '4',
    );
    expect(
      IncomingOrderPayload.tableNumber({
        'data': jsonEncode({
          'order': {'table_no': 'Table 9'},
        }),
      }),
      '9',
    );
  });
  test('supported explicit table aliases normalize consistently', () {
    for (final alias in [
      'tableNumber',
      'tableNo',
      'table_no',
      'table_number',
      'tableCode',
      'table_code',
      'tableName',
      'T',
      't',
      'table',
    ]) {
      expect(
        IncomingOrderPayload.tableNumber({alias: 'T-02'}),
        '2',
        reason: alias,
      );
    }
    expect(IncomingOrderPayload.normalizeTableNumber('Table A12'), 'A12');
  });
  test(
    'explicit table markers can be recovered from address or customer name',
    () {
      expect(
        IncomingOrderPayload.tableNumber({
          'deliveryAddress': 'Table T03, River Kitchen',
        }),
        '3',
      );
      expect(
        IncomingOrderPayload.tableNumber({'customerName': 'Nakul (T04)'}),
        '4',
      );
      expect(
        IncomingOrderPayload.tableNumber({'customerName': 'Nakul (Table 5)'}),
        '5',
      );
    },
  );
  test(
    'a street address, customer label or absent table never invents a table',
    () {
      for (final text in [
        '12 Green Park, Delhi',
        'Stable Road, Block T12',
        'Customer (VIP)',
        'Table reservation',
      ]) {
        expect(
          IncomingOrderPayload.tableNumber({'deliveryAddress': text}),
          isNull,
          reason: text,
        );
      }
      for (final value in [
        '',
        'null',
        'undefined',
        'Dine-In',
        'Table Dine-In',
        '0',
        'T00',
      ]) {
        expect(
          IncomingOrderPayload.tableNumber({'tableNumber': value}),
          isNull,
          reason: value,
        );
      }
      expect(
        IncomingOrderPayload.tableNumber({
          'table': {'_id': 'mongo-table-id'},
        }),
        isNull,
      );
    },
  );
  test('canonical notification payload retains table after serialization', () {
    final notification = IncomingOrderPayload.normalize({
      'order': {
        'orderNumber': 'ORD-1',
        'tableNumber': 'T10',
        'customerName': 'Nakul',
      },
      'tableNumber': '',
    });
    expect(
      IncomingOrderPayload.tableNumber(
        Map<String, dynamic>.from(jsonDecode(jsonEncode(notification))),
      ),
      '10',
    );
  });
}
