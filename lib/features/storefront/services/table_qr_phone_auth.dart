import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../models/customer_storefront_flow_models.dart';

typedef ConfirmTablePhone =
    Future<CustomerProfileModel> Function(String code, {String? name});

class TablePhoneChallenge {
  final ConfirmTablePhone? confirm;
  final CustomerProfileModel? verified;
  const TablePhoneChallenge.code(this.confirm) : verified = null;
  const TablePhoneChallenge.instant(this.verified) : confirm = null;
}

/// Dedicated restaurant customer session; never replaces merchant Firebase auth.
class TableQrPhoneAuth {
  TableQrPhoneAuth({required this.restaurantId});
  final String restaurantId;
  String get _path =>
      '/storefront/${Uri.encodeComponent(restaurantId)}/customer';
  String get _key =>
      'storefront_customer_session_${base64Url.encode(utf8.encode('${ApiEndpoints.baseUrl}|$restaurantId'))}';
  Future<String?> token() async =>
      (await SharedPreferences.getInstance()).getString(_key);
  Future<Options> options() async =>
      Options(headers: {'x-storefront-session': await token() ?? ''});
  Map<String, dynamic> _data(dynamic response) =>
      Map<String, dynamic>.from(response['data'] as Map);

  Future<CustomerProfileModel?> restore() async {
    if (await token() == null) return null;
    try {
      final response = await ApiClient().get(
        '$_path/me',
        options: await options(),
      );
      return CustomerProfileModel.fromJson(_data(response));
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await signOut();
        return null;
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove('customer_orders_$restaurantId');
  }

  Future<TablePhoneChallenge> send(String phone) async {
    final response = await ApiClient().post(
      '$_path/send-otp',
      data: {'phone': phone},
    );
    final id = _data(response)['challengeId'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Missing verification challenge');
    }
    return TablePhoneChallenge.code((code, {name}) async {
      final response = await ApiClient().post(
        '$_path/verify-otp',
        data: {
          'phone': phone,
          'code': code,
          'challengeId': id,
          'name': name?.trim() ?? '',
        },
      );
      final result = _data(response);
      if (result['token'] is! String || result['customer'] is! Map) {
        throw const FormatException('Missing customer session');
      }
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_key, result['token'] as String)) {
        throw StateError('Session could not be saved');
      }
      return CustomerProfileModel.fromJson(
        Map<String, dynamic>.from(result['customer'] as Map),
      );
    });
  }

  Future<List<CustomerOrderTrackingModel>> orders() async {
    final response = await ApiClient().get(
      '$_path/orders',
      options: await options(),
    );
    return (response['data'] as List)
        .map(
          (row) => CustomerOrderTrackingModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }
}
