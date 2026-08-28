import 'package:flutter/material.dart';

enum NotificationType {
  welcome,
  newOrder,
  newLead,
  dailySalesSummary,
  lowStock,
  system,
}

enum NotificationTarget {
  dashboard,
  orderDetails,
  crmLead,
  salesReport,
  inventory,
  none,
}

class NotificationItem {
  final String id;
  final String? userId;
  final String? businessId;
  final String title;
  final String message;
  final NotificationType type;
  final String rawType;
  final DateTime timestamp;
  bool isRead;
  final DateTime? readAt;
  final String entityType;
  final String? entityId;
  final Map<String, dynamic> metadata;

  NotificationItem({
    required this.id,
    this.userId,
    this.businessId,
    required this.title,
    required this.message,
    required this.type,
    required this.rawType,
    required this.timestamp,
    this.isRead = false,
    this.readAt,
    this.entityType = 'system',
    this.entityId,
    this.metadata = const {},
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] ?? json['notificationType'] ?? 'system').toString();

    NotificationType type;
    switch (rawType.toLowerCase()) {
      case 'welcome':
        type = NotificationType.welcome;
        break;
      case 'new_order':
      case 'order':
        type = NotificationType.newOrder;
        break;
      case 'new_lead':
      case 'crm':
      case 'lead':
        type = NotificationType.newLead;
        break;
      case 'daily_sales_summary':
      case 'summary':
      case 'daily_summary':
        type = NotificationType.dailySalesSummary;
        break;
      case 'low_stock':
      case 'inventory':
        type = NotificationType.lowStock;
        break;
      default:
        type = NotificationType.system;
    }

    DateTime timestamp;
    if (json['createdAt'] != null) {
      timestamp = DateTime.tryParse(json['createdAt'].toString())?.toLocal() ?? DateTime.now();
    } else if (json['timestamp'] != null) {
      timestamp = DateTime.tryParse(json['timestamp'].toString())?.toLocal() ?? DateTime.now();
    } else {
      timestamp = DateTime.now();
    }

    DateTime? readAt;
    if (json['readAt'] != null) {
      readAt = DateTime.tryParse(json['readAt'].toString())?.toLocal();
    }

    Map<String, dynamic> meta = {};
    if (json['metadata'] != null && json['metadata'] is Map) {
      meta = Map<String, dynamic>.from(json['metadata'] as Map);
    }

    return NotificationItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      userId: json['userId']?.toString(),
      businessId: json['businessId']?.toString(),
      title: (json['title'] ?? 'Notification').toString(),
      message: (json['message'] ?? '').toString(),
      type: type,
      rawType: rawType,
      timestamp: timestamp,
      isRead: json['isRead'] == true,
      readAt: readAt,
      entityType: (json['entityType'] ?? 'system').toString(),
      entityId: json['entityId']?.toString(),
      metadata: meta,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'businessId': businessId,
        'title': title,
        'message': message,
        'type': rawType,
        'rawType': rawType,
        'createdAt': timestamp.toIso8601String(),
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'readAt': readAt?.toIso8601String(),
        'entityType': entityType,
        'entityId': entityId,
        'metadata': metadata,
      };

  NotificationTarget get target {
    switch (type) {
      case NotificationType.newOrder:
        return NotificationTarget.orderDetails;
      case NotificationType.newLead:
        return NotificationTarget.crmLead;
      case NotificationType.dailySalesSummary:
        return NotificationTarget.salesReport;
      case NotificationType.welcome:
        return NotificationTarget.dashboard;
      case NotificationType.lowStock:
        return NotificationTarget.inventory;
      case NotificationType.system:
        return NotificationTarget.none;
    }
  }

  IconData get icon {
    switch (type) {
      case NotificationType.welcome:
        return Icons.celebration_rounded;
      case NotificationType.newOrder:
        return Icons.shopping_bag_outlined;
      case NotificationType.newLead:
        return Icons.person_add_alt_1_rounded;
      case NotificationType.dailySalesSummary:
        return Icons.bar_chart_rounded;
      case NotificationType.lowStock:
        return Icons.inventory_2_outlined;
      case NotificationType.system:
        return Icons.notifications_active_outlined;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.welcome:
        return const Color(0xFF082559);
      case NotificationType.newOrder:
        return const Color(0xFF10B981);
      case NotificationType.newLead:
        return const Color(0xFF0284C7);
      case NotificationType.dailySalesSummary:
        return const Color(0xFFF59E0B);
      case NotificationType.lowStock:
        return const Color(0xFFEF4444);
      case NotificationType.system:
        return const Color(0xFF8B5CF6);
    }
  }
}
