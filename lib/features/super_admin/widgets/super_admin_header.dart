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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: Colors.transparent,
      child: Row(
        children: [
          // 1. LOGO & HIGHLIGHTED SEMI-CURVED BRAND BADGE (Windows Build Style)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circular Brand Logo Container with Drop Shadow
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: SuperAdminTheme.primary,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Highlighted Semi-Curved Brand Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Apna POS',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.0),
                      ),
                      child: const Text(
                        'SUPER ADMIN',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0052FF),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(width: 20),

          // 2. Active Screen Title & Breadcrumb Indicator
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pageTitle,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF8FAFC),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (breadcrumbSubtitle != null)
                  Text(
                    breadcrumbSubtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // 3. Global Search Trigger Button (Glass Neumorphic Search Bar)
          InkWell(
            onTap: () => SuperAdminGlobalSearchDialog.show(context, onNavigate: onNavigate),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 260,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 1.0),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Global Search (Ctrl + K)...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '⌘K',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 4. Live Server Status Dot Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF10B981),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'ONLINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // 5. Admin Alerts / Notifications Bell Button
          PopupMenuButton<int>(
            tooltip: 'System Alerts & Reminders',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_none_rounded, size: 20, color: Colors.white),
                  if (expiringCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: const BoxDecoration(
                          color: SuperAdminTheme.warning,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$expiringCount',
                          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
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

          const SizedBox(width: 12),

          // 6. Admin Profile Pill Button on Header
          PopupMenuButton<SuperAdminRole>(
            tooltip: 'Admin Profile & Role',
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (role) {
              session.switchRole(role);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: Colors.white,
                    child: Text(
                      session.adminName.isNotEmpty ? session.adminName[0] : 'A',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0052FF)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    session.currentRole.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Colors.white70),
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

