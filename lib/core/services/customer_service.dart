import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String avatarUrl;
  final int totalOrders;
  final double totalSpent;
  final String? lastVisit;

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.address = '',
    this.avatarUrl = '',
    this.totalOrders = 0,
    this.totalSpent = 0,
    this.lastVisit,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name']?.toString() ?? json['customerName']?.toString() ?? json['clientName']?.toString() ?? '').trim();
    final rawPhone = (json['phone']?.toString() ?? json['customerPhone']?.toString() ?? json['mobile']?.toString() ?? json['phoneNumber']?.toString() ?? json['contactNumber']?.toString() ?? '').trim();
    final rawAddress = json['address']?.toString() ?? json['deliveryAddress']?.toString() ?? '';
    final rawAvatar = (json['avatarUrl']?.toString() ??
            json['profileImage']?.toString() ??
            json['avatar']?.toString() ??
            json['photoUrl']?.toString() ??
            json['logoUrl']?.toString() ??
            json['logo']?.toString() ??
            '')
        .trim();
    int parseCustInt(dynamic val, [int fallback = 0]) {
      if (val == null) return fallback;
      if (val is int) return val;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? fallback;
    }

    double parseCustDouble(dynamic val, [double fallback = 0.0]) {
      if (val == null) return fallback;
      if (val is double) return val;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? fallback;
    }

    final rawOrders = parseCustInt(
      json['totalOrders'] ??
          json['orderCount'] ??
          json['ordersCount'] ??
          json['totalOrdersCount'] ??
          json['salesCount'] ??
          json['ordersTotal'] ??
          (json['orders'] is List ? (json['orders'] as List).length : 0),
    );

    final rawSpent = parseCustDouble(
      json['totalSpent'] ??
          json['totalSpend'] ??
          json['totalAmount'] ??
          json['totalSales'] ??
          json['totalRevenue'] ??
          json['amount'] ??
          json['spend'],
    );

    return CustomerModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: rawName.isNotEmpty ? rawName : 'Customer',
      phone: rawPhone,
      email: json['email']?.toString() ?? '',
      address: rawAddress,
      avatarUrl: rawAvatar,
      totalOrders: rawOrders,
      totalSpent: rawSpent,
      lastVisit: json['lastVisit']?.toString() ?? json['updatedAt']?.toString() ?? json['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'avatarUrl': avatarUrl,
        'totalOrders': totalOrders,
        'totalSpent': totalSpent,
        'lastVisit': lastVisit,
      };

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? avatarUrl,
    int? totalOrders,
    double? totalSpent,
    String? lastVisit,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      totalOrders: totalOrders ?? this.totalOrders,
      totalSpent: totalSpent ?? this.totalSpent,
      lastVisit: lastVisit ?? this.lastVisit,
    );
  }
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

      if (response != null) {
        List<dynamic>? rawList;
        if (response is List) {
          rawList = response;
        } else if (response is Map) {
          final data = response['data'];
          if (data is List) {
            rawList = data;
          } else if (data is Map) {
            final Map<String, dynamic> dataMap = Map<String, dynamic>.from(data);
            rawList = (dataMap['customers'] ??
                    dataMap['docs'] ??
                    dataMap['items'] ??
                    dataMap['records'] ??
                    dataMap['data'] ??
                    dataMap['results']) as List<dynamic>?;
          }
          rawList ??= (response['customers'] ??
                  response['docs'] ??
                  response['items'] ??
                  response['records'] ??
                  response['results'] ??
                  (response['data'] is List ? response['data'] : null)) as List<dynamic>?;
        }

        if (rawList != null) {
          final List<CustomerModel> result = [];
          for (final c in rawList) {
            if (c is Map) {
              try {
                result.add(CustomerModel.fromJson(Map<String, dynamic>.from(c)));
              } catch (e) {
                debugPrint('[CustomerService.fetchCustomers] Skip malformed customer: $e');
              }
            }
          }
          return result;
        }
      }
      return [];
    } catch (e) {
      debugPrint('[CustomerService.fetchCustomers] error: $e');
      return [];
    }
  }

  /// Fast customer suggestions by phone or name prefix/query
  Future<List<CustomerModel>> fetchSuggestions(String query) async {
    try {
      final response = await _apiClient.get(
        '${ApiEndpoints.customers}/suggest',
        queryParameters: {'q': query.trim()},
      );

      if (response != null) {
        List<dynamic>? rawList;
        if (response is List) {
          rawList = response;
        } else if (response is Map) {
          final data = response['data'];
          if (data is List) {
            rawList = data;
          } else if (data is Map) {
            rawList = (data['customers'] ?? data['items'] ?? data['docs']) as List<dynamic>?;
          }
          rawList ??= response['customers'] as List<dynamic>?;
        }

        if (rawList != null) {
          final List<CustomerModel> result = [];
          for (final c in rawList) {
            if (c is Map) {
              try {
                result.add(CustomerModel.fromJson(Map<String, dynamic>.from(c)));
              } catch (_) {}
            }
          }
          if (result.isNotEmpty) return result;
        }
      }
      return await fetchCustomers(search: query, limit: 10);
    } catch (e) {
      debugPrint('[CustomerService.fetchSuggestions] error: $e');
      return await fetchCustomers(search: query, limit: 10);
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

