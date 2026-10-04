import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../services/super_admin_api_service.dart';
import '../../services/super_admin_auth_service.dart';
import '../../models/super_admin_user_model.dart';

class SuperAdminSettingsScreen extends StatefulWidget {
  const SuperAdminSettingsScreen({super.key});

  @override
  State<SuperAdminSettingsScreen> createState() => _SuperAdminSettingsScreenState();
}

class _SuperAdminSettingsScreenState extends State<SuperAdminSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form State
  bool _enforce2FA = true;
  int _sessionTimeout = 30; // minutes
  bool _maintenanceMode = false;
  int _defaultTrialDays = 14;
  double _defaultGstRate = 18.0;
  final String _invoicePrefix = 'INV-2026-';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = SuperAdminApiService();
    final auth = SuperAdminSession();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(context),
          const SizedBox(height: 20),

          // Tabs
          Container(
            decoration: SuperAdminTheme.cardDecoration(context),
            child: TabBar(
              controller: _tabController,
              labelColor: SuperAdminTheme.primaryBlue,
              unselectedLabelColor: SuperAdminTheme.textSecondary,
              indicatorColor: SuperAdminTheme.primaryBlue,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(icon: Icon(Icons.badge_rounded, size: 18), text: 'Admin Roles & Permissions'),
                Tab(icon: Icon(Icons.security_rounded, size: 18), text: 'Security & Auth'),
                Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Platform Config'),
                Tab(icon: Icon(Icons.cloud_sync_rounded, size: 18), text: 'Integrations & Health'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Tab Content Container
          SizedBox(
            height: 750,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRolesTab(context, auth),
                _buildSecurityTab(context),
                _buildPlatformConfigTab(context, api),
                _buildSystemHealthTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SuperAdminTheme.cardDecoration(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SuperAdminTheme.primaryBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.settings_rounded, color: SuperAdminTheme.primaryBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Super Admin Platform Settings & Security',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: SuperAdminTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage administrator role hierarchies, granular module permissions, 2FA security policies, and payment gateway webhooks.',
                  style: TextStyle(fontSize: 13, color: SuperAdminTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: Roles & Permissions ---
  Widget _buildRolesTab(BuildContext context, SuperAdminSession auth) {
    final roles = SuperAdminRole.values;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: SuperAdminTheme.cardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Role-Based Access Control (RBAC) Matrix',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Super Admin maintains strict separation of duty between Finance, Support, and Operations teams.',
                  style: TextStyle(fontSize: 12, color: SuperAdminTheme.textSecondary),
                ),
                const SizedBox(height: 20),

                // Roles Cards
                ...roles.map((r) {
                  final isCurrent = auth.currentRole == r;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isCurrent ? SuperAdminTheme.primaryBlue.withOpacity(0.04) : SuperAdminTheme.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCurrent ? SuperAdminTheme.primaryBlue.withOpacity(0.4) : SuperAdminTheme.border,
                        width: isCurrent ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: SuperAdminTheme.primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.verified_user_rounded, color: SuperAdminTheme.primaryBlue, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        r.label,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: SuperAdminTheme.primaryBlue,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('ACTIVE SESSION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    _getRoleDescription(r),
                                    style: TextStyle(fontSize: 12, color: SuperAdminTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildPermChip('Manage Businesses', r.canAccessBusinesses()),
                            _buildPermChip('Manage Users', r.canAccessUsers()),
                            _buildPermChip('Sales & Revenue', r.canAccessSales()),
                            _buildPermChip('Issue Refunds', r.canIssueRefunds),
                            _buildPermChip('Modify Subscriptions', r.canModifySubscriptions),
                            _buildPermChip('Support Desk', r.canAccessSupport()),
                            _buildPermChip('Feature Modules', r.canAccessModules()),
                            _buildPermChip('Broadcast Notifications', r.canBroadcastNotifications),
                            _buildPermChip('Audit Trail', r.canAccessAuditLogs()),
                            _buildPermChip('Platform Settings', r.canAccessSettings()),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: Security & Auth ---
  Widget _buildSecurityTab(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: SuperAdminTheme.cardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Security Policies & 2FA Enforcement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
                const SizedBox(height: 16),

                // 2FA Switch
                SwitchListTile(
                  value: _enforce2FA,
                  activeColor: SuperAdminTheme.primaryBlue,
                  title: const Text('Enforce Multi-Factor Authentication (2FA) for all Admins', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary)),
                  subtitle: Text('Requires Authenticator OTP or Hardware FIDO key on every admin login', style: TextStyle(fontSize: 11, color: SuperAdminTheme.textSecondary)),
                  onChanged: (v) => setState(() => _enforce2FA = v),
                ),
                const Divider(color: SuperAdminTheme.border),

                // Session Timeout
                ListTile(
                  title: const Text('Session Inactivity Auto-Logout Timeout', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary)),
                  subtitle: Text('Terminate active dashboard session if operator is idle', style: TextStyle(fontSize: 11, color: SuperAdminTheme.textSecondary)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: SuperAdminTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SuperAdminTheme.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _sessionTimeout,
                        items: const [
                          DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                          DropdownMenuItem(value: 30, child: Text('30 Minutes')),
                          DropdownMenuItem(value: 60, child: Text('1 Hour')),
                          DropdownMenuItem(value: 240, child: Text('4 Hours')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _sessionTimeout = v);
                        },
                      ),
                    ),
                  ),
                ),
                const Divider(color: SuperAdminTheme.border),

                // IP Whitelisting CIDRs
                ListTile(
                  title: const Text('Portal IP CIDR Whitelisting', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary)),
                  subtitle: Text('Restrict Super Admin web panel access to authorized corporate VPN & office IPs', style: TextStyle(fontSize: 11, color: SuperAdminTheme.textSecondary)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: SuperAdminTheme.successGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('172.16.0.0/16 Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SuperAdminTheme.successGreen)),
                  ),
                ),

                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Security policies saved and distributed to all clusters!'),
                        backgroundColor: SuperAdminTheme.successGreen,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.shield_rounded, size: 16),
                  label: const Text('Save Security Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SuperAdminTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 3: Platform Config ---
  Widget _buildPlatformConfigTab(BuildContext context, SuperAdminApiService api) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: SuperAdminTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('General Platform & Billing Configuration', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
            const SizedBox(height: 20),

            // Maintenance Mode
            SwitchListTile(
              value: _maintenanceMode,
              activeColor: SuperAdminTheme.errorRed,
              title: const Text('Platform Maintenance Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
              subtitle: Text('Pause cloud sync and merchant logins with an apology banner (Offline billing continues)', style: TextStyle(fontSize: 11, color: SuperAdminTheme.textSecondary)),
              onChanged: (v) => setState(() => _maintenanceMode = v),
            ),
            const Divider(color: SuperAdminTheme.border),

            // Default Free Trial Days
            ListTile(
              title: const Text('Default Free Trial Period', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary)),
              subtitle: Text('Number of complimentary trial days granted to new merchant registrations', style: TextStyle(fontSize: 11, color: SuperAdminTheme.textSecondary)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: SuperAdminTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SuperAdminTheme.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _defaultTrialDays,
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('7 Days')),
                      DropdownMenuItem(value: 14, child: Text('14 Days (Standard)')),
                      DropdownMenuItem(value: 30, child: Text('30 Days')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _defaultTrialDays = v);
                    },
                  ),
                ),
              ),
            ),
            const Divider(color: SuperAdminTheme.border),

            // GST Rate
            ListTile(
              title: const Text('Standard GST Tax Rate (%)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary)),
              subtitle: Text('Default tax percentage applied on platform subscription invoices', style: TextStyle(fontSize: 11, color: SuperAdminTheme.textSecondary)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: SuperAdminTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SuperAdminTheme.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<double>(
                    value: _defaultGstRate,
                    items: const [
                      DropdownMenuItem(value: 0.0, child: Text('0% (Exempt)')),
                      DropdownMenuItem(value: 5.0, child: Text('5% GST')),
                      DropdownMenuItem(value: 12.0, child: Text('12% GST')),
                      DropdownMenuItem(value: 18.0, child: Text('18% GST (Standard)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _defaultGstRate = v);
                    },
                  ),
                ),
              ),
            ),
            const Divider(color: SuperAdminTheme.border),

            // Invoice Prefix
            ListTile(
              title: const Text('Invoice Numbering Prefix', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary)),
              subtitle: Text('Prefix appended before auto-incrementing platform invoice codes', style: TextStyle(fontSize: 11, color: SuperAdminTheme.textSecondary)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: SuperAdminTheme.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: SuperAdminTheme.border),
                ),
                child: Text(_invoicePrefix, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
              ),
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Platform configuration updated and broadcasted!'),
                    backgroundColor: SuperAdminTheme.successGreen,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SuperAdminTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Save Platform Settings'),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 4: System Health ---
  Widget _buildSystemHealthTab(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: SuperAdminTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Infrastructure & Third-Party Integration Health', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
            const SizedBox(height: 16),

            _buildHealthItem(
              name: 'Cloud Firestore Database Cluster (Mumbai)',
              status: 'Operational',
              latency: '18 ms',
              isHealthy: true,
              icon: Icons.storage_rounded,
            ),
            const Divider(color: SuperAdminTheme.border),

            _buildHealthItem(
              name: 'Payment Gateway Webhook (Razorpay / UPI)',
              status: 'Active (100% Success)',
              latency: '45 ms',
              isHealthy: true,
              icon: Icons.payments_rounded,
            ),
            const Divider(color: SuperAdminTheme.border),

            _buildHealthItem(
              name: 'WhatsApp Cloud API Gateway (Meta Business)',
              status: 'Connected (Tier 2 Verified)',
              latency: '120 ms',
              isHealthy: true,
              icon: Icons.chat_rounded,
            ),
            const Divider(color: SuperAdminTheme.border),

            _buildHealthItem(
              name: 'Push Notification Dispatcher (Firebase FCM)',
              status: 'Operational',
              latency: '32 ms',
              isHealthy: true,
              icon: Icons.notifications_active_rounded,
            ),
            const Divider(color: SuperAdminTheme.border),

            _buildHealthItem(
              name: 'SMTP Email Delivery Relay (SendGrid)',
              status: 'Operational (99.8% Inbox)',
              latency: '85 ms',
              isHealthy: true,
              icon: Icons.email_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthItem({
    required String name,
    required String status,
    required String latency,
    required bool isHealthy,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isHealthy ? SuperAdminTheme.successGreen : SuperAdminTheme.errorRed).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: isHealthy ? SuperAdminTheme.successGreen : SuperAdminTheme.errorRed, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
                Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isHealthy ? SuperAdminTheme.successGreen : SuperAdminTheme.errorRed)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: SuperAdminTheme.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: SuperAdminTheme.border),
            ),
            child: Text(latency, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SuperAdminTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildPermChip(String label, bool isGranted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isGranted ? SuperAdminTheme.successGreen.withOpacity(0.12) : SuperAdminTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isGranted ? SuperAdminTheme.successGreen.withOpacity(0.4) : SuperAdminTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGranted ? Icons.check_rounded : Icons.close_rounded,
            size: 12,
            color: isGranted ? SuperAdminTheme.successGreen : SuperAdminTheme.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isGranted ? FontWeight.w700 : FontWeight.w500,
              color: isGranted ? SuperAdminTheme.successGreen : SuperAdminTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleDescription(SuperAdminRole role) {
    switch (role) {
      case SuperAdminRole.superAdmin:
        return 'Full unrestricted platform administrative control, audit forensics, and billing configuration.';
      case SuperAdminRole.financeAdmin:
        return 'Financial reconciliations, revenue reports, invoice auditing, and refund issuance.';
      case SuperAdminRole.supportAdmin:
        return 'Support desk tickets, merchant communication, and printer configuration assistance.';
      case SuperAdminRole.operationsAdmin:
        return 'Merchant lifecycle management, plan extensions, and module access overrides.';
    }
  }
}
