import 'package:flutter/material.dart';

/// Platform Feature / Module Configuration Entity
class PlatformModuleConfig {
  final String key;
  final String name;
  final String description;
  final String category; // POS Core, Kitchen, Marketing, Growth, Operations
  final IconData icon;
  final bool isGloballyEnabled;
  final List<String> enabledPlans; // IDs of plans that have access
  final Map<String, DateTime> temporaryBusinessAccess; // Business ID -> Expiry date

  const PlatformModuleConfig({
    required this.key,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    this.isGloballyEnabled = true,
    required this.enabledPlans,
    this.temporaryBusinessAccess = const {},
  });

  bool isEnabledForBusiness(String businessId, String planId) {
    if (!isGloballyEnabled) return false;
    if (enabledPlans.contains(planId)) return true;
    final tempExpiry = temporaryBusinessAccess[businessId];
    if (tempExpiry != null && tempExpiry.isAfter(DateTime.now())) {
      return true;
    }
    return false;
  }

  PlatformModuleConfig copyWith({
    bool? isGloballyEnabled,
    List<String>? enabledPlans,
    Map<String, DateTime>? temporaryBusinessAccess,
  }) {
    return PlatformModuleConfig(
      key: key,
      name: name,
      description: description,
      category: category,
      icon: icon,
      isGloballyEnabled: isGloballyEnabled ?? this.isGloballyEnabled,
      enabledPlans: enabledPlans ?? this.enabledPlans,
      temporaryBusinessAccess: temporaryBusinessAccess ?? this.temporaryBusinessAccess,
    );
  }
}
