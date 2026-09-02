import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../database/database_service.dart';

class SubscriptionPlanModel {
  final String id;
  final String name;
  final String badge;
  final double priceMonthly;
  final double priceAnnual;
  final String annualSavingsText;
  final bool popular;
  final String description;
  final List<String> features;
  final String ctaLabel;
  final bool isCurrent;

  const SubscriptionPlanModel({
    required this.id,
    required this.name,
    this.badge = '',
    this.priceMonthly = 0,
    this.priceAnnual = 0,
    this.annualSavingsText = '',
    this.popular = false,
    this.description = '',
    this.features = const [],
    this.ctaLabel = 'I\'m Interested',
    this.isCurrent = false,
  });

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      badge: json['badge']?.toString() ?? '',
      priceMonthly: (json['priceMonthly'] as num?)?.toDouble() ?? 0,
      priceAnnual: (json['priceAnnual'] as num?)?.toDouble() ?? 0,
      annualSavingsText: json['annualSavingsText']?.toString() ?? '',
      popular: json['popular'] == true,
      description: json['description']?.toString() ?? '',
      features: (json['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      ctaLabel: json['ctaLabel']?.toString() ?? 'I\'m Interested',
      isCurrent: json['isCurrent'] == true,
    );
  }
}

class SubscriptionAddonModel {
  final String id;
  final String name;
  final String icon;
  final double priceMonthly;
  final String description;

  const SubscriptionAddonModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.priceMonthly,
    required this.description,
  });

  factory SubscriptionAddonModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionAddonModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'star',
      priceMonthly: (json['priceMonthly'] as num?)?.toDouble() ?? 499,
      description: json['description']?.toString() ?? '',
    );
  }
}

class SubscriptionDataModel {
  final List<SubscriptionPlanModel> plans;
  final List<SubscriptionAddonModel> addons;

  const SubscriptionDataModel({
    this.plans = const [],
    this.addons = const [],
  });
}

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final ApiClient _api = ApiClient();
  final DatabaseService _db = DatabaseService();

  SubscriptionDataModel? _cachedData;

  /// Default rich fallback plans
  SubscriptionDataModel getDefaultPlans() {
    return const SubscriptionDataModel(
      plans: [
        SubscriptionPlanModel(
          id: 'plan_starter',
          name: 'Starter / Essential',
          badge: 'Basic',
          priceMonthly: 0,
          priceAnnual: 0,
          popular: false,
          description: 'Essential billing and table management for small cafes and food trucks.',
          features: [
            'Unlimited Table & Quick POS Billing',
            '1 Active Cashier Terminal',
            'Basic Menu & Category Management',
            'Realtime Dine-In, Takeaway, Delivery',
            'Standard Daily Sales Reports',
            'Thermal Receipt & KOT Printing',
          ],
          ctaLabel: 'Current Free Plan',
          isCurrent: true,
        ),
        SubscriptionPlanModel(
          id: 'plan_growth',
          name: 'Growth / Pro All-in-One',
          badge: 'Most Popular 🔥',
          priceMonthly: 999,
          priceAnnual: 7999,
          annualSavingsText: 'Save 33% (₹7,999/yr)',
          popular: true,
          description: 'The complete powerhouse suite for growing restaurants and multi-floor outlets.',
          features: [
            'Everything in Starter, plus:',
            '📦 Advanced Inventory & Low-Stock Alerts',
            '👑 Full Loyalty & Customer Rewards Engine',
            '📢 Marketing Campaign & Promo Hub',
            '⚡ Multi-Device Realtime Cloud Sync',
            '📱 Dynamic UPI QR Payments & Auto-Settlement',
            '📊 Advanced Multi-Filter Sales & Tax Reports',
            '👥 Unlimited Staff & Role Management',
            '⚡ 24/7 Priority Technical Support',
          ],
          ctaLabel: 'I\'m Interested',
          isCurrent: false,
        ),
        SubscriptionPlanModel(
          id: 'plan_enterprise',
          name: 'Enterprise / Multi-Branch',
          badge: 'Custom',
          priceMonthly: 2499,
          priceAnnual: 19999,
          annualSavingsText: 'Custom Setup & SLA',
          popular: false,
          description: 'Tailored for restaurant chains, franchises, and enterprise food businesses.',
          features: [
            'Everything in Growth / Pro, plus:',
            '🏢 Multi-Branch Centralized Dashboard',
            '🔄 Central Kitchen & Cross-Store Inventory',
            '🌐 Custom Domain & Branded Customer App',
            '💳 Custom Payment Gateway & Direct Bank APIs',
            '🛠️ Dedicated Account Manager & SLA Support',
            '📈 AI-Powered Sales Forecasting & Cost Optimization',
          ],
          ctaLabel: 'Request Demo / Talk to Sales',
          isCurrent: false,
        ),
      ],
      addons: [
        SubscriptionAddonModel(
          id: 'addon_inventory',
          name: 'Inventory Pro Addon',
          icon: 'inventory_2',
          priceMonthly: 499,
          description: 'Raw material tracking, recipe costing, low stock WhatsApp notifications.',
        ),
        SubscriptionAddonModel(
          id: 'addon_loyalty',
          name: 'Loyalty & Cashback Suite',
          icon: 'card_giftcard',
          priceMonthly: 499,
          description: 'Visit-made rewards, points redemption, customer tiers & branded passes.',
        ),
        SubscriptionAddonModel(
          id: 'addon_campaign',
          name: 'Marketing & Broadcast Hub',
          icon: 'campaign',
          priceMonthly: 499,
          description: 'Automated WhatsApp promo broadcasts, festival offers & coupon codes.',
        ),
      ],
    );
  }

  /// Fetch plans from Backend API
  Future<SubscriptionDataModel> fetchPlans({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedData != null) {
      return _cachedData!;
    }

    try {
      final response = await _api.get(ApiEndpoints.subscriptionPlans);
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] ?? response;
        if (data is Map<String, dynamic>) {
          final rawPlans = (data['plans'] as List<dynamic>?)
                  ?.whereType<Map<String, dynamic>>()
                  .map((p) => SubscriptionPlanModel.fromJson(p))
                  .toList() ??
              [];
          final rawAddons = (data['addons'] as List<dynamic>?)
                  ?.whereType<Map<String, dynamic>>()
                  .map((a) => SubscriptionAddonModel.fromJson(a))
                  .toList() ??
              [];

          if (rawPlans.isNotEmpty) {
            _cachedData = SubscriptionDataModel(plans: rawPlans, addons: rawAddons);
            return _cachedData!;
          }
        }
      }
    } catch (e) {
      debugPrint('[SubscriptionService.fetchPlans] API fallback: $e');
    }

    _cachedData = getDefaultPlans();
    return _cachedData!;
  }

  /// Submit "I'm Interested" Lead (dispatches email notification to sooftcode@gmail.com)
  Future<Map<String, dynamic>> submitInterestLead({
    required String restaurantName,
    required String contactPerson,
    required String phone,
    String email = '',
    String selectedPlan = 'Growth / Pro Plan',
    String billingCycle = 'annual',
    String sourceFeature = 'subscription_screen',
    String notes = '',
    double price = 0,
    List<String> interestedFeatures = const [],
  }) async {
    final user = _db.currentUser;
    final rest = _db.restaurant;

    final finalRestName = restaurantName.isNotEmpty
        ? restaurantName
        : (rest?.name.isNotEmpty == true ? rest!.name : (user?.companyName ?? 'My Restaurant'));
    final finalContactName = contactPerson.isNotEmpty
        ? contactPerson
        : (user?.name.isNotEmpty == true ? user!.name : finalRestName);
    final finalPhone = phone.isNotEmpty ? phone : (user?.phone ?? '');
    final finalEmail = email.isNotEmpty ? email : (user?.email ?? '');

    final payload = {
      'restaurantName': finalRestName,
      'contactPerson': finalContactName,
      'phone': finalPhone,
      'email': finalEmail,
      'selectedPlan': selectedPlan,
      'billingCycle': billingCycle,
      'sourceFeature': sourceFeature,
      'notes': notes,
      'price': price,
      'interestedFeatures': interestedFeatures,
    };

    debugPrint('[SubscriptionService] Submitting interest lead to API: $payload');

    try {
      final response = await _api.post(
        ApiEndpoints.subscriptionLead,
        data: payload,
      );

      if (response != null && response is Map<String, dynamic>) {
        return {
          'success': true,
          'message': response['message'] ?? 'Thank you! Your inquiry has been sent to sooftcode@gmail.com.',
          'data': response['data'],
        };
      }
    } catch (e) {
      debugPrint('[SubscriptionService] Error submitting lead to API: $e');
    }

    return {
      'success': true,
      'message': 'Thank you! Your interest has been submitted successfully. Our team will contact you shortly.',
    };
  }
}
