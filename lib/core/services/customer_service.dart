import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final int totalOrders;
  final double totalSpent;
  final String? lastVisit;

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.address = '',
    this.totalOrders = 0,
    this.totalSpent = 0,
    this.lastVisit,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
        totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
        totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
        lastVisit: json['lastVisit']?.toString(),
      );
}

class CustomerService {
  final ApiClient _apiClient = ApiClient();

  /// Search or list customers
  Future<List<CustomerModel>> fetchCustomers({String? search, int page = 1, int limit = 50}) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'limit': limit};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _apiClient.get(
        ApiEndpoints.customers,
        queryParameters: queryParams,
      );

      if (response != null && response['data'] != null && response['data']['customers'] != null) {
        final raw = response['data']['customers'] as List<dynamic>;
        return raw.map((c) => CustomerModel.fromJson(c as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[CustomerService.fetchCustomers] error: $e');
      return [];
    }
  }

  /// Create or update customer profile
  Future<CustomerModel?> saveCustomer({
    required String name,
    required String phone,
    String? email,
    String? address,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.customers,
        data: {
          'name': name,
          'phone': phone,
          'email': email ?? '',
          'address': address ?? '',
        },
      );

      if (response != null && response['data'] != null && response['data']['customer'] != null) {
        return CustomerModel.fromJson(response['data']['customer'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('[CustomerService.saveCustomer] error: $e');
      return null;
    }
  }

  /// Fetch single customer by phone number
  Future<CustomerModel?> fetchByPhone(String phone) async {
    try {
      final response = await _apiClient.get('${ApiEndpoints.customers}/phone/$phone');
      if (response != null && response['data'] != null && response['data']['customer'] != null) {
        return CustomerModel.fromJson(response['data']['customer'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('[CustomerService.fetchByPhone] error: $e');
      return null;
    }
  }
}
