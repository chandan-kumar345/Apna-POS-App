import 'package:flutter/material.dart';
import '../theme/super_admin_theme.dart';
import '../services/super_admin_auth_service.dart';

class SuperAdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final bool isCollapsed;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onToggleCollapse;
  final VoidCallback onLogout;

  const SuperAdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.isCollapsed,
    required this.onItemSelected,
    required this.onToggleCollapse,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final session = SuperAdminSession();
    final role = session.currentRole;

    // Define 15 Navigation Items with pastel squircle colors matching Windows build
    final allNavItems = <_NavItem>[
      _NavItem(0, 'Dashboard', Icons.dashboard_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF), true),
      _NavItem(1, 'Users', Icons.people_alt_rounded, const Color(0xFF0284C7), const Color(0xFFE0F2FE), role.canAccessUsers()),
      _NavItem(2, 'Businesses', Icons.storefront_rounded, const Color(0xFF10B981), const Color(0xFFDCFCE7), role.canAccessBusinesses()),
      _NavItem(3, 'Subscriptions', Icons.card_membership_rounded, const Color(0xFF7C3AED), const Color(0xFFF3E8FF), role.canAccessSubscriptions()),
      _NavItem(4, 'Plans', Icons.layers_rounded, const Color(0xFF6366F1), const Color(0xFFEEF2FF), role.canAccessPlans()),
      _NavItem(5, 'Sales', Icons.point_of_sale_rounded, const Color(0xFFEA580C), const Color(0xFFFFEDD5), role.canAccessSales()),
      _NavItem(6, 'Payments', Icons.payments_rounded, const Color(0xFF059669), const Color(0xFFECFDF5), role.canAccessPayments()),
      _NavItem(7, 'Revenue', Icons.analytics_rounded, const Color(0xFF1D4ED8), const Color(0xFFEBF2FE), role.canAccessRevenue()),
      _NavItem(8, 'Teams', Icons.group_work_rounded, const Color(0xFF8B5CF6), const Color(0xFFF5EBFB), role.canAccessSubscriptions()),
      _NavItem(9, 'Products / Modules', Icons.extension_rounded, const Color(0xFFD97706), const Color(0xFFFEF3EB), role.canAccessModules()),
      _NavItem(10, 'Support', Icons.support_agent_rounded, const Color(0xFFDB2777), const Color(0xFFFCE7F3), role.canAccessSupport()),
      _NavItem(11, 'Notifications', Icons.campaign_rounded, const Color(0xFFE11D48), const Color(0xFFFFE4E6), true),
      _NavItem(12, 'Activity Logs', Icons.history_rounded, const Color(0xFF475569), const Color(0xFFF1F5F9), role.canAccessAuditLogs()),
      _NavItem(13, 'Reports', Icons.assessment_rounded, const Color(0xFF0891B2), const Color(0xFFECFEFF), role.canAccessSales() || role.canAccessRevenue()),
      _NavItem(14, 'Settings', Icons.tune_rounded, const Color(0xFF334155), const Color(0xFFF8FAFC), role.canAccessSettings()),
    ];

    final visibleNavItems = allNavItems.where((item) => item.isAllowed).toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      width: isCollapsed ? 76 : 254,
      height: double.infinity,
      decoration: SuperAdminTheme.sidebarDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            // Sidebar Header / Collapse Toggle Bar
            Container(
              height: 58,
              padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: SuperAdminTheme.border)),
              ),
              child: Row(
                mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
                children: [
                  if (!isCollapsed)
                    Row(
                      children: const [
                        Icon(Icons.grid_view_rounded, size: 18, color: SuperAdminTheme.primary),
                        SizedBox(width: 8),
                        Text(
                          'NAVIGATION',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: SuperAdminTheme.textMuted,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  IconButton(
                    icon: Icon(
                      isCollapsed ? Icons.menu_rounded : Icons.menu_open_rounded,
                      size: 20,
                      color: SuperAdminTheme.textSecondary,
                    ),
                    onPressed: onToggleCollapse,
                    tooltip: isCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            // Scrollable Navigation Items List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                itemCount: visibleNavItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 3),
                itemBuilder: (context, idx) {
                  final item = visibleNavItems[idx];
                  final isSelected = selectedIndex == item.index;

                  return _buildNavItemWidget(
                    item: item,
                    isSelected: isSelected,
                    isCollapsed: isCollapsed,
                  );
                },
              ),
            ),

            // Bottom Section: System Status & Admin Profile
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: SuperAdminTheme.border)),
                color: Color(0xFFF8FAFC),
              ),
              child: isCollapsed
                  ? Column(
                      children: [
                        _buildStatusDot(),
                        const SizedBox(height: 8),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, size: 18, color: SuperAdminTheme.danger),
                          onPressed: onLogout,
                          tooltip: 'Logout',
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // System Status Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: SuperAdminTheme.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildStatusDot(),
                              const SizedBox(width: 6),
                              const Text(
                                'Systems Operational',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: SuperAdminTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Admin User Row
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: SuperAdminTheme.primaryLight,
                              child: Text(
                                session.adminName.isNotEmpty ? session.adminName[0] : 'A',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: SuperAdminTheme.primary),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.adminName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: SuperAdminTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    role.label,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: SuperAdminTheme.primary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout_rounded, size: 16, color: SuperAdminTheme.textMuted),
                              onPressed: onLogout,
                              tooltip: 'Logout',
                              splashRadius: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDot() {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: SuperAdminTheme.success,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0xFF10B981),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItemWidget({
    required _NavItem item,
    required bool isSelected,
    required bool isCollapsed,
  }) {
    return Tooltip(
      message: isCollapsed ? item.title : '',
      waitDuration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onItemSelected(item.index),
          borderRadius: BorderRadius.circular(12),
          hoverColor: const Color(0xFFEFF6FF).withValues(alpha: 0.6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 8 : 8,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.35), width: 1.2)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                // Pastel squircle icon container
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.iconBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: item.iconColor.withValues(alpha: 0.2),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    item.icon,
                    size: 18,
                    color: item.iconColor,
                  ),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF334155),
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final int index;
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final bool isAllowed;
  const _NavItem(this.index, this.title, this.icon, this.iconColor, this.iconBg, this.isAllowed);
}

