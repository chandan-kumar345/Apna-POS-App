import 'package:flutter/material.dart';
import '../theme/super_admin_theme.dart';
import '../models/super_admin_user_model.dart';
import '../services/super_admin_auth_service.dart';
import '../services/super_admin_api_service.dart';
import 'super_admin_global_search.dart';

class SuperAdminHeader extends StatelessWidget {
  final String pageTitle;
  final String? breadcrumbSubtitle;
  final Function(int targetTab, String? entityId)? onNavigate;
  final VoidCallback onLogout;

  const SuperAdminHeader({
    super.key,
    required this.pageTitle,
    this.breadcrumbSubtitle,
    this.onNavigate,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final session = SuperAdminSession();
    final api = SuperAdminApiService();
    final expiringCount = api.expiringSoonSubscriptions;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: SuperAdminTheme.surface,
        border: Border(
          bottom: BorderSide(color: SuperAdminTheme.border, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // Page Title & Breadcrumb
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pageTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: SuperAdminTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              if (breadcrumbSubtitle != null)
                Text(
                  breadcrumbSubtitle!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: SuperAdminTheme.textMuted,
                  ),
                ),
            ],
          ),

          const Spacer(),

          // Global Search Trigger Button
          InkWell(
            onTap: () => SuperAdminGlobalSearchDialog.show(context, onNavigate: onNavigate),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 280,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: SuperAdminTheme.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SuperAdminTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 16, color: SuperAdminTheme.textMuted),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Global Search (Ctrl + K)...',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: SuperAdminTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: SuperAdminTheme.border),
                    ),
                    child: const Text(
                      '⌘K',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SuperAdminTheme.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Admin Alerts / Notifications Button with Expiring Subscriptions Badge
          PopupMenuButton<int>(
            tooltip: 'System Alerts & Reminders',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SuperAdminTheme.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SuperAdminTheme.border),
                  ),
                  child: const Icon(Icons.notifications_none_rounded, size: 20, color: SuperAdminTheme.textSecondary),
                ),
                if (expiringCount > 0)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: const BoxDecoration(
                        color: SuperAdminTheme.warning,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$expiringCount',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Admin Alerts', style: TextStyle(fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: SuperAdminTheme.primaryLight, borderRadius: BorderRadius.circular(6)),
                      child: Text('$expiringCount new', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SuperAdminTheme.primary)),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              if (expiringCount > 0)
                PopupMenuItem(
                  onTap: () => onNavigate?.call(3, null), // Subscriptions
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.timer_rounded, color: SuperAdminTheme.warning),
                    title: Text('$expiringCount Subscriptions Expiring Soon', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Expiring within 7 days. Action required.', style: TextStyle(fontSize: 11)),
                  ),
                ),
              PopupMenuItem(
                onTap: () => onNavigate?.call(10, null), // Support
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.support_agent_rounded, color: SuperAdminTheme.primary),
                  title: Text('New High-Priority Support Ticket', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  subtitle: Text('Royal Biryani House reported printing issue.', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),

          const SizedBox(width: 14),

          // Role Switcher & Admin Profile Dropdown
          PopupMenuButton<SuperAdminRole>(
            tooltip: 'Admin Profile & Role',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (role) {
              session.switchRole(role);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SuperAdminTheme.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SuperAdminTheme.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: SuperAdminTheme.primary,
                    child: Text(
                      session.adminName[0],
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    session.currentRole.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: SuperAdminTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down_rounded, size: 18, color: SuperAdminTheme.textMuted),
                ],
              ),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.adminName, style: const TextStyle(fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
                    Text(session.adminEmail, style: const TextStyle(fontSize: 11, color: SuperAdminTheme.textMuted)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                enabled: false,
                child: Text('SWITCH ADMIN ROLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SuperAdminTheme.textMuted, letterSpacing: 0.5)),
              ),
              ...SuperAdminRole.values.map(
                (r) => PopupMenuItem(
                  value: r,
                  child: Row(
                    children: [
                      Icon(
                        session.currentRole == r ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: session.currentRole == r ? SuperAdminTheme.primary : SuperAdminTheme.textMuted,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(r.label, style: const TextStyle(fontSize: 12.5)),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                onTap: onLogout,
                child: Row(
                  children: const [
                    Icon(Icons.logout_rounded, color: SuperAdminTheme.danger, size: 16),
                    SizedBox(width: 8),
                    Text('Logout of Admin Console', style: TextStyle(color: SuperAdminTheme.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
