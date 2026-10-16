import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database/database_service.dart';
import '../../core/models/menu_item_model.dart';
import '../subscription/screens/subscription_screen.dart';
import 'models/raw_material_model.dart';
import 'models/recipe_model.dart';
import 'models/inventory_movement_model.dart';
import 'services/restaurant_inventory_service.dart';

class InventoryScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const InventoryScreen({super.key, this.onBack});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final DatabaseService _db = DatabaseService();
  final RestaurantInventoryService _inventoryService = RestaurantInventoryService();

  // Neumorphic Design System Palette
  static const Color _primaryNavy = Color(0xFF082559);
  static const Color _neumorphicBase = Color(0xFFEFF2F7);
  static const Color _neumorphicCard = Color(0xFFFFFFFF);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);
  static const Color _greenAccent = Color(0xFF16A34A);
  static const Color _amberAccent = Color(0xFFD97706);
  static const Color _redAccent = Color(0xFFDC2626);
  static const Color _blueAccent = Color(0xFF0284C7);

  // Tabs: 0 = Overview, 1 = Raw Materials, 2 = Recipes, 3 = Operations, 4 = Reports
  int _selectedTabIndex = 0;
  int _operationSubTab = 0; // 0 = Stock In, 1 = Stock Out, 2 = Physical Count, 3 = Opening Stock
  int _reportSubTab = 0; // 0 = Stock Report, 1 = Movement Ledger, 2 = Food Cost Analytics

  bool _isLoading = false;
  bool _isActionLoading = false;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedStockStatus = 'All'; // All, In Stock, Low Stock, Out of Stock
  String _selectedMode = 'All'; // All, Automatic, Manual

  // Dynamic backend state
  List<RawMaterialModel> _rawMaterials = [];
  List<RecipeModel> _recipes = [];
  List<InventoryMovementModel> _movementsLedger = [];
  Map<String, dynamic>? _dashboardSummary;
  Map<String, dynamic>? _stockReportData;
  List<Map<String, dynamic>> _productAnalyticsData = [];

  // In-memory cache across screen visits for instant loading
  static Map<String, dynamic>? _cachedSummary;
  static List<RawMaterialModel>? _cachedMaterials;
  static List<RecipeModel>? _cachedRecipes;
  static List<InventoryMovementModel>? _cachedMovements;
  static Map<String, dynamic>? _cachedStockReport;
  static List<Map<String, dynamic>>? _cachedAnalytics;

  @override
  void initState() {
    super.initState();
    _db.addListener(_onDbChange);
    // Restore from cache if available for instant render
    if (_cachedMaterials != null) _rawMaterials = _cachedMaterials!;
    if (_cachedRecipes != null) _recipes = _cachedRecipes!;
    if (_cachedSummary != null) _dashboardSummary = _cachedSummary;
    if (_cachedMovements != null) _movementsLedger = _cachedMovements!;
    if (_cachedStockReport != null) _stockReportData = _cachedStockReport;
    if (_cachedAnalytics != null) _productAnalyticsData = _cachedAnalytics!;

    _loadData();
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChange);
    super.dispose();
  }

  void _onDbChange() {
    if (mounted) setState(() {});
  }

  void _openSubscription() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SubscriptionScreen(sourceFeature: 'inventory'),
      ),
    );
  }

  /// High-performance progressive data load with instant rendering and background synchronization
  Future<void> _loadData() async {
    if (!mounted) return;
    final bool hasCached = _rawMaterials.isNotEmpty || _dashboardSummary != null;
    if (!hasCached) {
      setState(() => _isLoading = true);
    }

    try {
      // 1. Fast Primary Fetch: Summary, Materials, and Recipes
      final primary = await Future.wait([
        _inventoryService.fetchDashboardSummary(),
        _inventoryService.fetchRawMaterials(),
        _inventoryService.fetchRecipes(),
      ]);

      if (mounted) {
        setState(() {
          if (primary[0] != null) {
            _dashboardSummary = primary[0] as Map<String, dynamic>;
            _cachedSummary = _dashboardSummary;
          }
          final materials = primary[1] as List<RawMaterialModel>;
          _rawMaterials = materials;
          _cachedMaterials = materials;

          final recipes = primary[2] as List<RecipeModel>;
          _recipes = recipes;
          _cachedRecipes = recipes;

          _isLoading = false;
        });
      }

      // 2. Secondary Non-blocking Background Fetch: Ledger, Stock Report, Analytics
      Future.wait([
        _inventoryService.fetchMovementsLedger(),
        _inventoryService.fetchStockReport(),
        _inventoryService.fetchProductAnalytics(),
      ]).then((secondary) {
        if (!mounted) return;
        setState(() {
          final movements = secondary[0] as List<InventoryMovementModel>;
          _movementsLedger = movements;
          _cachedMovements = movements;

          if (secondary[1] != null) {
            _stockReportData = secondary[1] as Map<String, dynamic>;
            _cachedStockReport = _stockReportData;
          }

          final analytics = secondary[2] as List<Map<String, dynamic>>;
          _productAnalyticsData = analytics;
          _cachedAnalytics = analytics;
        });
      }).catchError((err) {
        debugPrint('[InventoryScreen._loadData] Secondary sync notice: $err');
      });
    } catch (e) {
      debugPrint('[InventoryScreen._loadData] Primary API Sync error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _dynamicCategories {
    final catSet = <String>{'All', 'Dairy', 'Vegetables', 'Meat & Poultry', 'Spices', 'Grains & Flour', 'Bakery', 'Beverages', 'Packaging', 'Essentials'};
    for (final m in _rawMaterials) {
      if (m.category.isNotEmpty) catSet.add(m.category);
    }
    return catSet.toList();
  }

  // ===========================================================================
  // NEUMORPHIC DECORATION HELPERS
  // ===========================================================================

  BoxDecoration _neumorphicCardDecoration({
    Color? color,
    double radius = 14,
    Border? border,
  }) {
    return BoxDecoration(
      color: color ?? _neumorphicCard,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? Border.all(color: _borderColor.withValues(alpha: 0.7)),
      boxShadow: const [
        BoxShadow(
          color: Colors.white,
          offset: Offset(-2.5, -2.5),
          blurRadius: 5,
        ),
        BoxShadow(
          color: Color(0x120F172A),
          offset: Offset(3, 3),
          blurRadius: 6,
        ),
      ],
    );
  }


  // ===========================================================================
  // NEUMORPHIC BUTTON & FILTER HELPERS
  // ===========================================================================

  Widget _buildNeumorphicButton({
    required VoidCallback? onPressed,
    required String label,
    IconData? icon,
    Color backgroundColor = _primaryNavy,
    Color textColor = Colors.white,
    double fontSize = 10.5,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    double radius = 8,
    bool isSecondary = false,
  }) {
    final bool isEnabled = onPressed != null;

    if (isSecondary) {
      return InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _neumorphicBase,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.white,
                offset: Offset(-2, -2),
                blurRadius: 4,
              ),
              BoxShadow(
                color: Color(0x14000000),
                offset: Offset(2, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 2.5, color: _textMuted),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(radius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: padding,
        decoration: BoxDecoration(
          color: isEnabled ? backgroundColor : backgroundColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
          boxShadow: [
            if (isEnabled) ...[
              BoxShadow(
                color: backgroundColor.withValues(alpha: 0.35),
                offset: const Offset(0, 3),
                blurRadius: 6,
              ),
              const BoxShadow(
                color: Colors.white24,
                offset: Offset(-1, -1),
                blurRadius: 2,
              ),
            ],
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: fontSize + 2.5, color: textColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeumorphicFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color activeColor = _primaryNavy,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.35),
                  offset: const Offset(0, 2),
                  blurRadius: 5,
                )
              else ...[
                const BoxShadow(
                  color: Colors.white,
                  offset: Offset(-1, -1),
                  blurRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  offset: const Offset(1, 1.5),
                  blurRadius: 3,
                ),
              ],
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
              color: isSelected ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // UI BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _neumorphicBase,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavigationTabBar(),
            Expanded(
              child: _isLoading && _rawMaterials.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: _primaryNavy),
                    )
                  : _buildSelectedTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. SEGMENTED NEUMORPHIC NAVIGATION TABS
  // ===========================================================================

  Widget _buildNavigationTabBar() {
    final tabs = [
      {'label': 'Overview', 'icon': Icons.dashboard_outlined},
      {'label': 'Raw Materials', 'icon': Icons.inventory_2_outlined},
      {'label': 'Recipes', 'icon': Icons.menu_book_outlined},
      {'label': 'Stock Operations', 'icon': Icons.swap_horiz_rounded},
      {'label': 'Reports', 'icon': Icons.analytics_outlined},
    ];

    return Container(
      color: _neumorphicBase,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(tabs.length, (index) {
                  final isSelected = _selectedTabIndex == index;
                  final tab = tabs[index];

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => setState(() => _selectedTabIndex = index),
                      borderRadius: BorderRadius.circular(9),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? _primaryNavy : Colors.white,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: isSelected ? _primaryNavy : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: _primaryNavy.withValues(alpha: 0.35),
                                offset: const Offset(0, 2),
                                blurRadius: 5,
                              )
                            else
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                offset: const Offset(0, 1.5),
                                blurRadius: 3,
                              ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tab['icon'] as IconData,
                              size: 15,
                              color: isSelected ? Colors.white : const Color(0xFF334155),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tab['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                color: isSelected ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: _openSubscription,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: _neumorphicCardDecoration(radius: 9),
              child: const Icon(Icons.workspace_premium_rounded, size: 14, color: Color(0xFFFBBF24)),
            ),
          ),
          const SizedBox(width: 5),
          InkWell(
            onTap: _loadData,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: _neumorphicCardDecoration(radius: 9),
              child: _isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _primaryNavy),
                    )
                  : const Icon(Icons.sync_rounded, size: 14, color: _primaryNavy),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB ROUTER
  // ===========================================================================

  Widget _buildSelectedTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildRawMaterialsTab();
      case 2:
        return _buildRecipesTab();
      case 3:
        return _buildStockOperationsTab();
      case 4:
        return _buildReportsTab();
      default:
        return _buildOverviewTab();
    }
  }

  // ===========================================================================
  // TAB 0: OVERVIEW DASHBOARD (COMPACT & DEFENSIVELY WRAPPED)
  // ===========================================================================

  Widget _buildOverviewTab() {
    final double totalValuation = _dashboardSummary?['totalInventoryValue'] != null
        ? (_dashboardSummary!['totalInventoryValue'] as num).toDouble()
        : _rawMaterials.fold(0.0, (sum, m) => sum + m.valuation);
    final int lowStockCount = _dashboardSummary?['lowStockCount'] ?? _rawMaterials.where((m) => m.isLowStock).length;
    final int outOfStockCount = _dashboardSummary?['outOfStockCount'] ?? _rawMaterials.where((m) => m.isOutOfStock).length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Responsive KPI Cards (2 boxes in one row on mobile & tablet)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    // Always 2 boxes in one row on mobile/tablets; 3 boxes on large desktop
                    final int cols = width > 750 ? 3 : 2;
                    final double cardWidth = (width - ((cols - 1) * 8)) / cols;

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildKpiCard(
                          title: 'Stock Valuation',
                          value: '₹${totalValuation.toStringAsFixed(2)}',
                          subtitle: '${_rawMaterials.length} materials on hand',
                          icon: Icons.account_balance_wallet_rounded,
                          iconColor: const Color(0xFF2563EB),
                          width: cardWidth,
                        ),
                        _buildKpiCard(
                          title: 'Low Stock Alert',
                          value: '$lowStockCount Items',
                          subtitle: 'Below reorder point',
                          icon: Icons.warning_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          width: cardWidth,
                          isWarning: lowStockCount > 0,
                        ),
                        _buildKpiCard(
                          title: 'Out of Stock',
                          value: '$outOfStockCount Items',
                          subtitle: 'Needs immediate restock',
                          icon: Icons.remove_shopping_cart_rounded,
                          iconColor: const Color(0xFFEF4444),
                          width: cardWidth,
                          isDanger: outOfStockCount > 0,
                        ),
                        _buildKpiCard(
                          title: "Today's Stock-In",
                          value: '₹${(_dashboardSummary?['todayStockInValue'] ?? 0).toString()}',
                          subtitle: 'Goods purchases received',
                          icon: Icons.local_shipping_rounded,
                          iconColor: const Color(0xFF10B981),
                          width: cardWidth,
                        ),
                        _buildKpiCard(
                          title: "Today's Consumption",
                          value: '₹${(_dashboardSummary?['todayStockOutValue'] ?? 0).toString()}',
                          subtitle: 'Kitchen cooking & sales',
                          icon: Icons.soup_kitchen_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          width: cardWidth,
                        ),
                        _buildKpiCard(
                          title: 'Active Recipes',
                          value: '${_recipes.length} Recipes',
                          subtitle: 'Menu auto-deductions',
                          icon: Icons.menu_book_rounded,
                          iconColor: _primaryNavy,
                          width: cardWidth,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Quick Action Bar
                _buildQuickActionsBar(),
                const SizedBox(height: 12),

                // Low Stock Warning Banner (if any)
                if (lowStockCount > 0 || outOfStockCount > 0) ...[
                  _buildAttentionBanner(),
                  const SizedBox(height: 12),
                ],

                // Split sections: Responsive row on desktop, stack on mobile
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 720) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTopConsumedSection()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildRecentTransactionsSection()),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        _buildTopConsumedSection(),
                        const SizedBox(height: 12),
                        _buildRecentTransactionsSection(),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required double width,
    bool isWarning = false,
    bool isDanger = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8.5),
      decoration: _neumorphicCardDecoration(
        border: Border.all(
          color: isDanger
              ? _redAccent.withValues(alpha: 0.45)
              : isWarning
                  ? _amberAccent.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.8),
          width: isDanger || isWarning ? 1.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9.8,
                    fontWeight: FontWeight.w700,
                    color: _textMuted,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDanger ? _redAccent : isWarning ? _amberAccent : _textDark,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 8.8, color: _textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsBar() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _neumorphicCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚡ Quick Operations',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textDark),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildActionButton(
                  icon: Icons.add_circle_outline_rounded,
                  label: '+ Add Material',
                  color: _blueAccent,
                  onTap: () => _showAddMaterialDialog(),
                ),
                const SizedBox(width: 6),
                _buildActionButton(
                  icon: Icons.archive_outlined,
                  label: '+ Stock In (Purchase)',
                  color: _greenAccent,
                  onTap: () => _showStockInDialog(),
                ),
                const SizedBox(width: 6),
                _buildActionButton(
                  icon: Icons.unarchive_outlined,
                  label: '− Stock Out (Kitchen/Wastage)',
                  color: _redAccent,
                  onTap: () => _showStockOutDialog(),
                ),
                const SizedBox(width: 6),
                _buildActionButton(
                  icon: Icons.restaurant_menu_rounded,
                  label: '🍳 Create Recipe',
                  color: _primaryNavy,
                  onTap: () => _showCreateRecipeDialog(),
                ),
                const SizedBox(width: 6),
                _buildActionButton(
                  icon: Icons.fact_check_outlined,
                  label: '⚖️ Physical Count',
                  color: _amberAccent,
                  onTap: () => _showPhysicalCountDialog(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _neumorphicBase,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.white, width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.white,
                offset: Offset(-2, -2),
                blurRadius: 4,
              ),
              BoxShadow(
                color: Color(0x14000000),
                offset: Offset(2, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 12.5),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _textDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttentionBanner() {
    final lowStock = _rawMaterials.where((m) => m.isLowStock || m.isOutOfStock).toList();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Attention Needed: ${lowStock.length} items low or out of stock!',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF991B1B)),
                ),
                const SizedBox(height: 1.5),
                Text(
                  lowStock.take(4).map((m) => '${m.name} (${m.formattedStock})').join(' • '),
                  style: const TextStyle(fontSize: 9.5, color: Color(0xFFB91C1C)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _buildNeumorphicButton(
            onPressed: () => _showStockInDialog(),
            label: 'Restock Now',
            backgroundColor: _redAccent,
            fontSize: 10,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
        ],
      ),
    );
  }

  Widget _buildTopConsumedSection() {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: _neumorphicCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '🔥 Top Consumed Ingredients',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('Live Deductions', style: TextStyle(fontSize: 9.5, color: _textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          if (_rawMaterials.isEmpty)
            const Text('No ingredients recorded yet', style: TextStyle(fontSize: 10, color: _textMuted))
          else
            Column(
              children: _rawMaterials.take(4).map((m) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.kitchen_rounded, size: 12, color: _primaryNavy),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              m.name,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Stock: ${m.formattedStock}',
                              style: const TextStyle(fontSize: 9.5, color: _textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '₹${m.valuation.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _primaryNavy),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsSection() {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: _neumorphicCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '📜 Recent Transactions',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text('Audit Ledger', style: TextStyle(fontSize: 9.5, color: _textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          if (_movementsLedger.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text('No movements recorded today', style: TextStyle(fontSize: 10, color: _textMuted)),
              ),
            )
          else
            Column(
              children: _movementsLedger.take(4).map((mov) {
                final isAdd = mov.isAddition;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isAdd ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          isAdd ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          size: 12,
                          color: isAdd ? _greenAccent : _redAccent,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              mov.materialName,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textDark),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              mov.typeLabel,
                              style: const TextStyle(fontSize: 9.5, color: _textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isAdd ? '+' : ''}${mov.quantityDeltaBaseUnits.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isAdd ? _greenAccent : _redAccent,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: RAW MATERIALS (COMPACT & FULLY WRAPPED)
  // ===========================================================================

  Widget _buildRawMaterialsTab() {
    final filtered = _rawMaterials.where((m) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!m.name.toLowerCase().contains(q) && !m.sku.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_selectedCategory != 'All' && m.category != _selectedCategory) {
        return false;
      }
      if (_selectedMode != 'All' && m.inventoryMode.toLowerCase() != _selectedMode.toLowerCase()) {
        return false;
      }
      if (_selectedStockStatus == 'Low Stock' && !m.isLowStock) return false;
      if (_selectedStockStatus == 'Out of Stock' && !m.isOutOfStock) return false;
      if (_selectedStockStatus == 'In Stock' && (m.isLowStock || m.isOutOfStock)) return false;
      return true;
    }).toList();

    return Column(
      children: [
        // Filter & Search Header
        Container(
          color: _neumorphicBase,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _borderColor),
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(fontSize: 11.5, color: _textDark),
                        decoration: const InputDecoration(
                          hintText: 'Search raw materials by name or SKU...',
                          hintStyle: TextStyle(fontSize: 11, color: _textMuted),
                          prefixIcon: Icon(Icons.search_rounded, size: 16, color: _textMuted),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildNeumorphicButton(
                    onPressed: () => _showAddMaterialDialog(),
                    icon: Icons.add_rounded,
                    label: 'Add Material',
                    backgroundColor: _primaryNavy,
                    fontSize: 10.5,
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7.5),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              // Category filter pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _dynamicCategories.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return _buildNeumorphicFilterPill(
                      label: cat,
                      isSelected: isSel,
                      onTap: () => setState(() => _selectedCategory = cat),
                      activeColor: _primaryNavy,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 5),
              // Stock status and mode filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    ...['All', 'In Stock', 'Low Stock', 'Out of Stock'].map((status) {
                      final isSel = _selectedStockStatus == status;
                      return _buildNeumorphicFilterPill(
                        label: status,
                        isSelected: isSel,
                        onTap: () => setState(() => _selectedStockStatus = status),
                        activeColor: _blueAccent,
                      );
                    }),
                    const SizedBox(width: 6),
                    ...['All', 'Automatic', 'Manual'].map((mode) {
                      final isSel = _selectedMode == mode;
                      return _buildNeumorphicFilterPill(
                        label: mode == 'All' ? 'All Modes' : 'Mode: $mode',
                        isSelected: isSel,
                        onTap: () => setState(() => _selectedMode = mode),
                        activeColor: _primaryNavy,
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Material Cards List
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No raw materials found matching filters', style: TextStyle(fontSize: 11, color: _textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final material = filtered[idx];
                    return _buildMaterialCard(material);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMaterialCard(RawMaterialModel material) {
    final isLow = material.isLowStock;
    final isOut = material.isOutOfStock;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: _neumorphicCardDecoration(
        border: Border.all(
          color: isOut
              ? _redAccent.withValues(alpha: 0.5)
              : isLow
                  ? _amberAccent.withValues(alpha: 0.5)
                  : _borderColor.withValues(alpha: 0.7),
          width: isOut || isLow ? 1.3 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  material.sku,
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _primaryNavy),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  material.name,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: material.inventoryMode == 'automatic'
                      ? _blueAccent.withValues(alpha: 0.1)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  material.inventoryMode == 'automatic' ? 'Mode A: Auto' : 'Mode B: Manual',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: material.inventoryMode == 'automatic' ? _blueAccent : _textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Wrapped Stats Grid (Guaranteed no RenderFlex overflows on mobile)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 440;
              if (isNarrow) {
                return Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _buildStatCol('Current Stock', material.formattedStock, isOut ? _redAccent : isLow ? _amberAccent : _textDark),
                    _buildStatCol('Min Alert', material.formattedMinStock, _textDark),
                    _buildStatCol('Avg Cost', '₹${material.averageUnitCost.toStringAsFixed(0)} / ${material.purchaseUnit}', _textDark),
                    _buildStatCol('Valuation', '₹${material.valuation.toStringAsFixed(2)}', _primaryNavy, isBold: true),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatCol('Current Stock', material.formattedStock, isOut ? _redAccent : isLow ? _amberAccent : _textDark),
                  _buildStatCol('Min Alert', material.formattedMinStock, _textDark),
                  _buildStatCol('Avg Cost', '₹${material.averageUnitCost.toStringAsFixed(0)} / ${material.purchaseUnit}', _textDark),
                  _buildStatCol('Valuation', '₹${material.valuation.toStringAsFixed(2)}', _primaryNavy, isBold: true),
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          // Action row
          Row(
            children: [
              if (material.preferredSupplier.isNotEmpty)
                Expanded(
                  child: Text(
                    'Supplier: ${material.preferredSupplier}',
                    style: const TextStyle(fontSize: 9.5, color: _textMuted, fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              _buildNeumorphicButton(
                onPressed: () => _showMaterialLedgerDialog(material),
                icon: Icons.history_rounded,
                label: 'Ledger',
                fontSize: 9.8,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
                isSecondary: true,
              ),
              const SizedBox(width: 5),
              _buildNeumorphicButton(
                onPressed: () => _showAddMaterialDialog(editingMaterial: material),
                icon: Icons.edit_outlined,
                label: 'Edit',
                fontSize: 9.8,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
                isSecondary: true,
              ),
              const SizedBox(width: 5),
              _buildNeumorphicButton(
                onPressed: () => _showStockInDialog(preselectedMaterial: material),
                icon: Icons.add_shopping_cart_rounded,
                label: 'Restock',
                backgroundColor: _primaryNavy,
                fontSize: 9.8,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value, Color valueColor, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: valueColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: RECIPES (COMPACT & FULLY WRAPPED)
  // ===========================================================================

  Widget _buildRecipesTab() {
    return Column(
      children: [
        Container(
          color: _neumorphicBase,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '🍳 Recipe Management & Costing',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildNeumorphicButton(
                onPressed: () => _showCreateRecipeDialog(),
                icon: Icons.add_rounded,
                label: 'Create Recipe',
                backgroundColor: _primaryNavy,
                fontSize: 10.5,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7.5),
              ),
            ],
          ),
        ),
        Expanded(
          child: _recipes.isEmpty
              ? const Center(
                  child: Text('No recipes created yet. Click "+ Create Recipe" to connect menu items to raw materials.',
                      style: TextStyle(fontSize: 11, color: _textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  itemCount: _recipes.length,
                  itemBuilder: (context, idx) {
                    final recipe = _recipes[idx];
                    return _buildRecipeCard(recipe);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecipeCard(RecipeModel recipe) {
    final foodCostPct = recipe.foodCostPercentage;
    final isHealthy = foodCostPct <= 30.0;
    final isModerate = foodCostPct > 30.0 && foodCostPct <= 40.0;

    final badgeColor = isHealthy ? _greenAccent : isModerate ? _amberAccent : _redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: _neumorphicCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recipe.productName,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _textDark),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      recipe.recipeName.isNotEmpty ? recipe.recipeName : 'Standard Recipe',
                      style: const TextStyle(fontSize: 10, color: _textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 11, color: badgeColor),
                    const SizedBox(width: 3),
                    Text(
                      '${foodCostPct.toStringAsFixed(1)}% Food Cost',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Wrapped Stats Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 440;
              if (isNarrow) {
                return Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _buildStatCol('Food Cost', '₹${recipe.totalFoodCost.toStringAsFixed(2)}', _textDark),
                    _buildStatCol('Selling Price', '₹${recipe.sellingPrice.toStringAsFixed(2)}', _primaryNavy, isBold: true),
                    _buildStatCol('Gross Profit', '₹${recipe.grossMargin.toStringAsFixed(2)} (${recipe.marginPercentage.toStringAsFixed(0)}%)', _greenAccent),
                    _buildStatCol('Portion', '${recipe.servingSize.toStringAsFixed(0)} serving', _textDark),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatCol('Food Cost', '₹${recipe.totalFoodCost.toStringAsFixed(2)}', _textDark),
                  _buildStatCol('Selling Price', '₹${recipe.sellingPrice.toStringAsFixed(2)}', _primaryNavy, isBold: true),
                  _buildStatCol('Gross Profit', '₹${recipe.grossMargin.toStringAsFixed(2)} (${recipe.marginPercentage.toStringAsFixed(0)}%)', _greenAccent),
                  _buildStatCol('Portion', '${recipe.servingSize.toStringAsFixed(0)} serving', _textDark),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          const Text('Ingredients in Recipe:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _textDark)),
          const SizedBox(height: 3),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: recipe.ingredients.map((ing) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${ing.materialName}: ${ing.quantity}${ing.unit}',
                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 3: STOCK OPERATIONS (COMPACT & FULLY WRAPPED)
  // ===========================================================================

  Widget _buildStockOperationsTab() {
    final subTabs = ['Stock In (Purchase)', 'Stock Out (Wastage)', 'Physical Count (Audit)', 'Opening Stock'];

    return Column(
      children: [
        Container(
          color: _neumorphicBase,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: List.generate(subTabs.length, (idx) {
                final isSel = _operationSubTab == idx;
                return _buildNeumorphicFilterPill(
                  label: subTabs[idx],
                  isSelected: isSel,
                  onTap: () => setState(() => _operationSubTab = idx),
                  activeColor: _primaryNavy,
                );
              }),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _buildOperationSubContent(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOperationSubContent() {
    switch (_operationSubTab) {
      case 0:
        return _buildOperationCard(
          title: 'Receive Stock / Record Purchase Invoice',
          subtitle: 'Records incoming stock from suppliers and calculates weighted average cost automatically.',
          icon: Icons.archive_outlined,
          iconColor: _greenAccent,
          btnLabel: 'Open Stock-In Entry Form',
          btnColor: _greenAccent,
          onTap: () => _showStockInDialog(),
        );
      case 1:
        return _buildOperationCard(
          title: 'Record Stock Out / Wastage / Kitchen Issue',
          subtitle: 'Record kitchen consumption, spoilage, breakage, or staff meals with categorized reasons.',
          icon: Icons.unarchive_outlined,
          iconColor: _redAccent,
          btnLabel: 'Open Stock-Out Entry Form',
          btnColor: _redAccent,
          onTap: () => _showStockOutDialog(),
        );
      case 2:
        return _buildOperationCard(
          title: 'Physical Stock Count & Variance Reconciliation',
          subtitle: 'Perform periodic inventory audits to compare physical shelf stock against system counts.',
          icon: Icons.fact_check_outlined,
          iconColor: _amberAccent,
          btnLabel: 'Start Physical Count Audit',
          btnColor: _amberAccent,
          onTap: () => _showPhysicalCountDialog(),
        );
      case 3:
        return _buildOperationCard(
          title: 'Initialize Opening Stock',
          subtitle: 'Rapidly configure initial on-hand stock for all raw materials when setting up Apna POS.',
          icon: Icons.start_rounded,
          iconColor: _primaryNavy,
          btnLabel: 'Enter Opening Stock',
          btnColor: _primaryNavy,
          onTap: () => _showOpeningStockDialog(),
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildOperationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String btnLabel,
    required Color btnColor,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _neumorphicCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _textDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10.5, color: _textMuted),
          ),
          const SizedBox(height: 14),
          Center(
            child: _buildNeumorphicButton(
              onPressed: onTap,
              icon: icon,
              label: btnLabel,
              backgroundColor: btnColor,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              fontSize: 11,
              radius: 9,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 4: REPORTS & ANALYTICS (COMPACT & FULLY WRAPPED)
  // ===========================================================================

  Widget _buildReportsTab() {
    final subReports = ['Stock Valuation Report', 'Stock Movement Ledger', 'Product & Food Cost Analytics'];

    return Column(
      children: [
        Container(
          color: _neumorphicBase,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: List.generate(subReports.length, (idx) {
                      final isSel = _reportSubTab == idx;
                      return _buildNeumorphicFilterPill(
                        label: subReports[idx],
                        isSelected: isSel,
                        onTap: () => setState(() => _reportSubTab = idx),
                        activeColor: _primaryNavy,
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildDownloadExcelButton(
                onTap: _exportInventoryReportToExcel,
                label: 'Export Excel',
              ),
            ],
          ),
        ),
        Expanded(
          child: _reportSubTab == 0
              ? _buildStockValuationReport()
              : _reportSubTab == 1
                  ? _buildMovementsLedgerReport()
                  : _buildFoodCostAnalyticsReport(),
        ),
      ],
    );
  }

  Widget _buildStockValuationReport() {
    final double totalValuation = _stockReportData?['totalValuation'] != null
        ? (_stockReportData!['totalValuation'] as num).toDouble()
        : _rawMaterials.fold(0.0, (sum, m) => sum + m.valuation);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _primaryNavy,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryNavy.withValues(alpha: 0.3),
                      offset: const Offset(0, 3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Inventory Asset Valuation',
                            style: TextStyle(color: Color(0xFF93C5FD), fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${totalValuation.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    _buildDownloadExcelButton(
                      onTap: _exportInventoryReportToExcel,
                      label: 'Download Excel',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ..._rawMaterials.map((m) {
                final isLow = m.isLowStock;
                final isOut = m.isOutOfStock;
                final statusColor = isOut ? _redAccent : isLow ? _amberAccent : _greenAccent;
                final statusText = isOut ? 'Out of Stock' : isLow ? 'Low Stock' : 'In Stock';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: _neumorphicCardDecoration(
                    border: Border.all(
                      color: isOut
                          ? _redAccent.withValues(alpha: 0.4)
                          : isLow
                              ? _amberAccent.withValues(alpha: 0.4)
                              : const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  m.name,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _textDark),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: statusColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'SKU: ${m.sku} • Category: ${m.category} • Cost: ₹${m.averageUnitCost.toStringAsFixed(0)}/${m.purchaseUnit}',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            m.formattedStock,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: statusColor),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${m.valuation.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: _primaryNavy),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMovementsLedgerReport() {
    return _movementsLedger.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.history_rounded, size: 40, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                const Text('No stock movements recorded yet.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                const SizedBox(height: 12),
                _buildDownloadExcelButton(
                  onTap: _exportInventoryReportToExcel,
                  label: 'Download Empty Template',
                ),
              ],
            ),
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Stock Movement Audit (${_movementsLedger.length} Records)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _textDark),
                    ),
                    _buildDownloadExcelButton(
                      onTap: _exportInventoryReportToExcel,
                      label: 'Download Excel',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: _movementsLedger.length,
                  itemBuilder: (context, idx) {
                    final mov = _movementsLedger[idx];
                    final isAdd = mov.isAddition;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.all(11),
                      decoration: _neumorphicCardDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: isAdd ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isAdd ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              color: isAdd ? _greenAccent : _redAccent,
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mov.materialName,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _textDark),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${mov.typeLabel} • ${mov.reason} • ${DateFormat('dd MMM, HH:mm').format(mov.timestamp)}',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isAdd ? '+' : ''}${mov.quantityDeltaBaseUnits.toStringAsFixed(0)} ${mov.baseUnit}',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: isAdd ? _greenAccent : _redAccent),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Bal: ${mov.balanceAfterBaseUnits.toStringAsFixed(0)} ${mov.baseUnit}',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
  }

  Widget _buildFoodCostAnalyticsReport() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menu Item Profitability & Food Cost Health',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _textDark),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Benchmark: <=30% Optimal, 31-40% Moderate, >40% High Cost.',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildDownloadExcelButton(
                    onTap: _exportInventoryReportToExcel,
                    label: 'Download Excel',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._recipes.map((r) {
                final isHealthy = r.foodCostPercentage <= 30;
                final badgeColor = isHealthy ? _greenAccent : r.foodCostPercentage <= 40 ? _amberAccent : _redAccent;
                final badgeLabel = isHealthy ? 'Optimal' : r.foodCostPercentage <= 40 ? 'Moderate' : 'High Cost';

                return Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.all(12),
                  decoration: _neumorphicCardDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.productName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 3),
                            Text(
                              'Selling Price: ₹${r.sellingPrice.toStringAsFixed(0)} | Food Cost: ₹${r.totalFoodCost.toStringAsFixed(1)} | Margin: ₹${r.grossMargin.toStringAsFixed(1)} (${r.marginPercentage.toStringAsFixed(0)}%)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '${r.foodCostPercentage.toStringAsFixed(1)}%',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: badgeColor),
                            ),
                            Text(
                              badgeLabel,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: badgeColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (_productAnalyticsData.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Backend Dynamic Margin Analytics',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _textDark),
                ),
                const SizedBox(height: 6),
                ..._productAnalyticsData.map((item) {
                  final name = item['productName']?.toString() ?? 'Item';
                  final sp = (item['sellingPrice'] as num?)?.toDouble() ?? 0.0;
                  final fc = (item['foodCost'] as num?)?.toDouble() ?? 0.0;
                  final fcp = (item['foodCostPercentage'] as num?)?.toDouble() ?? 0.0;
                  final badgeColor = fcp <= 30 ? _greenAccent : fcp <= 40 ? _amberAccent : _redAccent;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$name (SP: ₹$sp | Cost: ₹${fc.toStringAsFixed(1)})',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _textDark),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${fcp.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: badgeColor),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // INTERACTIVE NEUMORPHIC DIALOGS / POPUPS (FULLY WRAPPED & ZERO OVERFLOW)
  // ===========================================================================

  /// Add / Edit Raw Material Dialog
  void _showAddMaterialDialog({RawMaterialModel? editingMaterial}) {
    final nameCtrl = TextEditingController(text: editingMaterial?.name ?? '');
    final skuCtrl = TextEditingController(text: editingMaterial?.sku ?? '');
    final currentStockCtrl = TextEditingController(text: editingMaterial != null ? editingMaterial.currentStock.toString() : '0');
    final minStockCtrl = TextEditingController(text: editingMaterial != null ? editingMaterial.minimumStock.toString() : '1000');
    final costCtrl = TextEditingController(text: editingMaterial != null ? editingMaterial.averageUnitCost.toString() : '100');
    final supplierCtrl = TextEditingController(text: editingMaterial?.preferredSupplier ?? '');
    final conversionCtrl = TextEditingController(text: editingMaterial != null ? editingMaterial.conversionFactor.toString() : '1000');

    String baseUnit = editingMaterial?.baseUnit ?? 'g';
    String purchaseUnit = editingMaterial?.purchaseUnit ?? 'kg';
    String category = editingMaterial?.category ?? 'Dairy';
    String mode = editingMaterial?.inventoryMode ?? 'automatic';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final screenWidth = MediaQuery.of(ctx).size.width;

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: min(screenWidth * 0.94, 520),
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _primaryNavy.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_rounded, color: _primaryNavy, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            editingMaterial == null ? 'Add Raw Material' : 'Edit ${editingMaterial.name}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 16, color: _textMuted),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const Divider(height: 18),

                    // Scrollable form body (Guaranteed no overflow)
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTextField(label: 'Material Name *', controller: nameCtrl, hint: 'e.g. Fresh Paneer'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: _buildTextField(label: 'SKU (Leave blank to auto-generate)', controller: skuCtrl, hint: 'e.g. RM-0001')),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Category', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                                      const SizedBox(height: 4),
                                      DropdownButtonFormField<String>(
                                        dropdownColor: Colors.white,
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textDark),
                                        icon: const Icon(Icons.arrow_drop_down_rounded, color: _primaryNavy, size: 22),
                                        iconEnabledColor: _primaryNavy,
                                        isExpanded: true,
                                        initialValue: _dynamicCategories.contains(category) ? category : 'Dairy',
                                        items: _dynamicCategories.where((c) => c != 'All').map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark)))).toList(),
                                        onChanged: (v) => setDlgState(() => category = v ?? 'General'),
                                        decoration: _dropdownInputDecoration(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Base Unit (Canonical)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                                      const SizedBox(height: 4),
                                      DropdownButtonFormField<String>(
                                        dropdownColor: Colors.white,
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textDark),
                                        icon: const Icon(Icons.arrow_drop_down_rounded, color: _primaryNavy, size: 22),
                                        iconEnabledColor: _primaryNavy,
                                        isExpanded: true,
                                        initialValue: baseUnit,
                                        items: const [
                                          DropdownMenuItem(value: 'g', child: Text('Gram (g)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark))),
                                          DropdownMenuItem(value: 'ml', child: Text('Millilitre (ml)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark))),
                                          DropdownMenuItem(value: 'pcs', child: Text('Piece (pcs)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark))),
                                        ],
                                        onChanged: (v) {
                                          setDlgState(() {
                                            baseUnit = v ?? 'g';
                                            if (baseUnit == 'g') {
                                              purchaseUnit = 'kg';
                                            } else if (baseUnit == 'ml') {
                                              purchaseUnit = 'L';
                                            } else {
                                              purchaseUnit = 'pcs';
                                            }
                                          });
                                        },
                                        decoration: _dropdownInputDecoration(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Purchase Unit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                                      const SizedBox(height: 4),
                                      DropdownButtonFormField<String>(
                                        dropdownColor: Colors.white,
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textDark),
                                        icon: const Icon(Icons.arrow_drop_down_rounded, color: _primaryNavy, size: 22),
                                        iconEnabledColor: _primaryNavy,
                                        isExpanded: true,
                                        initialValue: purchaseUnit,
                                        items: const [
                                          DropdownMenuItem(value: 'kg', child: Text('Kilogram (kg)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark))),
                                          DropdownMenuItem(value: 'L', child: Text('Litre (L)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark))),
                                          DropdownMenuItem(value: 'pcs', child: Text('Pieces (pcs)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark))),
                                          DropdownMenuItem(value: 'box', child: Text('Box', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark))),
                                          DropdownMenuItem(value: 'bag', child: Text('Bag', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark))),
                                          DropdownMenuItem(value: 'pack', child: Text('Pack', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark))),
                                        ],
                                        onChanged: (v) => setDlgState(() => purchaseUnit = v ?? 'kg'),
                                        decoration: _dropdownInputDecoration(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildTextField(
                              label: 'Conversion Factor (Base Units per Purchase Unit)',
                              controller: conversionCtrl,
                              hint: '1000 for kg->g, 1000 for L->ml',
                              isNumber: true,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (editingMaterial == null) ...[
                                  Expanded(child: _buildTextField(label: 'Opening Stock ($baseUnit)', controller: currentStockCtrl, isNumber: true)),
                                  const SizedBox(width: 8),
                                ],
                                Expanded(child: _buildTextField(label: 'Minimum Alert ($baseUnit)', controller: minStockCtrl, isNumber: true)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: _buildTextField(label: 'Avg Cost (₹ per $purchaseUnit)', controller: costCtrl, isNumber: true)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Inventory Mode', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                                      const SizedBox(height: 4),
                                      DropdownButtonFormField<String>(
                                        dropdownColor: Colors.white,
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textDark),
                                        icon: const Icon(Icons.arrow_drop_down_rounded, color: _primaryNavy, size: 22),
                                        iconEnabledColor: _primaryNavy,
                                        isExpanded: true,
                                        initialValue: mode,
                                        items: const [
                                          DropdownMenuItem(value: 'automatic', child: Text('Mode A: Automatic (POS Deduct)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark))),
                                          DropdownMenuItem(value: 'manual', child: Text('Mode B: Manual (Batch Audit)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark))),
                                        ],
                                        onChanged: (v) => setDlgState(() => mode = v ?? 'automatic'),
                                        decoration: _dropdownInputDecoration(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildTextField(label: 'Preferred Supplier (Optional)', controller: supplierCtrl, hint: 'e.g. Amul Dairy Dist.'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildNeumorphicButton(
                          onPressed: () => Navigator.pop(ctx),
                          label: 'Cancel',
                          isSecondary: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        ),
                        const SizedBox(width: 8),
                        _buildNeumorphicButton(
                          onPressed: _isActionLoading
                              ? null
                              : () async {
                                  final name = nameCtrl.text.trim();
                                  if (name.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter material name')));
                                    return;
                                  }

                                  final conv = double.tryParse(conversionCtrl.text) ?? 1000.0;
                                  final cost = double.tryParse(costCtrl.text) ?? 0.0;
                                  final minStock = double.tryParse(minStockCtrl.text) ?? 0.0;
                                  final curStock = double.tryParse(currentStockCtrl.text) ?? 0.0;

                                  final payload = {
                                    'name': name,
                                    'sku': skuCtrl.text.trim(),
                                    'category': category,
                                    'baseUnit': baseUnit,
                                    'purchaseUnit': purchaseUnit,
                                    'conversionFactor': conv,
                                    'minimumStock': minStock,
                                    'openingStock': curStock,
                                    'currentStock': curStock,
                                    'averageUnitCost': cost,
                                    'preferredSupplier': supplierCtrl.text.trim(),
                                    'inventoryMode': mode,
                                  };

                                  setDlgState(() => _isActionLoading = true);

                                  try {
                                    if (editingMaterial == null) {
                                      await _inventoryService.createRawMaterial(payload);
                                    } else {
                                      await _inventoryService.updateRawMaterial(editingMaterial.id, payload);
                                    }
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    await _loadData();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(editingMaterial == null ? 'Raw material added successfully!' : 'Material updated!'),
                                          backgroundColor: _greenAccent,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    await _loadData();
                                  } finally {
                                    if (mounted) setState(() => _isActionLoading = false);
                                  }
                                },
                          label: editingMaterial != null ? 'Update Material' : 'Save Material',
                          backgroundColor: _primaryNavy,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Create Recipe Dialog (Wrapped & Flexible for mobile & desktop)
  void _showCreateRecipeDialog() {
    MenuItemModel? selectedMenuItem = _db.menuItems.isNotEmpty ? _db.menuItems.first : null;
    final recipeNameCtrl = TextEditingController(text: selectedMenuItem != null ? '${selectedMenuItem.name} Recipe' : '');
    final servingCtrl = TextEditingController(text: '1');

    final List<Map<String, dynamic>> ingredientRows = [];
    if (_rawMaterials.isNotEmpty) {
      ingredientRows.add({
        'material': _rawMaterials.first,
        'quantityCtrl': TextEditingController(text: '100'),
        'unit': _rawMaterials.first.baseUnit,
        'lossCtrl': TextEditingController(text: '0'),
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final screenWidth = MediaQuery.of(ctx).size.width;

          // Live Costing calculation
          double liveFoodCost = 0.0;
          for (final row in ingredientRows) {
            final mat = row['material'] as RawMaterialModel;
            final qty = double.tryParse((row['quantityCtrl'] as TextEditingController).text) ?? 0.0;
            final loss = double.tryParse((row['lossCtrl'] as TextEditingController).text) ?? 0.0;
            final unit = row['unit'] as String;

            double baseUnits = qty;
            if (unit == 'kg' && mat.baseUnit == 'g') {
              baseUnits = qty * 1000;
            } else if (unit == 'L' && mat.baseUnit == 'ml') {
              baseUnits = qty * 1000;
            } else if (unit == mat.purchaseUnit) {
              baseUnits = qty * mat.conversionFactor;
            }

            final effective = baseUnits * (1 + loss / 100);
            liveFoodCost += effective * mat.costPerBaseUnit;
          }

          final double sellingPrice = selectedMenuItem?.salePrice != null && selectedMenuItem!.salePrice! > 0
              ? selectedMenuItem!.salePrice!
              : selectedMenuItem?.price ?? 0.0;
          final double foodCostPct = sellingPrice > 0 ? (liveFoodCost / sellingPrice) * 100 : 0.0;

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: min(screenWidth * 0.94, 540),
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _primaryNavy.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.restaurant_menu_rounded, color: _primaryNavy, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Create Recipe & Live Costing',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 16, color: _textMuted),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const Divider(height: 18),

                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Link POS Menu Item *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<MenuItemModel>(
                              dropdownColor: Colors.white,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textDark),
                              icon: const Icon(Icons.arrow_drop_down_rounded, color: _primaryNavy, size: 22),
                              iconEnabledColor: _primaryNavy,
                              isExpanded: true,
                              initialValue: selectedMenuItem,
                              items: _db.menuItems.map((m) => DropdownMenuItem(
                                value: m,
                                child: Text('${m.name} (₹${m.price})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark)),
                              )).toList(),
                              onChanged: (v) {
                                setDlgState(() {
                                  selectedMenuItem = v;
                                  if (v != null) recipeNameCtrl.text = '${v.name} Recipe';
                                });
                              },
                              decoration: _dropdownInputDecoration(),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: _buildTextField(label: 'Recipe Name', controller: recipeNameCtrl, hint: 'e.g. Standard Recipe')),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 90,
                                  child: _buildTextField(label: 'Servings', controller: servingCtrl, isNumber: true),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Ingredients Required:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _textDark)),
                                _buildNeumorphicButton(
                                  onPressed: () {
                                    setDlgState(() {
                                      if (_rawMaterials.isNotEmpty) {
                                        ingredientRows.add({
                                          'material': _rawMaterials.first,
                                          'quantityCtrl': TextEditingController(text: '50'),
                                          'unit': _rawMaterials.first.baseUnit,
                                          'lossCtrl': TextEditingController(text: '0'),
                                        });
                                      }
                                    });
                                  },
                                  icon: Icons.add_rounded,
                                  label: 'Add Ingredient',
                                  fontSize: 10.5,
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  isSecondary: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Ingredients List
                            ...List.generate(ingredientRows.length, (i) {
                              final row = ingredientRows[i];
                              final mat = row['material'] as RawMaterialModel;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: DropdownButton<RawMaterialModel>(
                                        isExpanded: true,
                                        dropdownColor: Colors.white,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textDark),
                                        icon: const Icon(Icons.arrow_drop_down_rounded, color: _primaryNavy, size: 20),
                                        iconEnabledColor: _primaryNavy,
                                        value: mat,
                                        underline: const SizedBox(),
                                        items: _rawMaterials.map((m) => DropdownMenuItem(
                                          value: m,
                                          child: Text(m.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textDark)),
                                        )).toList(),
                                        onChanged: (v) {
                                          if (v != null) {
                                            setDlgState(() {
                                              row['material'] = v;
                                              row['unit'] = v.baseUnit;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    SizedBox(
                                      width: 65,
                                      child: TextField(
                                        controller: row['quantityCtrl'] as TextEditingController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _textDark),
                                        onChanged: (_) => setDlgState(() {}),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _primaryNavy, width: 1.2)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(mat.baseUnit, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      onPressed: () => setDlgState(() => ingredientRows.removeAt(i)),
                                      icon: const Icon(Icons.delete_outline_rounded, color: _redAccent, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 10),

                            // Live Costing Summary Box
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Recipe Cost', style: TextStyle(fontSize: 9.5, color: _textMuted)),
                                      Text('₹${liveFoodCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _textDark)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Selling Price', style: TextStyle(fontSize: 9.5, color: _textMuted)),
                                      Text('₹${sellingPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _primaryNavy)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Food Cost %', style: TextStyle(fontSize: 9.5, color: _textMuted)),
                                      Text(
                                        '${foodCostPct.toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: foodCostPct <= 30 ? _greenAccent : foodCostPct <= 40 ? _amberAccent : _redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildNeumorphicButton(
                          onPressed: () => Navigator.pop(ctx),
                          label: 'Cancel',
                          isSecondary: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        ),
                        const SizedBox(width: 8),
                        _buildNeumorphicButton(
                          onPressed: () async {
                            if (selectedMenuItem == null) return;
                            if (ingredientRows.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one ingredient')));
                              return;
                            }

                            final payload = {
                              'productId': selectedMenuItem!.id,
                              'productName': selectedMenuItem!.name,
                              'recipeName': recipeNameCtrl.text.trim(),
                              'servingSize': double.tryParse(servingCtrl.text) ?? 1.0,
                              'sellingPrice': sellingPrice,
                              'ingredients': ingredientRows.map((row) {
                                final mat = row['material'] as RawMaterialModel;
                                return {
                                  'materialId': mat.id,
                                  'materialName': mat.name,
                                  'quantity': double.tryParse((row['quantityCtrl'] as TextEditingController).text) ?? 0.0,
                                  'unit': row['unit'],
                                  'preparationLossPercent': double.tryParse((row['lossCtrl'] as TextEditingController).text) ?? 0.0,
                                };
                              }).toList(),
                            };

                            Navigator.pop(ctx);

                            try {
                              await _inventoryService.createRecipe(payload);
                              await _loadData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Recipe created successfully!'), backgroundColor: _greenAccent),
                                );
                              }
                            } catch (e) {
                              await _loadData();
                            }
                          },
                          label: 'Save Recipe',
                          backgroundColor: _primaryNavy,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Stock-In (Purchases) Modal Dialog
  void _showStockInDialog({RawMaterialModel? preselectedMaterial}) {
    RawMaterialModel selectedMat = preselectedMaterial ?? (_rawMaterials.isNotEmpty ? _rawMaterials.first : RawMaterialModel(id: '', sku: '', name: ''));
    final supplierCtrl = TextEditingController(text: selectedMat.preferredSupplier);
    final invoiceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '5');
    final costCtrl = TextEditingController(text: selectedMat.averageUnitCost.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final screenWidth = MediaQuery.of(ctx).size.width;
          final qty = double.tryParse(qtyCtrl.text) ?? 0.0;
          final unitCost = double.tryParse(costCtrl.text) ?? 0.0;
          final totalCost = qty * unitCost;

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: min(screenWidth * 0.94, 460)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: _greenAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.archive_outlined, color: _greenAccent, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Record Stock In (Purchase)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 16, color: _textMuted),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Select Raw Material *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<RawMaterialModel>(
                              dropdownColor: Colors.white,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textDark),
                              icon: const Icon(Icons.arrow_drop_down_rounded, color: _primaryNavy, size: 22),
                              iconEnabledColor: _primaryNavy,
                              isExpanded: true,
                              initialValue: _rawMaterials.firstWhere((m) => m.id == selectedMat.id, orElse: () => _rawMaterials.first),
                              items: _rawMaterials.map((m) => DropdownMenuItem(value: m, child: Text('${m.name} (${m.formattedStock})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark)))).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setDlgState(() {
                                    selectedMat = v;
                                    costCtrl.text = v.averageUnitCost.toString();
                                    supplierCtrl.text = v.preferredSupplier;
                                  });
                                }
                              },
                              decoration: _dropdownInputDecoration(),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: _buildTextField(label: 'Supplier Name', controller: supplierCtrl, hint: 'e.g. Pure Farms')),
                                const SizedBox(width: 8),
                                Expanded(child: _buildTextField(label: 'Invoice #', controller: invoiceCtrl, hint: 'e.g. INV-1002')),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    label: 'Quantity (${selectedMat.purchaseUnit})',
                                    controller: qtyCtrl,
                                    isNumber: true,
                                    onChanged: (_) => setDlgState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildTextField(
                                    label: 'Cost (₹ / ${selectedMat.purchaseUnit})',
                                    controller: costCtrl,
                                    isNumber: true,
                                    onChanged: (_) => setDlgState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total Invoice Amount:', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _textMuted)),
                                  Text('₹${totalCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _greenAccent)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildNeumorphicButton(
                          onPressed: () => Navigator.pop(ctx),
                          label: 'Cancel',
                          isSecondary: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        ),
                        const SizedBox(width: 8),
                        _buildNeumorphicButton(
                          onPressed: () async {
                            if (qty <= 0) return;
                            final payload = {
                              'supplierName': supplierCtrl.text.trim(),
                              'invoiceNumber': invoiceCtrl.text.trim(),
                              'items': [
                                {
                                  'materialId': selectedMat.id,
                                  'purchaseQuantity': qty,
                                  'purchaseUnit': selectedMat.purchaseUnit,
                                  'conversionFactor': selectedMat.conversionFactor,
                                  'unitCost': unitCost,
                                }
                              ],
                            };

                            Navigator.pop(ctx);

                            try {
                              await _inventoryService.recordStockIn(payload);
                              await _loadData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Received $qty ${selectedMat.purchaseUnit} of ${selectedMat.name}'), backgroundColor: _greenAccent),
                                );
                              }
                            } catch (e) {
                              await _loadData();
                            }
                          },
                          label: 'Confirm Stock-In',
                          backgroundColor: _greenAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Stock-Out (Kitchen / Wastage) Dialog
  void _showStockOutDialog() {
    RawMaterialModel selectedMat = _rawMaterials.isNotEmpty ? _rawMaterials.first : RawMaterialModel(id: '', sku: '', name: '');
    final qtyCtrl = TextEditingController(text: '1');
    String reason = 'Kitchen Preparation';

    final reasons = ['Kitchen Preparation', 'Spoilage / Expiry', 'Spillage / Damage', 'Staff Meal', 'Testing / Sampling'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final screenWidth = MediaQuery.of(ctx).size.width;

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: min(screenWidth * 0.94, 440)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: _redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.unarchive_outlined, color: _redAccent, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Record Stock Out / Wastage', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 16, color: _textMuted),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Select Raw Material *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<RawMaterialModel>(
                              dropdownColor: Colors.white,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textDark),
                              icon: const Icon(Icons.arrow_drop_down_rounded, color: _primaryNavy, size: 22),
                              iconEnabledColor: _primaryNavy,
                              isExpanded: true,
                              initialValue: _rawMaterials.firstWhere((m) => m.id == selectedMat.id, orElse: () => _rawMaterials.first),
                              items: _rawMaterials.map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                  '${m.name} (${m.formattedStock})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textDark),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )).toList(),
                              onChanged: (v) {
                                if (v != null) setDlgState(() => selectedMat = v);
                              },
                              decoration: _dropdownInputDecoration(),
                            ),
                            const SizedBox(height: 10),
                            _buildTextField(label: 'Quantity (${selectedMat.purchaseUnit})', controller: qtyCtrl, isNumber: true),
                            const SizedBox(height: 10),
                            const Text('Reason / Category', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              dropdownColor: Colors.white,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textDark),
                              icon: const Icon(Icons.arrow_drop_down_rounded, color: _primaryNavy, size: 22),
                              iconEnabledColor: _primaryNavy,
                              isExpanded: true,
                              initialValue: reason,
                              items: reasons.map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(
                                  r,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textDark),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )).toList(),
                              onChanged: (v) => setDlgState(() => reason = v ?? reasons.first),
                              decoration: _dropdownInputDecoration(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildNeumorphicButton(
                          onPressed: () => Navigator.pop(ctx),
                          label: 'Cancel',
                          isSecondary: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        ),
                        const SizedBox(width: 8),
                        _buildNeumorphicButton(
                          onPressed: () async {
                            final qty = double.tryParse(qtyCtrl.text) ?? 0.0;
                            if (qty <= 0) return;

                            final payload = {
                              'materialId': selectedMat.id,
                              'quantity': qty,
                              'unit': selectedMat.purchaseUnit,
                              'movementType': reason.contains('Spoilage') || reason.contains('Spillage') ? 'wastage' : 'stock_out',
                              'reason': reason,
                            };

                            Navigator.pop(ctx);

                            try {
                              await _inventoryService.recordStockOut(payload);
                              await _loadData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Issued $qty ${selectedMat.purchaseUnit} of ${selectedMat.name}'), backgroundColor: _redAccent),
                                );
                              }
                            } catch (e) {
                              await _loadData();
                            }
                          },
                          label: 'Deduct Stock',
                          backgroundColor: _redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Physical Stock Count (Audit) Dialog
  void _showPhysicalCountDialog() {
    RawMaterialModel selectedMat = _rawMaterials.isNotEmpty ? _rawMaterials.first : RawMaterialModel(id: '', sku: '', name: '');
    final countCtrl = TextEditingController(text: selectedMat.currentStock.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final screenWidth = MediaQuery.of(ctx).size.width;
          final expected = selectedMat.currentStock;
          final actual = double.tryParse(countCtrl.text) ?? expected;
          final variance = actual - expected;

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: min(screenWidth * 0.94, 440)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: _amberAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.fact_check_outlined, color: _amberAccent, size: 16),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Physical Count Reconciliation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 16, color: _textMuted),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Select Material to Audit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<RawMaterialModel>(
                              dropdownColor: Colors.white,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textDark),
                              icon: const Icon(Icons.arrow_drop_down_rounded, color: _primaryNavy, size: 22),
                              iconEnabledColor: _primaryNavy,
                              isExpanded: true,
                              initialValue: _rawMaterials.firstWhere((m) => m.id == selectedMat.id, orElse: () => _rawMaterials.first),
                              items: _rawMaterials.map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                  '${m.name} (${m.formattedStock})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textDark),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setDlgState(() {
                                    selectedMat = v;
                                    countCtrl.text = v.currentStock.toStringAsFixed(0);
                                  });
                                }
                              },
                              decoration: _dropdownInputDecoration(),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('System Expected Stock:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                Text('${expected.toStringAsFixed(0)} ${selectedMat.baseUnit}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _textDark)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildTextField(
                              label: 'Actual Physical Count (${selectedMat.baseUnit})',
                              controller: countCtrl,
                              isNumber: true,
                              onChanged: (_) => setDlgState(() {}),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: variance == 0 ? const Color(0xFFF1F5F9) : variance > 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: variance == 0 ? const Color(0xFFCBD5E1) : variance > 0 ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Audit Variance:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                  Text(
                                    '${variance > 0 ? '+' : ''}${variance.toStringAsFixed(0)} ${selectedMat.baseUnit}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: variance == 0 ? _textMuted : variance > 0 ? _greenAccent : _redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildNeumorphicButton(
                          onPressed: () => Navigator.pop(ctx),
                          label: 'Cancel',
                          isSecondary: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        ),
                        const SizedBox(width: 8),
                        _buildNeumorphicButton(
                          onPressed: () async {
                            final payload = {
                              'items': [
                                {
                                  'materialId': selectedMat.id,
                                  'actualQuantity': actual,
                                  'unit': selectedMat.baseUnit,
                                  'reason': 'Physical stock audit adjustment',
                                }
                              ]
                            };

                            Navigator.pop(ctx);

                            try {
                              await _inventoryService.recordPhysicalStockCount(payload);
                              await _loadData();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Physical count variance reconciled!'), backgroundColor: _greenAccent),
                                );
                              }
                            } catch (e) {
                              await _loadData();
                            }
                          },
                          label: 'Adjust to Count',
                          backgroundColor: _amberAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Opening Stock Dialog
  void _showOpeningStockDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Opening Stock Setup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textDark)),
        content: const Text(
          'To set opening stock for materials, edit individual materials or use the "+ Add Material" button.',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        ),
        actions: [
          _buildNeumorphicButton(
            onPressed: () => Navigator.pop(ctx),
            label: 'OK',
            isSecondary: true,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          ),
        ],
      ),
    );
  }

  /// Material Movement Ledger Dialog
  void _showMaterialLedgerDialog(RawMaterialModel material) {
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<List<InventoryMovementModel>>(
        future: _inventoryService.fetchMaterialMovements(material.id),
        builder: (ctx, snapshot) {
          final movements = snapshot.data ?? [];
          final screenWidth = MediaQuery.of(ctx).size.width;

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: min(screenWidth * 0.94, 520), maxHeight: 420),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history_rounded, color: _primaryNavy, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ledger: ${material.name} (${material.sku})',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _textDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 16, color: _textMuted),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Expanded(
                      child: snapshot.connectionState == ConnectionState.waiting
                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _primaryNavy))
                          : movements.isEmpty
                              ? const Center(child: Text('No historical ledger transactions found', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B))))
                              : ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: movements.length,
                                  itemBuilder: (context, i) {
                                    final mov = movements[i];
                                    final isAdd = mov.isAddition;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 5),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: _borderColor),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(isAdd ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                              color: isAdd ? _greenAccent : _redAccent, size: 14),
                                          const SizedBox(width: 7),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(mov.typeLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                Text(mov.reason, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: Color(0xFF475569)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text('${isAdd ? '+' : ''}${mov.quantityDeltaBaseUnits.toStringAsFixed(0)} ${material.baseUnit}',
                                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isAdd ? _greenAccent : _redAccent)),
                                              Text('Bal: ${mov.balanceAfterBaseUnits.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // HELPER WIDGETS
  // ===========================================================================

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool isNumber = false,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 12.5, color: _textDark, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
          ),
        ),
      ],
    );
  }

  InputDecoration _dropdownInputDecoration({String? hint}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
    );
  }

  /// Proper Download Excel Report Button
  Widget _buildDownloadExcelButton({
    required VoidCallback onTap,
    String label = 'Download Excel',
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
          decoration: BoxDecoration(
            color: const Color(0xFF107C41), // Microsoft Excel brand green
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF107C41).withValues(alpha: 0.35),
                offset: const Offset(0, 2),
                blurRadius: 5,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.file_download_outlined, color: Colors.white, size: 16),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Export current inventory report tab data to Excel spreadsheet (CSV format with UTF-8 BOM)
  Future<void> _exportInventoryReportToExcel() async {
    final currency = _db.restaurant?.currencySymbol ?? '₹';
    final now = DateTime.now();
    final dateTag = DateFormat('yyyyMMdd_HHmmss').format(now);
    final String reportTitle;
    final String filename;
    final List<List<dynamic>> rows = [];

    if (_reportSubTab == 0) {
      reportTitle = 'Stock Valuation Report';
      filename = 'Inventory_Stock_Valuation_$dateTag.csv';
      rows.add([
        'Material Name',
        'SKU',
        'Category',
        'Current Stock',
        'Base Unit',
        'Min Stock Alert',
        'Purchase Unit',
        'Conversion Factor',
        'Avg Unit Cost ($currency)',
        'Valuation ($currency)',
        'Stock Status',
        'Inventory Mode',
        'Preferred Supplier',
      ]);

      if (_rawMaterials.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No raw materials found to export.'), backgroundColor: Color(0xFFD97706)),
          );
        }
        return;
      }

      for (final m in _rawMaterials) {
        final status = m.isOutOfStock ? 'Out of Stock' : (m.isLowStock ? 'Low Stock' : 'In Stock');
        rows.add([
          m.name,
          m.sku,
          m.category,
          m.currentStock.toStringAsFixed(2),
          m.baseUnit,
          m.minimumStock.toStringAsFixed(2),
          m.purchaseUnit,
          m.conversionFactor.toStringAsFixed(2),
          m.averageUnitCost.toStringAsFixed(2),
          m.valuation.toStringAsFixed(2),
          status,
          m.inventoryMode,
          m.preferredSupplier,
        ]);
      }
    } else if (_reportSubTab == 1) {
      reportTitle = 'Stock Movement Ledger';
      filename = 'Inventory_Movement_Ledger_$dateTag.csv';
      rows.add([
        'Date & Time',
        'Material Name',
        'Movement Type',
        'Quantity Delta',
        'Base Unit',
        'Balance After',
        'Reason / Notes',
      ]);

      if (_movementsLedger.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No stock movements found to export.'), backgroundColor: Color(0xFFD97706)),
          );
        }
        return;
      }

      for (final mov in _movementsLedger) {
        final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(mov.timestamp);
        final deltaStr = '${mov.isAddition ? '+' : ''}${mov.quantityDeltaBaseUnits.toStringAsFixed(2)}';
        rows.add([
          dateStr,
          mov.materialName,
          mov.typeLabel,
          deltaStr,
          mov.baseUnit,
          mov.balanceAfterBaseUnits.toStringAsFixed(2),
          mov.reason,
        ]);
      }
    } else {
      reportTitle = 'Product & Food Cost Analytics';
      filename = 'Inventory_Food_Cost_Analytics_$dateTag.csv';
      rows.add([
        'Product Name',
        'Recipe Name',
        'Selling Price ($currency)',
        'Total Food Cost ($currency)',
        'Food Cost %',
        'Gross Margin ($currency)',
        'Margin %',
        'Portion / Servings',
        'Cost Health Status',
        'Ingredients Summary',
      ]);

      if (_recipes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No recipe analytics found to export.'), backgroundColor: Color(0xFFD97706)),
          );
        }
        return;
      }

      for (final r in _recipes) {
        final ingStr = r.ingredients.map((i) => '${i.materialName}: ${i.quantity}${i.unit}').join('; ');
        final health = r.foodCostPercentage <= 30
            ? 'Optimal (<=30%)'
            : (r.foodCostPercentage <= 40 ? 'Moderate (31-40%)' : 'High Cost (>40%)');

        rows.add([
          r.productName,
          r.recipeName.isNotEmpty ? r.recipeName : 'Standard Recipe',
          r.sellingPrice.toStringAsFixed(2),
          r.totalFoodCost.toStringAsFixed(2),
          '${r.foodCostPercentage.toStringAsFixed(1)}%',
          r.grossMargin.toStringAsFixed(2),
          '${r.marginPercentage.toStringAsFixed(1)}%',
          r.servingSize.toStringAsFixed(1),
          health,
          ingStr,
        ]);
      }
    }

    final StringBuffer csvBuffer = StringBuffer();
    // Prepend UTF-8 BOM so Excel opens currency symbols and international characters cleanly
    csvBuffer.write('\uFEFF');
    for (final row in rows) {
      final line = row.map((f) => '"${f.toString().replaceAll('"', '""')}"').join(',');
      csvBuffer.writeln(line);
    }

    try {
      Directory? targetDir;
      try {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          final docsDir = Directory('/storage/emulated/0/Documents');
          if (!docsDir.existsSync()) {
            try {
              await docsDir.create(recursive: true);
            } catch (_) {}
          }
          if (await docsDir.exists()) {
            targetDir = docsDir;
          } else {
            final downloadDir = Directory('/storage/emulated/0/Download');
            if (await downloadDir.exists()) {
              targetDir = downloadDir;
            }
          }
        }
      } catch (_) {}

      try {
        targetDir ??= await getDownloadsDirectory();
      } catch (_) {}
      try {
        targetDir ??= await getApplicationDocumentsDirectory();
      } catch (_) {}
      targetDir ??= Directory.systemTemp;

      final filePath = '${targetDir.path}/$filename';
      final file = File(filePath);
      await file.writeAsString(csvBuffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Excel report downloaded:\n$filename',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF107C41),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(14),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'SHARE / OPEN',
              textColor: Colors.white,
              onPressed: () {
                SharePlus.instance.share(
                  ShareParams(
                    files: [XFile(filePath, mimeType: 'text/csv')],
                    text: 'Apna POS $reportTitle',
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: $e'),
            backgroundColor: _redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
