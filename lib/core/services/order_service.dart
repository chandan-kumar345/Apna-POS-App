import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class OrderService {
  final ApiClient _apiClient = ApiClient();

  /// Create a new order in backend
  Future<OrderModel> createOrder(OrderModel order) async {
    try {
      final payload = {
        'orderType': order.orderType.name,
        'tableNumber': order.tableNumber ?? '',
        'customerName': order.customerName ?? '',
        'customerPhone': order.customerPhone ?? '',
        'items': order.items.map((i) => {
              'productId': i.item.id.length == 24 ? i.item.id : null,
              'name': i.item.name,
              'price': i.item.price,
              'quantity': i.quantity,
              'foodType': i.item.itemType.toLowerCase().replaceAll('-', '_'),
              'note': i.note ?? '',
            }).toList(),
        'subtotal': order.subtotal,
        'discountAmount': order.discountAmount,
        'taxAmount': order.taxAmount,
        'totalAmount': order.totalAmount,
        'paymentMethod': order.paymentMethod.toLowerCase(),
        'paymentStatus': order.status == OrderStatus.completed ? 'paid' : 'pending',
      };

      final response = await _apiClient.post(
        ApiEndpoints.orders,
        data: payload,
      );

      if (response != null && response['data'] != null && response['data']['order'] != null) {
        return OrderModel.fromJson(response['data']['order'] as Map<String, dynamic>);
      }
      return order;
    } catch (e) {
      debugPrint('[OrderService.createOrder] error: $e');
      rethrow;
    }
  }

  /// Fetch orders list
  Future<List<OrderModel>> fetchOrders({
    int page = 1,
    int limit = 50,
    String? status,
    String? orderType,
    String? search,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (status != null && status.isNotEmpty && status != 'All') {
        queryParams['status'] = status.toLowerCase();
      }
      if (orderType != null && orderType.isNotEmpty && orderType != 'All') {
        queryParams['orderType'] = orderType.toLowerCase();
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final response = await _apiClient.get(
        ApiEndpoints.orders,
        queryParameters: queryParams,
      );

      if (response != null && response['data'] != null) {
        final ordersData = response['data']['orders'] as List<dynamic>?;
        if (ordersData != null) {
          return ordersData
              .map((o) => OrderModel.fromJson(o as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[OrderService.fetchOrders] error: $e');
      return [];
    }
  }

  /// Update order status
  Future<OrderModel?> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      final response = await _apiClient.patch(
        '${ApiEndpoints.orders}/$orderId/status',
        data: {'status': status.name},
      );

      if (response != null && response['data'] != null && response['data']['order'] != null) {
        return OrderModel.fromJson(response['data']['order'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('[OrderService.updateOrderStatus] error: $e');
      rethrow;
    }
  }

  /// Settle and pay order
  Future<bool> payOrder(String orderId, {required String paymentMethod, double? amountPaid}) async {
    try {
      final response = await _apiClient.post(
        '${ApiEndpoints.orders}/$orderId/pay',
        data: {
          'paymentMethod': paymentMethod.toLowerCase(),
          if (amountPaid != null) 'amountPaid': amountPaid,
        },
      );
      return response != null && response['success'] == true;
    } catch (e) {
      debugPrint('[OrderService.payOrder] error: $e');
      rethrow;
    }
  }

  /// Fetch active order for a table
  Future<OrderModel?> fetchTableOrder(String tableNumber) async {
    try {
      final response = await _apiClient.get('${ApiEndpoints.orderTable}/$tableNumber');
      if (response != null && response['data'] != null && response['data']['order'] != null) {
        return OrderModel.fromJson(response['data']['order'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('[OrderService.fetchTableOrder] error: $e');
      return null;
    }
  }
}
