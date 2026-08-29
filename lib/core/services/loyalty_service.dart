import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../models/loyalty_program_model.dart';
import '../database/database_service.dart';
import 'auth_service.dart';

class LoyaltyService {
  static final LoyaltyService _instance = LoyaltyService._internal();
  factory LoyaltyService() => _instance;
  LoyaltyService._internal();

  final ApiClient _apiClient = ApiClient();
  final AuthService _authService = AuthService();
  final DatabaseService _db = DatabaseService();

  LoyaltyBrandingModel? _cachedBranding;
  LoyaltyPerformanceModel? _cachedPerformance;

  LoyaltyBrandingModel? get cachedBranding => _cachedBranding;
  LoyaltyPerformanceModel? get cachedPerformance => _cachedPerformance;

  /// Default fallback programs if fresh offline or first launch
  LoyaltyBrandingModel getDefaultLoyaltyBranding() {
    final companyName = _db.restaurant?.name ??
        _db.currentUser?.companyName ??
        _db.currentUser?.name ??
        'THE ROYAL GARDENIA';
    final companyLogo = _db.currentUser?.profilePhotoPath ?? '';

    return LoyaltyBrandingModel(
      companyName: companyName,
      companyLogo: companyLogo,
      programs: [
        LoyaltyProgramModel(
          id: 'prog_visit_made',
          type: LoyaltyType.visitMade,
          title: 'Visit Made',
          description: 'Get rewarded on every purchase',
          earningRule: '1 Visit Made = 10 Cookie',
          rewardCurrency: 'Cookie',
          gradientColors: ['#4A082F', '#8E1449'],
          milestones: [
            RewardMilestoneModel(id: 'm1', label: '300 Cookie', value: 300, iconName: 'cookie', rewardValue: 100),
            RewardMilestoneModel(id: 'm2', label: '500 Cookie', value: 500, iconName: 'cookie', rewardValue: 200),
            RewardMilestoneModel(id: 'm3', label: '800 Cookie', value: 800, iconName: 'cookie', rewardValue: 300),
          ],
        ),
        LoyaltyProgramModel(
          id: 'prog_amount_spent',
          type: LoyaltyType.amountSpent,
          title: 'Amount Spent',
          description: 'Get rewarded on every purchase',
          earningRule: '₹75 Amount Spent = 1 Cookie',
          rewardCurrency: 'Cookie',
          gradientColors: ['#6B0505', '#C81A1A'],
          milestones: [
            RewardMilestoneModel(id: 'm4', label: '300 Cookie', value: 300, iconName: 'cookie'),
            RewardMilestoneModel(id: 'm5', label: '500 Cookie', value: 500, iconName: 'cookie'),
            RewardMilestoneModel(id: 'm6', label: '800 Cookie', value: 800, iconName: 'cookie'),
          ],
        ),
        LoyaltyProgramModel(
          id: 'prog_cashback',
          type: LoyaltyType.cashback,
          title: 'Cashback',
          description: 'Get rewarded on every step',
          earningRule: '10% Cashback on sales above ₹500',
          rewardCurrency: '%',
          gradientColors: ['#0A425C', '#1E3A8A'],
          cashbackDetails: CashbackDetailsModel(
            percentage: 10.0,
            minSpend: 500.0,
            headline: '10% Cashback on sales',
            subtext: 'On min. spend of ₹500',
            termsNote: 'Cashback will be credited when another coupon or offer is already applied.',
            billRewardText: 'Rs 500+ bill earns 10% cashback',
            slabTitle: 'STARTER REWARD',
            goal: 'On min purchase of Rs 500',
            reward: '🎁 Earn 10% cashback',
            progressPercent: 65.0,
          ),
        ),
      ],
    );
  }

  /// Fetch all active loyalty programs with company branding from API (or local cache)
  Future<LoyaltyBrandingModel> fetchLoyaltyPrograms({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedBranding != null) {
      return _cachedBranding!;
    }

    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final response = await _apiClient.get(ApiEndpoints.loyaltyPrograms);
        if (response.statusCode == 200 && response.data != null) {
          final body = response.data;
          final data = (body is Map<String, dynamic> && body.containsKey('data'))
              ? body['data']
              : body;
          if (data is Map<String, dynamic>) {
            _cachedBranding = LoyaltyBrandingModel.fromJson(data);
            await _persistBrandingToPrefs(_cachedBranding!);
            return _cachedBranding!;
          }
        }
      }
    } catch (e) {
      debugPrint('[LoyaltyService.fetchLoyaltyPrograms] API error: $e');
    }

    final local = await _loadBrandingFromPrefs();
    if (local != null) {
      _cachedBranding = local;
      return local;
    }

    final defaultData = getDefaultLoyaltyBranding();
    _cachedBranding = defaultData;
    return defaultData;
  }

  final Map<String, LoyaltyPerformanceModel> _performanceCache = {};

  /// Fetch performance metrics (Fast Cache-First & Dynamic Refresh)
  Future<LoyaltyPerformanceModel> fetchLoyaltyPerformance({
    bool forceRefresh = false,
    String? dateRange,
  }) async {
    final cacheKey = dateRange ?? 'default';
    if (!forceRefresh && _performanceCache.containsKey(cacheKey)) {
      _cachedPerformance = _performanceCache[cacheKey];
      return _cachedPerformance!;
    }
    if (!forceRefresh && dateRange == null && _cachedPerformance != null) {
      return _cachedPerformance!;
    }

    LoyaltyPerformanceModel? resultModel;

    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final queryParams = dateRange != null ? {'dateRange': dateRange} : null;
        final response = await _apiClient.get(
          ApiEndpoints.loyaltyPerformance,
          queryParameters: queryParams,
        );
        if (response.statusCode == 200 && response.data != null) {
          final body = response.data;
          final data = (body is Map<String, dynamic> && body.containsKey('data'))
              ? body['data']
              : body;
          if (data is Map<String, dynamic>) {
            resultModel = LoyaltyPerformanceModel.fromJson(data);
          }
        }
      }
    } catch (e) {
      debugPrint('[LoyaltyService.fetchLoyaltyPerformance] API error: $e');
    }

    // Merge with locally created visit config if needed
    final base = resultModel ?? _performanceCache[cacheKey] ?? _cachedPerformance ?? const LoyaltyPerformanceModel();
    final syncedModel = await _ensureProgramInPerformance(base);

    _performanceCache[cacheKey] = syncedModel;
    if (dateRange == null) _cachedPerformance = syncedModel;
    return syncedModel;
  }

  /// Ensure locally created VisitRewardConfig is represented in program library
  Future<LoyaltyPerformanceModel> _ensureProgramInPerformance(LoyaltyPerformanceModel base) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJsonStr = prefs.getString('apna_pos_visit_reward_config');

      // If backend returned programs, use backend as authoritative source and sync local prefs
      if (base.programLibrary.isNotEmpty) {
        final serverProg = base.programLibrary.firstWhere(
          (p) => p.id == 'prog_visit_made' || p.category.contains('Visit'),
          orElse: () => base.programLibrary.first,
        );
        if (configJsonStr != null && configJsonStr.isNotEmpty) {
          final configMap = jsonDecode(configJsonStr) as Map<String, dynamic>?;
          if (configMap != null) {
            configMap['isActive'] = serverProg.isActive;
            configMap['status'] = serverProg.status;
            await prefs.setString('apna_pos_visit_reward_config', jsonEncode(configMap));
          }
        }
        return base;
      }

      // Only if base.programLibrary is empty (offline/fallback), construct from local prefs
      if (configJsonStr == null || configJsonStr.isEmpty) {
        return base;
      }

      final configMap = jsonDecode(configJsonStr) as Map<String, dynamic>?;
      if (configMap == null) return base;

      final config = VisitRewardConfig.fromJson(configMap);
      final progName = config.programName.isNotEmpty
          ? config.programName
          : (_db.restaurant?.name ?? _db.currentUser?.companyName ?? 'THE ROYAL GARDENIA');

      final orderTypes = config.orderType.isNotEmpty
          ? config.orderType.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          : const ['DineIn', 'TakeAway'];

      final starterStage = config.rewardStages.isNotEmpty ? config.rewardStages.first : null;
      final starterRewardTitle = starterStage != null
          ? (starterStage.freeItemName.isNotEmpty ? starterStage.freeItemName : '🎁 Level 1 Offer (₹${starterStage.rewardValue.toInt()} off)')
          : '🎁 Level 1 Offer';
      final starterRewardSubtext = starterStage != null
          ? '${starterStage.visitCount} Cookie'
          : '200 Cookie';

      final isProgActive = config.isActive && config.status != 'inactive' && config.status != 'draft';
      final progStatus = isProgActive ? 'active' : (config.status.isNotEmpty ? config.status : 'inactive');

      final localProgramItem = ProgramLibraryItemModel(
        id: 'prog_visit_made',
        name: progName,
        status: progStatus,
        createDate: '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
        category: 'Visit Made',
        channel: 'Store Visit',
        orderTypes: orderTypes,
        bannerImageUrl: config.bannerImageUrl,
        logoUrl: config.logoUrl,
        pointsName: 'Cookie',
        pointsPerVisit: 10,
        slogan: config.slogan.isNotEmpty ? config.slogan : 'Get rewarded on every purchase',
        bgGradientStart: '#4A082F',
        bgGradientEnd: '#8E1449',
        rewardColorStart: '#0F766E',
        rewardColorEnd: '#064E3B',
        starterRewardTitle: starterRewardTitle,
        starterRewardSubtext: starterRewardSubtext,
        isActive: isProgActive,
      );

      final currentLib = [localProgramItem];
      final activeCount = isProgActive ? 1 : 0;
      final inactiveCount = !isProgActive ? 1 : 0;

      return LoyaltyPerformanceModel(
        activeProgramsCount: activeCount,
        inactiveProgramsCount: inactiveCount,
        draftProgramsCount: 0,
        totalProgramsCount: 1,
        healthScore: base.healthScore,
        healthScoreStatus: base.healthScoreStatus,
        dateRangeText: base.dateRangeText,
        totalRevenue: base.totalRevenue,
        totalRedemptions: base.totalRedemptions,
        totalParticipants: base.totalParticipants,
        redemptionRate: base.redemptionRate,
        pointsRedeemed: base.pointsRedeemed,
        pointsIssued: base.pointsIssued,
        avgRewardPerRedemption: base.avgRewardPerRedemption,
        chartData: base.chartData,
        topRedeemingCustomers: base.topRedeemingCustomers,
        rewardScoreboard: base.rewardScoreboard,
        recentActivity: base.recentActivity,
        programLibrary: currentLib,
        totalMembers: base.totalMembers,
        activeMembers: base.activeMembers,
        rewardsClaimed: base.rewardsClaimed,
        repeatVisitRate: base.repeatVisitRate,
        totalPointsIssued: base.totalPointsIssued,
        totalCashbackGiven: base.totalCashbackGiven,
        loyaltyRevenue: base.loyaltyRevenue,
        roiPercentage: base.roiPercentage,
      );
    } catch (e) {
      debugPrint('[LoyaltyService._ensureProgramInPerformance] error: $e');
      return base;
    }
  }

  /// Update or save a specific loyalty program (e.g. Visit Made, Amount Spent, Cashback)
  Future<bool> updateLoyaltyProgram(LoyaltyProgramModel program) async {
    try {
      // 1. Try Cloud API
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final response = await _apiClient.put(
          '${ApiEndpoints.loyaltyPrograms}/${program.id}',
          data: program.toJson(),
        );
        if (response.statusCode == 200) {
          debugPrint('[LoyaltyService.updateLoyaltyProgram] Cloud program updated: ${program.id}');
        }
      }

      // 2. Update local cached branding
      if (_cachedBranding != null) {
        final updatedList = List<LoyaltyProgramModel>.from(_cachedBranding!.programs);
        final idx = updatedList.indexWhere((p) => p.id == program.id);
        if (idx >= 0) {
          updatedList[idx] = program;
        } else {
          updatedList.add(program);
        }
        _cachedBranding = LoyaltyBrandingModel(
          companyName: _cachedBranding!.companyName,
          companyLogo: _cachedBranding!.companyLogo,
          programs: updatedList,
        );
        await _persistBrandingToPrefs(_cachedBranding!);
      }

      return true;
    } catch (e) {
      debugPrint('[LoyaltyService.updateLoyaltyProgram] Error: $e');
      return true;
    }
  }

  /// Toggle / update status of a program in the program library
  Future<bool> updateProgramStatus(String programId, {required bool isActive, String? status}) async {
    try {
      _performanceCache.clear();
      _cachedPerformance = null;

      final prefs = await SharedPreferences.getInstance();
      final configJsonStr = prefs.getString('apna_pos_visit_reward_config');
      if (configJsonStr != null && configJsonStr.isNotEmpty) {
        final configMap = jsonDecode(configJsonStr) as Map<String, dynamic>?;
        if (configMap != null) {
          configMap['isActive'] = isActive;
          configMap['status'] = status ?? (isActive ? 'active' : 'inactive');
          await prefs.setString('apna_pos_visit_reward_config', jsonEncode(configMap));
        }
      }

      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final payload = {
          'id': programId,
          'isActive': isActive,
          'status': status ?? (isActive ? 'active' : 'inactive'),
        };
        await _apiClient.put(
          '${ApiEndpoints.loyaltyPrograms}/$programId',
          data: payload,
        );
      }
      return true;
    } catch (e) {
      debugPrint('[LoyaltyService.updateProgramStatus] error: $e');
      return false;
    }
  }

  /// Save VisitRewardConfig (cached locally & synchronized with backend API)
  Future<bool> saveVisitRewardConfig(VisitRewardConfig config) async {
    try {
      _performanceCache.clear();
      _cachedPerformance = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('apna_pos_visit_reward_config', jsonEncode(config.toJson()));

      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        try {
          final response = await _apiClient.post(
            ApiEndpoints.loyaltyConfig,
            data: config.toJson(),
          );
          if (response.statusCode == 200) {
            debugPrint('[LoyaltyService.saveVisitRewardConfig] Saved to cloud successfully!');
          }
        } catch (apiErr) {
          debugPrint('[LoyaltyService.saveVisitRewardConfig] API sync warning: $apiErr');
        }
      }
      return true;
    } catch (e) {
      debugPrint('[LoyaltyService.saveVisitRewardConfig] error: $e');
      return true;
    }
  }

  /// Retrieve VisitRewardConfig (from cloud API or local cache)
  Future<VisitRewardConfig> getVisitRewardConfig({String? companyName, String? companyLogo}) async {
    // 1. Try Cloud API
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final response = await _apiClient.get(ApiEndpoints.loyaltyConfig);
        if (response.statusCode == 200 && response.data != null) {
          final body = response.data;
          final data = (body is Map<String, dynamic> && body.containsKey('data'))
              ? body['data']
              : body;
          if (data is Map<String, dynamic>) {
            final config = VisitRewardConfig.fromJson(data);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('apna_pos_visit_reward_config', jsonEncode(config.toJson()));
            return config;
          }
        }
      }
    } catch (e) {
      debugPrint('[LoyaltyService.getVisitRewardConfig] API check error: $e');
    }

    // 2. Try local cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('apna_pos_visit_reward_config');
      if (raw != null && raw.isNotEmpty) {
        return VisitRewardConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {}

    // 3. Fallback defaults
    final defaultCompName = (companyName != null && companyName.trim().isNotEmpty)
        ? companyName.trim()
        : (_db.restaurant?.name ?? _db.currentUser?.companyName ?? 'THE ROYAL GARDENIA');

    return VisitRewardConfig(
      programName: defaultCompName,
      slogan: 'Get rewarded on every purchase',
      visitTrigger: 'Every Visit',
      triggerMinSpend: 100.0,
      visitCount: 300,
      rewardType: '₹ Discount',
      rewardValue: 100.0,
      minimumPurchase: 100.0,
      logoUrl: companyLogo ?? '',
      rewardStages: [
        RewardStageModel(
          id: 'stage_1',
          visitCount: 300,
          rewardType: '₹ Discount',
          rewardValue: 100.0,
          minimumPurchase: 100.0,
          freeItemName: 'Cheers ! Rs 100 off on your purchase.',
        ),
        RewardStageModel(
          id: 'stage_2',
          visitCount: 500,
          rewardType: '₹ Discount',
          rewardValue: 200.0,
          minimumPurchase: 100.0,
          freeItemName: 'Cheers ! Rs 200 off on your purchase.',
        ),
        RewardStageModel(
          id: 'stage_3',
          visitCount: 800,
          rewardType: '₹ Discount',
          rewardValue: 300.0,
          minimumPurchase: 100.0,
          freeItemName: 'Cheers ! Rs 300 off on your purchase.',
        ),
      ],
    );
  }

  /// Fetch Customer Loyalty Profile by Phone
  Future<CustomerLoyaltyModel?> getCustomerLoyalty(String phone, {String name = ''}) async {
    if (phone.trim().isEmpty) return null;

    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final uri = '${ApiEndpoints.loyaltyCustomer}/${phone.trim()}${name.isNotEmpty ? '?name=${Uri.encodeComponent(name)}' : ''}';
        final response = await _apiClient.get(uri);
        if (response.statusCode == 200 && response.data != null) {
          final body = response.data;
          final data = (body is Map<String, dynamic> && body.containsKey('data'))
              ? body['data']
              : body;
          if (data is Map<String, dynamic>) {
            return CustomerLoyaltyModel.fromJson(data);
          }
        }
      }
    } catch (e) {
      debugPrint('[LoyaltyService.getCustomerLoyalty] API error: $e');
    }

    return null;
  }

  /// Request OTP for Stage Level Loyalty Redemption
  Future<Map<String, dynamic>> sendRedemptionOtp({
    required String phone,
    required String stageId,
  }) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final response = await _apiClient.post(
          ApiEndpoints.loyaltySendOtp,
          data: {
            'phone': phone.trim(),
            'stageId': stageId,
          },
        );
        if (response.statusCode == 200 && response.data != null) {
          final body = response.data;
          return (body is Map<String, dynamic> && body.containsKey('data'))
              ? (body['data'] as Map<String, dynamic>)
              : (body as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[LoyaltyService.sendRedemptionOtp] API error: $e');
      rethrow;
    }

    throw Exception('Failed to send OTP. Please check server connection.');
  }

  /// Verify Redemption OTP
  Future<Map<String, dynamic>> verifyRedemptionOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final response = await _apiClient.post(
          ApiEndpoints.loyaltyVerifyOtp,
          data: {
            'phone': phone.trim(),
            'otp': otp.trim(),
          },
        );
        if (response.statusCode == 200 && response.data != null) {
          final body = response.data;
          return (body is Map<String, dynamic> && body.containsKey('data'))
              ? (body['data'] as Map<String, dynamic>)
              : (body as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[LoyaltyService.verifyRedemptionOtp] API error: $e');
      rethrow;
    }

    throw Exception('Invalid OTP verification request');
  }

  /// Settle Points Deduction after Order Completion
  Future<Map<String, dynamic>?> redeemLoyaltyPoints({
    required String phone,
    required String stageId,
    required double discountAmount,
    required int pointsToRedeem,
    String? orderId,
    String? orderNumber,
  }) async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        final response = await _apiClient.post(
          ApiEndpoints.loyaltyRedeem,
          data: {
            'phone': phone.trim(),
            'stageId': stageId,
            'discountAmount': discountAmount,
            'pointsToRedeem': pointsToRedeem,
            'orderId': orderId,
            'orderNumber': orderNumber,
          },
        );
        if (response.statusCode == 200 && response.data != null) {
          final body = response.data;
          return (body is Map<String, dynamic> && body.containsKey('data'))
              ? (body['data'] as Map<String, dynamic>)
              : (body as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('[LoyaltyService.redeemLoyaltyPoints] API error: $e');
    }
    return null;
  }

  Future<void> _persistBrandingToPrefs(LoyaltyBrandingModel branding) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'companyName': branding.companyName,
        'companyLogo': branding.companyLogo,
        'programs': branding.programs.map((p) => p.toJson()).toList(),
      };
      await prefs.setString('apna_pos_cached_loyalty_branding', jsonEncode(map));
    } catch (_) {}
  }

  Future<LoyaltyBrandingModel?> _loadBrandingFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('apna_pos_cached_loyalty_branding');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return LoyaltyBrandingModel.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}
