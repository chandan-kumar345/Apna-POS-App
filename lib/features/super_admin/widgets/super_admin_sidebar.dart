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

    // Define 15 Navigation Items
    final allNavItems = <_NavItem>[
      _NavItem(0, 'Dashboard', Icons.dashboard_rounded, true),
      _NavItem(1, 'Users', Icons.people_alt_rounded, role.canAccessUsers()),
      _NavItem(2, 'Businesses', Icons.storefront_rounded, role.canAccessBusinesses()),
      _NavItem(3, 'Subscriptions', Icons.card_membership_rounded, role.canAccessSubscriptions()),
      _NavItem(4, 'Plans', Icons.layers_rounded, role.canAccessPlans()),
      _NavItem(5, 'Sales', Icons.point_of_sale_rounded, role.canAccessSales()),
      _NavItem(6, 'Payments', Icons.payments_rounded, role.canAccessPayments()),
      _NavItem(7, 'Revenue', Icons.analytics_rounded, role.canAccessRevenue()),
      _NavItem(8, 'Teams', Icons.group_work_rounded, role.canAccessSubscriptions()),
      _NavItem(9, 'Products / Modules', Icons.extension_rounded, role.canAccessModules()),
      _NavItem(10, 'Support', Icons.support_agent_rounded, role.canAccessSupport()),
      _NavItem(11, 'Notifications', Icons.campaign_rounded, true),
      _NavItem(12, 'Activity Logs', Icons.history_rounded, role.canAccessAuditLogs()),
      _NavItem(13, 'Reports', Icons.assessment_rounded, role.canAccessSales() || role.canAccessRevenue()),
      _NavItem(14, 'Settings', Icons.tune_rounded, role.canAccessSettings()),
    ];

    final visibleNavItems = allNavItems.where((item) => item.isAllowed).toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      width: isCollapsed ? 76 : 248,
      decoration: BoxDecoration(
        color: SuperAdminTheme.surface,
        border: const Border(
          right: BorderSide(color: SuperAdminTheme.border, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            offset: const Offset(2, 0),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo & Brand Header
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 14 : 18),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: SuperAdminTheme.border)),
            ),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: [
                if (!isCollapsed) ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: SuperAdminTheme.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: SuperAdminTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Apna POSS',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: SuperAdminTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Super Admin Web',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: SuperAdminTheme.primary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
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

          // Scrollable Navigation List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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

          // Bottom Section: Admin Profile & System Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: SuperAdminTheme.border)),
              color: SuperAdminTheme.bg,
            ),
            child: isCollapsed
                ? Column(
                    children: [
                      _buildStatusDot(),
                      const SizedBox(height: 10),
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
                      // System Live Status Pill
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
                                fontWeight: FontWeight.w600,
                                color: SuperAdminTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Admin Profile Card
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: SuperAdminTheme.primary,
                            child: Text(
                              session.adminName.isNotEmpty ? session.adminName[0] : 'A',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
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
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: SuperAdminTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  role.label,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w500,
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
          borderRadius: BorderRadius.circular(8),
          hoverColor: SuperAdminTheme.primaryLight.withValues(alpha: 0.5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 12 : 12,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: isSelected ? SuperAdminTheme.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: SuperAdminTheme.primary.withValues(alpha: 0.25), width: 1.0)
                  : null,
            ),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(
                  item.icon,
                  size: 19,
                  color: isSelected ? SuperAdminTheme.primary : SuperAdminTheme.textSecondary,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? SuperAdminTheme.primary : SuperAdminTheme.textSecondary,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: SuperAdminTheme.primary,
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
  final bool isAllowed;
  const _NavItem(this.index, this.title, this.icon, this.isAllowed);
}
