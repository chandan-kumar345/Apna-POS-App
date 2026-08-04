import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/widgets/glass_widgets.dart';
import '../../core/database/database_service.dart';
import '../../core/widgets/glass_company_name_badge.dart';
import '../pos/pos_register_screen.dart';
import '../tables/table_management_screen.dart';
import '../orders/orders_screen.dart';
import '../menu/menu_management_screen.dart';
import '../inventory/inventory_screen.dart';
import '../reports/reports_screen.dart';
import '../onboarding/business_settings_screen.dart';
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
  int _selectedIndex = 1;
  bool _isSidebarOpen = false;
  String? _selectedTableForPos;
  final db = DatabaseService();

  // Animation controllers for premium items
  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    // Border shimmer: sweeping gradient
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
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

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return GlassDashboardScreen(
          onNavigateTab: (index) => setState(() => _selectedIndex = index),
        );
      case 1:
        return PosRegisterScreen(
          initialTable: _selectedTableForPos,
          onOpenDrawer: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
          onOpenTablesTab: () => setState(() => _selectedIndex = 2),
        );
      case 2:
        return TableManagementScreen(
          onTakeOrder: (tableName) {
            setState(() {
              _selectedTableForPos = tableName;
              _selectedIndex = 1;
            });
          },
        );
      case 3:
        return const OrdersScreen();
      case 4:
        return const MenuManagementScreen();
      case 5:
        return const InventoryScreen();
      case 6:
        return const ReportsScreen();
      case 7:
        return _buildFeatureModalScreen('Loyalty & Rewards', Icons.card_giftcard_rounded, 'Manage customer loyalty points, rewards program, and VIP memberships.');
      case 8:
        return _buildFeatureModalScreen('Marketing Campaign', Icons.campaign_rounded, 'Create promotional SMS/WhatsApp campaigns and discount coupons for customers.');
      case 9:
        return const BusinessSettingsScreen();
      default:
        return PosRegisterScreen(
          initialTable: _selectedTableForPos,
          onOpenDrawer: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
        );
    }
  }

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
              onPressed: () => setState(() => _selectedIndex = 1),
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
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
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
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
                    // Crown emoji from asset / emoji
                    const Text('👑', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 10),
                    const Text(
                      'Premium Feature',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$featureName is a premium feature.\nSubscribe to unlock full access.',
                      style: const TextStyle(fontSize: 13, color: Color(0xFFB0C4DE)),
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
                      '₹999 / month',
                      'All premium features for 30 days',
                      const Color(0xFF051C48),
                    ),
                    const SizedBox(height: 10),
                    _buildPlanCard(
                      '🔥 Annual Plan',
                      '₹7,999 / year',
                      'Save 33% • Best value for growing businesses',
                      const Color(0xFFF59E0B),
                      isHighlighted: true,
                    ),

                    const SizedBox(height: 16),

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
                          const SizedBox(height: 8),
                          for (final f in [
                            '👑  Loyalty & Rewards Program',
                            '📢  Marketing Campaign Tools',
                            '📦  Inventory & Stock Management',
                            '📊  Advanced Analytics & Reports',
                            '🔔  Priority Customer Support',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(f, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Subscribe button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
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
                            Text('👑', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 8),
                            Text(
                              'Subscribe Now',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Maybe Later',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
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

  Widget _buildPlanCard(String title, String price, String subtitle, Color color, {bool isHighlighted = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Text(
            price,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
          ),
        ],
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/images/restaurant_icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, color: Color(0xFF0052FF), size: 24),
                  ),
                ),
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
                onPressed: () => setState(() => _isSidebarOpen = false),
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
                _buildNavItem(0, 'Dashboard', Icons.dashboard_rounded),
                _buildNavItem(1, 'POS', Icons.point_of_sale_rounded, badge: '${db.menuItems.length}'),
                _buildNavItem(2, 'Tables', Icons.table_restaurant_rounded, badge: '${db.tables.where((t) => t.status != TableStatus.free).length}'),
                _buildNavItem(3, 'My Orders', Icons.receipt_long_rounded, badge: '${db.orders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.preparing).length}'),
                _buildNavItem(4, 'Menu & Categories', Icons.restaurant_menu_rounded),
                _buildNavItem(5, 'Inventory', Icons.inventory_2_rounded, isPremium: true),
                _buildNavItem(6, 'Sales Report', Icons.bar_chart_rounded),
                _buildNavItem(7, 'Loyalty', Icons.card_giftcard_rounded, isPremium: true),
                _buildNavItem(8, 'Campaign', Icons.campaign_rounded, isPremium: true),
                _buildNavItem(9, 'Business Setting', Icons.settings_rounded),
              ],
            ),
          ),

          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 12),

          // User Profile & Logout
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF0052FF).withOpacity(0.3),
                child: Text(
                  (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'A',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'Admin Staff',
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
                  await db.logout();
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
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

    return Scaffold(
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
                    Container(
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
                            onTap: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
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
                                  child: CircleAvatar(
                                    radius: 17,
                                    backgroundColor: Colors.white,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(17),
                                      child: Image.asset(
                                        'assets/images/restaurant_icon.png',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, color: Color(0xFF051C48), size: 20),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // HIGHLIGHTED SEMI-CURVED FIELD FOR COMPANY NAME
                                GlassCompanyNameBadge(name: companyTitle),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ACTIVE SCREEN WORKSPACE (CURVED WHITE BACKGROUND DOWNSIDE)
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          child: Row(
                            children: [
                              if (_isSidebarOpen && !isSmallScreen)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: 270,
                                  child: _buildSidebarContent(false),
                                ),

                              Expanded(
                                child: _getSelectedScreen(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // FULL HEIGHT SIDEBAR OVERLAY ON MOBILE / SMALL SCREENS
                if (_isSidebarOpen && isSmallScreen) ...[
                  GestureDetector(
                    onTap: () => setState(() => _isSidebarOpen = false),
                    child: Container(
                      color: Colors.black.withOpacity(0.55),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 280,
                    child: GestureDetector(
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null && details.primaryVelocity! < -100) {
                          setState(() => _isSidebarOpen = false);
                        }
                      },
                      child: _buildSidebarContent(true),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon,
      {String? badge, Color? badgeColor, bool isPremium = false}) {
    final isSelected = _selectedIndex == index;

    // ── PREMIUM NAV ITEM: animated shimmer border + 3D orbit crown ──
    if (isPremium) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: GestureDetector(
          onTap: () => _showSubscriptionDialog(title),
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
          setState(() {
            _selectedIndex = index;
            _isSidebarOpen = false;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF0052FF).withOpacity(0.4)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: const Color(0xFF00C2FF))
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: [
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
