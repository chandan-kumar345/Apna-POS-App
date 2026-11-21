import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/services/customer_service.dart';
import '../models/campaign_models.dart';

class CustomerDirectoryPage {
  final List<CustomerModel> customers;
  final int total, page;
  const CustomerDirectoryPage(this.customers, this.total, this.page);
}

/// Uses the authenticated, business-scoped endpoints. Mutations never fall back
/// to fabricated local records: a successful response means the record is saved.
class MobileCustomersApi {
  final ApiClient _client = ApiClient();

  Map<String, dynamic> _data(dynamic response) {
    if (response is Map && response['success'] != false) {
      final data = response['data'] ?? response;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    throw StateError(
      'The server returned an unexpected response. Please retry.',
    );
  }

  Future<CustomerDirectoryPage> customers({
    String search = '',
    int page = 1,
  }) async {
    final data = _data(
      await _client.get(
        ApiEndpoints.customers,
        queryParameters: {'search': search, 'page': page, 'limit': 50},
      ),
    );
    final rows = (data['customers'] as List? ?? [])
        .map((c) => CustomerModel.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList();
    final pagination = data['pagination'] as Map? ?? {};
    return CustomerDirectoryPage(
      rows,
      (pagination['total'] as num?)?.toInt() ?? rows.length,
      page,
    );
  }

  Future<List<AudienceGroupModel>> groups() async {
    final response = await _client.get(ApiEndpoints.campaignGroups);
    final data = response is Map && response['success'] != false
        ? response['data']
        : null;
    if (data is! List) {
      throw StateError('Could not load your groups. Please retry.');
    }
    return data
        .map(
          (g) =>
              AudienceGroupModel.fromJson(Map<String, dynamic>.from(g as Map)),
        )
        .toList();
  }

  Future<AudienceGroupModel> group(String id) async =>
      AudienceGroupModel.fromJson(
        _data(await _client.get(ApiEndpoints.campaignGroupById(id))),
      );

  Future<AudienceGroupModel> saveGroup({
    String? id,
    required String name,
    required List<Map<String, String>> numbers,
    String source = 'Manual',
    String description = '',
  }) async {
    final payload = {
      'name': name.trim(),
      'type': 'Customer',
      'source': source,
      'description': description,
      'numbers': numbers,
    };
    final response = id == null
        ? await _client.postOnce(ApiEndpoints.campaignGroups, data: payload)
        : await _client.put(ApiEndpoints.campaignGroupById(id), data: payload);
    final saved = AudienceGroupModel.fromJson(_data(response));
    if (saved.id.isEmpty) {
      throw StateError('The group was not saved. Please retry.');
    }
    return saved;
  }

  Future<void> deleteGroup(String id) async {
    _data(await _client.delete(ApiEndpoints.campaignGroupById(id)));
  }

  Future<void> saveCustomer(String name, String phone) async {
    final data = _data(
      await _client.postOnce(
        ApiEndpoints.customers,
        data: {'name': name.trim(), 'phone': phone},
      ),
    );
    if (data['customer'] is! Map) {
      throw StateError('The customer was not saved.');
    }
  }
}
