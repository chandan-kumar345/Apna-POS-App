import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  static const Color _navyTint = Color(0xFFEFF4FA);
  static const Color _navyBorder = Color(0xFFCBDDF7);

  // Selection & View State
  String? _selectedCategory;
  bool _isGridView = false; // List vs Grid View Toggle
  bool _mobileSearchExpanded = false; // Mobile top bar inline search toggle
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
    if (_selectedCategory != null && _selectedCategory != 'All') {
      if (!_db.categories.contains(_selectedCategory)) {
        _selectedCategory = null;
      }
    }
  }

  // --- Reorder Proxy Decorator: Eliminates Default Dark Blue / Purple Drag Tint ---
  Widget _reorderProxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double elevation = 3.0 + (animValue * 5.0);
        return Transform.scale(
          scale: 1.0 + (animValue * 0.02),
          child: Material(
            elevation: elevation,
            color: Colors.transparent,
            shadowColor: const Color(0xFF0F2B48).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
            child: child,
          ),
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

  // --- High-Contrast Modern Animated Toggle Switch Widget ---
  Widget _buildToggleSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
    double scale = 1.0,
    Color activeColor = const Color(0xFF0F2B48),
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        width: 44 * scale,
        height: 24 * scale,
        padding: EdgeInsets.all(2.5 * scale),
        decoration: BoxDecoration(
          color: value ? activeColor : const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(16 * scale),
          boxShadow: [
            BoxShadow(
              color: (value ? activeColor : const Color(0xFF94A3B8)).withValues(alpha: 0.25),
              blurRadius: 3,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 19 * scale,
            height: 19 * scale,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
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
      final trimmed = rawUrl.trim();
      if (trimmed.startsWith('data:image') || trimmed.startsWith('data:') || (trimmed.length > 80 && !trimmed.contains('/') && !trimmed.contains('\\'))) {
        try {
          final commaIdx = trimmed.indexOf(',');
          final base64Clean = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
          final bytes = base64Decode(base64Clean.replaceAll('\n', '').replaceAll('\r', '').trim());
          imageWidget = Image.memory(
            bytes,
            width: width,
            height: height,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => _buildFallbackProductIcon(width, height),
          );
        } catch (_) {}
      }

      if (imageWidget == null) {
        final resolved = ApiEndpoints.resolveMediaUrl(trimmed);
        if (resolved.isNotEmpty) {
          if (resolved.startsWith('data:image') || resolved.startsWith('data:')) {
            try {
              final commaIdx = resolved.indexOf(',');
              final base64Clean = commaIdx != -1 ? resolved.substring(commaIdx + 1) : resolved;
              final bytes = base64Decode(base64Clean.replaceAll('\n', '').replaceAll('\r', '').trim());
              imageWidget = Image.memory(
                bytes,
                width: width,
                height: height,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => _buildFallbackProductIcon(width, height),
              );
            } catch (_) {}
          } else if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
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
      final trimmed = imagePath.trim();
      if (trimmed.startsWith('data:image') || trimmed.startsWith('data:') || (trimmed.length > 80 && !trimmed.contains('/') && !trimmed.contains('\\'))) {
        try {
          final commaIdx = trimmed.indexOf(',');
          final base64Clean = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
          final bytes = base64Decode(base64Clean.replaceAll('\n', '').replaceAll('\r', '').trim());
          imageWidget = Image.memory(
            bytes,
            width: width,
            height: height,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => _buildCategoryIconFallback(category, width, height, isSelected),
          );
        } catch (_) {}
      }

      if (imageWidget == null) {
        final resolved = ApiEndpoints.resolveMediaUrl(trimmed);
        if (resolved.isNotEmpty) {
          if (resolved.startsWith('data:image') || resolved.startsWith('data:')) {
            try {
              final commaIdx = resolved.indexOf(',');
              final base64Clean = commaIdx != -1 ? resolved.substring(commaIdx + 1) : resolved;
              final bytes = base64Decode(base64Clean.replaceAll('\n', '').replaceAll('\r', '').trim());
              imageWidget = Image.memory(
                bytes,
                width: width,
                height: height,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => _buildCategoryIconFallback(category, width, height, isSelected),
              );
            } catch (_) {}
          } else if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
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
      backgroundColor: isDesktop ? const Color(0xFFF8FAFC) : const Color(0xFFEDF3FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top drag handle pill for mobile
            if (!isDesktop)
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

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
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 6,
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
                        Text('Import CSV Spreadsheet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export_csv',
                    child: Row(
                      children: [
                        Icon(Icons.download_rounded, size: 16, color: _primaryNavy),
                        SizedBox(width: 8),
                        Text('Export Menu to CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'sync',
                    child: Row(
                      children: [
                        Icon(Icons.sync_rounded, size: 16, color: _primaryNavy),
                        SizedBox(width: 8),
                        Text('Sync with Cloud', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
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
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 6,
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
                          Text('Edit Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
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
                            Text('Move Up', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
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
                            Text('Move Down', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
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
    final String category = _selectedCategory ?? 'All';
    final products = _selectedCategory == null ? _getAllProductsFiltered() : _getCategoryProducts(category);
    final activeCount = _selectedCategory == null
        ? _db.menuItems.where((m) => m.isAvailable).length
        : _getCategoryActiveCount(category);
    final totalStock = _selectedCategory == null
        ? _db.menuItems.fold(0, (sum, m) => sum + (m.stockQuantity > 0 ? m.stockQuantity : 0))
        : _getCategoryTotalStock(category);

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
    final isAll = _selectedCategory == null || _selectedCategory == 'All';

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
                  isAll ? 'All Products' : category,
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

          if (!isAll) ...[
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
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 6,
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
                      Text('Add Product to Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
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
                                if (product.variants.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F3FF),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: const Color(0xFFDDD6FE)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.tune_rounded, size: 9, color: Color(0xFF7C3AED)),
                                        const SizedBox(width: 2.5),
                                        Text(
                                          '${product.variants.length} Var',
                                          style: const TextStyle(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF7C3AED),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
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
                        if (product.variants.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: const Color(0xFFDDD6FE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tune_rounded, size: 9, color: Color(0xFF7C3AED)),
                                const SizedBox(width: 2.5),
                                Text(
                                  '${product.variants.length} Var',
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '₹${product.effectivePrice.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _primaryNavy),
                            ),
                            if (product.variants.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F3FF),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: const Color(0xFFDDD6FE)),
                                ),
                                child: Text(
                                  '${product.variants.length} Var',
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                              ),
                            ],
                          ],
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
      color: const Color(0xFFEDF3FA),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFEDF3FA),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.95),
              offset: const Offset(-2, -2),
              blurRadius: 5,
            ),
            BoxShadow(
              color: const Color(0xFF0F2B48).withValues(alpha: 0.08),
              offset: const Offset(2, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            // Categories Tab
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _mobileActiveTab = 'categories'),
                borderRadius: BorderRadius.circular(22),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _mobileActiveTab == 'categories' ? const Color(0xFF0F2B48) : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: _mobileActiveTab == 'categories'
                        ? [
                            BoxShadow(
                              color: const Color(0xFF0F2B48).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        size: 16,
                        color: _mobileActiveTab == 'categories' ? Colors.white : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Categories',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _mobileActiveTab == 'categories' ? FontWeight.w800 : FontWeight.w600,
                          color: _mobileActiveTab == 'categories' ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Products Tab
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _mobileActiveTab = 'products'),
                borderRadius: BorderRadius.circular(22),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _mobileActiveTab == 'products' ? const Color(0xFF0F2B48) : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: _mobileActiveTab == 'products'
                        ? [
                            BoxShadow(
                              color: const Color(0xFF0F2B48).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_rounded,
                        size: 16,
                        color: _mobileActiveTab == 'products' ? Colors.white : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Products',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _mobileActiveTab == 'products' ? FontWeight.w800 : FontWeight.w600,
                          color: _mobileActiveTab == 'products' ? Colors.white : const Color(0xFF64748B),
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
      color: const Color(0xFFEDF3FA),
      child: _mobileActiveTab == 'categories'
          ? _buildMobileCategoriesView()
          : _buildMobileProductsView(),
    );
  }

  // --- Mobile Categories View (Clean, Compact & Neumorphic) ---
  Widget _buildMobileCategoriesView() {
    final rawCategories = _db.categories;
    final categories = _categorySearchQuery.trim().isEmpty
        ? rawCategories
        : rawCategories.where((c) => c.toLowerCase().contains(_categorySearchQuery.trim().toLowerCase())).toList();

    return Column(
      children: [
        // 1. Inset Search Bar + Add Category Button Row
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: Row(
            children: [
              // Inset Neumorphic Search Bar
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF3FA),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F2B48).withValues(alpha: 0.05),
                        offset: const Offset(1.5, 2),
                        blurRadius: 3,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.8),
                        offset: const Offset(-1.5, -2),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 17, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _categorySearchController,
                          focusNode: _categorySearchFocus,
                          onChanged: (val) => setState(() => _categorySearchQuery = val),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search categories...',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      if (_categorySearchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _categorySearchQuery = '';
                              _categorySearchController.clear();
                            });
                          },
                          child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Deep Navy Add Category Button
              InkWell(
                onTap: _showAddCategoryModal,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F2B48),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F2B48).withValues(alpha: 0.3),
                        blurRadius: 6,
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Reorderable Categories List with Compact Neumorphic Cards
        Expanded(
          child: categories.isEmpty
              ? _buildEmptyCategoriesState()
              : ReorderableListView.builder(
                  proxyDecorator: _reorderProxyDecorator,
                  buildDefaultDragHandles: false,
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
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
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FBFE),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F2B48).withValues(alpha: 0.05),
                            offset: const Offset(1.5, 3),
                            blurRadius: 6,
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.9),
                            offset: const Offset(-1.5, -2),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // 6-dot drag handle with generous touch target
                          ReorderableDragStartListener(
                            index: index,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                color: Colors.transparent,
                                child: const Icon(Icons.drag_indicator_rounded, size: 18, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Dynamic Category Image Thumbnail (42x42 with 10px radius)
                          _buildCategoryImageThumbnail(cat, width: 42, height: 42, borderRadius: 10),
                          const SizedBox(width: 8),

                          // Category Title & Subtitle
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
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDisabled ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                      decoration: isDisabled ? TextDecoration.lineThrough : null,
                                      height: 1.15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3.5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFDBEAFE)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.inventory_2_outlined, size: 9.5, color: Color(0xFF1D4ED8)),
                                        const SizedBox(width: 3),
                                        Text(
                                          '$productCount products',
                                          style: const TextStyle(fontSize: 8.5, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Status Switch
                          _buildToggleSwitch(
                            value: !isDisabled,
                            onChanged: (val) => _toggleCategoryStatus(cat),
                            scale: 0.82,
                          ),
                          const SizedBox(width: 2),

                          // 3-Dots Menu Button
                          PopupMenuButton<String>(
                            color: Colors.white,
                            surfaceTintColor: Colors.transparent,
                            elevation: 6,
                            icon: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Icon(Icons.more_vert_rounded, size: 15, color: Color(0xFF64748B)),
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (val) {
                              if (val == 'view') {
                                setState(() {
                                  _selectedCategory = cat;
                                  _mobileActiveTab = 'products';
                                });
                              } else if (val == 'edit') {
                                _showEditCategoryModal(cat);
                              } else if (val == 'delete') {
                                _confirmDeleteCategory(cat);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: Row(
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 15, color: Color(0xFF0F172A)),
                                    SizedBox(width: 8),
                                    Text('View Products', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 15, color: Color(0xFF0F172A)),
                                    SizedBox(width: 8),
                                    Text('Edit Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
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
                  },
                ),
        ),
      ],
    );
  }

  // --- Mobile Products View (Clean, Compact & Neumorphic Matching Image) ---
  Widget _buildMobileProductsView() {
    final categories = _db.categories;
    final products = _getAllProductsFiltered();

    return Column(
      children: [
        // 1. Inset Search Bar + Action Row (Filter, CSV, Add)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
          child: Row(
            children: [
              // Inset Search Field
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF3FA),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F2B48).withValues(alpha: 0.05),
                        offset: const Offset(1.5, 2),
                        blurRadius: 3,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.8),
                        offset: const Offset(-1.5, -2),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 17, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _productsSearchController,
                          focusNode: _productsSearchFocus,
                          onChanged: (val) => setState(() => _globalSearch = val),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search products...',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      if (_globalSearch.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _globalSearch = '';
                              _productsSearchController.clear();
                            });
                          },
                          child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Filter Icon Button (Soft Square)
              InkWell(
                onTap: _showMobileFilterModal,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (_productFilter != 'all' || _productSortMode != 'custom')
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFFEDF3FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F2B48).withValues(alpha: 0.06),
                        offset: const Offset(1.5, 2),
                        blurRadius: 3,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.9),
                        offset: const Offset(-1.5, -2),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.filter_alt_outlined,
                        size: 18,
                        color: (_productFilter != 'all' || _productSortMode != 'custom')
                            ? const Color(0xFF0F2B48)
                            : const Color(0xFF475569),
                      ),
                      if (_productFilter != 'all' || _productSortMode != 'custom')
                        Positioned(
                          top: 7,
                          right: 7,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0F2B48),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // CSV Button
              InkWell(
                onTap: _showCsvImportModal,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF3FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F2B48).withValues(alpha: 0.06),
                        offset: const Offset(1.5, 2),
                        blurRadius: 3,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.9),
                        offset: const Offset(-1.5, -2),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_rounded, size: 16, color: Color(0xFF475569)),
                      SizedBox(width: 4),
                      Text(
                        'CSV',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Add Product Button
              InkWell(
                onTap: () => _openAddEditProductScreen(null, _selectedCategory),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F2B48),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F2B48).withValues(alpha: 0.3),
                        blurRadius: 6,
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Category Quick Filter Chips
        if (categories.isNotEmpty)
          Container(
            height: 36,
            margin: const EdgeInsets.only(top: 6, bottom: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: categories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isAllSelected = _selectedCategory == null;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedCategory = null),
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isAllSelected ? const Color(0xFF0F2B48) : const Color(0xFFEDF3FA),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isAllSelected ? const Color(0xFF0F2B48) : Colors.white,
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isAllSelected
                                  ? const Color(0xFF0F2B48).withValues(alpha: 0.25)
                                  : const Color(0xFF0F2B48).withValues(alpha: 0.05),
                              offset: const Offset(1, 2),
                              blurRadius: 3,
                            ),
                            if (!isAllSelected)
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.8),
                                offset: const Offset(-1, -1),
                                blurRadius: 3,
                              ),
                          ],
                        ),
                        child: Text(
                          'All (${_db.menuItems.length})',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isAllSelected ? Colors.white : const Color(0xFF475569),
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
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategory = cat),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0F2B48) : const Color(0xFFEDF3FA),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0F2B48) : Colors.white,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? const Color(0xFF0F2B48).withValues(alpha: 0.25)
                                : const Color(0xFF0F2B48).withValues(alpha: 0.05),
                            offset: const Offset(1, 2),
                            blurRadius: 3,
                          ),
                          if (!isSelected)
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.8),
                              offset: const Offset(-1, -1),
                              blurRadius: 3,
                            ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildCategoryImageThumbnail(cat, width: 16, height: 16, isSelected: isSelected),
                          const SizedBox(width: 5),
                          Text(
                            '$cat ($count)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
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

        // 3. Reorderable Products List with Compact Neumorphic Cards
        Expanded(
          child: products.isEmpty
              ? _buildEmptyProductsState(_selectedCategory ?? 'All')
              : ReorderableListView.builder(
                  proxyDecorator: _reorderProxyDecorator,
                  buildDefaultDragHandles: false,
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
                  itemCount: products.length,
                  onReorder: (oldIndex, newIndex) {
                    if (_selectedCategory == null || _selectedCategory == 'All') {
                      _db.reorderAllProducts(oldIndex, newIndex);
                    } else {
                      _db.reorderCategoryProducts(_selectedCategory!, oldIndex, newIndex);
                    }
                  },
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final inStock = product.stockQuantity > 0;

                    return Container(
                      key: ValueKey('mob_prod_${product.id}_$index'),
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FBFE),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F2B48).withValues(alpha: 0.05),
                            offset: const Offset(1.5, 3),
                            blurRadius: 6,
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.9),
                            offset: const Offset(-1.5, -2),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // 6-dot drag handle with generous touch target
                          ReorderableDragStartListener(
                            index: index,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                color: Colors.transparent,
                                child: const Icon(Icons.drag_indicator_rounded, size: 18, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          // Dynamic Product Image Thumbnail (42x42 with 10px radius)
                          _buildProductImageThumbnail(product, width: 42, height: 42, borderRadius: 10),
                          const SizedBox(width: 8),

                          // Details Column
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
                                          height: 1.15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3.5),
                                Wrap(
                                  spacing: 5,
                                  runSpacing: 3,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    // Price capsule
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFDBEAFE)),
                                      ),
                                      child: Text(
                                        '₹${product.effectivePrice.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                      ),
                                    ),
                                    // Stock capsule
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: inStock ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: inStock ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.inventory_2_outlined,
                                            size: 9.5,
                                            color: inStock ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            inStock ? '${product.stockQuantity} in stock' : 'Out of stock',
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w700,
                                              color: inStock ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Variant capsule
                                    if (product.variants.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5F3FF),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFDDD6FE)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.tune_rounded,
                                              size: 9.5,
                                              color: Color(0xFF7C3AED),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${product.variants.length} Variants',
                                              style: const TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF7C3AED),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),

                          // High-contrast custom toggle switch
                          _buildToggleSwitch(
                            value: product.isAvailable,
                            onChanged: (val) {
                              _db.saveMenuItem(product.copyWith(isAvailable: val));
                              setState(() {});
                            },
                            scale: 0.82,
                          ),
                          const SizedBox(width: 2),

                          // 3-Dots Button with soft circular background
                          PopupMenuButton<String>(
                            color: Colors.white,
                            surfaceTintColor: Colors.transparent,
                            elevation: 6,
                            icon: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Icon(Icons.more_vert_rounded, size: 15, color: Color(0xFF64748B)),
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                    Text('Edit Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
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
                                  pickedImagePath!.startsWith('http') ? 'Cloudflare R2 Image' : pickedImagePath!.split(RegExp(r'[\\/]')).last,
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
                                  pickedImagePath!.startsWith('http') ? 'Cloudflare R2 Image' : pickedImagePath!.split(RegExp(r'[\\/]')).last,
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

  List<List<String>> _parseCsvContent(String rawText) {
    final List<List<String>> result = [];
    final lines = const LineSplitter().convert(rawText.replaceAll('\r\n', '\n'));

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final List<String> row = [];
      final StringBuffer current = StringBuffer();
      bool inQuotes = false;

      for (int i = 0; i < line.length; i++) {
        final char = line[i];
        if (char == '"') {
          inQuotes = !inQuotes;
        } else if (char == ',' && !inQuotes) {
          row.add(current.toString().trim());
          current.clear();
        } else {
          current.write(char);
        }
      }
      row.add(current.toString().trim());
      result.add(row);
    }
    return result;
  }

  List<ProductVariant> _parseVariantsFromCsv(String rawText) {
    if (rawText.trim().isEmpty) return const [];
    final List<ProductVariant> variants = [];

    // Delimiters supported: '|', ';', or '\n' or ','
    final String cleanText = rawText.trim();
    List<String> chunks = [];
    if (cleanText.contains('|')) {
      chunks = cleanText.split('|');
    } else if (cleanText.contains(';')) {
      chunks = cleanText.split(';');
    } else if (cleanText.contains('\n')) {
      chunks = cleanText.split('\n');
    } else if (cleanText.contains(',')) {
      chunks = cleanText.split(',');
    } else {
      chunks = [cleanText];
    }

    for (final chunk in chunks) {
      final clean = chunk.trim();
      if (clean.isEmpty) continue;

      String vName = '';
      double vPrice = 0.0;
      int vStock = -1;

      if (clean.contains(':')) {
        final parts = clean.split(':');
        vName = parts[0].trim();
        if (parts.length > 1) {
          final priceStr = parts[1].replaceAll(RegExp(r'[^0-9.]'), '');
          vPrice = double.tryParse(priceStr) ?? 0.0;
        }
        if (parts.length > 2) {
          final stockStr = parts[2].replaceAll(RegExp(r'[^0-9]'), '');
          vStock = int.tryParse(stockStr) ?? -1;
        }
      } else if (clean.contains('=')) {
        final parts = clean.split('=');
        vName = parts[0].trim();
        if (parts.length > 1) {
          final priceStr = parts[1].replaceAll(RegExp(r'[^0-9.]'), '');
          vPrice = double.tryParse(priceStr) ?? 0.0;
        }
      } else if (clean.contains('-')) {
        final parts = clean.split('-');
        vName = parts[0].trim();
        if (parts.length > 1) {
          final priceStr = parts[1].replaceAll(RegExp(r'[^0-9.]'), '');
          vPrice = double.tryParse(priceStr) ?? 0.0;
        }
      } else {
        vName = clean;
      }

      if (vName.isNotEmpty) {
        variants.add(ProductVariant(
          name: vName,
          price: vPrice,
          stock: vStock,
        ));
      }
    }

    return variants;
  }

  double? _parseGstFromCsv(String rawText) {
    if (rawText.trim().isEmpty) return null;
    final clean = rawText.replaceAll('%', '').trim().toLowerCase();
    if (clean == 'exempt' || clean == 'nil' || clean == 'none' || clean == 'zero' || clean == '0') {
      return 0.0;
    }
    return double.tryParse(clean);
  }

  // --- Top Left CSV Squircle Icon Widget ---
  Widget _buildTopLeftCsvIcon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Container(
          width: 32,
          height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E7BFE), Color(0xFF0F5AF2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(7),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1D68FE).withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF90BFFE),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(5),
                      topRight: Radius.circular(7),
                    ),
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'CSV',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Top Right 3D Stacked Documents Illustration Widget ---
  Widget _buildHeader3DIllustration() {
    return SizedBox(
      width: 80,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Background tilted paper 1
          Transform.rotate(
            angle: 0.16,
            child: Container(
              width: 48,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFD4E6FA).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // Background tilted paper 2
          Transform.rotate(
            angle: 0.08,
            child: Container(
              width: 50,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFBDD9FC),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // Foreground white document
          Container(
            width: 50,
            height: 56,
            padding: const EdgeInsets.only(top: 14, left: 8, right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F5AF2).withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCAD7E6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 22,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCAD7E6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 26,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCAD7E6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          // Green CSV Badge on top left of paper
          Positioned(
            top: 4,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF00C875),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C875).withValues(alpha: 0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: const Text(
                'CSV',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 7.5,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          // Blue Upload arrow circle on bottom right of paper
          Positioned(
            bottom: 2,
            right: 4,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7BFE), Color(0xFF0F5AF2)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F5AF2).withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 1 Illustration Widget ---
  Widget _buildStep1Illustration() {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        color: Color(0xFFE2F7ED),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 30,
            height: 36,
            padding: const EdgeInsets.only(top: 10, left: 5, right: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00A862).withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 18,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 14,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 16,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 6,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFF00C875),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'CSV',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 6.5,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 2 Illustration Widget ---
  Widget _buildStep2Illustration() {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        color: Color(0xFFE2EDFD),
        shape: BoxShape.circle,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 30,
            height: 36,
            padding: const EdgeInsets.only(top: 10, left: 5, right: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F5AF2).withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 18,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCAD7E6),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 14,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCAD7E6),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 16,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCAD7E6),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 6,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFF00C875),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text(
                'CSV',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 6.5,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 6,
            right: 8,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Color(0xFF1D68FE),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Pixel-Perfect Redesigned CSV Import Modal ---
  void _showCsvImportModal() {
    bool isProcessing = false;
    bool isImporting = false;
    String? modalError;
    String? selectedFileName;
    List<MenuItemModel>? parsedItems;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final screenWidth = MediaQuery.of(context).size.width;

            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              elevation: 20,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: screenWidth >= 650 ? 410 : screenWidth * 0.94,
                  minWidth: 280,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row: Top-Left Squircle CSV Doc + Header Title + Top-Right 3D Illustration
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildTopLeftCsvIcon(),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Import Products via',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'CSV',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1D68FE),
                                    letterSpacing: -0.5,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildHeader3DIllustration(),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Error message banner if template format is incorrect
                      if (modalError != null) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFECACA), width: 1),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  modalError!,
                                  style: const TextStyle(
                                    color: Color(0xFF991B1B),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Step 1: Download Sample Template Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAFD),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFEEF2F6), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE0ECFD),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '1',
                                      style: TextStyle(
                                        color: Color(0xFF1D68FE),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Download Sample Template',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildStep1Illustration(),
                              ],
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: () async {
                                try {
                                  Directory? targetDir;
                                  try {
                                    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
                                      final downloadDir = Directory('/storage/emulated/0/Download');
                                      if (await downloadDir.exists()) {
                                        targetDir = downloadDir;
                                      }
                                    }
                                  } catch (_) {}

                                  targetDir ??= await getDownloadsDirectory();
                                  targetDir ??= await getExternalStorageDirectory();
                                  targetDir ??= await getApplicationDocumentsDirectory();

                                  final filePath = '${targetDir.path}/Apna_POS_Menu_Template.csv';
                                  const sampleCsv =
                                      'Product Name,Category,Price,Food Type,Stock,GST (%),Custom Variants,Description,Status\n'
                                      'Shahi Paneer,Main Course,230,Veg,50,5,Half:130 | Full:230,Rich and creamy paneer curry,Active\n'
                                      'Dal Tadka,Main Course,199,Veg,50,5,Half:110 | Full:199,Classic yellow dal with tadka,Active\n'
                                      'Butter Naan,Bread,45,Veg,100,5,,Crispy clay oven bread,Active\n'
                                      'Chicken Biryani,Rice & Biryani,280,Non-Veg,30,5,Half:160 | Full:280,Aromatic spiced rice with tender chicken,Active\n'
                                      'Cold Coffee,Beverages,120,Beverage,40,18,Small:80 | Regular:120 | Large:160,Chilled creamy coffee shake,Active\n'
                                      'Margherita Pizza,Pizza,249,Veg,25,12,Regular:199 | Medium:299 | Large:399,Fresh mozzarella and basil pizza,Active\n';

                                  final file = File(filePath);
                                  await file.writeAsString(sampleCsv);

                                  if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
                                    try {
                                      await SharePlus.instance.share(
                                        ShareParams(
                                          files: [XFile(file.path)],
                                          text: 'Apna POS Menu Template CSV',
                                        ),
                                      );
                                    } catch (_) {}
                                  }

                                  setModalState(() {
                                    modalError = null;
                                  });

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✓ CSV template downloaded successfully!'),
                                        backgroundColor: Color(0xFF00C774),
                                        behavior: SnackBarBehavior.floating,
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to download template: $e'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                width: double.infinity,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF00C774), Color(0xFF00A25C)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00C774).withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.download_rounded, size: 18, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'Download CSV Template',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Step 2: Upload Filled CSV File Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAFD),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFEEF2F6), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE0ECFD),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '2',
                                      style: TextStyle(
                                        color: Color(0xFF1D68FE),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Upload Filled CSV File',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildStep2Illustration(),
                              ],
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: isProcessing
                                  ? null
                                  : () async {
                                      try {
                                        setModalState(() {
                                          isProcessing = true;
                                          modalError = null;
                                        });

                                        final result = await FilePicker.platform.pickFiles(
                                          type: FileType.custom,
                                          allowedExtensions: ['csv'],
                                        );

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

                                        if (csvContent.trim().isEmpty) {
                                          setModalState(() {
                                            isProcessing = false;
                                            parsedItems = null;
                                            selectedFileName = null;
                                            modalError = 'The selected CSV file is completely empty.';
                                          });
                                          return;
                                        }

                                        // Parse CSV
                                        final rows = _parseCsvContent(csvContent);

                                        if (rows.length < 2) {
                                          setModalState(() {
                                            isProcessing = false;
                                            parsedItems = null;
                                            selectedFileName = null;
                                            modalError = 'CSV file has no data rows. Please use the template format.';
                                          });
                                          return;
                                        }

                                        // Validate Headers
                                        final headers = rows[0].map((e) => e.toString().trim().toLowerCase()).toList();
                                        final nameIdx = headers.indexWhere((h) => h.contains('product') || h.contains('name') || h == 'item');
                                        final priceIdx = headers.indexWhere((h) => h.contains('price') || h.contains('rate') || h.contains('mrp') || h == 'amount');
                                        final catIdx = headers.indexWhere((h) => h.contains('category') || h.contains('cat'));
                                        final typeIdx = headers.indexWhere((h) => h.contains('food') || h.contains('type'));
                                        final descIdx = headers.indexWhere((h) => h.contains('desc'));
                                        final stockIdx = headers.indexWhere((h) => h.contains('stock') || h.contains('quantity') || h.contains('qty'));
                                        final gstIdx = headers.indexWhere((h) => h.contains('gst') || h.contains('tax'));
                                        final variantIdx = headers.indexWhere((h) => h.contains('variant') || h.contains('varient') || h.contains('portion') || h.contains('size'));
                                        final statusIdx = headers.indexWhere((h) => h.contains('status') || h.contains('avail'));

                                        // If header format is incorrect
                                        if (nameIdx == -1 || priceIdx == -1) {
                                          setModalState(() {
                                            isProcessing = false;
                                            parsedItems = null;
                                            selectedFileName = null;
                                            modalError = 'Incorrect template format! Required columns "Product Name" and "Price" were not found in the header. Please download the sample template above.';
                                          });
                                          return;
                                        }

                                        // Parse Rows into MenuItemModel
                                        final List<MenuItemModel> items = [];
                                        for (int i = 1; i < rows.length; i++) {
                                          final row = rows[i];
                                          if (row.isEmpty) continue;
                                          final pName = (nameIdx < row.length) ? row[nameIdx].toString().trim() : '';
                                          if (pName.isEmpty) continue;

                                          final rawPriceStr = (priceIdx < row.length) ? row[priceIdx].toString().replaceAll(RegExp(r'[^0-9.]'), '') : '0';
                                          final pPrice = double.tryParse(rawPriceStr) ?? 0.0;
                                          final pCat = (catIdx != -1 && catIdx < row.length) ? row[catIdx].toString().trim() : 'General';
                                          final pTypeRaw = (typeIdx != -1 && typeIdx < row.length) ? row[typeIdx].toString().trim().toLowerCase() : 'veg';
                                          final pDesc = (descIdx != -1 && descIdx < row.length) ? row[descIdx].toString().trim() : '';
                                          final pStockRaw = (stockIdx != -1 && stockIdx < row.length) ? row[stockIdx].toString().replaceAll(RegExp(r'[^0-9]'), '') : '50';
                                          final pStock = int.tryParse(pStockRaw) ?? 50;

                                          final pGstRaw = (gstIdx != -1 && gstIdx < row.length) ? row[gstIdx].toString().trim() : '';
                                          final pGst = _parseGstFromCsv(pGstRaw);

                                          final pVariantsRaw = (variantIdx != -1 && variantIdx < row.length) ? row[variantIdx].toString().trim() : '';
                                          final pVariants = _parseVariantsFromCsv(pVariantsRaw);

                                          final pStatusRaw = (statusIdx != -1 && statusIdx < row.length) ? row[statusIdx].toString().trim().toLowerCase() : 'active';
                                          final pIsAvailable = !pStatusRaw.contains('inactive') && !pStatusRaw.contains('disable') && !pStatusRaw.contains('no');

                                          final foodType = pTypeRaw.contains('non')
                                              ? 'Non-Veg'
                                              : (pTypeRaw.contains('egg') ? 'Egg' : (pTypeRaw.contains('bev') ? 'Beverage' : 'Veg'));

                                          final finalBasePrice = (pPrice == 0.0 && pVariants.isNotEmpty) ? pVariants.first.price : pPrice;

                                          items.add(MenuItemModel(
                                            id: 'PRD-${DateTime.now().millisecondsSinceEpoch}-$i',
                                            name: pName,
                                            description: pDesc,
                                            category: pCat.isNotEmpty ? pCat : 'General',
                                            price: finalBasePrice,
                                            itemType: foodType,
                                            stockQuantity: pStock,
                                            gstPercent: pGst,
                                            variants: pVariants,
                                            isAvailable: pIsAvailable,
                                          ));
                                        }

                                        if (items.isEmpty) {
                                          setModalState(() {
                                            isProcessing = false;
                                            parsedItems = null;
                                            selectedFileName = null;
                                            modalError = 'No valid products found in CSV. Ensure rows contain product names and prices.';
                                          });
                                          return;
                                        }

                                        // Success: Template is valid!
                                        setModalState(() {
                                          isProcessing = false;
                                          modalError = null;
                                          selectedFileName = file.name;
                                          parsedItems = items;
                                        });
                                      } catch (e) {
                                        setModalState(() {
                                          isProcessing = false;
                                          parsedItems = null;
                                          selectedFileName = null;
                                          modalError = 'Error reading CSV file: $e';
                                        });
                                      }
                                    },
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                width: double.infinity,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1D68FE), Color(0xFF0049DB)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF1D68FE).withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isProcessing) ...[
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Verifying File...',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
                                      ),
                                    ] else ...[
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          selectedFileName != null ? 'Change File ($selectedFileName)' : 'Choose & Upload CSV File',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            // If template is validated and products are ready
                            if (parsedItems != null && parsedItems!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFBBF7D0), width: 1),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 16),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '✓ ${parsedItems!.length} products verified from "$selectedFileName"',
                                        style: const TextStyle(
                                          color: Color(0xFF14532D),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // If template is verified, show DONE BUTTON
                      if (parsedItems != null && parsedItems!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: isImporting
                              ? null
                              : () async {
                                  try {
                                    setModalState(() => isImporting = true);
                                    final count = await _db.importProductsFromCsv(parsedItems!);
                                    if (!dialogCtx.mounted) return;
                                    Navigator.pop(dialogCtx);
                                    setState(() {});
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('✓ Successfully added $count products into POS!'),
                                          backgroundColor: const Color(0xFF021B54),
                                          behavior: SnackBarBehavior.floating,
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    setModalState(() {
                                      isImporting = false;
                                      modalError = 'Import failed: $e';
                                    });
                                  }
                                },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: double.infinity,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1D68FE), Color(0xFF0049DB)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1D68FE).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: isImporting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Done - Add ${parsedItems!.length} Products to POS',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            letterSpacing: 0.2,
                                          ),
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
            );
          },
        );
      },
    );
  }

  void _exportCsv() async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('Product Name,Category,Price,Food Type,Stock,GST (%),Custom Variants,Status,Description');
      for (final item in _db.menuItems) {
        final variantsStr = item.variants.isNotEmpty
            ? item.variants.map((v) => '${v.name}:${v.price > 0 ? v.price.toStringAsFixed(0) : "0"}').join(' | ')
            : '';
        final gstStr = item.gstPercent != null ? item.gstPercent!.toStringAsFixed(0) : '';
        buffer.writeln('"${item.name}","${item.category}",${item.price},"${item.itemType}",${item.stockQuantity},"$gstStr","$variantsStr",${item.isAvailable ? "Active" : "Inactive"},"${item.description.replaceAll('"', '""')}"');
      }

      Directory? dir;
      try {
        dir = await getDownloadsDirectory();
      } catch (_) {}
      dir ??= await getApplicationDocumentsDirectory();

      final file = File('${dir.path}/Apna_POS_Menu_Export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
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
