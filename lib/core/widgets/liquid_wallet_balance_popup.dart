import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/sound_service.dart';
import '../../features/wallet/wallet_screen.dart';

/// Ultra-sleek Liquid Glass styled Available Balance Card popup.
/// Displays an animated horizontal translucent frosted glass capsule anchored directly below the top wallet button.
/// Includes smooth organic fluid spring opening and closing transitions anchored to the arrow tip.
class LiquidWalletBalancePopup extends StatefulWidget {
  final double balance;
  final VoidCallback onClose;
  final bool? isOpen;
  final double? topOffset;
  final double? rightOffset;

  const LiquidWalletBalancePopup({
    super.key,
    required this.balance,
    required this.onClose,
    this.isOpen,
    this.topOffset,
    this.rightOffset,
  });

  @override
  State<LiquidWalletBalancePopup> createState() => LiquidWalletBalancePopupState();
}

class LiquidWalletBalancePopupState extends State<LiquidWalletBalancePopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _barrierFadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
    );

    // Natural fluid deceleration from behind the button (iOS popover standard)
    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Cubic(0.16, 1.0, 0.3, 1.0), // Fluid Apple-style deceleration curve
        reverseCurve: Curves.easeInCubic,
      ),
    );

    // Gentle downward glide directly under the wallet button
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -6),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    // Smooth opacity fade
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
        reverseCurve: Curves.easeIn,
      ),
    );

    // Barrier fade for smooth touch shield
    _barrierFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        if (mounted) setState(() {});
      }
    });

    if (widget.isOpen != false) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant LiquidWalletBalancePopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen != null && widget.isOpen != oldWidget.isOpen) {
      if (widget.isOpen!) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  Future<void> _handleClose() async {
    try {
      await _controller.reverse();
    } catch (_) {}
    widget.onClose();
  }

  Future<void> _navigateToWalletScreen() async {
    SoundService.playButtonClick();
    try {
      await _controller.reverse();
    } catch (_) {}
    widget.onClose();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const WalletScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isClosed = (widget.isOpen != null)
        ? (!widget.isOpen! && _controller.isDismissed)
        : false;

    if (isClosed) {
      return const SizedBox.shrink();
    }

    final formattedBalance = widget.balance.toStringAsFixed(2);
    final top = widget.topOffset ?? 46.0;
    final right = widget.rightOffset ?? 12.0;

    return Stack(
      children: [
        // 1. Full-screen transparent dismiss barrier with fade transition
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _barrierFadeAnimation,
            builder: (context, child) {
              if (_controller.value == 0) return const SizedBox.shrink();
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleClose,
                child: Container(
                  color: Colors.transparent,
                ),
              );
            },
          ),
        ),

        // 2. Liquid Glass Horizontal Capsule with Spring Opening/Closing Transitions
        Positioned(
          top: top,
          right: right,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: _slideAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  alignment: const Alignment(0.08, -1.0), // Anchored directly to arrow tip & wallet button
                  child: Opacity(
                    opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _navigateToWalletScreen,
                borderRadius: BorderRadius.circular(20),
                splashColor: const Color(0x10007AFF),
                highlightColor: const Color(0x08007AFF),
                child: CustomPaint(
                  painter: _LiquidArrowPainter(),
                  child: Container(
                    width: 138,
                    padding: const EdgeInsets.only(top: 7), // Space for top pointing arrow
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(19),
                            // Liquid frosted iridescent glass body
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xF8FFFFFF), // crisp frosted white
                                Color(0xF2F8FAFC), // subtle glass translucency
                                Color(0xF0FFFFFF), // clear crystal glass
                              ],
                              stops: [0.0, 0.5, 1.0],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.92),
                              width: 1.3,
                            ),
                            boxShadow: [
                              // Crisp ambient depth shadow
                              BoxShadow(
                                color: const Color(0x1A0F172A).withValues(alpha: 0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Top-Left Glossy Specular Highlight (Liquid reflection)
                              Positioned(
                                top: -10,
                                left: -10,
                                child: Container(
                                  width: 55,
                                  height: 35,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.92),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Fine top-edge gloss shine line
                              Positioned(
                                top: 0,
                                left: 14,
                                right: 14,
                                height: 1.2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.2),
                                        Colors.white.withValues(alpha: 0.95),
                                        Colors.white.withValues(alpha: 0.2),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Inner Capsule Row Content
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 1. Soft Mint Rounded Square with Cartoon Wallet Icon
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFFD1FAE5), // Soft pastel mint
                                            Color(0xFFA7F3D0), // Fresh mint
                                          ],
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFF6EE7B7).withValues(alpha: 0.65),
                                          width: 1.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0x2210B981).withValues(alpha: 0.20),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1.5),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Image.asset(
                                        'assets/images/wallet_icon.png',
                                        width: 25,
                                        height: 25,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 2. Text Column: 'Available Balance' + Amount
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            'Available Balance',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '₹$formattedBalance',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF0F172A),
                                              fontSize: 17.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.6,
                                              height: 1.15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for the top liquid arrow caret pointing up directly at the wallet button
class _LiquidArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Arrow is placed directly under the wallet button
    final arrowCenterX = size.width - 64.0;
    const arrowWidth = 13.0;
    const arrowHeight = 7.0;

    final path = Path();
    path.moveTo(arrowCenterX - (arrowWidth / 2), arrowHeight);
    path.lineTo(arrowCenterX, 0);
    path.lineTo(arrowCenterX + (arrowWidth / 2), arrowHeight);
    path.close();

    final paint = Paint()
      ..color = const Color(0xF5FFFFFF)
      ..style = PaintingStyle.fill;

    // Arrow drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawPath(path.shift(const Offset(0, -1)), shadowPaint);

    canvas.drawPath(path, paint);

    // White rim border highlight
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;

    canvas.drawLine(
      Offset(arrowCenterX - (arrowWidth / 2), arrowHeight),
      Offset(arrowCenterX, 0),
      borderPaint,
    );
    canvas.drawLine(
      Offset(arrowCenterX, 0),
      Offset(arrowCenterX + (arrowWidth / 2), arrowHeight),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
