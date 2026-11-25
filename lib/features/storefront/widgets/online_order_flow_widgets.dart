import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/restaurant_model.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/customer_storefront_flow_models.dart';
import '../services/customer_storefront_api_service.dart';

/// ============================================================================
/// PERSISTENT 5-TAB BOTTOM NAVIGATION BAR
/// Matches Screen 1 design: [Home, Menu, Cart, Orders, Account]
/// ============================================================================
class OnlineStorefrontBottomBar extends StatelessWidget {
  final int currentIndex;
  final int cartCount;
  final ValueChanged<int> onTabSelected;
  final Color activeColor;

  const OnlineStorefrontBottomBar({
    super.key,
    required this.currentIndex,
    required this.cartCount,
    required this.onTabSelected,
    this.activeColor = const Color(0xFF2563EB),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            offset: const Offset(0, -3),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              Expanded(child: _buildNavItem(0, Icons.home_rounded, 'Home')),
              Expanded(
                child: _buildNavItem(1, Icons.grid_view_rounded, 'Menu'),
              ),
              Expanded(
                child: _buildCartItem(
                  2,
                  Icons.shopping_cart_outlined,
                  'Cart',
                ),
              ),
              Expanded(
                child: _buildNavItem(3, Icons.receipt_long_outlined, 'Orders'),
              ),
              Expanded(
                child: _buildNavItem(4, Icons.person_outline_rounded, 'Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    final color = isSelected ? activeColor : const Color(0xFF1E293B);
    return InkWell(
      onTap: () => onTabSelected(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    final color = isSelected ? activeColor : const Color(0xFF1E293B);
    return InkWell(
      onTap: () => onTabSelected(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 20, color: color),
                Positioned(
                  right: -8,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1.5,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 15,
                      minHeight: 15,
                    ),
                    child: Center(
                      child: Text(
                        cartCount > 99 ? '99+' : '$cartCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// VEG / NON-VEG INDICATOR BADGE
/// Green square with green circle for Veg, Red square with red mark for Non-Veg
/// ============================================================================
Widget buildFoodTypeBadge(String type) {
  final lower = type.toLowerCase();
  final isNonVeg = lower.contains('non');
  final isEgg = lower.contains('egg');
  final color = isNonVeg
      ? const Color(0xFFDC2626)
      : isEgg
      ? const Color(0xFFD97706)
      : const Color(0xFF16A34A);
  return Container(
    width: 14,
    height: 14,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      border: Border.all(color: color, width: 1.3),
      borderRadius: BorderRadius.circular(3),
      color: Colors.white,
    ),
    child: Center(
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: color,
          shape: isNonVeg ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: isNonVeg ? BorderRadius.circular(1) : null,
        ),
      ),
    ),
  );
}

final Map<String, Uint8List> _foodThumbBytesCache = {};

/// ============================================================================
/// FOOD THUMBNAIL WITH ASSET / NETWORK / BASE64 / PLACEHOLDER FALLBACK
/// ============================================================================
Widget buildFoodThumbnail(
  String? imageUrl, {
  double? size,
  double width = 75,
  double height = 75,
  double radius = 12,
  BoxFit fit = BoxFit.cover,
}) {
  final w = size ?? width;
  final h = size ?? height;
  final side = w < h ? w : h;
  final iconFallback = Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFFCBD5E1)),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: side * 0.62,
          height: side * 0.62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.92),
          ),
        ),
        Icon(
          Icons.restaurant_menu_rounded,
          size: side * 0.36,
          color: const Color(0xFF334155),
        ),
      ],
    ),
  );

  var url = (imageUrl ?? '').trim();
  if (url.isEmpty) {
    return iconFallback;
  }

  if (url.startsWith('/uploads/')) {
    url = ApiEndpoints.resolveMediaUrl(url);
  }

  if (url.startsWith('data:image') ||
      url.startsWith('data:') ||
      (url.length > 100 &&
          !url.startsWith('http') &&
          !url.startsWith('assets/'))) {
    try {
      final clean = url.contains(',') ? url.split(',').last : url;
      final normalized = clean
          .replaceAll('\n', '')
          .replaceAll('\r', '')
          .trim();
      Uint8List? bytes = _foodThumbBytesCache[normalized];
      if (bytes == null) {
        bytes = base64Decode(normalized);
        if (_foodThumbBytesCache.length > 64) {
          _foodThumbBytesCache.remove(_foodThumbBytesCache.keys.first);
        }
        _foodThumbBytesCache[normalized] = bytes;
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          bytes,
          width: w,
          height: h,
          fit: fit,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => iconFallback,
        ),
      );
    } catch (_) {
      return iconFallback;
    }
  }

  if (url.startsWith('assets/')) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        url,
        width: w,
        height: h,
        fit: fit,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => iconFallback,
      ),
    );
  }

  if (url.startsWith('http://') || url.startsWith('https://')) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: w,
        height: h,
        fit: fit,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => iconFallback,
      ),
    );
  }

  return iconFallback;
}

/// ============================================================================
/// RESPONSIVE MOBILE VIEWPORT WRAPPER FOR CUSTOMER STOREFRONT SCREENS
/// Frames the storefront at phone width (430px) on wider tablets/desktops
/// and renders edge-to-edge on handheld mobile screens.
/// ============================================================================
class StorefrontViewportFrame extends StatelessWidget {
  final Widget child;
  final Color outerColor;

  const StorefrontViewportFrame({
    super.key,
    required this.child,
    this.outerColor = const Color(0xFFDCE3EC),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 440) {
          return child;
        }
        return ColoredBox(
          color: outerColor,
          child: Center(
            child: Container(
              width: 430,
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2F7),
                border: Border.symmetric(
                  vertical: BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 22,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// ============================================================================
/// LIGHT THEME SCOPE FOR CUSTOMER DELIVERY STOREFRONT & MODAL SHEETS
/// Ensures crisp dark ink text and inputs even when the parent app uses
/// dark GlassTheme.themeData.
/// ============================================================================
ThemeData storefrontLightTheme(BuildContext context) {
  final parentFont = Theme.of(context).textTheme.bodyMedium?.fontFamily;
  final base = ThemeData.light(useMaterial3: true);
  const ink = Color(0xFF090D16);
  const brand = Color(0xFF1D4ED8);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: brand,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: parentFont,
      bodyColor: ink,
      displayColor: ink,
    ),
    iconTheme: const IconThemeData(color: ink),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: brand,
      selectionColor: Color(0x331D4ED8),
      selectionHandleColor: brand,
    ),
  );
}

/// ============================================================================
/// BLURRED MODAL WRAPPER FOR CHECKOUT POPUPS (SCREENS 4 & 5)
/// Renders the underlying Cart screen blurred behind the white popup sheet.
/// ============================================================================
Future<T?> showBlurredStorefrontSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.34),
    builder: (ctx) => Theme(
      data: storefrontLightTheme(ctx),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).maybePop(),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: builder(ctx),
            ),
          ),
        ],
      ),
    ),
  );
}

/// ============================================================================
/// SCREEN 4: LOGIN BOTTOM SHEET MODAL (BEFORE CHECKOUT)
/// Matches design:
/// - Blurred Cart background + drag handle + X close button
/// - Tilted phone with user icon & pink/yellow shopping bags illustration
/// - "Login to Continue"
/// - "Log in to save your orders, track delivery, and get exclusive offers."
/// - 🇮🇳 +91 v | Enter mobile number
/// - Send OTP button (real WhatsApp OTP verification)
/// - OR divider
/// - Continue as Guest outlined button
/// ============================================================================
class OnlineLoginModalSheet extends StatefulWidget {
  final RestaurantModel restaurant;
  final ValueChanged<CustomerProfileModel> onLoggedIn;
  final VoidCallback onContinueAsGuest;

  const OnlineLoginModalSheet({
    super.key,
    required this.restaurant,
    required this.onLoggedIn,
    this.onContinueAsGuest = _defaultNoop,
  });

  static void _defaultNoop() {}

  static Future<CustomerProfileModel?> show(
    BuildContext context, {
    required RestaurantModel restaurant,
    VoidCallback? onContinueAsGuest,
  }) {
    return showBlurredStorefrontSheet<CustomerProfileModel>(
      context: context,
      builder: (ctx) => OnlineLoginModalSheet(
        restaurant: restaurant,
        onLoggedIn: (customer) => Navigator.pop(ctx, customer),
        onContinueAsGuest: () => onContinueAsGuest?.call(),
      ),
    );
  }

  @override
  State<OnlineLoginModalSheet> createState() => _OnlineLoginModalSheetState();
}

class _OnlineLoginModalSheetState extends State<OnlineLoginModalSheet> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final CustomerStorefrontApiService _api = CustomerStorefrontApiService();

  bool _isOtpSent = false;
  bool _isGuestMode = false;
  bool _isLoading = false;
  String? _errorMessage;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String _cleanDigits(String raw) {
    return raw
        .replaceAll(RegExp(r'\D'), '')
        .replaceFirst(RegExp(r'^91(?=\d{10}$)'), '');
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleSendOtp() async {
    final digits = _cleanDigits(_phoneController.text);
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      setState(
        () => _errorMessage = 'Please enter a valid 10-digit mobile number',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _api.sendOtp(
        '+91$digits',
        restaurantId: widget.restaurant.id,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOtpSent = true;
        });
        _startResendCooldown();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Could not send WhatsApp OTP right now. Please try again or Continue as Guest.';
        });
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final digits = _cleanDigits(_phoneController.text);
    final otp = _otpController.text.trim();
    final name = _nameController.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _errorMessage = 'Please enter the 6-digit WhatsApp OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final customer = await _api.verifyOtp(
        '+91$digits',
        otp,
        restaurantId: widget.restaurant.id,
        name: name.isNotEmpty ? name : null,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (customer != null) {
        widget.onLoggedIn(customer);
      } else {
        setState(
          () => _errorMessage =
              'Incorrect or expired OTP. Please check WhatsApp and try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to verify OTP right now. Please try again.';
        });
      }
    }
  }

  void _handleGuestTap() {
    final digits = _cleanDigits(_phoneController.text);
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      final guestName = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : 'Guest Customer';
      widget.onLoggedIn(
        CustomerProfileModel(
          id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
          phone: '+91$digits',
          name: guestName,
          addresses: const [],
        ),
      );
      return;
    }
    setState(() {
      _isGuestMode = true;
      _isOtpSent = false;
      _errorMessage = null;
    });
  }

  void _confirmGuestCheckout() {
    final digits = _cleanDigits(_phoneController.text);
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      setState(
        () => _errorMessage =
            'Enter a 10-digit mobile number for delivery updates',
      );
      return;
    }
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Guest Customer';
    widget.onLoggedIn(
      CustomerProfileModel(
        id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
        phone: '+91$digits',
        name: name,
        addresses: const [],
      ),
    );
  }

  Widget _buildShoppingPhoneIllustration() {
    return SizedBox(
      height: 112,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Subtle celebratory accents
            Positioned(
              top: 6,
              left: -34,
              child: Transform.rotate(
                angle: -0.45,
                child: Container(
                  width: 14,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFB7185),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: -36,
              child: Transform.rotate(
                angle: 0.45,
                child: Container(
                  width: 14,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Left Pink Shopping Bag
            Positioned(
              left: -38,
              bottom: 6,
              child: Transform.rotate(
                angle: -0.14,
                child: Container(
                  width: 46,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFB7185), Color(0xFFF43F5E)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF43F5E).withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(-2, 4),
                      ),
                    ],
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 16,
                      height: 10,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Right Yellow Shopping Bag
            Positioned(
              right: -36,
              bottom: 6,
              child: Transform.rotate(
                angle: 0.14,
                child: Container(
                  width: 44,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFDE047), Color(0xFFF59E0B)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 15,
                      height: 9,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(7),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Center Tilted Smartphone
            Transform.rotate(
              angle: 0.10,
              child: Container(
                width: 60,
                height: 98,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFF1D4ED8),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 18,
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDBEAFE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 20,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Container(
              width: 22,
              height: 15,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 0.6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2.4),
                child: Column(
                  children: [
                    Expanded(child: Container(color: const Color(0xFFFF9933))),
                    Expanded(
                      child: Container(
                        color: Colors.white,
                        child: Center(
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF000080),
                                width: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: Container(color: const Color(0xFF138808))),
                  ],
                ),
              ),
            ),
          ),
          const Text(
            '+91',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: Color(0xFF64748B),
          ),
          Container(
            width: 1,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFFE2E8F0),
          ),
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF090D16),
              ),
              decoration: const InputDecoration(
                hintText: 'Enter mobile number',
                hintStyle: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF94A3B8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Top Right Close Button
              Align(
                alignment: Alignment.topRight,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),

              if (!_isGuestMode) ...[
                _buildShoppingPhoneIllustration(),
                const SizedBox(height: 10),
                const Text(
                  'Login to Continue',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF090D16),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Log in to save your orders, track delivery, and get exclusive offers.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF334155),
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    size: 28,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Continue as Guest',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Share your mobile number so the delivery partner can reach you.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 18),

              if (_isGuestMode) ...[
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF090D16),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Your name (optional)',
                        hintStyle: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 12,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildPhoneField(),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _confirmGuestCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4BF5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue to Payment',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _isGuestMode = false;
                    _errorMessage = null;
                  }),
                  child: const Text(
                    'Back to Login with OTP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ] else if (!_isOtpSent) ...[
                _buildPhoneField(),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4BF5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Send OTP',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ] else ...[
                // OTP + optional name verification
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF94A3B8),
                      width: 1.2,
                    ),
                  ),
                  child: TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: Color(0xFF090D16),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Enter 6-digit WhatsApp OTP',
                      hintStyle: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 12,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w500,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF94A3B8),
                      width: 1.2,
                    ),
                  ),
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF090D16),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Your name (optional)',
                      hintStyle: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 12,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F4BF5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Verify & Continue',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _isOtpSent = false;
                        _otpController.clear();
                        _errorMessage = null;
                      }),
                      child: const Text(
                        'Change number',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          (_isLoading || _resendSeconds > 0) ? null : _handleSendOtp,
                      child: Text(
                        _resendSeconds > 0
                            ? 'Resend in ${_resendSeconds}s'
                            : 'Resend OTP',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (!_isGuestMode) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(
                      child: Divider(color: Color(0xFFCBD5E1), thickness: 1),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: Color(0xFFCBD5E1), thickness: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGuestTap,
                    icon: const Icon(
                      Icons.person_outline_rounded,
                      size: 17,
                      color: Color(0xFF1D4ED8),
                    ),
                    label: const Text(
                      'Continue as Guest',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Color(0xFF94A3B8),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
  }
}

/// ============================================================================
/// SCREEN 5: PAYMENT METHOD POPUP MODAL
/// Matches design:
/// - Blurred Cart background + X close button
/// - Blue rounded wallet icon + "Select Payment Method"
/// - Radio 1: Pay via UPI (Google Pay, PhonePe, Paytm, etc.) [SELECTED]
/// - Radio 2: Credit / Debit Card (Visa, Mastercard, RuPay)
/// - Radio 3: Net Banking (Pay using your bank account)
/// - Radio 4: Cash on Delivery (Pay when you receive your order)
/// - Pay ₹575.40 full-width blue button
/// ============================================================================
class OnlinePaymentModalSheet extends StatefulWidget {
  final double totalAmount;
  final String currencySymbol;
  final ValueChanged<String> onPay;
  final Future<String?> Function(String paymentMethod)? onConfirmPay;

  const OnlinePaymentModalSheet({
    super.key,
    required this.totalAmount,
    this.currencySymbol = '₹',
    required this.onPay,
    this.onConfirmPay,
  });

  static Future<String?> show(
    BuildContext context, {
    required double totalAmount,
    String currencySymbol = '₹',
    Future<String?> Function(String paymentMethod)? onConfirmPay,
  }) {
    return showBlurredStorefrontSheet<String>(
      context: context,
      builder: (ctx) => OnlinePaymentModalSheet(
        totalAmount: totalAmount,
        currencySymbol: currencySymbol,
        onConfirmPay: onConfirmPay,
        onPay: (method) => Navigator.pop(ctx, method),
      ),
    );
  }

  @override
  State<OnlinePaymentModalSheet> createState() =>
      _OnlinePaymentModalSheetState();
}

class _OnlinePaymentModalSheetState extends State<OnlinePaymentModalSheet> {
  String _selectedMethod = 'UPI';
  bool _submitting = false;
  String? _errorText;

  Widget _buildUpiMark() {
    return Container(
      width: 34,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 2),
          Container(
            width: 5,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFEA4335),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 2),
          Container(
            width: 5,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF34A853),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePayTap() async {
    if (_submitting) return;
    if (widget.onConfirmPay == null) {
      widget.onPay(_selectedMethod);
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    final error = await widget.onConfirmPay!(_selectedMethod);
    if (!mounted) return;
    if (error == null) {
      widget.onPay(_selectedMethod);
    } else {
      setState(() {
        _submitting = false;
        _errorText = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedTotal =
        '${widget.currencySymbol}${widget.totalAmount.toStringAsFixed(widget.totalAmount % 1 == 0 ? 0 : 2)}';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: _submitting ? null : () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ),

            Center(
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Select Payment Method',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF090D16),
                    ),
                  ),
                ],
              ),
            ),

            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  _errorText!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            const SizedBox(height: 12),

            _buildPaymentOption(
              id: 'UPI',
              leading: _buildUpiMark(),
              title: 'Pay via UPI',
              subtitle: 'Google Pay, PhonePe, Paytm, etc.',
            ),
            const Divider(height: 1, color: Color(0xFFCBD5E1)),
            _buildPaymentOption(
              id: 'Credit / Debit Card',
              leading: const Icon(
                Icons.credit_card_rounded,
                size: 22,
                color: Color(0xFF1D4ED8),
              ),
              title: 'Credit / Debit Card',
              subtitle: 'Visa, Mastercard, RuPay',
            ),
            const Divider(height: 1, color: Color(0xFFCBD5E1)),
            _buildPaymentOption(
              id: 'Net Banking',
              leading: const Icon(
                Icons.account_balance_rounded,
                size: 22,
                color: Color(0xFF1D4ED8),
              ),
              title: 'Net Banking',
              subtitle: 'Pay using your bank account',
            ),
            const Divider(height: 1, color: Color(0xFFCBD5E1)),
            _buildPaymentOption(
              id: 'Cash on Delivery',
              leading: const Icon(
                Icons.payments_outlined,
                size: 22,
                color: Color(0xFF15803D),
              ),
              title: 'Cash on Delivery',
              subtitle: 'Pay when you receive your order',
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _submitting ? null : _handlePayTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F4BF5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(23),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    : Text(
                        'Pay $formattedTotal',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required Widget leading,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedMethod == id;
    return InkWell(
      onTap: _submitting ? null : () => setState(() => _selectedMethod = id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            SizedBox(width: 38, child: Center(child: leading)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF090D16),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF94A3B8),
                  width: isSelected ? 5.5 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// DELIVERY ADDRESS SHEET (FROM SCREEN 3 "Enter Delivery Address")
/// ============================================================================
class DeliveryAddressBottomSheet extends StatefulWidget {
  final String initialAddress;
  final List<CustomerAddressModel> savedAddresses;

  const DeliveryAddressBottomSheet({
    super.key,
    required this.initialAddress,
    this.savedAddresses = const [],
  });

  static Future<CustomerAddressModel?> show(
    BuildContext context, {
    required String initialAddress,
    List<CustomerAddressModel> savedAddresses = const [],
  }) {
    return showBlurredStorefrontSheet<CustomerAddressModel>(
      context: context,
      builder: (_) => DeliveryAddressBottomSheet(
        initialAddress: initialAddress,
        savedAddresses: savedAddresses,
      ),
    );
  }

  @override
  State<DeliveryAddressBottomSheet> createState() =>
      _DeliveryAddressBottomSheetState();
}

class _DeliveryAddressBottomSheetState
    extends State<DeliveryAddressBottomSheet> {
  static const Color _ink = Color(0xFF090D16);
  static const Color _muted = Color(0xFF334155);
  static const Color _hint = Color(0xFF475569);
  static const Color _border = Color(0xFF94A3B8);
  static const Color _brand = Color(0xFF1D4ED8);
  static const Color _ctaBlue = Color(0xFF0F4BF5);

  late final TextEditingController _addressCtrl;
  final TextEditingController _landmarkCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();
  String _label = 'Home';
  String? _error;

  @override
  void initState() {
    super.initState();
    _addressCtrl = TextEditingController(text: widget.initialAddress);
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _landmarkCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _saveAddress() {
    final street = _addressCtrl.text.trim();
    if (street.length < 5) {
      setState(() => _error = 'Please enter complete house/flat & street address');
      return;
    }
    final landmark = _landmarkCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    final parts = [
      street,
      if (landmark.isNotEmpty) landmark,
      if (pin.isNotEmpty) pin,
    ];
    Navigator.pop(
      context,
      CustomerAddressModel(
        id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
        label: _label,
        fullAddress: parts.join(', '),
        landmark: landmark,
        pinCode: pin,
        isDefault: true,
      ),
    );
  }

  IconData _tagIcon(String tag) {
    switch (tag) {
      case 'Work':
        return Icons.work_rounded;
      case 'Other':
        return Icons.place_rounded;
      default:
        return Icons.home_rounded;
    }
  }

  Widget _buildLabeledInput({
    required String caption,
    required TextEditingController controller,
    required String hintText,
    Key? fieldKey,
    IconData? prefixIcon,
    int maxLines = 1,
    int minLines = 1,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    List<TextInputFormatter>? inputFormatters,
    bool showClearButton = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          key: fieldKey,
          controller: controller,
          maxLines: maxLines,
          minLines: minLines,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          cursorColor: _brand,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _ink,
            height: 1.35,
          ),
          onChanged: (_) {
            if (_error != null || showClearButton) {
              setState(() => _error = null);
            }
          },
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: _hint,
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 17, color: _brand)
                : null,
            suffixIcon: showClearButton && controller.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Clear',
                    onPressed: () {
                      controller.clear();
                      setState(() => _error = null);
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: _hint,
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _brand, width: 1.7),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: storefrontLightTheme(context),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF94A3B8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF93C5FD)),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: _brand,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery Address',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Enter complete doorstep details for delivery',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (widget.savedAddresses.isNotEmpty) ...[
                  const Text(
                    'Saved Addresses',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.savedAddresses.map((addr) {
                    final isCurrent =
                        widget.initialAddress.trim().isNotEmpty &&
                        widget.initialAddress.trim().toLowerCase() ==
                            addr.fullAddress.trim().toLowerCase();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => Navigator.pop(context, addr),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFFEFF6FF)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrent ? _brand : _border,
                              width: isCurrent ? 1.4 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Icon(
                                  _tagIcon(addr.label),
                                  size: 15,
                                  color: _brand,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      addr.label,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: _ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      addr.fullAddress,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _muted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                isCurrent
                                    ? Icons.check_circle_rounded
                                    : Icons.chevron_right_rounded,
                                size: 18,
                                color: isCurrent ? _brand : _hint,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Divider(height: 1, color: Color(0xFFCBD5E1)),
                  ),
                  const SizedBox(height: 6),
                ],
                const Text(
                  'Save As',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: ['Home', 'Work', 'Other'].map((tag) {
                    final selected = _label == tag;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _label = tag),
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: selected ? _brand : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected ? _brand : _border,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _tagIcon(tag),
                                size: 14,
                                color: selected ? Colors.white : _ink,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : _ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                _buildLabeledInput(
                  fieldKey: const ValueKey('delivery-address-input'),
                  caption: 'House / Flat No., Building, Street *',
                  controller: _addressCtrl,
                  hintText: 'e.g. Flat 302, Green Park Residency, Sector 18',
                  prefixIcon: Icons.location_on_outlined,
                  maxLines: 2,
                  showClearButton: true,
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildLabeledInput(
                        caption: 'Landmark (Optional)',
                        controller: _landmarkCtrl,
                        hintText: 'Near park, gate, mall',
                        prefixIcon: Icons.assistant_direction_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _buildLabeledInput(
                        caption: 'Pincode',
                        controller: _pinCtrl,
                        hintText: '6 digits',
                        keyboardType: TextInputType.number,
                        textCapitalization: TextCapitalization.none,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 15,
                          color: Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _saveAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ctaBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(23),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Confirm Delivery Address',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
