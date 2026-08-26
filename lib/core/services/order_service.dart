import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class OrderService {
  final ApiClient _apiClient = ApiClient();

  /// Create a new order in backend
  Future<OrderModel> createOrder(OrderModel order) async {
    try {
      final pm = order.paymentMethod.toLowerCase().trim();
      final isKotOrUnpaid = pm.contains('kot') ||
          pm.contains('pending') ||
          pm == 'unpaid' ||
          pm.isEmpty ||
          order.status == OrderStatus.pending ||
          order.status == OrderStatus.preparing;

      final isPaid = order.status == OrderStatus.completed || order.isPaid || (!isKotOrUnpaid && order.paymentStatus == 'paid');

      final itemsPayload = order.items.isNotEmpty
          ? order.items.map((i) => {
                'productId': i.item.id.length == 24 ? i.item.id : null,
                'name': i.item.name,
                'price': i.item.effectivePrice > 0 ? i.item.effectivePrice : i.item.price,
                'quantity': i.quantity,
                'foodType': i.item.itemType.toLowerCase().replaceAll('-', '_'),
                'note': i.note ?? '',
              }).toList()
          : [
              {
                'name': 'Custom Order Item',
                'price': order.totalAmount > 0 ? order.totalAmount : 1.0,
                'quantity': 1,
                'foodType': 'veg',
                'note': '',
              }
            ];

      final payload = {
        'orderNumber': order.orderNumber,
        'orderType': order.orderType.name,
        'status': isPaid ? 'completed' : order.status.name,
        'tableNumber': order.orderType == OrderType.dineIn ? (order.tableNumber ?? '') : '',
        'deliveryAddress': order.orderType == OrderType.delivery ? (order.deliveryAddress ?? '') : '',
        'customerName': order.customerName ?? '',
        'customerPhone': order.customerPhone ?? '',
        'items': itemsPayload,
        'subtotal': order.subtotal,
        'discountAmount': order.discountAmount,
        'taxAmount': order.taxAmount,
        'tipAmount': order.tipAmount,
        'deliveryCharge': order.deliveryCharge,
        'roundOff': order.roundOff,
        'totalAmount': order.totalAmount,
        'paymentMethod': isPaid ? (order.paymentMethod.isNotEmpty ? order.paymentMethod : 'Cash') : (isKotOrUnpaid ? 'KOT Pending' : order.paymentMethod),
        'paymentStatus': isPaid ? 'paid' : 'pending',
        'idempotencyKey': 'pos:generatePosOrder:${order.id}',
        'clientSyncId': order.id,
        'localOrderId': order.id,
        'isPaid': isPaid,
        'isDineIn': order.orderType == OrderType.dineIn,
        'paymentMode': isPaid ? (order.paymentMethod.isNotEmpty ? order.paymentMethod : 'Cash') : (isKotOrUnpaid ? 'KOT Pending' : order.paymentMethod),
        'paymentDetails': isPaid
            ? [
                {
                  'paymentType': order.paymentMethod.isNotEmpty ? order.paymentMethod : 'Cash',
                  'paymentName': order.paymentMethod.isNotEmpty ? order.paymentMethod : 'Cash',
                  'amount': order.totalAmount,
                  'paymentMethod': order.paymentMethod.isNotEmpty ? order.paymentMethod : 'Cash',
                  'ncReason': '',
                }
              ]
            : [],
      };

      final response = await _apiClient.post(
        ApiEndpoints.orders,
        data: payload,
      );

      if (response != null && response['data'] != null) {
        final orderData = (response['data']['order'] ?? response['data']) as Map<String, dynamic>?;
        if (orderData != null) {
          return OrderModel.fromJson(orderData).copyWith(isSynced: true);
        }
      }
      return order.copyWith(isSynced: true);
    } catch (e) {
      debugPrint('[OrderService.createOrder] error: $e');
      rethrow;
    }
  }

  /// Save current cart/order state and generate bill snapshot via Save & Print API
  Future<Map<String, dynamic>?> saveAndPrintOrder(Map<String, dynamic> payload) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.orderSaveAndPrint,
        data: payload,
      );
      if (response != null && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[OrderService.saveAndPrintOrder] error: $e');
      rethrow;
    }
  }

  /// Settle and complete order with full payment details
  Future<Map<String, dynamic>?> settleOrder(String orderId, Map<String, dynamic> paymentData) async {
    try {
      final response = await _apiClient.post(
        '${ApiEndpoints.orders}/$orderId/settle',
        data: paymentData,
      );
      if (response != null && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[OrderService.settleOrder] error: $e');
      rethrow;
    }
  }

  /// Generate POS Order with custom payload & idempotency
  Future<Map<String, dynamic>?> generatePosOrder(Map<String, dynamic> payload) async {
    try {
      final response = await _apiClient.post(
        '${ApiEndpoints.orders}/generateposorder',
        data: payload,
      );
      if (response != null && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[OrderService.generatePosOrder] error: $e');
      rethrow;
    }
  }

  /// Fetch orders list
  Future<List<OrderModel>> fetchOrders({
    int page = 1,
    int limit = 500,
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

      if (response != null) {
        List<dynamic>? ordersData;
        if (response is List) {
          ordersData = response;
        } else if (response['data'] is List) {
          ordersData = response['data'] as List<dynamic>;
        } else if (response['data'] is Map && response['data']['orders'] is List) {
          ordersData = response['data']['orders'] as List<dynamic>;
        } else if (response['orders'] is List) {
          ordersData = response['orders'] as List<dynamic>;
        }

        if (ordersData != null) {
          return ordersData
              .whereType<Map>()
              .map((o) => OrderModel.fromJson(Map<String, dynamic>.from(o)))
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
      final data = <String, dynamic>{
        'paymentMethod': paymentMethod.toLowerCase(),
      };
      if (amountPaid != null) {
        data['amountPaid'] = amountPaid;
      }
      final response = await _apiClient.post(
        '${ApiEndpoints.orders}/$orderId/pay',
        data: data,
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

  /// Check real-time UPI payment verification status for an order
  Future<bool> checkUpiPaymentVerification(String orderId) async {
    try {
      final response = await _apiClient.get(
        '${ApiEndpoints.orders}/$orderId/payment-status',
      );
      if (response != null && response['data'] != null) {
        final paymentStatus = response['data']['paymentStatus']?.toString().toLowerCase() ?? '';
        final isPaid = response['data']['isPaid'] == true;
        return isPaid || paymentStatus == 'paid' || paymentStatus == 'completed' || paymentStatus == 'success';
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
