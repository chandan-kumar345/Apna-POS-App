import 'package:flutter/material.dart';

enum SubscriptionStatus {
  trial('Trial', Color(0xFF0EA5E9), Color(0xFFE0F2FE)),
  active('Active', Color(0xFF10B981), Color(0xFFECFDF5)),
  expiringSoon('Expiring Soon', Color(0xFFF59E0B), Color(0xFFFFFBEB)),
  expired('Expired', Color(0xFFEF4444), Color(0xFFFEF2F2)),
  cancelled('Cancelled', Color(0xFF64748B), Color(0xFFF1F5F9)),
  suspended('Suspended', Color(0xFFDC2626), Color(0xFFFEE2E2));

  final String label;
  final Color color;
  final Color bg;
  const SubscriptionStatus(this.label, this.color, this.bg);

  static SubscriptionStatus fromString(String str) {
    switch (str.toLowerCase().trim()) {
      case 'trial':
        return SubscriptionStatus.trial;
      case 'active':
        return SubscriptionStatus.active;
      case 'expiringsoon':
      case 'expiring_soon':
      case 'expiring soon':
        return SubscriptionStatus.expiringSoon;
      case 'expired':
        return SubscriptionStatus.expired;
      case 'cancelled':
      case 'canceled':
        return SubscriptionStatus.cancelled;
      case 'suspended':
        return SubscriptionStatus.suspended;
      default:
        return SubscriptionStatus.active;
    }
  }
}

enum BillingCycle {
  monthly('Monthly', 30),
  quarterly('Quarterly', 90),
  yearly('Yearly', 365);

  final String label;
  final int days;
  const BillingCycle(this.label, this.days);
}

/// Subscription Plan definition configured by Super Admin
class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final double monthlyPrice;
  final double quarterlyPrice;
  final double yearlyPrice;
  final int trialDays;
  final int maxUsers;
  final int maxBranches;
  final int maxOrdersPerMonth;
  final int storageLimitGb;
  final List<String> enabledModules;
  final bool isPopular;
  final bool isActive;
  final int subscribersCount;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.quarterlyPrice,
    required this.yearlyPrice,
    this.trialDays = 14,
    required this.maxUsers,
    required this.maxBranches,
    this.maxOrdersPerMonth = 5000,
    this.storageLimitGb = 10,
    required this.enabledModules,
    this.isPopular = false,
    this.isActive = true,
    this.subscribersCount = 0,
  });

  SubscriptionPlan copyWith({
    String? name,
    String? description,
    double? monthlyPrice,
    double? quarterlyPrice,
    double? yearlyPrice,
    int? trialDays,
    int? maxUsers,
    int? maxBranches,
    int? maxOrdersPerMonth,
    int? storageLimitGb,
    List<String>? enabledModules,
    bool? isPopular,
    bool? isActive,
  }) {
    return SubscriptionPlan(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      quarterlyPrice: quarterlyPrice ?? this.quarterlyPrice,
      yearlyPrice: yearlyPrice ?? this.yearlyPrice,
      trialDays: trialDays ?? this.trialDays,
      maxUsers: maxUsers ?? this.maxUsers,
      maxBranches: maxBranches ?? this.maxBranches,
      maxOrdersPerMonth: maxOrdersPerMonth ?? this.maxOrdersPerMonth,
      storageLimitGb: storageLimitGb ?? this.storageLimitGb,
      enabledModules: enabledModules ?? this.enabledModules,
      isPopular: isPopular ?? this.isPopular,
      isActive: isActive ?? this.isActive,
      subscribersCount: subscribersCount,
    );
  }
}

/// Active Business Subscription Instance
class BusinessSubscription {
  final String id;
  final String businessId;
  final String businessName;
  final String ownerName;
  final String ownerEmail;
  final String planId;
  final String planName;
  final BillingCycle billingCycle;
  final DateTime startDate;
  final DateTime expiryDate;
  final double amount;
  final String paymentStatus; // paid, pending, failed, refunded
  final SubscriptionStatus subscriptionStatus;
  final bool autoRenew;

  const BusinessSubscription({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.ownerName,
    required this.ownerEmail,
    required this.planId,
    required this.planName,
    required this.billingCycle,
    required this.startDate,
    required this.expiryDate,
    required this.amount,
    required this.paymentStatus,
    required this.subscriptionStatus,
    this.autoRenew = true,
  });

  int get remainingDays => expiryDate.difference(DateTime.now()).inDays;

  BusinessSubscription copyWith({
    String? planId,
    String? planName,
    BillingCycle? billingCycle,
    DateTime? startDate,
    DateTime? expiryDate,
    double? amount,
    String? paymentStatus,
    SubscriptionStatus? subscriptionStatus,
    bool? autoRenew,
  }) {
    return BusinessSubscription(
      id: id,
      businessId: businessId,
      businessName: businessName,
      ownerName: ownerName,
      ownerEmail: ownerEmail,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      billingCycle: billingCycle ?? this.billingCycle,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      amount: amount ?? this.amount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      autoRenew: autoRenew ?? this.autoRenew,
    );
  }
}

/// Separate Team Subscription Entity (Strict separation from Business Subscription)
class TeamSubscription {
  final String id;
  final String businessId;
  final String businessName;
  final String teamId;
  final String teamName;
  final int memberCount;
  final double teamPricePerMonth;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime expiryDate;
  final String paymentStatus;
  final bool autoRenew;

  const TeamSubscription({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.teamId,
    required this.teamName,
    required this.memberCount,
    required this.teamPricePerMonth,
    required this.status,
    required this.startDate,
    required this.expiryDate,
    required this.paymentStatus,
    this.autoRenew = true,
  });

  TeamSubscription copyWith({
    String? teamName,
    int? memberCount,
    double? teamPricePerMonth,
    SubscriptionStatus? status,
    DateTime? expiryDate,
    String? paymentStatus,
    bool? autoRenew,
  }) {
    return TeamSubscription(
      id: id,
      businessId: businessId,
      businessName: businessName,
      teamId: teamId,
      teamName: teamName ?? this.teamName,
      memberCount: memberCount ?? this.memberCount,
      teamPricePerMonth: teamPricePerMonth ?? this.teamPricePerMonth,
      status: status ?? this.status,
      startDate: startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      autoRenew: autoRenew ?? this.autoRenew,
    );
  }
}
