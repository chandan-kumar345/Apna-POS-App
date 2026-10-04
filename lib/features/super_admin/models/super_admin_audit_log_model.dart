import 'package:flutter/material.dart';

enum AuditTargetType {
  business('Business', Icons.storefront_rounded, Color(0xFF0052FF)),
  user('User', Icons.person_rounded, Color(0xFF0EA5E9)),
  subscription('Subscription', Icons.card_membership_rounded, Color(0xFF10B981)),
  plan('Plan', Icons.layers_rounded, Color(0xFF6366F1)),
  payment('Payment', Icons.receipt_long_rounded, Color(0xFFF59E0B)),
  module('Module', Icons.extension_rounded, Color(0xFF8B5CF6)),
  system('System', Icons.settings_rounded, Color(0xFF64748B));

  final String label;
  final IconData icon;
  final Color color;
  const AuditTargetType(this.label, this.icon, this.color);
}

/// Immutable Super Admin Audit Log Record
class AuditLogRecord {
  final String id;
  final String adminId;
  final String adminName;
  final String adminRole;
  final String action; // e.g. "Extended Subscription", "Suspended Business", "Created Plan"
  final AuditTargetType targetType;
  final String targetName;
  final String targetId;
  final String details;
  final String? previousValue;
  final String? newValue;
  final DateTime timestamp;
  final String ipAddress;

  const AuditLogRecord({
    required this.id,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
    required this.action,
    required this.targetType,
    required this.targetName,
    required this.targetId,
    required this.details,
    this.previousValue,
    this.newValue,
    required this.timestamp,
    required this.ipAddress,
  });
}
