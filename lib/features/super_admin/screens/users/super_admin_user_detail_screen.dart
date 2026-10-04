import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../models/super_admin_user_model.dart';
import '../../services/super_admin_api_service.dart';
import '../../widgets/super_admin_confirmation_dialog.dart';

class SuperAdminUserDetailScreen extends StatelessWidget {
  final String userId;
  final VoidCallback onBack;
  final Function(int targetTab, String? entityId)? onNavigate;

  const SuperAdminUserDetailScreen({
    super.key,
    required this.userId,
    required this.onBack,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final api = SuperAdminApiService();
    final user = api.users.firstWhere(
      (u) => u.id == userId,
      orElse: () => api.users.first,
    );

    final biz = api.businesses.firstWhere(
      (b) => b.id == user.businessId,
      orElse: () => api.businesses.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Navigation Bar
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Back to Users List'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SuperAdminTheme.textSecondary,
                  side: const BorderSide(color: SuperAdminTheme.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const Spacer(),
              if (user.status != 'suspended')
                ElevatedButton.icon(
                  onPressed: () => _confirmSuspend(context, api, user),
                  icon: const Icon(Icons.block_rounded, size: 16),
                  label: const Text('Suspend User Account'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SuperAdminTheme.danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    api.activateUser(user.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User account activated successfully'), backgroundColor: SuperAdminTheme.success),
                    );
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Activate User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SuperAdminTheme.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {
                  api.resetUserPassword(user.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Password reset instructions dispatched to ${user.email}')),
                  );
                },
                icon: const Icon(Icons.lock_reset_rounded, size: 16),
                label: const Text('Reset Password'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SuperAdminTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Top Profile Card (Section 8: Basic Information)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: SuperAdminTheme.neumorphicBox(radius: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: SuperAdminTheme.primaryLight,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0] : 'U',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: SuperAdminTheme.primary),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(user.name, style: SuperAdminTheme.h1),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: user.status == 'suspended'
                                  ? SuperAdminTheme.dangerLight
                                  : SuperAdminTheme.successLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: user.status == 'suspended'
                                    ? SuperAdminTheme.danger.withValues(alpha: 0.3)
                                    : SuperAdminTheme.success.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              user.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: user.status == 'suspended' ? SuperAdminTheme.danger : SuperAdminTheme.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'User ID: ${user.id} • Registered ${user.createdAt.toString().split(" ").first} • Last active: ${user.lastLogin != null ? user.lastLogin.toString().split(".").first : "Never"}',
                        style: SuperAdminTheme.caption,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 15, color: SuperAdminTheme.textMuted),
                          const SizedBox(width: 6),
                          Text(user.email, style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textSecondary, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 16),
                          const Icon(Icons.phone_outlined, size: 15, color: SuperAdminTheme.textMuted),
                          const SizedBox(width: 6),
                          Text(user.phone, style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textSecondary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2 Columns: Business & Subscription Info (Section 8: Business & Subscription)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Business Information
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: SuperAdminTheme.neumorphicBox(radius: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Business Information', style: SuperAdminTheme.h3),
                          TextButton.icon(
                            onPressed: () => onNavigate?.call(2, biz.id), // Go to business detail
                            icon: const Text('View Business', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            label: const Icon(Icons.arrow_forward_rounded, size: 14),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: SuperAdminTheme.border),
                      _buildInfoRow('Business Name', biz.name),
                      _buildInfoRow('Business ID', biz.id),
                      _buildInfoRow('Category', biz.category),
                      _buildInfoRow('Location', '${biz.city}, ${biz.state}'),
                      _buildInfoRow('Branches Count', '${biz.branchesCount} Outlet(s)'),
                      _buildInfoRow('User Role', user.role),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Subscription Information
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: SuperAdminTheme.neumorphicBox(radius: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Subscription Details', style: SuperAdminTheme.h3),
                      const Divider(height: 24, color: SuperAdminTheme.border),
                      _buildInfoRow('Current Plan', biz.planName),
                      _buildInfoRow('Subscription Status', biz.status.label),
                      _buildInfoRow('Start Date', biz.startDate.toString().split(' ').first),
                      _buildInfoRow('Expiry Date', biz.expiryDate.toString().split(' ').first),
                      _buildInfoRow('Total Amount Paid', '₹${biz.subscriptionRevenue.toStringAsFixed(0)}'),
                      _buildInfoRow('Auto-Renewal', 'Enabled (Card on file)'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Team Members Section (Section 8: Team)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: SuperAdminTheme.neumorphicBox(radius: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Associated Team Members', style: SuperAdminTheme.h3),
                const SizedBox(height: 4),
                const Text('Staff and managers registered under this restaurant account', style: SuperAdminTheme.caption),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: SuperAdminTheme.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SuperAdminTheme.border),
                  ),
                  child: Column(
                    children: [
                      _buildTeamRow('Amit Sharma (You)', 'Owner', 'Full Control', '2 mins ago', true),
                      const Divider(height: 1, color: SuperAdminTheme.border),
                      _buildTeamRow('Deepak Rao', 'Head Cashier', 'Billing, Split, Reports', '1 hour ago', false),
                      const Divider(height: 1, color: SuperAdminTheme.border),
                      _buildTeamRow('Sunita Patel', 'Kitchen Chef', 'KDS, Recipe Bump', 'Yesterday', false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildTeamRow(String name, String role, String perms, String lastActive, bool isOwner) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: isOwner ? SuperAdminTheme.primaryLight : const Color(0xFFE2E8F0),
            child: Text(name[0], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isOwner ? SuperAdminTheme.primary : SuperAdminTheme.textSecondary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
                Text(perms, style: const TextStyle(fontSize: 11, color: SuperAdminTheme.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: SuperAdminTheme.border)),
            child: Text(role, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SuperAdminTheme.textSecondary)),
          ),
          const SizedBox(width: 20),
          Text(lastActive, style: const TextStyle(fontSize: 11.5, color: SuperAdminTheme.textMuted)),
        ],
      ),
    );
  }

  void _confirmSuspend(BuildContext context, SuperAdminApiService api, PlatformUser user) {
    SuperAdminConfirmationDialog.show(
      context: context,
      title: 'Suspend User Account?',
      message: 'Are you sure you want to suspend access for ${user.name}? They will immediately be logged out and cannot sign in until activated.',
      confirmLabel: 'Suspend User',
      onConfirmWithReason: (reason) async {
        api.suspendUser(user.id, reason);
      },
    );
  }
}
