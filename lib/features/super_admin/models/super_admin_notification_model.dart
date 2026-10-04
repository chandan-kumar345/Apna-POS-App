import 'package:flutter/material.dart';

enum PlatformNotificationType {
  systemAnnouncement('System Announcement', Icons.campaign_rounded, Color(0xFF0052FF)),
  subscriptionReminder('Subscription Reminder', Icons.schedule_rounded, Color(0xFFF59E0B)),
  paymentReminder('Payment Reminder', Icons.payment_rounded, Color(0xFFEF4444)),
  maintenance('Platform Maintenance', Icons.build_circle_rounded, Color(0xFF64748B)),
  featureAnnouncement('Feature Release', Icons.auto_awesome_rounded, Color(0xFF10B981));

  final String label;
  final IconData icon;
  final Color color;
  const PlatformNotificationType(this.label, this.icon, this.color);
}

enum NotificationTarget {
  allUsers('All Users'),
  allBusinesses('All Businesses'),
  specificPlan('Specific Plan Subscribers'),
  specificBusiness('Specific Business'),
  specificUser('Specific User'),
  expiringSubscriptions('Expiring Subscriptions (7 Days)');

  final String label;
  const NotificationTarget(this.label);
}

class PlatformBroadcastNotification {
  final String id;
  final String title;
  final String message;
  final PlatformNotificationType type;
  final NotificationTarget targetAudience;
  final String? targetValue; // Plan ID or Business ID if targeted
  final DateTime sentAt;
  final String sentBy;
  final int totalRecipients;
  final int readCount;

  const PlatformBroadcastNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.targetAudience,
    this.targetValue,
    required this.sentAt,
    required this.sentBy,
    required this.totalRecipients,
    this.readCount = 0,
  });
}
