import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/super_admin_theme.dart';
import '../services/super_admin_auth_service.dart';
import 'super_admin_sidebar.dart';
import 'super_admin_header.dart';
import 'super_admin_global_search.dart';

// Screens
import '../screens/auth/super_admin_login_screen.dart';
import '../screens/dashboard/super_admin_dashboard_screen.dart';
import '../screens/users/super_admin_users_screen.dart';
import '../screens/users/super_admin_user_detail_screen.dart';
import '../screens/businesses/super_admin_businesses_screen.dart';
import '../screens/businesses/super_admin_business_detail_screen.dart';
import '../screens/subscriptions/super_admin_subscriptions_screen.dart';
import '../screens/subscriptions/super_admin_plans_screen.dart';
import '../screens/sales/super_admin_sales_screen.dart';
import '../screens/sales/super_admin_business_sales_screen.dart';
import '../screens/payments/super_admin_payments_screen.dart';
import '../screens/revenue/super_admin_revenue_screen.dart';
import '../screens/revenue/super_admin_revenue_report_screen.dart';
import '../screens/teams/super_admin_team_subscriptions_screen.dart';
import '../screens/modules/super_admin_modules_screen.dart';
import '../screens/support/super_admin_support_screen.dart';
import '../screens/notifications/super_admin_notifications_screen.dart';
import '../screens/audit_logs/super_admin_audit_logs_screen.dart';
import '../screens/reports/super_admin_reports_screen.dart';
import '../screens/settings/super_admin_settings_screen.dart';

class SuperAdminLayout extends StatefulWidget {
  final int initialTab;

  const SuperAdminLayout({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<SuperAdminLayout> createState() => _SuperAdminLayoutState();
}

class _SuperAdminLayoutState extends State<SuperAdminLayout> {
  late int _selectedTab;
  bool _isSidebarCollapsed = false;

  // Drill-down states
  String? _selectedUserId;
  String? _selectedBusinessId;
  String? _selectedBusinessSalesId;
  bool _showingRevenueReport = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  void _handleNavigation(int targetTab, String? entityId) {
    setState(() {
      _selectedTab = targetTab;
      _showingRevenueReport = false;

      if (targetTab == 1 && entityId != null) {
        _selectedUserId = entityId;
      } else if (targetTab == 2 && entityId != null) {
        _selectedBusinessId = entityId;
      } else if (targetTab == 5 && entityId != null) {
        _selectedBusinessSalesId = entityId;
      } else {
        _selectedUserId = null;
        _selectedBusinessId = null;
        _selectedBusinessSalesId = null;
      }
    });
  }

  void _handleCustomRoute(String route) {
    setState(() {
      if (route == 'revenue_report') {
        _selectedTab = 7;
        _showingRevenueReport = true;
      } else if (route == 'modules') {
        _selectedTab = 9;
      } else if (route == 'support') {
        _selectedTab = 10;
      } else if (route == 'audit_logs') {
        _selectedTab = 12;
      }
    });
  }

  void _handleLogout() {
    SuperAdminSession().logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SuperAdminLoginScreen()),
    );
  }

  String _getPageTitle() {
    if (_showingRevenueReport) return 'Revenue & Billing Report';
    if (_selectedUserId != null) return 'User Profile Details';
    if (_selectedBusinessId != null) return 'Business 360° Overview';
    if (_selectedBusinessSalesId != null) return 'Business Sales Analytics';

    switch (_selectedTab) {
      case 0:
        return 'Executive Overview';
      case 1:
        return 'Platform Users';
      case 2:
        return 'Registered Businesses';
      case 3:
        return 'Subscription Management';
      case 4:
        return 'Subscription Plans';
      case 5:
        return 'Sales Overview';
      case 6:
        return 'Payment Transactions';
      case 7:
        return 'Revenue Analytics';
      case 8:
        return 'Team Subscriptions';
      case 9:
        return 'Feature Modules';
      case 10:
        return 'Support Tickets';
      case 11:
        return 'Broadcast Notifications';
      case 12:
        return 'Activity & Audit Logs';
      case 13:
        return 'Platform Reports';
      case 14:
        return 'Settings & Roles';
      default:
        return 'Dashboard';
    }
  }

  String? _getBreadcrumb() {
    if (_showingRevenueReport) return 'Revenue > Business-Wise Report';
    if (_selectedUserId != null) return 'Users > User Profile [$_selectedUserId]';
    if (_selectedBusinessId != null) return 'Businesses > Overview [$_selectedBusinessId]';
    if (_selectedBusinessSalesId != null) return 'Sales > Business Breakdown [$_selectedBusinessSalesId]';
    return null;
  }

  Widget _buildActiveScreen() {
    // Drilldowns take precedence
    if (_showingRevenueReport) {
      return SuperAdminRevenueReportScreen(
        onBack: () => setState(() => _showingRevenueReport = false),
        onSelectBusiness: (bizId) {
          _handleNavigation(2, bizId);
        },
      );
    }

    if (_selectedTab == 1 && _selectedUserId != null) {
      return SuperAdminUserDetailScreen(
        userId: _selectedUserId!,
        onBack: () => setState(() => _selectedUserId = null),
        onNavigate: _handleNavigation,
      );
    }

    if (_selectedTab == 2 && _selectedBusinessId != null) {
      return SuperAdminBusinessDetailScreen(
        businessId: _selectedBusinessId!,
        onBack: () => setState(() => _selectedBusinessId = null),
        onNavigate: _handleNavigation,
      );
    }

    if (_selectedTab == 5 && _selectedBusinessSalesId != null) {
      return SuperAdminBusinessSalesScreen(
        initialBusinessId: _selectedBusinessSalesId,
        onNavigate: _handleNavigation,
      );
    }

    // Base Tab Screens
    switch (_selectedTab) {
      case 0:
        return SuperAdminDashboardScreen(onNavigate: _handleNavigation);
      case 1:
        return SuperAdminUsersScreen(
          onSelectUser: (uId) => setState(() => _selectedUserId = uId),
          onNavigate: _handleNavigation,
        );
      case 2:
        return SuperAdminBusinessesScreen(
          onSelectBusiness: (bId) => setState(() => _selectedBusinessId = bId),
          onNavigate: _handleNavigation,
        );
      case 3:
        return SuperAdminSubscriptionsScreen(onNavigate: _handleNavigation);
      case 4:
        return const SuperAdminPlansScreen();
      case 5:
        return SuperAdminSalesScreen(onNavigate: _handleNavigation);
      case 6:
        return SuperAdminPaymentsScreen(onNavigate: _handleNavigation);
      case 7:
        return SuperAdminRevenueScreen(onNavigate: _handleCustomRoute);
      case 8:
        return SuperAdminTeamSubscriptionsScreen(onNavigate: _handleNavigation);
      case 9:
        return const SuperAdminModulesScreen();
      case 10:
        return const SuperAdminSupportScreen();
      case 11:
        return const SuperAdminNotificationsScreen();
      case 12:
        return const SuperAdminAuditLogsScreen();
      case 13:
        return SuperAdminReportsScreen(onNavigate: _handleCustomRoute);
      case 14:
        return const SuperAdminSettingsScreen();
      default:
        return SuperAdminDashboardScreen(onNavigate: _handleNavigation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          SuperAdminGlobalSearchDialog.show(context, onNavigate: _handleNavigation);
        },
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
          SuperAdminGlobalSearchDialog.show(context, onNavigate: _handleNavigation);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: SuperAdminTheme.bg,
          body: Row(
            children: [
              // 1. Persistent Neumorphic Sidebar
              SuperAdminSidebar(
                selectedIndex: _selectedTab,
                isCollapsed: _isSidebarCollapsed,
                onItemSelected: (idx) {
                  setState(() {
                    _selectedTab = idx;
                    _selectedUserId = null;
                    _selectedBusinessId = null;
                    _selectedBusinessSalesId = null;
                    _showingRevenueReport = false;
                  });
                },
                onToggleCollapse: () {
                  setState(() {
                    _isSidebarCollapsed = !_isSidebarCollapsed;
                  });
                },
                onLogout: _handleLogout,
              ),

              // 2. Main Content Canvas
              Expanded(
                child: Column(
                  children: [
                    // Persistent Top Header
                    SuperAdminHeader(
                      pageTitle: _getPageTitle(),
                      breadcrumbSubtitle: _getBreadcrumb(),
                      onNavigate: _handleNavigation,
                      onLogout: _handleLogout,
                    ),

                    // Scrollable Active Screen Content
                    Expanded(
                      child: Container(
                        color: SuperAdminTheme.bg,
                        child: _buildActiveScreen(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
