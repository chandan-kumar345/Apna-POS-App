import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/restaurant_model.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/services/location_service.dart';
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
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, -4),
            blurRadius: 14,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
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
    final foregroundColor = isSelected ? Colors.white : const Color(0xFF0F172A);
    final deeperBlue = Color.lerp(activeColor, Colors.black, 0.14) ?? activeColor;

    return InkWell(
      onTap: () => onTabSelected(index),
      borderRadius: BorderRadius.circular(14),
      child: Center(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: isSelected
              ? BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [activeColor, deeperBlue],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: foregroundColor),
              const SizedBox(height: 2.5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: foregroundColor,
                    height: 1.05,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItem(int index, IconData icon) {
    final isSelected = currentIndex == index;
    final deeperBlue = Color.lerp(activeColor, Colors.black, 0.16) ?? activeColor;

    return InkWell(
      onTap: () => onTabSelected(index),
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        height: 66,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -4,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [activeColor, deeperBlue],
                  ),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.96),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: isSelected ? 0.42 : 0.30),
                      blurRadius: isSelected ? 14 : 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, size: 26, color: Colors.white),
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.6),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Center(
                          child: Text(
                            cartCount > 99 ? '99+' : '$cartCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
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
              ),
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
Widget buildFoodTypeBadge(String type, {double size = 15}) {
  final lower = type.toLowerCase();
  final isNonVeg = lower.contains('non');
  final isEgg = lower.contains('egg');
  final color = isNonVeg
      ? const Color(0xFFDC2626)
      : isEgg
      ? const Color(0xFFD97706)
      : const Color(0xFF16A34A);
  final dotSize = (size * 0.43).clamp(5.0, 9.0);
  return Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      border: Border.all(color: color, width: 1.4),
      borderRadius: BorderRadius.circular(3.5),
      color: Colors.white,
    ),
    child: Center(
      child: Container(
        width: dotSize,
        height: dotSize,
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
/// Supports Google Address autocomplete, GPS auto-fill, and mandatory Pincode.
/// ============================================================================
class DeliveryAddressBottomSheet extends StatefulWidget {
  final String initialAddress;
  final String initialLandmark;
  final String initialPinCode;
  final List<CustomerAddressModel> savedAddresses;

  const DeliveryAddressBottomSheet({
    super.key,
    required this.initialAddress,
    this.initialLandmark = '',
    this.initialPinCode = '',
    this.savedAddresses = const [],
  });

  static Future<CustomerAddressModel?> show(
    BuildContext context, {
    required String initialAddress,
    String initialLandmark = '',
    String initialPinCode = '',
    List<CustomerAddressModel> savedAddresses = const [],
  }) {
    return showBlurredStorefrontSheet<CustomerAddressModel>(
      context: context,
      builder: (_) => DeliveryAddressBottomSheet(
        initialAddress: initialAddress,
        initialLandmark: initialLandmark,
        initialPinCode: initialPinCode,
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

  final TextEditingController _googleSearchCtrl = TextEditingController();
  late final TextEditingController _addressCtrl;
  late final TextEditingController _landmarkCtrl;
  late final TextEditingController _pinCtrl;
  final FocusNode _pinFocusNode = FocusNode();

  Timer? _searchDebounce;
  List<LocationAddressResult> _suggestions = [];
  bool _isSearchingAddress = false;
  bool _isFetchingCurrentLocation = false;
  bool _isLookingUpPin = false;
  String? _autoFillStatus;
  String _lastLookedUpPin = '';
  String _label = 'Home';
  String? _error;

  @override
  void initState() {
    super.initState();
    final extractedPin = LocationService.extractPinCode(widget.initialAddress);
    final resolvedInitialPin = widget.initialPinCode.trim().isNotEmpty
        ? widget.initialPinCode.trim()
        : extractedPin;
    var cleanedAddress = widget.initialAddress.trim();
    if (resolvedInitialPin.isNotEmpty && cleanedAddress.endsWith(resolvedInitialPin)) {
      cleanedAddress = cleanedAddress
          .substring(0, cleanedAddress.length - resolvedInitialPin.length)
          .replaceAll(RegExp(r'[\s,\-]+$'), '');
    }

    _addressCtrl = TextEditingController(text: cleanedAddress);
    _landmarkCtrl = TextEditingController(text: widget.initialLandmark.trim());
    _pinCtrl = TextEditingController(text: resolvedInitialPin);
    _lastLookedUpPin = resolvedInitialPin;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _googleSearchCtrl.dispose();
    _addressCtrl.dispose();
    _landmarkCtrl.dispose();
    _pinCtrl.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _onGoogleSearchChanged(String raw) {
    _searchDebounce?.cancel();
    final query = raw.trim();
    if (query.length < 3) {
      if (_suggestions.isNotEmpty || _isSearchingAddress) {
        setState(() {
          _suggestions = [];
          _isSearchingAddress = false;
        });
      }
      return;
    }

    setState(() => _isSearchingAddress = true);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await LocationService.fetchAddressSuggestions(query);
      if (!mounted) return;
      if (_googleSearchCtrl.text.trim() != query) return;
      setState(() {
        _suggestions = results;
        _isSearchingAddress = false;
      });
    });
  }

  Future<void> _selectAddressSuggestion(LocationAddressResult suggestion) async {
    setState(() {
      _isSearchingAddress = true;
      _suggestions = [];
      _error = null;
    });

    final resolved = await LocationService.resolveSuggestionDetails(suggestion);
    if (!mounted) return;
    _applyLocationResult(
      resolved,
      statusMessage: resolved.pincode.isNotEmpty
          ? 'Google address & pincode (${resolved.pincode}) auto-filled'
          : 'Google address auto-filled — verify 6-digit PIN',
    );
  }

  Future<void> _autoFillCurrentLocation() async {
    setState(() {
      _isFetchingCurrentLocation = true;
      _suggestions = [];
      _error = null;
    });

    try {
      final locationResult = await LocationService.getCurrentLocationAddress();
      if (!mounted) return;
      _applyLocationResult(
        locationResult,
        statusMessage: locationResult.pincode.isNotEmpty
            ? 'Current location & pincode (${locationResult.pincode}) auto-filled'
            : 'Current location filled — verify 6-digit PIN',
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFetchingCurrentLocation = false;
          _error = 'Unable to detect current location. Search Google address above.';
        });
      }
    }
  }

  void _applyLocationResult(
    LocationAddressResult result, {
    required String statusMessage,
  }) {
    final rawFull = result.fullAddress.trim();
    final pin = result.pincode.trim().isNotEmpty
        ? result.pincode.trim()
        : LocationService.extractPinCode(rawFull);

    // Build clean street/area text without duplicating trailing PIN code
    var streetText = rawFull.isNotEmpty
        ? rawFull
        : [result.houseNo, result.mainText, result.city, result.state]
            .where((s) => s.trim().isNotEmpty)
            .join(', ');
    if (pin.isNotEmpty && streetText.endsWith(pin)) {
      streetText = streetText
          .substring(0, streetText.length - pin.length)
          .replaceAll(RegExp(r'[\s,\-]+$'), '');
    }

    setState(() {
      _isSearchingAddress = false;
      _isFetchingCurrentLocation = false;
      if (result.mainText.trim().isNotEmpty) {
        _googleSearchCtrl.text = result.mainText.trim();
      }
      if (streetText.isNotEmpty) {
        _addressCtrl.text = streetText;
      }
      if (result.landmark.trim().isNotEmpty) {
        _landmarkCtrl.text = result.landmark.trim();
      }
      if (pin.isNotEmpty) {
        _pinCtrl.text = pin;
        _lastLookedUpPin = pin;
      }
      _autoFillStatus = statusMessage;
      _error = null;
    });

    if (pin.isEmpty) {
      _pinFocusNode.requestFocus();
    }
  }

  void _onPinChanged(String raw) {
    final pin = raw.trim();
    if (_error != null) {
      setState(() => _error = null);
    }
    if (pin.length == 6 &&
        RegExp(r'^[1-9][0-9]{5}$').hasMatch(pin) &&
        pin != _lastLookedUpPin) {
      _lastLookedUpPin = pin;
      unawaited(_lookupPinDetails(pin));
    }
  }

  Future<void> _lookupPinDetails(String pin) async {
    setState(() => _isLookingUpPin = true);
    final info = await LocationService.lookupPincode(pin);
    if (!mounted || _pinCtrl.text.trim() != pin) return;
    setState(() {
      _isLookingUpPin = false;
      if (info != null) {
        if (_addressCtrl.text.trim().isEmpty && info.fullAddress.isNotEmpty) {
          _addressCtrl.text = info.fullAddress;
        }
        if (_landmarkCtrl.text.trim().isEmpty && info.landmark.isNotEmpty) {
          _landmarkCtrl.text = info.landmark;
        }
        final placeSummary = [info.mainText, info.city, info.state]
            .where((s) => s.trim().isNotEmpty)
            .toSet()
            .join(', ');
        _autoFillStatus = placeSummary.isNotEmpty
            ? 'Verified PIN $pin • $placeSummary'
            : 'Verified PIN $pin';
      }
    });
  }

  void _selectSavedAddress(CustomerAddressModel addr) {
    final extractedPin = addr.pinCode.trim().isNotEmpty
        ? addr.pinCode.trim()
        : LocationService.extractPinCode(addr.fullAddress);
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(extractedPin)) {
      setState(() {
        _label = addr.label.isNotEmpty ? addr.label : 'Home';
        _addressCtrl.text = addr.fullAddress.trim();
        _landmarkCtrl.text = addr.landmark.trim();
        _pinCtrl.clear();
        _error = 'Pin code is mandatory. Please enter 6-digit PIN code';
      });
      _pinFocusNode.requestFocus();
      return;
    }
    Navigator.pop(
      context,
      addr.pinCode.trim().isNotEmpty
          ? addr
          : addr.copyWith(pinCode: extractedPin),
    );
  }

  void _saveAddress() {
    final street = _addressCtrl.text.trim();
    if (street.length < 5) {
      setState(() => _error = 'Please enter complete house/flat & street address');
      return;
    }
    final landmark = _landmarkCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) {
      setState(() => _error = 'Pin code is mandatory. Please enter 6-digit PIN code');
      _pinFocusNode.requestFocus();
      return;
    }
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(pin)) {
      setState(() => _error = 'Please enter a valid 6-digit PIN code');
      _pinFocusNode.requestFocus();
      return;
    }
    final lowerStreet = street.toLowerCase();
    final parts = [
      street,
      if (landmark.isNotEmpty && !lowerStreet.contains(landmark.toLowerCase()))
        landmark,
      if (!street.contains(pin)) pin,
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

  Widget _buildGoogleAddressSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.travel_explore_rounded, size: 15, color: _brand),
            const SizedBox(width: 5),
            const Expanded(
              child: Text(
                'Google Address Search & Auto-fill',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('google-address-search-input'),
                controller: _googleSearchCtrl,
                cursorColor: _brand,
                onChanged: _onGoogleSearchChanged,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
                decoration: InputDecoration(
                  hintText: 'Search Google address, area, street...',
                  hintStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: _hint,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: _brand,
                  ),
                  suffixIcon: _isSearchingAddress
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _brand,
                            ),
                          ),
                        )
                      : (_googleSearchCtrl.text.isNotEmpty
                          ? IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchDebounce?.cancel();
                                _googleSearchCtrl.clear();
                                setState(() {
                                  _suggestions = [];
                                  _isSearchingAddress = false;
                                });
                              },
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: _hint,
                              ),
                            )
                          : null),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border, width: 1.15),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _brand, width: 1.6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              key: const ValueKey('delivery-autofill-location-btn'),
              onTap: _isFetchingCurrentLocation ? null : _autoFillCurrentLocation,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF3B82F6),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isFetchingCurrentLocation)
                      const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _brand,
                        ),
                      )
                    else
                      const Icon(
                        Icons.my_location_rounded,
                        size: 16,
                        color: _brand,
                      ),
                    const SizedBox(width: 5),
                    const Text(
                      'Auto-fill',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 190),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
              itemBuilder: (context, index) {
                final item = _suggestions[index];
                return InkWell(
                  onTap: () => _selectAddressSuggestion(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 17,
                            color: _brand,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.mainText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                              if (item.secondaryText.trim().isNotEmpty) ...[
                                const SizedBox(height: 1.5),
                                Text(
                                  item.secondaryText,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (item.pincode.trim().isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: Text(
                              item.pincode,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: _brand,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLabeledInput({
    required String caption,
    required TextEditingController controller,
    required String hintText,
    Key? fieldKey,
    FocusNode? focusNode,
    IconData? prefixIcon,
    int maxLines = 1,
    int minLines = 1,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.sentences,
    List<TextInputFormatter>? inputFormatters,
    bool showClearButton = false,
    bool isRequired = false,
    ValueChanged<String>? onChangedExtra,
    Widget? trailingSuffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isRequired)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  caption,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          )
        else
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
          focusNode: focusNode,
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
          onChanged: (value) {
            if (_error != null || showClearButton) {
              setState(() => _error = null);
            }
            onChangedExtra?.call(value);
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
            suffixIcon: trailingSuffix ??
                (showClearButton && controller.text.isNotEmpty
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
                    : null),
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
                            'Search Google address or auto-fill with GPS',
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
                _buildGoogleAddressSearchSection(),
                const SizedBox(height: 12),
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
                        onTap: () => _selectSavedAddress(addr),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Home', 'Work', 'Other'].map((tag) {
                    final selected = _label == tag;
                    return InkWell(
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
                        fieldKey: const ValueKey('delivery-landmark-input'),
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
                        fieldKey: const ValueKey('delivery-pincode-input'),
                        focusNode: _pinFocusNode,
                        caption: 'Pincode',
                        isRequired: true,
                        controller: _pinCtrl,
                        hintText: '6 digits *',
                        keyboardType: TextInputType.number,
                        textCapitalization: TextCapitalization.none,
                        onChangedExtra: _onPinChanged,
                        trailingSuffix: _isLookingUpPin
                            ? const Padding(
                                padding: EdgeInsets.all(11),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _brand,
                                  ),
                                ),
                              )
                            : null,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_autoFillStatus != null && _error == null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 15,
                          color: Color(0xFF15803D),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _autoFillStatus!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF14532D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Confirm Delivery Address',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
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
