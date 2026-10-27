/// High-level Dashboard statistics
class CampaignStatsModel {
  final int totalCampaigns;
  final int messagesSent;
  final double deliveryRate;
  final double totalSpent;
  final int allCount;
  final int marketingCount;
  final int utilityCount;
  final int scheduledCount;
  final int runningCount;
  final int completedCount;

  const CampaignStatsModel({
    this.totalCampaigns = 24,
    this.messagesSent = 12450,
    this.deliveryRate = 92.4,
    this.totalSpent = 1125.30,
    this.allCount = 24,
    this.marketingCount = 14,
    this.utilityCount = 6,
    this.scheduledCount = 4,
    this.runningCount = 2,
    this.completedCount = 18,
  });

  factory CampaignStatsModel.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'] as Map<String, dynamic>? ?? {};
    return CampaignStatsModel(
      totalCampaigns: (json['totalCampaigns'] as num?)?.toInt() ?? 24,
      messagesSent: (json['messagesSent'] as num?)?.toInt() ?? 12450,
      deliveryRate: (json['deliveryRate'] as num?)?.toDouble() ?? 92.4,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 1125.30,
      allCount: (counts['all'] as num?)?.toInt() ?? 24,
      marketingCount: (counts['marketing'] as num?)?.toInt() ?? 14,
      utilityCount: (counts['utility'] as num?)?.toInt() ?? 6,
      scheduledCount: (counts['scheduled'] as num?)?.toInt() ?? 4,
      runningCount: (counts['running'] as num?)?.toInt() ?? 2,
      completedCount: (counts['completed'] as num?)?.toInt() ?? 18,
    );
  }
}

/// Audience group item
class AudienceGroupModel {
  final String id;
  final String name;
  final int count;
  final String description;

  const AudienceGroupModel({
    required this.id,
    required this.name,
    required this.count,
    this.description = '',
  });

  factory AudienceGroupModel.fromJson(Map<String, dynamic> json) {
    return AudienceGroupModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      description: json['description']?.toString() ?? '',
    );
  }
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

/// WhatsApp template model
class CampaignTemplateModel {
  final String id;
  final String name;
  final String category; // 'Marketing', 'Utility'
  final String language;
  final String body;
  final String headerText;
  final String footerText;
  final List<String> parameters;

  const CampaignTemplateModel({
    required this.id,
    required this.name,
    this.category = 'Marketing',
    this.language = 'EN',
    this.body = '',
    this.headerText = '',
    this.footerText = '',
    this.parameters = const [],
  });

  factory CampaignTemplateModel.fromJson(Map<String, dynamic> json) {
    final rawParams = json['parameters'] as List<dynamic>? ?? [];
    return CampaignTemplateModel(
      id: json['id']?.toString() ?? json['templateId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Marketing',
      language: json['language']?.toString() ?? 'EN',
      body: json['body']?.toString() ?? '',
      headerText: json['headerText']?.toString() ?? '',
      footerText: json['footerText']?.toString() ?? '',
      parameters: rawParams.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'templateId': id,
        'name': name,
        'category': category,
        'language': language,
        'body': body,
        'parameters': parameters,
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
