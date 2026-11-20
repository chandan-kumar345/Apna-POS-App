import 'dart:async';
import 'dart:convert';
import 'table_qr_phone_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/order_model.dart';
import '../../../core/models/restaurant_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/firestore_service.dart';

class StorefrontOrderService {
  Future<OrderModel> submit(
    OrderModel order,
    RestaurantModel restaurant, {
    String notes = '',
  }) async {
    final slug = restaurant.storefrontSlug.isNotEmpty
        ? restaurant.storefrontSlug
        : restaurant.slug.isNotEmpty
        ? restaurant.slug
        : restaurant.id;
    final payload = <String, dynamic>{
      'orderId': order.id,
      'orderNumber': order.orderNumber,
      'idempotencyKey': order.id,
      'businessId': restaurant.id,
      'restaurantId': restaurant.id,
      'orderSource': 'storefront',
      'orderType': order.orderType.name,
      'tableNumber': order.tableNumber,
      'customerName': order.customerName,
      'customerPhone': order.customerPhone,
      'deliveryAddress': order.deliveryAddress,
      'subtotal': order.subtotal,
      'taxAmount': order.taxAmount,
      'discountAmount': order.discountAmount,
      'deliveryCharge': order.deliveryCharge,
      'totalAmount': order.totalAmount,
      'paymentMethod': order.paymentMethod,
      'notes': notes,
      'items': order.items.map((line) {
        final type = line.item.itemType.toLowerCase();
        return {
          'productId': line.item.productId,
          'name': line.item.name,
          'price': line.item.effectivePrice,
          'quantity': line.quantity,
          'note': line.note ?? '',
          'foodType': type.contains('non')
              ? 'non_veg'
              : type.contains('egg')
              ? 'egg'
              : type.contains('beverage')
              ? 'beverage'
              : 'veg',
        };
      }).toList(),
    };
    final preferences = await SharedPreferences.getInstance();
    final scope =
        '${ApiEndpoints.baseUrl}|${restaurant.id}|${order.customerPhone}|${order.orderType.name}|${order.tableNumber ?? ''}';
    final pendingKey =
        'storefront_pending_${base64Url.encode(utf8.encode(scope))}';
    final contents = Map<String, dynamic>.from(payload)
      ..remove('orderId')
      ..remove('orderNumber')
      ..remove('idempotencyKey');
    final fingerprint = jsonEncode(contents);
    Map<String, dynamic> pending = {};
    try {
      pending = Map<String, dynamic>.from(
        jsonDecode(preferences.getString(pendingKey) ?? '{}') as Map,
      );
    } catch (_) {}
    if (pending['fingerprint'] == fingerprint) {
      payload['orderId'] = pending['orderId'];
      payload['orderNumber'] = pending['orderNumber'];
      payload['idempotencyKey'] = pending['orderId'];
    }
    final stored = await preferences.setString(
      pendingKey,
      jsonEncode({
        'fingerprint': fingerprint,
        'orderId': payload['orderId'],
        'orderNumber': payload['orderNumber'],
      }),
    );
    if (!stored) {
      throw ApiException(
        message: 'Unable to save the order request. Please retry.',
      );
    }
    dynamic response;
    try {
      response = await ApiClient().post(
        ApiEndpoints.storefrontOrder(slug),
        data: payload,
        options: await TableQrPhoneAuth(restaurantId: restaurant.id).options(),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 400 || error.statusCode == 422) {
        await preferences.remove(pendingKey);
      }
      rethrow;
    }
    final data = response is Map && response['data'] is Map
        ? Map<String, dynamic>.from(response['data'] as Map)
        : <String, dynamic>{};
    final id = (data['orderId'] ?? data['id'] ?? '').toString();
    if (id.isEmpty) {
      throw ApiException(
        message:
            'The restaurant has not confirmed receipt of the order. Please try again.',
      );
    }
    await preferences.remove(pendingKey);
    final savedOrder = OrderModel.fromJson({
      ...order.toJson(),
      ...data,
      'id': id,
      '_id': id,
      'orderSource': 'storefront',
      'paymentStatus': data['paymentStatus'] ?? 'pending',
      'isPaid': data['isPaid'] == true,
      'isSynced': true,
    });
    unawaited(
      FirestoreService().submitStorefrontOrder(
        savedOrder,
        restaurantId: (data['businessId'] ?? restaurant.id).toString(),
      ),
    );
    return savedOrder;
  }
}
