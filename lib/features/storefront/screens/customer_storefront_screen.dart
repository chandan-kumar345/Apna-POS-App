import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/storefront_model.dart';
import '../services/storefront_service.dart';
import '../widgets/storefront_product_detail_sheet.dart';
import '../widgets/storefront_menu_view.dart';
import '../../../core/models/restaurant_model.dart';
import '../widgets/storefront_checkout_flow_sheet.dart';
import 'table_qr_order_screen.dart';

class CustomerStorefrontScreen extends StatefulWidget {
  final String slug;
  final bool isPreviewMode;
  final String? tableCode;
  final String? restaurantCode;
  final String? businessCategory;

  const CustomerStorefrontScreen({
    super.key,
    required this.slug,
    this.isPreviewMode = false,
    this.tableCode,
    this.restaurantCode,
    this.businessCategory,
  });

  @override
  State<CustomerStorefrontScreen> createState() =>
      _CustomerStorefrontScreenState();
}

class _CustomerStorefrontScreenState extends State<CustomerStorefrontScreen> {
  final StorefrontService _service = StorefrontService();
  final TextEditingController _searchController = TextEditingController();
  final PageController _bannerController = PageController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isLoading = true;
  StorefrontData? _data;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  OrderType _orderType = OrderType.delivery;
  String _deliveryAddress = '';
  String? _loadError;
  int _loadGeneration = 0;
  RestaurantModel? _loadingRestaurant;
  bool _isFavorite = false;
  int _activeBannerIndex = 0;
  Timer? _bannerTimer;
  String? _activeTableCode;
  bool _isTableValid = true;

  // In-memory cart
  final List<StorefrontCartItem> _cartItems = [];
  static final Map<String, Uint8List> _avatarBytesCache = {};
  bool get _isTableSession =>
      _activeTableCode != null && _activeTableCode!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _activeTableCode = widget.tableCode;
    if (widget.tableCode != null && widget.tableCode!.trim().isNotEmpty) {
      _orderType = OrderType.dineIn;
    }
    _loadData();
    _startBannerTimer();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _startBannerTimer() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_bannerController.hasClients && (_data?.banners.length ?? 0) > 1) {
        final next = (_activeBannerIndex + 1) % _data!.banners.length;
        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant CustomerStorefrontScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug ||
        oldWidget.tableCode != widget.tableCode ||
        oldWidget.restaurantCode != widget.restaurantCode ||
        oldWidget.isPreviewMode != widget.isPreviewMode) {
      _loadGeneration++;
      _data = null;
      _loadingRestaurant = null;
      _activeTableCode = widget.tableCode;
      _cartItems.clear();
      _selectedCategory = 'All';
      _searchController.clear();
      _searchQuery = '';
      _deliveryAddress = '';
      _isFavorite = false;
      _orderType = _isTableSession ? OrderType.dineIn : OrderType.delivery;
      _isTableValid = !_isTableSession;
      _activeBannerIndex = 0;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    _loadingRestaurant = _service.cachedStorefront(widget.slug)?.restaurant;
    final local = DatabaseService().restaurant;
    if (widget.isPreviewMode && local != null) {
      _loadingRestaurant = local;
    } else if (local != null &&
        (widget.slug == 'preview' ||
            widget.slug.toLowerCase() == local.storefrontSlug.toLowerCase() ||
            widget.slug.toLowerCase() ==
                local.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'))) {
      _loadingRestaurant = local;
    }
    if (_loadingRestaurant == null && _data == null && !widget.isPreviewMode) {
      unawaited(
        _service
            .loadBranding(widget.slug)
            .then((restaurant) {
              if (mounted && generation == _loadGeneration && _data == null)
                setState(() => _loadingRestaurant = restaurant);
            })
            .catchError((Object error) {}),
      );
    }
    try {
      final data = await _service.loadStorefront(
        widget.slug,
        tableCode: widget.tableCode ?? _activeTableCode,
        restaurantCode: widget.restaurantCode,
        preview: widget.isPreviewMode,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _data = data;
        _isLoading = false;
        final table = data.tableInfo;
        _isTableValid = _isTableSession
            ? table?.isValid == true && table!.tableCode.trim().isNotEmpty
            : true;
        if (_isTableSession && _isTableValid && table != null) {
          _activeTableCode = table.tableCode;
          _orderType = OrderType.dineIn;
        } else if (!_isTableSession) {
          final services = data.restaurant.services;
          if (_orderType == OrderType.delivery &&
              !services.contains('Delivery'))
            _orderType = services.contains('Takeaway')
                ? OrderType.takeaway
                : OrderType.dineIn;
          if (_orderType == OrderType.takeaway &&
              !services.contains('Takeaway'))
            _orderType = services.contains('Delivery')
                ? OrderType.delivery
                : OrderType.dineIn;
        }
        if (!data.categories.contains(_selectedCategory))
          _selectedCategory = 'All';
        if (_activeBannerIndex >= data.banners.length) _activeBannerIndex = 0;
      });
    } catch (error) {
      if (mounted && generation == _loadGeneration)
        setState(() {
          _isLoading = false;
          _loadError = 'We could not load this restaurant. Please try again.';
        });
    }
  }

  void _showSelectValidTableDialog() {
    final total = _data?.tableInfo?.totalTables ?? 0;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Your Dining Table',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              if (total == 0)
                const Text(
                  'No dining tables are available for this restaurant.',
                ),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: total,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (_, i) => OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _activeTableCode =
                            'T${(i + 1).toString().padLeft(2, '0')}';
                        _isTableValid = false;
                      });
                      _loadData();
                    },
                    child: Text('T${(i + 1).toString().padLeft(2, '0')}'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<MenuItemModel> get _filteredItems {
    if (_data == null) return [];
    var list = _data!.menuItems;

    // Filter by Category
    if (_selectedCategory != 'All') {
      list = list.where((item) {
        final cat = item.category.trim().toLowerCase();
        final sel = _selectedCategory.trim().toLowerCase();
        return cat == sel || cat.contains(sel) || sel.contains(cat);
      }).toList();
    }

    // Filter by Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((item) {
        return item.name.toLowerCase().contains(q) ||
            item.description.toLowerCase().contains(q) ||
            item.category.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  int get _totalCartCount => _cartItems.fold(0, (sum, i) => sum + i.quantity);
  double get _totalCartAmount =>
      _cartItems.fold(0.0, (sum, i) => sum + i.totalPrice);
  Color get _themeColor => Color(
    _data?.themeColorHex ??
        _loadingRestaurant?.storefrontThemeColor ??
        0xFFE65100,
  );
  Color? get _themeColorEnd =>
      _data?.themeColorEndHex != null ? Color(_data!.themeColorEndHex!) : null;
  bool get _isStoreOnline =>
      (_data?.isOnline ?? false) &&
      (_isTableSession || (_data?.restaurant.services.isNotEmpty ?? false));

  void _openCustomizationModal(MenuItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StorefrontProductDetailSheet(
        item: item,
        themeColor: _themeColor,
        themeColorEnd: _themeColorEnd,
        isOnline: _isStoreOnline,
        availableAddons: _data?.addOns,
        onAddToCart: (cartItem, {bool openCartImmediately = false}) {
          setState(() {
            final existingIdx = _cartItems.indexWhere(
              (c) =>
                  c.item.id == cartItem.item.id &&
                  c.selectedSize?.id == cartItem.selectedSize?.id &&
                  c.instructions == cartItem.instructions,
            );
            if (existingIdx >= 0) {
              _cartItems[existingIdx].quantity += cartItem.quantity;
            } else {
              _cartItems.add(cartItem);
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added "${item.name}" to cart'),
              backgroundColor: _themeColor,
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            ),
          );

          if (openCartImmediately) {
            _openCartModal();
          }
        },
      ),
    );
  }

  void _openCartModal({int initialStep = 3}) {
    if (_data == null) return;
    if (_orderType == OrderType.dineIn && !_isTableValid) {
      _showSelectValidTableDialog();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StorefrontCheckoutFlowSheet(
        restaurant: _data!.restaurant,
        cartItems: _cartItems,
        allMenuItems: _data!.menuItems,
        initialStep: initialStep,
        themeColor: _themeColor,
        themeColorEnd: _themeColorEnd,
        tableCode: (_orderType == OrderType.dineIn && _isTableValid)
            ? _activeTableCode
            : null,
        restaurantCode: widget.restaurantCode,
        onUpdateQuantity: (item, newQty) {
          setState(() {
            if (newQty <= 0) {
              _cartItems.removeWhere((i) => i.uid == item.uid);
            } else {
              item.quantity = newQty;
            }
          });
        },
        onAddCrossSellItem: (item) {
          setState(() {
            _cartItems.add(
              StorefrontCartItem(
                uid: 'cart_cross_${DateTime.now().millisecondsSinceEpoch}',
                item: item,
                quantity: 1,
              ),
            );
          });
        },
        onClearCart: () {
          setState(() {
            _cartItems.clear();
          });
        },
      ),
    );
  }

  void _showChangeLocationDialog() {
    final controller = TextEditingController(text: _deliveryAddress);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Change Delivery Location',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter area or city',
            prefixIcon: Icon(Icons.location_on_rounded, color: _themeColor),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _deliveryAddress = controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _themeColor),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRestaurantInfo() {
    final restaurant = _data?.restaurant;
    if (restaurant == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildRestaurantAvatar(
                    restaurant.logoUrl,
                    restaurant.name,
                    size: 50,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      restaurant.name,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (restaurant.tagline.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(restaurant.tagline),
                ),
              if (restaurant.address.isNotEmpty)
                _buildInfoRow(Icons.location_on_outlined, restaurant.address),
              if (restaurant.phone.isNotEmpty)
                _buildInfoRow(Icons.phone_outlined, restaurant.phone),
              if (restaurant.openingTime.isNotEmpty &&
                  restaurant.closingTime.isNotEmpty)
                _buildInfoRow(
                  Icons.schedule,
                  '${restaurant.openingTime} - ${restaurant.closingTime}',
                ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _themeColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0F172A),
              height: 1.4,
            ),
            softWrap: true,
          ),
        ),
      ],
    );
  }

  Widget _buildRestaurantAvatar(String? logo, String name, {double size = 50}) {
    final effectiveLogo = (logo != null && logo.trim().isNotEmpty)
        ? logo.trim()
        : null;

    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: _themeColor.withValues(alpha: 0.8),
            width: 1.5,
          ),
          boxShadow: [
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-2, -2),
              blurRadius: 4,
            ),
            BoxShadow(
              color: const Color(0xFF94A3B8).withValues(alpha: 0.25),
              offset: const Offset(2, 2.5),
              blurRadius: 5,
            ),
          ],
        ),
        child: ClipOval(child: _buildAvatarImage(effectiveLogo, name, size)),
      ),
    );
  }

  Widget _buildAvatarImage(String? path, String name, double size) {
    if (path?.startsWith('/uploads/') == true) {
      path = ApiEndpoints.resolveMediaUrl(path!);
    }
    if (path != null && path.isNotEmpty) {
      // 1. Data URI / Base64 image
      if (path.startsWith('data:image') ||
          path.startsWith('data:') ||
          (path.length > 80 &&
              !path.startsWith('http') &&
              !path.startsWith('assets/'))) {
        try {
          final clean = path.contains(',') ? path.split(',').last : path;
          final normalized = clean
              .replaceAll('\n', '')
              .replaceAll('\r', '')
              .trim();
          Uint8List? bytes = _avatarBytesCache[normalized];
          if (bytes == null) {
            bytes = base64Decode(normalized);
            _avatarBytesCache[normalized] = bytes;
          }
          return Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                _buildFallbackImage(name, size),
          );
        } catch (_) {}
      } else if (path.startsWith('http://') ||
          path.startsWith('https://') ||
          path.startsWith('/uploads/')) {
        return Image.network(
          ApiEndpoints.resolveMediaUrl(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackImage(name, size),
        );
      } else if (path.startsWith('assets/')) {
        return Image.asset(
          path,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackImage(name, size),
        );
      } else if (!kIsWeb) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            return Image.file(
              file,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) =>
                  _buildFallbackImage(name, size),
            );
          }
        } catch (_) {}
      }
    }
    return _buildFallbackImage(name, size);
  }

  Widget _buildFallbackImage(String name, double size) {
    return _buildEmblemLogo(name, size);
  }

  Widget _buildEmblemLogo(String name, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        shape: BoxShape.circle,
        border: Border.all(color: _themeColor, width: 1.5),
      ),
      child: Center(
        child: Text(
          name.length > 2 ? name.substring(0, 2).toUpperCase() : 'POS',
          style: TextStyle(
            color: _themeColor,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      if (_loadError != null)
        return Scaffold(
          backgroundColor: storefrontBackground,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      size: 44,
                      color: Color(0xFF8B9BA9),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadData,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      return StorefrontMenuLoading(
        restaurant: _loadingRestaurant,
        avatar: (logo, name, size) =>
            _buildRestaurantAvatar(logo, name, size: size),
      );
    }
    if (_isTableSession) {
      return TableQrOrderScreen(
        key: ValueKey((
          widget.slug,
          _activeTableCode,
          widget.restaurantCode,
          widget.isPreviewMode,
        )),
        data: _data!,
        tableCode: _activeTableCode!,
        preview: widget.isPreviewMode,
        onRefresh: _loadData,
        avatar: (logo, name, size) => _buildRestaurantAvatar(logo, name, size: size),
      );
    }
    return StorefrontMenuView(
      data: _data!,
      items: _filteredItems,
      orderType: _orderType,
      category: _selectedCategory,
      deliveryAddress: _deliveryAddress,
      favorite: _isFavorite,
      preview: widget.isPreviewMode,
      tableSession: _isTableSession,
      tableCode: _activeTableCode,
      refreshing: _isLoading,
      refreshError: _loadError,
      searchController: _searchController,
      bannerController: _bannerController,
      bannerIndex: _activeBannerIndex,
      cartCount: _totalCartCount,
      cartTotal: _totalCartAmount,
      onRefresh: _loadData,
      onOrderType: (type) => setState(() => _orderType = type),
      onCategory: (category) => setState(() => _selectedCategory = category),
      onSearch: (query) => setState(() => _searchQuery = query),
      onBannerChanged: (index) => setState(() => _activeBannerIndex = index),
      onBanner: (banner) {
        if (banner.couponCode?.isNotEmpty == true) {
          Clipboard.setData(ClipboardData(text: banner.couponCode!));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Coupon ${banner.couponCode} copied')),
          );
        }
      },
      onProduct: _openCustomizationModal,
      onFavorite: () => setState(() => _isFavorite = !_isFavorite),
      onInfo: _showRestaurantInfo,
      onLocation: _showChangeLocationDialog,
      onCart: () => _openCartModal(),
      onExitPreview: () => Navigator.maybePop(context),
      avatar: (logo, name, size) =>
          _buildRestaurantAvatar(logo, name, size: size),
    );
  }
}
