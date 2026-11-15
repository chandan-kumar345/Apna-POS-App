import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class StorefrontOrderAdapter implements HttpClientAdapter {
  int statusCode = 201;
  final requests = <Map<String, dynamic>>[];
  static const orderId = '63a123456789012345678901';
  static const businessId = '63b123456789012345678901';

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    final payload = options.data is String
        ? jsonDecode(options.data as String)
        : options.data;
    final data = Map<String, dynamic>.from(payload as Map);
    requests.add(data);
    return ResponseBody.fromString(
      jsonEncode(
        statusCode < 400
            ? {
                'data': {
                  'orderId': orderId,
                  'businessId': businessId,
                  'orderNumber': data['orderNumber'],
                  'status': 'pending',
                  'paymentStatus': 'pending',
                  'isPaid': false,
                  'createdAt': DateTime.now().toUtc().toIso8601String(),
                },
              }
            : {
                'error': {'code': 'INVALID_ORDER', 'message': 'Order rejected'},
              },
      ),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}
