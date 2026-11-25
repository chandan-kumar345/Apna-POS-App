import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/coupon_model.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/restaurant_model.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/services/youtube_service.dart';
import '../../pos/widgets/pos_product_media_box.dart';
import '../models/customer_order_status.dart';
import '../models/customer_storefront_flow_models.dart';
import '../models/storefront_model.dart';
import '../screens/customer_my_orders_screen.dart';
import '../screens/restaurant_info_screen.dart';
import '../services/customer_storefront_api_service.dart';
import '../services/table_qr_phone_auth.dart';
import 'online_order_flow_widgets.dart';

const storefrontBackground = Color(0xFFEEF2F7);
const _ink = Color(0xFF090D16);
const _muted = Color(0xFF334155);
const _cardBorder = Color(0xFFCBD5E1);
const _deliveryBlue = Color(0xFF1D4ED8);
const _ctaBlue = Color(0xFF0F4BF5);

typedef StorefrontPlaceOrderCallback =
    Future<CustomerOrderTrackingModel?> Function({
      required String paymentMethod,
      required String address,
      required String instructions,
      double discount,
      String? couponCode,
      CustomerProfileModel? customerOverride,
      CustomerAddressModel? selectedAddress,
    });

/// Customer frontstore for online delivery matching the 5-screen flow:
/// 1. Online Order Home
/// 2. Our Menu (Add to Cart)
/// 3. Your Cart (Delivery Address & Bill Summary)
/// 4. Login (Before Checkout popup over blurred Cart)
/// 5. Payment Method (Popup over blurred Cart)
/// Plus Restaurant Info (from logo/name tap), Orders tracking tab, and Account tab.
class StorefrontMenuView extends StatefulWidget {
  final StorefrontData data;
  final List<MenuItemModel> items;
  final OrderType orderType;
  final String category, deliveryAddress;
  final bool favorite, preview, tableSession, refreshing;
  final String? tableCode, refreshError;
  final TextEditingController searchController;
  final PageController bannerController;
  final int bannerIndex, cartCount;
  final double cartTotal;
  final Future<void> Function() onRefresh;
  final ValueChanged<OrderType> onOrderType;
  final ValueChanged<String> onCategory, onSearch;
  final ValueChanged<int> onBannerChanged;
  final ValueChanged<StorefrontBanner> onBanner;
  final ValueChanged<MenuItemModel> onProduct;
  final VoidCallback onFavorite, onInfo, onLocation, onCart, onExitPreview;
  final Widget Function(String?, String, double) avatar;

  // Dynamic delivery workflow callbacks
  final List<StorefrontCartItem>? cartItems;
  final void Function(MenuItemModel)? onAddToCart;
  final void Function(StorefrontCartItem, int)? onUpdateQuantity;
  final VoidCallback? onClearCart;
  final Future<void> Function(
    String paymentMethod,
    String address,
    String instructions,
  )?
  onPlaceOrder;
  final StorefrontPlaceOrderCallback? onPlaceOrderWithReceipt;
  final CustomerProfileModel? customer;
  final ValueChanged<CustomerProfileModel?>? onUpdateCustomer;
  final ValueChanged<CustomerAddressModel>? onUpdateDeliveryAddress;
  final String? restaurantCode;

  const StorefrontMenuView({
    super.key,
    required this.data,
    required this.items,
    required this.orderType,
    required this.category,
    required this.deliveryAddress,
    required this.favorite,
    required this.preview,
    required this.tableSession,
    required this.refreshing,
    this.tableCode,
    this.refreshError,
    required this.searchController,
    required this.bannerController,
    required this.bannerIndex,
    required this.cartCount,
    required this.cartTotal,
    required this.onRefresh,
    required this.onOrderType,
    required this.onCategory,
    required this.onSearch,
    required this.onBannerChanged,
    required this.onBanner,
    required this.onProduct,
    required this.onFavorite,
    required this.onInfo,
    required this.onLocation,
    required this.onCart,
    required this.onExitPreview,
    required this.avatar,
    this.cartItems,
    this.onAddToCart,
    this.onUpdateQuantity,
    this.onClearCart,
    this.onPlaceOrder,
    this.onPlaceOrderWithReceipt,
    this.customer,
    this.onUpdateCustomer,
    this.onUpdateDeliveryAddress,
    this.restaurantCode,
  });

  @override
  State<StorefrontMenuView> createState() => _StorefrontMenuViewState();
}

class _StorefrontMenuViewState extends State<StorefrontMenuView> {
  final CustomerStorefrontApiService _apiService =
      CustomerStorefrontApiService();
  final TextEditingController _cookingInstructionsController =
      TextEditingController();

  int _currentTab = 0; // 0: Home, 1: Menu, 2: Cart, 3: Orders, 4: Account
  bool _showRestaurantInfoView = false;
  bool _vegOnly = false;
  CustomerProfileModel? _localCustomer;
  CustomerAddressModel? _selectedAddressModel;
  String _localDeliveryAddress = '';

  List<CouponModel> _coupons = [];
  String? _appliedCouponCode;
  double _couponDiscount = 0.0;
  Set<String> _favoriteItemIds = {};
  List<CustomerOrderTrackingModel> _orderHistory = [];
  bool _loadingOrders = false;

  Color get brand => _deliveryBlue;
  RestaurantModel get restaurant => widget.data.restaurant;
  bool get canOrder =>
      widget.data.isOnline &&
      (widget.tableSession || restaurant.services.isNotEmpty);

  String money(double amount) =>
      '${restaurant.currencySymbol}${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';

  String get _favItemsPrefKey => 'storefront_fav_items_${restaurant.id}';

  @override
  void initState() {
    super.initState();
    _localCustomer = widget.customer;
    _localDeliveryAddress = widget.deliveryAddress.trim().isNotEmpty
        ? widget.deliveryAddress.trim()
        : (widget.customer?.addresses.isNotEmpty == true
              ? widget.customer!.addresses.first.fullAddress
              : '');
    unawaited(_loadDynamicStorefrontExtras());
  }

  @override
  void didUpdateWidget(covariant StorefrontMenuView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.customer != oldWidget.customer) {
      _localCustomer = widget.customer;
    }
    if (widget.deliveryAddress != oldWidget.deliveryAddress &&
        widget.deliveryAddress.trim().isNotEmpty) {
      _localDeliveryAddress = widget.deliveryAddress.trim();
    }
    if (widget.data.restaurant.id != oldWidget.data.restaurant.id) {
      _appliedCouponCode = null;
      _couponDiscount = 0.0;
      unawaited(_loadDynamicStorefrontExtras());
    }
  }

  @override
  void dispose() {
    _cookingInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadDynamicStorefrontExtras() async {
    await Future.wait([
      _loadCoupons(),
      _loadFavoriteItems(),
      _loadOrderHistory(),
    ]);
  }

  Future<void> _loadCoupons() async {
    try {
      final coupons = await _apiService.fetchStorefrontCoupons(
        restaurant.id,
        preview: widget.preview,
      );
      if (mounted) {
        setState(() => _coupons = coupons);
      }
    } catch (_) {}
  }

  Future<void> _loadFavoriteItems() async {
    if (restaurant.id.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_favItemsPrefKey) ?? [];
      if (mounted) {
        setState(() => _favoriteItemIds = list.toSet());
      }
    } catch (_) {}
  }

  Future<void> _toggleFavoriteItem(String itemId) async {
    final next = Set<String>.from(_favoriteItemIds);
    if (next.contains(itemId)) {
      next.remove(itemId);
    } else {
      next.add(itemId);
    }
    setState(() => _favoriteItemIds = next);
    if (restaurant.id.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favItemsPrefKey, next.toList());
    } catch (_) {}
  }

  Future<void> _loadOrderHistory() async {
    if (restaurant.id.trim().isEmpty) return;
    if (mounted) setState(() => _loadingOrders = true);
    try {
      final orders = await _apiService.orderHistory(restaurant.id);
      if (mounted) {
        setState(() {
          _orderHistory = orders;
          _loadingOrders = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  // Cart & pricing helpers
  double get _subtotal => widget.cartTotal;

  double get _effectiveTaxRate {
    if (_subtotal <= 0 || restaurant.billingType == 'Non-GST') return 0.0;
    return restaurant.taxRate > 0 ? restaurant.taxRate : 0.0;
  }

  double get _taxAmount =>
      _effectiveTaxRate > 0 ? _subtotal * (_effectiveTaxRate / 100.0) : 0.0;

  double get _deliveryFee {
    if (widget.orderType != OrderType.delivery || _subtotal <= 0) return 0.0;
    if (restaurant.freeDeliveryEnabled &&
        restaurant.freeDeliveryMinOrder > 0 &&
        _subtotal >= restaurant.freeDeliveryMinOrder) {
      return 0.0;
    }
    return restaurant.deliveryBaseCharge > 0
        ? restaurant.deliveryBaseCharge
        : 0.0;
  }

  double get _grandTotal =>
      (_subtotal + _taxAmount + _deliveryFee - _couponDiscount).clamp(
        0.0,
        double.infinity,
      );

  int _getItemCartQuantity(MenuItemModel item) {
    if (widget.cartItems == null) return 0;
    return widget.cartItems!
        .where((c) => c.item.id == item.id)
        .fold(0, (sum, i) => sum + i.quantity);
  }

  StorefrontCartItem? _getCartItem(MenuItemModel item) {
    if (widget.cartItems == null) return null;
    for (final c in widget.cartItems!) {
      if (c.item.id == item.id &&
          c.selectedSize == null &&
          c.selectedAddons.isEmpty &&
          c.instructions.isEmpty) {
        return c;
      }
    }
    for (final c in widget.cartItems!) {
      if (c.item.id == item.id) return c;
    }
    return null;
  }

  void _handleQuickAdd(MenuItemModel item) {
    if (!canOrder || !item.isAvailable || item.isOutOfStock) return;
    if (item.variants.length > 1 || widget.onAddToCart == null) {
      widget.onProduct(item);
      return;
    }
    widget.onAddToCart!(item);
    _recalculateLocalCouponDiscount();
  }

  void _handleIncrementItem(MenuItemModel item) {
    final cartItem = _getCartItem(item);
    if (cartItem != null && widget.onUpdateQuantity != null) {
      widget.onUpdateQuantity!(cartItem, cartItem.quantity + 1);
      _recalculateLocalCouponDiscount();
    } else {
      _handleQuickAdd(item);
    }
  }

  void _handleDecrementItem(MenuItemModel item) {
    final cartItem = _getCartItem(item);
    if (cartItem != null && widget.onUpdateQuantity != null) {
      widget.onUpdateQuantity!(cartItem, cartItem.quantity - 1);
      _recalculateLocalCouponDiscount();
    }
  }

  void _recalculateLocalCouponDiscount() {
    if (_appliedCouponCode == null) return;
    final match = _coupons.cast<CouponModel?>().firstWhere(
      (c) => c?.code.toUpperCase() == _appliedCouponCode!.toUpperCase(),
      orElse: () => null,
    );
    if (match == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_subtotal < match.minCartAmount) {
        setState(() => _couponDiscount = 0.0);
        return;
      }
      double disc = match.isPercentage
          ? (_subtotal * match.discountValue) / 100.0
          : match.discountValue;
      if (match.maxDiscountAmount != null &&
          match.maxDiscountAmount! > 0 &&
          disc > match.maxDiscountAmount!) {
        disc = match.maxDiscountAmount!;
      }
      if (disc > _subtotal) disc = _subtotal;
      setState(() => _couponDiscount = disc);
    });
  }

  Future<void> _applyCoupon(CouponModel coupon) async {
    if (_subtotal <= 0) {
      await Clipboard.setData(ClipboardData(text: coupon.code));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Coupon ${coupon.code} copied. Add items to apply at checkout!',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (_subtotal < coupon.minCartAmount) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Add ${money(coupon.minCartAmount - _subtotal)} more to use ${coupon.code}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    double discount = 0.0;
    try {
      final quote = await _apiService.quoteStorefrontCoupon(
        restaurantId: restaurant.id,
        code: coupon.code,
        subtotal: _subtotal,
        orderType: widget.orderType.name,
        cartItems: widget.cartItems ?? const [],
        customerPhone: _localCustomer?.phone,
      );
      if (quote != null && quote['valid'] == true) {
        discount = (quote['discountAmount'] as num?)?.toDouble() ?? 0.0;
      } else if (quote != null && quote['allowDefaultOffer'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                quote['message']?.toString() ?? 'Coupon not applicable',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } catch (_) {
      // Preview / offline fallback calculation
      discount = coupon.isPercentage
          ? (_subtotal * coupon.discountValue) / 100.0
          : coupon.discountValue;
      if (coupon.maxDiscountAmount != null &&
          coupon.maxDiscountAmount! > 0 &&
          discount > coupon.maxDiscountAmount!) {
        discount = coupon.maxDiscountAmount!;
      }
    }

    if (discount <= 0) {
      discount = coupon.isPercentage
          ? (_subtotal * coupon.discountValue) / 100.0
          : coupon.discountValue;
      if (coupon.maxDiscountAmount != null &&
          coupon.maxDiscountAmount! > 0 &&
          discount > coupon.maxDiscountAmount!) {
        discount = coupon.maxDiscountAmount!;
      }
    }
    if (discount > _subtotal) discount = _subtotal;

    if (mounted) {
      setState(() {
        _appliedCouponCode = coupon.code;
        _couponDiscount = discount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Coupon ${coupon.code} applied! Saved ${money(discount)}',
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  IconData _getCategoryIcon(String category) {
    final c = category.toLowerCase();
    if (c.contains('pizza')) return Icons.local_pizza_outlined;
    if (c.contains('burger')) return Icons.lunch_dining_outlined;
    if (c.contains('side') ||
        c.contains('bread') ||
        c.contains('snack') ||
        c.contains('starter')) {
      return Icons.bakery_dining_outlined;
    }
    if (c.contains('drink') ||
        c.contains('beverage') ||
        c.contains('shake') ||
        c.contains('juice') ||
        c.contains('lime') ||
        c.contains('coffee') ||
        c.contains('tea')) {
      return Icons.local_drink_outlined;
    }
    if (c.contains('dessert') ||
        c.contains('cake') ||
        c.contains('sweet') ||
        c.contains('ice')) {
      return Icons.icecream_outlined;
    }
    if (c.contains('pasta') || c.contains('noodle')) {
      return Icons.ramen_dining_outlined;
    }
    if (c.contains('combo') || c.contains('meal') || c.contains('box')) {
      return Icons.bento_outlined;
    }
    if (c.contains('biryani') || c.contains('rice')) {
      return Icons.rice_bowl_outlined;
    }
    return Icons.restaurant_outlined;
  }

  String _primaryProductImage(MenuItemModel item) {
    if (item.imageUrl.trim().isNotEmpty) return item.imageUrl.trim();
    for (final img in item.images) {
      if (img.trim().isNotEmpty) return img.trim();
    }
    final rawVideo = item.videoUrl.trim();
    if (rawVideo.isNotEmpty && YouTubeService.isYouTubeUrl(rawVideo)) {
      final videoId = YouTubeService.extractVideoId(rawVideo);
      if (videoId != null && videoId.isNotEmpty) {
        return YouTubeService.getThumbnailUrl(videoId);
      }
    }
    return '';
  }

  String _categoryFirstProductImage(String category) {
    final target = category.trim().toLowerCase();
    if (target.isEmpty || target == 'all') return '';
    for (final item in widget.data.menuItems) {
      if (item.category.trim().toLowerCase() == target) {
        final img = _primaryProductImage(item);
        if (img.isNotEmpty) return img;
      }
    }
    return '';
  }

  Widget _buildProductMedia(
    MenuItemModel item, {
    double? width,
    double? height,
    double radius = 12,
    bool isPopularCard = false,
  }) {
    final primaryImg = _primaryProductImage(item);
    final hasVideo = item.videoUrl.trim().isNotEmpty;
    if (!hasVideo && item.images.length <= 1) {
      return buildFoodThumbnail(
        primaryImg,
        width: width ?? 90,
        height: height ?? 90,
        radius: radius,
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PosProductMediaBox(
            key: ValueKey(
              'storefront_media_${item.id}_${item.imageUrl}_${item.videoUrl}_${item.images.length}',
            ),
            item: item,
            width: width,
            height: height,
            fit: BoxFit.cover,
            imageCacheWidth: isPopularCard ? 480 : 320,
            showDots: item.images.length > 1 || hasVideo,
            autoSlide: false,
            autoPlayVideo: true,
            independentPlayback: true,
            borderRadius: BorderRadius.circular(radius),
            onTap: () => widget.onProduct(item),
          ),
          if (hasVideo)
            Positioned(
              top: 5,
              left: 5,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.videocam_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildVariantsLabel(
    MenuItemModel item, {
    bool compact = false,
  }) {
    final names = item.variants
        .map((v) => v.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isEmpty) return null;

    final labelPrefix = names.length > 1 ? 'Variants' : 'Variant';
    if (compact) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFBFDBFE), width: 0.9),
        ),
        child: Text(
          '$labelPrefix: ${names.join(' • ')}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: brand,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 5,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '$labelPrefix:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: brand,
            ),
          ),
          ...names.map(
            (name) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 2.5,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFBFDBFE),
                  width: 0.9,
                ),
              ),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _pickDeliveryAddress() async {
    final chosen = await DeliveryAddressBottomSheet.show(
      context,
      initialAddress: _localDeliveryAddress,
      initialLandmark: _selectedAddressModel?.landmark ?? '',
      initialPinCode: _selectedAddressModel?.pinCode ?? '',
      savedAddresses: _localCustomer?.addresses ?? const [],
    );
    if (chosen == null || !mounted) return false;
    setState(() {
      _selectedAddressModel = chosen;
      _localDeliveryAddress = chosen.fullAddress;
    });
    widget.onUpdateDeliveryAddress?.call(chosen);
    return true;
  }

  bool _hasValidPinCode() {
    final savedPin = (_selectedAddressModel?.pinCode ?? '').trim();
    if (RegExp(r'^[1-9][0-9]{5}$').hasMatch(savedPin)) {
      return true;
    }
    return RegExp(r'\b[1-9][0-9]{5}\b').hasMatch(_localDeliveryAddress);
  }

  // Screen 3 -> Screen 4 (Login) -> Screen 5 (Payment Method) -> Real Order Submit
  Future<void> _handleProceedToCheckout() async {
    if ((widget.cartItems?.isEmpty ?? true) && widget.cartCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty. Add dishes to checkout.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (widget.orderType == OrderType.delivery &&
        (_localDeliveryAddress.trim().isEmpty || !_hasValidPinCode())) {
      final saved = await _pickDeliveryAddress();
      if (!saved || !mounted) return;
    }

    CustomerProfileModel? customer = _localCustomer;

    // Screen 4: Login (Before Checkout) over blurred Cart
    if (customer == null) {
      final loggedIn = await OnlineLoginModalSheet.show(
        context,
        restaurant: restaurant,
      );
      if (loggedIn == null || !mounted) return;
      customer = loggedIn;
      setState(() => _localCustomer = customer);
      widget.onUpdateCustomer?.call(customer);
    }

    if (!mounted) return;

    CustomerOrderTrackingModel? placedReceipt;
    final currentCustomer = customer;
    final addressText = _localDeliveryAddress.trim().isNotEmpty
        ? _localDeliveryAddress.trim()
        : (currentCustomer.addresses.isNotEmpty
              ? currentCustomer.addresses.first.fullAddress
              : '');

    // Screen 5: Payment Method Popup over blurred Cart
    final selectedMethod = await OnlinePaymentModalSheet.show(
      context,
      totalAmount: _grandTotal,
      currencySymbol: restaurant.currencySymbol,
      onConfirmPay: (paymentMethod) async {
        try {
          if (widget.onPlaceOrderWithReceipt != null) {
            final receipt = await widget.onPlaceOrderWithReceipt!(
              paymentMethod: paymentMethod,
              address: addressText,
              instructions: _cookingInstructionsController.text.trim(),
              discount: _couponDiscount,
              couponCode: _appliedCouponCode,
              customerOverride: currentCustomer,
              selectedAddress: _selectedAddressModel,
            );
            if (receipt == null) {
              return 'Order could not be confirmed by the restaurant. Please try again.';
            }
            placedReceipt = receipt;
            return null;
          } else if (widget.onPlaceOrder != null) {
            await widget.onPlaceOrder!(
              paymentMethod,
              addressText,
              _cookingInstructionsController.text.trim(),
            );
            return null;
          }
          return null;
        } catch (_) {
          return 'Unable to place your order right now. Please try again.';
        }
      },
    );

    if (selectedMethod == null || !mounted) return;

    widget.onClearCart?.call();
    _cookingInstructionsController.clear();
    setState(() {
      _appliedCouponCode = null;
      _couponDiscount = 0.0;
      if (placedReceipt != null) {
        _orderHistory.removeWhere((o) => o.orderId == placedReceipt!.orderId);
        _orderHistory.insert(0, placedReceipt!);
      }
      _currentTab = 3; // Navigate to Orders tab
    });

    unawaited(_loadOrderHistory());

    if (mounted) {
      final ordNum = placedReceipt?.orderNumber ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ordNum.isNotEmpty
                ? 'Order $ordNum placed successfully!'
                : 'Order placed successfully!',
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (placedReceipt != null) {
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CustomerMyOrdersScreen(
                order: placedReceipt!,
                restaurant: restaurant,
                themeColor: brand,
              ),
            ),
          ),
        );
      }
    }
  }

  void _openOffersSheet({bool fromCart = false}) {
    final bannerCoupons = widget.data.banners
        .where((b) => (b.couponCode ?? '').trim().isNotEmpty)
        .map(
          (b) => CouponModel(
            id: 'banner_${b.id}',
            code: b.couponCode!.trim(),
            title: b.discountText?.isNotEmpty == true
                ? b.discountText!
                : b.headline,
            description: b.subtitle,
            discountType: 'flat',
            discountValue: 0,
            isActive: true,
          ),
        );
    final merged = <CouponModel>[
      ..._coupons,
      ...bannerCoupons.where(
        (bc) => !_coupons.any(
          (c) => c.code.toUpperCase() == bc.code.toUpperCase(),
        ),
      ),
    ];

    showBlurredStorefrontSheet<void>(
      context: context,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.72,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available Offers & Coupons',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: _ink, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (merged.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.local_offer_outlined,
                          size: 36,
                          color: Color(0xFF475569),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          restaurant.freeDeliveryEnabled &&
                                  restaurant.freeDeliveryMinOrder > 0
                              ? 'Free delivery on orders above ${money(restaurant.freeDeliveryMinOrder)}'
                              : 'No active coupon codes right now. Check back soon!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: merged.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, idx) {
                      final coupon = merged[idx];
                      final isApplied =
                          _appliedCouponCode?.toUpperCase() ==
                          coupon.code.toUpperCase();
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isApplied
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isApplied ? brand : _cardBorder,
                            width: 1.15,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEDE9FE),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      coupon.code,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF5B21B6),
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    coupon.title.isNotEmpty
                                        ? coupon.title
                                        : (coupon.isPercentage
                                              ? '${coupon.discountValue.toInt()}% OFF'
                                              : 'Flat ${money(coupon.discountValue)} OFF'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _ink,
                                    ),
                                  ),
                                  if (coupon.description.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      coupon.description,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _muted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                if (coupon.discountValue <= 0 && !fromCart) {
                                  await Clipboard.setData(
                                    ClipboardData(text: coupon.code),
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Coupon ${coupon.code} copied!',
                                        ),
                                      ),
                                    );
                                  }
                                } else {
                                  await _applyCoupon(coupon);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brand,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(
                                _subtotal > 0 ? 'Apply' : 'Copy',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
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
  }

  void _openFavoritesSheet() {
    final favItems = widget.data.menuItems
        .where((m) => _favoriteItemIds.contains(m.id))
        .toList();

    showBlurredStorefrontSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final currentFavs = widget.data.menuItems
              .where((m) => _favoriteItemIds.contains(m.id))
              .toList();
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.72,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Favorite Dishes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _ink,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: _ink, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  if (currentFavs.isEmpty && favItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.star_outline_rounded,
                              size: 38,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'No favorite dishes saved yet',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap the heart on dishes in the menu to save your go-to cravings.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11.5, color: _muted),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() => _currentTab = 1);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brand,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'Browse Menu',
                                style: TextStyle(fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: currentFavs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, idx) {
                          final item = currentFavs[idx];
                          return Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _cardBorder,
                                width: 1.15,
                              ),
                            ),
                            child: Row(
                              children: [
                                buildFoodThumbnail(
                                  _primaryProductImage(item),
                                  size: 52,
                                  radius: 9,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: _ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        money(item.effectivePrice),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w900,
                                          color: _ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.favorite_rounded,
                                    color: Color(0xFFEF4444),
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    await _toggleFavoriteItem(item.id);
                                    setSheetState(() {});
                                  },
                                ),
                                if (canOrder &&
                                    item.isAvailable &&
                                    !item.isOutOfStock)
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _handleQuickAdd(item);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: brand,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      minimumSize: const Size(56, 32),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Add',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
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
          );
        },
      ),
    );
  }

  void _openSupportSheet() {
    final phone = restaurant.phone.trim();
    final address = restaurant.address.trim();
    final open = restaurant.openingTime.trim().isNotEmpty
        ? restaurant.openingTime.trim()
        : '09:00 AM';
    final close = restaurant.closingTime.trim().isNotEmpty
        ? restaurant.closingTime.trim()
        : '11:00 PM';

    showBlurredStorefrontSheet<void>(
      context: context,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Customer Support',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: _ink, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cardBorder, width: 1.15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name.isNotEmpty
                          ? restaurant.name
                          : 'Restaurant Support',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Hours: $open - $close',
                      style: const TextStyle(fontSize: 11.5, color: _muted),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        address,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: _ink,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri(scheme: 'tel', path: phone);
                          try {
                            await launchUrl(uri);
                          } catch (_) {}
                        },
                        icon: const Icon(Icons.call_rounded, size: 18),
                        label: Text('Call $phone'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: phone));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Phone number copied')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(23),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showRestaurantInfoView) {
      return RestaurantInfoScreen(
        restaurant: restaurant,
        data: widget.data,
        themeColor: brand,
        avatar: widget.avatar,
        onBack: () => setState(() => _showRestaurantInfoView = false),
      );
    }

    return PopScope(
      canPop: _currentTab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentTab != 0) {
          setState(() {
            _currentTab = _currentTab == 2 ? 1 : 0;
          });
        }
      },
      child: StorefrontViewportFrame(
        child: Scaffold(
          backgroundColor: storefrontBackground,
          body: SafeArea(child: _buildCurrentTabBody()),
          bottomNavigationBar: OnlineStorefrontBottomBar(
            currentIndex: _currentTab,
            cartCount: widget.cartCount,
            activeColor: brand,
            onTabSelected: (index) {
              setState(() => _currentTab = index);
              if (index == 3) {
                unawaited(_loadOrderHistory());
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionScreenHeader(String title, VoidCallback onBack) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(
              Icons.arrow_back_rounded,
              size: 24,
              color: _ink,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _ink,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityStepper({
    required int quantity,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    double height = 34,
    double iconSize = 15.5,
    double fontSize = 14,
    double horizontalPad = 10,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: const Color(0xFF94A3B8),
          width: 1.15,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onDecrement,
            borderRadius: BorderRadius.circular(height / 2),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPad,
                vertical: 4,
              ),
              child: Icon(
                Icons.remove_rounded,
                size: iconSize,
                color: const Color(0xFF1D4ED8),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '$quantity',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
          ),
          InkWell(
            onTap: onIncrement,
            borderRadius: BorderRadius.circular(height / 2),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPad,
                vertical: 4,
              ),
              child: Icon(
                Icons.add_rounded,
                size: iconSize,
                color: const Color(0xFF1D4ED8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTabBody() {
    switch (_currentTab) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildMenuTab();
      case 2:
        return _buildCartTab();
      case 3:
        return _buildOrdersTab();
      case 4:
        return _buildAccountTab();
      default:
        return _buildHomeTab();
    }
  }

  // ===========================================================================
  // SCREEN 1: ONLINE ORDER HOME
  // ===========================================================================
  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await widget.onRefresh();
        await _loadCoupons();
      },
      color: brand,
      child: ListView(
        key: const PageStorageKey('storefront-home-tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
        children: [
          if (widget.preview) _previewBanner(),
          _homeHeader(),
          const SizedBox(height: 12),
          _heroBannerCarousel(),
          const SizedBox(height: 12),
          _quickActionsRow(),
          const SizedBox(height: 14),
          _popularPicksSection(),
          const SizedBox(height: 14),
          _bottomOfferBanner(),
        ],
      ),
    );
  }

  Widget _previewBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, color: Colors.white, size: 15),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Storefront Live Preview',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: widget.onExitPreview,
            child: const Text(
              'Exit Preview',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeHeader() {
    final open = restaurant.openingTime.trim().isNotEmpty
        ? restaurant.openingTime.trim()
        : '09:00 AM';
    final close = restaurant.closingTime.trim().isNotEmpty
        ? restaurant.closingTime.trim()
        : '11:00 PM';
    final subtitle = restaurant.cuisineType.trim().isNotEmpty
        ? restaurant.cuisineType.trim()
        : 'Restaurant';

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _showRestaurantInfoView = true),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  widget.avatar(restaurant.logoUrl, restaurant.name, 60),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant.name.trim().isNotEmpty
                              ? restaurant.name
                              : 'Storefront',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18.5,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 3,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: widget.data.isOnline
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFDC2626),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.data.isOnline ? 'Open' : 'Closed',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Text(
                              '$open – $close',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _muted,
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
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: widget.onFavorite,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _cardBorder, width: 1.15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              widget.favorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 22,
              color: widget.favorite ? const Color(0xFFDC2626) : _ink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _heroBannerCarousel() {
    final banners = widget.data.banners;
    final slideCount = banners.isNotEmpty ? banners.length : 1;

    return Container(
      height: 154,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          children: [
            PageView.builder(
              controller: widget.bannerController,
              itemCount: slideCount,
              onPageChanged: widget.onBannerChanged,
              itemBuilder: (context, index) {
                final banner = banners.isNotEmpty ? banners[index] : null;
                return _buildHeroSlide(banner);
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(slideCount, (i) {
                  final active = i == (widget.bannerIndex % slideCount);
                  return Container(
                    width: active ? 8 : 5.5,
                    height: 5.5,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSlide(StorefrontBanner? banner) {
    final headline = banner?.headline.trim().isNotEmpty == true
        ? banner!.headline.trim()
        : 'Order Food Online';
    final subtitle = banner?.subtitle.trim().isNotEmpty == true
        ? banner!.subtitle.trim()
        : (restaurant.tagline.trim().isNotEmpty
              ? restaurant.tagline.trim()
              : 'Freshly baked, delivered to your doorstep.');
    final imageUrl = banner?.imageUrl.trim() ?? '';

    return InkWell(
      onTap: () {
        if (banner != null) widget.onBanner(banner);
        setState(() => _currentTab = 1);
      },
      child: ColoredBox(
        color: const Color(0xFF060913),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full-bleed HD food photography anchored on the right
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: _buildHeroImage(imageUrl),
              ),
            ),
            // Left-to-right obsidian gradient scrim for razor-sharp contrast
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF060913),
                    Color(0xEB080C17),
                    Color(0x52080C17),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.36, 0.62, 1.0],
                ),
              ),
            ),
            // Left promotional headline & subtitle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 130, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (headline == 'Order Food Online')
                    const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Order Food\n',
                            style: TextStyle(
                              fontSize: 20.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.12,
                            ),
                          ),
                          TextSpan(
                            text: 'Online',
                            style: TextStyle(
                              fontSize: 21.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFACC15),
                              height: 1.12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.15,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 8),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFE2E8F0),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage(String imageUrl) {
    final hdFallback = Image.asset(
      'assets/images/storefront_promo_pizza_hd.jpg',
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      alignment: Alignment.centerRight,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(
          Icons.local_pizza_rounded,
          size: 72,
          color: Color(0xFFF59E0B),
        ),
      ),
    );

    final isLegacyStub =
        imageUrl.isEmpty ||
        imageUrl.contains('tpl_food_bogo_pizza') ||
        imageUrl.contains('tpl_food_diwali_pizza') ||
        imageUrl.contains('restaurant_cooking_pan');
    if (isLegacyStub) return hdFallback;

    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        alignment: Alignment.centerRight,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => hdFallback,
      );
    }
    final resolved = imageUrl.startsWith('/uploads/')
        ? ApiEndpoints.resolveMediaUrl(imageUrl)
        : imageUrl;
    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return Image.network(
        resolved,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        alignment: Alignment.centerRight,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => hdFallback,
      );
    }
    return hdFallback;
  }

  Widget _quickActionsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionTile(
            iconWidget: Transform.rotate(
              angle: 0.785,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFFEA580C), width: 2),
                ),
                child: Transform.rotate(
                  angle: -0.785,
                  child: const Center(
                    child: Icon(
                      Icons.percent_rounded,
                      size: 16,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ),
              ),
            ),
            label: 'Offers',
            onTap: _openOffersSheet,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionTile(
            iconWidget: const Icon(
              Icons.star_rounded,
              size: 30,
              color: Color(0xFFF59E0B),
            ),
            label: 'Favorites',
            onTap: _openFavoritesSheet,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionTile(
            iconWidget: const Icon(
              Icons.shopping_bag_outlined,
              size: 27,
              color: Color(0xFF1D4ED8),
            ),
            label: 'Order\nHistory',
            onTap: () {
              setState(() => _currentTab = 3);
              unawaited(_loadOrderHistory());
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionTile(
            iconWidget: const Icon(
              Icons.headset_mic_outlined,
              size: 27,
              color: Color(0xFF1D4ED8),
            ),
            label: 'Support',
            onTap: _openSupportSheet,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionTile({
    required Widget iconWidget,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cardBorder, width: 1.15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 32, child: Center(child: iconWidget)),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.2,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _popularPicksSection() {
    final available = widget.data.menuItems
        .where((i) => i.isAvailable && !i.isOutOfStock)
        .toList();
    final picks = (available.isNotEmpty ? available : widget.data.menuItems)
        .take(8)
        .toList();
    if (picks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Popular Picks',
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
            ),
            InkWell(
              onTap: () => setState(() => _currentTab = 1),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Color(0xFF1D4ED8),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = ((constraints.maxWidth - 10) / 2).clamp(
              132.0,
              204.0,
            );
            return SizedBox(
              height: 216,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: picks.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: cardWidth,
                    child: _popularPickCard(picks[index]),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _popularPickCard(MenuItemModel item) {
    final qty = _getItemCartQuantity(item);
    final available = canOrder && item.isAvailable && !item.isOutOfStock;
    final variantsChip = _buildVariantsLabel(item, compact: true);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => widget.onProduct(item),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _cardBorder, width: 1.15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(13),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 98,
                  child: _buildProductMedia(
                    item,
                    width: double.infinity,
                    height: 98,
                    radius: 0,
                    isPopularCard: true,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1.5),
                            child: buildFoodTypeBadge(item.itemType, size: 15),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                                height: 1.18,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (variantsChip != null) variantsChip,
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              money(item.effectivePrice),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: _ink,
                              ),
                            ),
                          ),
                          if (!available)
                            const SizedBox.shrink()
                          else if (qty == 0)
                            InkWell(
                              onTap: () => _handleQuickAdd(item),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: 31,
                                height: 31,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDBEAFE),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF93C5FD),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  size: 19,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            )
                          else
                            _buildQuantityStepper(
                              quantity: qty,
                              onDecrement: () => _handleDecrementItem(item),
                              onIncrement: () => _handleIncrementItem(item),
                              height: 28,
                              iconSize: 13.5,
                              fontSize: 12,
                              horizontalPad: 6,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomOfferBanner() {
    String title;
    String subtitle;
    if (_coupons.isNotEmpty) {
      final c = _coupons.first;
      title = c.title.isNotEmpty
          ? c.title
          : (c.isPercentage
                ? 'Flat ${c.discountValue.toInt()}% OFF'
                : 'Flat ${money(c.discountValue)} OFF');
      subtitle = c.description.isNotEmpty
          ? c.description
          : 'Use code ${c.code} at checkout';
    } else {
      final offerBanner = widget.data.banners
          .where((b) => (b.discountText ?? '').trim().isNotEmpty)
          .firstOrNull;
      if (offerBanner != null) {
        title = offerBanner.discountText!.trim();
        subtitle = offerBanner.subtitle.isNotEmpty
            ? offerBanner.subtitle
            : 'Tap to view active offers';
      } else if (restaurant.freeDeliveryEnabled &&
          restaurant.freeDeliveryMinOrder > 0) {
        title = 'Free Delivery';
        subtitle =
            'on orders above ${money(restaurant.freeDeliveryMinOrder)}';
      } else {
        title = 'Fresh & Fast Delivery';
        subtitle =
            'Order direct from ${restaurant.name.isNotEmpty ? restaurant.name : "our kitchen"}';
      }
    }

    return InkWell(
      onTap: _coupons.isNotEmpty
          ? _openOffersSheet
          : () => setState(() => _currentTab = 1),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF6D28D9),
              Color(0xFF5B21B6),
              Color(0xFF4338CA),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B21B6).withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              right: -10,
              top: -8,
              child: Transform.rotate(
                angle: 0.45,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 22,
              bottom: -10,
              child: Transform.rotate(
                angle: -0.35,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.28),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/loyalty_hero_gift_3d.png',
                          width: 48,
                          height: 48,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.card_giftcard_rounded,
                            color: Color(0xFFFDE047),
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2.5),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.2,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.94),
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
    );
  }

  // ===========================================================================
  // SCREEN 2: OUR MENU (ADD TO CART)
  // ===========================================================================
  Widget _buildMenuTab() {
    var menuList = widget.items;
    if (_vegOnly) {
      menuList = menuList.where((i) => i.isVeg).toList();
    }

    final Map<String, List<MenuItemModel>> grouped = {};
    for (final item in menuList) {
      final cat = item.category.trim().isNotEmpty
          ? item.category.trim()
          : 'Dishes';
      grouped.putIfAbsent(cat, () => []).add(item);
    }

    final nonAllCats = widget.data.categories
        .where((c) => c != 'All')
        .take(3)
        .map((c) => c.toLowerCase())
        .toList();
    final searchHint = nonAllCats.length >= 2
        ? 'Search ${nonAllCats.sublist(0, nonAllCats.length - 1).join(", ")} & ${nonAllCats.last}'
        : 'Search pizzas, sides & drinks';

    return Stack(
      children: [
        CustomScrollView(
          key: const PageStorageKey('storefront-menu-tab'),
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top App Bar: <- Our Menu
                    _buildSectionScreenHeader(
                      'Our Menu',
                      () => setState(() => _currentTab = 0),
                    ),

                    const SizedBox(height: 12),

                    // High-Contrast Pill Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _cardBorder, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: widget.searchController,
                        onChanged: widget.onSearch,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                        decoration: InputDecoration(
                          hintText: searchHint,
                          hintStyle: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF1E293B),
                            size: 21,
                          ),
                          suffixIcon: widget.searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                    color: _ink,
                                  ),
                                  onPressed: () {
                                    widget.searchController.clear();
                                    widget.onSearch('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Category Filter Pills
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: widget.data.categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = widget.data.categories[index];
                          final isSelected = widget.category == cat;
                          final catImage = _categoryFirstProductImage(cat);
                          return InkWell(
                            onTap: () => widget.onCategory(cat),
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              padding: EdgeInsets.fromLTRB(
                                catImage.isNotEmpty ? 6 : 14,
                                6,
                                14,
                                6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ? brand : Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isSelected ? brand : _cardBorder,
                                  width: 1.15,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (catImage.isNotEmpty)
                                    Container(
                                      width: 28,
                                      height: 28,
                                      padding: const EdgeInsets.all(1.5),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.white
                                              : _cardBorder,
                                          width: 1,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: buildFoodThumbnail(
                                          catImage,
                                          size: 25,
                                          radius: 12.5,
                                        ),
                                      ),
                                    )
                                  else
                                    Icon(
                                      cat == 'All'
                                          ? Icons.grid_view_rounded
                                          : _getCategoryIcon(cat),
                                      size: 16.5,
                                      color: isSelected ? Colors.white : _ink,
                                    ),
                                  const SizedBox(width: 7),
                                  Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                      color: isSelected ? Colors.white : _ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // High-Contrast Veg Only Switch Toggle
                    Row(
                      children: [
                        const Text(
                          'Veg only',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Transform.scale(
                          scale: 0.84,
                          child: Switch(
                            value: _vegOnly,
                            activeTrackColor: const Color(0xFF15803D),
                            activeThumbColor: Colors.white,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: const Color(0xFF94A3B8),
                            trackOutlineColor: const WidgetStatePropertyAll(
                              Color(0xFF64748B),
                            ),
                            onChanged: (val) => setState(() => _vegOnly = val),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (grouped.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: Color(0xFF475569),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No matching dishes found',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () {
                            widget.searchController.clear();
                            widget.onSearch('');
                            widget.onCategory('All');
                            setState(() => _vegOnly = false);
                          },
                          child: const Text(
                            'Reset filters',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  14,
                  0,
                  14,
                  widget.cartCount > 0 ? 94 : 22,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final catName = grouped.keys.elementAt(index);
                    final catDishes = grouped[catName]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 9),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  catName,
                                  style: const TextStyle(
                                    fontSize: 17.5,
                                    fontWeight: FontWeight.w900,
                                    color: _ink,
                                  ),
                                ),
                              ),
                              Text(
                                '${catDishes.length} ${catDishes.length == 1 ? "item" : "items"}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...catDishes.map(
                          (dish) => Padding(
                            padding: const EdgeInsets.only(bottom: 11),
                            child: _dishCard(dish),
                          ),
                        ),
                      ],
                    );
                  }, childCount: grouped.keys.length),
                ),
              ),
          ],
        ),

        // Floating White Sticky Cart Bar matching Screen 2
        if (widget.cartCount > 0)
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 9, 9, 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _cardBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    color: _ink,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text:
                                '${widget.cartCount} ${widget.cartCount == 1 ? "item" : "items"}  |  ',
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: money(widget.cartTotal),
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => setState(() => _currentTab = 2),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ctaBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(132, 42),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Cart',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _dishCard(MenuItemModel item) {
    final qty = _getItemCartQuantity(item);
    final available = canOrder && item.isAvailable && !item.isOutOfStock;
    final hasStrike =
        item.hasDiscount && item.price > item.effectivePrice;
    final variantsSection = _buildVariantsLabel(item);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => widget.onProduct(item),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder, width: 1.15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProductMedia(item, width: 92, height: 92, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: buildFoodTypeBadge(item.itemType, size: 16),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (item.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _muted,
                          height: 1.32,
                        ),
                      ),
                    ],
                    if (variantsSection != null) variantsSection,
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Wrap(
                            spacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                money(item.effectivePrice),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: _ink,
                                ),
                              ),
                              if (hasStrike)
                                Text(
                                  money(item.price),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!available)
                          const SizedBox.shrink()
                        else if (qty == 0)
                          ElevatedButton.icon(
                            onPressed: () => _handleQuickAdd(item),
                            icon: const Icon(
                              Icons.shopping_cart_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              'Add',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _ctaBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              minimumSize: const Size(98, 36),
                            ),
                          )
                        else
                          _buildQuantityStepper(
                            quantity: qty,
                            onDecrement: () => _handleDecrementItem(item),
                            onIncrement: () => _handleIncrementItem(item),
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
    );
  }

  // ===========================================================================
  // SCREEN 3: YOUR CART (DELIVERY ADDRESS & BILL SUMMARY)
  // ===========================================================================
  Widget _buildCartTab() {
    final cartList = widget.cartItems ?? [];
    final hasAddress = _localDeliveryAddress.trim().isNotEmpty;

    return Column(
      children: [
        // Top App Bar: <- Your Cart
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 6),
          child: _buildSectionScreenHeader(
            'Your Cart',
            () => setState(() => _currentTab = 1),
          ),
        ),

        Expanded(
          child: cartList.isEmpty && widget.cartCount == 0
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_cart_outlined,
                          size: 58,
                          color: Color(0xFF475569),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Your cart is empty',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Add tasty items from the menu to get started.',
                          style: TextStyle(fontSize: 13.5, color: _muted),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: () => setState(() => _currentTab = 1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _ctaBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            'Explore Menu',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. High-Contrast Delivery Address Pill
                      InkWell(
                        onTap: _pickDeliveryAddress,
                        borderRadius: BorderRadius.circular(
                          hasAddress ? 16 : 24,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(
                              hasAddress ? 16 : 24,
                            ),
                            border: Border.all(
                              color: const Color(0xFF3B82F6),
                              width: 1.3,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: Color(0xFF1D4ED8),
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: hasAddress
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Deliver to ${_selectedAddressModel?.label ?? "Address"}',
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: _ink,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _localDeliveryAddress,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                              color: _muted,
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Text(
                                        'Enter Delivery Address',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: _ink,
                                        ),
                                      ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF1D4ED8),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 2. Cart Items List
                      ...List.generate(cartList.length, (index) {
                        final cItem = cartList[index];
                        final addonLabels = cItem.selectedAddons
                            .where((a) => a.isSelected)
                            .map((a) => a.name)
                            .join(', ');
                        final subInfo = [
                          if (cItem.selectedSize != null)
                            cItem.selectedSize!.name,
                          if (addonLabels.isNotEmpty) addonLabels,
                        ].join(' • ');

                        return Container(
                          margin: const EdgeInsets.only(bottom: 11),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: _cardBorder,
                              width: 1.15,
                            ),
                          ),
                          child: Row(
                            children: [
                              buildFoodThumbnail(
                                _primaryProductImage(cItem.item),
                                size: 68,
                                radius: 11,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        buildFoodTypeBadge(
                                          cItem.item.itemType,
                                          size: 15,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            cItem.item.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w800,
                                              color: _ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (subInfo.isNotEmpty) ...[
                                      const SizedBox(height: 2.5),
                                      Text(
                                        subInfo,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: _muted,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      money(cItem.totalPrice),
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w900,
                                        color: _ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildQuantityStepper(
                                quantity: cItem.quantity,
                                horizontalPad: 9,
                                onDecrement: () {
                                  widget.onUpdateQuantity?.call(
                                    cItem,
                                    cItem.quantity - 1,
                                  );
                                  _recalculateLocalCouponDiscount();
                                },
                                onIncrement: () {
                                  widget.onUpdateQuantity?.call(
                                    cItem,
                                    cItem.quantity + 1,
                                  );
                                  _recalculateLocalCouponDiscount();
                                },
                              ),
                            ],
                          ),
                        );
                      }),

                      // 3. + Add more items link
                      InkWell(
                        onTap: () => setState(() => _currentTab = 1),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 5),
                          child: Text(
                            '+ Add more items',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // 4. High-Contrast Cooking Instructions Card
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _cardBorder,
                            width: 1.15,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: Color(0xFF1E293B),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _cookingInstructionsController,
                                maxLines: 2,
                                minLines: 1,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: _ink,
                                ),
                                decoration: const InputDecoration(
                                  hintText:
                                      'Add cooking instructions\n(e.g., less spicy, extra cheese)',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 12.5,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Optional coupon strip when coupons exist or applied
                      if (_appliedCouponCode != null ||
                          _coupons.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () => _openOffersSheet(fromCart: true),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _appliedCouponCode != null
                                    ? const Color(0xFF16A34A)
                                    : _cardBorder,
                                width: 1.15,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.local_offer_outlined,
                                  size: 19,
                                  color: _appliedCouponCode != null
                                      ? const Color(0xFF15803D)
                                      : brand,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    _appliedCouponCode != null
                                        ? 'Coupon $_appliedCouponCode applied (-${money(_couponDiscount)})'
                                        : 'Apply Offer / Coupon (${_coupons.length} available)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _appliedCouponCode != null
                                          ? const Color(0xFF14532D)
                                          : _ink,
                                    ),
                                  ),
                                ),
                                if (_appliedCouponCode != null)
                                  InkWell(
                                    onTap: () => setState(() {
                                      _appliedCouponCode = null;
                                      _couponDiscount = 0.0;
                                    }),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: _ink,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: _ink,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // 5. High-Contrast Bill Summary Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: _cardBorder,
                            width: 1.15,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                15,
                                14,
                                15,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Bill Summary',
                                    style: TextStyle(
                                      fontSize: 17.5,
                                      fontWeight: FontWeight.w900,
                                      color: _ink,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildBillRow('Subtotal', money(_subtotal)),
                                  if (_effectiveTaxRate > 0) ...[
                                    const SizedBox(height: 7),
                                    _buildBillRow(
                                      'GST (${_effectiveTaxRate % 1 == 0 ? _effectiveTaxRate.toInt() : _effectiveTaxRate}%)',
                                      money(_taxAmount),
                                    ),
                                  ],
                                  if (restaurant.deliveryBaseCharge > 0 ||
                                      (restaurant.freeDeliveryEnabled &&
                                          restaurant.freeDeliveryMinOrder >
                                              0)) ...[
                                    const SizedBox(height: 7),
                                    _buildBillRow(
                                      'Delivery Charge',
                                      _deliveryFee == 0
                                          ? 'FREE'
                                          : money(_deliveryFee),
                                      valueColor: _deliveryFee == 0
                                          ? const Color(0xFF15803D)
                                          : null,
                                    ),
                                  ],
                                  if (_couponDiscount > 0) ...[
                                    const SizedBox(height: 7),
                                    _buildBillRow(
                                      'Coupon Discount',
                                      '-${money(_couponDiscount)}',
                                      valueColor: const Color(0xFF15803D),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 12,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(14),
                                ),
                                border: Border(
                                  top: BorderSide(
                                    color: Color(0xFFBFDBFE),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: _buildBillRow(
                                'Total Amount',
                                money(_grandTotal),
                                isBold: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        if (cartList.isNotEmpty || widget.cartCount > 0)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _cardBorder, width: 1.1)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _handleProceedToCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _ctaBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Proceed to Checkout',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBillRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isBold ? 16.5 : 14,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w500,
              color: isBold ? _ink : _muted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 17 : 14.5,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: valueColor ?? _ink,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 3: ORDERS TAB (REAL LIVE TRACKING & HISTORY)
  // ===========================================================================
  Widget _buildOrdersTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _cardBorder, width: 1.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Orders',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              IconButton(
                onPressed: _loadOrderHistory,
                icon: const Icon(Icons.refresh_rounded, color: _ink, size: 20),
                tooltip: 'Refresh orders',
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingOrders && _orderHistory.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _orderHistory.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 46,
                          color: Color(0xFF475569),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No orders yet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Your placed delivery orders and live tracking status will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: _muted),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() => _currentTab = 1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _ctaBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 9,
                            ),
                          ),
                          child: const Text(
                            'Browse Menu',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOrderHistory,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(14),
                    itemCount: _orderHistory.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final order = _orderHistory[index];
                      final resolved = CustomerOrderStatus.resolve({
                        'status': order.status,
                      });
                      final totalQty = order.items.fold<int>(
                        0,
                        (s, item) => s + item.quantity,
                      );
                      final isCancelled =
                          resolved == CustomerOrderStatus.cancelled;
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => StorefrontViewportFrame(
                                  child: CustomerMyOrdersScreen(
                                    order: order,
                                    restaurant: restaurant,
                                    themeColor: brand,
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _cardBorder,
                                width: 1.15,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        order.orderNumber,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w900,
                                          color: _ink,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isCancelled
                                            ? const Color(0xFFFEE2E2)
                                            : const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        resolved.label,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: isCancelled
                                              ? const Color(0xFF991B1B)
                                              : const Color(0xFF14532D),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (order.items.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    order.items
                                        .map((i) => '${i.quantity}x ${i.name}')
                                        .join(', '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                                const Divider(height: 16, color: _cardBorder),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '$totalQty ${totalQty == 1 ? "item" : "items"} • ${order.paymentMethod}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _ink,
                                      ),
                                    ),
                                    Text(
                                      money(order.grandTotal),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        color: brand,
                                      ),
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
                ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 4: ACCOUNT TAB
  // ===========================================================================
  Widget _buildAccountTab() {
    final customer = _localCustomer;
    final isVerified =
        customer != null && !customer.id.startsWith('guest_');

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Account',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),

          // Profile card
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cardBorder, width: 1.15),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: brand.withValues(alpha: 0.14),
                  child: Icon(Icons.person_rounded, size: 24, color: brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer?.name.isNotEmpty == true
                            ? customer!.name
                            : 'Guest Customer',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        customer?.phone.isNotEmpty == true
                            ? customer!.phone
                            : 'Sign in to save orders & addresses',
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                ),
                if (!isVerified)
                  ElevatedButton(
                    onPressed: () async {
                      final logged = await OnlineLoginModalSheet.show(
                        context,
                        restaurant: restaurant,
                      );
                      if (logged != null && mounted) {
                        setState(() => _localCustomer = logged);
                        widget.onUpdateCustomer?.call(logged);
                        unawaited(_loadOrderHistory());
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ctaBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                    ),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Saved Delivery Address card
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cardBorder, width: 1.15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Color(0xFF1D4ED8),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Delivery Address',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _localDeliveryAddress.isNotEmpty
                      ? _localDeliveryAddress
                      : 'No delivery address added yet',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: _muted,
                    height: 1.38,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _pickDeliveryAddress,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _cardBorder, width: 1.2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    minimumSize: const Size(80, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _localDeliveryAddress.isNotEmpty
                        ? 'Change Address'
                        : 'Add Delivery Address',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Quick Links
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cardBorder, width: 1.15),
            ),
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.storefront_outlined,
                    size: 19,
                    color: Color(0xFF1D4ED8),
                  ),
                  title: const Text(
                    'Restaurant Information',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 19),
                  onTap: () => setState(() => _showRestaurantInfoView = true),
                ),
                const Divider(height: 1, color: _cardBorder),
                ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.receipt_long_outlined,
                    size: 19,
                    color: Color(0xFF1D4ED8),
                  ),
                  title: const Text(
                    'Order History',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 19),
                  onTap: () {
                    setState(() => _currentTab = 3);
                    unawaited(_loadOrderHistory());
                  },
                ),
                const Divider(height: 1, color: _cardBorder),
                ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.headset_mic_outlined,
                    size: 19,
                    color: Color(0xFF15803D),
                  ),
                  title: const Text(
                    'Help & Support',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 19),
                  onTap: _openSupportSheet,
                ),
                if (customer != null) ...[
                  const Divider(height: 1, color: _cardBorder),
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.logout_rounded,
                      size: 19,
                      color: Color(0xFFDC2626),
                    ),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    onTap: () async {
                      await TableQrPhoneAuth(
                        restaurantId: restaurant.id,
                      ).signOut();
                      await _apiService.logout();
                      if (mounted) {
                        setState(() {
                          _localCustomer = null;
                          _orderHistory = [];
                        });
                        widget.onUpdateCustomer?.call(null);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StorefrontMenuLoading extends StatefulWidget {
  final RestaurantModel? restaurant;
  final Widget Function(String?, String, double) avatar;

  const StorefrontMenuLoading({
    super.key,
    this.restaurant,
    required this.avatar,
  });

  @override
  State<StorefrontMenuLoading> createState() => _StorefrontMenuLoadingState();
}

class _StorefrontMenuLoadingState extends State<StorefrontMenuLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Color get _brand =>
      Color(widget.restaurant?.storefrontThemeColor ?? 0xFF2563EB);

  Widget _shimmerBox(double height, {double? width, double radius = 12}) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE2E8F0),
                Color(0xFFF1F5F9),
                Color(0xFFE2E8F0),
              ],
              stops: [
                (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                _shimmerController.value,
                (_shimmerController.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.restaurant?.name ?? '';
    final cuisine = widget.restaurant?.cuisineType ?? '';

    return StorefrontViewportFrame(
      child: Scaffold(
        backgroundColor: storefrontBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    widget.avatar(
                      widget.restaurant?.logoUrl,
                      name.isEmpty ? 'Menu' : name,
                      60,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Opening menu' : name,
                            style: const TextStyle(
                              fontSize: 18.5,
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name.isEmpty
                                ? cuisine
                                : "Loading $name's menu...",
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    color: _brand,
                    backgroundColor: _brand.withValues(alpha: .14),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 14),
                _shimmerBox(154, radius: 16),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _shimmerBox(82, radius: 14)),
                    const SizedBox(width: 8),
                    Expanded(child: _shimmerBox(82, radius: 14)),
                    const SizedBox(width: 8),
                    Expanded(child: _shimmerBox(82, radius: 14)),
                    const SizedBox(width: 8),
                    Expanded(child: _shimmerBox(82, radius: 14)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _shimmerBox(216, radius: 14)),
                    const SizedBox(width: 10),
                    Expanded(child: _shimmerBox(216, radius: 14)),
                  ],
                ),
                const SizedBox(height: 14),
                _shimmerBox(76, radius: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
