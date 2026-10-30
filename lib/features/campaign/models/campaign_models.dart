/// High-level Dashboard statistics
class CampaignStatsModel {
  final int totalCampaigns;
  final int messagesSent;
  final double deliveryRate;
  final double totalSpent;
  final int draftCount;
  final int approvedCount;
  final int scheduledCount;
  final int pendingCount;
  final int rejectedCount;
  final double walletBalance;
  final int allCount;
  final int marketingCount;
  final int utilityCount;
  final int runningCount;
  final int completedCount;

  const CampaignStatsModel({
    this.totalCampaigns = 0,
    this.messagesSent = 0,
    this.deliveryRate = 0.0,
    this.totalSpent = 0.0,
    this.draftCount = 36,
    this.approvedCount = 12,
    this.scheduledCount = 5,
    this.pendingCount = 3,
    this.rejectedCount = 0,
    this.walletBalance = 7250.50,
    this.allCount = 0,
    this.marketingCount = 0,
    this.utilityCount = 0,
    this.runningCount = 0,
    this.completedCount = 0,
  });

  factory CampaignStatsModel.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'] as Map<String, dynamic>? ?? {};
    return CampaignStatsModel(
      totalCampaigns: (json['totalCampaigns'] as num?)?.toInt() ?? 0,
      messagesSent: (json['messagesSent'] as num?)?.toInt() ?? 0,
      deliveryRate: (json['deliveryRate'] as num?)?.toDouble() ?? 0.0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
      draftCount: (json['draftCount'] as num?)?.toInt() ?? (counts['drafts'] as num?)?.toInt() ?? 36,
      approvedCount: (json['approvedCount'] as num?)?.toInt() ?? (counts['approved'] as num?)?.toInt() ?? 12,
      scheduledCount: (json['scheduledCount'] as num?)?.toInt() ?? (counts['scheduled'] as num?)?.toInt() ?? 5,
      pendingCount: (json['pendingCount'] as num?)?.toInt() ?? (counts['pending'] as num?)?.toInt() ?? 3,
      rejectedCount: (json['rejectedCount'] as num?)?.toInt() ?? (counts['rejected'] as num?)?.toInt() ?? 0,
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 7250.50,
      allCount: (counts['all'] as num?)?.toInt() ?? 0,
      marketingCount: (counts['marketing'] as num?)?.toInt() ?? 0,
      utilityCount: (counts['utility'] as num?)?.toInt() ?? 0,
      runningCount: (counts['running'] as num?)?.toInt() ?? 0,
      completedCount: (counts['completed'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Contact phone number item in an audience group
class ContactNumberModel {
  final String id;
  final String name;
  final String phone;
  final DateTime? addedAt;

  const ContactNumberModel({
    required this.id,
    required this.name,
    required this.phone,
    this.addedAt,
  });

  factory ContactNumberModel.fromJson(Map<String, dynamic> json) {
    return ContactNumberModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Contact',
      phone: json['phone']?.toString() ?? '',
      addedAt: json['addedAt'] != null ? DateTime.tryParse(json['addedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
      };
}

/// Audience group item (Organize contact groups with a cleaner command center)
class AudienceGroupModel {
  final String id;
  final int srNo;
  final String name;
  final String type; // 'Mobile', 'Customer', 'Excel/CSV', 'Segment'
  final String source; // 'Mobile source', 'POS Customers', etc.
  final String description;
  final int count;
  final int totalNumbers;
  final List<ContactNumberModel> numbers;
  final DateTime? createdAt;

  const AudienceGroupModel({
    required this.id,
    this.srNo = 237,
    required this.name,
    this.type = 'Mobile',
    this.source = 'Mobile source',
    this.description = '',
    this.count = 0,
    this.totalNumbers = 0,
    this.numbers = const [],
    this.createdAt,
  });

  factory AudienceGroupModel.fromJson(Map<String, dynamic> json) {
    final rawNumbers = json['numbers'] as List<dynamic>? ?? [];
    final total = (json['totalNumbers'] as num?)?.toInt() ?? (json['count'] as num?)?.toInt() ?? rawNumbers.length;
    return AudienceGroupModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      srNo: (json['srNo'] as num?)?.toInt() ?? 237,
      name: json['name']?.toString() ?? 'Group',
      type: json['type']?.toString() ?? 'Mobile',
      source: json['source']?.toString() ?? 'Mobile source',
      description: json['description']?.toString() ?? '',
      count: total,
      totalNumbers: total,
      numbers: rawNumbers.map((n) => ContactNumberModel.fromJson(Map<String, dynamic>.from(n as Map))).toList(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'source': source,
        'description': description,
        'numbers': numbers.map((n) => n.toJson()).toList(),
      };
}

/// Audience selection details
class CampaignAudienceModel {
  final String source; // 'all', 'group', 'segment', 'upload', 'manual'
  final String groupName;
  final int recipientCount;

  const CampaignAudienceModel({
    this.source = 'group',
    this.groupName = 'All Customers',
    this.recipientCount = 0,
  });

  factory CampaignAudienceModel.fromJson(Map<String, dynamic> json) {
    return CampaignAudienceModel(
      source: json['source']?.toString() ?? 'group',
      groupName: json['groupName']?.toString() ?? 'All Customers',
      recipientCount: (json['recipientCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'source': source,
        'groupName': groupName,
        'recipientCount': recipientCount,
      };
}

/// Channel selection model
class CampaignChannelModel {
  final String id;
  final String channelType; // 'business_whatsapp', 'softcode_shared'
  final String name;
  final String description;
  final String badge;
  final String businessName;
  final String phoneNumber;
  final String phoneNumberId;
  final bool isConnected;

  const CampaignChannelModel({
    this.id = 'business_whatsapp',
    this.channelType = 'business_whatsapp',
    this.name = 'My Business WhatsApp',
    this.description = 'Send using your connected Meta WhatsApp API',
    this.badge = 'Connected',
    this.businessName = 'Pizza 47',
    this.phoneNumber = '+91 98765 43210',
    this.phoneNumberId = '1284567890123456',
    this.isConnected = true,
  });

  factory CampaignChannelModel.fromJson(Map<String, dynamic> json) {
    return CampaignChannelModel(
      id: json['id']?.toString() ?? json['channelType']?.toString() ?? 'business_whatsapp',
      channelType: json['channelType']?.toString() ?? 'business_whatsapp',
      name: json['name']?.toString() ?? 'My Business WhatsApp',
      description: json['description']?.toString() ?? '',
      badge: json['badge']?.toString() ?? (json['channelType'] == 'softcode_shared' ? 'Default Channel' : 'Connected'),
      businessName: json['businessName']?.toString() ?? 'Pizza 47',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      phoneNumberId: json['phoneNumberId']?.toString() ?? '',
      isConnected: json['isConnected'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'channelType': channelType,
        'name': name,
        'phoneNumber': phoneNumber,
        'phoneNumberId': phoneNumberId,
      };
}

/// WhatsApp & Multi-Channel Meta-Verified template model
class CampaignTemplateModel {
  final String id;
  final String name;
  final String subtitle;
  final String category; // 'Promotional', 'Discount', 'BOGO', 'New Menu', 'Free Gift', 'Festival', 'Re-engagement', 'AI', 'Utility'
  final String channel; // 'whatsapp', 'sms', 'email'
  final String metaStatus; // 'APPROVED', 'PENDING', 'REJECTED'
  final String metaTemplateName;
  final String metaCategory; // 'MARKETING', 'UTILITY'
  final String language;
  final String headerImageUrl;
  final String iconCode; // 'crown', 'tag', 'clock', 'cloche', 'gift', 'refresh'
  final String tagLabel;
  final String tagColor;
  final bool isMetaVerified;
  final String body;
  final String headerText;
  final String footerText;
  final List<String> parameters;
  final List<String> sampleParameters;

  const CampaignTemplateModel({
    required this.id,
    required this.name,
    this.subtitle = '',
    this.category = 'Promotional',
    this.channel = 'whatsapp',
    this.metaStatus = 'APPROVED',
    this.metaTemplateName = '',
    this.metaCategory = 'MARKETING',
    this.language = 'EN',
    this.headerImageUrl = '',
    this.iconCode = 'tag',
    this.tagLabel = 'Promotional',
    this.tagColor = '#10B981',
    this.isMetaVerified = true,
    this.body = '',
    this.headerText = '',
    this.footerText = '',
    this.parameters = const [],
    this.sampleParameters = const [],
  });

  CampaignTemplateModel copyWith({
    String? id,
    String? name,
    String? subtitle,
    String? category,
    String? channel,
    String? metaStatus,
    String? metaTemplateName,
    String? metaCategory,
    String? language,
    String? headerImageUrl,
    String? iconCode,
    String? tagLabel,
    String? tagColor,
    bool? isMetaVerified,
    String? body,
    String? headerText,
    String? footerText,
    List<String>? parameters,
    List<String>? sampleParameters,
  }) {
    return CampaignTemplateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      category: category ?? this.category,
      channel: channel ?? this.channel,
      metaStatus: metaStatus ?? this.metaStatus,
      metaTemplateName: metaTemplateName ?? this.metaTemplateName,
      metaCategory: metaCategory ?? this.metaCategory,
      language: language ?? this.language,
      headerImageUrl: headerImageUrl ?? this.headerImageUrl,
      iconCode: iconCode ?? this.iconCode,
      tagLabel: tagLabel ?? this.tagLabel,
      tagColor: tagColor ?? this.tagColor,
      isMetaVerified: isMetaVerified ?? this.isMetaVerified,
      body: body ?? this.body,
      headerText: headerText ?? this.headerText,
      footerText: footerText ?? this.footerText,
      parameters: parameters ?? this.parameters,
      sampleParameters: sampleParameters ?? this.sampleParameters,
    );
  }

  bool get isApprovedByMeta => metaStatus.toUpperCase() == 'APPROVED' && channel == 'whatsapp';
  String get title => name;
  String get description => subtitle.isNotEmpty ? subtitle : body;

  factory CampaignTemplateModel.fromJson(Map<String, dynamic> json) {
    final rawParams = json['parameters'] as List<dynamic>? ?? [];
    final rawSampleParams = json['sampleParameters'] as List<dynamic>? ?? [];

    return CampaignTemplateModel(
      id: json['id']?.toString() ?? json['templateId']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? json['description']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Promotional',
      channel: json['channel']?.toString() ?? 'whatsapp',
      metaStatus: (json['metaStatus']?.toString() ?? 'APPROVED').toUpperCase(),
      metaTemplateName: json['metaTemplateName']?.toString() ?? '',
      metaCategory: json['metaCategory']?.toString() ?? 'MARKETING',
      language: json['language']?.toString() ?? 'EN',
      headerImageUrl: json['headerImageUrl']?.toString() ?? '',
      iconCode: json['iconCode']?.toString() ?? 'tag',
      tagLabel: json['tagLabel']?.toString() ?? json['category']?.toString() ?? 'Promotional',
      tagColor: json['tagColor']?.toString() ?? '#10B981',
      isMetaVerified: json['isMetaVerified'] ?? (json['channel'] == 'whatsapp' || json['channel'] == null),
      body: json['body']?.toString() ?? '',
      headerText: json['headerText']?.toString() ?? '',
      footerText: json['footerText']?.toString() ?? '',
      parameters: rawParams.map((e) => e.toString()).toList(),
      sampleParameters: rawSampleParams.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'templateId': id,
        'name': name,
        'subtitle': subtitle,
        'category': category,
        'channel': channel,
        'metaStatus': metaStatus,
        'metaTemplateName': metaTemplateName,
        'metaCategory': metaCategory,
        'language': language,
        'headerImageUrl': headerImageUrl,
        'iconCode': iconCode,
        'tagLabel': tagLabel,
        'tagColor': tagColor,
        'isMetaVerified': isMetaVerified,
        'body': body,
        'parameters': parameters,
        'sampleParameters': sampleParameters,
      };
}

/// Cost calculation breakdown
class CampaignCostModel {
  final int messages;
  final double ratePerMessage;
  final double subtotal;
  final double gst;
  final double totalAmount;
  final double spentSoFar;
  final double remaining;

  const CampaignCostModel({
    this.messages = 0,
    this.ratePerMessage = 0.90,
    this.subtotal = 0.0,
    this.gst = 0.0,
    this.totalAmount = 0.0,
    this.spentSoFar = 0.0,
    this.remaining = 0.0,
  });

  factory CampaignCostModel.fromJson(Map<String, dynamic> json) {
    return CampaignCostModel(
      messages: (json['messages'] as num?)?.toInt() ?? 0,
      ratePerMessage: (json['ratePerMessage'] as num?)?.toDouble() ?? 0.90,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      gst: (json['gst'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      spentSoFar: (json['spentSoFar'] as num?)?.toDouble() ?? 0.0,
      remaining: (json['remaining'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'messages': messages,
        'ratePerMessage': ratePerMessage,
        'subtotal': subtotal,
        'gst': gst,
        'totalAmount': totalAmount,
        'spentSoFar': spentSoFar,
        'remaining': remaining,
      };
}

/// Performance & Delivery statistics
class CampaignStatsDetailModel {
  final int totalRecipients;
  final int messagesSent;
  final int delivered;
  final int failed;
  final int read;
  final double deliveryRate;
  final double completionRate;

  const CampaignStatsDetailModel({
    this.totalRecipients = 0,
    this.messagesSent = 0,
    this.delivered = 0,
    this.failed = 0,
    this.read = 0,
    this.deliveryRate = 0.0,
    this.completionRate = 0.0,
  });

  factory CampaignStatsDetailModel.fromJson(Map<String, dynamic> json) {
    return CampaignStatsDetailModel(
      totalRecipients: (json['totalRecipients'] as num?)?.toInt() ?? 0,
      messagesSent: (json['messagesSent'] as num?)?.toInt() ?? 0,
      delivered: (json['delivered'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      read: (json['read'] as num?)?.toInt() ?? 0,
      deliveryRate: (json['deliveryRate'] as num?)?.toDouble() ?? 0.0,
      completionRate: (json['completionRate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Timeline data point for delivery trend chart
class DeliveryTimelinePoint {
  final String time;
  final int sent;
  final int delivered;
  final int failed;

  const DeliveryTimelinePoint({
    required this.time,
    this.sent = 0,
    this.delivered = 0,
    this.failed = 0,
  });

  factory DeliveryTimelinePoint.fromJson(Map<String, dynamic> json) {
    return DeliveryTimelinePoint(
      time: json['time']?.toString() ?? '',
      sent: (json['sent'] as num?)?.toInt() ?? 0,
      delivered: (json['delivered'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Primary Campaign entity
class CampaignRewardDetailsModel {
  final String rewardType; // 'flat_discount', 'percent_discount', 'free_gift', 'bogo', 'cashback'
  final double discountAmount;
  final String discountScope; // 'whole_bill', 'chosen_products'
  final List<Map<String, dynamic>> chosenProducts;
  final bool hasMinSpend;
  final double minSpendAmount;
  final double maxCashbackCap;
  final String comboOfferTitle;
  final String campaignTitle;
  final String description;
  final String bannerImageUrl;
  final String logoUrl;
  final String themeColor;
  final String textColor;
  final String restaurantName;
  final String freeGiftProductId;
  final String freeGiftProductName;
  final double freeGiftProductPrice;
  final List<String> termsAndConditions;

  const CampaignRewardDetailsModel({
    this.rewardType = 'flat_discount',
    this.discountAmount = 300.0,
    this.discountScope = 'whole_bill',
    this.chosenProducts = const [],
    this.hasMinSpend = true,
    this.minSpendAmount = 500.0,
    this.maxCashbackCap = 200.0,
    this.comboOfferTitle = 'Grab Any 2 Combos & Enjoy 10% OFF!',
    this.campaignTitle = 'New Year Special - Flat ₹300 OFF',
    this.description = 'Kick-start the New Year with guaranteed savings. Get a flat ₹300 OFF and enjoy stress-free shopping as you welcome the year with confidence and joy.',
    this.bannerImageUrl = 'assets/images/campaign_hero_banner_full.png',
    this.logoUrl = '',
    this.themeColor = '#E91E63',
    this.textColor = '#FFFFFF',
    this.restaurantName = '',
    this.freeGiftProductId = '',
    this.freeGiftProductName = '',
    this.freeGiftProductPrice = 0.0,
    this.termsAndConditions = const [
      'Minimum purchase required.',
      '2 offers cannot be clubbed.',
    ],
  });

  factory CampaignRewardDetailsModel.fromJson(Map<String, dynamic> json) {
    return CampaignRewardDetailsModel(
      rewardType: json['rewardType']?.toString() ?? 'flat_discount',
      discountAmount: (json['discountAmount'] is num) ? (json['discountAmount'] as num).toDouble() : 300.0,
      discountScope: json['discountScope']?.toString() ?? 'whole_bill',
      chosenProducts: (json['chosenProducts'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      hasMinSpend: json['hasMinSpend'] != false,
      minSpendAmount: (json['minSpendAmount'] is num) ? (json['minSpendAmount'] as num).toDouble() : 500.0,
      maxCashbackCap: (json['maxCashbackCap'] is num) ? (json['maxCashbackCap'] as num).toDouble() : 200.0,
      comboOfferTitle: json['comboOfferTitle']?.toString() ?? '',
      campaignTitle: json['campaignTitle']?.toString() ?? 'New Year Special - Flat ₹300 OFF',
      description: json['description']?.toString() ?? 'Kick-start the New Year with guaranteed savings. Get a flat ₹300 OFF and enjoy stress-free shopping as you welcome the year with confidence and joy.',
      bannerImageUrl: json['bannerImageUrl']?.toString() ?? 'assets/images/campaign_hero_banner_full.png',
      logoUrl: json['logoUrl']?.toString() ?? '',
      themeColor: json['themeColor']?.toString() ?? '#E91E63',
      textColor: json['textColor']?.toString() ?? '#FFFFFF',
      restaurantName: json['restaurantName']?.toString() ?? '',
      freeGiftProductId: json['freeGiftProductId']?.toString() ?? '',
      freeGiftProductName: json['freeGiftProductName']?.toString() ?? '',
      freeGiftProductPrice: (json['freeGiftProductPrice'] is num) ? (json['freeGiftProductPrice'] as num).toDouble() : 0.0,
      termsAndConditions: (json['termsAndConditions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const ['Minimum purchase required.', '2 offers cannot be clubbed.'],
    );
  }

  Map<String, dynamic> toJson() => {
        'rewardType': rewardType,
        'discountAmount': discountAmount,
        'discountScope': discountScope,
        'chosenProducts': chosenProducts,
        'hasMinSpend': hasMinSpend,
        'minSpendAmount': minSpendAmount,
        'maxCashbackCap': maxCashbackCap,
        'comboOfferTitle': comboOfferTitle,
        'campaignTitle': campaignTitle,
        'description': description,
        'bannerImageUrl': bannerImageUrl,
        'logoUrl': logoUrl,
        'themeColor': themeColor,
        'textColor': textColor,
        'restaurantName': restaurantName,
        'freeGiftProductId': freeGiftProductId,
        'freeGiftProductName': freeGiftProductName,
        'freeGiftProductPrice': freeGiftProductPrice,
        'termsAndConditions': termsAndConditions,
      };
}

class CampaignCouponSettingsModel {
  final bool useCustomCouponCode;
  final String customCouponCode;
  final String couponCode;
  final bool hasSendSchedule;
  final DateTime? sendDate;
  final String sendTime;
  final DateTime? scheduledAt;
  final bool hasExpiryDate;
  final DateTime? expiryDate;
  final String redemptionPerCustomer; // 'only_once' | 'multiple_times'
  final int maxRedemptionsPerCustomer;
  final bool displayCouponInProfile;

  const CampaignCouponSettingsModel({
    this.useCustomCouponCode = false,
    this.customCouponCode = '',
    this.couponCode = '',
    this.hasSendSchedule = false,
    this.sendDate,
    this.sendTime = '8:00 AM',
    this.scheduledAt,
    this.hasExpiryDate = true,
    this.expiryDate,
    this.redemptionPerCustomer = 'only_once',
    this.maxRedemptionsPerCustomer = 1,
    this.displayCouponInProfile = false,
  });

  factory CampaignCouponSettingsModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedSend;
    if (json['sendDate'] != null) {
      try {
        parsedSend = DateTime.parse(json['sendDate'].toString());
      } catch (_) {}
    }
    DateTime? parsedExpiry;
    if (json['expiryDate'] != null) {
      try {
        parsedExpiry = DateTime.parse(json['expiryDate'].toString());
      } catch (_) {}
    }
    DateTime? parsedScheduledAt;
    if (json['scheduledAt'] != null) {
      try {
        parsedScheduledAt = DateTime.parse(json['scheduledAt'].toString());
      } catch (_) {}
    }

    return CampaignCouponSettingsModel(
      useCustomCouponCode: json['useCustomCouponCode'] == true,
      customCouponCode: json['customCouponCode']?.toString() ?? '',
      couponCode: json['couponCode']?.toString() ?? '',
      hasSendSchedule: json['hasSendSchedule'] == true,
      sendDate: parsedSend,
      sendTime: json['sendTime']?.toString() ?? '8:00 AM',
      scheduledAt: parsedScheduledAt,
      hasExpiryDate: json['hasExpiryDate'] != false,
      expiryDate: parsedExpiry,
      redemptionPerCustomer: json['redemptionPerCustomer']?.toString() ?? 'only_once',
      maxRedemptionsPerCustomer: (json['maxRedemptionsPerCustomer'] is num) ? (json['maxRedemptionsPerCustomer'] as num).toInt() : 1,
      displayCouponInProfile: json['displayCouponInProfile'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'useCustomCouponCode': useCustomCouponCode,
        'customCouponCode': customCouponCode,
        'couponCode': couponCode,
        'hasSendSchedule': hasSendSchedule,
        'sendDate': sendDate?.toIso8601String(),
        'sendTime': sendTime,
        'scheduledAt': scheduledAt?.toIso8601String(),
        'hasExpiryDate': hasExpiryDate,
        'expiryDate': expiryDate?.toIso8601String(),
        'redemptionPerCustomer': redemptionPerCustomer,
        'maxRedemptionsPerCustomer': maxRedemptionsPerCustomer,
        'displayCouponInProfile': displayCouponInProfile,
      };
}

class CampaignModel {
  final String id;
  final String campaignId;
  final String name;
  final String type; // 'marketing' | 'utility'
  final String status; // 'draft' | 'scheduled' | 'running' | 'completed' | 'paused'
  final CampaignAudienceModel audience;
  final CampaignChannelModel channel;
  final CampaignTemplateModel template;
  final String scheduleMode; // 'now' | 'later' | 'recurring'
  final DateTime? scheduledAt;
  final String estimatedSendingTime;
  final CampaignCostModel cost;
  final CampaignStatsDetailModel stats;
  final CampaignRewardDetailsModel? rewardDetails;
  final CampaignCouponSettingsModel? couponSettings;
  final List<String> orderTypes;
  final List<DeliveryTimelinePoint> deliveryTimeline;
  final DateTime createdAt;

  const CampaignModel({
    required this.id,
    required this.campaignId,
    required this.name,
    this.type = 'marketing',
    this.status = 'draft',
    required this.audience,
    required this.channel,
    required this.template,
    this.scheduleMode = 'now',
    this.scheduledAt,
    this.estimatedSendingTime = '',
    required this.cost,
    required this.stats,
    this.rewardDetails,
    this.couponSettings,
    this.orderTypes = const ['delivery', 'takeaway', 'dine_in'],
    this.deliveryTimeline = const [],
    required this.createdAt,
  });

  bool get isRunning => status.toLowerCase() == 'running';
  bool get isScheduled => status.toLowerCase() == 'scheduled';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isDraft => status.toLowerCase() == 'draft';
  bool get isMarketing => type.toLowerCase() == 'marketing';

  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedCreated;
    try {
      parsedCreated = json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now();
    } catch (_) {
      parsedCreated = DateTime.now();
    }

    DateTime? parsedScheduled;
    if (json['schedule']?['scheduledAt'] != null) {
      try {
        parsedScheduled = DateTime.parse(json['schedule']['scheduledAt'].toString());
      } catch (_) {}
    }

    final rawTimeline = json['deliveryTimeline'] as List<dynamic>? ?? [];

    final rawOrderTypes = json['orderTypes'] as List<dynamic>? ?? ['delivery', 'takeaway', 'dine_in'];

    return CampaignModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      campaignId: json['campaignId']?.toString() ?? '#CMP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      name: json['name']?.toString() ?? 'Campaign',
      type: json['type']?.toString().toLowerCase() ?? 'marketing',
      status: json['status']?.toString().toLowerCase() ?? 'draft',
      audience: CampaignAudienceModel.fromJson(json['audience'] as Map<String, dynamic>? ?? {}),
      channel: CampaignChannelModel.fromJson(json['channel'] as Map<String, dynamic>? ?? {}),
      template: CampaignTemplateModel.fromJson(json['template'] as Map<String, dynamic>? ?? {}),
      scheduleMode: json['schedule']?['mode']?.toString() ?? 'now',
      scheduledAt: parsedScheduled,
      estimatedSendingTime: json['schedule']?['estimatedSendingTime']?.toString() ?? '',
      cost: CampaignCostModel.fromJson(json['cost'] as Map<String, dynamic>? ?? {}),
      stats: CampaignStatsDetailModel.fromJson(json['stats'] as Map<String, dynamic>? ?? {}),
      rewardDetails: json['rewardDetails'] != null
          ? CampaignRewardDetailsModel.fromJson(json['rewardDetails'] as Map<String, dynamic>)
          : null,
      couponSettings: json['couponSettings'] != null
          ? CampaignCouponSettingsModel.fromJson(json['couponSettings'] as Map<String, dynamic>)
          : null,
      orderTypes: rawOrderTypes.map((e) => e.toString()).toList(),
      deliveryTimeline: rawTimeline.map((e) => DeliveryTimelinePoint.fromJson(e as Map<String, dynamic>)).toList(),
      createdAt: parsedCreated,
    );
  }
}

/// Auto Campaign Entity
class AutoCampaignModel {
  final String id;
  final String name;
  final String trigger; // 'birthday', 'new_customer', 'inactive_x_days', 'post_purchase', 'loyalty_points', 'custom_date'
  final String customerType;
  final String orderCountCondition;
  final int orderCountValue;
  final String lastOrderCondition;
  final int lastOrderDays;
  final String customerGroup;
  final bool sendOnlyOnce;
  final String channelName;
  final String templateName;
  final String sendTiming;
  final bool isActive;

  const AutoCampaignModel({
    required this.id,
    required this.name,
    this.trigger = 'birthday',
    this.customerType = 'All Customers',
    this.orderCountCondition = 'greater_than',
    this.orderCountValue = 0,
    this.lastOrderCondition = 'more_than',
    this.lastOrderDays = 30,
    this.customerGroup = 'VIP Customers',
    this.sendOnlyOnce = true,
    this.channelName = 'Pizza 47',
    this.templateName = 'Birthday Offer',
    this.sendTiming = '10:00 AM',
    this.isActive = true,
  });

  factory AutoCampaignModel.fromJson(Map<String, dynamic> json) {
    final cond = json['conditions'] as Map<String, dynamic>? ?? {};
    return AutoCampaignModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Auto Campaign',
      trigger: json['trigger']?.toString() ?? 'birthday',
      customerType: cond['customerType']?.toString() ?? 'All Customers',
      orderCountCondition: cond['orderCountCondition']?.toString() ?? 'greater_than',
      orderCountValue: (cond['orderCountValue'] as num?)?.toInt() ?? 0,
      lastOrderCondition: cond['lastOrderCondition']?.toString() ?? 'more_than',
      lastOrderDays: (cond['lastOrderDays'] as num?)?.toInt() ?? 30,
      customerGroup: cond['customerGroup']?.toString() ?? 'VIP Customers',
      sendOnlyOnce: cond['sendOnlyOnce'] ?? true,
      channelName: json['channel']?['name']?.toString() ?? 'Pizza 47',
      templateName: json['template']?['name']?.toString() ?? 'Birthday Offer',
      sendTiming: json['sendTiming']?.toString() ?? '10:00 AM',
      isActive: json['isActive'] ?? true,
    );
  }
}
