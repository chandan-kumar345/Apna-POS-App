import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../../core/widgets/glass_widgets.dart';
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

import '../../core/models/table_model.dart';
import '../../core/models/order_model.dart';
import '../auth/login_screen.dart';
import 'dashboard_screen.dart';


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
        _sidebarController.forward();
      } else {
        _sidebarController.reverse();
      }
    });
  }

  void _openSidebar() {
    if (!_isSidebarOpen) {
      setState(() => _isSidebarOpen = true);
      _sidebarController.forward();
    }
  }

  void _closeSidebar() {
    if (_isSidebarOpen) {
      setState(() => _isSidebarOpen = false);
      _sidebarController.reverse();
    }
  }

  final List<String> _titles = [
    'Dashboard Overview',
    'POS Billing System',
    'Tables & Floor Management',
    'My Orders & Kitchen',
    'Menu & Categories Manager',
    'Inventory & Stock Control',
    'Sales & Analytics Report',
    'Loyalty & Rewards',
    'Marketing Campaign',
    'Business Setting',
  ];



  Widget _buildFeatureModalScreen(String title, IconData icon, String description) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF0052FF), size: 56),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _selectTab(1),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0052FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Back to POS Billing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  PREMIUM SUBSCRIPTION DIALOG
  // ══════════════════════════════════════════════════════
  void _showSubscriptionDialog(String featureName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header gradient banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF051C48), Color(0xFF0A2B6E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        const Text('👑', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        const Text(
                          'Premium Feature',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$featureName is a premium feature.\nSubscribe to unlock full access.',
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFFB0C4DE)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Plan cards
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildPlanCard(
                          '⚡ Monthly Plan',
                          '₹999 / mo',
                          'All premium features for 30 days',
                          const Color(0xFF051C48),
                        ),
                        const SizedBox(height: 10),
                        _buildPlanCard(
                          '🔥 Annual Plan',
                          '₹7,999 / yr',
                          'Save 33% • Best value for growing businesses',
                          const Color(0xFFF59E0B),
                          isHighlighted: true,
                        ),

                        const SizedBox(height: 14),

                        // What's included
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Premium includes:',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 6),
                              for (final f in [
                                '👑  Loyalty & Rewards Program',
                                '📢  Marketing Campaign Tools',
                                '📦  Inventory & Stock Management',
                                '📊  Advanced Analytics & Reports',
                                '🔔  Priority Customer Support',
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Text(f, style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155))),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Subscribe button
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Redirecting to subscription portal...'),
                                  backgroundColor: const Color(0xFF051C48),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF051C48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('👑', style: TextStyle(fontSize: 15)),
                                SizedBox(width: 8),
                                Text(
                                  'Subscribe Now',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Maybe Later',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(String title, String price, String subtitle, Color color, {bool isHighlighted = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted ? color.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? color : const Color(0xFFE2E8F0),
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              price,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: color),
            ),
          ),
        ],
      ),
    );
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
    final user = db.currentUser;
    final displayName = (user?.name.isNotEmpty == true)
        ? user!.name
        : (db.restaurant?.name.isNotEmpty == true ? db.restaurant!.name : 'A');
    return Center(
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
        style: TextStyle(
          color: const Color(0xFF051C48),
          fontWeight: FontWeight.bold,
          fontSize: size * 0.45,
        ),
      ),
    );
  }

  Widget _buildSidebarContent(bool isSmallScreen) {
    final rest = db.restaurant;
    final user = db.currentUser;
    final companyName = rest?.name ?? user?.companyName ?? 'My Business';

    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(2, 4)),
        ],
      ),
      child: Column(
        children: [
          // Profile / Brand Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00C2FF), width: 2),
                ),
                child: _buildProfileAvatarImage(40),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companyName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'Store Management',
                      style: TextStyle(
                        color: Color(0xFF00C2FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                onPressed: _closeSidebar,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 12),

          // Navigation Items (10 Items)
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildNavItem(0, 'Dashboard', Icons.dashboard_rounded, isSmallScreen: isSmallScreen),
                _buildNavItem(1, 'POS', Icons.point_of_sale_rounded, badge: '${db.menuItems.length}', isSmallScreen: isSmallScreen),
                _buildNavItem(2, 'Tables', Icons.table_restaurant_rounded, badge: '${db.tables.where((t) => t.status != TableStatus.free).length}', isSmallScreen: isSmallScreen),
                _buildNavItem(3, 'My Orders', Icons.receipt_long_rounded, badge: '${db.orders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.preparing).length}', isSmallScreen: isSmallScreen),
                _buildNavItem(4, 'Menu & Categories', Icons.restaurant_menu_rounded, isSmallScreen: isSmallScreen),
                _buildNavItem(5, 'Inventory', Icons.inventory_2_rounded, isPremium: true, isSmallScreen: isSmallScreen),
                _buildNavItem(6, 'Sales Report', Icons.bar_chart_rounded, isSmallScreen: isSmallScreen),
                _buildNavItem(7, 'CRM', Icons.people_alt_rounded, isSmallScreen: isSmallScreen),
                _buildNavItem(8, 'Loyalty', Icons.card_giftcard_rounded, isSmallScreen: isSmallScreen),
                _buildNavItem(9, 'Campaign', Icons.campaign_rounded, isPremium: true, isSmallScreen: isSmallScreen),
                _buildNavItem(10, 'Business Setting', Icons.settings_rounded, isSmallScreen: isSmallScreen),
              ],
            ),
          ),

          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 12),

          // User Profile & Logout
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00C2FF), width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4),
                  ],
                ),
                child: _buildProfileAvatarImage(36),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (user?.name.isNotEmpty == true)
                          ? user!.name
                          : (rest?.name.isNotEmpty == true
                              ? rest!.name
                              : 'Owner'),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user?.role ?? 'Owner',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                tooltip: 'Sign Out',
                onPressed: () async {
                  await AuthService().logout();
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
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
                            // ONLINE / OFFLINE BADGE & CLOUD SYNC INDICATOR
                            const GlassConnectionStatusBadge(isDarkTheme: true),
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
                                    final width = 270.0 * _sidebarAnimation.value;
                                    if (_sidebarAnimation.value <= 0.001) {
                                      return const SizedBox.shrink();
                                    }
                                    return SizedBox(
                                      width: width,
                                      child: ClipRect(
                                        child: OverflowBox(
                                          alignment: Alignment.topLeft,
                                          minWidth: 270,
                                          maxWidth: 270,
                                          minHeight: 0,
                                          maxHeight: double.infinity,
                                          child: Opacity(
                                            opacity: _sidebarAnimation.value.clamp(0.0, 1.0),
                                            child: _buildSidebarContent(false),
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
                                    const InventoryScreen(),
                                    const ReportsScreen(),
                                    _buildFeatureModalScreen('Customer Relationship Management (CRM)', Icons.people_alt_rounded, 'Manage customer directory, contact details, purchase histories, and relationships.'),
                                    LoyaltyLandingScreen(onBack: () => _selectTab(0)),
                                    _buildFeatureModalScreen('Marketing Campaign', Icons.campaign_rounded, 'Create promotional SMS/WhatsApp campaigns and discount coupons for customers.'),
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
                      return Stack(
                        children: [
                          // Smooth Backdrop Fade Overlay
                          Positioned.fill(
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
                            top: 0,
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

  Widget _buildNavItem(int index, String title, IconData icon,
      {String? badge, Color? badgeColor, bool isPremium = false, bool isSmallScreen = false}) {
    final isSelected = _selectedIndex == index;

    // ── PREMIUM NAV ITEM: animated shimmer border + 3D orbit crown ──
    if (isPremium) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: GestureDetector(
          onTap: () {
            if (isSmallScreen) _closeSidebar();
            _showSubscriptionDialog(title);
          },
          child: AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              final angle = _shimmerController.value * 2 * math.pi;
              final glowPulse = (math.sin(angle) + 1) / 2; // 0..1
              return Container(
                // subtle 1.5px gradient border
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: const [
                      Color(0xFFFFE57F), // soft gold
                      Color(0xFFFFF9C4), // very pale shine
                      Color(0xFFFFCC80), // light amber
                      Color(0xFFFFE57F), // soft gold
                    ],
                    transform: GradientRotation(angle),
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(255, 230, 100, 0.12 + 0.18 * glowPulse),
                      blurRadius: 6 + 5 * glowPulse,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                // Lighter background — soft warm dark navy with a hint of amber
                color: const Color(0xFF1C1A0E).withOpacity(0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(icon, color: const Color(0xFFFFE082), size: 18), // light gold icon
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFFFF8E1), // very light cream-gold text
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Crown: static (no spin)
                  const Text('👑', style: TextStyle(fontSize: 20)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // ── REGULAR NAV ITEM ──
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () {
          _selectTab(index);
          if (isSmallScreen) {
            _closeSidebar();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0052FF).withOpacity(0.35)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: const Color(0xFF00C2FF), width: 1.2)
                : Border.all(color: Colors.transparent),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF00C2FF).withOpacity(0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 3 : 0,
                height: 16,
                margin: EdgeInsets.only(right: isSelected ? 8 : 0),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C2FF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(
                icon,
                color: isSelected
                    ? const Color(0xFF00C2FF)
                    : const Color(0xFF94A3B8),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null) ...[
                GlassBadge(
                  label: badge,
                  color: badgeColor ??
                      (isSelected
                          ? const Color(0xFF00C2FF)
                          : const Color(0xFF0052FF)),
                  fontSize: 9,
                ),
              ],
            ],
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
