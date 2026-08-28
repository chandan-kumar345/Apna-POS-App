import 'package:flutter/material.dart';

enum LoyaltyType {
  visitMade,
  amountSpent,
  cashback,
  custom,
}

class RewardMilestoneModel {
  final String id;
  final String label;
  final double value;
  final String iconName;
  final String rewardText;
  final double rewardValue;

  RewardMilestoneModel({
    required this.id,
    required this.label,
    required this.value,
    this.iconName = 'cookie',
    this.rewardText = '',
    this.rewardValue = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'value': value,
        'iconName': iconName,
        'rewardText': rewardText,
        'rewardValue': rewardValue,
      };

  factory RewardMilestoneModel.fromJson(Map<String, dynamic> json) {
    return RewardMilestoneModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '${json['value'] ?? ''} Cookie',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      iconName: json['iconName']?.toString() ?? 'cookie',
      rewardText: json['rewardText']?.toString() ?? '',
      rewardValue: (json['rewardValue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CashbackDetailsModel {
  final double percentage;
  final double minSpend;
  final String headline;
  final String subtext;
  final String termsNote;
  final String billRewardText;
  final String slabTitle;
  final String goal;
  final String reward;
  final double progressPercent;

  CashbackDetailsModel({
    this.percentage = 10.0,
    this.minSpend = 500.0,
    this.headline = '10% Cashback on sales',
    this.subtext = 'On min. spend of ₹500',
    this.termsNote = 'Cashback will be credited when another coupon or offer is already applied.',
    this.billRewardText = 'Rs 500+ bill earns 10% cashback',
    this.slabTitle = 'STARTER REWARD',
    this.goal = 'On min purchase of Rs 500',
    this.reward = '🎁 Earn 10% cashback',
    this.progressPercent = 65.0,
  });

  Map<String, dynamic> toJson() => {
        'percentage': percentage,
        'minSpend': minSpend,
        'headline': headline,
        'subtext': subtext,
        'termsNote': termsNote,
        'billRewardText': billRewardText,
        'slabTitle': slabTitle,
        'goal': goal,
        'reward': reward,
        'progressPercent': progressPercent,
      };

  factory CashbackDetailsModel.fromJson(Map<String, dynamic> json) {
    return CashbackDetailsModel(
      percentage: (json['percentage'] as num?)?.toDouble() ?? 10.0,
      minSpend: (json['minSpend'] as num?)?.toDouble() ?? 500.0,
      headline: json['headline']?.toString() ?? '10% Cashback on sales',
      subtext: json['subtext']?.toString() ?? 'On min. spend of ₹500',
      termsNote: json['termsNote']?.toString() ??
          'Cashback will be credited when another coupon or offer is already applied.',
      billRewardText: json['billRewardText']?.toString() ?? 'Rs 500+ bill earns 10% cashback',
      slabTitle: json['slabTitle']?.toString() ?? 'STARTER REWARD',
      goal: json['goal']?.toString() ?? 'On min purchase of Rs 500',
      reward: json['reward']?.toString() ?? '🎁 Earn 10% cashback',
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 65.0,
    );
  }
}

class LoyaltyProgramModel {
  final String id;
  final LoyaltyType type;
  final String title;
  final String description;
  final String earningRule;
  final String rewardCurrency;
  final List<RewardMilestoneModel> milestones;
  final CashbackDetailsModel? cashbackDetails;
  final List<String> gradientColors;
  final bool isActive;
  final int orderIndex;

  LoyaltyProgramModel({
    required this.id,
    required this.type,
    required this.title,
    this.description = 'Get rewarded on every purchase',
    required this.earningRule,
    this.rewardCurrency = 'Cookie',
    this.milestones = const [],
    this.cashbackDetails,
    this.gradientColors = const ['#580B3B', '#8E1449'],
    this.isActive = true,
    this.orderIndex = 0,
  });

  List<Color> get parsedGradientColors {
    if (gradientColors.isEmpty) {
      return [const Color(0xFF580B3B), const Color(0xFF8E1449)];
    }
    return gradientColors.map((hex) {
      try {
        final clean = hex.replaceAll('#', '');
        return Color(int.parse('FF$clean', radix: 16));
      } catch (_) {
        return const Color(0xFF580B3B);
      }
    }).toList();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type == LoyaltyType.visitMade
            ? 'visit_made'
            : type == LoyaltyType.amountSpent
                ? 'amount_spent'
                : type == LoyaltyType.cashback
                    ? 'cashback'
                    : 'custom',
        'title': title,
        'description': description,
        'earningRule': earningRule,
        'rewardCurrency': rewardCurrency,
        'milestones': milestones.map((m) => m.toJson()).toList(),
        'cashbackDetails': cashbackDetails?.toJson(),
        'gradientColors': gradientColors,
        'isActive': isActive,
        'orderIndex': orderIndex,
      };

  factory LoyaltyProgramModel.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] ?? '').toString().toLowerCase();
    LoyaltyType parsedType;
    if (rawType.contains('visit') || rawType == 'visit_made') {
      parsedType = LoyaltyType.visitMade;
    } else if (rawType.contains('amount') || rawType.contains('spent') || rawType == 'amount_spent') {
      parsedType = LoyaltyType.amountSpent;
    } else if (rawType.contains('cashback')) {
      parsedType = LoyaltyType.cashback;
    } else {
      parsedType = LoyaltyType.custom;
    }

    final rawMilestones = json['milestones'] as List?;
    final milestonesList = rawMilestones != null
        ? rawMilestones
            .whereType<Map<String, dynamic>>()
            .map((m) => RewardMilestoneModel.fromJson(m))
            .toList()
        : <RewardMilestoneModel>[];

    CashbackDetailsModel? cbDetails;
    if (json['cashbackDetails'] is Map<String, dynamic>) {
      cbDetails = CashbackDetailsModel.fromJson(json['cashbackDetails'] as Map<String, dynamic>);
    } else if (parsedType == LoyaltyType.cashback) {
      cbDetails = CashbackDetailsModel();
    }

    final rawColors = json['gradientColors'] as List?;
    final colorsList = rawColors != null
        ? rawColors.map((c) => c.toString()).toList()
        : (parsedType == LoyaltyType.visitMade
            ? ['#3A002A', '#8E1449']
            : parsedType == LoyaltyType.amountSpent
                ? ['#6B0505', '#C81A1A']
                : ['#0A425C', '#1E3A8A']);

    return LoyaltyProgramModel(
      id: json['id']?.toString() ?? '',
      type: parsedType,
      title: json['title']?.toString() ?? (parsedType == LoyaltyType.visitMade ? 'Visit Made' : parsedType == LoyaltyType.amountSpent ? 'Amount Spent' : 'Cashback'),
      description: json['description']?.toString() ?? (parsedType == LoyaltyType.cashback ? 'Get rewarded on every step' : 'Get rewarded on every purchase'),
      earningRule: json['earningRule']?.toString() ?? '',
      rewardCurrency: json['rewardCurrency']?.toString() ?? 'Cookie',
      milestones: milestonesList,
      cashbackDetails: cbDetails,
      gradientColors: colorsList,
      isActive: json['isActive'] != false,
      orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
    );
  }
}

class LoyaltyBrandingModel {
  final String companyName;
  final String companyLogo;
  final List<LoyaltyProgramModel> programs;

  LoyaltyBrandingModel({
    required this.companyName,
    required this.companyLogo,
    required this.programs,
  });

  factory LoyaltyBrandingModel.fromJson(Map<String, dynamic> json) {
    final rawPrograms = json['programs'] as List?;
    final programsList = rawPrograms != null
        ? rawPrograms
            .whereType<Map<String, dynamic>>()
            .map((p) => LoyaltyProgramModel.fromJson(p))
            .toList()
        : <LoyaltyProgramModel>[];

    return LoyaltyBrandingModel(
      companyName: json['companyName']?.toString() ?? '',
      companyLogo: json['companyLogo']?.toString() ?? '',
      programs: programsList,
    );
  }
}

class LoyaltyPerformanceModel {
  final int totalMembers;
  final int activeMembers;
  final int rewardsClaimed;
  final String repeatVisitRate;
  final int totalPointsIssued;
  final double totalCashbackGiven;
  final double loyaltyRevenue;
  final String roiPercentage;

  LoyaltyPerformanceModel({
    this.totalMembers = 0,
    this.activeMembers = 0,
    this.rewardsClaimed = 0,
    this.repeatVisitRate = '0%',
    this.totalPointsIssued = 0,
    this.totalCashbackGiven = 0.0,
    this.loyaltyRevenue = 0.0,
    this.roiPercentage = '0%',
  });

  factory LoyaltyPerformanceModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyPerformanceModel(
      totalMembers: (json['totalMembers'] as num?)?.toInt() ?? 0,
      activeMembers: (json['activeMembers'] as num?)?.toInt() ?? 0,
      rewardsClaimed: (json['rewardsClaimed'] as num?)?.toInt() ?? 0,
      repeatVisitRate: json['repeatVisitRate']?.toString() ?? '42.5%',
      totalPointsIssued: (json['totalPointsIssued'] as num?)?.toInt() ?? 0,
      totalCashbackGiven: (json['totalCashbackGiven'] as num?)?.toDouble() ?? 0.0,
      loyaltyRevenue: (json['loyaltyRevenue'] as num?)?.toDouble() ?? 0.0,
      roiPercentage: json['roiPercentage']?.toString() ?? '315%',
    );
  }
}

class RewardStageModel {
  final String id;
  final int visitCount;
  final String rewardType;
  final double rewardValue;
  final double minimumPurchase;
  final int expiryDays;
  final String freeItemName;
  final String discountScope;
  final bool minSpendRedemptionEnabled;
  final List<String> applicableProductIds;

  RewardStageModel({
    required this.id,
    required this.visitCount,
    this.rewardType = 'Redeem cash discount',
    required this.rewardValue,
    this.minimumPurchase = 100.0,
    this.expiryDays = 30,
    this.freeItemName = '',
    this.discountScope = 'Whole bill',
    this.minSpendRedemptionEnabled = false,
    this.applicableProductIds = const [],
  });

  String get rewardDisplayTitle {
    if (rewardType.contains('Free') || rewardType.toLowerCase().contains('free item')) {
      return freeItemName.isNotEmpty ? freeItemName : 'Free Item';
    } else if (rewardType.contains('%') || rewardType.toLowerCase().contains('percent')) {
      final valStr = rewardValue.truncateToDouble() == rewardValue ? rewardValue.toInt().toString() : rewardValue.toStringAsFixed(1);
      return '$valStr% OFF';
    } else if (rewardType.contains('Cashback')) {
      final valStr = rewardValue.truncateToDouble() == rewardValue ? rewardValue.toInt().toString() : rewardValue.toStringAsFixed(2);
      return '₹$valStr Cashback';
    } else if (rewardType.contains('Coupon') || rewardType.contains('Voucher')) {
      final valStr = rewardValue.truncateToDouble() == rewardValue ? rewardValue.toInt().toString() : rewardValue.toStringAsFixed(2);
      return '₹$valStr Voucher';
    } else {
      final valStr = rewardValue.truncateToDouble() == rewardValue ? rewardValue.toInt().toString() : rewardValue.toStringAsFixed(2);
      return '₹$valStr OFF';
    }
  }

  String get previewSubtitle {
    if (freeItemName.isNotEmpty) return freeItemName;
    final valStr = rewardValue.truncateToDouble() == rewardValue ? rewardValue.toInt().toString() : rewardValue.toStringAsFixed(2);
    if (rewardType.contains('%') || rewardType.toLowerCase().contains('percent')) {
      return 'Cheers ! $valStr% off on your purchase.';
    } else if (rewardType.contains('Free') || rewardType.toLowerCase().contains('free item')) {
      return 'Cheers ! Enjoy a free item.';
    } else {
      return 'Cheers ! Rs $valStr off on your purchase.';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'visitCount': visitCount,
        'rewardType': rewardType,
        'rewardValue': rewardValue,
        'minimumPurchase': minimumPurchase,
        'expiryDays': expiryDays,
        'freeItemName': freeItemName,
        'discountScope': discountScope,
        'minSpendRedemptionEnabled': minSpendRedemptionEnabled,
        'applicableProductIds': applicableProductIds,
      };

  factory RewardStageModel.fromJson(Map<String, dynamic> json) {
    return RewardStageModel(
      id: json['id']?.toString() ?? '',
      visitCount: (json['visitCount'] as num?)?.toInt() ?? 1,
      rewardType: json['rewardType']?.toString() ?? 'Redeem cash discount',
      rewardValue: (json['rewardValue'] as num?)?.toDouble() ?? 100.0,
      minimumPurchase: (json['minimumPurchase'] as num?)?.toDouble() ?? 100.0,
      expiryDays: (json['expiryDays'] as num?)?.toInt() ?? 30,
      freeItemName: json['freeItemName']?.toString() ?? '',
      discountScope: json['discountScope']?.toString() ?? 'Whole bill',
      minSpendRedemptionEnabled: json['minSpendRedemptionEnabled'] == true,
      applicableProductIds: (json['applicableProductIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }

  RewardStageModel copyWith({
    String? id,
    int? visitCount,
    String? rewardType,
    double? rewardValue,
    double? minimumPurchase,
    int? expiryDays,
    String? freeItemName,
    String? discountScope,
    bool? minSpendRedemptionEnabled,
    List<String>? applicableProductIds,
  }) {
    return RewardStageModel(
      id: id ?? this.id,
      visitCount: visitCount ?? this.visitCount,
      rewardType: rewardType ?? this.rewardType,
      rewardValue: rewardValue ?? this.rewardValue,
      minimumPurchase: minimumPurchase ?? this.minimumPurchase,
      expiryDays: expiryDays ?? this.expiryDays,
      freeItemName: freeItemName ?? this.freeItemName,
      discountScope: discountScope ?? this.discountScope,
      minSpendRedemptionEnabled: minSpendRedemptionEnabled ?? this.minSpendRedemptionEnabled,
      applicableProductIds: applicableProductIds ?? this.applicableProductIds,
    );
  }
}

class VisitRewardConfig {
  final String programName;
  final String slogan;
  final String visitTrigger;
  final double triggerMinSpend;
  final int visitCount;
  final String rewardType;
  final double rewardValue;
  final double minimumPurchase;
  final List<RewardStageModel> rewardStages;
  final String bannerImageUrl;
  final String logoUrl;
  final String orderType;
  final String termsNote;
  final bool minSpendConditionEnabled;
  final double minSpendCondition;
  final bool pointEarningGapEnabled;
  final int pointEarningGap;
  final bool maxCashbackLimitEnabled;
  final double maxCashbackLimit;
  final bool bonusPointsEnabled;
  final double bonusPointsAmount;
  final List<String> bonusRequiredFields;

  VisitRewardConfig({
    this.programName = 'THE ROYAL GARDENIA',
    this.slogan = 'Get rewarded on every purchase',
    this.visitTrigger = 'Every Visit',
    this.triggerMinSpend = 100.0,
    this.visitCount = 3,
    this.rewardType = '₹ Discount',
    this.rewardValue = 100.0,
    this.minimumPurchase = 100.0,
    this.rewardStages = const [],
    this.bannerImageUrl = '',
    this.logoUrl = '',
    this.orderType = 'Dine-In',
    this.termsNote = 'Terms and conditions apply.\nMinimum purchase of ₹100 required.\n3 offers cannot be clubbed.',
    this.minSpendConditionEnabled = false,
    this.minSpendCondition = 0.0,
    this.pointEarningGapEnabled = false,
    this.pointEarningGap = 24,
    this.maxCashbackLimitEnabled = false,
    this.maxCashbackLimit = 0.0,
    this.bonusPointsEnabled = true,
    this.bonusPointsAmount = 100.0,
    this.bonusRequiredFields = const ['name', 'phone', 'gender', 'birthday', 'anniversary'],
  });

  Map<String, dynamic> toJson() => {
        'programName': programName,
        'slogan': slogan,
        'visitTrigger': visitTrigger,
        'triggerMinSpend': triggerMinSpend,
        'visitCount': visitCount,
        'rewardType': rewardType,
        'rewardValue': rewardValue,
        'minimumPurchase': minimumPurchase,
        'rewardStages': rewardStages.map((s) => s.toJson()).toList(),
        'bannerImageUrl': bannerImageUrl,
        'logoUrl': logoUrl,
        'orderType': orderType,
        'termsNote': termsNote,
        'minSpendConditionEnabled': minSpendConditionEnabled,
        'minSpendCondition': minSpendCondition,
        'pointEarningGapEnabled': pointEarningGapEnabled,
        'pointEarningGap': pointEarningGap,
        'maxCashbackLimitEnabled': maxCashbackLimitEnabled,
        'maxCashbackLimit': maxCashbackLimit,
        'bonusPointsEnabled': bonusPointsEnabled,
        'bonusPointsAmount': bonusPointsAmount,
        'bonusRequiredFields': bonusRequiredFields,
      };

  factory VisitRewardConfig.fromJson(Map<String, dynamic> json) {
    final rawStages = json['rewardStages'] as List?;
    final stages = rawStages != null
        ? rawStages
            .whereType<Map<String, dynamic>>()
            .map((s) => RewardStageModel.fromJson(s))
            .toList()
        : <RewardStageModel>[];

    return VisitRewardConfig(
      programName: json['programName']?.toString() ?? 'THE ROYAL GARDENIA',
      slogan: json['slogan']?.toString() ?? 'Get rewarded on every purchase',
      visitTrigger: json['visitTrigger']?.toString() ?? 'Every Visit',
      triggerMinSpend: (json['triggerMinSpend'] as num?)?.toDouble() ?? 100.0,
      visitCount: (json['visitCount'] as num?)?.toInt() ?? 3,
      rewardType: json['rewardType']?.toString() ?? '₹ Discount',
      rewardValue: (json['rewardValue'] as num?)?.toDouble() ?? 100.0,
      minimumPurchase: (json['minimumPurchase'] as num?)?.toDouble() ?? 100.0,
      rewardStages: stages,
      bannerImageUrl: json['bannerImageUrl']?.toString() ?? '',
      logoUrl: json['logoUrl']?.toString() ?? '',
      orderType: json['orderType']?.toString() ?? 'Dine-In',
      termsNote: json['termsNote']?.toString() ??
          'Terms and conditions apply.\nMinimum purchase of ₹100 required.\n3 offers cannot be clubbed.',
      minSpendConditionEnabled: json['minSpendConditionEnabled'] == true,
      minSpendCondition: (json['minSpendCondition'] as num?)?.toDouble() ?? 0.0,
      pointEarningGapEnabled: json['pointEarningGapEnabled'] == true,
      pointEarningGap: (json['pointEarningGap'] as num?)?.toInt() ?? 24,
      maxCashbackLimitEnabled: json['maxCashbackLimitEnabled'] == true,
      maxCashbackLimit: (json['maxCashbackLimit'] as num?)?.toDouble() ?? 0.0,
      bonusPointsEnabled: json['bonusPointsEnabled'] != false,
      bonusPointsAmount: (json['bonusPointsAmount'] as num?)?.toDouble() ?? 100.0,
      bonusRequiredFields: (json['bonusRequiredFields'] as List?)?.map((e) => e.toString()).toList() ??
          const ['name', 'phone', 'gender', 'birthday', 'anniversary'],
    );
  }

  VisitRewardConfig copyWith({
    String? programName,
    String? slogan,
    String? visitTrigger,
    double? triggerMinSpend,
    int? visitCount,
    String? rewardType,
    double? rewardValue,
    double? minimumPurchase,
    List<RewardStageModel>? rewardStages,
    String? bannerImageUrl,
    String? logoUrl,
    String? orderType,
    String? termsNote,
    bool? minSpendConditionEnabled,
    double? minSpendCondition,
    bool? pointEarningGapEnabled,
    int? pointEarningGap,
    bool? maxCashbackLimitEnabled,
    double? maxCashbackLimit,
    bool? bonusPointsEnabled,
    double? bonusPointsAmount,
    List<String>? bonusRequiredFields,
  }) {
    return VisitRewardConfig(
      programName: programName ?? this.programName,
      slogan: slogan ?? this.slogan,
      visitTrigger: visitTrigger ?? this.visitTrigger,
      triggerMinSpend: triggerMinSpend ?? this.triggerMinSpend,
      visitCount: visitCount ?? this.visitCount,
      rewardType: rewardType ?? this.rewardType,
      rewardValue: rewardValue ?? this.rewardValue,
      minimumPurchase: minimumPurchase ?? this.minimumPurchase,
      rewardStages: rewardStages ?? this.rewardStages,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      orderType: orderType ?? this.orderType,
      termsNote: termsNote ?? this.termsNote,
      minSpendConditionEnabled: minSpendConditionEnabled ?? this.minSpendConditionEnabled,
      minSpendCondition: minSpendCondition ?? this.minSpendCondition,
      pointEarningGapEnabled: pointEarningGapEnabled ?? this.pointEarningGapEnabled,
      pointEarningGap: pointEarningGap ?? this.pointEarningGap,
      maxCashbackLimitEnabled: maxCashbackLimitEnabled ?? this.maxCashbackLimitEnabled,
      maxCashbackLimit: maxCashbackLimit ?? this.maxCashbackLimit,
    );
  }
}

class AvailableRewardStageModel {
  final String id;
  final int requiredPoints;
  final String rewardType;
  final double rewardValue;
  final double minimumPurchase;
  final String freeItemName;
  final bool isUnlocked;

  AvailableRewardStageModel({
    required this.id,
    required this.requiredPoints,
    this.rewardType = '₹ Discount',
    required this.rewardValue,
    this.minimumPurchase = 100.0,
    required this.freeItemName,
    required this.isUnlocked,
  });

  factory AvailableRewardStageModel.fromJson(Map<String, dynamic> json) {
    return AvailableRewardStageModel(
      id: json['id']?.toString() ?? '',
      requiredPoints: (json['requiredPoints'] as num?)?.toInt() ?? 0,
      rewardType: json['rewardType']?.toString() ?? '₹ Discount',
      rewardValue: (json['rewardValue'] as num?)?.toDouble() ?? 100.0,
      minimumPurchase: (json['minimumPurchase'] as num?)?.toDouble() ?? 100.0,
      freeItemName: json['freeItemName']?.toString() ?? '',
      isUnlocked: json['isUnlocked'] == true,
    );
  }
}

class CustomerLoyaltyModel {
  final String customerPhone;
  final String customerName;
  final int pointsBalance;
  final int totalVisits;
  final int totalPointsEarned;
  final int totalPointsRedeemed;
  final String pointsName;
  final String programName;
  final List<String> unlockedStages;
  final List<AvailableRewardStageModel> availableStages;

  CustomerLoyaltyModel({
    required this.customerPhone,
    this.customerName = '',
    this.pointsBalance = 0,
    this.totalVisits = 0,
    this.totalPointsEarned = 0,
    this.totalPointsRedeemed = 0,
    this.pointsName = 'Cookie',
    this.programName = 'THE ROYAL GARDENIA',
    this.unlockedStages = const [],
    this.availableStages = const [],
  });

  bool get hasUnlockedStages => availableStages.any((s) => s.isUnlocked);

  List<AvailableRewardStageModel> get claimableStages =>
      availableStages.where((s) => s.isUnlocked).toList();

  factory CustomerLoyaltyModel.fromJson(Map<String, dynamic> json) {
    final rawStages = json['availableStages'] as List?;
    final stages = rawStages != null
        ? rawStages
            .whereType<Map<String, dynamic>>()
            .map((s) => AvailableRewardStageModel.fromJson(s))
            .toList()
        : <AvailableRewardStageModel>[];

    final rawUnlocked = json['unlockedStages'] as List?;
    final unlocked = rawUnlocked != null
        ? rawUnlocked.map((e) => e.toString()).toList()
        : <String>[];

    return CustomerLoyaltyModel(
      customerPhone: json['customerPhone']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      pointsBalance: (json['pointsBalance'] as num?)?.toInt() ?? 0,
      totalVisits: (json['totalVisits'] as num?)?.toInt() ?? 0,
      totalPointsEarned: (json['totalPointsEarned'] as num?)?.toInt() ?? 0,
      totalPointsRedeemed: (json['totalPointsRedeemed'] as num?)?.toInt() ?? 0,
      pointsName: json['pointsName']?.toString() ?? 'Cookie',
      programName: json['programName']?.toString() ?? 'THE ROYAL GARDENIA',
      unlockedStages: unlocked,
      availableStages: stages,
    );
  }
}

