import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'storefront_order_adapter.dart';

class StorefrontCustomerAuthAdapter extends StorefrontOrderAdapter {
  final calls = <RequestOptions>[];
  String customerName = 'Valued Customer';
  String code = '654321';
  final history = <Map<String, dynamic>>[];
  bool deliveryFails = false;
  Map<String, dynamic> get customer => {
    'id': 'customer-verified',
    'name': customerName,
    'phone': '+919876543210',
  };
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    if (!options.path.contains('/customer/'))
      return super.fetch(options, body, cancel);
    calls.add(options);
    final input = options.data is String
        ? jsonDecode(options.data as String)
        : options.data;
    Object data;
    var status = 200;
    if (options.path.endsWith('/send-otp')) {
      status = deliveryFails ? 503 : 200;
      data = {
        'challengeId': 'challenge-1',
        'expiresIn': 300,
        'resendAfter': 60,
        'channel': 'whatsapp',
      };
    } else if (options.path.endsWith('/verify-otp')) {
      if ((input as Map)['code'] != code) {
        status = 401;
      }
      final name = input['name']?.toString().trim() ?? '';
      if (status == 200 && name.isNotEmpty) customerName = name;
      data = {'token': List.filled(64, 'a').join(), 'customer': customer};
    } else if (options.path.endsWith('/orders')) {
      data = history;
    } else {
      data = customer;
    }
    return ResponseBody.fromString(
      jsonEncode(
        status == 200
            ? {'data': data}
            : {
                'error': {
                  'code': 'INVALID_OTP',
                  'message': deliveryFails
                      ? 'WhatsApp unavailable'
                      : 'Code is incorrect or expired.',
                },
              },
      ),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }
}
