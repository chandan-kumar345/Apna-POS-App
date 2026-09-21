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

  /// Fetch paginated staff list with filtering and stats
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
        queryParams['role'] = role;
      }
      if (status != null && status.isNotEmpty && status != 'All Status' && status != 'All') {
        queryParams['status'] = status;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _apiClient.get(
        ApiEndpoints.staff,
        queryParameters: queryParams,
      );

      if (response != null && response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final rawList = data['staff'] as List<dynamic>? ?? [];
        final staffMembers = rawList
            .map((s) => StaffModel.fromJson(s as Map<String, dynamic>))
            .toList();

        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
        final totalCount = (pagination['total'] as num?)?.toInt() ?? staffMembers.length;
        final totalPages = (pagination['totalPages'] as num?)?.toInt() ?? 1;

        // Fetch / compute stats
        final stats = await fetchStats() ?? _computeStats(staffMembers);

        // Sync local cache
        _db.syncStaffList(staffMembers);

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

  /// Fetch overall staff statistics
  Future<StaffStatsModel?> fetchStats() async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (!isAuth) {
        return _computeStats(_db.staffList);
      }

      final response = await _apiClient.get(ApiEndpoints.staffStats);
      if (response != null && response['success'] == true && response['data'] != null) {
        return StaffStatsModel.fromJson(response['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[StaffService] fetchStats error: $e');
    }
    return _computeStats(_db.staffList);
  }

  /// Create a new staff member
  Future<StaffModel?> createStaff(StaffModel staff) async {
    try {
      final payload = staff.toJson();
      final response = await _apiClient.post(
        ApiEndpoints.staff,
        data: payload,
      );

      if (response != null && response['success'] == true && response['data'] != null) {
        final created = StaffModel.fromJson(response['data'] as Map<String, dynamic>);
        _db.addStaff(created);
        return created;
      }
    } catch (e) {
      debugPrint('[StaffService] createStaff API error: $e. Saving locally.');
    }

    // Local fallback
    _db.addStaff(staff);
    return staff;
  }

  /// Update an existing staff member
  Future<StaffModel?> updateStaff(StaffModel staff) async {
    try {
      final payload = staff.toJson();
      final response = await _apiClient.put(
        ApiEndpoints.staffById(staff.id),
        data: payload,
      );

      if (response != null && response['success'] == true && response['data'] != null) {
        final updated = StaffModel.fromJson(response['data'] as Map<String, dynamic>);
        _db.updateStaff(updated);
        return updated;
      }
    } catch (e) {
      debugPrint('[StaffService] updateStaff API error: $e. Updating locally.');
    }

    // Local fallback
    _db.updateStaff(staff);
    return staff;
  }

  /// Toggle Active / Inactive status of staff
  Future<StaffModel?> toggleStatus(String id) async {
    try {
      final response = await _apiClient.patch(
        ApiEndpoints.staffStatus(id),
      );

      if (response != null && response['success'] == true && response['data'] != null) {
        final updated = StaffModel.fromJson(response['data'] as Map<String, dynamic>);
        _db.updateStaff(updated);
        return updated;
      }
    } catch (e) {
      debugPrint('[StaffService] toggleStatus API error: $e. Toggling locally.');
    }

    // Local fallback
    return _db.toggleStaffStatus(id);
  }

  /// Delete a staff member
  Future<bool> deleteStaff(String id) async {
    try {
      final response = await _apiClient.delete(
        ApiEndpoints.staffById(id),
      );

      if (response != null && response['success'] == true) {
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
