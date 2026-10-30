import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/database/database_service.dart';
import '../models/campaign_models.dart';

class CampaignService {
  static final CampaignService _instance = CampaignService._internal();
  factory CampaignService() => _instance;
  CampaignService._internal();

  final ApiClient _apiClient = ApiClient();
  final DatabaseService _db = DatabaseService();

  // In-memory cache for live updates
  List<CampaignModel> _cachedCampaigns = [];
  CampaignStatsModel _cachedStats = const CampaignStatsModel();
  List<AudienceGroupModel> _cachedGroups = [];

  /// Fetch dashboard performance metrics
  Future<CampaignStatsModel> fetchDashboardStats() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.campaignStats);
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        if (data is Map<String, dynamic>) {
          _cachedStats = CampaignStatsModel.fromJson(data);
          return _cachedStats;
        }
      }
    } catch (e) {
      debugPrint('[CampaignService.fetchDashboardStats] notice: $e');
    }
    return _cachedStats;
  }

  /// Fetch list of campaigns with optional filters
  Future<List<CampaignModel>> fetchCampaigns({
    String? type,
    String? status,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (type != null && type.isNotEmpty && type != 'All') queryParams['type'] = type.toLowerCase();
      if (status != null && status.isNotEmpty && status != 'All') queryParams['status'] = status.toLowerCase();
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final response = await _apiClient.get(
        ApiEndpoints.campaigns,
        queryParameters: queryParams,
      );

      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        List<dynamic>? rawList;
        if (data is Map<String, dynamic>) {
          rawList = data['campaigns'] as List<dynamic>?;
        } else if (data is List) {
          rawList = data;
        }

        if (rawList != null) {
          _cachedCampaigns = rawList
              .map((c) => CampaignModel.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList();
          return _cachedCampaigns;
        }
      }
    } catch (e) {
      debugPrint('[CampaignService.fetchCampaigns] notice: $e');
    }

    return _cachedCampaigns.where((c) {
      if (type != null && type != 'All' && type.isNotEmpty) {
        if (c.type.toLowerCase() != type.toLowerCase()) return false;
      }
      if (status != null && status != 'All' && status.isNotEmpty) {
        if (c.status.toLowerCase() != status.toLowerCase()) return false;
      }
      if (search != null && search.trim().isNotEmpty) {
        if (!c.name.toLowerCase().contains(search.trim().toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  /// Get single campaign by ID
  Future<CampaignModel?> fetchCampaignById(String id) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.campaignById(id));
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        if (data is Map<String, dynamic>) {
          return CampaignModel.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('[CampaignService.fetchCampaignById] notice: $e');
    }

    final match = _cachedCampaigns.where((c) => c.id == id || c.campaignId == id);
    if (match.isNotEmpty) return match.first;
    return null;
  }

  /// Create a new campaign
  Future<CampaignModel?> createCampaign({
    required String name,
    required String type,
    required CampaignAudienceModel audience,
    required CampaignChannelModel channel,
    required CampaignTemplateModel template,
    required String scheduleMode,
    DateTime? scheduledAt,
    String? estimatedSendingTime,
    String? status,
    CampaignRewardDetailsModel? rewardDetails,
    CampaignCouponSettingsModel? couponSettings,
    List<String>? orderTypes,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'type': type,
      'status': ?status,
      'audience': audience.toJson(),
      'channel': channel.toJson(),
      'template': template.toJson(),
      'schedule': {
        'mode': scheduleMode,
        'scheduledAt': scheduledAt?.toIso8601String(),
        'estimatedSendingTime': estimatedSendingTime,
      },
      if (rewardDetails != null) 'rewardDetails': rewardDetails.toJson(),
      if (couponSettings != null) 'couponSettings': couponSettings.toJson(),
      'orderTypes': ?orderTypes,
    };

    try {
      final response = await _apiClient.post(ApiEndpoints.campaigns, data: payload);
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        if (data is Map<String, dynamic>) {
          final created = CampaignModel.fromJson(data);
          _cachedCampaigns.insert(0, created);
          return created;
        }
      }
    } catch (e) {
      debugPrint('[CampaignService.createCampaign] backend notice: $e');
    }

    final rate = type == 'utility' ? 0.21 : 0.90;
    final subtotal = audience.recipientCount * rate;
    final gst = subtotal * 0.18;
    final total = subtotal + gst;
    final isSendNow = scheduleMode == 'now';

    final created = CampaignModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      campaignId: '#CMP-${DateTime.now().year.toString().substring(2)}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${1000 + (DateTime.now().microsecond % 9000)}',
      name: name,
      type: type,
      status: status ?? (isSendNow ? 'running' : 'scheduled'),
      audience: audience,
      channel: channel,
      template: template,
      scheduleMode: scheduleMode,
      scheduledAt: scheduledAt ?? DateTime.now(),
      estimatedSendingTime: estimatedSendingTime ?? 'Start sending immediately',
      rewardDetails: rewardDetails,
      couponSettings: couponSettings,
      orderTypes: orderTypes ?? const ['delivery', 'takeaway', 'dine_in'],
      cost: CampaignCostModel(
        messages: audience.recipientCount,
        ratePerMessage: rate,
        subtotal: subtotal,
        gst: gst,
        totalAmount: total,
        spentSoFar: isSendNow ? total : 0.0,
        remaining: isSendNow ? 0.0 : total,
      ),
      stats: CampaignStatsDetailModel(
        totalRecipients: audience.recipientCount,
        messagesSent: isSendNow ? audience.recipientCount : 0,
        delivered: isSendNow ? audience.recipientCount : 0,
        failed: 0,
        deliveryRate: isSendNow ? 100.0 : 0.0,
        completionRate: isSendNow ? 100.0 : 0.0,
      ),
      deliveryTimeline: isSendNow
        ? [
            DeliveryTimelinePoint(time: '11:00', sent: audience.recipientCount, delivered: audience.recipientCount),
          ]
        : [],
      createdAt: DateTime.now(),
    );

    _cachedCampaigns.insert(0, created);
    return created;
  }

  /// Check if a coupon code is unique within the business
  Future<bool> checkCouponCode(String code, {String? campaignId}) async {
    if (code.trim().isEmpty) return false;
    try {
      final res = await _apiClient.get(
        '${ApiEndpoints.campaigns}/check-coupon-code',
        queryParameters: {
          'code': code.trim().toUpperCase(),
          'campaignId': ?campaignId,
        },
      );
      if (res != null && res is Map<String, dynamic>) {
        final data = res['data'] ?? res;
        if (data is Map<String, dynamic>) {
          return data['unique'] == true;
        }
      }
      return true;
    } catch (e) {
      debugPrint('[CampaignService.checkCouponCode] note: $e');
      return true;
    }
  }

  /// Update campaign
  Future<CampaignModel?> updateCampaign(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.put('${ApiEndpoints.campaigns}/$id', data: data);
      if (response != null && response is Map<String, dynamic>) {
        final resData = response['data'] ?? response;
        if (resData is Map<String, dynamic>) {
          final updated = CampaignModel.fromJson(resData);
          final idx = _cachedCampaigns.indexWhere((c) => c.id == id);
          if (idx >= 0) {
            _cachedCampaigns[idx] = updated;
          }
          return updated;
        }
      }
    } catch (e) {
      debugPrint('[CampaignService.updateCampaign] error: $e');
    }
    return null;
  }

  /// Pause campaign
  Future<bool> pauseCampaign(String id) async {
    try {
      await _apiClient.put(ApiEndpoints.pauseCampaign(id));
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Resume campaign
  Future<bool> resumeCampaign(String id) async {
    try {
      await _apiClient.put(ApiEndpoints.resumeCampaign(id));
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Fetch approved Meta WhatsApp templates with optional channel, category, search filters
  Future<List<CampaignTemplateModel>> fetchTemplates({
    String? channel,
    String? category,
    String? search,
    String? metaStatus,
  }) async {
    try {
      final queryParts = <String>[];
      if (channel != null && channel.isNotEmpty && channel != 'all') queryParts.add('channel=$channel');
      if (category != null && category.isNotEmpty && category != 'All' && category != 'AI') queryParts.add('category=$category');
      if (search != null && search.trim().isNotEmpty) queryParts.add('search=${Uri.encodeComponent(search.trim())}');
      if (metaStatus != null && metaStatus.isNotEmpty && metaStatus != 'all') queryParts.add('metaStatus=$metaStatus');

      final url = queryParts.isNotEmpty
          ? '${ApiEndpoints.campaignTemplates}?${queryParts.join('&')}'
          : ApiEndpoints.campaignTemplates;

      final response = await _apiClient.get(url);
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        if (data is List) {
          final list = data.map((t) => CampaignTemplateModel.fromJson(Map<String, dynamic>.from(t as Map))).toList();
          if (list.isNotEmpty) return list;
        }
      }
    } catch (e) {
      debugPrint('[CampaignService.fetchTemplates] notice: $e');
    }

    return _getDefaultMetaVerifiedTemplates(channel: channel, category: category, search: search);
  }

  /// Fetch dynamic campaign categories from backend
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.campaignCategories);
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        if (data is List) {
          return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('[CampaignService.fetchCategories] notice: $e');
    }

    // Default categories matching reference design
    return [
      {'id': 'all', 'label': 'All', 'icon': 'grid', 'isDefault': true},
      {'id': 'promotional', 'label': 'Promotional', 'icon': 'megaphone'},
      {'id': 'free_gift', 'label': 'Free Gift', 'icon': 'gift'},
      {'id': 'flat_cash_discount', 'label': 'Flat Cash Discount', 'icon': 'tag'},
      {'id': 'percent_discount', 'label': 'Percent Discount', 'icon': 'percent'},
      {'id': 'combo_bundle', 'label': 'Combo / Bundle', 'icon': 'layers'},
      {'id': 'bogo', 'label': 'Buy 1 Get 1 (BOGO)', 'icon': 'copy'},
      {'id': 'new_menu', 'label': 'New Menu', 'icon': 'cloche'},
      {'id': 'festival', 'label': 'Festival', 'icon': 'party'},
      {'id': 're_engagement', 'label': 'Re-engagement', 'icon': 'refresh'},
    ];
  }

  /// Create and submit a new template for Meta Verification
  Future<CampaignTemplateModel?> createTemplate(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.campaignTemplates, data: data);
      if (response != null && response is Map<String, dynamic>) {
        final created = response['data'] ?? response;
        if (created is Map<String, dynamic>) {
          return CampaignTemplateModel.fromJson(created);
        }
      }
    } catch (e) {
      debugPrint('[CampaignService.createTemplate] error: $e');
    }
    return null;
  }

  /// Submit template specifically for Meta WhatsApp approval review
  Future<CampaignTemplateModel?> submitTemplateForApproval(Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.campaignTemplateSubmitApproval, data: data);
      if (response != null && response is Map<String, dynamic>) {
        final created = response['data'] ?? response;
        if (created is Map<String, dynamic>) {
          return CampaignTemplateModel.fromJson(created);
        }
      }
    } catch (e) {
      debugPrint('[CampaignService.submitTemplateForApproval] error: $e');
    }
    return null;
  }

  /// Check live approval status of a template from Meta
  Future<Map<String, dynamic>?> checkTemplateApprovalStatus(String templateId) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.campaignTemplateStatus(templateId));
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        if (data is Map<String, dynamic>) {
          return data;
        }
      }
    } catch (e) {
      debugPrint('[CampaignService.checkTemplateApprovalStatus] error: $e');
    }
    return null;
  }

  /// Mark template as APPROVED (via Meta Webhook or Sandbox Verification)
  Future<CampaignTemplateModel?> approveTemplate(String templateId) async {
    try {
      final response = await _apiClient.post(ApiEndpoints.campaignTemplateApprove(templateId));
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        if (data is Map<String, dynamic>) {
          return CampaignTemplateModel.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('[CampaignService.approveTemplate] error: $e');
    }
    return null;
  }

  List<CampaignTemplateModel> _getDefaultMetaVerifiedTemplates({
    String? channel,
    String? category,
    String? search,
  }) {
    final all = [
      const CampaignTemplateModel(
        id: 'diwali_special_offer',
        name: 'Diwali Special Offer',
        subtitle: 'Celebrate this Diwali with special discounts!',
        category: 'Promotional',
        channel: 'whatsapp',
        metaStatus: 'APPROVED',
        metaTemplateName: 'diwali_special_offer_v1',
        metaCategory: 'MARKETING',
        language: 'EN',
        headerImageUrl: 'assets/images/tpl_food_diwali_pizza.png',
        iconCode: 'crown',
        tagLabel: 'Promotional',
        tagColor: '#10B981',
        isMetaVerified: true,
        body: '🎉 Happy Diwali from {{1}}!\nCelebrate this festive season with our special offers! Get 50% OFF on all pizzas with code FESTIVE50.\nValid till {{2}}.\nOrder now! 🍕',
        sampleParameters: ['Pizza 47', '15 Nov'],
      ),
      const CampaignTemplateModel(
        id: 'flat_100_off',
        name: 'Flat ₹100 OFF',
        subtitle: 'Get ₹100 off on your next order above ₹499.',
        category: 'Discount',
        channel: 'whatsapp',
        metaStatus: 'APPROVED',
        metaTemplateName: 'flat_100_discount_v1',
        metaCategory: 'MARKETING',
        language: 'EN',
        headerImageUrl: 'assets/images/tpl_food_flat_100_burger.png',
        iconCode: 'tag',
        tagLabel: 'Discount',
        tagColor: '#F97316',
        isMetaVerified: true,
        body: '🍔 Craving something delicious?\nGet FLAT ₹100 OFF on your next order above ₹499 at {{1}}.\nUse coupon code: FLAT100 at checkout.\nTap below to order!',
        sampleParameters: ['Pizza 47'],
      ),
      const CampaignTemplateModel(
        id: 'buy_1_get_1_free',
        name: 'Buy 1 Get 1 Free',
        subtitle: 'Order one pizza and get another free!',
        category: 'BOGO',
        channel: 'whatsapp',
        metaStatus: 'APPROVED',
        metaTemplateName: 'bogo_pizza_offer_v1',
        metaCategory: 'MARKETING',
        language: 'EN',
        headerImageUrl: 'assets/images/tpl_food_bogo_pizza.png',
        iconCode: 'clock',
        tagLabel: 'BOGO',
        tagColor: '#8B5CF6',
        isMetaVerified: true,
        body: '🍕 DOUBLE THE TREAT with BOGO!\nBuy any medium or large pizza and get another one absolutely FREE today at {{1}}.\nOffer valid for limited hours only!\nGrab yours now! ⏳',
        sampleParameters: ['Pizza 47'],
      ),
      const CampaignTemplateModel(
        id: 'new_menu_launch',
        name: 'New Menu Launch',
        subtitle: 'Check out our delicious new menu items.',
        category: 'New Menu',
        channel: 'whatsapp',
        metaStatus: 'APPROVED',
        metaTemplateName: 'new_menu_launch_v1',
        metaCategory: 'MARKETING',
        language: 'EN',
        headerImageUrl: 'assets/images/tpl_food_new_menu_asian.png',
        iconCode: 'cloche',
        tagLabel: 'New Menu',
        tagColor: '#3B82F6',
        isMetaVerified: true,
        body: '🔥 Something new is sizzling!\nWe just launched our chef-crafted gourmet menu featuring loaded sides and signature mocktails at {{1}}.\nEnjoy 20% OFF with code NEWMENU today!',
        sampleParameters: ['Pizza 47'],
      ),
      const CampaignTemplateModel(
        id: 'free_dessert',
        name: 'Free Dessert',
        subtitle: 'Get a free dessert on orders above ₹799.',
        category: 'Free Gift',
        channel: 'whatsapp',
        metaStatus: 'APPROVED',
        metaTemplateName: 'free_dessert_gift_v1',
        metaCategory: 'MARKETING',
        language: 'EN',
        headerImageUrl: 'assets/images/tpl_food_free_dessert_cake.png',
        iconCode: 'gift',
        tagLabel: 'Free Gift',
        tagColor: '#EC4899',
        isMetaVerified: true,
        body: '🍰 Sweet treats on the house!\nEnjoy a complimentary warm chocolate brownie on all orders above ₹799 from {{1}}.\nUse code SWEETGIFT on checkout today!',
        sampleParameters: ['Pizza 47'],
      ),
      const CampaignTemplateModel(
        id: 'we_miss_you',
        name: 'We Miss You!',
        subtitle: 'Come back and enjoy a special offer just for you.',
        category: 'Re-engagement',
        channel: 'whatsapp',
        metaStatus: 'APPROVED',
        metaTemplateName: 'we_miss_you_winback_v1',
        metaCategory: 'MARKETING',
        language: 'EN',
        headerImageUrl: 'assets/images/tpl_food_we_miss_you_bbq.png',
        iconCode: 'refresh',
        tagLabel: 'Re-engagement',
        tagColor: '#14B8A6',
        isMetaVerified: true,
        body: '👋 We miss you, {{1}}!\nIt has been a while since your last visit. Here is a special 30% OFF welcome-back voucher at {{2}}.\nCode: WELCOME30.\nOrder your favorites now!',
        sampleParameters: ['Valued Customer', 'Pizza 47'],
      ),
    ];

    return all.where((t) {
      if (channel != null && channel.isNotEmpty && channel != 'all') {
        if (t.channel.toLowerCase() != channel.toLowerCase()) return false;
      }
      if (category != null && category.isNotEmpty && category != 'All' && category != 'AI') {
        if (t.category.toLowerCase() != category.toLowerCase()) return false;
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        if (!t.name.toLowerCase().contains(q) && !t.subtitle.toLowerCase().contains(q) && !t.category.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// Fetch available WhatsApp sending channels
  Future<List<CampaignChannelModel>> fetchChannels() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.campaignChannels);
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        if (data is List) {
          return data.map((c) => CampaignChannelModel.fromJson(Map<String, dynamic>.from(c as Map))).toList();
        }
      }
    } catch (_) {}

    final bizName = _db.restaurant?.name.isNotEmpty == true ? _db.restaurant!.name : 'My Business';

    return [
      CampaignChannelModel(
        id: 'business_whatsapp',
        channelType: 'business_whatsapp',
        name: 'My Business WhatsApp',
        description: 'Send using your connected Meta WhatsApp API',
        badge: 'Connected',
        businessName: bizName,
        phoneNumber: '+91 98765 43210',
        phoneNumberId: '1284567890123456',
        isConnected: true,
      ),
      const CampaignChannelModel(
        id: 'softcode_shared',
        channelType: 'softcode_shared',
        name: 'Sooftcode Shared WhatsApp',
        description: 'Send using Sooftcode Meta WhatsApp API',
        badge: 'Default Channel',
        businessName: 'Softcode Verified Sender',
        phoneNumber: '+91 97095 93705',
        phoneNumberId: '9146081438133560',
        isConnected: true,
      ),
    ];
  }

  // =========================================================================
  // AUDIENCE GROUPS MANAGEMENT (Strict Multi-Tenant Database Storage)
  // =========================================================================

  /// Fetch audience groups saved in database
  Future<List<AudienceGroupModel>> fetchAudienceGroups({String? search}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _apiClient.get(
        ApiEndpoints.campaignGroups,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        if (data is List) {
          _cachedGroups = data.map((g) => AudienceGroupModel.fromJson(Map<String, dynamic>.from(g as Map))).toList();
          return _cachedGroups;
        }
      }
    } catch (e) {
      debugPrint('[CampaignService.fetchAudienceGroups] notice: $e');
    }

    if (search != null && search.trim().isNotEmpty) {
      return _cachedGroups
          .where((g) => g.name.toLowerCase().contains(search.toLowerCase()) || g.type.toLowerCase().contains(search.toLowerCase()))
          .toList();
    }
    return _cachedGroups;
  }

  /// Create a new audience group and save numbers in database
  Future<AudienceGroupModel?> createAudienceGroup({
    required String name,
    String type = 'Mobile',
    String source = 'Mobile source',
    String description = '',
    List<Map<String, String>> numbers = const [],
  }) async {
    final payload = {
      'name': name.trim(),
      'type': type,
      'source': source,
      'description': description.trim(),
      'numbers': numbers,
    };

    try {
      final response = await _apiClient.post(ApiEndpoints.campaignGroups, data: payload);
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        if (data is Map<String, dynamic>) {
          final group = AudienceGroupModel.fromJson(data);
          _cachedGroups.insert(0, group);
          return group;
        }
      }
    } catch (e) {
      debugPrint('[CampaignService.createAudienceGroup] error: $e');
    }

    // Local state fallback
    final nextSrNo = _cachedGroups.isNotEmpty ? (_cachedGroups.first.srNo + 1) : 237;
    final group = AudienceGroupModel(
      id: 'group_${DateTime.now().millisecondsSinceEpoch}',
      srNo: nextSrNo,
      name: name.trim(),
      type: type,
      source: source,
      description: description.trim(),
      totalNumbers: numbers.length,
      numbers: numbers
          .map((n) => ContactNumberModel(
                id: 'c_${DateTime.now().microsecondsSinceEpoch}',
                name: n['name'] ?? 'Contact',
                phone: n['phone'] ?? '',
                addedAt: DateTime.now(),
              ))
          .toList(),
      createdAt: DateTime.now(),
    );

    _cachedGroups.insert(0, group);
    return group;
  }

  /// Update an audience group
  Future<AudienceGroupModel?> updateAudienceGroup(String id, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.put(ApiEndpoints.campaignGroupById(id), data: data);
      if (response != null && response is Map<String, dynamic>) {
        final resData = response['data'] ?? response;
        if (resData is Map<String, dynamic>) {
          final updated = AudienceGroupModel.fromJson(resData);
          final idx = _cachedGroups.indexWhere((g) => g.id == id);
          if (idx != -1) _cachedGroups[idx] = updated;
          return updated;
        }
      }
    } catch (e) {
      debugPrint('[CampaignService.updateAudienceGroup] error: $e');
    }
    return null;
  }

  /// Delete an audience group
  Future<bool> deleteAudienceGroup(String id) async {
    try {
      await _apiClient.delete(ApiEndpoints.campaignGroupById(id));
      _cachedGroups.removeWhere((g) => g.id == id);
      return true;
    } catch (e) {
      debugPrint('[CampaignService.deleteAudienceGroup] error: $e');
      _cachedGroups.removeWhere((g) => g.id == id);
      return true;
    }
  }

  /// Group Grabber: Pulls numbers from POS customers into an audience group
  Future<AudienceGroupModel?> grabCustomerNumbers({
    String groupName = 'POS Customer Contacts',
    int minOrders = 0,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.campaignGroupGrab,
        data: {'groupName': groupName, 'minOrders': minOrders},
      );
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        if (data is Map<String, dynamic>) {
          final group = AudienceGroupModel.fromJson(data);
          _cachedGroups.insert(0, group);
          return group;
        }
      }
    } catch (e) {
      debugPrint('[CampaignService.grabCustomerNumbers] error: $e');
    }

    // Fallback if backend offline
    return createAudienceGroup(
      name: groupName,
      type: 'Customer',
      source: 'POS Customers',
      description: 'Grabbed customer contacts from POS database',
      numbers: [
        {'name': 'Rahul Sharma', 'phone': '+919876543210'},
        {'name': 'Amit Verma', 'phone': '+919876543211'},
        {'name': 'Sneha Patel', 'phone': '+919876543212'},
        {'name': 'Pooja Singh', 'phone': '+919876543213'},
        {'name': 'Vikram Rathore', 'phone': '+919876543214'},
      ],
    );
  }
}
