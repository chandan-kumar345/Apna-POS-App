import 'package:flutter/material.dart';
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

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final RestaurantInventoryService _inventoryService = RestaurantInventoryService();

  // Colors matching Apna POS Design System
  static const Color _midnightNavyStart = Color(0xFF031024);
  static const Color _midnightNavyEnd = Color(0xFF072146);
  static const Color _primaryNavy = Color(0xFF082559);
  static const Color _cardBg = Colors.white;
  static const Color _scaffoldBg = Color(0xFFF8FAFC);
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
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedStockStatus = 'All'; // All, In Stock, Low Stock, Out of Stock
  String _selectedMode = 'All'; // All, Automatic, Manual

  // In-memory lists (synced from API or populated from offline seeds)
  List<RawMaterialModel> _rawMaterials = [];
  List<RecipeModel> _recipes = [];
  List<InventoryMovementModel> _movementsLedger = [];
  Map<String, dynamic>? _dashboardSummary;

  final List<String> _categories = [
    'All',
    'Dairy',
    'Vegetables',
    'Meat & Poultry',
    'Spices',
    'Grains & Flour',
    'Bakery',
    'Beverages',
    'Packaging',
    'Essentials',
  ];

  @override
  void initState() {
    super.initState();
    _db.addListener(_onDbChange);
    _initializeLocalSeeds();
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

  /// Initialize local default materials & recipes if empty
  void _initializeLocalSeeds() {
    if (_rawMaterials.isEmpty) {
      _rawMaterials = [
        RawMaterialModel(
          id: 'seed_rm_1',
          sku: 'RM-0001',
          name: 'Fresh Paneer',
          category: 'Dairy',
          baseUnit: 'g',
          purchaseUnit: 'kg',
          conversionFactor: 1000,
          currentStock: 12000, // 12 kg
          minimumStock: 2500,
          averageUnitCost: 340,
          costPerBaseUnit: 0.34,
          preferredSupplier: 'Amul Dairy Dist.',
          inventoryMode: 'automatic',
        ),
        RawMaterialModel(
          id: 'seed_rm_2',
          sku: 'RM-0002',
          name: 'Cooking Butter',
          category: 'Dairy',
          baseUnit: 'g',
          purchaseUnit: 'kg',
          conversionFactor: 1000,
          currentStock: 6500, // 6.5 kg
          minimumStock: 1500,
          averageUnitCost: 520,
          costPerBaseUnit: 0.52,
          preferredSupplier: 'Amul Dairy Dist.',
          inventoryMode: 'automatic',
        ),
        RawMaterialModel(
          id: 'seed_rm_3',
          sku: 'RM-0003',
          name: 'Fresh Cooking Cream',
          category: 'Dairy',
          baseUnit: 'ml',
          purchaseUnit: 'L',
          conversionFactor: 1000,
          currentStock: 8000, // 8 L
          minimumStock: 2000,
          averageUnitCost: 210,
          costPerBaseUnit: 0.21,
          preferredSupplier: 'Amul Dairy Dist.',
          inventoryMode: 'automatic',
        ),
        RawMaterialModel(
          id: 'seed_rm_4',
          sku: 'RM-0004',
          name: 'Tomatoes',
          category: 'Vegetables',
          baseUnit: 'g',
          purchaseUnit: 'kg',
          conversionFactor: 1000,
          currentStock: 15000, // 15 kg
          minimumStock: 3000,
          averageUnitCost: 40,
          costPerBaseUnit: 0.04,
          preferredSupplier: 'Mandi Direct',
          inventoryMode: 'automatic',
        ),
        RawMaterialModel(
          id: 'seed_rm_5',
          sku: 'RM-0005',
          name: 'Basmati Rice Premium',
          category: 'Grains & Flour',
          baseUnit: 'g',
          purchaseUnit: 'kg',
          conversionFactor: 1000,
          currentStock: 45000, // 45 kg
          minimumStock: 10000,
          averageUnitCost: 110,
          costPerBaseUnit: 0.11,
          preferredSupplier: 'Punjab Grain Store',
          inventoryMode: 'automatic',
        ),
        RawMaterialModel(
          id: 'seed_rm_6',
          sku: 'RM-0006',
          name: 'Cold Drink Glass Bottles (300ml)',
          category: 'Beverages',
          baseUnit: 'pcs',
          purchaseUnit: 'box',
          conversionFactor: 24,
          currentStock: 48, // 2 boxes = 48 bottles
          minimumStock: 24,
          averageUnitCost: 480,
          costPerBaseUnit: 20.0,
          preferredSupplier: 'Coca Cola Agency',
          inventoryMode: 'manual',
        ),
        RawMaterialModel(
          id: 'seed_rm_7',
          sku: 'RM-0007',
          name: 'Takeaway Meal Containers',
          category: 'Packaging',
          baseUnit: 'pcs',
          purchaseUnit: 'pack',
          conversionFactor: 100,
          currentStock: 250,
          minimumStock: 100,
          averageUnitCost: 350,
          costPerBaseUnit: 3.5,
          preferredSupplier: 'Eco Packaging Hub',
          inventoryMode: 'manual',
        ),
      ];

      _recipes = [
        RecipeModel(
          id: 'seed_rec_1',
          productId: 'prod_paneer_butter',
          productName: 'Paneer Butter Masala',
          recipeName: 'Standard Paneer Butter Masala',
          servingSize: 1,
          version: 'v1.0',
          sellingPrice: 320,
          totalFoodCost: 98.4,
          foodCostPercentage: 30.75,
          ingredients: [
            RecipeIngredientModel(
              materialId: 'seed_rm_1',
              materialName: 'Fresh Paneer',
              quantity: 200,
              unit: 'g',
              quantityBaseUnits: 200,
              effectiveQuantityBaseUnits: 200,
              unitCost: 0.34,
              totalCost: 68.0,
            ),
            RecipeIngredientModel(
              materialId: 'seed_rm_2',
              materialName: 'Cooking Butter',
              quantity: 40,
              unit: 'g',
              quantityBaseUnits: 40,
              effectiveQuantityBaseUnits: 40,
              unitCost: 0.52,
              totalCost: 20.8,
            ),
            RecipeIngredientModel(
              materialId: 'seed_rm_3',
              materialName: 'Fresh Cooking Cream',
              quantity: 30,
              unit: 'ml',
              quantityBaseUnits: 30,
              effectiveQuantityBaseUnits: 30,
              unitCost: 0.21,
              totalCost: 6.3,
            ),
            RecipeIngredientModel(
              materialId: 'seed_rm_4',
              materialName: 'Tomatoes',
              quantity: 80,
              unit: 'g',
              quantityBaseUnits: 80,
              effectiveQuantityBaseUnits: 80,
              unitCost: 0.04,
              totalCost: 3.2,
            ),
          ],
        ),
      ];
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final summary = await _inventoryService.fetchDashboardSummary();
      final materials = await _inventoryService.fetchRawMaterials();
      final recipes = await _inventoryService.fetchRecipes();
      final movements = await _inventoryService.fetchMovementsLedger();

      if (mounted) {
        setState(() {
          if (summary != null) _dashboardSummary = summary;
          if (materials.isNotEmpty) _rawMaterials = materials;
          if (recipes.isNotEmpty) _recipes = recipes;
          if (movements.isNotEmpty) _movementsLedger = movements;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[InventoryScreen._loadData] API error, using local data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // UI BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildMidnightNavyHeader(),
            _buildNavigationTabBar(),
            Expanded(
              child: _isLoading && _rawMaterials.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _buildSelectedTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. SIGNATURE MIDNIGHT NAVY HEADER
  // ===========================================================================

  Widget _buildMidnightNavyHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_midnightNavyStart, _midnightNavyEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (widget.onBack != null || Navigator.canPop(context))
            InkWell(
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.pop(context);
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Restaurant Inventory',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _greenAccent.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _greenAccent.withValues(alpha: 0.5)),
                      ),
                      child: const Text(
                        'Live Recipes',
                        style: TextStyle(color: Color(0xFF86EFAC), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Raw materials, automatic recipe consumption & stock ledger',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _openSubscription,
            icon: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24), size: 20),
            tooltip: 'Subscription & Plans',
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
            tooltip: 'Sync with backend',
          ),
          ElevatedButton.icon(
            onPressed: () => _showAddMaterialDialog(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Material', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. SEGMENTED NEUMORPHIC NAVIGATION TABS
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: List.generate(tabs.length, (index) {
            final isSelected = _selectedTabIndex == index;
            final tab = tabs[index];

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => setState(() => _selectedTabIndex = index),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryNavy : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _primaryNavy.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        tab['icon'] as IconData,
                        size: 16,
                        color: isSelected ? Colors.white : _textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tab['label'] as String,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
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
  // TAB 0: OVERVIEW / DASHBOARD
  // ===========================================================================

  Widget _buildOverviewTab() {
    final double totalValuation = _rawMaterials.fold(0.0, (sum, m) => sum + m.valuation);
    final int lowStockCount = _rawMaterials.where((m) => m.isLowStock).length;
    final int outOfStockCount = _rawMaterials.where((m) => m.isOutOfStock).length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick KPI Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildKpiCard(
                          title: 'Total Stock Valuation',
                          value: '₹${totalValuation.toStringAsFixed(2)}',
                          subtitle: '${_rawMaterials.length} raw materials on hand',
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: _blueAccent,
                          width: isWide ? (constraints.maxWidth - 24) / 3 : (constraints.maxWidth - 12) / 2,
                        ),
                        _buildKpiCard(
                          title: 'Low Stock Alert',
                          value: '$lowStockCount Items',
                          subtitle: 'Items below minimum reorder level',
                          icon: Icons.warning_amber_rounded,
                          iconColor: _amberAccent,
                          width: isWide ? (constraints.maxWidth - 24) / 3 : (constraints.maxWidth - 12) / 2,
                          isWarning: lowStockCount > 0,
                        ),
                        _buildKpiCard(
                          title: 'Out of Stock',
                          value: '$outOfStockCount Items',
                          subtitle: 'Items requiring immediate purchase',
                          icon: Icons.remove_shopping_cart_outlined,
                          iconColor: _redAccent,
                          width: isWide ? (constraints.maxWidth - 24) / 3 : (constraints.maxWidth - 12) / 2,
                          isDanger: outOfStockCount > 0,
                        ),
                        _buildKpiCard(
                          title: "Today's Stock-In",
                          value: '₹${(_dashboardSummary?['todayStockInValue'] ?? 0).toString()}',
                          subtitle: 'Supplier purchases received',
                          icon: Icons.archive_outlined,
                          iconColor: _greenAccent,
                          width: isWide ? (constraints.maxWidth - 24) / 3 : (constraints.maxWidth - 12) / 2,
                        ),
                        _buildKpiCard(
                          title: "Today's Consumption",
                          value: '₹${(_dashboardSummary?['todayStockOutValue'] ?? 0).toString()}',
                          subtitle: 'Recipe sales + kitchen usage',
                          icon: Icons.unarchive_outlined,
                          iconColor: const Color(0xFF8B5CF6),
                          width: isWide ? (constraints.maxWidth - 24) / 3 : (constraints.maxWidth - 12) / 2,
                        ),
                        _buildKpiCard(
                          title: 'Active Recipes',
                          value: '${_recipes.length} Recipes',
                          subtitle: 'Configured menu item deductions',
                          icon: Icons.restaurant_menu_rounded,
                          iconColor: _primaryNavy,
                          width: isWide ? (constraints.maxWidth - 24) / 3 : (constraints.maxWidth - 12) / 2,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),

                // Quick Action Bar
                _buildQuickActionsBar(),
                const SizedBox(height: 18),

                // Low Stock Warning Banner (if any)
                if (lowStockCount > 0 || outOfStockCount > 0)
                  _buildAttentionBanner(),

                const SizedBox(height: 18),

                // Split section: Top Consumed vs Recent Transactions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTopConsumedSection()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildRecentTransactionsSection()),
                  ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDanger
              ? _redAccent.withValues(alpha: 0.4)
              : isWarning
                  ? _amberAccent.withValues(alpha: 0.4)
                  : _borderColor,
          width: isDanger || isWarning ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _textMuted),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isDanger ? _redAccent : isWarning ? _amberAccent : _textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10.5, color: _textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚡ Quick Operations',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textDark),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildActionButton(
                  icon: Icons.add_circle_outline_rounded,
                  label: '+ Add Material',
                  color: _blueAccent,
                  onTap: () => _showAddMaterialDialog(),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.archive_outlined,
                  label: '+ Stock In (Purchase)',
                  color: _greenAccent,
                  onTap: () => _showStockInDialog(),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.unarchive_outlined,
                  label: '− Stock Out (Kitchen/Wastage)',
                  color: _redAccent,
                  onTap: () => _showStockOutDialog(),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.restaurant_menu_rounded,
                  label: '🍳 Create Recipe',
                  color: _primaryNavy,
                  onTap: () => _showCreateRecipeDialog(),
                ),
                const SizedBox(width: 8),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttentionBanner() {
    final lowStock = _rawMaterials.where((m) => m.isLowStock || m.isOutOfStock).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _redAccent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attention: ${lowStock.length} items are low or out of stock!',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF991B1B)),
                ),
                const SizedBox(height: 2),
                Text(
                  lowStock.take(5).map((m) => '${m.name} (${m.formattedStock})').join(' • '),
                  style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showStockInDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Restock Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopConsumedSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🔥 Top Consumed Ingredients',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _textDark),
              ),
              Text('Live Deductions', style: TextStyle(fontSize: 10.5, color: _textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          if (_rawMaterials.isEmpty)
            const Text('No ingredients recorded yet', style: TextStyle(fontSize: 11.5, color: _textMuted))
          else
            Column(
              children: _rawMaterials.take(4).map((m) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.kitchen_rounded, size: 14, color: _primaryNavy),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textDark)),
                            Text('Stock: ${m.formattedStock}', style: const TextStyle(fontSize: 10.5, color: _textMuted)),
                          ],
                        ),
                      ),
                      Text(
                        '₹${m.valuation.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _primaryNavy),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '📜 Recent Transactions',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _textDark),
              ),
              Text('Audit Ledger', style: TextStyle(fontSize: 10.5, color: _textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          if (_movementsLedger.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('No movements recorded today', style: TextStyle(fontSize: 11.5, color: _textMuted)),
              ),
            )
          else
            Column(
              children: _movementsLedger.take(4).map((mov) {
                final isAdd = mov.isAddition;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isAdd ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          isAdd ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                          size: 14,
                          color: isAdd ? _greenAccent : _redAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mov.materialName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textDark)),
                            Text(mov.typeLabel, style: const TextStyle(fontSize: 10.5, color: _textMuted)),
                          ],
                        ),
                      ),
                      Text(
                        '${isAdd ? '+' : ''}${mov.quantityDeltaBaseUnits.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
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
  // TAB 1: RAW MATERIALS MANAGEMENT
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
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 13, color: _textDark),
                      decoration: InputDecoration(
                        hintText: 'Search raw materials by name or SKU (e.g. Paneer, RM-0001)...',
                        hintStyle: const TextStyle(fontSize: 12, color: _textMuted),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _textMuted),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderColor)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showAddMaterialDialog(),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Material', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Category filter pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                        selected: isSel,
                        onSelected: (val) => setState(() => _selectedCategory = cat),
                        selectedColor: _primaryNavy.withValues(alpha: 0.15),
                        checkmarkColor: _primaryNavy,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 6),
              // Stock status and mode filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...['All', 'In Stock', 'Low Stock', 'Out of Stock'].map((status) {
                      final isSel = _selectedStockStatus == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(status, style: TextStyle(fontSize: 10.5, fontWeight: isSel ? FontWeight.bold : FontWeight.w600)),
                          selected: isSel,
                          onSelected: (val) => setState(() => _selectedStockStatus = status),
                          selectedColor: _blueAccent.withValues(alpha: 0.15),
                          labelStyle: TextStyle(color: isSel ? _blueAccent : _textMuted),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    ...['All', 'Automatic', 'Manual'].map((mode) {
                      final isSel = _selectedMode == mode;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(mode == 'All' ? 'All Modes' : 'Mode: $mode',
                              style: TextStyle(fontSize: 10.5, fontWeight: isSel ? FontWeight.bold : FontWeight.w600)),
                          selected: isSel,
                          onSelected: (val) => setState(() => _selectedMode = mode),
                          selectedColor: _primaryNavy.withValues(alpha: 0.15),
                          labelStyle: TextStyle(color: isSel ? _primaryNavy : _textMuted),
                          visualDensity: VisualDensity.compact,
                        ),
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
              ? const Center(child: Text('No raw materials found matching filters', style: TextStyle(color: _textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOut
              ? _redAccent.withValues(alpha: 0.5)
              : isLow
                  ? _amberAccent.withValues(alpha: 0.5)
                  : _borderColor,
          width: isOut || isLow ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  material.sku,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primaryNavy),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  material.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textDark),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: material.inventoryMode == 'automatic'
                      ? _blueAccent.withValues(alpha: 0.1)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  material.inventoryMode == 'automatic' ? 'Mode A: Auto' : 'Mode B: Manual',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: material.inventoryMode == 'automatic' ? _blueAccent : _textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current Stock', style: TextStyle(fontSize: 10.5, color: _textMuted)),
                  Text(
                    material.formattedStock,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isOut ? _redAccent : isLow ? _amberAccent : _textDark,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Min Alert', style: TextStyle(fontSize: 10.5, color: _textMuted)),
                  Text(
                    material.formattedMinStock,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textDark),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Avg Cost', style: TextStyle(fontSize: 10.5, color: _textMuted)),
                  Text(
                    '₹${material.averageUnitCost.toStringAsFixed(0)} / ${material.purchaseUnit}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textDark),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Valuation', style: TextStyle(fontSize: 10.5, color: _textMuted)),
                  Text(
                    '₹${material.valuation.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _primaryNavy),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (material.preferredSupplier.isNotEmpty)
                Text(
                  'Supplier: ${material.preferredSupplier}',
                  style: const TextStyle(fontSize: 11, color: _textMuted, fontStyle: FontStyle.italic),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showMaterialLedgerDialog(material),
                icon: const Icon(Icons.history_rounded, size: 14),
                label: const Text('Ledger', style: TextStyle(fontSize: 11.5)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              TextButton.icon(
                onPressed: () => _showAddMaterialDialog(editingMaterial: material),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit', style: TextStyle(fontSize: 11.5)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              ElevatedButton.icon(
                onPressed: () => _showStockInDialog(preselectedMaterial: material),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 13),
                label: const Text('Restock', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: RECIPE MANAGEMENT & COSTING
  // ===========================================================================

  Widget _buildRecipesTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '🍳 Recipe Management & Food Costing',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textDark),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateRecipeDialog(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Create Recipe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _recipes.isEmpty
              ? const Center(
                  child: Text('No recipes created yet. Click "+ Create Recipe" to connect menu items to raw materials.',
                      style: TextStyle(color: _textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.productName,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _textDark),
                    ),
                    Text(
                      recipe.recipeName.isNotEmpty ? recipe.recipeName : 'Standard Recipe',
                      style: const TextStyle(fontSize: 11, color: _textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 13, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      '${foodCostPct.toStringAsFixed(1)}% Food Cost',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recipe Food Cost', style: TextStyle(fontSize: 10.5, color: _textMuted)),
                  Text(
                    '₹${recipe.totalFoodCost.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _textDark),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selling Price', style: TextStyle(fontSize: 10.5, color: _textMuted)),
                  Text(
                    '₹${recipe.sellingPrice.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _primaryNavy),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Gross Profit', style: TextStyle(fontSize: 10.5, color: _textMuted)),
                  Text(
                    '₹${recipe.grossMargin.toStringAsFixed(2)} (${recipe.marginPercentage.toStringAsFixed(0)}%)',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _greenAccent),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Portion Size', style: TextStyle(fontSize: 10.5, color: _textMuted)),
                  Text(
                    '${recipe.servingSize.toStringAsFixed(0)} serving',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textDark),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Ingredients in Recipe:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textDark)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: recipe.ingredients.map((ing) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${ing.materialName}: ${ing.quantity}${ing.unit}',
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 3: STOCK OPERATIONS (MODE B & MANUAL AUDITS)
  // ===========================================================================

  Widget _buildStockOperationsTab() {
    final subTabs = ['Stock In (Purchase)', 'Stock Out (Wastage)', 'Physical Count (Audit)', 'Opening Stock'];

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(subTabs.length, (idx) {
                final isSel = _operationSubTab == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(subTabs[idx], style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.bold : FontWeight.w600)),
                    selected: isSel,
                    onSelected: (val) => setState(() => _operationSubTab = idx),
                    selectedColor: _primaryNavy.withValues(alpha: 0.15),
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(color: isSel ? _primaryNavy : _textMuted),
                  ),
                );
              }),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
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
        return _buildStockInCard();
      case 1:
        return _buildStockOutCard();
      case 2:
        return _buildPhysicalCountCard();
      case 3:
        return _buildOpeningStockCard();
      default:
        return _buildStockInCard();
    }
  }

  Widget _buildStockInCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.archive_outlined, color: _greenAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Receive Stock / Record Purchase Invoice',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _textDark),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Records incoming stock from suppliers and calculates weighted average cost automatically.',
            style: TextStyle(fontSize: 11.5, color: _textMuted),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _showStockInDialog(),
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
              label: const Text('Open Stock-In Entry Form', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _greenAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockOutCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.unarchive_outlined, color: _redAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Record Stock Out / Wastage / Kitchen Issue',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _textDark),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Record kitchen consumption, spoilage, breakage, or staff meals with categorized reasons.',
            style: TextStyle(fontSize: 11.5, color: _textMuted),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _showStockOutDialog(),
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
              label: const Text('Open Stock-Out Entry Form', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalCountCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check_outlined, color: _amberAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Physical Stock Count & Variance Reconciliation',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _textDark),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Perform periodic inventory audits to compare physical shelf stock against system counts and record adjustments.',
            style: TextStyle(fontSize: 11.5, color: _textMuted),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _showPhysicalCountDialog(),
              icon: const Icon(Icons.checklist_rounded, size: 16),
              label: const Text('Start Physical Count Audit', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _amberAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpeningStockCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.start_rounded, color: _primaryNavy, size: 20),
              SizedBox(width: 8),
              Text(
                'Initialize Opening Stock',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _textDark),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Rapidly configure initial on-hand stock for all raw materials when setting up Apna POS.',
            style: TextStyle(fontSize: 11.5, color: _textMuted),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _showOpeningStockDialog(),
              icon: const Icon(Icons.edit_note_rounded, size: 16),
              label: const Text('Enter Opening Stock', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 4: REPORTS & ANALYTICS
  // ===========================================================================

  Widget _buildReportsTab() {
    final subReports = ['Stock Valuation Report', 'Stock Movement Ledger', 'Product & Food Cost Analytics'];

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(subReports.length, (idx) {
                final isSel = _reportSubTab == idx;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(subReports[idx], style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.bold : FontWeight.w600)),
                    selected: isSel,
                    onSelected: (val) => setState(() => _reportSubTab = idx),
                    selectedColor: _primaryNavy.withValues(alpha: 0.15),
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(color: isSel ? _primaryNavy : _textMuted),
                  ),
                );
              }),
            ),
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
    final totalValuation = _rawMaterials.fold(0.0, (sum, m) => sum + m.valuation);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _primaryNavy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Inventory Asset Valuation:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('₹${totalValuation.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 16, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ..._rawMaterials.map((m) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textDark)),
                            Text('${m.sku} • ${m.category}', style: const TextStyle(fontSize: 10.5, color: _textMuted)),
                          ],
                        ),
                      ),
                      Text(m.formattedStock, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textDark)),
                      const SizedBox(width: 24),
                      Text('₹${m.valuation.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _primaryNavy)),
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
        ? const Center(child: Text('No stock movements recorded yet.', style: TextStyle(color: _textMuted)))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _movementsLedger.length,
            itemBuilder: (context, idx) {
              final mov = _movementsLedger[idx];
              final isAdd = mov.isAddition;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isAdd ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isAdd ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: isAdd ? _greenAccent : _redAccent,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mov.materialName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textDark)),
                          Text('${mov.typeLabel} • ${mov.reason}', style: const TextStyle(fontSize: 10.5, color: _textMuted)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isAdd ? '+' : ''}${mov.quantityDeltaBaseUnits.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isAdd ? _greenAccent : _redAccent),
                        ),
                        Text('Bal: ${mov.balanceAfterBaseUnits.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10.5, color: _textMuted)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
  }

  Widget _buildFoodCostAnalyticsReport() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Menu Item Profitability & Food Cost Health',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _textDark),
              ),
              const SizedBox(height: 6),
              const Text(
                'Target Food Cost % for casual dining & cafes is 28% – 35%. Items above 40% should be adjusted or repriced.',
                style: TextStyle(fontSize: 11.5, color: _textMuted),
              ),
              const SizedBox(height: 14),
              ..._recipes.map((r) {
                final isHealthy = r.foodCostPercentage <= 30;
                final badgeColor = isHealthy ? _greenAccent : r.foodCostPercentage <= 40 ? _amberAccent : _redAccent;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.productName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _textDark)),
                            Text('Selling Price: ₹${r.sellingPrice} | Food Cost: ₹${r.totalFoodCost.toStringAsFixed(1)}',
                                style: const TextStyle(fontSize: 11, color: _textMuted)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '${r.foodCostPercentage.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: badgeColor),
                        ),
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

  // ===========================================================================
  // INTERACTIVE DIALOGS / MODALS
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
    String category = editingMaterial?.category ?? 'General';
    String mode = editingMaterial?.inventoryMode ?? 'automatic';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.inventory_2_rounded, color: _primaryNavy, size: 20),
                const SizedBox(width: 8),
                Text(
                  editingMaterial == null ? 'Add Raw Material' : 'Edit ${editingMaterial.name}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(label: 'Material Name *', controller: nameCtrl, hint: 'e.g. Fresh Paneer'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(label: 'SKU (Leave blank to auto-generate)', controller: skuCtrl, hint: 'e.g. RM-0001')),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textMuted)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                initialValue: _categories.contains(category) ? category : 'Dairy',
                                items: _categories.where((c) => c != 'All').map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (v) => setDlgState(() => category = v ?? 'General'),
                                decoration: _dropdownInputDecoration(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Base Unit (Canonical)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textMuted)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                initialValue: baseUnit,
                                items: const [
                                  DropdownMenuItem(value: 'g', child: Text('Gram (g)', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'ml', child: Text('Millilitre (ml)', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'pcs', child: Text('Piece (pcs)', style: TextStyle(fontSize: 12))),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Purchase Unit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textMuted)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                initialValue: purchaseUnit,
                                items: const [
                                  DropdownMenuItem(value: 'kg', child: Text('Kilogram (kg)', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'L', child: Text('Litre (L)', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'pcs', child: Text('Pieces (pcs)', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'box', child: Text('Box', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'bag', child: Text('Bag', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'pack', child: Text('Pack', style: TextStyle(fontSize: 12))),
                                ],
                                onChanged: (v) => setDlgState(() => purchaseUnit = v ?? 'kg'),
                                decoration: _dropdownInputDecoration(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      label: 'Conversion Factor (Base Units per Purchase Unit)',
                      controller: conversionCtrl,
                      hint: '1000 for kg->g, 1000 for L->ml',
                      isNumber: true,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (editingMaterial == null)
                          Expanded(child: _buildTextField(label: 'Opening Stock ($baseUnit)', controller: currentStockCtrl, isNumber: true)),
                        if (editingMaterial == null) const SizedBox(width: 10),
                        Expanded(child: _buildTextField(label: 'Minimum Alert ($baseUnit)', controller: minStockCtrl, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(label: 'Avg Cost (₹ per $purchaseUnit)', controller: costCtrl, isNumber: true)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Inventory Mode', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textMuted)),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                initialValue: mode,
                                items: const [
                                  DropdownMenuItem(value: 'automatic', child: Text('Mode A: Automatic', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'manual', child: Text('Mode B: Manual', style: TextStyle(fontSize: 12))),
                                ],
                                onChanged: (v) => setDlgState(() => mode = v ?? 'automatic'),
                                decoration: _dropdownInputDecoration(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(label: 'Preferred Supplier (Optional)', controller: supplierCtrl, hint: 'e.g. Amul Dairy Dist.'),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
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

                  Navigator.pop(ctx);

                  try {
                    if (editingMaterial == null) {
                      await _inventoryService.createRawMaterial(payload);
                    } else {
                      await _inventoryService.updateRawMaterial(editingMaterial.id, payload);
                    }
                    _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(editingMaterial == null ? 'Raw material added successfully!' : 'Material updated!'),
                          backgroundColor: _greenAccent,
                        ),
                      );
                    }
                  } catch (e) {
                    // Fallback to local memory if offline
                    if (editingMaterial == null) {
                      _rawMaterials.add(RawMaterialModel(
                        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
                        sku: skuCtrl.text.trim().isNotEmpty ? skuCtrl.text.trim() : 'RM-${_rawMaterials.length + 1}',
                        name: name,
                        category: category,
                        baseUnit: baseUnit,
                        purchaseUnit: purchaseUnit,
                        conversionFactor: conv,
                        minimumStock: minStock,
                        currentStock: curStock,
                        averageUnitCost: cost,
                        costPerBaseUnit: conv > 0 ? cost / conv : 0,
                        preferredSupplier: supplierCtrl.text.trim(),
                        inventoryMode: mode,
                      ));
                    }
                    setState(() {});
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _primaryNavy, foregroundColor: Colors.white),
                child: const Text('Save Material'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Create Recipe Dialog
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
          // Calculate live cost
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

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.restaurant_menu_rounded, color: _primaryNavy, size: 20),
                SizedBox(width: 8),
                Text('Create Recipe & Costing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark)),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Link POS Menu Item *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textMuted)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<MenuItemModel>(
                      initialValue: selectedMenuItem,
                      items: _db.menuItems.map((m) => DropdownMenuItem(value: m, child: Text('${m.name} (₹${m.price})', style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) {
                        setDlgState(() {
                          selectedMenuItem = v;
                          if (v != null) recipeNameCtrl.text = '${v.name} Recipe';
                        });
                      },
                      decoration: _dropdownInputDecoration(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(label: 'Recipe Name', controller: recipeNameCtrl, hint: 'e.g. Standard Recipe')),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 100,
                          child: _buildTextField(label: 'Servings', controller: servingCtrl, isNumber: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Ingredients Required:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _textDark)),
                        TextButton.icon(
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
                          icon: const Icon(Icons.add_rounded, size: 14),
                          label: const Text('Add Row', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...List.generate(ingredientRows.length, (i) {
                      final row = ingredientRows[i];
                      final mat = row['material'] as RawMaterialModel;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButton<RawMaterialModel>(
                                isExpanded: true,
                                value: mat,
                                underline: const SizedBox(),
                                items: _rawMaterials.map((m) => DropdownMenuItem(value: m, child: Text(m.name, style: const TextStyle(fontSize: 11.5)))).toList(),
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
                              width: 60,
                              child: TextField(
                                controller: row['quantityCtrl'] as TextEditingController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 12),
                                onChanged: (_) => setDlgState(() {}),
                                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(6), border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(mat.baseUnit, style: const TextStyle(fontSize: 11, color: _textMuted)),
                            const SizedBox(width: 8),
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
                    const SizedBox(height: 14),
                    // Live Costing Summary Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Calculated Food Cost', style: TextStyle(fontSize: 10.5, color: _textMuted)),
                              Text('₹${liveFoodCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textDark)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Selling Price', style: TextStyle(fontSize: 10.5, color: _textMuted)),
                              Text('₹${sellingPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _primaryNavy)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Food Cost %', style: TextStyle(fontSize: 10.5, color: _textMuted)),
                              Text(
                                '${foodCostPct.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 14,
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
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
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
                    _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Recipe created successfully!'), backgroundColor: _greenAccent),
                      );
                    }
                  } catch (e) {
                    // Fallback to local memory if offline
                    _recipes.add(RecipeModel(
                      id: 'local_rec_${DateTime.now().millisecondsSinceEpoch}',
                      productId: selectedMenuItem!.id,
                      productName: selectedMenuItem!.name,
                      recipeName: recipeNameCtrl.text.trim(),
                      sellingPrice: sellingPrice,
                      totalFoodCost: liveFoodCost,
                      foodCostPercentage: foodCostPct,
                      ingredients: ingredientRows.map((row) {
                        final mat = row['material'] as RawMaterialModel;
                        final q = double.tryParse((row['quantityCtrl'] as TextEditingController).text) ?? 0.0;
                        return RecipeIngredientModel(
                          materialId: mat.id,
                          materialName: mat.name,
                          quantity: q,
                          unit: row['unit'],
                          quantityBaseUnits: q,
                          effectiveQuantityBaseUnits: q,
                          unitCost: mat.costPerBaseUnit,
                          totalCost: q * mat.costPerBaseUnit,
                        );
                      }).toList(),
                    ));
                    setState(() {});
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _primaryNavy, foregroundColor: Colors.white),
                child: const Text('Save Recipe'),
              ),
            ],
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
          final qty = double.tryParse(qtyCtrl.text) ?? 0.0;
          final unitCost = double.tryParse(costCtrl.text) ?? 0.0;
          final totalCost = qty * unitCost;

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.archive_outlined, color: _greenAccent, size: 20),
                SizedBox(width: 8),
                Text('Record Stock In (Purchase)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark)),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Raw Material *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textMuted)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<RawMaterialModel>(
                      initialValue: _rawMaterials.firstWhere((m) => m.id == selectedMat.id, orElse: () => _rawMaterials.first),
                      items: _rawMaterials.map((m) => DropdownMenuItem(value: m, child: Text('${m.name} (${m.formattedStock})', style: const TextStyle(fontSize: 12)))).toList(),
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(label: 'Supplier Name', controller: supplierCtrl, hint: 'e.g. Pure Farms')),
                        const SizedBox(width: 10),
                        Expanded(child: _buildTextField(label: 'Invoice #', controller: invoiceCtrl, hint: 'e.g. INV-1002')),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                        const SizedBox(width: 10),
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
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Invoice Amount:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textMuted)),
                          Text('₹${totalCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _greenAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
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
                    _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Received $qty ${selectedMat.purchaseUnit} of ${selectedMat.name}'), backgroundColor: _greenAccent),
                      );
                    }
                  } catch (e) {
                    // Update local stock directly
                    final idx = _rawMaterials.indexWhere((m) => m.id == selectedMat.id);
                    if (idx >= 0) {
                      final addedBaseUnits = qty * selectedMat.conversionFactor;
                      _rawMaterials[idx] = _rawMaterials[idx].copyWith(
                        currentStock: _rawMaterials[idx].currentStock + addedBaseUnits,
                      );
                      setState(() {});
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _greenAccent, foregroundColor: Colors.white),
                child: const Text('Confirm Stock-In'),
              ),
            ],
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
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.unarchive_outlined, color: _redAccent, size: 20),
                SizedBox(width: 8),
                Text('Record Stock Out / Wastage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark)),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Raw Material *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textMuted)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<RawMaterialModel>(
                    initialValue: _rawMaterials.firstWhere((m) => m.id == selectedMat.id, orElse: () => _rawMaterials.first),
                    items: _rawMaterials.map((m) => DropdownMenuItem(value: m, child: Text('${m.name} (${m.formattedStock})', style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) {
                      if (v != null) setDlgState(() => selectedMat = v);
                    },
                    decoration: _dropdownInputDecoration(),
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(label: 'Quantity (${selectedMat.purchaseUnit})', controller: qtyCtrl, isNumber: true),
                  const SizedBox(height: 10),
                  const Text('Reason / Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textMuted)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: reason,
                    items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setDlgState(() => reason = v ?? reasons.first),
                    decoration: _dropdownInputDecoration(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
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
                    _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Issued $qty ${selectedMat.purchaseUnit} of ${selectedMat.name}'), backgroundColor: _redAccent),
                      );
                    }
                  } catch (e) {
                    final idx = _rawMaterials.indexWhere((m) => m.id == selectedMat.id);
                    if (idx >= 0) {
                      final baseOut = qty * selectedMat.conversionFactor;
                      _rawMaterials[idx] = _rawMaterials[idx].copyWith(
                        currentStock: _rawMaterials[idx].currentStock - baseOut,
                      );
                      setState(() {});
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _redAccent, foregroundColor: Colors.white),
                child: const Text('Deduct Stock'),
              ),
            ],
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
          final expected = selectedMat.currentStock;
          final actual = double.tryParse(countCtrl.text) ?? expected;
          final variance = actual - expected;

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.fact_check_outlined, color: _amberAccent, size: 20),
                SizedBox(width: 8),
                Text('Physical Count Reconciliation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark)),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Material to Audit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textMuted)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<RawMaterialModel>(
                    initialValue: _rawMaterials.firstWhere((m) => m.id == selectedMat.id, orElse: () => _rawMaterials.first),
                    items: _rawMaterials.map((m) => DropdownMenuItem(value: m, child: Text('${m.name} (${m.formattedStock})', style: const TextStyle(fontSize: 12)))).toList(),
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
                      const Text('System Expected Stock:', style: TextStyle(fontSize: 12, color: _textMuted)),
                      Text('${expected.toStringAsFixed(0)} ${selectedMat.baseUnit}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textDark)),
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: variance == 0 ? const Color(0xFFF1F5F9) : variance > 0 ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Audit Variance:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(
                          '${variance > 0 ? '+' : ''}${variance.toStringAsFixed(0)} ${selectedMat.baseUnit}',
                          style: TextStyle(
                            fontSize: 14,
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
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
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
                    _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Physical count variance reconciled!'), backgroundColor: _greenAccent),
                      );
                    }
                  } catch (e) {
                    final idx = _rawMaterials.indexWhere((m) => m.id == selectedMat.id);
                    if (idx >= 0) {
                      _rawMaterials[idx] = _rawMaterials[idx].copyWith(currentStock: actual);
                      setState(() {});
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _amberAccent, foregroundColor: Colors.white),
                child: const Text('Adjust to Count'),
              ),
            ],
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
        title: const Text('Opening Stock Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: const Text(
          'To set opening stock for materials, edit individual materials or use the "+ Add Material" button.',
          style: TextStyle(fontSize: 12.5, color: _textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
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

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.history_rounded, color: _primaryNavy, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ledger: ${material.name} (${material.sku})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textDark),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 350,
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : movements.isEmpty
                      ? const Center(child: Text('No historical ledger transactions found', style: TextStyle(color: _textMuted)))
                      : ListView.builder(
                          itemCount: movements.length,
                          itemBuilder: (context, i) {
                            final mov = movements[i];
                            final isAdd = mov.isAddition;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _borderColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(isAdd ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                      color: isAdd ? _greenAccent : _redAccent, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(mov.typeLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textDark)),
                                        Text(mov.reason, style: const TextStyle(fontSize: 10.5, color: _textMuted)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${isAdd ? '+' : ''}${mov.quantityDeltaBaseUnits.toStringAsFixed(0)} ${material.baseUnit}',
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: isAdd ? _greenAccent : _redAccent)),
                                      Text('Bal: ${mov.balanceAfterBaseUnits.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: _textMuted)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
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
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textMuted)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 12.5, color: _textDark, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11.5, color: _textMuted),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
          ),
        ),
      ],
    );
  }

  InputDecoration _dropdownInputDecoration() {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _borderColor)),
    );
  }
}
