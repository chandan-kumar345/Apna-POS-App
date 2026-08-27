import 'package:flutter/foundation.dart';
import '../models/crm_model.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import 'auth_service.dart';

class CrmFetchResult {
  final List<CrmLeadModel> leads;
  final int totalCount;
  final int page;
  final int totalPages;
  final CrmStatsModel stats;

  CrmFetchResult({
    required this.leads,
    required this.totalCount,
    required this.page,
    required this.totalPages,
    required this.stats,
  });
}

class CrmService {
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();

  static final CrmService _instance = CrmService._internal();
  factory CrmService() => _instance;
  CrmService._internal();

  /// Fetch paginated leads with filtering & statistics
  Future<CrmFetchResult?> fetchLeads({
    int page = 1,
    int limit = 20,
    String? stage,
    String? search,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (!isAuth) return null;

      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (stage != null && stage.isNotEmpty && stage != 'All') {
        queryParams['stage'] = stage;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['endDate'] = endDate;
      }

      final response = await _apiClient.get(
        ApiEndpoints.crmLeads,
        queryParameters: queryParams,
      );

      if (response != null && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final rawLeads = data['leads'] as List<dynamic>? ?? [];
        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
        final rawStats = data['stats'] as Map<String, dynamic>?;

        final leads = rawLeads
            .whereType<Map<String, dynamic>>()
            .map((item) => CrmLeadModel.fromJson(item))
            .toList();

        return CrmFetchResult(
          leads: leads,
          totalCount: (pagination['total'] as num?)?.toInt() ?? leads.length,
          page: (pagination['page'] as num?)?.toInt() ?? page,
          totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
          stats: CrmStatsModel.fromJson(rawStats),
        );
      }
    } catch (e) {
      debugPrint('[CrmService.fetchLeads] Error: $e');
    }
    return null;
  }

  /// Fetch dynamic stage counts
  Future<CrmStatsModel> fetchStats() async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final response = await _apiClient.get(ApiEndpoints.crmStats);
        if (response != null && response['data'] != null) {
          return CrmStatsModel.fromJson(response['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[CrmService.fetchStats] Error: $e');
    }
    return CrmStatsModel();
  }

  /// Get complete lead details
  Future<CrmLeadModel?> fetchLeadById(String id) async {
    try {
      final response = await _apiClient.get('${ApiEndpoints.crmLeads}/$id');
      if (response != null && response['data'] != null) {
        return CrmLeadModel.fromJson(response['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[CrmService.fetchLeadById] Error: $e');
    }
    return null;
  }

  /// Create a new customer lead
  Future<CrmLeadModel?> createLead(Map<String, dynamic> leadData) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.crmLeads,
        data: leadData,
      );
      if (response != null && response['data'] != null) {
        return CrmLeadModel.fromJson(response['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[CrmService.createLead] Error: $e');
      rethrow;
    }
    return null;
  }

  /// Update existing lead information
  Future<CrmLeadModel?> updateLead(String id, Map<String, dynamic> updateData) async {
    try {
      final response = await _apiClient.patch(
        '${ApiEndpoints.crmLeads}/$id',
        data: updateData,
      );
      if (response != null && response['data'] != null) {
        return CrmLeadModel.fromJson(response['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[CrmService.updateLead] Error: $e');
      rethrow;
    }
    return null;
  }

  /// Update lead stage (New Lead, Prospect, Deal, Won, Lost)
  Future<bool> updateStage(String id, String stage) async {
    try {
      final response = await _apiClient.post(
        '${ApiEndpoints.crmLeads}/$id/stage',
        data: {'stage': stage},
      );
      return response != null && response['success'] == true;
    } catch (e) {
      debugPrint('[CrmService.updateStage] Error: $e');
      return false;
    }
  }

  /// Schedule a follow-up
  Future<bool> setFollowup(
    String id, {
    required DateTime followupDate,
    String? followupNotes,
    String followupStatus = 'pending',
  }) async {
    try {
      final response = await _apiClient.post(
        '${ApiEndpoints.crmLeads}/$id/followup',
        data: {
          'followupDate': followupDate.toIso8601String(),
          'followupNotes': followupNotes ?? '',
          'followupStatus': followupStatus,
        },
      );
      return response != null && response['success'] == true;
    } catch (e) {
      debugPrint('[CrmService.setFollowup] Error: $e');
      return false;
    }
  }

  /// Toggle Like
  Future<bool> toggleLike(String id) async {
    try {
      final response = await _apiClient.post('${ApiEndpoints.crmLeads}/$id/like');
      return response != null && response['success'] == true;
    } catch (e) {
      debugPrint('[CrmService.toggleLike] Error: $e');
      return false;
    }
  }

  /// Toggle Star
  Future<bool> toggleStar(String id) async {
    try {
      final response = await _apiClient.post('${ApiEndpoints.crmLeads}/$id/star');
      return response != null && response['success'] == true;
    } catch (e) {
      debugPrint('[CrmService.toggleStar] Error: $e');
      return false;
    }
  }

  /// Export leads data for CSV/Excel
  Future<List<dynamic>?> exportLeads() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.crmExport);
      if (response != null && response['data'] is List) {
        return response['data'] as List<dynamic>;
      }
    } catch (e) {
      debugPrint('[CrmService.exportLeads] Error: $e');
    }
    return null;
  }

  /// Bulk import leads
  Future<int> importLeads(List<Map<String, dynamic>> leads) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.crmImport,
        data: {'leads': leads},
      );
      if (response != null && response['data'] != null) {
        return (response['data']['importedCount'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint('[CrmService.importLeads] Error: $e');
    }
    return 0;
  }
}
