/// Revenue KPI Overview Entity
class RevenueKpis {
  final double totalRevenue;
  final double mrr; // Monthly Recurring Revenue
  final double arr; // Annual Run Rate
  final double newRevenue;
  final double renewalRevenue;
  final double upgradeRevenue;
  final double addonRevenue;
  final double refunds;
  final double netRevenue;
  final double growthPercentage;
  final double pendingPayments;

  const RevenueKpis({
    required this.totalRevenue,
    required this.mrr,
    required this.arr,
    required this.newRevenue,
    required this.renewalRevenue,
    required this.upgradeRevenue,
    required this.addonRevenue,
    required this.refunds,
    required this.netRevenue,
    required this.growthPercentage,
    required this.pendingPayments,
  });
}

/// Point on Revenue Trend Chart
class RevenueTrendPoint {
  final String periodLabel; // 'Jan', 'Feb', 'Mon', 'Tue', etc.
  final double totalRevenue;
  final double subscriptionRevenue;
  final double addonRevenue;

  const RevenueTrendPoint({
    required this.periodLabel,
    required this.totalRevenue,
    required this.subscriptionRevenue,
    required this.addonRevenue,
  });
}

/// Revenue Breakdown by Business Entity
class BusinessRevenueRow {
  final String businessId;
  final String businessName;
  final String planName;
  final String city;
  final double totalPaid;
  final double subscriptionRevenue;
  final double addonRevenue;
  final double refunds;
  final double netRevenue;
  final DateTime lastPaymentDate;
  final DateTime nextRenewalDate;
  final String status;

  const BusinessRevenueRow({
    required this.businessId,
    required this.businessName,
    required this.planName,
    required this.city,
    required this.totalPaid,
    required this.subscriptionRevenue,
    required this.addonRevenue,
    required this.refunds,
    required this.netRevenue,
    required this.lastPaymentDate,
    required this.nextRenewalDate,
    required this.status,
  });
}
