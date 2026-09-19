import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/widgets/food_type_icon.dart';
import '../../core/database/database_service.dart';
import '../../core/models/menu_item_model.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/services/upload_service.dart';
import 'add_product_screen.dart';

/// Redesigned Responsive Menu Management Screen
/// Compatible with Windows Desktop & Android / Mobile displays.
/// Features 6-Dot Drag Sorting, Dynamic Media, Image Uploading, High-Contrast Toggles, and No Emojis.
class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final DatabaseService _db = DatabaseService();

  // Signature Deep Navy Theme Constants (Matching Brand Theme)
  static const Color _primaryNavy = Color(0xFF051C48);
  static const Color _primaryNavyDark = Color(0xFF071A36);
  static const Color _primaryNavyLight = Color(0xFF0D2547);
  static const Color _navyTint = Color(0xFFEFF4FA);
  static const Color _navyBorder = Color(0xFFCBDDF7);

  // Selection & View State
  String? _selectedCategory;
  bool _isGridView = false; // List vs Grid View Toggle
  bool _mobileSearchExpanded = false; // Mobile top bar inline search toggle
  bool _mobileCategorySearchExpanded = false; // Mobile categories expandable search
  bool _mobileProductsSearchExpanded = false; // Mobile products expandable search
  final TextEditingController _categorySearchController = TextEditingController();
  final FocusNode _categorySearchFocus = FocusNode();
  final TextEditingController _productsSearchController = TextEditingController();
  final FocusNode _productsSearchFocus = FocusNode();

  // Mobile Segmented Tab State ('categories' | 'products')
  String _mobileActiveTab = 'categories';
  String _categorySearchQuery = '';

  // Search & Filter State
  String _globalSearch = '';
  String _productSortMode = 'custom';
  String _productFilter = 'all';

  // Multi-Select State
  final Set<String> _selectedProductIds = {};
  final Set<String> _disabledCategories = {};

  @override
  void initState() {
    super.initState();
    _db.addListener(_onDbChange);
    _db.syncWithBackend();
    _initSelectedCategory();
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChange);
    _categorySearchController.dispose();
    _categorySearchFocus.dispose();
    _productsSearchController.dispose();
    _productsSearchFocus.dispose();
    super.dispose();
  }

  void _onDbChange() {
    if (mounted) {
      _initSelectedCategory();
      setState(() {});
    }
  }

  void _initSelectedCategory() {
    if (_db.categories.isNotEmpty) {
      if (_selectedCategory == null || !_db.categories.contains(_selectedCategory)) {
        _selectedCategory = _db.categories.first;
      }
    } else {
      _selectedCategory = null;
    }
  }

  // --- Reorder Proxy Decorator: Eliminates Default Dark Blue / Purple Drag Tint ---
  Widget _reorderProxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double elevation = 3.0 + (animValue * 6.0);
        return Material(
          elevation: elevation,
          color: Colors.white,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          child: child,
        );
      },
      child: child,
    );
  }

  // --- Category Products Resolution ---
  List<MenuItemModel> _getCategoryProducts(String category) {
    final catLower = category.trim().toLowerCase();
    var list = _db.menuItems.where((m) => m.category.trim().toLowerCase() == catLower).toList();

    // Global Search Filter (if active)
    if (_globalSearch.trim().isNotEmpty) {
      final q = _globalSearch.trim().toLowerCase();
      list = list.where((m) {
        return m.name.toLowerCase().contains(q) ||
            m.description.toLowerCase().contains(q) ||
            m.category.toLowerCase().contains(q);
      }).toList();
    }

    // Secondary Filter
    if (_productFilter == 'active') {
      list = list.where((m) => m.isAvailable).toList();
    } else if (_productFilter == 'inactive') {
      list = list.where((m) => !m.isAvailable).toList();
    } else if (_productFilter == 'in_stock') {
      list = list.where((m) => m.stockQuantity > 0).toList();
    } else if (_productFilter == 'out_of_stock') {
      list = list.where((m) => m.stockQuantity <= 0).toList();
    } else if (_productFilter == 'veg') {
      list = list.where((m) => m.itemType.toLowerCase() == 'veg').toList();
    } else if (_productFilter == 'non_veg') {
      list = list.where((m) => m.itemType.toLowerCase().contains('non')).toList();
    }

    // Sort Mode
    if (_productSortMode == 'name_asc') {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_productSortMode == 'name_desc') {
      list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    } else if (_productSortMode == 'price_asc') {
      list.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
    } else if (_productSortMode == 'price_desc') {
      list.sort((a, b) => b.effectivePrice.compareTo(a.effectivePrice));
    } else if (_productSortMode == 'stock_desc') {
      list.sort((a, b) => b.stockQuantity.compareTo(a.stockQuantity));
    }

    return list;
  }

  // --- All Products Resolution (Across All Categories) ---
  List<MenuItemModel> _getAllProductsFiltered() {
    var list = List<MenuItemModel>.from(_db.menuItems);

    if (_selectedCategory != null) {
      final catLower = _selectedCategory!.trim().toLowerCase();
      list = list.where((m) => m.category.trim().toLowerCase() == catLower).toList();
    }

    // Global Search Filter (if active)
    if (_globalSearch.trim().isNotEmpty) {
      final q = _globalSearch.trim().toLowerCase();
      list = list.where((m) {
        return m.name.toLowerCase().contains(q) ||
            m.description.toLowerCase().contains(q) ||
            m.category.toLowerCase().contains(q);
      }).toList();
    }

    // Secondary Filter
    if (_productFilter == 'active') {
      list = list.where((m) => m.isAvailable).toList();
    } else if (_productFilter == 'inactive') {
      list = list.where((m) => !m.isAvailable).toList();
    } else if (_productFilter == 'in_stock') {
      list = list.where((m) => m.stockQuantity > 0).toList();
    } else if (_productFilter == 'out_of_stock') {
      list = list.where((m) => m.stockQuantity <= 0).toList();
    } else if (_productFilter == 'veg') {
      list = list.where((m) => m.itemType.toLowerCase() == 'veg').toList();
    } else if (_productFilter == 'non_veg') {
      list = list.where((m) => m.itemType.toLowerCase().contains('non')).toList();
    }

    // Sort Mode
    if (_productSortMode == 'name_asc') {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (_productSortMode == 'name_desc') {
      list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    } else if (_productSortMode == 'price_asc') {
      list.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
    } else if (_productSortMode == 'price_desc') {
      list.sort((a, b) => b.effectivePrice.compareTo(a.effectivePrice));
    } else if (_productSortMode == 'stock_desc') {
      list.sort((a, b) => b.stockQuantity.compareTo(a.stockQuantity));
    }

    return list;
  }

  // --- Category Statistics ---
  int _getCategoryActiveCount(String category) {
    final catLower = category.trim().toLowerCase();
    return _db.menuItems.where((m) => m.category.trim().toLowerCase() == catLower && m.isAvailable).length;
  }

  int _getCategoryTotalStock(String category) {
    final catLower = category.trim().toLowerCase();
    return _db.menuItems
        .where((m) => m.category.trim().toLowerCase() == catLower)
        .fold(0, (sum, m) => sum + (m.stockQuantity > 0 ? m.stockQuantity : 0));
  }

  // --- Category Actions ---
  void _toggleCategoryStatus(String category) {
    setState(() {
      if (_disabledCategories.contains(category)) {
        _disabledCategories.remove(category);
      } else {
        _disabledCategories.add(category);
      }
    });
  }

  void _openAddEditProductScreen([MenuItemModel? editItem, String? initialCategory]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(
          editItem: editItem,
          initialCategory: initialCategory ?? _selectedCategory,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  // --- High-Contrast Modern Toggle Switch Widget ---
  Widget _buildToggleSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
    double scale = 0.72,
    Color activeColor = _primaryNavy,
  }) {
    return Transform.scale(
      scale: scale,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: activeColor,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFFCBD5E1),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
    );
  }

  // --- Dynamic Product Thumbnail Loader (No emojis) ---
  Widget _buildProductImageThumbnail(
    MenuItemModel product, {
    double width = 36,
    double height = 36,
    double borderRadius = 8,
  }) {
    String? rawUrl;
    if (product.imageUrl.trim().isNotEmpty) {
      rawUrl = product.imageUrl.trim();
    } else if (product.images.isNotEmpty) {
      rawUrl = product.images.firstWhere((img) => img.trim().isNotEmpty, orElse: () => '');
    }

    Widget? imageWidget;
    if (rawUrl != null && rawUrl.isNotEmpty) {
      final resolved = ApiEndpoints.resolveMediaUrl(rawUrl);
      if (resolved.isNotEmpty) {
        if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
          imageWidget = Image.network(
            resolved,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackProductIcon(width, height),
          );
        } else if (resolved.startsWith('assets/')) {
          imageWidget = Image.asset(
            resolved,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackProductIcon(width, height),
          );
        } else {
          final file = File(resolved);
          if (file.existsSync()) {
            imageWidget = Image.file(
              file,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallbackProductIcon(width, height),
            );
          }
        }
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: imageWidget ?? _buildFallbackProductIcon(width, height),
      ),
    );
  }

  Widget _buildFallbackProductIcon(double width, double height) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant_rounded,
        color: _primaryNavy,
        size: (width * 0.45).clamp(12.0, 30.0),
      ),
    );
  }

  // --- Dynamic Category Thumbnail Loader (No emojis) ---
  Widget _buildCategoryImageThumbnail(
    String category, {
    double width = 36,
    double height = 36,
    double borderRadius = 8,
    bool isSelected = false,
  }) {
    final imagePath = _db.getCategoryImage(category);
    Widget? imageWidget;

    if (imagePath != null && imagePath.trim().isNotEmpty) {
      final resolved = ApiEndpoints.resolveMediaUrl(imagePath.trim());
      if (resolved.isNotEmpty) {
        if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
          imageWidget = Image.network(
            resolved,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildCategoryIconFallback(category, width, height, isSelected),
          );
        } else if (resolved.startsWith('assets/')) {
          imageWidget = Image.asset(
            resolved,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildCategoryIconFallback(category, width, height, isSelected),
          );
        } else {
          final file = File(resolved);
          if (file.existsSync()) {
            imageWidget = Image.file(
              file,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildCategoryIconFallback(category, width, height, isSelected),
            );
          }
        }
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isSelected ? _navyBorder.withValues(alpha: 0.35) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        alignment: Alignment.center,
        child: imageWidget ?? _buildCategoryIconFallback(category, width, height, isSelected),
      ),
    );
  }

  Widget _buildCategoryIconFallback(String category, double width, double height, bool isSelected) {
    IconData icon = Icons.category_rounded;
    final cat = category.toLowerCase().trim();
    if (cat.contains('main') || cat.contains('curry') || cat.contains('course')) {
      icon = Icons.dinner_dining_rounded;
    } else if (cat.contains('bread') || cat.contains('roti') || cat.contains('naan')) {
      icon = Icons.bakery_dining_rounded;
    } else if (cat.contains('starter') || cat.contains('snack') || cat.contains('appetizer')) {
      icon = Icons.tapas_rounded;
    } else if (cat.contains('bev') || cat.contains('drink') || cat.contains('tea') || cat.contains('coffee') || cat.contains('shake')) {
      icon = Icons.local_cafe_rounded;
    } else if (cat.contains('dessert') || cat.contains('sweet') || cat.contains('cake') || cat.contains('ice cream')) {
      icon = Icons.icecream_rounded;
    } else if (cat.contains('rice') || cat.contains('biryani') || cat.contains('pulao')) {
      icon = Icons.rice_bowl_rounded;
    } else if (cat.contains('pizza') || cat.contains('burger') || cat.contains('fast')) {
      icon = Icons.fastfood_rounded;
    } else if (cat.contains('soup') || cat.contains('salad')) {
      icon = Icons.ramen_dining_rounded;
    }

    return Icon(
      icon,
      color: isSelected ? _primaryNavy : const Color(0xFF475569),
      size: (width * 0.48).clamp(14.0, 26.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    return Scaffold(
      backgroundColor: isDesktop ? const Color(0xFFF8FAFC) : const Color(0xFF071A36),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header Component (Desktop Top Bar or Mobile Segmented Tabs Bar)
            if (isDesktop)
              _buildTopBar(true)
            else
              _buildMobileTopSegmentedTabs(),

            // 2. Main Content Area (Two-Column Desktop or Android Mobile Layout)
            Expanded(
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Master Panel: Categories (Drag to Reorder)
                        SizedBox(
                          width: 290,
                          child: _buildCategoriesPanel(),
                        ),

                        // Vertical Divider
                        Container(width: 1, color: const Color(0xFFE2E8F0)),

                        // Right Detail Panel: Products
                        Expanded(
                          child: _buildProductsPanel(isDesktop: true),
                        ),
                      ],
                    )
                  : _buildMobileLayout(),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. TOP BAR COMPONENT (Responsive & Compact)
  // ===========================================================================
  Widget _buildTopBar(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Screen Title & Icon
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _primaryNavy,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Menu Management',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isDesktop) ...[
                      const SizedBox(height: 1),
                      const Text(
                        'Organize and manage your menu categories and products',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Desktop Search Bar
              if (isDesktop)
                Container(
                  width: 210,
                  height: 35,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _globalSearch = val),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Search menu...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                      prefixIcon: const Icon(Icons.search_rounded, color: _primaryNavy, size: 16),
                      suffixIcon: _globalSearch.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF64748B)),
                              onPressed: () => setState(() => _globalSearch = ''),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 7),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: Icon(
                    _mobileSearchExpanded ? Icons.search_off_rounded : Icons.search_rounded,
                    color: _primaryNavy,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _mobileSearchExpanded = !_mobileSearchExpanded),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),

              // Import CSV Button (Direct 1-Tap Access)
              if (isDesktop)
                OutlinedButton.icon(
                  onPressed: _showCsvImportModal,
                  icon: const Icon(Icons.file_upload_outlined, size: 14, color: _primaryNavy),
                  label: const Text(
                    'Import CSV',
                    style: TextStyle(color: _primaryNavy, fontWeight: FontWeight.w700, fontSize: 11.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _navyBorder, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    backgroundColor: _navyTint,
                  ),
                )
              else
                IconButton(
                  tooltip: 'Import CSV',
                  icon: const Icon(Icons.file_upload_outlined, size: 20, color: _primaryNavy),
                  onPressed: _showCsvImportModal,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              const SizedBox(width: 6),

              // Preview Menu Button
              if (isDesktop)
                OutlinedButton.icon(
                  onPressed: _showMenuPreviewModal,
                  icon: const Icon(Icons.visibility_outlined, size: 14, color: _primaryNavy),
                  label: const Text(
                    'Preview Menu',
                    style: TextStyle(color: _primaryNavy, fontWeight: FontWeight.w700, fontSize: 11.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    backgroundColor: Colors.white,
                  ),
                )
              else
                IconButton(
                  tooltip: 'Preview Menu',
                  icon: const Icon(Icons.visibility_outlined, size: 20, color: _primaryNavy),
                  onPressed: _showMenuPreviewModal,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              const SizedBox(width: 6),

              // Add Category Button
              ElevatedButton.icon(
                onPressed: _showAddCategoryModal,
                icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                label: Text(
                  isDesktop ? 'Add Category' : 'Category',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 12 : 8, vertical: 7),
                  elevation: 0,
                ),
              ),

              // More Menu / CSV
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 19),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (val) {
                  if (val == 'import_csv') _showCsvImportModal();
                  if (val == 'export_csv') _exportCsv();
                  if (val == 'sync') _db.syncWithBackend();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'import_csv',
                    child: Row(
                      children: [
                        Icon(Icons.upload_file_rounded, size: 16, color: _primaryNavy),
                        SizedBox(width: 8),
                        Text('Import CSV Spreadsheet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export_csv',
                    child: Row(
                      children: [
                        Icon(Icons.download_rounded, size: 16, color: _primaryNavy),
                        SizedBox(width: 8),
                        Text('Export Menu to CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'sync',
                    child: Row(
                      children: [
                        Icon(Icons.sync_rounded, size: 16, color: _primaryNavy),
                        SizedBox(width: 8),
                        Text('Sync with Cloud', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Mobile Expandable Search Bar
          if (!isDesktop && _mobileSearchExpanded) ...[
            const SizedBox(height: 8),
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _primaryNavy, width: 1.8),
              ),
              child: TextField(
                autofocus: true,
                onChanged: (val) => setState(() => _globalSearch = val),
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Search products by name or category...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                  prefixIcon: const Icon(Icons.search_rounded, color: _primaryNavy, size: 16),
                  suffixIcon: _globalSearch.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF64748B)),
                          onPressed: () => setState(() => _globalSearch = ''),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. LEFT MASTER PANEL: CATEGORIES (Clean 6-Dot Drag Handles, NO Arrows)
  // ===========================================================================
  Widget _buildCategoriesPanel() {
    final categories = _db.categories;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Category Header: "Categories (N)" + "+ Add" Button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Text(
                  'Categories (${categories.length})',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: _showAddCategoryModal,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primaryNavy,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 13, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          'Add',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Categories Scrollable List (Reorderable with 6-dot drag handles)
          Expanded(
            child: categories.isEmpty
                ? _buildEmptyCategoriesState()
                : ReorderableListView.builder(
                    proxyDecorator: _reorderProxyDecorator,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    itemCount: categories.length,
                    buildDefaultDragHandles: false,
                    onReorder: (oldIndex, newIndex) {
                      _db.reorderCategories(oldIndex, newIndex);
                    },
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = _selectedCategory == cat;
                      final isDisabled = _disabledCategories.contains(cat);
                      final productCount = _db.menuItems.where((m) => m.category.trim().toLowerCase() == cat.trim().toLowerCase()).length;

                      return _buildCategoryCard(
                        key: ValueKey('cat_$cat'),
                        category: cat,
                        index: index,
                        productCount: productCount,
                        isSelected: isSelected,
                        isDisabled: isDisabled,
                        totalCategories: categories.length,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard({
    Key? key,
    required String category,
    required int index,
    required int productCount,
    required bool isSelected,
    required bool isDisabled,
    required int totalCategories,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? _navyTint : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? _primaryNavy : const Color(0xFFE2E8F0),
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: _primaryNavy.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedCategory = category;
              _selectedProductIds.clear();
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            child: Row(
              children: [
                // 6-Dot Drag Handle (Icons.drag_indicator_rounded)
                ReorderableDragStartListener(
                  index: index,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.drag_indicator_rounded,
                        size: 17,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Category Dynamic Image / Icon Thumbnail (No emojis)
                _buildCategoryImageThumbnail(category, width: 34, height: 34, isSelected: isSelected),
                const SizedBox(width: 8),

                // Category Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                          color: isDisabled ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                          decoration: isDisabled ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$productCount products',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isSelected ? _primaryNavy : const Color(0xFF64748B),
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Category Status Switch (High-contrast OFF state)
                _buildToggleSwitch(
                  value: !isDisabled,
                  onChanged: (val) => _toggleCategoryStatus(category),
                  scale: 0.68,
                ),

                // Category 3-Dots Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 16, color: Color(0xFF64748B)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (val) {
                    if (val == 'edit') _showEditCategoryModal(category);
                    if (val == 'delete') _confirmDeleteCategory(category);
                    if (val == 'up' && index > 0) _db.reorderCategories(index, index - 1);
                    if (val == 'down' && index < totalCategories - 1) _db.reorderCategories(index, index + 2);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 15, color: _primaryNavy),
                          SizedBox(width: 8),
                          Text('Edit Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    if (index > 0)
                      const PopupMenuItem(
                        value: 'up',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_upward_rounded, size: 15, color: Color(0xFF0F172A)),
                            SizedBox(width: 8),
                            Text('Move Up', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    if (index < totalCategories - 1)
                      const PopupMenuItem(
                        value: 'down',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_downward_rounded, size: 15, color: Color(0xFF0F172A)),
                            SizedBox(width: 8),
                            Text('Move Down', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                          SizedBox(width: 8),
                          Text('Delete Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 3. RIGHT DETAIL PANEL: PRODUCTS MANAGEMENT
  // ===========================================================================
  Widget _buildProductsPanel({required bool isDesktop}) {
    if (_selectedCategory == null) {
      return _buildNoCategorySelectedState();
    }

    final category = _selectedCategory!;
    final products = _getCategoryProducts(category);
    final activeCount = _getCategoryActiveCount(category);
    final totalStock = _getCategoryTotalStock(category);

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // A. Selected Category Info Header Card
          _buildSelectedCategoryHeader(category, activeCount, totalStock, isDesktop: isDesktop),

          // B. Action Toolbar (Sort, Filter, View Toggle, Add Product)
          _buildProductsToolbar(category, isDesktop: isDesktop),

          // C. Products View (List Table or Card Grid)
          Expanded(
            child: products.isEmpty
                ? _buildEmptyProductsState(category)
                : _isGridView
                    ? _buildProductsGridView(products, category, isDesktop: isDesktop)
                    : (isDesktop
                        ? _buildProductsListView(products, category)
                        : _buildProductsMobileListView(products, category)),
          ),

          // D. Product Count & Footer Actions
          _buildProductsFooter(products.length, isDesktop: isDesktop),
        ],
      ),
    );
  }

  // Selected Category Info Header
  Widget _buildSelectedCategoryHeader(String category, int activeCount, int totalStock, {required bool isDesktop}) {
    return Container(
      margin: EdgeInsets.fromLTRB(isDesktop ? 16 : 10, isDesktop ? 12 : 8, isDesktop ? 16 : 10, 6),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 14 : 10, vertical: isDesktop ? 10 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Dynamic Category Thumbnail (No emojis)
          _buildCategoryImageThumbnail(category, width: isDesktop ? 40 : 34, height: isDesktop ? 40 : 34, borderRadius: 10),
          const SizedBox(width: 10),

          // Category Title & Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$activeCount active • $totalStock total stock',
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

          // Edit Category Button
          OutlinedButton.icon(
            onPressed: () => _showEditCategoryModal(category),
            icon: const Icon(Icons.edit_outlined, size: 13, color: _primaryNavy),
            label: Text(
              isDesktop ? 'Edit Category' : 'Edit',
              style: const TextStyle(color: _primaryNavy, fontWeight: FontWeight.w700, fontSize: 11),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 6),

          // 3-Dots Category Actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B), size: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onSelected: (val) {
              if (val == 'add_product') _openAddEditProductScreen(null, category);
              if (val == 'delete') _confirmDeleteCategory(category);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'add_product',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 15, color: _primaryNavy),
                    SizedBox(width: 8),
                    Text('Add Product to Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                    SizedBox(width: 8),
                    Text('Delete Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Toolbar (Sort, Filter, View Toggle, Add Product) with Clear Dropdown Visibility & Wrapping
  Widget _buildProductsToolbar(String category, {required bool isDesktop}) {
    final sortDropdown = Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _productSortMode,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(10),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: _primaryNavy),
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          onChanged: (val) {
            if (val != null) setState(() => _productSortMode = val);
          },
          items: const [
            DropdownMenuItem(value: 'custom', child: Text('Custom Order (Drag)', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.w600))),
            DropdownMenuItem(value: 'name_asc', child: Text('Name (A → Z)', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.w600))),
            DropdownMenuItem(value: 'name_desc', child: Text('Name (Z → A)', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.w600))),
            DropdownMenuItem(value: 'price_asc', child: Text('Price (Low → High)', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.w600))),
            DropdownMenuItem(value: 'price_desc', child: Text('Price (High → Low)', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.w600))),
            DropdownMenuItem(value: 'stock_desc', child: Text('Stock (High → Low)', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );

    final filterDropdown = Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _productFilter,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(10),
          icon: const Icon(Icons.filter_list_rounded, size: 16, color: _primaryNavy),
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          onChanged: (val) {
            if (val != null) setState(() => _productFilter = val);
          },
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Products', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.w600))),
            DropdownMenuItem(value: 'active', child: Text('Active Only', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.w600))),
            DropdownMenuItem(value: 'inactive', child: Text('Inactive Only', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.w600))),
            DropdownMenuItem(value: 'in_stock', child: Text('In Stock', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.w600))),
            DropdownMenuItem(value: 'out_of_stock', child: Text('Out of Stock', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.w600))),
            DropdownMenuItem(value: 'veg', child: Text('Veg Only', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.w600))),
            DropdownMenuItem(value: 'non_veg', child: Text('Non-Veg Only', style: TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.w600))),
          ],
        ),
      ),
    );

    final viewToggle = Container(
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewToggleButton(
            icon: Icons.format_list_bulleted_rounded,
            label: 'List',
            isActive: !_isGridView,
            onTap: () => setState(() => _isGridView = false),
          ),
          _buildViewToggleButton(
            icon: Icons.grid_view_rounded,
            label: 'Grid',
            isActive: _isGridView,
            onTap: () => setState(() => _isGridView = true),
          ),
        ],
      ),
    );

    final importCsvBtn = OutlinedButton.icon(
      onPressed: _showCsvImportModal,
      icon: const Icon(Icons.file_upload_outlined, size: 14, color: _primaryNavy),
      label: const Text(
        'Import CSV',
        style: TextStyle(color: _primaryNavy, fontWeight: FontWeight.w700, fontSize: 11.5),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: _navyBorder, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        backgroundColor: _navyTint,
      ),
    );

    final addProductBtn = ElevatedButton.icon(
      onPressed: () => _openAddEditProductScreen(null, category),
      icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
      label: const Text(
        'Add Product',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryNavy,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 0,
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 10, vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              sortDropdown,
              const SizedBox(width: 6),
              filterDropdown,
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              viewToggle,
              const SizedBox(width: 6),
              if (isDesktop) ...[
                importCsvBtn,
                const SizedBox(width: 6),
              ],
              addProductBtn,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? _primaryNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isActive ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // PRODUCTS LIST (DESKTOP WIDE TABLE VIEW WITH 6-DOT DRAG HANDLE)
  // ===========================================================================
  Widget _buildProductsListView(List<MenuItemModel> products, String category) {
    final allSelected = products.isNotEmpty && products.every((p) => _selectedProductIds.contains(p.id));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Checkbox(
                    value: allSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedProductIds.addAll(products.map((p) => p.id));
                        } else {
                          _selectedProductIds.removeAll(products.map((p) => p.id));
                        }
                      });
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    activeColor: _primaryNavy,
                  ),
                ),
                const SizedBox(width: 26),
                const SizedBox(
                  width: 24,
                  child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                ),
                const Expanded(
                  flex: 4,
                  child: Text('Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                ),
                const Expanded(
                  flex: 2,
                  child: Text('Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                ),
                const SizedBox(
                  width: 60,
                  child: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                ),
                const SizedBox(
                  width: 80,
                  child: Text('Price', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                ),
                const SizedBox(
                  width: 80,
                  child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                ),
              ],
            ),
          ),

          // Table Rows List with 6-Dot Drag & Drop Reordering (NO Arrows)
          Expanded(
            child: ReorderableListView.builder(
              proxyDecorator: _reorderProxyDecorator,
              buildDefaultDragHandles: false,
              itemCount: products.length,
              onReorder: (oldIndex, newIndex) {
                _db.reorderCategoryProducts(category, oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final product = products[index];
                final isChecked = _selectedProductIds.contains(product.id);

                return KeyedSubtree(
                  key: ValueKey('prod_${product.id}_$index'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildProductTableRow(
                        product: product,
                        index: index,
                        isChecked: isChecked,
                        category: category,
                        totalProducts: products.length,
                      ),
                      if (index < products.length - 1)
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTableRow({
    required MenuItemModel product,
    required int index,
    required bool isChecked,
    required String category,
    required int totalProducts,
  }) {
    final inStock = product.stockQuantity > 0;

    return Container(
      color: isChecked ? _navyTint : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        children: [
          // 6-Dot Drag Handle (Icons.drag_indicator_rounded)
          ReorderableDragStartListener(
            index: index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.drag_indicator_rounded,
                  size: 17,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Row Checkbox
          SizedBox(
            width: 28,
            child: Checkbox(
              value: isChecked,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedProductIds.add(product.id);
                  } else {
                    _selectedProductIds.remove(product.id);
                  }
                });
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              activeColor: _primaryNavy,
            ),
          ),
          const SizedBox(width: 4),

          // Row Number (#)
          SizedBox(
            width: 24,
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
          ),

          // Product Info (Dynamic Thumbnail + Name + Description + FoodType)
          Expanded(
            flex: 4,
            child: Row(
              children: [
                _buildProductImageThumbnail(product, width: 34, height: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          FoodTypeIcon(itemType: product.itemType, size: 10),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (product.description.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          product.description,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stock Pill Badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: inStock ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: inStock ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                ),
                child: Text(
                  inStock ? '${product.stockQuantity} in stock' : 'Out of stock',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: inStock ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
          ),

          // Status Switch (High-contrast OFF state)
          SizedBox(
            width: 60,
            child: _buildToggleSwitch(
              value: product.isAvailable,
              onChanged: (val) {
                _db.saveMenuItem(product.copyWith(isAvailable: val));
                setState(() {});
              },
              scale: 0.68,
            ),
          ),

          // Price Column
          SizedBox(
            width: 80,
            child: Text(
              '₹${product.effectivePrice.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _primaryNavy,
              ),
            ),
          ),

          // Actions Column (Edit & Delete - Clean, NO arrows)
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => _openAddEditProductScreen(product, category),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.edit_outlined, size: 16, color: _primaryNavy),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => _confirmDeleteProduct(product),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // MOBILE RESPONSIVE PRODUCT LIST CARDS (For Android / Phones - NO Overflows)
  // ===========================================================================
  Widget _buildProductsMobileListView(List<MenuItemModel> products, String category) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      buildDefaultDragHandles: false,
      itemCount: products.length,
      onReorder: (oldIndex, newIndex) {
        _db.reorderCategoryProducts(category, oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final product = products[index];
        final isChecked = _selectedProductIds.contains(product.id);
        final inStock = product.stockQuantity > 0;

        return Container(
          key: ValueKey('mob_prod_${product.id}_$index'),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isChecked ? _navyTint : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isChecked ? _primaryNavy : const Color(0xFFE2E8F0),
              width: isChecked ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 6-Dot Drag Handle
              ReorderableDragStartListener(
                index: index,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.drag_indicator_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Checkbox
              SizedBox(
                width: 24,
                child: Checkbox(
                  value: isChecked,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedProductIds.add(product.id);
                      } else {
                        _selectedProductIds.remove(product.id);
                      }
                    });
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  activeColor: _primaryNavy,
                ),
              ),
              const SizedBox(width: 6),

              // Product Image
              _buildProductImageThumbnail(product, width: 40, height: 40),
              const SizedBox(width: 10),

              // Details (Name, food type, stock pill, price)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        FoodTypeIcon(itemType: product.itemType, size: 10),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 5,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '₹${product.effectivePrice.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _primaryNavy),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: inStock ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: inStock ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                          ),
                          child: Text(
                            inStock ? '${product.stockQuantity} in stock' : 'Out of stock',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: inStock ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // High-Contrast Switch & Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToggleSwitch(
                    value: product.isAvailable,
                    onChanged: (val) {
                      _db.saveMenuItem(product.copyWith(isAvailable: val));
                      setState(() {});
                    },
                    scale: 0.68,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16, color: _primaryNavy),
                    onPressed: () => _openAddEditProductScreen(product, category),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                    onPressed: () => _confirmDeleteProduct(product),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // PRODUCTS GRID VIEW (CARD GRID WITH DYNAMIC IMAGES - NO ARROWS)
  // ===========================================================================
  Widget _buildProductsGridView(List<MenuItemModel> products, String category, {required bool isDesktop}) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(isDesktop ? 16 : 10, 6, isDesktop ? 16 : 10, 12),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isDesktop ? 240 : 190,
        mainAxisExtent: isDesktop ? 245 : 235,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isChecked = _selectedProductIds.contains(product.id);
        final inStock = product.stockQuantity > 0;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isChecked ? _primaryNavy : const Color(0xFFE2E8F0),
              width: isChecked ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic Product Image Banner
              Container(
                height: isDesktop ? 95 : 85,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildProductImageThumbnail(
                        product,
                        width: double.infinity,
                        height: isDesktop ? 95 : 85,
                        borderRadius: 0,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: isChecked,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedProductIds.add(product.id);
                              } else {
                                _selectedProductIds.remove(product.id);
                              }
                            });
                          },
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          activeColor: _primaryNavy,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: inStock ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: inStock ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          inStock ? '${product.stockQuantity} in stock' : 'Out of stock',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: inStock ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Product Info & Price
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        FoodTypeIcon(itemType: product.itemType, size: 10),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '₹${product.effectivePrice.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _primaryNavy),
                        ),
                        _buildToggleSwitch(
                          value: product.isAvailable,
                          onChanged: (val) {
                            _db.saveMenuItem(product.copyWith(isAvailable: val));
                            setState(() {});
                          },
                          scale: 0.65,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Action Row (Clean Edit & Delete, NO Arrows)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 15, color: _primaryNavy),
                      onPressed: () => _openAddEditProductScreen(product, category),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(5),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                      onPressed: () => _confirmDeleteProduct(product),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Footer (Product Count + Delete Selected) with Responsive Wrapping
  Widget _buildProductsFooter(int productCount, {required bool isDesktop}) {
    final hasSelection = _selectedProductIds.isNotEmpty;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$productCount products • Drag handles to sort',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ElevatedButton.icon(
            onPressed: hasSelection ? _confirmDeleteSelectedProducts : null,
            icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.white),
            label: Text(
              hasSelection ? 'Delete Selected (${_selectedProductIds.length})' : 'Delete Selected',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasSelection ? const Color(0xFFEF4444) : const Color(0xFFCBD5E1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }



  // ===========================================================================
  // MOBILE TOP SEGMENTED TABS & REDESIGNED VIEWS (Android / Mobile Viewport)
  // ===========================================================================
  Widget _buildMobileTopSegmentedTabs() {
    return Container(
      color: _primaryNavyDark,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Container(
        padding: const EdgeInsets.all(3.5),
        decoration: BoxDecoration(
          color: _primaryNavyLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Categories Tab
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _mobileActiveTab = 'categories'),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _mobileActiveTab == 'categories' ? _primaryNavy : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _mobileActiveTab == 'categories'
                        ? [
                            BoxShadow(
                              color: _primaryNavy.withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.table_rows_rounded,
                        size: 15,
                        color: _mobileActiveTab == 'categories' ? Colors.white : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _mobileActiveTab == 'categories' ? FontWeight.w800 : FontWeight.w600,
                          color: _mobileActiveTab == 'categories' ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Products Tab
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _mobileActiveTab = 'products'),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _mobileActiveTab == 'products' ? _primaryNavy : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _mobileActiveTab == 'products'
                        ? [
                            BoxShadow(
                              color: _primaryNavy.withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 15,
                        color: _mobileActiveTab == 'products' ? Colors.white : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Products',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _mobileActiveTab == 'products' ? FontWeight.w800 : FontWeight.w600,
                          color: _mobileActiveTab == 'products' ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: _mobileActiveTab == 'categories'
          ? _buildMobileCategoriesView()
          : _buildMobileProductsView(),
    );
  }

  // --- Mobile Categories View (Clean & Responsive) ---
  Widget _buildMobileCategoriesView() {
    final rawCategories = _db.categories;
    final categories = _categorySearchQuery.trim().isEmpty
        ? rawCategories
        : rawCategories.where((c) => c.toLowerCase().contains(_categorySearchQuery.trim().toLowerCase())).toList();

    return Column(
      children: [
        // 1. Expandable Search + Add Category Row
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            firstCurve: Curves.easeInOut,
            secondCurve: Curves.easeInOut,
            sizeCurve: Curves.easeInOut,
            crossFadeState: _mobileCategorySearchExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Row(
              children: [
                // Search Icon Button
                InkWell(
                  onTap: () {
                    setState(() => _mobileCategorySearchExpanded = true);
                    Future.delayed(const Duration(milliseconds: 120), () {
                      if (mounted) _categorySearchFocus.requestFocus();
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.search_rounded, size: 20, color: _primaryNavy),
                  ),
                ),
                const Spacer(),

                // Add Category Button
                InkWell(
                  onTap: _showAddCategoryModal,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _primaryNavy,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryNavy.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Add', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            secondChild: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _primaryNavy, width: 1.5),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search_rounded, color: _primaryNavy, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _categorySearchController,
                      focusNode: _categorySearchFocus,
                      onChanged: (val) => setState(() => _categorySearchQuery = val),
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        hintText: 'Search categories...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  // Inside field cross icon to close search bar and restore Add button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _mobileCategorySearchExpanded = false;
                          _categorySearchQuery = '';
                          _categorySearchController.clear();
                        });
                        _categorySearchFocus.unfocus();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF475569)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 2. Reorderable Categories List
        Expanded(
          child: categories.isEmpty
              ? _buildEmptyCategoriesState()
              : ReorderableListView.builder(
                  proxyDecorator: _reorderProxyDecorator,
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  itemCount: categories.length,
                  onReorder: (oldIndex, newIndex) {
                    _db.reorderCategories(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isDisabled = _disabledCategories.contains(cat);
                    final productCount = _db.menuItems.where((m) => m.category.trim().toLowerCase() == cat.trim().toLowerCase()).length;

                    return Container(
                      key: ValueKey('mob_cat_$cat'),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // 6-dot drag handle
                          ReorderableDragStartListener(
                            index: index,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.drag_indicator_rounded, size: 18, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Dynamic Category Image Thumbnail
                          _buildCategoryImageThumbnail(cat, width: 44, height: 44, borderRadius: 10),
                          const SizedBox(width: 10),

                          // Category Title & Subtitle (Full name up to 2 lines)
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = cat;
                                  _mobileActiveTab = 'products';
                                });
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDisabled ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                      decoration: isDisabled ? TextDecoration.lineThrough : null,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$productCount products',
                                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Status Switch
                          _buildToggleSwitch(
                            value: !isDisabled,
                            onChanged: (val) => _toggleCategoryStatus(cat),
                            scale: 0.70,
                          ),

                          // Chevron Right Button
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF64748B)),
                            onPressed: () {
                              setState(() {
                                _selectedCategory = cat;
                                _mobileActiveTab = 'products';
                              });
                            },
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
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

  // --- Mobile Products View (Clean & Responsive) ---
  Widget _buildMobileProductsView() {
    final categories = _db.categories;
    final products = _getAllProductsFiltered();

    return Column(
      children: [
        // 1. Expandable Search + Action Row (Filter, CSV, Add)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            firstCurve: Curves.easeInOut,
            secondCurve: Curves.easeInOut,
            sizeCurve: Curves.easeInOut,
            crossFadeState: _mobileProductsSearchExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Row(
              children: [
                // Search Icon Button
                InkWell(
                  onTap: () {
                    setState(() => _mobileProductsSearchExpanded = true);
                    Future.delayed(const Duration(milliseconds: 120), () {
                      if (mounted) _productsSearchFocus.requestFocus();
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: _primaryNavy,
                    ),
                  ),
                ),
                const Spacer(),

                // Filter Icon Button
                InkWell(
                  onTap: _showMobileFilterModal,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: (_productFilter != 'all' || _productSortMode != 'custom')
                          ? _navyTint
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_productFilter != 'all' || _productSortMode != 'custom')
                            ? _primaryNavy
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.filter_alt_outlined,
                          size: 18,
                          color: (_productFilter != 'all' || _productSortMode != 'custom')
                              ? _primaryNavy
                              : const Color(0xFF0F172A),
                        ),
                        if (_productFilter != 'all' || _productSortMode != 'custom')
                          Positioned(
                            top: 7,
                            right: 7,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: _primaryNavy,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // + CSV Button (Direct 1-Tap Access)
                InkWell(
                  onTap: _showCsvImportModal,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    decoration: BoxDecoration(
                      color: _navyTint,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _navyBorder),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.file_upload_outlined, size: 15, color: _primaryNavy),
                        SizedBox(width: 4),
                        Text(
                          'CSV',
                          style: TextStyle(
                            color: _primaryNavy,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // + Add Button
                InkWell(
                  onTap: () => _openAddEditProductScreen(null, _selectedCategory),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _primaryNavy,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryNavy.withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            secondChild: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _primaryNavy, width: 1.5),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.search_rounded, color: _primaryNavy, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _productsSearchController,
                      focusNode: _productsSearchFocus,
                      onChanged: (val) => setState(() => _globalSearch = val),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search products...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  // Inside field cross icon to close search bar and restore action buttons
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _mobileProductsSearchExpanded = false;
                          _globalSearch = '';
                          _productsSearchController.clear();
                        });
                        _productsSearchFocus.unfocus();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 2. Category Quick Filter Chips
        if (categories.isNotEmpty)
          Container(
            height: 34,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: categories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isAllSelected = _selectedCategory == null;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => setState(() => _selectedCategory = null),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isAllSelected ? _primaryNavy : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isAllSelected ? _primaryNavy : const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          'All (${_db.menuItems.length})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isAllSelected ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final cat = categories[index - 1];
                final isSelected = _selectedCategory == cat;
                final count = _db.menuItems.where((m) => m.category.trim().toLowerCase() == cat.trim().toLowerCase()).length;

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategory = cat),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryNavy : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? _primaryNavy : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCategoryImageThumbnail(cat, width: 16, height: 16, isSelected: isSelected),
                          const SizedBox(width: 4),
                          Text(
                            '$cat ($count)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // 3. Reorderable Products List
        Expanded(
          child: products.isEmpty
              ? _buildEmptyProductsState(_selectedCategory ?? 'All')
              : ReorderableListView.builder(
                  proxyDecorator: _reorderProxyDecorator,
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  itemCount: products.length,
                  onReorder: (oldIndex, newIndex) {
                    if (_selectedCategory != null) {
                      _db.reorderCategoryProducts(_selectedCategory!, oldIndex, newIndex);
                    }
                  },
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final inStock = product.stockQuantity > 0;

                    return Container(
                      key: ValueKey('mob_prod_${product.id}_$index'),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // 6-dot drag handle
                          ReorderableDragStartListener(
                            index: index,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                                child: const Icon(Icons.drag_indicator_rounded, size: 18, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Dynamic Product Image Thumbnail
                          _buildProductImageThumbnail(product, width: 44, height: 44, borderRadius: 10),
                          const SizedBox(width: 8),

                          // Details Column (Full Name with maxLines: 2 + Price & Stock Row)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    FoodTypeIcon(itemType: product.itemType, size: 10),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                          height: 1.2,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Wrap(
                                  spacing: 5,
                                  runSpacing: 2,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '₹${product.effectivePrice.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                        color: _primaryNavy,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: inStock ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: inStock ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                                      ),
                                      child: Text(
                                        inStock ? '${product.stockQuantity} in stock' : 'Out of stock',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: inStock ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Status Switch
                          _buildToggleSwitch(
                            value: product.isAvailable,
                            onChanged: (val) {
                              _db.saveMenuItem(product.copyWith(isAvailable: val));
                              setState(() {});
                            },
                            scale: 0.68,
                          ),

                          // 3-Dots Menu Button
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (val) {
                              if (val == 'edit') _openAddEditProductScreen(product, product.category);
                              if (val == 'delete') _confirmDeleteProduct(product);
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 15, color: Color(0xFF0F172A)),
                                    SizedBox(width: 8),
                                    Text('Edit Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                                    SizedBox(width: 8),
                                    Text('Delete Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                                  ],
                                ),
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

  // --- Mobile Filter Modal Bottom Sheet ---
  void _showMobileFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + MediaQuery.of(ctx).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Filter & Sort Products',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(ctx),
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Status Filter Chips
                    const Text('Availability & Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildModalChip('All', _productFilter == 'all', () {
                          setState(() => _productFilter = 'all');
                          setModalState(() {});
                        }),
                        _buildModalChip('Active Only', _productFilter == 'active', () {
                          setState(() => _productFilter = 'active');
                          setModalState(() {});
                        }),
                        _buildModalChip('In Stock', _productFilter == 'in_stock', () {
                          setState(() => _productFilter = 'in_stock');
                          setModalState(() {});
                        }),
                        _buildModalChip('Out of Stock', _productFilter == 'out_of_stock', () {
                          setState(() => _productFilter = 'out_of_stock');
                          setModalState(() {});
                        }),
                        _buildModalChip('Veg Only', _productFilter == 'veg', () {
                          setState(() => _productFilter = 'veg');
                          setModalState(() {});
                        }),
                        _buildModalChip('Non-Veg Only', _productFilter == 'non_veg', () {
                          setState(() => _productFilter = 'non_veg');
                          setModalState(() {});
                        }),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Sort Options
                    const Text('Sort By', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildModalChip('Custom (Drag)', _productSortMode == 'custom', () {
                          setState(() => _productSortMode = 'custom');
                          setModalState(() {});
                        }),
                        _buildModalChip('Name (A → Z)', _productSortMode == 'name_asc', () {
                          setState(() => _productSortMode = 'name_asc');
                          setModalState(() {});
                        }),
                        _buildModalChip('Price (Low → High)', _productSortMode == 'price_asc', () {
                          setState(() => _productSortMode = 'price_asc');
                          setModalState(() {});
                        }),
                        _buildModalChip('Price (High → Low)', _productSortMode == 'price_desc', () {
                          setState(() => _productSortMode = 'price_desc');
                          setModalState(() {});
                        }),
                      ],
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryNavy,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                        child: const Text('Apply Filter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _primaryNavy : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? _primaryNavy : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATES
  // ===========================================================================
  Widget _buildEmptyCategoriesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.category_outlined, size: 40, color: Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            const Text(
              'No categories found',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Add your first category to start organizing items.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showAddCategoryModal,
              icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
              label: const Text('Add Category', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryNavy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCategorySelectedState() {
    return const Center(
      child: Text(
        'Select a category to view products',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
      ),
    );
  }

  Widget _buildEmptyProductsState(String category) {
    final isSearching = _globalSearch.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching ? Icons.search_off_rounded : Icons.fastfood_outlined,
              size: 42,
              color: const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 10),
            Text(
              isSearching ? 'No products found' : 'No products in "$category"',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              isSearching
                  ? 'No items matched "$_globalSearch". Try another keyword.'
                  : 'Add delicious dishes and beverages under this category.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            if (isSearching)
              OutlinedButton(
                onPressed: () => setState(() => _globalSearch = ''),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Clear Search', style: TextStyle(fontSize: 11.5)),
              )
            else
              ElevatedButton.icon(
                onPressed: () => _openAddEditProductScreen(null, category),
                icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                label: const Text('Add Product', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  elevation: 0,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MODALS & DIALOGS
  // ===========================================================================

  // Preview Menu Modal (No emojis)
  void _showMenuPreviewModal() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 580),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _primaryNavy,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.visibility_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _db.restaurant?.name ?? 'Live Digital Menu Preview',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const Text(
                            'Customer-facing visual menu simulation',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 10),

                  // Menu Preview Content
                  Expanded(
                    child: ListView.builder(
                      itemCount: _db.categories.length,
                      itemBuilder: (context, catIdx) {
                        final cat = _db.categories[catIdx];
                        final items = _db.menuItems.where((m) => m.category.trim().toLowerCase() == cat.trim().toLowerCase()).toList();
                        if (items.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  _buildCategoryImageThumbnail(cat, width: 24, height: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    cat,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${items.length} items',
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 200,
                                mainAxisExtent: 145,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: items.length,
                              itemBuilder: (context, itemIdx) {
                                final item = items[itemIdx];
                                return Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildProductImageThumbnail(item, width: 30, height: 30),
                                          FoodTypeIcon(itemType: item.itemType, size: 12),
                                        ],
                                      ),
                                      const Spacer(),
                                      Text(
                                        item.name,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${item.effectivePrice.toStringAsFixed(0)}',
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _primaryNavy),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
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
    );
  }

  // Add Category Modal (with Cloudflare R2 Image Upload & Sync)
  void _showAddCategoryModal() {
    final catCtrl = TextEditingController();
    String? pickedImagePath;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.all(20),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _primaryNavy,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.category_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Add New Category',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: catCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      hintText: 'e.g. Starters, Beverages, Desserts',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _primaryNavy, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category Image Section
                  const Text(
                    'Category Image (Optional)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        if (isUploading) ...[
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _navyTint,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const CircularProgressIndicator(strokeWidth: 2, color: _primaryNavy),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Uploading to Cloudflare R2...',
                              style: TextStyle(fontSize: 11.5, color: _primaryNavy, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ] else if (pickedImagePath != null && pickedImagePath!.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 38,
                              height: 38,
                              child: pickedImagePath!.startsWith('http')
                                  ? Image.network(pickedImagePath!, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => const Icon(Icons.image_rounded, color: Color(0xFF64748B)))
                                  : Image.file(File(pickedImagePath!), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_rounded, color: Color(0xFF64748B))),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  pickedImagePath!.startsWith('http') ? 'Cloudflare R2 Image' : pickedImagePath!.split(Platform.pathSeparator).last,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (pickedImagePath!.startsWith('http'))
                                  const Text(
                                    'Saved in cloud',
                                    style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFEF4444)),
                            onPressed: () => setModalState(() => pickedImagePath = null),
                          ),
                        ] else ...[
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _navyTint,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.add_photo_alternate_rounded, color: _primaryNavy, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No image selected',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                              );
                              if (result != null && result.files.isNotEmpty) {
                                final fileItem = result.files.single;
                                setModalState(() => isUploading = true);
                                try {
                                    if (fileItem.path != null && fileItem.path!.isNotEmpty) {
                                    final uploadUrl = await UploadService().uploadImage(File(fileItem.path!), folder: 'categories');
                                    setModalState(() {
                                      pickedImagePath = (uploadUrl != null && uploadUrl.isNotEmpty) ? uploadUrl : fileItem.path;
                                      isUploading = false;
                                    });
                                  } else if (fileItem.bytes != null) {
                                    final uploadUrl = await UploadService().uploadImageBytes(fileItem.bytes!, fileName: fileItem.name, folder: 'categories');
                                    setModalState(() {
                                      pickedImagePath = uploadUrl;
                                      isUploading = false;
                                    });
                                  } else {
                                    setModalState(() => isUploading = false);
                                  }
                                } catch (e) {
                                  debugPrint('[AddCategoryModal] R2 upload error: $e');
                                  setModalState(() {
                                    pickedImagePath = fileItem.path;
                                    isUploading = false;
                                  });
                                }
                              }
                            },
                            icon: const Icon(Icons.upload_rounded, size: 13, color: _primaryNavy),
                            label: const Text('Browse', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _primaryNavy)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _navyBorder),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              backgroundColor: _navyTint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: isUploading
                            ? null
                            : () async {
                                final name = catCtrl.text.trim();
                                if (name.isNotEmpty) {
                                  if (pickedImagePath != null && pickedImagePath!.isNotEmpty && !pickedImagePath!.startsWith('http')) {
                                    setModalState(() => isUploading = true);
                                    try {
                                      final uploadUrl = await UploadService().uploadImage(File(pickedImagePath!), folder: 'categories');
                                      if (uploadUrl != null && uploadUrl.isNotEmpty) {
                                        pickedImagePath = uploadUrl;
                                      }
                                    } catch (_) {}
                                  }
                                  await _db.addCategory(name, imagePath: pickedImagePath);
                                  if (pickedImagePath != null && pickedImagePath!.isNotEmpty) {
                                    await _db.saveCategoryImage(name, pickedImagePath!);
                                  }
                                  if (mounted) {
                                    setState(() {
                                      _selectedCategory = name;
                                    });
                                  }
                                  if (dialogCtx.mounted) {
                                    Navigator.pop(dialogCtx);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryNavy,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                        label: const Text('Save Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Edit Category Modal (with Cloudflare R2 Image Upload & Sync)
  void _showEditCategoryModal(String oldCategory) {
    final catCtrl = TextEditingController(text: oldCategory);
    String? pickedImagePath = _db.getCategoryImage(oldCategory);
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.all(20),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _primaryNavy,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Edit Category',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: catCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _primaryNavy, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category Image Section
                  const Text(
                    'Category Image',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        if (isUploading) ...[
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _navyTint,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const CircularProgressIndicator(strokeWidth: 2, color: _primaryNavy),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Uploading to Cloudflare R2...',
                              style: TextStyle(fontSize: 11.5, color: _primaryNavy, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ] else if (pickedImagePath != null && pickedImagePath!.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 38,
                              height: 38,
                              child: pickedImagePath!.startsWith('http')
                                  ? Image.network(pickedImagePath!, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => const Icon(Icons.image_rounded, color: Color(0xFF64748B)))
                                  : Image.file(File(pickedImagePath!), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_rounded, color: Color(0xFF64748B))),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  pickedImagePath!.startsWith('http') ? 'Cloudflare R2 Image' : pickedImagePath!.split(Platform.pathSeparator).last,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (pickedImagePath!.startsWith('http'))
                                  const Text(
                                    'Saved in cloud',
                                    style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFEF4444)),
                            onPressed: () => setModalState(() => pickedImagePath = null),
                          ),
                        ] else ...[
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _navyTint,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.add_photo_alternate_rounded, color: _primaryNavy, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No image selected',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
                              );
                              if (result != null && result.files.isNotEmpty) {
                                final fileItem = result.files.single;
                                setModalState(() => isUploading = true);
                                try {
                                  if (fileItem.path != null && fileItem.path!.isNotEmpty) {
                                    final uploadUrl = await UploadService().uploadImage(File(fileItem.path!), folder: 'categories');
                                    setModalState(() {
                                      pickedImagePath = (uploadUrl != null && uploadUrl.isNotEmpty) ? uploadUrl : fileItem.path;
                                      isUploading = false;
                                    });
                                  } else if (fileItem.bytes != null) {
                                    final uploadUrl = await UploadService().uploadImageBytes(fileItem.bytes!, fileName: fileItem.name, folder: 'categories');
                                    setModalState(() {
                                      pickedImagePath = uploadUrl;
                                      isUploading = false;
                                    });
                                  } else {
                                    setModalState(() => isUploading = false);
                                  }
                                } catch (e) {
                                  debugPrint('[EditCategoryModal] R2 upload error: $e');
                                  setModalState(() {
                                    pickedImagePath = fileItem.path;
                                    isUploading = false;
                                  });
                                }
                              }
                            },
                            icon: const Icon(Icons.upload_rounded, size: 13, color: _primaryNavy),
                            label: const Text('Change', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _primaryNavy)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _navyBorder),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              backgroundColor: _navyTint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: isUploading
                            ? null
                            : () async {
                                final newName = catCtrl.text.trim();
                                if (newName.isNotEmpty) {
                                  if (pickedImagePath != null && pickedImagePath!.isNotEmpty && !pickedImagePath!.startsWith('http')) {
                                    setModalState(() => isUploading = true);
                                    try {
                                      final uploadUrl = await UploadService().uploadImage(File(pickedImagePath!), folder: 'categories');
                                      if (uploadUrl != null && uploadUrl.isNotEmpty) {
                                        pickedImagePath = uploadUrl;
                                      }
                                    } catch (_) {}
                                  }
                                  if (newName != oldCategory) {
                                    await _db.editCategory(oldCategory, newName);
                                  }
                                  if (pickedImagePath != null && pickedImagePath!.isNotEmpty) {
                                    await _db.saveCategoryImage(newName, pickedImagePath!);
                                  } else {
                                    await _db.removeCategoryImage(newName);
                                  }
                                  if (mounted) {
                                    setState(() {
                                      if (_selectedCategory == oldCategory) {
                                        _selectedCategory = newName;
                                      }
                                    });
                                  }
                                  if (dialogCtx.mounted) {
                                    Navigator.pop(dialogCtx);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryNavy,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                        label: const Text('Update Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Delete Product
  void _confirmDeleteProduct(MenuItemModel dish) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.all(18),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              'Delete "${dish.name}"?',
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Are you sure you want to delete this product from the menu?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _db.deleteMenuItem(dish.id);
                      _selectedProductIds.remove(dish.id);
                      if (!mounted) return;
                      setState(() {});
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.white),
                    label: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Delete Category
  void _confirmDeleteCategory(String categoryName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.all(18),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              'Delete Category "$categoryName"?',
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Deleting a category will remove it from the menu filters.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _db.deleteCategory(categoryName);
                      await _db.removeCategoryImage(categoryName);
                      if (_selectedCategory == categoryName) {
                        _selectedCategory = _db.categories.isNotEmpty ? _db.categories.first : null;
                      }
                      if (!mounted) return;
                      setState(() {});
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.white),
                    label: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Batch Delete Selected Products
  void _confirmDeleteSelectedProducts() {
    final count = _selectedProductIds.length;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.all(18),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              'Delete $count Selected Products?',
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'These products will be removed from your menu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      for (final id in _selectedProductIds.toList()) {
                        await _db.deleteMenuItem(id);
                      }
                      _selectedProductIds.clear();
                      if (!mounted) return;
                      setState(() {});
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.white),
                    label: const Text('Delete All', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- CSV Import & Export Utilities ---
  void _showCsvImportModal() {
    bool isProcessing = false;
    String? modalError;
    String? modalSuccess;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                              color: _primaryNavy,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.table_chart_rounded, color: Colors.white, size: 17),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Import Products via CSV', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                Text('Bulk add products using CSV template', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (modalError != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                          child: Text(modalError!, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),

                      if (modalSuccess != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                          child: Text(modalSuccess!, style: const TextStyle(color: Color(0xFF14532D), fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),

                      // Step 1: Download Template
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Step 1: Download Sample Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  Directory? targetDir;
                                  try {
                                    targetDir = await getDownloadsDirectory();
                                  } catch (_) {}
                                  targetDir ??= await getApplicationDocumentsDirectory();

                                  final filePath = '${targetDir.path}/Apna_POS_Menu_Template.csv';
                                  const sampleCsv =
                                      'Product Name,Description,Food Type,Price,Variant Name,Variant Price,Category\n'
                                      'Shahi Paneer,Rich and creamy paneer curry,Veg,230,,0,Main Course\n'
                                      'Dal Tadka,Classic yellow dal with tadka,Veg,199,,0,Main Course\n'
                                      'Butter Naan,Crispy clay oven bread,Veg,45,,0,Bread\n';

                                  final file = File(filePath);
                                  await file.writeAsString(sampleCsv);
                                  setModalState(() => modalSuccess = 'Sample template saved to:\n$filePath');
                                } catch (e) {
                                  setModalState(() => modalError = 'Failed to download template: $e');
                                }
                              },
                              icon: const Icon(Icons.download_rounded, size: 14, color: Colors.white),
                              label: const Text('Download CSV Template', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Step 2: Upload CSV
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Step 2: Upload Filled CSV File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 6),
                            ElevatedButton.icon(
                              onPressed: isProcessing
                                  ? null
                                  : () async {
                                      try {
                                        setModalState(() => isProcessing = true);
                                        final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
                                        if (result == null || result.files.isEmpty) {
                                          setModalState(() => isProcessing = false);
                                          return;
                                        }

                                        final file = result.files.single;
                                        String csvContent = '';
                                        if (file.path != null) {
                                          csvContent = await File(file.path!).readAsString();
                                        } else if (file.bytes != null) {
                                          csvContent = utf8.decode(file.bytes!);
                                        }

                                        final lines = const LineSplitter().convert(csvContent);
                                        if (lines.length <= 1) {
                                          setModalState(() {
                                            isProcessing = false;
                                            modalError = 'CSV file has no data rows.';
                                          });
                                          return;
                                        }

                                        final List<MenuItemModel> items = [];
                                        for (int i = 1; i < lines.length; i++) {
                                          final cols = lines[i].split(',');
                                          if (cols.isEmpty || cols[0].trim().isEmpty) continue;
                                          final pName = cols[0].trim();
                                          final pDesc = cols.length > 1 ? cols[1].trim() : '';
                                          final pType = cols.length > 2 ? cols[2].trim() : 'Veg';
                                          final pPrice = cols.length > 3 ? (double.tryParse(cols[3].trim()) ?? 0.0) : 0.0;
                                          final pCat = cols.length > 6 ? cols[6].trim() : 'General';

                                          items.add(MenuItemModel(
                                            id: 'PRD-${DateTime.now().millisecondsSinceEpoch}-$i',
                                            name: pName,
                                            description: pDesc,
                                            category: pCat.isNotEmpty ? pCat : 'General',
                                            price: pPrice,
                                            itemType: pType,
                                            stockQuantity: 50,
                                            isAvailable: true,
                                          ));
                                        }

                                        final count = await _db.importProductsFromCsv(items);
                                        if (!context.mounted) return;
                                        Navigator.pop(context);
                                        setState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Successfully imported $count products'),
                                            backgroundColor: const Color(0xFF15803D),
                                          ),
                                        );
                                      } catch (e) {
                                        setModalState(() {
                                          isProcessing = false;
                                          modalError = 'Error: $e';
                                        });
                                      }
                                    },
                              icon: isProcessing ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.file_upload_rounded, size: 14, color: Colors.white),
                              label: Text(isProcessing ? 'Importing...' : 'Choose & Upload CSV File', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              style: ElevatedButton.styleFrom(backgroundColor: _primaryNavy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), elevation: 0),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _exportCsv() async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('Product Name,Category,Price,Food Type,Stock,Status,Description');
      for (final item in _db.menuItems) {
        buffer.writeln('"${item.name}","${item.category}",${item.price},"${item.itemType}",${item.stockQuantity},${item.isAvailable ? "Active" : "Inactive"},"${item.description}"');
      }

      Directory? dir;
      try {
        dir = await getDownloadsDirectory();
      } catch (_) {}
      dir ??= await getApplicationDocumentsDirectory();

      final file = File('${dir.path}/Apna_POS_Menu_Export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      if (Platform.isWindows) {
        try {
          await Process.run('cmd', ['/c', 'start', '', file.path]);
        } catch (_) {}
      } else {
        try {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(file.path)],
              text: 'Apna POS Menu Export',
            ),
          );
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported successfully to: ${file.path}'),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
