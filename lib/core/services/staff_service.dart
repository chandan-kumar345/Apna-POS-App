import 'package:flutter/foundation.dart';
import '../models/staff_model.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../database/database_service.dart';
import 'auth_service.dart';

class StaffFetchResult {
  final List<StaffModel> staff;
  final int totalCount;
  final int page;
  final int totalPages;
  final StaffStatsModel stats;

  StaffFetchResult({
    required this.staff,
    required this.totalCount,
    required this.page,
    required this.totalPages,
    required this.stats,
  });
}

class StaffService {
  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();
  final DatabaseService _db = DatabaseService();

  static final StaffService _instance = StaffService._internal();
  factory StaffService() => _instance;
  StaffService._internal();

  /// Fetch paginated staff list with filtering and stats dynamically from API
  Future<StaffFetchResult?> fetchStaff({
    int page = 1,
    int limit = 8,
    String? role,
    String? status,
    String? search,
  }) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (!isAuth) {
        return _getLocalStaff(page: page, limit: limit, role: role, status: status, search: search);
      }

      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (role != null && role.isNotEmpty && role != 'All Roles' && role != 'All') {
        queryParams['role'] = role.trim();
      }
      if (status != null && status.isNotEmpty && status != 'All Status' && status != 'All') {
        queryParams['status'] = status.trim();
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _apiClient.get(
        ApiEndpoints.staff,
        queryParameters: queryParams,
      );

      if (response != null) {
        List<dynamic> rawList = [];
        Map<String, dynamic> pagination = {};
        StaffStatsModel? statsFromResponse;

        if (response is Map<String, dynamic>) {
          if (response['data'] is Map<String, dynamic>) {
            final data = response['data'] as Map<String, dynamic>;
            if (data['staff'] is List) {
              rawList = data['staff'] as List<dynamic>;
            } else if (data['data'] is List) {
              rawList = data['data'] as List<dynamic>;
            }
            if (data['pagination'] is Map<String, dynamic>) {
              pagination = data['pagination'] as Map<String, dynamic>;
            }
            if (data['stats'] is Map<String, dynamic>) {
              statsFromResponse = StaffStatsModel.fromJson(data['stats'] as Map<String, dynamic>);
            }
          } else if (response['data'] is List) {
            rawList = response['data'] as List<dynamic>;
          } else if (response['staff'] is List) {
            rawList = response['staff'] as List<dynamic>;
          }
        } else if (response is List) {
          rawList = response;
        }

        final staffMembers = rawList
            .whereType<Map>()
            .map((s) => StaffModel.fromJson(Map<String, dynamic>.from(s)))
            .toList();

        final totalCount = (pagination['total'] as num?)?.toInt() ??
            int.tryParse(pagination['total']?.toString() ?? '') ??
            staffMembers.length;
        final totalPages = (pagination['totalPages'] as num?)?.toInt() ??
            int.tryParse(pagination['totalPages']?.toString() ?? '') ??
            ((totalCount / limit).ceil() > 0 ? (totalCount / limit).ceil() : 1);

        // Sync local cache with remote results
        _db.syncStaffList(staffMembers);

        // Fetch dynamic stats or compute from response/cache
        final stats = statsFromResponse ?? await fetchStats() ?? _computeStats(_db.staffList);

        return StaffFetchResult(
          staff: staffMembers,
          totalCount: totalCount,
          page: page,
          totalPages: totalPages,
          stats: stats,
        );
      }
    } catch (e) {
      debugPrint('[StaffService] fetchStaff error: $e. Falling back to local cache.');
    }

    return _getLocalStaff(page: page, limit: limit, role: role, status: status, search: search);
  }

  /// Fetch overall staff statistics dynamically from API
  Future<StaffStatsModel?> fetchStats() async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (!isAuth) {
        return _computeStats(_db.staffList);
      }

      final response = await _apiClient.get(ApiEndpoints.staffStats);
      if (response != null) {
        if (response is Map<String, dynamic>) {
          if (response['data'] is Map<String, dynamic>) {
            return StaffStatsModel.fromJson(response['data'] as Map<String, dynamic>);
          }
          if (response['total'] != null) {
            return StaffStatsModel.fromJson(response);
          }
        }
      }
    } catch (e) {
      debugPrint('[StaffService] fetchStats error: $e');
    }
    return _computeStats(_db.staffList);
  }

  /// Create a new staff member dynamically via API
  Future<StaffModel?> createStaff(StaffModel staff) async {
    try {
      final payload = staff.toJson();
      final response = await _apiClient.post(
        ApiEndpoints.staff,
        data: payload,
      );

      if (response != null) {
        Map<String, dynamic>? data;
        if (response is Map<String, dynamic>) {
          if (response['data'] is Map<String, dynamic>) {
            data = response['data'] as Map<String, dynamic>;
          } else if (response['staff'] is Map<String, dynamic>) {
            data = response['staff'] as Map<String, dynamic>;
          } else if (response['id'] != null || response['_id'] != null) {
            data = response;
          }
        }
        if (data != null) {
          final created = StaffModel.fromJson(data);
          _db.addStaff(created);
          return created;
        }
      }
    } catch (e) {
      debugPrint('[StaffService] createStaff API error: $e. Saving locally.');
    }

    // Local fallback
    _db.addStaff(staff);
    return staff;
  }

  /// Update an existing staff member dynamically via API
  Future<StaffModel?> updateStaff(StaffModel staff) async {
    try {
      final payload = staff.toJson();
      final response = await _apiClient.put(
        ApiEndpoints.staffById(staff.id),
        data: payload,
      );

      if (response != null) {
        Map<String, dynamic>? data;
        if (response is Map<String, dynamic>) {
          if (response['data'] is Map<String, dynamic>) {
            data = response['data'] as Map<String, dynamic>;
          } else if (response['id'] != null || response['_id'] != null) {
            data = response;
          }
        }
        if (data != null) {
          final updated = StaffModel.fromJson(data);
          _db.updateStaff(updated);
          return updated;
        }
      }
    } catch (e) {
      debugPrint('[StaffService] updateStaff API error: $e. Updating locally.');
    }

    // Local fallback
    _db.updateStaff(staff);
    return staff;
  }

  /// Toggle Active / Inactive status of staff dynamically via API
  Future<StaffModel?> toggleStatus(String id) async {
    try {
      final response = await _apiClient.patch(
        ApiEndpoints.staffStatus(id),
      );

      if (response != null) {
        Map<String, dynamic>? data;
        if (response is Map<String, dynamic>) {
          if (response['data'] is Map<String, dynamic>) {
            data = response['data'] as Map<String, dynamic>;
          } else if (response['id'] != null || response['_id'] != null) {
            data = response;
          }
        }
        if (data != null) {
          final updated = StaffModel.fromJson(data);
          _db.updateStaff(updated);
          return updated;
        }
      }
    } catch (e) {
      debugPrint('[StaffService] toggleStatus API error: $e. Toggling locally.');
    }

    // Local fallback
    return _db.toggleStaffStatus(id);
  }

  /// Delete a staff member dynamically via API
  Future<bool> deleteStaff(String id) async {
    try {
      final response = await _apiClient.delete(
        ApiEndpoints.staffById(id),
      );

      if (response != null && (response['success'] == true || response['data'] != null)) {
        _db.deleteStaff(id);
        return true;
      }
    } catch (e) {
      debugPrint('[StaffService] deleteStaff API error: $e. Deleting locally.');
    }

    _db.deleteStaff(id);
    return true;
  }

  /// Compute local statistics
  StaffStatsModel _computeStats(List<StaffModel> staffList) {
    int active = 0;
    int inactive = 0;
    int admins = 0;

    for (final s in staffList) {
      if (s.isActive) {
        active++;
      } else {
        inactive++;
      }
      if (s.isAdmin) {
        admins++;
      }
    }

    return StaffStatsModel(
      total: staffList.length,
      active: active,
      inactive: inactive,
      admins: admins,
    );
  }

  /// Local cache filtering fallback
  StaffFetchResult _getLocalStaff({
    int page = 1,
    int limit = 8,
    String? role,
    String? status,
    String? search,
  }) {
    List<StaffModel> list = List.from(_db.staffList);

    if (role != null && role.isNotEmpty && role != 'All Roles' && role != 'All') {
      list = list.where((s) => s.role.toLowerCase() == role.toLowerCase()).toList();
    }

    if (status != null && status.isNotEmpty && status != 'All Status' && status != 'All') {
      list = list.where((s) => s.status.toLowerCase() == status.toLowerCase()).toList();
    }

    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      list = list.where((s) {
        return s.name.toLowerCase().contains(q) ||
            s.employeeId.toLowerCase().contains(q) ||
            s.email.toLowerCase().contains(q) ||
            s.phone.toLowerCase().contains(q) ||
            s.role.toLowerCase().contains(q);
      }).toList();
    }

    final totalCount = list.length;
    final totalPages = (totalCount / limit).ceil() > 0 ? (totalCount / limit).ceil() : 1;
    final startIndex = (page - 1) * limit;
    final endIndex = (startIndex + limit).clamp(0, totalCount);

    final paginated = (startIndex < totalCount)
        ? list.sublist(startIndex, endIndex)
        : <StaffModel>[];

    final stats = _computeStats(_db.staffList);

    return StaffFetchResult(
      staff: paginated,
      totalCount: totalCount,
      page: page,
      totalPages: totalPages,
      stats: stats,
    );
  }
}
