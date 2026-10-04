import 'package:flutter/material.dart';

/// Admin Role types with specific permission boundaries
enum SuperAdminRole {
  superAdmin('Super Admin', 'Full unrestricted platform access'),
  financeAdmin('Finance Admin', 'Sales, Payments, Revenue, Subscriptions & Financial Reports'),
  supportAdmin('Support Admin', 'Users, Businesses, Support Tickets & Activity Logs'),
  operationsAdmin('Operations Admin', 'Businesses, Users, Modules & Subscription Lifecycle');

  final String label;
  final String description;
  const SuperAdminRole(this.label, this.description);

  bool canAccessSales() => this == superAdmin || this == financeAdmin;
  bool canAccessPayments() => this == superAdmin || this == financeAdmin;
  bool canAccessRevenue() => this == superAdmin || this == financeAdmin;
  bool canAccessSubscriptions() => this == superAdmin || this == financeAdmin || this == operationsAdmin;
  bool canAccessPlans() => this == superAdmin || this == financeAdmin || this == operationsAdmin;
  bool canAccessUsers() => this == superAdmin || this == supportAdmin || this == operationsAdmin;
  bool canAccessBusinesses() => this == superAdmin || this == supportAdmin || this == operationsAdmin;
  bool canAccessModules() => this == superAdmin || this == operationsAdmin;
  bool canAccessSupport() => this == superAdmin || this == supportAdmin;
  bool canAccessSettings() => this == superAdmin;
  bool canAccessAuditLogs() => this == superAdmin || this == supportAdmin;
  bool canPerformDestructiveActions() => this == superAdmin;

  // Property getters for easy consumption
  bool get canAccessSalesProp => canAccessSales();
  bool get canAccessPaymentsProp => canAccessPayments();
  bool get canAccessRevenueProp => canAccessRevenue();
  bool get canAccessBusinessesProp => canAccessBusinesses();
  bool get canAccessUsersProp => canAccessUsers();
  bool get canAccessSubscriptionsProp => canAccessSubscriptions();
  bool get canAccessPlansProp => canAccessPlans();
  bool get canAccessModulesProp => canAccessModules();
  bool get canAccessSupportProp => canAccessSupport();
  bool get canAccessSettingsProp => canAccessSettings();
  bool get canAccessAuditLogsProp => canAccessAuditLogs();
  bool get canIssueRefunds => this == superAdmin || this == financeAdmin;
  bool get canModifySubscriptions => this == superAdmin || this == operationsAdmin;
  bool get canBroadcastNotifications => this == superAdmin || this == operationsAdmin;
}

/// Managed Platform User Model
class PlatformUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String businessId;
  final String businessName;
  final String role;
  final String status; // active, inactive, suspended, trial, paid, expired
  final String subscriptionPlan;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String? profilePhoto;

  const PlatformUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.businessId,
    required this.businessName,
    required this.role,
    required this.status,
    required this.subscriptionPlan,
    required this.createdAt,
    this.lastLogin,
    this.profilePhoto,
  });

  PlatformUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? status,
    String? role,
    String? subscriptionPlan,
    DateTime? lastLogin,
  }) {
    return PlatformUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      businessId: businessId,
      businessName: businessName,
      role: role ?? this.role,
      status: status ?? this.status,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      createdAt: createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      profilePhoto: profilePhoto,
    );
  }

  factory PlatformUser.fromJson(Map<String, dynamic> json) {
    return PlatformUser(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      businessId: json['businessId'] ?? '',
      businessName: json['businessName'] ?? 'Unassigned',
      role: json['role'] ?? 'Staff',
      status: json['status'] ?? 'active',
      subscriptionPlan: json['subscriptionPlan'] ?? 'Free Trial',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastLogin: json['lastLogin'] != null
          ? DateTime.tryParse(json['lastLogin'].toString())
          : null,
      profilePhoto: json['profilePhoto'] ?? json['avatarUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'businessId': businessId,
    'businessName': businessName,
    'role': role,
    'status': status,
    'subscriptionPlan': subscriptionPlan,
    'createdAt': createdAt.toIso8601String(),
    'lastLogin': lastLogin?.toIso8601String(),
    'profilePhoto': profilePhoto,
  };
}

/// Team Member inside a business
class PlatformTeamMember {
  final String id;
  final String name;
  final String email;
  final String role;
  final List<String> permissions;
  final DateTime lastActive;
  final bool isOnline;

  const PlatformTeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.permissions,
    required this.lastActive,
    this.isOnline = false,
  });
}
