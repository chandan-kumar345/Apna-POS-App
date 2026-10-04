import 'package:flutter/material.dart';

/// Business Status Lifecycle
enum BusinessStatus {
  active('Active', Color(0xFF10B981), Color(0xFFECFDF5)),
  trial('Trial', Color(0xFF0EA5E9), Color(0xFFE0F2FE)),
  suspended('Suspended', Color(0xFFEF4444), Color(0xFFFEF2F2)),
  expired('Expired', Color(0xFFF59E0B), Color(0xFFFFFBEB)),
  cancelled('Cancelled', Color(0xFF64748B), Color(0xFFF1F5F9));

  final String label;
  final Color color;
  final Color bg;
  const BusinessStatus(this.label, this.color, this.bg);

  Color get badgeColor => color;
  Color get badgeBg => bg;

  static BusinessStatus fromString(String status) {
    switch (status.toLowerCase().trim()) {
      case 'active':
        return BusinessStatus.active;
      case 'trial':
        return BusinessStatus.trial;
      case 'suspended':
        return BusinessStatus.suspended;
      case 'expired':
        return BusinessStatus.expired;
      case 'cancelled':
      case 'canceled':
        return BusinessStatus.cancelled;
      default:
        return BusinessStatus.active;
    }
  }
}

/// Platform Business Entity
class PlatformBusiness {
  final String id;
  final String name;
  final String ownerName;
  final String ownerEmail;
  final String ownerPhone;
  final String category; // Restaurant, Cafe, Fast Food, Cloud Kitchen, Bar & Grill
  final String planId;
  final String planName;
  final BusinessStatus status;
  final int usersCount;
  final int branchesCount;
  final int teamMembersCount;
  final double totalRevenue;
  final double subscriptionRevenue;
  final double pendingAmount;
  final int renewalsCount;
  final int upgradesCount;
  final int downgradesCount;
  final DateTime startDate;
  final DateTime expiryDate;
  final String address;
  final String city;
  final String state;
  final DateTime createdAt;
  final Map<String, bool> enabledModules;
  final String? logoUrl;

  const PlatformBusiness({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPhone,
    required this.category,
    required this.planId,
    required this.planName,
    required this.status,
    required this.usersCount,
    required this.branchesCount,
    required this.teamMembersCount,
    required this.totalRevenue,
    required this.subscriptionRevenue,
    this.pendingAmount = 0.0,
    this.renewalsCount = 1,
    this.upgradesCount = 0,
    this.downgradesCount = 0,
    required this.startDate,
    required this.expiryDate,
    required this.address,
    required this.city,
    required this.state,
    required this.createdAt,
    required this.enabledModules,
    this.logoUrl,
  });

  bool get isExpiringSoon {
    final diff = expiryDate.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 7 && status == BusinessStatus.active;
  }

  PlatformBusiness copyWith({
    String? name,
    String? ownerName,
    String? ownerEmail,
    String? ownerPhone,
    String? category,
    String? planId,
    String? planName,
    BusinessStatus? status,
    int? usersCount,
    int? branchesCount,
    int? teamMembersCount,
    double? totalRevenue,
    double? subscriptionRevenue,
    double? pendingAmount,
    int? renewalsCount,
    int? upgradesCount,
    int? downgradesCount,
    DateTime? startDate,
    DateTime? expiryDate,
    String? address,
    String? city,
    String? state,
    Map<String, bool>? enabledModules,
  }) {
    return PlatformBusiness(
      id: id,
      name: name ?? this.name,
      ownerName: ownerName ?? this.ownerName,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      category: category ?? this.category,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      status: status ?? this.status,
      usersCount: usersCount ?? this.usersCount,
      branchesCount: branchesCount ?? this.branchesCount,
      teamMembersCount: teamMembersCount ?? this.teamMembersCount,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      subscriptionRevenue: subscriptionRevenue ?? this.subscriptionRevenue,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      renewalsCount: renewalsCount ?? this.renewalsCount,
      upgradesCount: upgradesCount ?? this.upgradesCount,
      downgradesCount: downgradesCount ?? this.downgradesCount,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      createdAt: createdAt,
      enabledModules: enabledModules ?? this.enabledModules,
      logoUrl: logoUrl,
    );
  }

  factory PlatformBusiness.fromJson(Map<String, dynamic> json) {
    return PlatformBusiness(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? 'Apna Restaurant',
      ownerName: json['ownerName'] ?? json['owner'] ?? 'Owner',
      ownerEmail: json['ownerEmail'] ?? '',
      ownerPhone: json['ownerPhone'] ?? '',
      category: json['category'] ?? 'Restaurant',
      planId: json['planId'] ?? 'plan_pro',
      planName: json['planName'] ?? 'Pro Growth Plan',
      status: BusinessStatus.fromString(json['status'] ?? 'active'),
      usersCount: (json['usersCount'] as num?)?.toInt() ?? 1,
      branchesCount: (json['branchesCount'] as num?)?.toInt() ?? 1,
      teamMembersCount: (json['teamMembersCount'] as num?)?.toInt() ?? 3,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      subscriptionRevenue: (json['subscriptionRevenue'] as num?)?.toDouble() ?? 0.0,
      pendingAmount: (json['pendingAmount'] as num?)?.toDouble() ?? 0.0,
      renewalsCount: (json['renewalsCount'] as num?)?.toInt() ?? 0,
      upgradesCount: (json['upgradesCount'] as num?)?.toInt() ?? 0,
      downgradesCount: (json['downgradesCount'] as num?)?.toInt() ?? 0,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'].toString()) ?? DateTime.now().add(const Duration(days: 30))
          : DateTime.now().add(const Duration(days: 30)),
      address: json['address'] ?? '',
      city: json['city'] ?? 'New Delhi',
      state: json['state'] ?? 'Delhi',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      enabledModules: json['enabledModules'] is Map
          ? Map<String, bool>.from(json['enabledModules'])
          : {
              'posBilling': true,
              'kds': true,
              'inventory': true,
              'crm': true,
              'loyalty': true,
              'whatsapp': true,
              'onlineOrdering': true,
              'qrMenu': true,
              'analytics': true,
            },
      logoUrl: json['logoUrl'],
    );
  }
}

/// Branch entity within a business
class BusinessBranch {
  final String id;
  final String name;
  final String address;
  final String managerName;
  final String phone;
  final int activeTables;
  final bool isMainBranch;

  const BusinessBranch({
    required this.id,
    required this.name,
    required this.address,
    required this.managerName,
    required this.phone,
    required this.activeTables,
    this.isMainBranch = false,
  });
}
