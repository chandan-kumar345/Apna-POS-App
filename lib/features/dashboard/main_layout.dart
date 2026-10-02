import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/database/database_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/widgets/glass_company_name_badge.dart';
import '../../core/widgets/connection_status_badge.dart';
import '../pos/pos_register_screen.dart';
import '../tables/table_management_screen.dart';
import '../orders/orders_screen.dart';
import '../menu/menu_management_screen.dart';
import '../inventory/inventory_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/business_settings_hub_screen.dart';
import '../loyalty/screens/loyalty_landing_screen.dart';
import '../crm/screens/crm_leads_screen.dart';
import '../notifications/screens/notifications_screen.dart';
import '../notifications/services/notification_service.dart';
import '../settings/superadmin_order_deletion_screen.dart';

import '../../core/models/table_model.dart';
import '../../core/models/order_model.dart';
import '../auth/login_screen.dart';
import 'dashboard_screen.dart';
import '../subscription/screens/subscription_screen.dart';
import '../campaign/screens/campaign_screen.dart';
import '../staff/screens/staff_management_screen.dart';
import '../staff/screens/staff_profile_screen.dart';
import '../../core/services/sound_service.dart';


/// Declarative Navigation Item Definition for dynamic sidebar rendering
class NavItemDef {
  final int index;
  final String title;
  final IconData icon;
  final String imageAsset;
  final Color iconColor;
  final Color iconBgColor;
  final bool isPremium;
  final String? Function(DatabaseService db) getBadge;
  final bool Function(dynamic user) canAccess;

  const NavItemDef({
    required this.index,
    required this.title,
    required this.icon,
    required this.imageAsset,
    required this.iconColor,
    required this.iconBgColor,
    this.isPremium = false,
    required this.getBadge,
    required this.canAccess,
  });
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with SingleTickerProviderStateMixin {
  final GlobalKey<GlassDashboardScreenState> _dashboardKey = GlobalKey<GlassDashboardScreenState>();
  int _selectedIndex = 1;
  final List<int> _tabHistory = [];
  bool _isSidebarOpen = false;
  bool _isPosFullScreen = false;
  bool _isStaffDropdownOpen = false;
  String? _selectedTableForPos;
  OrderType? _selectedOrderTypeForPos;
  final db = DatabaseService();

  bool _canAccessTab(int index) {
    final user = db.currentUser;
    // Tab 13 (Delete Orders) is strictly restricted to SuperAdmin in Web mode only.
    // It is NEVER accessible or visible on Android, Windows, or for regular users/owners.
    if (index == 13) {
      return kIsWeb && user != null && user.isSuperAdmin;
    }

    if (user == null || user.isOwner || user.isAdmin) return true;
    switch (index) {
      case 0: // Dashboard
        return user.hasPermission('dashboard') || user.hasPermission('reports');
      case 1: // POS
        return user.hasPermission('pos');
      case 2: // Tables
        return user.hasPermission('tables');
      case 3: // My Orders
        return user.hasPermission('orders');
      case 4: // Menu & Categories
        return user.hasPermission('menu') || user.hasPermission('products');
      case 5: // Inventory
        return user.hasPermission('inventory');
      case 6: // Sales Report
        return true; // Staff can always access their own Sales Report
      case 7: // CRM
        return user.hasPermission('crm') || user.hasPermission('customers');
      case 8: // Loyalty
        return user.hasPermission('loyalty');
      case 9: // Campaign
        return user.hasPermission('campaign');
      case 10: // Staff Setting
        return user.hasPermission('staff') || user.hasPermission('settings_staff');
      case 11: // Business Setting
        return user.hasPermission('settings');
      case 12: // Staff Profile
        return true; // Everyone / Staff can access their own profile
      default:
        return true;
    }
  }

  List<NavItemDef> _getAvailableNavItems() {
    final allItems = [
      NavItemDef(
        index: 12,
        title: 'Staff Profile',
        icon: Icons.person_rounded,
        imageAsset: 'assets/images/Side bar icons/staff_profile.png',
        iconColor: const Color(0xFF2563EB),
        iconBgColor: const Color(0xFFEFF6FF),
        getBadge: (db) => null,
        canAccess: (user) => true,
      ),
      NavItemDef(
        index: 0,
        title: 'Dashboard',
        icon: Icons.home_rounded,
        imageAsset: 'assets/images/Side bar icons/home.png',
        iconColor: const Color(0xFF1D4ED8),
        iconBgColor: const Color(0xFFEBF2FE),
        getBadge: (db) => null,
        canAccess: (user) => _canAccessTab(0),
      ),
      NavItemDef(
        index: 1,
        title: 'POS',
        icon: Icons.point_of_sale_rounded,
        imageAsset: 'assets/images/Side bar icons/POS.png',
        iconColor: const Color(0xFF1D4ED8),
        iconBgColor: const Color(0xFFDCEBFE),
        getBadge: (db) => '${db.menuItems.length}',
        canAccess: (user) => _canAccessTab(1),
      ),
      NavItemDef(
        index: 2,
        title: 'Tables',
        icon: Icons.table_restaurant_rounded,
        imageAsset: 'assets/images/Side bar icons/tables.png',
        iconColor: const Color(0xFF10B981),
        iconBgColor: const Color(0xFFDCFCE7),
        getBadge: (db) => '${db.tables.where((t) => t.status != TableStatus.free).length}',
        canAccess: (user) => _canAccessTab(2),
      ),
      NavItemDef(
        index: 3,
        title: 'My Orders',
        icon: Icons.receipt_long_rounded,
        imageAsset: 'assets/images/Side bar icons/my orders.png',
        iconColor: const Color(0xFF7C3AED),
        iconBgColor: const Color(0xFFF3E8FF),
        getBadge: (db) => '${db.orders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.preparing).length}',
        canAccess: (user) => _canAccessTab(3),
      ),
      NavItemDef(
        index: 4,
        title: 'Menu & Categories',
        icon: Icons.dinner_dining_rounded,
        imageAsset: 'assets/images/Side bar icons/menu & categories.png',
        iconColor: const Color(0xFFEA580C),
        iconBgColor: const Color(0xFFFFEDD5),
        getBadge: (db) => null,
        canAccess: (user) => _canAccessTab(4),
      ),
      NavItemDef(
        index: 5,
        title: 'Inventory',
        icon: Icons.inventory_2_rounded,
        imageAsset: 'assets/images/Side bar icons/inventory.png',
        iconColor: const Color(0xFFEA580C),
        iconBgColor: const Color(0xFFFFEDD5),
        isPremium: true,
        getBadge: (db) => null,
        canAccess: (user) => _canAccessTab(5),
      ),
      NavItemDef(
        index: 6,
        title: 'Sales Report',
        icon: Icons.bar_chart_rounded,
        imageAsset: 'assets/images/Side bar icons/sale.png',
        iconColor: const Color(0xFF0284C7),
        iconBgColor: const Color(0xFFE0F2FE),
        getBadge: (db) => null,
        canAccess: (user) => _canAccessTab(6),
      ),
      NavItemDef(
        index: 7,
        title: 'CRM',
        icon: Icons.people_alt_rounded,
        imageAsset: 'assets/images/Side bar icons/crm.png',
        iconColor: const Color(0xFFDB2777),
        iconBgColor: const Color(0xFFFCE7F3),
        getBadge: (db) => null,
        canAccess: (user) => _canAccessTab(7),
      ),
      NavItemDef(
        index: 8,
        title: 'Loyalty',
        icon: Icons.card_giftcard_rounded,
        imageAsset: 'assets/images/Side bar icons/Loyalty.png',
        iconColor: const Color(0xFFD97706),
        iconBgColor: const Color(0xFFFEF08A),
        isPremium: true,
        getBadge: (db) => null,
        canAccess: (user) => _canAccessTab(8),
      ),
      NavItemDef(
        index: 9,
        title: 'Campaign',
        icon: Icons.campaign_rounded,
        imageAsset: 'assets/images/Side bar icons/campaign.png',
        iconColor: const Color(0xFFEA580C),
        iconBgColor: const Color(0xFFFFE4E6),
        isPremium: true,
        getBadge: (db) => null,
        canAccess: (user) => _canAccessTab(9),
      ),
      NavItemDef(
        index: 10,
        title: 'Staff Setting',
        icon: Icons.badge_rounded,
        imageAsset: 'assets/images/Side bar icons/staff.png',
        iconColor: const Color(0xFF2563EB),
        iconBgColor: const Color(0xFFEFF6FF),
        getBadge: (db) => '${db.staffList.length}',
        canAccess: (user) => _canAccessTab(10),
      ),
      NavItemDef(
        index: 11,
        title: 'Business Setting',
        icon: Icons.settings_rounded,
        imageAsset: 'assets/images/Side bar icons/setting.png',
        iconColor: const Color(0xFF475569),
        iconBgColor: const Color(0xFFF1F5F9),
        getBadge: (db) => null,
        canAccess: (user) => _canAccessTab(11),
      ),
      NavItemDef(
        index: 13,
        title: 'Delete Orders',
        icon: Icons.delete_forever_rounded,
        imageAsset: 'assets/images/Side bar icons/setting.png',
        iconColor: const Color(0xFFDC2626),
        iconBgColor: const Color(0xFFFEE2E2),
        getBadge: (db) => null,
        canAccess: (user) => _canAccessTab(13),
      ),
    ];

    final permittedItems = allItems.where((item) => _canAccessTab(item.index)).toList();
    if (permittedItems.isEmpty) {
      return [allItems[1]]; // POS fallback
    }
    return permittedItems;
  }

  void _initInitialAccessibleTab() {
    final user = db.currentUser;
    final visibleNavItems = _getAvailableNavItems();

    // If staff has a defaultScreen configured in StaffModel, try to land on it first
    if (user != null && !user.isOwner && !user.isAdmin) {
      final staffMatch = db.staffList.where((s) => s.id == user.id || (s.employeeId.isNotEmpty && s.employeeId == user.employeeId)).firstOrNull;
      final defaultScreen = staffMatch?.defaultScreen;
      if (defaultScreen != null && defaultScreen.isNotEmpty) {
        int? targetIdx;
        if (defaultScreen.contains('Dashboard')) {
          targetIdx = 0;
        } else if (defaultScreen.contains('POS')) {
          targetIdx = 1;
        } else if (defaultScreen.contains('Table')) {
          targetIdx = 2;
        } else if (defaultScreen.contains('Order') || defaultScreen.contains('Kitchen') || defaultScreen.contains('KDS')) {
          targetIdx = 3;
        } else if (defaultScreen.contains('Menu') || defaultScreen.contains('Product')) {
          targetIdx = 4;
        } else if (defaultScreen.contains('Inventory') || defaultScreen.contains('Stock')) {
          targetIdx = 5;
        } else if (defaultScreen.contains('Report')) {
          targetIdx = 6;
        } else if (defaultScreen.contains('Customer') || defaultScreen.contains('CRM')) {
          targetIdx = 7;
        } else if (defaultScreen.contains('Loyalty')) {
          targetIdx = 8;
        } else if (defaultScreen.contains('Campaign')) {
          targetIdx = 9;
        } else if (defaultScreen.contains('Staff') && !defaultScreen.contains('Profile')) {
          targetIdx = 10;
        } else if (defaultScreen.contains('Setting')) {
          targetIdx = 11;
        } else if (defaultScreen.contains('Profile')) {
          targetIdx = 12;
        } else if (defaultScreen.contains('Delete') || defaultScreen.contains('Purge') || defaultScreen.contains('SuperAdmin')) {
          targetIdx = 13;
        }

        if (targetIdx != null && _canAccessTab(targetIdx)) {
          _selectedIndex = targetIdx;
          return;
        }
      }
    }

    // Default to POS if permitted
    if (_canAccessTab(1)) {
      _selectedIndex = 1;
      return;
    }

    // Otherwise select the first accessible tab
    if (visibleNavItems.isNotEmpty) {
      _selectedIndex = visibleNavItems.first.index;
    } else {
      for (int i = 0; i <= 12; i++) {
        if (_canAccessTab(i)) {
          _selectedIndex = i;
          break;
        }
      }
    }
  }

  String? _lastUserId;
  String? _lastUserRole;
  String? _lastUserPhoto;
  String? _lastCompanyLogo;
  String? _lastCompanyName;
  int _lastStaffCount = -1;
  List<String>? _lastPermissions;

  void _onDbUserChanged() {
    if (!mounted) return;
    final currentUser = db.currentUser;
    final companyLogo = db.companyLogoPath;
    final companyName = db.restaurant?.name ?? db.currentUser?.companyName;
    final staffCount = db.staffList.length;

    final bool userChanged = _lastUserId != currentUser?.id ||
        _lastUserRole != currentUser?.role ||
        _lastUserPhoto != currentUser?.profilePhotoPath ||
        _lastCompanyLogo != companyLogo ||
        _lastCompanyName != companyName ||
        _lastStaffCount != staffCount ||
        !_stringListEquals(_lastPermissions, currentUser?.permissions);

    final bool accessChanged = !_canAccessTab(_selectedIndex);

    if (userChanged || accessChanged) {
      _lastUserId = currentUser?.id;
      _lastUserRole = currentUser?.role;
      _lastUserPhoto = currentUser?.profilePhotoPath;
      _lastCompanyLogo = companyLogo;
      _lastCompanyName = companyName;
      _lastStaffCount = staffCount;
      _lastPermissions = currentUser?.permissions != null ? List<String>.from(currentUser!.permissions) : null;

      setState(() {
        if (accessChanged) {
          _initInitialAccessibleTab();
        }
      });
    }
  }

  bool _stringListEquals(List<String>? a, List<String>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _selectTab(int index) {
    if (!_canAccessTab(index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: You do not have permission to access this section.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_selectedIndex != index) {
      setState(() {
        _tabHistory.add(_selectedIndex);
        _selectedIndex = index;
        if (index != 1) {
          _isPosFullScreen = false;
        }
      });
      if (index == 0) {
        _dashboardKey.currentState?.refreshDashboard();
      }
    } else if (index == 0) {
      _dashboardKey.currentState?.refreshDashboard();
    }
  }

  void _navigateToRootTab() {
    final available = _getAvailableNavItems();
    final rootIndex = available.any((i) => i.index == 1)
        ? 1
        : (available.any((i) => i.index == 0)
            ? 0
            : (available.isNotEmpty ? available.first.index : 1));
    _selectTab(rootIndex);
  }

  // Animation controllers
  late final AnimationController _sidebarController;
  late final Animation<double> _sidebarAnimation;
  late final Animation<Offset> _sidebarSlideAnimation;

  @override
  void initState() {
    super.initState();
    db.addListener(_onDbUserChanged);
    _lastUserId = db.currentUser?.id;
    _lastUserRole = db.currentUser?.role;
    _lastUserPhoto = db.currentUser?.profilePhotoPath;
    _lastCompanyLogo = db.companyLogoPath;
    _lastCompanyName = db.restaurant?.name ?? db.currentUser?.companyName;
    _lastStaffCount = db.staffList.length;
    _lastPermissions = db.currentUser?.permissions != null ? List<String>.from(db.currentUser!.permissions) : null;
    _initInitialAccessibleTab();

    // Smooth sidebar frame transition with direct touch tracking & smooth curves
    _sidebarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
    );

    _sidebarAnimation = CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.fastEaseInToSlowEaseOut,
      reverseCurve: Curves.easeInCubic,
    );

    _sidebarSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(_sidebarController);

    // Initial fetch of unread notifications count
    NotificationService().fetchUnreadCount();
  }

  @override
  void dispose() {
    db.removeListener(_onDbUserChanged);
    _sidebarController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    if (_isSidebarOpen) {
      _closeSidebar();
    } else {
      _openSidebar();
    }
  }

  void _openSidebar() {
    setState(() {
      _isSidebarOpen = true;
      _isPosFullScreen = false;
    });
    _sidebarController.animateTo(1.0, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  void _closeSidebar() {
    setState(() => _isSidebarOpen = false);
    _sidebarController.animateTo(0.0, duration: const Duration(milliseconds: 220), curve: Curves.easeInCubic);
  }

  Widget _buildCompanyProfileLogo(double size) {
    final rest = db.restaurant;
    final user = db.currentUser;
    final companyTitle = rest?.name ?? user?.companyName ?? 'Tea Coffee';
    return SmoothBrandLogoWidget(
      size: size,
      logoPath: db.companyLogoPath,
      companyName: companyTitle,
    );
  }

  Widget _buildProfileAvatarImage(double size) {
    final rest = db.restaurant;
    final user = db.currentUser;
    final userName = (user?.name.isNotEmpty == true)
        ? user!.name
        : (rest?.name.isNotEmpty == true ? rest!.name : 'chandan kumar');
    return SmoothProfileAvatarWidget(
      size: size,
      photoPath: user?.profilePhotoPath,
      userName: userName,
      isOwner: user?.isOwner == true || user?.role.toLowerCase() == 'owner',
      companyLogoPath: db.companyLogoPath,
    );
  }

  Widget _buildSidebarContent(bool isSmallScreen, {double expansionFactor = 1.0, bool isCollapsed = false}) {
    final rest = db.restaurant;
    final user = db.currentUser;
    final double textOpacity = isSmallScreen ? 1.0 : ((expansionFactor - 0.25) / 0.75).clamp(0.0, 1.0);
    final visibleNavItems = _getAvailableNavItems();

    String roleDisplay = 'Owner';
    if (user?.role.isNotEmpty == true) {
      if (user!.isOwner) {
        roleDisplay = 'Owner';
      } else if (user.isAdmin) {
        roleDisplay = 'Admin';
      } else {
        final r = user.role;
        roleDisplay = '${r[0].toUpperCase()}${r.substring(1)}${user.employeeId != null && user.employeeId!.isNotEmpty ? ' • ${user.employeeId}' : ''}';
      }
    }

    final userName = (user?.name.isNotEmpty == true)
        ? user!.name
        : (rest?.name.isNotEmpty == true ? rest!.name : 'chandan kumar');

    return Container(
      margin: isSmallScreen
          ? const EdgeInsets.fromLTRB(8, 8, 0, 8)
          : const EdgeInsets.fromLTRB(8, 8, 0, 8),
      padding: EdgeInsets.only(
        top: isSmallScreen ? 10 : 10,
        left: isSmallScreen ? 8 : (4.0 + 4.0 * expansionFactor),
        right: isSmallScreen ? 8 : (4.0 + 4.0 * expansionFactor),
        bottom: isSmallScreen ? 10 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isSmallScreen
            ? BorderRadius.circular(24)
            : BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: isSmallScreen ? Colors.black.withOpacity(0.18) : const Color(0x0A000000),
            blurRadius: isSmallScreen ? 24 : 16,
            offset: isSmallScreen ? const Offset(4, 4) : const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Dynamic Navigation Items strictly filtered by staff permissions
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: visibleNavItems.map((item) {
                  return _buildNavItem(
                    key: ValueKey('nav_item_${item.index}'),
                    index: item.index,
                    title: item.title,
                    icon: item.icon,
                    imageAsset: item.imageAsset,
                    iconColor: item.iconColor,
                    iconBgColor: item.iconBgColor,
                    badge: item.getBadge(db),
                    isPremium: item.isPremium,
                    isSmallScreen: isSmallScreen,
                    isCollapsed: isCollapsed,
                    expansionFactor: expansionFactor,
                  );
                }).toList(),
              ),
            ),
          ),

          const Divider(color: Color(0xFFE2E8F0), height: 16, thickness: 1),
          const SizedBox(height: 4),

          // User Profile & Logout Bottom Row with Smooth Fade & Slide Transition
          if (!isSmallScreen && isCollapsed && expansionFactor < 0.25)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Tooltip(
                    message: '$userName ($roleDisplay) - View Profile',
                    child: InkWell(
                      onTap: () => _selectTab(12),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                        ),
                        child: ClipOval(
                          child: _buildProfileAvatarImage(38),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Tooltip(
                    message: 'Logout',
                    child: InkWell(
                      onTap: () async {
                        await AuthService().logout();
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFCDD2), width: 1),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFEF4444),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        _selectTab(12);
                        if (isSmallScreen) _closeSidebar();
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          children: [
                            Container(
                              width: isSmallScreen ? 42 : (38.0 + 6.0 * expansionFactor),
                              height: isSmallScreen ? 42 : (38.0 + 6.0 * expansionFactor),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1.5),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _buildProfileAvatarImage(isSmallScreen ? 42 : 44),
                              ),
                            ),
                            if (isSmallScreen || textOpacity > 0.0) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: Opacity(
                                  opacity: textOpacity,
                                  child: Transform.translate(
                                    offset: Offset(-8 * (1.0 - textOpacity), 0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          userName,
                                          style: TextStyle(
                                            color: const Color(0xFF0F172A),
                                            fontSize: isSmallScreen ? 14 : 14.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.1,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          roleDisplay,
                                          style: TextStyle(
                                            color: const Color(0xFF64748B),
                                            fontSize: isSmallScreen ? 12 : 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Opacity(
                    opacity: textOpacity,
                    child: Transform.translate(
                      offset: Offset(-8 * (1.0 - textOpacity), 0),
                      child: Tooltip(
                        message: 'Logout',
                        child: InkWell(
                          onTap: () async {
                            await AuthService().logout();
                            if (mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: isSmallScreen ? 40 : 40,
                            height: isSmallScreen ? 40 : 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFCDD2),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.logout_rounded,
                              color: const Color(0xFFEF4444),
                              size: isSmallScreen ? 19 : 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openStaffProfileDropdown() async {
    final staffList = db.staffList;
    if (staffList.isEmpty) return;

    final currentUser = db.currentUser;
    final rest = db.restaurant;
    final ownerUser = db.cachedOwnerUser ??
        (currentUser != null && (currentUser.isOwner || currentUser.role.toLowerCase() == 'owner') ? currentUser : null);

    String ownerDisplayName = ownerUser?.name ?? '';
    if (ownerDisplayName.isEmpty || ownerDisplayName.toLowerCase().contains('demo')) {
      if (currentUser != null && currentUser.name.isNotEmpty && !currentUser.name.toLowerCase().contains('demo')) {
        ownerDisplayName = currentUser.name;
      } else if (rest?.name.isNotEmpty == true && !rest!.name.toLowerCase().contains('demo')) {
        ownerDisplayName = rest.name;
      } else {
        ownerDisplayName = 'Chandan Kumar';
      }
    }

    final bool isCurrentOwner = currentUser == null || currentUser.isOwner || currentUser.role.toLowerCase() == 'owner';

    setState(() => _isStaffDropdownOpen = true);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Switch Profile',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curve),
          child: FadeTransition(
            opacity: anim1,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      offset: const Offset(0, 12),
                      blurRadius: 28,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      offset: const Offset(0, 4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header (Group Icon + Title + Subtitle + Close Button)
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDBEAFE), width: 1.0),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.groups_rounded,
                            color: Color(0xFF2563EB),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Switch Profile / Staff',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${staffList.length} staff member${staffList.length > 1 ? 's' : ''} available',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Scrollable Profiles List (Wrapped & Responsive)
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section 1: Business Owner
                            const Padding(
                              padding: EdgeInsets.only(left: 2, bottom: 6),
                              child: Text(
                                'BUSINESS OWNER',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            _buildProfileSelectCard(
                              name: ownerDisplayName,
                              subtitle: 'Full Access • All Permissions',
                              role: 'Owner',
                              roleBgColor: const Color(0xFFDBEAFE),
                              roleTextColor: const Color(0xFF2563EB),
                              avatarUrl: ownerUser?.profilePhotoPath ?? db.companyLogoPath,
                              fallbackInitials: 'OW',
                              isOwner: true,
                              isActive: isCurrentOwner,
                              onTap: () async {
                                Navigator.of(ctx).pop();
                                if (!isCurrentOwner) {
                                  await db.switchToOwner();
                                  _onProfileSwitched(ownerDisplayName, 'Owner');
                                }
                              },
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),
                            ),

                            // Section 2: Staff Profiles
                            Padding(
                              padding: const EdgeInsets.only(left: 2, bottom: 6),
                              child: Text(
                                'STAFF PROFILES (${staffList.length})',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),

                            ...staffList.map((staff) {
                              final bool isThisStaffActive = !isCurrentOwner &&
                                  (currentUser.id == staff.id ||
                                      (currentUser.employeeId != null && currentUser.employeeId == staff.employeeId));

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildProfileSelectCard(
                                  name: staff.name,
                                  subtitle: staff.employeeId.isNotEmpty ? 'ID: ${staff.employeeId}' : 'Staff Member',
                                  role: staff.role,
                                  roleBgColor: staff.roleBgColor,
                                  roleTextColor: staff.roleTextColor,
                                  avatarUrl: staff.avatarUrl,
                                  fallbackInitials: staff.initials,
                                  isOwner: false,
                                  isActive: isThisStaffActive,
                                  onTap: () async {
                                    Navigator.of(ctx).pop();
                                    if (!isThisStaffActive) {
                                      await db.switchToStaff(staff);
                                      _onProfileSwitched(staff.name, staff.role, defaultScreen: staff.defaultScreen);
                                    }
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (mounted) {
      setState(() => _isStaffDropdownOpen = false);
    }
  }

  void _onProfileSwitched(String name, String role, {String? defaultScreen}) {
    SoundService.playButtonClick();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Switched to $name ($role)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      // Navigate to defaultScreen if set
      if (defaultScreen != null && defaultScreen.isNotEmpty) {
        int? targetIdx;
        if (defaultScreen.contains('Dashboard')) {
          targetIdx = 0;
        } else if (defaultScreen.contains('POS')) {
          targetIdx = 1;
        } else if (defaultScreen.contains('Table')) {
          targetIdx = 2;
        } else if (defaultScreen.contains('Order') || defaultScreen.contains('Kitchen')) {
          targetIdx = 3;
        } else if (defaultScreen.contains('Menu')) {
          targetIdx = 4;
        } else if (defaultScreen.contains('Inventory')) {
          targetIdx = 5;
        } else if (defaultScreen.contains('Report')) {
          targetIdx = 6;
        } else if (defaultScreen.contains('CRM')) {
          targetIdx = 7;
        } else if (defaultScreen.contains('Loyalty')) {
          targetIdx = 8;
        } else if (defaultScreen.contains('Campaign')) {
          targetIdx = 9;
        } else if (defaultScreen.contains('Staff')) {
          targetIdx = 10;
        } else if (defaultScreen.contains('Setting')) {
          targetIdx = 11;
        } else if (defaultScreen.contains('Profile')) {
          targetIdx = 12;
        } else if (defaultScreen.contains('Delete') || defaultScreen.contains('Purge') || defaultScreen.contains('SuperAdmin')) {
          targetIdx = 13;
        }

        if (targetIdx != null && _canAccessTab(targetIdx)) {
          _selectTab(targetIdx);
          return;
        }
      }

      _initInitialAccessibleTab();
    }
  }

  Widget _buildProfileSelectCard({
    required String name,
    required String subtitle,
    required String role,
    required Color roleBgColor,
    required Color roleTextColor,
    required String? avatarUrl,
    required String fallbackInitials,
    required bool isOwner,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: const Color(0x142563EB),
        highlightColor: const Color(0x0A2563EB),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              width: isActive ? 1.5 : 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Avatar with subtle circular border (42x42 for comfortable text fit)
              _buildPopupAvatar(avatarUrl, fallbackInitials, roleBgColor, roleTextColor, isOwner, size: 42),
              const SizedBox(width: 9),

              // Name, Role Badge, Subtitle (Generous horizontal space)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: roleBgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            role,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: roleTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Active Green Pill Badge or Neumorphic Switch Button
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF86EFAC), width: 1.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1816A34A),
                        blurRadius: 4,
                        offset: Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF16A34A),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x6616A34A),
                              blurRadius: 3,
                              spreadRadius: 0.8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4.5),
                      const Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF15803D),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.white,
                        offset: Offset(-1, -1),
                        blurRadius: 2.5,
                      ),
                      BoxShadow(
                        color: Color(0x100F172A),
                        offset: Offset(1, 1.5),
                        blurRadius: 2.5,
                      ),
                    ],
                  ),
                  child: const Text(
                    'Switch',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupAvatar(
    String? avatarUrl,
    String fallbackInitials,
    Color roleBgColor,
    Color roleTextColor,
    bool isOwner, {
    double size = 42,
  }) {
    final db = DatabaseService();
    String photo = avatarUrl?.trim() ?? '';
    if (photo.isEmpty && isOwner) {
      photo = db.companyLogoPath ?? db.restaurant?.logoUrl ?? '';
    }

    Widget content;
    if (photo.isNotEmpty) {
      if (photo.startsWith('data:image') || photo.startsWith('data:') || (photo.length > 80 && !photo.contains('/') && !photo.contains('\\'))) {
        try {
          final commaIdx = photo.indexOf(',');
          final cleanBase64 = commaIdx != -1 ? photo.substring(commaIdx + 1) : photo;
          final bytes = base64Decode(cleanBase64.replaceAll('\n', '').replaceAll('\r', '').trim());
          content = Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(fallbackInitials, roleBgColor, roleTextColor, size: size),
          );
        } catch (_) {
          content = _buildAvatarFallback(fallbackInitials, roleBgColor, roleTextColor, size: size);
        }
      } else if (photo.startsWith('http://') || photo.startsWith('https://')) {
        content = Image.network(
          photo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(fallbackInitials, roleBgColor, roleTextColor, size: size),
        );
      } else if (photo.startsWith('assets/')) {
        content = Image.asset(
          photo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(fallbackInitials, roleBgColor, roleTextColor, size: size),
        );
      } else if (!photo.contains('_selected') && File(photo).existsSync()) {
        content = Image.file(
          File(photo),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(fallbackInitials, roleBgColor, roleTextColor, size: size),
        );
      } else if (isOwner) {
        content = _buildCompanyProfileLogo(size);
      } else {
        content = _buildAvatarFallback(fallbackInitials, roleBgColor, roleTextColor, size: size);
      }
    } else if (isOwner) {
      content = _buildCompanyProfileLogo(size);
    } else {
      content = _buildAvatarFallback(fallbackInitials, roleBgColor, roleTextColor, size: size);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.3),
        boxShadow: const [
          BoxShadow(color: Color(0x12000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: ClipOval(child: content),
    );
  }

  Widget _buildAvatarFallback(
    String initials,
    Color bgColor,
    Color textColor, {
    double size = 42,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }

  void _openNotificationScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }

  Widget _buildNotificationBellButton({bool isNeumorphic = false}) {
    return AnimatedBuilder(
      animation: NotificationService(),
      builder: (context, _) {
        final unreadCount = NotificationService().unreadCount;
        final hasNotification = unreadCount > 0 || NotificationService().notifications.any((n) => !n.isRead);

        return Tooltip(
          message: hasNotification
              ? 'Notifications ($unreadCount unread)'
              : 'Notifications',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openNotificationScreen,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: isNeumorphic
                    ? BoxDecoration(
                        color: const Color(0xFFF7FAFD),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F2B48).withValues(alpha: 0.08),
                            offset: const Offset(1.5, 2.5),
                            blurRadius: 5,
                          ),
                        ],
                      )
                    : BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.1,
                        ),
                      ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: isNeumorphic ? const Color(0xFF0F2B48) : Colors.white,
                      size: 19,
                    ),
                    if (hasNotification)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 8.5,
                          height: 8.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isNeumorphic ? const Color(0xFFF7FAFD) : const Color(0xFF051C48),
                              width: 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66EF4444),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rest = db.restaurant;
    final user = db.currentUser;
    final companyTitle = rest?.name ?? user?.companyName ?? 'Tea Coffee';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // 1. If sidebar is open, close it first
        if (_isSidebarOpen) {
          _closeSidebar();
          return;
        }

        // 2. If user navigated to other tabs, navigate back through tab history
        while (_tabHistory.isNotEmpty) {
          final prevIndex = _tabHistory.removeLast();
          if (_canAccessTab(prevIndex) && prevIndex != _selectedIndex) {
            setState(() {
              _selectedIndex = prevIndex;
            });
            return;
          }
        }

        // 3. If currently on a non-root tab, return to root accessible tab (POS if permitted, else first available)
        final available = _getAvailableNavItems();
        final rootIndex = available.any((i) => i.index == 1) ? 1 : (available.isNotEmpty ? available.first.index : 1);
        if (_selectedIndex != rootIndex) {
          setState(() {
            _selectedIndex = rootIndex;
          });
          return;
        }

        // 4. User is on root accessible screen -> Close/exit the app cleanly
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF031024),
        resizeToAvoidBottomInset: false,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF031024), // Deep Midnight Navy
                Color(0xFF072146), // Rich Royal Navy
                Color(0xFF0A2E5C), // Deep Indigo Blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 900;

              return Column(
                children: [
                  // TOP HEADER BAR (Always on dark navy background like reference UI)
                    AnimatedCrossFade(
                      firstChild: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: Colors.transparent,
                        child: Row(
                          children: [
                            // LOGO AND HIGHLIGHTED SEMI-CURVED COMPANY NAME TOGETHER ON LEFT
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Circular Brand Logo (Toggles Sidebar)
                                InkWell(
                                  onTap: _toggleSidebar,
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
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
                                      child: _buildCompanyProfileLogo(38),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // HIGHLIGHTED COMPANY NAME WITH DROPDOWN IF STAFF MEMBERS EXIST
                                GlassCompanyNameBadge(
                                  name: companyTitle,
                                  hasDropdown: db.staffList.isNotEmpty,
                                  isDropdownOpen: _isStaffDropdownOpen,
                                  isNeumorphic: false,
                                  onTap: () {
                                    if (db.staffList.isNotEmpty) {
                                      _openStaffProfileDropdown();
                                    } else {
                                      _toggleSidebar();
                                    }
                                  },
                                ),
                              ],
                            ),
                            const Spacer(),
                            // ONLINE / OFFLINE STATUS DOT INDICATOR
                            const GlassConnectionStatusBadge(isDarkTheme: true),
                            const SizedBox(width: 8),
                            // NOTIFICATION BELL BUTTON
                            _buildNotificationBellButton(isNeumorphic: false),
                          ],
                        ),
                      ),
                      secondChild: const SizedBox.shrink(),
                      crossFadeState: ((_selectedIndex == 1 && _isPosFullScreen) || _selectedIndex == 8)
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 250),
                      sizeCurve: Curves.easeInOutCubic,
                    ),

                    // ACTIVE SCREEN WORKSPACE & MOBILE SIDEBAR OVERLAY (STACKED BELOW HEADER)
                    Expanded(
                      child: Stack(
                        children: [
                          // ACTIVE SCREEN WORKSPACE (CURVED CONTAINER WRAPPING THE SCREEN UNDER HEADER)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOutCubic,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEDF3FA),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(32),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x33000000),
                                  blurRadius: 16,
                                  offset: Offset(0, -4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(32),
                              ),
                              child: Row(
                                children: [
                                  // DESKTOP ANIMATED SLIDING & SCALING SIDEBAR (Collapsed Icon Rail by default, Extended on Hamburger Click)
                                  if (!isSmallScreen)
                                    AnimatedBuilder(
                                      animation: _sidebarAnimation,
                                      builder: (context, child) {
                                        if (_selectedIndex == 1 && _isPosFullScreen) {
                                          return const SizedBox.shrink();
                                        }
                                        final double currentWidth = 74.0 + (260.0 - 74.0) * _sidebarAnimation.value;
                                        final bool isCollapsed = _sidebarAnimation.value < 0.5;

                                        return SizedBox(
                                          width: currentWidth,
                                          height: double.infinity,
                                          child: ClipRect(
                                            child: _buildSidebarContent(
                                              false,
                                              isCollapsed: isCollapsed,
                                              expansionFactor: _sidebarAnimation.value,
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                   Expanded(
                                    child: SmoothAnimatedIndexedStack(
                                      index: _selectedIndex.clamp(0, 13),
                                      tabBuilders: [
                                        (ctx) => _canAccessTab(0)
                                            ? GlassDashboardScreen(
                                                key: _dashboardKey,
                                                isActive: _selectedIndex == 0,
                                                onNavigateTab: (index) => _selectTab(index),
                                              )
                                            : _buildAccessDeniedScreen('Dashboard'),
                                        (ctx) => _canAccessTab(1)
                                            ? PosRegisterScreen(
                                                initialTable: _selectedTableForPos,
                                                initialOrderType: _selectedOrderTypeForPos,
                                                onOpenDrawer: _toggleSidebar,
                                                onOpenTablesTab: () => _selectTab(2),
                                                isFullScreen: _isPosFullScreen,
                                                onToggleFullScreen: () {
                                                  setState(() {
                                                    _isPosFullScreen = !_isPosFullScreen;
                                                  });
                                                },
                                                onFullScreenChanged: (full) {
                                                  setState(() {
                                                    _isPosFullScreen = full;
                                                  });
                                                },
                                              )
                                            : _buildAccessDeniedScreen('POS'),
                                        (ctx) => _canAccessTab(2)
                                            ? TableManagementScreen(
                                                onTakeOrder: (tableName) {
                                                  setState(() {
                                                    _selectedTableForPos = tableName;
                                                    _selectedOrderTypeForPos = OrderType.dineIn;
                                                  });
                                                  _selectTab(1);
                                                },
                                                onTakeOrderForType: (orderType) {
                                                  setState(() {
                                                    _selectedTableForPos = null;
                                                    _selectedOrderTypeForPos = orderType;
                                                  });
                                                  _selectTab(1);
                                                },
                                              )
                                            : _buildAccessDeniedScreen('Tables'),
                                        (ctx) => _canAccessTab(3)
                                            ? OrdersScreen(
                                                onOpenPosForTable: (tableName) {
                                                  setState(() {
                                                    _selectedTableForPos = tableName;
                                                    _selectedOrderTypeForPos = OrderType.dineIn;
                                                  });
                                                  _selectTab(1);
                                                },
                                              )
                                            : _buildAccessDeniedScreen('My Orders'),
                                        (ctx) => _canAccessTab(4)
                                            ? const MenuManagementScreen()
                                            : _buildAccessDeniedScreen('Menu & Categories'),
                                        (ctx) => _canAccessTab(5)
                                            ? InventoryScreen(onBack: _navigateToRootTab)
                                            : _buildAccessDeniedScreen('Inventory'),
                                        (ctx) => _canAccessTab(6)
                                            ? const ReportsScreen()
                                            : _buildAccessDeniedScreen('Sales Report'),
                                        (ctx) => _canAccessTab(7)
                                            ? CrmLeadsScreen(
                                                onOpenDrawer: _toggleSidebar,
                                                onNavigateToDashboard: _navigateToRootTab,
                                              )
                                            : _buildAccessDeniedScreen('CRM'),
                                        (ctx) => _canAccessTab(8)
                                            ? LoyaltyLandingScreen(onBack: _navigateToRootTab)
                                            : _buildAccessDeniedScreen('Loyalty'),
                                        (ctx) => _canAccessTab(9)
                                            ? CampaignScreen(onBack: _navigateToRootTab)
                                            : _buildAccessDeniedScreen('Campaign'),
                                        (ctx) => _canAccessTab(10)
                                            ? StaffManagementScreen(
                                                onOpenDrawer: _toggleSidebar,
                                                onNavigateToDashboard: _navigateToRootTab,
                                              )
                                            : _buildAccessDeniedScreen('Staff Setting'),
                                        (ctx) => _canAccessTab(11)
                                            ? const BusinessSettingsHubScreen()
                                            : _buildAccessDeniedScreen('Business Setting'),
                                        (ctx) => _canAccessTab(12)
                                            ? StaffProfileScreen(
                                                onOpenDrawer: _toggleSidebar,
                                                onNavigateToDashboard: _navigateToRootTab,
                                              )
                                            : _buildAccessDeniedScreen('Staff Profile'),
                                        (ctx) => _canAccessTab(13)
                                            ? SuperAdminOrderDeletionScreen(
                                                onOpenDrawer: _toggleSidebar,
                                                onNavigateToDashboard: _navigateToRootTab,
                                              )
                                            : _buildAccessDeniedScreen('Delete Orders'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // MOBILE / SMALL SCREEN SIDEBAR OVERLAY (TOUCHING HEADER DOWNSIDE & LEFT SCREEN EDGE)
                          if (isSmallScreen)
                            AnimatedBuilder(
                              animation: _sidebarController,
                              builder: (context, child) {
                                if (_sidebarController.value <= 0.001 && !_isSidebarOpen) {
                                  return const SizedBox.shrink();
                                }
                                final double mobileDrawerWidth = (constraints.maxWidth * 0.74).clamp(265.0, 295.0);

                                return Stack(
                                  children: [
                                    // Smooth Backdrop Fade Overlay (Synchronized with finger drag)
                                    Positioned.fill(
                                      child: GestureDetector(
                                        onTap: _closeSidebar,
                                        behavior: HitTestBehavior.opaque,
                                        onHorizontalDragUpdate: (details) {
                                          if (details.primaryDelta != null) {
                                            _sidebarController.value = (_sidebarController.value + details.primaryDelta! / mobileDrawerWidth).clamp(0.0, 1.0);
                                          }
                                        },
                                        onHorizontalDragEnd: (details) {
                                          final velocity = details.primaryVelocity ?? 0.0;
                                          if (velocity < -250 || _sidebarController.value < 0.5) {
                                            _closeSidebar();
                                          } else {
                                            _openSidebar();
                                          }
                                        },
                                        child: Container(
                                          color: Colors.black.withOpacity(0.50 * _sidebarController.value),
                                        ),
                                      ),
                                    ),
                                    // Smooth Sliding Sidebar (1:1 Finger tracking on hold and slide)
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      bottom: 0,
                                      width: mobileDrawerWidth,
                                      child: SlideTransition(
                                        position: _sidebarSlideAnimation,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onHorizontalDragUpdate: (details) {
                                            if (details.primaryDelta != null) {
                                              _sidebarController.value = (_sidebarController.value + details.primaryDelta! / mobileDrawerWidth).clamp(0.0, 1.0);
                                            }
                                          },
                                          onHorizontalDragEnd: (details) {
                                            final velocity = details.primaryVelocity ?? 0.0;
                                            if (velocity < -250) {
                                              _closeSidebar();
                                            } else if (velocity > 250) {
                                              _openSidebar();
                                            } else if (_sidebarController.value < 0.5) {
                                              _closeSidebar();
                                            } else {
                                              _openSidebar();
                                            }
                                          },
                                          child: _buildSidebarContent(true),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccessDeniedScreen(String title) {
    return Container(
      color: const Color(0xFFF8FAFC),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock_rounded,
                    color: Color(0xFFDC2626),
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$title Access Restricted',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Your current staff profile does not have permission to access the $title module. Please ask your store owner or manager to update your role permissions.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _navigateToRootTab,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Back to Available Screen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    Key? key,
    required int index,
    required String title,
    IconData? icon,
    String? imageAsset,
    required Color iconColor,
    required Color iconBgColor,
    String? badge,
    bool isPremium = false,
    bool isSmallScreen = false,
    bool isCollapsed = false,
    double expansionFactor = 1.0,
  }) {
    final isSelected = _selectedIndex == index;
    final isPermitted = _canAccessTab(index);
    final double textOpacity = isSmallScreen ? 1.0 : ((expansionFactor - 0.25) / 0.75).clamp(0.0, 1.0);
    final double badgeCornerOpacity = isSmallScreen ? 0.0 : (1.0 - (expansionFactor / 0.35)).clamp(0.0, 1.0);

    void onTapAction() {
      if (!isPermitted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access Restricted: You do not have permission for $title.'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      if (isPremium) {
        if (isSmallScreen) _closeSidebar();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SubscriptionScreen(
              sourceFeature: title.toLowerCase(),
              onNavigateToFeature: (target) {
                if (target.contains('inventory')) {
                  _selectTab(5);
                } else if (target.contains('loyalty')) {
                  _selectTab(8);
                } else if (target.contains('campaign')) {
                  _selectTab(9);
                }
              },
            ),
          ),
        );
      } else {
        _selectTab(index);
        if (isSmallScreen) {
          _closeSidebar();
        }
      }
    }

    final bool isCollapsedRail = !isSmallScreen && expansionFactor < 0.35;
    final bool showTileHighlight = isSelected && !isCollapsedRail;

    return Padding(
      key: key,
      padding: EdgeInsets.only(bottom: isSmallScreen ? 3.5 : 4),
      child: Tooltip(
        message: isCollapsedRail
            ? (isPermitted ? title : '$title (Restricted)')
            : '',
        waitDuration: const Duration(milliseconds: 300),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTapAction,
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: isCollapsedRail ? Alignment.center : Alignment.centerLeft,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen
                        ? (isSelected ? 10 : 8)
                        : (isCollapsedRail ? 0 : (isSelected ? 8 : 6)),
                    vertical: isSmallScreen ? 6 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: showTileHighlight
                        ? const Color(0xFFEBF3FE)
                        : (isPremium ? const Color(0xFFFFFBEB) : Colors.transparent),
                    borderRadius: BorderRadius.circular(16),
                    border: showTileHighlight
                        ? Border.all(color: const Color(0xFFBFDBFE), width: 1.2)
                        : (isPremium ? Border.all(color: const Color(0xFFFDE68A), width: 1.0) : null),
                    boxShadow: showTileHighlight
                        ? [
                            BoxShadow(
                              color: const Color(0xFF1D4ED8).withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: isCollapsedRail ? MainAxisAlignment.center : MainAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          AnimatedScale(
                            scale: isSelected ? (isCollapsedRail ? 1.12 : 1.04) : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isPermitted
                                    ? (isSelected
                                        ? const Color(0xFFEFF6FF)
                                        : (isPremium ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC)))
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                                border: isSelected
                                    ? Border.all(
                                        color: const Color(0xFF3B82F6).withOpacity(0.4),
                                        width: 1.2,
                                      )
                                    : (isPremium
                                        ? Border.all(color: const Color(0xFFFDE68A), width: 1.0)
                                        : Border.all(color: const Color(0xFFE2E8F0), width: 1.0)),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF1D4ED8).withOpacity(0.14),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1.5),
                                        ),
                                      ],
                              ),
                              alignment: Alignment.center,
                              child: imageAsset != null && imageAsset.isNotEmpty
                                  ? Opacity(
                                      opacity: isPermitted ? 1.0 : 0.45,
                                      child: Image.asset(
                                        imageAsset,
                                        width: 26,
                                        height: 26,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) => Icon(
                                          icon ?? Icons.circle_outlined,
                                          color: isPermitted ? iconColor : const Color(0xFF94A3B8),
                                          size: 24,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      icon ?? Icons.circle_outlined,
                                      color: isPermitted ? iconColor : const Color(0xFF94A3B8),
                                      size: 24,
                                    ),
                            ),
                          ),
                          // Corner badge when collapsed (smoothly fades out as sidebar expands)
                          if (!isSmallScreen && badgeCornerOpacity > 0.0)
                            Positioned.fill(
                              child: Opacity(
                                opacity: badgeCornerOpacity,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    if (!isPermitted)
                                      const Positioned(
                                        top: -3,
                                        right: -3,
                                        child: Icon(
                                          Icons.lock_rounded,
                                          size: 11,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      )
                                    else if (isPremium)
                                      const Positioned(
                                        top: -4,
                                        right: -4,
                                        child: Text('👑', style: TextStyle(fontSize: 11)),
                                      )
                                    else if (badge != null && badge != '0')
                                      Positioned(
                                        top: -2,
                                        right: -3,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1D61E7),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                                          alignment: Alignment.center,
                                          child: Text(
                                            badge,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (isSmallScreen || textOpacity > 0.0) ...[
                        SizedBox(width: isSmallScreen ? 12 : (12.0 * textOpacity)),
                        Expanded(
                          child: Opacity(
                            opacity: textOpacity,
                            child: Transform.translate(
                              offset: Offset(-8 * (1.0 - textOpacity), 0),
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF1D61E7)
                                      : (!isPermitted
                                          ? const Color(0xFF94A3B8)
                                          : (isPremium ? const Color(0xFF92400E) : const Color(0xFF0F172A))),
                                  fontWeight: isSelected
                                      ? FontWeight.w900
                                      : (isPremium ? FontWeight.w800 : FontWeight.w800),
                                  fontSize: isSmallScreen ? 14.5 : 14.5,
                                  letterSpacing: 0.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        if (textOpacity > 0.0)
                          Opacity(
                            opacity: textOpacity,
                            child: Transform.translate(
                              offset: Offset(-6 * (1.0 - textOpacity), 0),
                              child: !isPermitted
                                  ? const Icon(
                                      Icons.lock_outline_rounded,
                                      size: 16,
                                      color: Color(0xFF94A3B8),
                                    )
                                  : isPremium
                                      ? Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFFFDE68A),
                                              width: 1.0,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Text(
                                            '👑',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        )
                                      : (badge != null && badge != '0')
                                          ? Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isSmallScreen ? 9 : 9,
                                                vertical: isSmallScreen ? 3 : 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? const Color(0xFF1D61E7)
                                                    : const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? const Color(0xFF1D61E7)
                                                      : const Color(0xFFDBEAFE),
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Text(
                                                badge,
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : const Color(0xFF1D61E7),
                                                  fontSize: isSmallScreen ? 11.5 : 11.5,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                if (showTileHighlight)
                  Positioned(
                    left: 0,
                    top: 10,
                    bottom: 10,
                    child: Container(
                      width: 4.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D61E7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A state-preserving Lazy IndexedStack with silky-smooth frame transitions (fade + subtle slide & scale)
class SmoothAnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<WidgetBuilder> tabBuilders;
  final Duration duration;

  const SmoothAnimatedIndexedStack({
    super.key,
    required this.index,
    required this.tabBuilders,
    this.duration = const Duration(milliseconds: 260),
  });

  @override
  State<SmoothAnimatedIndexedStack> createState() => _SmoothAnimatedIndexedStackState();
}

class _SmoothAnimatedIndexedStackState extends State<SmoothAnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;
  late int _currentIndex;
  final Set<int> _activatedTabs = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _activatedTabs.add(_currentIndex);
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..value = 1.0;

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.012, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.995,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didUpdateWidget(SmoothAnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _activatedTabs.add(widget.index);
    if (widget.index != _currentIndex) {
      setState(() {
        _currentIndex = widget.index;
      });
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _activatedTabs.add(_currentIndex);
    final children = List<Widget>.generate(widget.tabBuilders.length, (i) {
      if (_activatedTabs.contains(i)) {
        return widget.tabBuilders[i](context);
      }
      return const SizedBox.shrink();
    });

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: IndexedStack(
            index: _currentIndex.clamp(0, widget.tabBuilders.length - 1),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Flicker-free, GPU-cached brand logo widget with smooth fallback handling
class SmoothBrandLogoWidget extends StatelessWidget {
  final double size;
  final String? logoPath;
  final String companyName;

  const SmoothBrandLogoWidget({
    super.key,
    required this.size,
    this.logoPath,
    this.companyName = 'Apna POS',
  });

  static final Map<String, Uint8List> _base64Cache = {};

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: ClipOval(
          child: _buildImageContent(),
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    final path = logoPath?.trim();
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return Image.network(
          path,
          key: ValueKey('net_$path'),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } else if (path.startsWith('assets/')) {
        return Image.asset(
          path,
          key: ValueKey('asset_$path'),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } else if (!path.contains('_selected') && File(path).existsSync()) {
        return Image.file(
          File(path),
          key: ValueKey('file_$path'),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _buildFallback(),
        );
      } else if (path.startsWith('data:image') || (path.length > 50 && !path.startsWith('/'))) {
        try {
          Uint8List? bytes = _base64Cache[path];
          if (bytes == null) {
            final clean = path.contains(',') ? path.split(',').last : path;
            bytes = base64Decode(clean.trim());
            _base64Cache[path] = bytes;
          }
          return Image.memory(
            bytes,
            key: ValueKey('mem_${path.hashCode}'),
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => _buildFallback(),
          );
        } catch (_) {}
      }
    }

    return _buildFallback();
  }

  Widget _buildFallback() {
    return Image.asset(
      'assets/images/logo.png',
      key: const ValueKey('default_brand_logo_png'),
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => _buildInitialFallback(),
    );
  }

  Widget _buildInitialFallback() {
    String initial = 'A';
    if (companyName.trim().isNotEmpty) {
      initial = companyName.trim()[0].toUpperCase();
    }
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.44,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Flicker-free, GPU-cached user profile avatar widget
class SmoothProfileAvatarWidget extends StatelessWidget {
  final double size;
  final String? photoPath;
  final String userName;
  final bool isOwner;
  final String? companyLogoPath;

  const SmoothProfileAvatarWidget({
    super.key,
    required this.size,
    this.photoPath,
    required this.userName,
    this.isOwner = false,
    this.companyLogoPath,
  });

  static final Map<String, Uint8List> _base64Cache = {};

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFDBEAFE),
        ),
        child: ClipOval(
          child: _buildAvatarContent(),
        ),
      ),
    );
  }

  Widget _buildAvatarContent() {
    final path = photoPath?.trim();
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return Image.network(
          path,
          key: ValueKey('user_net_$path'),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _buildInitial(),
        );
      } else if (path.startsWith('assets/')) {
        return Image.asset(
          path,
          key: ValueKey('user_asset_$path'),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _buildInitial(),
        );
      } else if (!path.contains('_selected') && File(path).existsSync()) {
        return Image.file(
          File(path),
          key: ValueKey('user_file_$path'),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _buildInitial(),
        );
      } else if (path.startsWith('data:image') || (path.length > 50 && !path.startsWith('/'))) {
        try {
          Uint8List? bytes = _base64Cache[path];
          if (bytes == null) {
            final clean = path.contains(',') ? path.split(',').last : path;
            bytes = base64Decode(clean.trim());
            _base64Cache[path] = bytes;
          }
          return Image.memory(
            bytes,
            key: ValueKey('user_mem_${path.hashCode}'),
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => _buildInitial(),
          );
        } catch (_) {}
      }
    }

    if (isOwner && companyLogoPath != null && companyLogoPath!.isNotEmpty) {
      return SmoothBrandLogoWidget(
        size: size,
        logoPath: companyLogoPath,
        companyName: userName,
      );
    }

    return _buildInitial();
  }

  Widget _buildInitial() {
    String initials = '';
    final name = userName.trim();
    if (name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isNotEmpty ? initials : 'ST',
        style: TextStyle(
          fontSize: size * 0.40,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
