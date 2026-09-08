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
  final db = DatabaseService();

  void _selectTab(int index) {
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

  @override
  void initState() {
    super.initState();
    // Border shimmer: sweeping gradient
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Smooth sidebar frame transition
    _sidebarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _sidebarAnimation = CurvedAnimation(
      parent: _sidebarController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _sidebarSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(_sidebarAnimation);

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

  Widget _buildSidebarContent(bool isSmallScreen) {
    final rest = db.restaurant;
    final user = db.currentUser;

    return Container(
      margin: isSmallScreen
          ? const EdgeInsets.all(10)
          : const EdgeInsets.fromLTRB(10, 10, 0, 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
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
                  iconColor: const Color(0xFF1D4ED8),
                  iconBgColor: const Color(0xFFEBF2FE),
                  isSmallScreen: isSmallScreen,
                ),
                _buildNavItem(
                  index: 1,
                  title: 'POS',
                  icon: Icons.point_of_sale_rounded,
                  iconColor: const Color(0xFF1D4ED8),
                  iconBgColor: const Color(0xFFDCEBFE),
                  badge: '${db.menuItems.length}',
                  isSmallScreen: isSmallScreen,
                ),
                _buildNavItem(
                  index: 2,
                  title: 'Tables',
                  icon: Icons.table_restaurant_rounded,
                  iconColor: const Color(0xFF10B981),
                  iconBgColor: const Color(0xFFDCFCE7),
                  badge: '${db.tables.where((t) => t.status != TableStatus.free).length}',
                  isSmallScreen: isSmallScreen,
                ),
                _buildNavItem(
                  index: 3,
                  title: 'My Orders',
                  icon: Icons.receipt_long_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  iconBgColor: const Color(0xFFF3E8FF),
                  badge: '${db.orders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.preparing).length}',
                  isSmallScreen: isSmallScreen,
                ),
                _buildNavItem(
                  index: 4,
                  title: 'Menu & Categories',
                  icon: Icons.dinner_dining_rounded,
                  iconColor: const Color(0xFFEA580C),
                  iconBgColor: const Color(0xFFFFEDD5),
                  isSmallScreen: isSmallScreen,
                ),
                _buildNavItem(
                  index: 5,
                  title: 'Inventory',
                  icon: Icons.inventory_2_rounded,
                  iconColor: const Color(0xFFEA580C),
                  iconBgColor: const Color(0xFFFFEDD5),
                  isPremium: true,
                  isSmallScreen: isSmallScreen,
                ),
                _buildNavItem(
                  index: 6,
                  title: 'Sales Report',
                  icon: Icons.bar_chart_rounded,
                  iconColor: const Color(0xFF0284C7),
                  iconBgColor: const Color(0xFFE0F2FE),
                  isSmallScreen: isSmallScreen,
                ),
                _buildNavItem(
                  index: 7,
                  title: 'CRM',
                  icon: Icons.people_alt_rounded,
                  iconColor: const Color(0xFFDB2777),
                  iconBgColor: const Color(0xFFFCE7F3),
                  isSmallScreen: isSmallScreen,
                ),
                _buildNavItem(
                  index: 8,
                  title: 'Loyalty',
                  icon: Icons.card_giftcard_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBgColor: const Color(0xFFFEF08A),
                  isPremium: true,
                  isSmallScreen: isSmallScreen,
                ),
                _buildNavItem(
                  index: 9,
                  title: 'Campaign',
                  icon: Icons.campaign_rounded,
                  iconColor: const Color(0xFFEA580C),
                  iconBgColor: const Color(0xFFFFE4E6),
                  isPremium: true,
                  isSmallScreen: isSmallScreen,
                ),
                _buildNavItem(
                  index: 10,
                  title: 'Business Setting',
                  icon: Icons.settings_rounded,
                  iconColor: const Color(0xFF475569),
                  iconBgColor: const Color(0xFFF1F5F9),
                  isSmallScreen: isSmallScreen,
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFFE2E8F0), height: 1, thickness: 1),
          const SizedBox(height: 10),

          // User Profile & Logout Bottom Row (Matches exact screenshot layout)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDBEAFE),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: _buildProfileAvatarImage(46),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
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
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        (user?.role.isNotEmpty == true) ? user!.role.toLowerCase() : 'owner',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
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
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE4E6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFEF4444),
                      size: 22,
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
        body: SafeArea(
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
                            // MENU TOGGLE BUTTON (HAMBURGER) - Only shown on desktop/large screens
                            if (!isSmallScreen) ...[
                              IconButton(
                                icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
                                onPressed: _toggleSidebar,
                                tooltip: 'Open / Close Navigation',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              ),
                              const SizedBox(width: 6),
                            ],

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
                              // DESKTOP ANIMATED SLIDING & SCALING SIDEBAR
                              if (!isSmallScreen)
                                AnimatedBuilder(
                                  animation: _sidebarAnimation,
                                  builder: (context, child) {
                                    if (_sidebarAnimation.value <= 0.001) {
                                      return const SizedBox.shrink();
                                    }
                                    return SizedBox(
                                      width: 260.0 * _sidebarAnimation.value,
                                      height: double.infinity,
                                      child: ClipRect(
                                        child: Align(
                                          alignment: Alignment.topLeft,
                                          widthFactor: _sidebarAnimation.value,
                                          child: SizedBox(
                                            width: 260,
                                            height: double.infinity,
                                            child: Opacity(
                                              opacity: _sidebarAnimation.value.clamp(0.0, 1.0),
                                              child: _buildSidebarContent(false),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                              Expanded(
                                child: SmoothAnimatedIndexedStack(
                                  index: _selectedIndex.clamp(0, 10),
                                  children: [
                                    GlassDashboardScreen(
                                      key: _dashboardKey,
                                      isActive: _selectedIndex == 0,
                                      onNavigateTab: (index) => _selectTab(index),
                                    ),
                                    PosRegisterScreen(
                                      initialTable: _selectedTableForPos,
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
                                    ),
                                    TableManagementScreen(
                                      onTakeOrder: (tableName) {
                                        setState(() {
                                          _selectedTableForPos = tableName;
                                        });
                                        _selectTab(1);
                                      },
                                    ),
                                    OrdersScreen(
                                      onOpenPosForTable: (tableName) {
                                        setState(() {
                                          _selectedTableForPos = tableName;
                                        });
                                        _selectTab(1);
                                      },
                                    ),
                                    const MenuManagementScreen(),
                                    InventoryScreen(onBack: () => _selectTab(0)),
                                    const ReportsScreen(),
                                    CrmLeadsScreen(
                                      onOpenDrawer: _toggleSidebar,
                                      onNavigateToDashboard: () => _selectTab(0),
                                    ),
                                    LoyaltyLandingScreen(onBack: () => _selectTab(0)),
                                    CampaignScreen(onBack: () => _selectTab(0)),
                                    const BusinessSettingsHubScreen(),
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
                      final isHeaderVisible = !((_selectedIndex == 1 && _isPosFullScreen) || _selectedIndex == 8);
                      final sidebarTopOffset = isHeaderVisible ? 58.0 : 0.0;

                      return Stack(
                        children: [
                          // Smooth Backdrop Fade Overlay
                          Positioned(
                            left: 0,
                            right: 0,
                            top: sidebarTopOffset,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: _closeSidebar,
                              child: Opacity(
                                opacity: (_sidebarAnimation.value * 0.55).clamp(0.0, 0.55),
                                child: Container(color: Colors.black),
                              ),
                            ),
                          ),
                          // Smooth Sliding Sidebar
                          Positioned(
                            left: 0,
                            top: sidebarTopOffset,
                            bottom: 0,
                            width: 280,
                            child: SlideTransition(
                              position: _sidebarSlideAnimation,
                              child: GestureDetector(
                                onHorizontalDragUpdate: (details) {
                                  if (details.primaryDelta != null && details.primaryDelta! < 0) {
                                    _sidebarController.value += details.primaryDelta! / 280;
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

  Widget _buildNavItem({
    required int index,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    String? badge,
    bool isPremium = false,
    bool isSmallScreen = false,
  }) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: InkWell(
        onTap: () {
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
        },
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFEBF3FE)
                    : (isPremium ? const Color(0xFFFEF7DC) : Colors.transparent),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFF1D4ED8)
                            : (isPremium ? const Color(0xFF92400E) : const Color(0xFF0F172A)),
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : (isPremium ? FontWeight.w800 : FontWeight.w700),
                        fontSize: 14.5,
                        letterSpacing: 0.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isPremium)
                    const Text('👑', style: TextStyle(fontSize: 19))
                  else if (badge != null && badge != '0')
                    Container(
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
                    ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                left: 0,
                top: 8,
                bottom: 8,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D4ED8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ],
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
