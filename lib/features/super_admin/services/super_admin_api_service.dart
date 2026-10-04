import 'package:flutter/material.dart';
import '../models/super_admin_user_model.dart';
import '../models/super_admin_business_model.dart';
import '../models/super_admin_subscription_model.dart';
import '../models/super_admin_sales_model.dart';
import '../models/super_admin_module_model.dart';
import '../models/super_admin_support_model.dart';
import '../models/super_admin_notification_model.dart';
import '../models/super_admin_audit_log_model.dart';
import 'super_admin_auth_service.dart';

/// Central Reactive Data Store & API Service for Super Admin Web Dashboard
class SuperAdminApiService extends ChangeNotifier {
  static final SuperAdminApiService _instance = SuperAdminApiService._internal();
  factory SuperAdminApiService() => _instance;
  SuperAdminApiService._internal() {
    _seedInitialData();
  }

  // --- Core In-Memory State ---
  List<PlatformUser> _users = [];
  List<PlatformBusiness> _businesses = [];
  List<SubscriptionPlan> _plans = [];
  List<BusinessSubscription> _subscriptions = [];
  List<TeamSubscription> _teamSubscriptions = [];
  List<PlatformSaleRecord> _sales = [];
  final List<PlatformInvoice> _invoices = [];
  List<PlatformModuleConfig> _modules = [];
  List<SupportTicket> _tickets = [];
  List<PlatformBroadcastNotification> _notifications = [];
  List<AuditLogRecord> _auditLogs = [];

  // Getters
  List<PlatformUser> get users => List.unmodifiable(_users);
  List<PlatformBusiness> get businesses => List.unmodifiable(_businesses);
  List<SubscriptionPlan> get plans => List.unmodifiable(_plans);
  List<BusinessSubscription> get subscriptions => List.unmodifiable(_subscriptions);
  List<TeamSubscription> get teamSubscriptions => List.unmodifiable(_teamSubscriptions);
  List<PlatformSaleRecord> get sales => List.unmodifiable(_sales);
  List<PlatformInvoice> get invoices => List.unmodifiable(_invoices);
  List<PlatformModuleConfig> get modules => List.unmodifiable(_modules);
  List<SupportTicket> get tickets => List.unmodifiable(_tickets);
  List<PlatformBroadcastNotification> get notifications => List.unmodifiable(_notifications);
  List<AuditLogRecord> get auditLogs => List.unmodifiable(_auditLogs);

  // --- KPI Computed Getters ---
  int get totalUsers => _users.length;
  int get activeUsers => _users.where((u) => u.status == 'active' || u.status == 'paid').length;
  int get totalBusinesses => _businesses.length;
  int get activeBusinesses => _businesses.where((b) => b.status == BusinessStatus.active).length;
  int get trialBusinesses => _businesses.where((b) => b.status == BusinessStatus.trial).length;
  int get expiredBusinesses => _businesses.where((b) => b.status == BusinessStatus.expired).length;
  int get activeSubscriptions => _subscriptions.where((s) => s.subscriptionStatus == SubscriptionStatus.active).length;
  int get expiredSubscriptions => _subscriptions.where((s) => s.subscriptionStatus == SubscriptionStatus.expired).length;
  int get expiringSoonSubscriptions => _subscriptions.where((s) => s.subscriptionStatus == SubscriptionStatus.expiringSoon).length;

  double get totalRevenue => _sales
      .where((s) => s.status == PaymentStatus.successful)
      .fold(0.0, (acc, s) => acc + s.amount);

  double get monthlyRecurringRevenue {
    double mrr = 0;
    for (final s in _subscriptions) {
      if (s.subscriptionStatus == SubscriptionStatus.active) {
        if (s.billingCycle == BillingCycle.monthly) {
          mrr += s.amount;
        } else if (s.billingCycle == BillingCycle.quarterly) {
          mrr += s.amount / 3;
        } else if (s.billingCycle == BillingCycle.yearly) {
          mrr += s.amount / 12;
        }
      }
    }
    return mrr;
  }

  double get annualRunRate => monthlyRecurringRevenue * 12;

  double get pendingPayments => _sales
      .where((s) => s.status == PaymentStatus.pending)
      .fold(0.0, (acc, s) => acc + s.amount);

  int get newBusinessesThisMonth => _businesses
      .where((b) => b.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 30))))
      .length;

  // --- Audit Logging Helper ---
  void logAudit({
    required String action,
    required AuditTargetType targetType,
    required String targetName,
    required String targetId,
    required String details,
    String? previousValue,
    String? newValue,
  }) {
    final session = SuperAdminSession();
    final log = AuditLogRecord(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      adminId: session.adminId,
      adminName: session.adminName,
      adminRole: session.currentRole.label,
      action: action,
      targetType: targetType,
      targetName: targetName,
      targetId: targetId,
      details: details,
      previousValue: previousValue,
      newValue: newValue,
      timestamp: DateTime.now(),
      ipAddress: '172.16.2.2 (Web Portal)',
    );
    _auditLogs.insert(0, log);
    notifyListeners();
  }

  // --- Business Actions ---
  void suspendBusiness(String businessId, String reason) {
    final idx = _businesses.indexWhere((b) => b.id == businessId);
    if (idx != -1) {
      final old = _businesses[idx];
      _businesses[idx] = old.copyWith(status: BusinessStatus.suspended);
      // Also suspend subscription
      final subIdx = _subscriptions.indexWhere((s) => s.businessId == businessId);
      if (subIdx != -1) {
        _subscriptions[subIdx] = _subscriptions[subIdx].copyWith(subscriptionStatus: SubscriptionStatus.suspended);
      }
      logAudit(
        action: 'Suspended Business',
        targetType: AuditTargetType.business,
        targetName: old.name,
        targetId: old.id,
        details: 'Reason: $reason',
        previousValue: old.status.label,
        newValue: BusinessStatus.suspended.label,
      );
      notifyListeners();
    }
  }

  void activateBusiness(String businessId) {
    final idx = _businesses.indexWhere((b) => b.id == businessId);
    if (idx != -1) {
      final old = _businesses[idx];
      _businesses[idx] = old.copyWith(status: BusinessStatus.active);
      final subIdx = _subscriptions.indexWhere((s) => s.businessId == businessId);
      if (subIdx != -1) {
        _subscriptions[subIdx] = _subscriptions[subIdx].copyWith(subscriptionStatus: SubscriptionStatus.active);
      }
      logAudit(
        action: 'Activated Business',
        targetType: AuditTargetType.business,
        targetName: old.name,
        targetId: old.id,
        details: 'Reactivated business access',
        previousValue: old.status.label,
        newValue: BusinessStatus.active.label,
      );
      notifyListeners();
    }
  }

  void extendSubscription(String businessId, int additionalDays, {String? note}) {
    final idx = _businesses.indexWhere((b) => b.id == businessId);
    if (idx != -1) {
      final old = _businesses[idx];
      final newExpiry = old.expiryDate.add(Duration(days: additionalDays));
      _businesses[idx] = old.copyWith(
        expiryDate: newExpiry,
        status: BusinessStatus.active,
      );

      final subIdx = _subscriptions.indexWhere((s) => s.businessId == businessId);
      if (subIdx != -1) {
        _subscriptions[subIdx] = _subscriptions[subIdx].copyWith(
          expiryDate: newExpiry,
          subscriptionStatus: SubscriptionStatus.active,
        );
      }

      logAudit(
        action: 'Extended Subscription',
        targetType: AuditTargetType.subscription,
        targetName: old.name,
        targetId: old.id,
        details: 'Added $additionalDays days. ${note ?? ""}',
        previousValue: old.expiryDate.toString().split(' ').first,
        newValue: newExpiry.toString().split(' ').first,
      );
      notifyListeners();
    }
  }

  void changeBusinessPlan(String businessId, String newPlanId) {
    final bIdx = _businesses.indexWhere((b) => b.id == businessId);
    final plan = _plans.firstWhere((p) => p.id == newPlanId, orElse: () => _plans.first);
    if (bIdx != -1) {
      final old = _businesses[bIdx];
      _businesses[bIdx] = old.copyWith(
        planId: plan.id,
        planName: plan.name,
        upgradesCount: old.upgradesCount + 1,
      );

      final subIdx = _subscriptions.indexWhere((s) => s.businessId == businessId);
      if (subIdx != -1) {
        _subscriptions[subIdx] = _subscriptions[subIdx].copyWith(
          planId: plan.id,
          planName: plan.name,
          amount: plan.monthlyPrice,
        );
      }

      logAudit(
        action: 'Changed Plan',
        targetType: AuditTargetType.plan,
        targetName: old.name,
        targetId: old.id,
        details: 'Upgraded/Changed plan to ${plan.name}',
        previousValue: old.planName,
        newValue: plan.name,
      );
      notifyListeners();
    }
  }

  // --- User Actions ---
  void suspendUser(String userId, String reason) {
    final idx = _users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final old = _users[idx];
      _users[idx] = old.copyWith(status: 'suspended');
      logAudit(
        action: 'Suspended User',
        targetType: AuditTargetType.user,
        targetName: old.name,
        targetId: old.id,
        details: 'Reason: $reason',
        previousValue: old.status,
        newValue: 'suspended',
      );
      notifyListeners();
    }
  }

  void activateUser(String userId) {
    final idx = _users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final old = _users[idx];
      _users[idx] = old.copyWith(status: 'active');
      logAudit(
        action: 'Activated User',
        targetType: AuditTargetType.user,
        targetName: old.name,
        targetId: old.id,
        details: 'Re-enabled user account',
        previousValue: old.status,
        newValue: 'active',
      );
      notifyListeners();
    }
  }

  void resetUserPassword(String userId) {
    final user = _users.firstWhere((u) => u.id == userId);
    logAudit(
      action: 'Triggered Password Reset',
      targetType: AuditTargetType.user,
      targetName: user.name,
      targetId: user.id,
      details: 'Sent password reset link to ${user.email}',
    );
    notifyListeners();
  }

  // --- Plans Actions ---
  void createPlan(SubscriptionPlan newPlan) {
    _plans.add(newPlan);
    logAudit(
      action: 'Created Subscription Plan',
      targetType: AuditTargetType.plan,
      targetName: newPlan.name,
      targetId: newPlan.id,
      details: 'Monthly Price: ₹${newPlan.monthlyPrice}, Max Users: ${newPlan.maxUsers}',
    );
    notifyListeners();
  }

  void updatePlan(SubscriptionPlan updated) {
    final idx = _plans.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _plans[idx] = updated;
      logAudit(
        action: 'Updated Plan',
        targetType: AuditTargetType.plan,
        targetName: updated.name,
        targetId: updated.id,
        details: 'Updated plan limits and pricing',
      );
      notifyListeners();
    }
  }

  void togglePlanStatus(String planId) {
    final idx = _plans.indexWhere((p) => p.id == planId);
    if (idx != -1) {
      final old = _plans[idx];
      _plans[idx] = old.copyWith(isActive: !old.isActive);
      logAudit(
        action: 'Toggled Plan Active State',
        targetType: AuditTargetType.plan,
        targetName: old.name,
        targetId: old.id,
        details: 'Status changed to ${_plans[idx].isActive ? "Active" : "Archived"}',
      );
      notifyListeners();
    }
  }

  // --- Payment & Refund Actions ---
  void refundSale(String transactionId, String reason) {
    final idx = _sales.indexWhere((s) => s.transactionId == transactionId);
    if (idx != -1) {
      final old = _sales[idx];
      _sales[idx] = old.copyWith(status: PaymentStatus.refunded, notes: 'Refunded: $reason');
      logAudit(
        action: 'Issued Refund',
        targetType: AuditTargetType.payment,
        targetName: 'Txn: $transactionId (${old.businessName})',
        targetId: transactionId,
        details: 'Amount: ₹${old.amount}. Reason: $reason',
        previousValue: old.status.label,
        newValue: PaymentStatus.refunded.label,
      );
      notifyListeners();
    }
  }

  // --- Module Configuration Actions ---
  void toggleModuleGlobal(String key) {
    final idx = _modules.indexWhere((m) => m.key == key);
    if (idx != -1) {
      final old = _modules[idx];
      _modules[idx] = old.copyWith(isGloballyEnabled: !old.isGloballyEnabled);
      logAudit(
        action: 'Toggled Global Module Status',
        targetType: AuditTargetType.module,
        targetName: old.name,
        targetId: old.key,
        details: 'Global availability changed to ${_modules[idx].isGloballyEnabled ? "ON" : "OFF"}',
      );
      notifyListeners();
    }
  }

  void grantTemporaryModuleAccess(String key, String businessId, int days) {
    final idx = _modules.indexWhere((m) => m.key == key);
    if (idx != -1) {
      final old = _modules[idx];
      final currentMap = Map<String, DateTime>.from(old.temporaryBusinessAccess);
      currentMap[businessId] = DateTime.now().add(Duration(days: days));
      _modules[idx] = old.copyWith(temporaryBusinessAccess: currentMap);

      final biz = _businesses.firstWhere((b) => b.id == businessId, orElse: () => _businesses.first);
      logAudit(
        action: 'Granted Temp Module Access',
        targetType: AuditTargetType.module,
        targetName: old.name,
        targetId: old.key,
        details: 'Granted $days days temporary access to ${biz.name}',
      );
      notifyListeners();
    }
  }

  // --- Support Ticket Actions ---
  void replyTicket(String ticketId, String message) {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx != -1) {
      final old = _tickets[idx];
      final session = SuperAdminSession();
      final newReplies = List<SupportTicketReply>.from(old.replies)..add(
        SupportTicketReply(
          id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
          senderName: session.adminName,
          senderRole: 'Super Admin',
          message: message,
          sentAt: DateTime.now(),
          isAdmin: true,
        ),
      );
      _tickets[idx] = old.copyWith(
        status: TicketStatus.waitingForCustomer,
        updatedAt: DateTime.now(),
        replies: newReplies,
      );
      notifyListeners();
    }
  }

  void updateTicketStatus(String ticketId, TicketStatus newStatus) {
    final idx = _tickets.indexWhere((t) => t.id == ticketId);
    if (idx != -1) {
      final old = _tickets[idx];
      _tickets[idx] = old.copyWith(status: newStatus, updatedAt: DateTime.now());
      logAudit(
        action: 'Updated Support Ticket Status',
        targetType: AuditTargetType.system,
        targetName: 'Ticket #${old.ticketCode}',
        targetId: old.id,
        details: 'Status changed to ${newStatus.label}',
        previousValue: old.status.label,
        newValue: newStatus.label,
      );
      notifyListeners();
    }
  }

  // --- Notification Broadcast ---
  void broadcastNotification(PlatformBroadcastNotification notification) {
    _notifications.insert(0, notification);
    logAudit(
      action: 'Broadcasted Platform Notification',
      targetType: AuditTargetType.system,
      targetName: notification.title,
      targetId: notification.id,
      details: 'Audience: ${notification.targetAudience.label}',
    );
    notifyListeners();
  }

  // --- Seed Rich, Realistic SaaS Data ---
  void _seedInitialData() {
    // 1. Subscription Plans
    _plans = [
      const SubscriptionPlan(
        id: 'plan_starter',
        name: 'Starter Launch',
        description: 'Ideal for small cafes, kiosks, and single-counter QSR outlets.',
        monthlyPrice: 999,
        quarterlyPrice: 2699,
        yearlyPrice: 9999,
        trialDays: 14,
        maxUsers: 3,
        maxBranches: 1,
        maxOrdersPerMonth: 2000,
        storageLimitGb: 5,
        enabledModules: ['posBilling', 'inventory', 'reports'],
        subscribersCount: 38,
      ),
      const SubscriptionPlan(
        id: 'plan_pro',
        name: 'Growth Pro',
        description: 'Complete restaurant POS with KDS, CRM, and WhatsApp loyalty automation.',
        monthlyPrice: 2499,
        quarterlyPrice: 6799,
        yearlyPrice: 24999,
        trialDays: 14,
        maxUsers: 10,
        maxBranches: 3,
        maxOrdersPerMonth: 15000,
        storageLimitGb: 25,
        enabledModules: ['posBilling', 'kds', 'inventory', 'crm', 'loyalty', 'whatsapp', 'analytics', 'reports'],
        isPopular: true,
        subscribersCount: 84,
      ),
      const SubscriptionPlan(
        id: 'plan_enterprise',
        name: 'Enterprise Scale',
        description: 'Full-featured power for multi-chain restaurants & franchise operations.',
        monthlyPrice: 4999,
        quarterlyPrice: 13499,
        yearlyPrice: 49999,
        trialDays: 30,
        maxUsers: 50,
        maxBranches: 15,
        maxOrdersPerMonth: 100000,
        storageLimitGb: 100,
        enabledModules: [
          'posBilling',
          'kds',
          'inventory',
          'crm',
          'loyalty',
          'whatsapp',
          'onlineOrdering',
          'qrMenu',
          'staffManagement',
          'vendorManagement',
          'expenseManagement',
          'analytics',
          'reports'
        ],
        subscribersCount: 22,
      ),
    ];

    // 2. Businesses
    final now = DateTime.now();
    _businesses = [
      PlatformBusiness(
        id: 'biz_101',
        name: 'Royal Biryani House',
        ownerName: 'Amit Sharma',
        ownerEmail: 'amit.sharma@royalbiryani.in',
        ownerPhone: '+91 98765 43210',
        category: 'Fine Dining & Dine-in',
        planId: 'plan_pro',
        planName: 'Growth Pro',
        status: BusinessStatus.active,
        usersCount: 8,
        branchesCount: 2,
        teamMembersCount: 14,
        totalRevenue: 148500,
        subscriptionRevenue: 24999,
        pendingAmount: 0,
        renewalsCount: 2,
        startDate: now.subtract(const Duration(days: 120)),
        expiryDate: now.add(const Duration(days: 245)),
        address: 'Plot 42, Connaught Place',
        city: 'New Delhi',
        state: 'Delhi',
        createdAt: now.subtract(const Duration(days: 120)),
        enabledModules: {'posBilling': true, 'kds': true, 'inventory': true, 'crm': true, 'loyalty': true, 'whatsapp': true, 'analytics': true, 'reports': true},
      ),
      PlatformBusiness(
        id: 'biz_102',
        name: 'Chai & Co. Cafe',
        ownerName: 'Priya Verma',
        ownerEmail: 'priya@chaiandco.com',
        ownerPhone: '+91 98111 22334',
        category: 'Cafe & Bakery',
        planId: 'plan_starter',
        planName: 'Starter Launch',
        status: BusinessStatus.active,
        usersCount: 3,
        branchesCount: 1,
        teamMembersCount: 5,
        totalRevenue: 49990,
        subscriptionRevenue: 9999,
        pendingAmount: 0,
        renewalsCount: 1,
        startDate: now.subtract(const Duration(days: 60)),
        expiryDate: now.add(const Duration(days: 305)),
        address: 'Shop 12, Indiranagar',
        city: 'Bengaluru',
        state: 'Karnataka',
        createdAt: now.subtract(const Duration(days: 60)),
        enabledModules: {'posBilling': true, 'inventory': true, 'reports': true},
      ),
      PlatformBusiness(
        id: 'biz_103',
        name: 'Urban Wok Cloud Kitchen',
        ownerName: 'Rohan Mehta',
        ownerEmail: 'rohan@urbanwok.in',
        ownerPhone: '+91 99200 88776',
        category: 'Cloud Kitchen',
        planId: 'plan_enterprise',
        planName: 'Enterprise Scale',
        status: BusinessStatus.active,
        usersCount: 18,
        branchesCount: 5,
        teamMembersCount: 32,
        totalRevenue: 382000,
        subscriptionRevenue: 49999,
        pendingAmount: 0,
        renewalsCount: 3,
        startDate: now.subtract(const Duration(days: 210)),
        expiryDate: now.add(const Duration(days: 155)),
        address: 'B-8, Andheri East Industrial Area',
        city: 'Mumbai',
        state: 'Maharashtra',
        createdAt: now.subtract(const Duration(days: 210)),
        enabledModules: {'posBilling': true, 'kds': true, 'inventory': true, 'crm': true, 'loyalty': true, 'whatsapp': true, 'onlineOrdering': true, 'qrMenu': true, 'staffManagement': true, 'vendorManagement': true, 'expenseManagement': true, 'analytics': true, 'reports': true},
      ),
      PlatformBusiness(
        id: 'biz_104',
        name: 'Spice Garden Dhaba',
        ownerName: 'Harpreet Singh',
        ownerEmail: 'harpreet@spicegarden.co',
        ownerPhone: '+91 97800 11223',
        category: 'Highway Restaurant',
        planId: 'plan_pro',
        planName: 'Growth Pro',
        status: BusinessStatus.active,
        usersCount: 6,
        branchesCount: 1,
        teamMembersCount: 9,
        totalRevenue: 86400,
        subscriptionRevenue: 2499,
        pendingAmount: 0,
        renewalsCount: 0,
        startDate: now.subtract(const Duration(days: 26)),
        expiryDate: now.add(const Duration(days: 4)), // Expiring soon
        address: 'GT Road, Near Toll Plaza',
        city: 'Ambala',
        state: 'Haryana',
        createdAt: now.subtract(const Duration(days: 26)),
        enabledModules: {'posBilling': true, 'kds': true, 'inventory': true, 'crm': true, 'loyalty': true, 'whatsapp': true, 'analytics': true, 'reports': true},
      ),
      PlatformBusiness(
        id: 'biz_105',
        name: 'The Crust Pizzeria',
        ownerName: 'Ananya Gupta',
        ownerEmail: 'ananya@crustpizzeria.in',
        ownerPhone: '+91 96540 99887',
        category: 'Fast Food / QSR',
        planId: 'plan_starter',
        planName: 'Starter Launch',
        status: BusinessStatus.trial,
        usersCount: 2,
        branchesCount: 1,
        teamMembersCount: 4,
        totalRevenue: 0,
        subscriptionRevenue: 0,
        pendingAmount: 0,
        renewalsCount: 0,
        startDate: now.subtract(const Duration(days: 6)),
        expiryDate: now.add(const Duration(days: 8)),
        address: 'Sector 18 Market',
        city: 'Noida',
        state: 'Uttar Pradesh',
        createdAt: now.subtract(const Duration(days: 6)),
        enabledModules: {'posBilling': true, 'inventory': true, 'reports': true},
      ),
      PlatformBusiness(
        id: 'biz_106',
        name: 'BiteBox Burgers',
        ownerName: 'Vikram Joshi',
        ownerEmail: 'vikram@bitebox.in',
        ownerPhone: '+91 98450 66554',
        category: 'Fast Food',
        planId: 'plan_starter',
        planName: 'Starter Launch',
        status: BusinessStatus.expired,
        usersCount: 2,
        branchesCount: 1,
        teamMembersCount: 3,
        totalRevenue: 2997,
        subscriptionRevenue: 999,
        pendingAmount: 999,
        renewalsCount: 0,
        startDate: now.subtract(const Duration(days: 45)),
        expiryDate: now.subtract(const Duration(days: 15)),
        address: 'FC Road, Shivaji Nagar',
        city: 'Pune',
        state: 'Maharashtra',
        createdAt: now.subtract(const Duration(days: 45)),
        enabledModules: {'posBilling': true, 'inventory': true, 'reports': true},
      ),
      PlatformBusiness(
        id: 'biz_107',
        name: 'Moonlight Restobar',
        ownerName: 'Karan Kapoor',
        ownerEmail: 'karan@moonlightbar.com',
        ownerPhone: '+91 98200 33445',
        category: 'Bar & Grill',
        planId: 'plan_pro',
        planName: 'Growth Pro',
        status: BusinessStatus.suspended,
        usersCount: 7,
        branchesCount: 1,
        teamMembersCount: 12,
        totalRevenue: 64200,
        subscriptionRevenue: 6799,
        pendingAmount: 0,
        renewalsCount: 1,
        startDate: now.subtract(const Duration(days: 80)),
        expiryDate: now.subtract(const Duration(days: 5)),
        address: 'Jubilee Hills, Road 36',
        city: 'Hyderabad',
        state: 'Telangana',
        createdAt: now.subtract(const Duration(days: 80)),
        enabledModules: {'posBilling': true, 'kds': true, 'inventory': true, 'crm': true, 'loyalty': true, 'whatsapp': true, 'analytics': true, 'reports': true},
      ),
    ];

    // 3. Platform Users
    _users = [
      PlatformUser(id: 'usr_001', name: 'Amit Sharma', email: 'amit.sharma@royalbiryani.in', phone: '+91 98765 43210', businessId: 'biz_101', businessName: 'Royal Biryani House', role: 'Owner / Super Admin', status: 'paid', subscriptionPlan: 'Growth Pro', createdAt: now.subtract(const Duration(days: 120)), lastLogin: now.subtract(const Duration(minutes: 18))),
      PlatformUser(id: 'usr_002', name: 'Deepak Rao', email: 'deepak.billing@royalbiryani.in', phone: '+91 98765 43211', businessId: 'biz_101', businessName: 'Royal Biryani House', role: 'Head Cashier', status: 'active', subscriptionPlan: 'Growth Pro', createdAt: now.subtract(const Duration(days: 110)), lastLogin: now.subtract(const Duration(hours: 2))),
      PlatformUser(id: 'usr_003', name: 'Priya Verma', email: 'priya@chaiandco.com', phone: '+91 98111 22334', businessId: 'biz_102', businessName: 'Chai & Co. Cafe', role: 'Owner', status: 'paid', subscriptionPlan: 'Starter Launch', createdAt: now.subtract(const Duration(days: 60)), lastLogin: now.subtract(const Duration(minutes: 45))),
      PlatformUser(id: 'usr_004', name: 'Rohan Mehta', email: 'rohan@urbanwok.in', phone: '+91 99200 88776', businessId: 'biz_103', businessName: 'Urban Wok Cloud Kitchen', role: 'Owner / Managing Director', status: 'paid', subscriptionPlan: 'Enterprise Scale', createdAt: now.subtract(const Duration(days: 210)), lastLogin: now.subtract(const Duration(minutes: 10))),
      PlatformUser(id: 'usr_005', name: 'Kavita Nair', email: 'kavita.ops@urbanwok.in', phone: '+91 99200 88777', businessId: 'biz_103', businessName: 'Urban Wok Cloud Kitchen', role: 'Operations Manager', status: 'active', subscriptionPlan: 'Enterprise Scale', createdAt: now.subtract(const Duration(days: 180)), lastLogin: now.subtract(const Duration(hours: 1))),
      PlatformUser(id: 'usr_006', name: 'Harpreet Singh', email: 'harpreet@spicegarden.co', phone: '+91 97800 11223', businessId: 'biz_104', businessName: 'Spice Garden Dhaba', role: 'Owner', status: 'active', subscriptionPlan: 'Growth Pro', createdAt: now.subtract(const Duration(days: 26)), lastLogin: now.subtract(const Duration(days: 1))),
      PlatformUser(id: 'usr_007', name: 'Ananya Gupta', email: 'ananya@crustpizzeria.in', phone: '+91 96540 99887', businessId: 'biz_105', businessName: 'The Crust Pizzeria', role: 'Owner', status: 'trial', subscriptionPlan: 'Free Trial', createdAt: now.subtract(const Duration(days: 6)), lastLogin: now.subtract(const Duration(hours: 3))),
      PlatformUser(id: 'usr_008', name: 'Vikram Joshi', email: 'vikram@bitebox.in', phone: '+91 98450 66554', businessId: 'biz_106', businessName: 'BiteBox Burgers', role: 'Owner', status: 'expired', subscriptionPlan: 'Starter Launch', createdAt: now.subtract(const Duration(days: 45)), lastLogin: now.subtract(const Duration(days: 12))),
      PlatformUser(id: 'usr_009', name: 'Karan Kapoor', email: 'karan@moonlightbar.com', phone: '+91 98200 33445', businessId: 'biz_107', businessName: 'Moonlight Restobar', role: 'Owner', status: 'suspended', subscriptionPlan: 'Growth Pro', createdAt: now.subtract(const Duration(days: 80)), lastLogin: now.subtract(const Duration(days: 6))),
      PlatformUser(id: 'usr_010', name: 'Sunil Chettri', email: 'sunil@momoking.in', phone: '+91 97110 55443', businessId: 'biz_108', businessName: 'Momo King Express', role: 'Manager', status: 'trial', subscriptionPlan: 'Free Trial', createdAt: now.subtract(const Duration(days: 2)), lastLogin: now.subtract(const Duration(hours: 5))),
    ];

    // 4. Subscriptions
    _subscriptions = [
      BusinessSubscription(id: 'sub_001', businessId: 'biz_101', businessName: 'Royal Biryani House', ownerName: 'Amit Sharma', ownerEmail: 'amit.sharma@royalbiryani.in', planId: 'plan_pro', planName: 'Growth Pro', billingCycle: BillingCycle.yearly, startDate: now.subtract(const Duration(days: 120)), expiryDate: now.add(const Duration(days: 245)), amount: 24999, paymentStatus: 'paid', subscriptionStatus: SubscriptionStatus.active),
      BusinessSubscription(id: 'sub_002', businessId: 'biz_102', businessName: 'Chai & Co. Cafe', ownerName: 'Priya Verma', ownerEmail: 'priya@chaiandco.com', planId: 'plan_starter', planName: 'Starter Launch', billingCycle: BillingCycle.yearly, startDate: now.subtract(const Duration(days: 60)), expiryDate: now.add(const Duration(days: 305)), amount: 9999, paymentStatus: 'paid', subscriptionStatus: SubscriptionStatus.active),
      BusinessSubscription(id: 'sub_003', businessId: 'biz_103', businessName: 'Urban Wok Cloud Kitchen', ownerName: 'Rohan Mehta', ownerEmail: 'rohan@urbanwok.in', planId: 'plan_enterprise', planName: 'Enterprise Scale', billingCycle: BillingCycle.yearly, startDate: now.subtract(const Duration(days: 210)), expiryDate: now.add(const Duration(days: 155)), amount: 49999, paymentStatus: 'paid', subscriptionStatus: SubscriptionStatus.active),
      BusinessSubscription(id: 'sub_004', businessId: 'biz_104', businessName: 'Spice Garden Dhaba', ownerName: 'Harpreet Singh', ownerEmail: 'harpreet@spicegarden.co', planId: 'plan_pro', planName: 'Growth Pro', billingCycle: BillingCycle.monthly, startDate: now.subtract(const Duration(days: 26)), expiryDate: now.add(const Duration(days: 4)), amount: 2499, paymentStatus: 'paid', subscriptionStatus: SubscriptionStatus.expiringSoon),
      BusinessSubscription(id: 'sub_005', businessId: 'biz_105', businessName: 'The Crust Pizzeria', ownerName: 'Ananya Gupta', ownerEmail: 'ananya@crustpizzeria.in', planId: 'plan_starter', planName: 'Starter Launch', billingCycle: BillingCycle.monthly, startDate: now.subtract(const Duration(days: 6)), expiryDate: now.add(const Duration(days: 8)), amount: 0, paymentStatus: 'paid', subscriptionStatus: SubscriptionStatus.trial),
      BusinessSubscription(id: 'sub_006', businessId: 'biz_106', businessName: 'BiteBox Burgers', ownerName: 'Vikram Joshi', ownerEmail: 'vikram@bitebox.in', planId: 'plan_starter', planName: 'Starter Launch', billingCycle: BillingCycle.monthly, startDate: now.subtract(const Duration(days: 45)), expiryDate: now.subtract(const Duration(days: 15)), amount: 999, paymentStatus: 'pending', subscriptionStatus: SubscriptionStatus.expired),
      BusinessSubscription(id: 'sub_007', businessId: 'biz_107', businessName: 'Moonlight Restobar', ownerName: 'Karan Kapoor', ownerEmail: 'karan@moonlightbar.com', planId: 'plan_pro', planName: 'Growth Pro', billingCycle: BillingCycle.quarterly, startDate: now.subtract(const Duration(days: 80)), expiryDate: now.subtract(const Duration(days: 5)), amount: 6799, paymentStatus: 'paid', subscriptionStatus: SubscriptionStatus.suspended),
    ];

    // 5. Separate Team Subscriptions
    _teamSubscriptions = [
      TeamSubscription(id: 'tsub_001', businessId: 'biz_101', businessName: 'Royal Biryani House', teamId: 'team_cp', teamName: 'Connaught Place Service Team', memberCount: 8, teamPricePerMonth: 799, status: SubscriptionStatus.active, startDate: now.subtract(const Duration(days: 90)), expiryDate: now.add(const Duration(days: 275)), paymentStatus: 'paid'),
      TeamSubscription(id: 'tsub_002', businessId: 'biz_103', businessName: 'Urban Wok Cloud Kitchen', teamId: 'team_andheri', teamName: 'Central Kitchen Kitchen Ops', memberCount: 15, teamPricePerMonth: 1499, status: SubscriptionStatus.active, startDate: now.subtract(const Duration(days: 180)), expiryDate: now.add(const Duration(days: 185)), paymentStatus: 'paid'),
      TeamSubscription(id: 'tsub_003', businessId: 'biz_103', businessName: 'Urban Wok Cloud Kitchen', teamId: 'team_bandra', teamName: 'Bandra Delivery Pod', memberCount: 6, teamPricePerMonth: 599, status: SubscriptionStatus.active, startDate: now.subtract(const Duration(days: 60)), expiryDate: now.add(const Duration(days: 305)), paymentStatus: 'paid'),
    ];

    // 6. Sales & Invoices
    _sales = [
      PlatformSaleRecord(id: 'sale_001', transactionId: 'TXN_99812401', invoiceNumber: 'INV-2026-0891', businessId: 'biz_103', businessName: 'Urban Wok Cloud Kitchen', ownerName: 'Rohan Mehta', planName: 'Enterprise Scale', amount: 49999, status: PaymentStatus.successful, method: PaymentMethod.netBanking, saleType: 'Renewal', date: now.subtract(const Duration(days: 2))),
      PlatformSaleRecord(id: 'sale_002', transactionId: 'TXN_99812402', invoiceNumber: 'INV-2026-0892', businessId: 'biz_101', businessName: 'Royal Biryani House', ownerName: 'Amit Sharma', planName: 'Growth Pro', amount: 24999, status: PaymentStatus.successful, method: PaymentMethod.upi, saleType: 'Renewal', date: now.subtract(const Duration(days: 4))),
      PlatformSaleRecord(id: 'sale_003', transactionId: 'TXN_99812403', invoiceNumber: 'INV-2026-0893', businessId: 'biz_102', businessName: 'Chai & Co. Cafe', ownerName: 'Priya Verma', planName: 'Starter Launch', amount: 9999, status: PaymentStatus.successful, method: PaymentMethod.card, saleType: 'New', date: now.subtract(const Duration(days: 7))),
      PlatformSaleRecord(id: 'sale_004', transactionId: 'TXN_99812404', invoiceNumber: 'INV-2026-0894', businessId: 'biz_104', businessName: 'Spice Garden Dhaba', ownerName: 'Harpreet Singh', planName: 'Growth Pro', amount: 2499, status: PaymentStatus.successful, method: PaymentMethod.upi, saleType: 'New', date: now.subtract(const Duration(days: 12))),
      PlatformSaleRecord(id: 'sale_005', transactionId: 'TXN_99812405', invoiceNumber: 'INV-2026-0895', businessId: 'biz_106', businessName: 'BiteBox Burgers', ownerName: 'Vikram Joshi', planName: 'Starter Launch', amount: 999, status: PaymentStatus.pending, method: PaymentMethod.upi, saleType: 'Renewal', date: now.subtract(const Duration(days: 15))),
      PlatformSaleRecord(id: 'sale_006', transactionId: 'TXN_99812406', invoiceNumber: 'INV-2026-0896', businessId: 'biz_107', businessName: 'Moonlight Restobar', ownerName: 'Karan Kapoor', planName: 'Growth Pro', amount: 6799, status: PaymentStatus.refunded, method: PaymentMethod.card, saleType: 'Renewal', date: now.subtract(const Duration(days: 18)), notes: 'Refunded on user dispute'),
    ];

    // 7. Modules
    _modules = [
      const PlatformModuleConfig(key: 'posBilling', name: 'POS Fast Billing', description: 'Core lightning fast POS order punch, split bill, and thermal printing', category: 'POS Core', icon: Icons.point_of_sale_rounded, isGloballyEnabled: true, enabledPlans: ['plan_starter', 'plan_pro', 'plan_enterprise']),
      const PlatformModuleConfig(key: 'kds', name: 'Kitchen Display System (KDS)', description: 'Real-time kitchen order ticketing, item timer, and chef bump bar', category: 'Kitchen', icon: Icons.soup_kitchen_rounded, isGloballyEnabled: true, enabledPlans: ['plan_pro', 'plan_enterprise']),
      const PlatformModuleConfig(key: 'inventory', name: 'Inventory & Stock Management', description: 'Raw material depletion, low stock alerts, recipe costing, and purchase orders', category: 'Operations', icon: Icons.inventory_2_rounded, isGloballyEnabled: true, enabledPlans: ['plan_starter', 'plan_pro', 'plan_enterprise']),
      const PlatformModuleConfig(key: 'crm', name: 'Customer CRM & Leads', description: 'Customer purchase history, favorite items, visits frequency, and phonebook', category: 'Marketing', icon: Icons.groups_rounded, isGloballyEnabled: true, enabledPlans: ['plan_pro', 'plan_enterprise']),
      const PlatformModuleConfig(key: 'loyalty', name: 'Points & Rewards Loyalty', description: 'Cashback reward points, punch cards, birthday perks, and VIP tiers', category: 'Marketing', icon: Icons.military_tech_rounded, isGloballyEnabled: true, enabledPlans: ['plan_pro', 'plan_enterprise']),
      const PlatformModuleConfig(key: 'whatsapp', name: 'WhatsApp Marketing & Receipts', description: 'Send automated e-bills, promotional coupons, and order status via WhatsApp API', category: 'Growth', icon: Icons.chat_rounded, isGloballyEnabled: true, enabledPlans: ['plan_pro', 'plan_enterprise']),
      const PlatformModuleConfig(key: 'onlineOrdering', name: 'Online Direct Ordering', description: 'Custom branded restaurant website for direct customer takeout and delivery', category: 'Growth', icon: Icons.storefront_rounded, isGloballyEnabled: true, enabledPlans: ['plan_enterprise']),
      const PlatformModuleConfig(key: 'qrMenu', name: 'Dine-In QR Table Ordering', description: 'Dynamic contactless table QR code for digital menu browsing and direct ordering', category: 'Growth', icon: Icons.qr_code_2_rounded, isGloballyEnabled: true, enabledPlans: ['plan_enterprise']),
      const PlatformModuleConfig(key: 'staffManagement', name: 'Staff Shifts & Payroll', description: 'Employee PIN login, shift attendance, tip distribution, and staff roles', category: 'Operations', icon: Icons.badge_rounded, isGloballyEnabled: true, enabledPlans: ['plan_enterprise']),
      const PlatformModuleConfig(key: 'vendorManagement', name: 'Vendor & Expense Ledger', description: 'Supplier accounts, ingredient payments, recurring expense tracking, and P&L', category: 'Operations', icon: Icons.local_shipping_rounded, isGloballyEnabled: true, enabledPlans: ['plan_enterprise']),
      const PlatformModuleConfig(key: 'analytics', name: 'Advanced Business Analytics', description: 'Peak sales heatmaps, item margin analysis, staff performance, and forecasting', category: 'Analytics', icon: Icons.insights_rounded, isGloballyEnabled: true, enabledPlans: ['plan_pro', 'plan_enterprise']),
      const PlatformModuleConfig(key: 'reports', name: 'Audit & GST Tax Reports', description: 'GSTR-1 summaries, daily sales closures, payment split reports, and CSV export', category: 'Analytics', icon: Icons.assessment_rounded, isGloballyEnabled: true, enabledPlans: ['plan_starter', 'plan_pro', 'plan_enterprise']),
    ];

    // 8. Support Tickets
    _tickets = [
      SupportTicket(
        id: 'tkt_001',
        ticketCode: 'APT-8401',
        businessId: 'biz_101',
        businessName: 'Royal Biryani House',
        userName: 'Amit Sharma',
        userEmail: 'amit.sharma@royalbiryani.in',
        category: 'Printing & ESC/POS',
        priority: TicketPriority.high,
        status: TicketStatus.inProgress,
        assignedAdmin: 'Chandan SuperAdmin',
        subject: 'Bluetooth thermal printer disconnecting during peak lunch hours',
        initialMessage: 'We are using a 80mm Bluetooth printer on our tablet. Every day around 2 PM it loses connection and requires reconnecting in settings.',
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now.subtract(const Duration(minutes: 30)),
        replies: [
          SupportTicketReply(id: 'r1', senderName: 'Amit Sharma', senderRole: 'Owner', message: 'It happened again today for 3 bills.', sentAt: now.subtract(const Duration(hours: 3)), isAdmin: false),
          SupportTicketReply(id: 'r2', senderName: 'Chandan SuperAdmin', senderRole: 'Super Admin', message: 'Hello Amit, we have released an update (v1.0.4) that enables automatic Bluetooth keep-alive packets. Please refresh your POS app.', sentAt: now.subtract(const Duration(minutes: 30)), isAdmin: true),
        ],
      ),
      SupportTicket(
        id: 'tkt_002',
        ticketCode: 'APT-8402',
        businessId: 'biz_104',
        businessName: 'Spice Garden Dhaba',
        userName: 'Harpreet Singh',
        userEmail: 'harpreet@spicegarden.co',
        category: 'Billing & Invoices',
        priority: TicketPriority.medium,
        status: TicketStatus.open,
        assignedAdmin: 'Finance Admin',
        subject: 'Need GST invoice with company address for annual plan renewal',
        initialMessage: 'Please update our GSTIN 07AAAAA0000A1Z5 on our upcoming renewal invoice so we can claim input credit.',
        createdAt: now.subtract(const Duration(hours: 14)),
        updatedAt: now.subtract(const Duration(hours: 14)),
      ),
      SupportTicket(
        id: 'tkt_003',
        ticketCode: 'APT-8403',
        businessId: 'biz_103',
        businessName: 'Urban Wok Cloud Kitchen',
        userName: 'Rohan Mehta',
        userEmail: 'rohan@urbanwok.in',
        category: 'Feature Request',
        priority: TicketPriority.low,
        status: TicketStatus.resolved,
        assignedAdmin: 'Chandan SuperAdmin',
        subject: 'Can we add 2 more sub-branches to our Enterprise subscription?',
        initialMessage: 'We are opening Bandra and Powai outlets next month. Please clarify if additional branches are included or need an add-on.',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    // 9. Broadcast Notifications
    _notifications = [
      PlatformBroadcastNotification(
        id: 'notif_001',
        title: 'Platform Maintenance: Cloud Database Upgrade',
        message: 'Apna POSS cloud servers will undergo scheduled 15-minute optimization on Sunday, Oct 11 at 03:00 AM IST. Offline billing will continue seamlessly.',
        type: PlatformNotificationType.maintenance,
        targetAudience: NotificationTarget.allBusinesses,
        sentAt: now.subtract(const Duration(days: 1)),
        sentBy: 'Chandan SuperAdmin',
        totalRecipients: 142,
        readCount: 118,
      ),
      PlatformBroadcastNotification(
        id: 'notif_002',
        title: 'New Feature: AI Voice Assistant (Chotu) 2.0 Released',
        message: 'You can now punch complex Hindi and English multi-item orders in seconds using voice! Check the mic button on your POS topbar.',
        type: PlatformNotificationType.featureAnnouncement,
        targetAudience: NotificationTarget.allBusinesses,
        sentAt: now.subtract(const Duration(days: 4)),
        sentBy: 'Chandan SuperAdmin',
        totalRecipients: 142,
        readCount: 135,
      ),
    ];

    // 10. Audit Logs
    _auditLogs = [
      AuditLogRecord(
        id: 'log_001',
        adminId: 'adm_001',
        adminName: 'Chandan SuperAdmin',
        adminRole: 'Super Admin',
        action: 'Extended Subscription',
        targetType: AuditTargetType.subscription,
        targetName: 'Royal Biryani House',
        targetId: 'biz_101',
        details: 'Added 30 days promotional extension for loyalty milestone.',
        previousValue: '2026-09-10',
        newValue: '2026-10-10',
        timestamp: now.subtract(const Duration(hours: 2)),
        ipAddress: '172.16.2.2',
      ),
      AuditLogRecord(
        id: 'log_002',
        adminId: 'adm_001',
        adminName: 'Chandan SuperAdmin',
        adminRole: 'Super Admin',
        action: 'Created Subscription Plan',
        targetType: AuditTargetType.plan,
        targetName: 'Enterprise Scale',
        targetId: 'plan_enterprise',
        details: 'Configured new multi-branch franchise tier with custom limits.',
        timestamp: now.subtract(const Duration(days: 1)),
        ipAddress: '172.16.2.2',
      ),
      AuditLogRecord(
        id: 'log_003',
        adminId: 'adm_001',
        adminName: 'Chandan SuperAdmin',
        adminRole: 'Super Admin',
        action: 'Issued Refund',
        targetType: AuditTargetType.payment,
        targetName: 'Txn: TXN_99812406 (Moonlight Restobar)',
        targetId: 'TXN_99812406',
        details: 'Processed ₹6,799 refund due to duplicate billing transaction.',
        previousValue: 'Successful',
        newValue: 'Refunded',
        timestamp: now.subtract(const Duration(days: 2)),
        ipAddress: '172.16.2.2',
      ),
    ];
  }
}
