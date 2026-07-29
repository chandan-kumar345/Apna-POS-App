import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/database/database_service.dart';
import '../pos/pos_register_screen.dart';
import '../tables/table_management_screen.dart';
import '../kds/kds_screen.dart';
import '../menu/menu_management_screen.dart';
import '../inventory/inventory_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/models/table_model.dart';
import '../../core/models/order_model.dart';
import '../auth/login_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  bool _isSidebarOpen = false;
  String? _selectedTableForPos;
  final db = DatabaseService();

  final List<String> _titles = [
    'POS Billing',
    'Interactive Floor & Tables',
    'Kitchen Display System (KDS)',
    'Menu & Category Manager',
    'Inventory & Stock Control',
    'Analytics & Reports',
    'Restaurant & System Settings',
  ];

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return PosRegisterScreen(initialTable: _selectedTableForPos);
      case 1:
        return TableManagementScreen(
          onTakeOrder: (tableName) {
            setState(() {
              _selectedTableForPos = tableName;
              _selectedIndex = 0;
            });
          },
        );
      case 2:
        return const KdsScreen();
      case 3:
        return const MenuManagementScreen();
      case 4:
        return const InventoryScreen();
      case 5:
        return const ReportsScreen();
      case 6:
        return const SettingsScreen();
      default:
        return PosRegisterScreen(initialTable: _selectedTableForPos);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nowStr = DateFormat('EEE, dd MMM • hh:mm a').format(DateTime.now());
    final rest = db.restaurant;
    final user = db.currentUser;

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: GlassTheme.backgroundDecoration,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 900;
              
              return Stack(
                children: [
                  Row(
                    children: [
                      // Glassmorphic Left Sidebar Navigation (Collapsible with Slide to Close)
                      if (_isSidebarOpen)
                        GestureDetector(
                          onHorizontalDragEnd: (details) {
                            if (details.primaryVelocity != null && details.primaryVelocity! < -100) {
                              setState(() => _isSidebarOpen = false);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: isSmallScreen ? 240 : 260,
                            margin: const EdgeInsets.all(8),
                            child: GlassContainer(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              borderRadius: 20,
                              blurStrength: 24,
                              child: Column(
                                children: [
                                  // Brand Header
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          gradient: GlassTheme.primaryButtonGradient,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: GlassTheme.primaryViolet.withOpacity(0.5),
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Apna POS',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            Text(
                                              rest?.name ?? 'Restaurant POS',
                                              style: const TextStyle(
                                                color: GlassTheme.primaryCyan,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Divider(color: GlassTheme.glassBorder, height: 1),
                                  const SizedBox(height: 12),

                                  // Navigation Items
                                  Expanded(
                                    child: ListView(
                                      padding: EdgeInsets.zero,
                                      children: [
                                        _buildNavItem(0, 'POS Billing', Icons.point_of_sale, badge: '${db.menuItems.length}'),
                                      _buildNavItem(1, 'Tables & Floor', Icons.table_restaurant_outlined, badge: '${db.tables.where((t) => t.status != TableStatus.free).length}'),
                                      _buildNavItem(2, 'Kitchen (KDS)', Icons.soup_kitchen_outlined, badge: '${db.orders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.preparing).length}'),
                                      _buildNavItem(3, 'Menu & Categories', Icons.restaurant_menu_outlined),
                                      _buildNavItem(4, 'Inventory', Icons.inventory_2_outlined, badge: db.inventoryItems.any((i) => i.isLowStock) ? 'Alert' : null, badgeColor: GlassTheme.accentRose),
                                      _buildNavItem(5, 'Reports & Sales', Icons.bar_chart_rounded),
                                      _buildNavItem(6, 'Settings', Icons.settings_outlined),
                                    ],
                                  ),
                                ),

                                const Divider(color: GlassTheme.glassBorder, height: 1),
                                const SizedBox(height: 10),

                                // User Profile & Logout
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: GlassTheme.primaryViolet.withOpacity(0.3),
                                      child: Text(
                                        (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'A',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user?.name ?? 'Admin Staff',
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            user?.role ?? 'Owner',
                                            style: const TextStyle(color: GlassTheme.textMedium, fontSize: 10),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.logout_rounded, color: GlassTheme.accentRose, size: 18),
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
                          ),
                        ),
                      ),

                      // Right Main Content Region
                      Expanded(
                        child: Column(
                          children: [
                            // Top Glass Navigation Bar with Hamburger Toggle Button
                            Container(
                              margin: const EdgeInsets.only(top: 8, right: 8, left: 8, bottom: 6),
                              child: GlassContainer(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                borderRadius: 16,
                                blurStrength: 16,
                                child: Row(
                                  children: [
                                    // HAMBURGER MENU BUTTON TO TOGGLE SIDEBAR
                                    IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(6),
                                      icon: Icon(
                                        _isSidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
                                        color: GlassTheme.primaryCyan,
                                        size: 22,
                                      ),
                                      tooltip: _isSidebarOpen ? 'Hide Menu' : 'Open Menu',
                                      onPressed: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
                                    ),
                                    const SizedBox(width: 6),

                                    Expanded(
                                      child: Text(
                                        _titles[_selectedIndex],
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 14 : 17,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),

                                    if (!isSmallScreen) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: GlassTheme.glassInput,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: GlassTheme.glassBorder),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.access_time_rounded, color: GlassTheme.primaryCyan, size: 13),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                nowStr,
                                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            // Dynamic Screen Workspace
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(right: 8, left: 8, bottom: 8),
                                child: ClipRect(
                                  child: _getSelectedScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon, {String? badge, Color? badgeColor}) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
            // AUTO CLOSE SIDEBAR WHEN USER SELECTS ANY HAMBURGER OPTION
            _isSidebarOpen = false;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? GlassTheme.primaryViolet.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: GlassTheme.primaryViolet.withOpacity(0.6))
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? GlassTheme.primaryCyan : GlassTheme.textMedium,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : GlassTheme.textMedium,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null) ...[
                GlassBadge(
                  label: badge,
                  color: badgeColor ?? (isSelected ? GlassTheme.primaryCyan : GlassTheme.primaryViolet),
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
