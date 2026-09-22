import 'dart:convert';
import 'dart:io';
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

import '../../core/models/table_model.dart';
import '../../core/models/order_model.dart';
import '../auth/login_screen.dart';
import 'dashboard_screen.dart';
import '../subscription/screens/subscription_screen.dart';
import '../campaign/screens/campaign_screen.dart';
import '../staff/screens/staff_management_screen.dart';


class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with TickerProviderStateMixin {
  final GlobalKey<GlassDashboardScreenState> _dashboardKey = GlobalKey<GlassDashboardScreenState>();
  int _selectedIndex = 1;
  final List<int> _tabHistory = [];
  bool _isSidebarOpen = false;
  bool _isPosFullScreen = false;
  String? _selectedTableForPos;
  OrderType? _selectedOrderTypeForPos;
  final db = DatabaseService();

  bool _canAccessTab(int index) {
    final user = db.currentUser;
    if (user == null || user.isOwner || user.isAdmin) return true;
    switch (index) {
      case 0: // Dashboard
        return user.hasPermission('dashboard') || user.hasPermission('reports');
      case 1: // POS
        return user.hasPermission('pos');
      case 2: // Tables
        return user.hasPermission('tables') || user.hasPermission('pos');
      case 3: // My Orders
        return user.hasPermission('orders') || user.hasPermission('pos');
      case 4: // Menu & Categories
        return user.hasPermission('menu') || user.hasPermission('products');
      case 5: // Inventory
        return user.hasPermission('inventory');
      case 6: // Sales Report
        return user.hasPermission('reports');
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
      default:
        return true;
    }
  }

  void _initInitialAccessibleTab() {
    if (!_canAccessTab(_selectedIndex)) {
      for (int i = 0; i <= 11; i++) {
        if (_canAccessTab(i)) {
          _selectedIndex = i;
          break;
        }
      }
    }
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

  // Animation controllers
  late final AnimationController _shimmerController;
  late final AnimationController _sidebarController;
  late final Animation<double> _sidebarAnimation;
  late final Animation<Offset> _sidebarSlideAnimation;
  late final Animation<double> _sidebarFadeAnimation;
  late final Animation<double> _sidebarScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initInitialAccessibleTab();

    // Border shimmer: sweeping gradient
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Smooth sidebar frame transition with enhanced physics
    _sidebarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 260),
    );

    _sidebarAnimation = CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.fastEaseInToSlowEaseOut,
      reverseCurve: Curves.easeInCubic,
    );

    _sidebarSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _sidebarFadeAnimation = CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeInOut,
      reverseCurve: Curves.easeInOut,
    );

    _sidebarScaleAnimation = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    // Initial fetch of unread notifications count
    NotificationService().fetchUnreadCount();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _sidebarController.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
      if (_isSidebarOpen) {
        _isPosFullScreen = false;
        _sidebarController.forward();
      } else {
        _sidebarController.reverse();
      }
    });
  }

  void _openSidebar() {
    if (!_isSidebarOpen) {
      setState(() {
        _isSidebarOpen = true;
        _isPosFullScreen = false;
      });
      _sidebarController.forward();
    }
  }

  void _closeSidebar() {
    if (_isSidebarOpen) {
      setState(() => _isSidebarOpen = false);
      _sidebarController.reverse();
    }
  }







  Widget _buildProfileAvatarImage(double size) {
    final user = db.currentUser;
    final photoPath = user?.profilePhotoPath;

    if (photoPath != null && photoPath.isNotEmpty) {
      if (!photoPath.contains('_selected') && File(photoPath).existsSync()) {
        return ClipOval(
          child: Image.file(
            File(photoPath),
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } else if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
        return ClipOval(
          child: Image.network(
            photoPath,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackInitial(size),
          ),
        );
      } else if (photoPath.startsWith('data:image') || (photoPath.length > 50 && !photoPath.startsWith('/'))) {
        try {
          final cleanBase64 = photoPath.contains(',') ? photoPath.split(',').last : photoPath;
          final bytes = base64Decode(cleanBase64);
          return ClipOval(
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackInitial(size),
            ),
          );
        } catch (_) {}
      }
    }

    return _buildFallbackInitial(size);
  }

  Widget _buildFallbackInitial(double size) {
    return Center(
      child: Icon(
        Icons.person_rounded,
        color: const Color(0xFF1D4ED8),
        size: size * 0.62,
      ),
    );
  }

  Widget _buildSidebarContent(bool isSmallScreen, {double expansionFactor = 1.0, bool isCollapsed = false}) {
    final rest = db.restaurant;
    final user = db.currentUser;
    final double textOpacity = isSmallScreen ? 1.0 : ((expansionFactor - 0.25) / 0.75).clamp(0.0, 1.0);

    return Container(
      margin: isSmallScreen
          ? const EdgeInsets.all(10)
          : const EdgeInsets.fromLTRB(8, 8, 0, 8),
      padding: EdgeInsets.symmetric(
        vertical: 10,
        horizontal: isSmallScreen ? 10 : (4.0 + 4.0 * expansionFactor),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: isSmallScreen ? Colors.black.withOpacity(0.18) : const Color(0x0A000000),
            blurRadius: isSmallScreen ? 24 : 16,
            offset: isSmallScreen ? const Offset(6, 4) : const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Navigation Items (11 Items)
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                _buildNavItem(
                  index: 0,
                  title: 'Dashboard',
                  icon: Icons.home_rounded,
                  imageAsset: 'assets/images/Side bar icons/home.png',
                  iconColor: const Color(0xFF1D4ED8),
                  iconBgColor: const Color(0xFFEBF2FE),
                  isSmallScreen: isSmallScreen,
                  isCollapsed: isCollapsed,
                  expansionFactor: expansionFactor,
                ),
                _buildNavItem(
                  index: 1,
                  title: 'POS',
                  icon: Icons.point_of_sale_rounded,
                  imageAsset: 'assets/images/Side bar icons/POS.png',
                  iconColor: const Color(0xFF1D4ED8),
                  iconBgColor: const Color(0xFFDCEBFE),
                  badge: '${db.menuItems.length}',
                  isSmallScreen: isSmallScreen,
                  isCollapsed: isCollapsed,
                  expansionFactor: expansionFactor,
                ),
                _buildNavItem(
                  index: 2,
                  title: 'Tables',
                  icon: Icons.table_restaurant_rounded,
                  imageAsset: 'assets/images/Side bar icons/tables.png',
                  iconColor: const Color(0xFF10B981),
                  iconBgColor: const Color(0xFFDCFCE7),
                  badge: '${db.tables.where((t) => t.status != TableStatus.free).length}',
                  isSmallScreen: isSmallScreen,
                  isCollapsed: isCollapsed,
                  expansionFactor: expansionFactor,
                ),
                _buildNavItem(
                  index: 3,
                  title: 'My Orders',
                  icon: Icons.receipt_long_rounded,
                  imageAsset: 'assets/images/Side bar icons/my orders.png',
                  iconColor: const Color(0xFF7C3AED),
                  iconBgColor: const Color(0xFFF3E8FF),
                  badge: '${db.orders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.preparing).length}',
                  isSmallScreen: isSmallScreen,
                  isCollapsed: isCollapsed,
                  expansionFactor: expansionFactor,
                ),
                _buildNavItem(
                  index: 4,
                  title: 'Menu & Categories',
                  icon: Icons.dinner_dining_rounded,
                  imageAsset: 'assets/images/Side bar icons/menu & categories.png',
                  iconColor: const Color(0xFFEA580C),
                  iconBgColor: const Color(0xFFFFEDD5),
                  isSmallScreen: isSmallScreen,
                  isCollapsed: isCollapsed,
                  expansionFactor: expansionFactor,
                ),
                _buildNavItem(
                  index: 5,
                  title: 'Inventory',
                  icon: Icons.inventory_2_rounded,
                  imageAsset: 'assets/images/Side bar icons/inventory.png',
                  iconColor: const Color(0xFFEA580C),
                  iconBgColor: const Color(0xFFFFEDD5),
                  isPremium: true,
                  isSmallScreen: isSmallScreen,
                  isCollapsed: isCollapsed,
                  expansionFactor: expansionFactor,
                ),
                _buildNavItem(
                  index: 6,
                  title: 'Sales Report',
                  icon: Icons.bar_chart_rounded,
                  imageAsset: 'assets/images/Side bar icons/sale.png',
                  iconColor: const Color(0xFF0284C7),
                  iconBgColor: const Color(0xFFE0F2FE),
                  isSmallScreen: isSmallScreen,
                  isCollapsed: isCollapsed,
                  expansionFactor: expansionFactor,
                ),
                _buildNavItem(
                  index: 7,
                  title: 'CRM',
                  icon: Icons.people_alt_rounded,
                  imageAsset: 'assets/images/Side bar icons/crm.png',
                  iconColor: const Color(0xFFDB2777),
                  iconBgColor: const Color(0xFFFCE7F3),
                  isSmallScreen: isSmallScreen,
                  isCollapsed: isCollapsed,
                  expansionFactor: expansionFactor,
                ),
                _buildNavItem(
                  index: 8,
                  title: 'Loyalty',
                  icon: Icons.card_giftcard_rounded,
                  imageAsset: 'assets/images/Side bar icons/Loyalty.png',
                  iconColor: const Color(0xFFD97706),
                  iconBgColor: const Color(0xFFFEF08A),
                  isPremium: true,
                  isSmallScreen: isSmallScreen,
                  isCollapsed: isCollapsed,
                  expansionFactor: expansionFactor,
                ),
                _buildNavItem(
                  index: 9,
                  title: 'Campaign',
                  icon: Icons.campaign_rounded,
                  imageAsset: 'assets/images/Side bar icons/campaign.png',
                  iconColor: const Color(0xFFEA580C),
                  iconBgColor: const Color(0xFFFFE4E6),
                  isPremium: true,
                  isSmallScreen: isSmallScreen,
                  isCollapsed: isCollapsed,
                  expansionFactor: expansionFactor,
                ),
                _buildNavItem(
                  index: 10,
                  title: 'Staff Setting',
                  icon: Icons.badge_rounded,
                  imageAsset: 'assets/images/Side bar icons/staff.png',
                  iconColor: const Color(0xFF2563EB),
                  iconBgColor: const Color(0xFFEFF6FF),
                  badge: '${db.staffList.length}',
                  isSmallScreen: isSmallScreen,
                  isCollapsed: isCollapsed,
                  expansionFactor: expansionFactor,
                ),
                _buildNavItem(
                  index: 11,
                  title: 'Business Setting',
                  icon: Icons.settings_rounded,
                  imageAsset: 'assets/images/Side bar icons/setting.png',
                  iconColor: const Color(0xFF475569),
                  iconBgColor: const Color(0xFFF1F5F9),
                  isSmallScreen: isSmallScreen,
                  isCollapsed: isCollapsed,
                  expansionFactor: expansionFactor,
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),
          const SizedBox(height: 10),

          // User Profile & Logout Bottom Row with Smooth Fade & Slide Transition
          if (!isSmallScreen && isCollapsed && expansionFactor < 0.25)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Tooltip(
                    message: '${user?.name.isNotEmpty == true ? user!.name : (rest?.name.isNotEmpty == true ? rest!.name : "Kundan Lal")} (${(user?.role.isNotEmpty == true) ? user!.role.toLowerCase() : "owner"})',
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDBEAFE),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: _buildProfileAvatarImage(38),
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
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(10),
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
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: isSmallScreen ? 44 : (38.0 + 8.0 * expansionFactor),
                    height: isSmallScreen ? 44 : (38.0 + 8.0 * expansionFactor),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDBEAFE),
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: _buildProfileAvatarImage(isSmallScreen ? 44 : 42),
                    ),
                  ),
                  if (isSmallScreen || textOpacity > 0.0) ...[
                    const SizedBox(width: 8),
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
                                (user?.name.isNotEmpty == true)
                                    ? user!.name
                                    : (rest?.name.isNotEmpty == true
                                        ? rest!.name
                                        : 'Kundan Lal'),
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                (user?.role.isNotEmpty == true) ? user!.role.toLowerCase() : 'owner',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE4E6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.logout_rounded,
                                color: Color(0xFFEF4444),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
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

  Widget _buildNotificationBellButton() {
    return AnimatedBuilder(
      animation: NotificationService(),
      builder: (context, _) {
        final unreadCount = NotificationService().unreadCount;

        return Tooltip(
          message: 'Notifications ($unreadCount unread)',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openNotificationScreen,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1.1,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3.5),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                          alignment: Alignment.center,
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
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
        if (_tabHistory.isNotEmpty) {
          final prevIndex = _tabHistory.removeLast();
          setState(() {
            _selectedIndex = prevIndex;
          });
          return;
        }

        // 3. If currently on a non-POS tab, return to POS billing screen
        if (_selectedIndex != 1) {
          setState(() {
            _selectedIndex = 1;
          });
          return;
        }

        // 4. User is on POS billing screen (root of app) -> Close/exit the app cleanly
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF051C48), // Match exact deep navy blue from user image
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 900;

            return Stack(
              children: [
                // Workspace Body & Top Deep Navy Header Bar
                Column(
                  children: [
                    // TOP HEADER BAR (EXACT DEEP NAVY BLUE FROM IMAGE + LOGO & SEMI-CURVED NAME BADGE TOGETHER)
                    AnimatedCrossFade(
                      firstChild: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF051C48), // Deep Navy Blue
                              Color(0xFF0A2B66), // Rich Deep Royal Blue
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                        child: Row(
                          children: [
                            // MENU TOGGLE BUTTON (HAMBURGER) - Always available on all screen sizes
                            IconButton(
                              icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
                              onPressed: _toggleSidebar,
                              tooltip: 'Open / Close Navigation',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            ),
                            const SizedBox(width: 6),

                            // LOGO AND HIGHLIGHTED SEMI-CURVED COMPANY NAME TOGETHER ON LEFT
                            InkWell(
                              onTap: _toggleSidebar,
                              borderRadius: BorderRadius.circular(24),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black38, blurRadius: 6),
                                      ],
                                    ),
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: _buildProfileAvatarImage(34),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // HIGHLIGHTED SEMI-CURVED FIELD FOR COMPANY NAME
                                  GlassCompanyNameBadge(name: companyTitle),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // ONLINE / OFFLINE STATUS DOT INDICATOR
                            const GlassConnectionStatusBadge(isDarkTheme: true),
                            const SizedBox(width: 8),
                            // NOTIFICATION BELL BUTTON
                            _buildNotificationBellButton(),
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

                    // ACTIVE SCREEN WORKSPACE (CURVED WHITE BACKGROUND DOWNSIDE)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOutCubic,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(((_selectedIndex == 1 && _isPosFullScreen) || _selectedIndex == 8) ? 0 : 28),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(((_selectedIndex == 1 && _isPosFullScreen) || _selectedIndex == 8) ? 0 : 28),
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
                                  index: _selectedIndex.clamp(0, 11),
                                  children: [
                                    _canAccessTab(0)
                                        ? GlassDashboardScreen(
                                            key: _dashboardKey,
                                            isActive: _selectedIndex == 0,
                                            onNavigateTab: (index) => _selectTab(index),
                                          )
                                        : _buildAccessDeniedScreen('Dashboard'),
                                     _canAccessTab(1)
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
                                     _canAccessTab(2)
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
                                     _canAccessTab(3)
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
                                    _canAccessTab(4)
                                        ? const MenuManagementScreen()
                                        : _buildAccessDeniedScreen('Menu & Categories'),
                                    _canAccessTab(5)
                                        ? InventoryScreen(onBack: () => _selectTab(0))
                                        : _buildAccessDeniedScreen('Inventory'),
                                    _canAccessTab(6)
                                        ? const ReportsScreen()
                                        : _buildAccessDeniedScreen('Sales Report'),
                                    _canAccessTab(7)
                                        ? CrmLeadsScreen(
                                            onOpenDrawer: _toggleSidebar,
                                            onNavigateToDashboard: () => _selectTab(0),
                                          )
                                        : _buildAccessDeniedScreen('CRM'),
                                    _canAccessTab(8)
                                        ? LoyaltyLandingScreen(onBack: () => _selectTab(0))
                                        : _buildAccessDeniedScreen('Loyalty'),
                                    _canAccessTab(9)
                                        ? CampaignScreen(onBack: () => _selectTab(0))
                                        : _buildAccessDeniedScreen('Campaign'),
                                    _canAccessTab(10)
                                        ? StaffManagementScreen(
                                            onOpenDrawer: _toggleSidebar,
                                            onNavigateToDashboard: () => _selectTab(0),
                                          )
                                        : _buildAccessDeniedScreen('Staff Setting'),
                                    _canAccessTab(11)
                                        ? const BusinessSettingsHubScreen()
                                        : _buildAccessDeniedScreen('Business Setting'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // FULL HEIGHT SIDEBAR OVERLAY ON MOBILE / SMALL SCREENS WITH SMOOTH SLIDE & FADE
                if (isSmallScreen)
                  AnimatedBuilder(
                    animation: _sidebarAnimation,
                    builder: (context, child) {
                      if (_sidebarAnimation.value <= 0.001 && !_isSidebarOpen) {
                        return const SizedBox.shrink();
                      }
                      final double mobileDrawerWidth = (constraints.maxWidth * 0.82).clamp(270.0, 310.0);

                      return Stack(
                        children: [
                          // Smooth Backdrop Fade Overlay (Full screen coverage)
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: _closeSidebar,
                              behavior: HitTestBehavior.opaque,
                              child: FadeTransition(
                                opacity: _sidebarFadeAnimation,
                                child: Container(
                                  color: Colors.black.withOpacity(0.55),
                                ),
                              ),
                            ),
                          ),
                          // Smooth Sliding & Scaling Sidebar (Full height)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: mobileDrawerWidth,
                            child: SlideTransition(
                              position: _sidebarSlideAnimation,
                              child: ScaleTransition(
                                scale: _sidebarScaleAnimation,
                                alignment: Alignment.centerLeft,
                                child: GestureDetector(
                                  onHorizontalDragUpdate: (details) {
                                    if (details.primaryDelta != null && details.primaryDelta! < 0) {
                                      _sidebarController.value += details.primaryDelta! / mobileDrawerWidth;
                                    }
                                  },
                                  onHorizontalDragEnd: (details) {
                                    if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
                                      _closeSidebar();
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
                          ),
                        ],
                      );
                    },
                  ),
              ],
            );
          },
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
                onPressed: () {
                  for (int i = 0; i <= 11; i++) {
                    if (_canAccessTab(i)) {
                      _selectTab(i);
                      break;
                    }
                  }
                },
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

    final void Function() onTapAction = () {
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
    };

    final bool isCollapsedRail = !isSmallScreen && expansionFactor < 0.35;
    final bool showTileHighlight = isSelected && !isCollapsedRail;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
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
                        : (isCollapsedRail ? 0 : (isSelected ? 6 : 4)),
                    vertical: isSelected ? 6 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: showTileHighlight
                        ? const Color(0xFFEBF3FE)
                        : (isPremium ? const Color(0xFFFEF7DC) : Colors.transparent),
                    borderRadius: BorderRadius.circular(16),
                    border: showTileHighlight
                        ? Border.all(color: const Color(0xFF1D4ED8).withOpacity(0.18), width: 1.2)
                        : null,
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
                            scale: isSelected ? (isCollapsedRail ? 1.22 : 1.08) : 1.0,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutBack,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isPermitted ? iconBgColor : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(
                                        color: const Color(0xFF1D4ED8),
                                        width: isCollapsedRail ? 2.0 : 1.4,
                                      )
                                    : (isPermitted
                                        ? Border.all(color: const Color(0xFFE2E8F0), width: 0.8)
                                        : null),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF1D4ED8).withOpacity(isCollapsedRail ? 0.28 : 0.16),
                                          blurRadius: isCollapsedRail ? 8 : 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: AnimatedScale(
                                scale: isSelected ? 1.10 : 1.0,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutBack,
                                child: imageAsset != null && imageAsset.isNotEmpty
                                    ? Opacity(
                                        opacity: isPermitted ? 1.0 : 0.45,
                                        child: Image.asset(
                                          imageAsset,
                                          width: 26,
                                          height: 26,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => Icon(
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
                                            color: const Color(0xFFEF4444),
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
                              child: AnimatedScale(
                                scale: isSelected ? 1.04 : 1.0,
                                alignment: Alignment.centerLeft,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutBack,
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF1D4ED8)
                                        : (!isPermitted
                                            ? const Color(0xFF94A3B8)
                                            : (isPremium ? const Color(0xFF92400E) : const Color(0xFF0F172A))),
                                    fontWeight: isSelected
                                        ? FontWeight.w900
                                        : (isPremium ? FontWeight.w800 : FontWeight.w700),
                                    fontSize: 14.5,
                                    letterSpacing: 0.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                                      ? const Text('👑', style: TextStyle(fontSize: 19))
                                      : (badge != null && badge != '0')
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? const Color(0xFF1D4ED8)
                                                    : const Color(0xFFE2E8F0),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                badge,
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                                  fontSize: 11.5,
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
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 3.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D4ED8),
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

/// A state-preserving IndexedStack with silky-smooth frame transitions (fade + subtle slide & scale)
class SmoothAnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const SmoothAnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: IndexedStack(
            index: _currentIndex.clamp(0, widget.children.length - 1),
            children: widget.children,
          ),
        ),
      ),
    );
  }
}
