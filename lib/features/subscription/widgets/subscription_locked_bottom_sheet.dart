import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/subscription_service.dart';

class SubscriptionLockedBottomSheet extends StatefulWidget {
  final VoidCallback? onUnlocked;

  const SubscriptionLockedBottomSheet({
    super.key,
    this.onUnlocked,
  });

  /// Static helper to display the subscription locked bottom sheet or barrier
  static Future<void> show(BuildContext context, {VoidCallback? onUnlocked}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PopScope(
        canPop: false,
        child: SubscriptionLockedBottomSheet(onUnlocked: onUnlocked),
      ),
    );
  }

  @override
  State<SubscriptionLockedBottomSheet> createState() => _SubscriptionLockedBottomSheetState();
}

class _SubscriptionLockedBottomSheetState extends State<SubscriptionLockedBottomSheet>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final db = DatabaseService();
  final subscriptionService = SubscriptionService();

  bool _isProcessingPayment = false;
  bool _isVerifying = false;
  String? _statusMessage;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _glowController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isProcessingPayment) {
      // User returned from UPI app - automatically check / activate subscription
      _verifyAndUnlock(silent: true);
    }
  }

  Future<void> _handleUnlockClick() async {
    setState(() {
      _isProcessingPayment = true;
      _statusMessage = 'Opening UPI payment app for ₹300...';
    });

    final launched = await subscriptionService.launchUpiPayment(
      upiId: '9709593705@ybl',
      amount: 300.0,
      payeeName: 'Apna POS',
      transactionNote: 'Apna POS Subscription Unlock',
    );

    if (!launched) {
      // On Windows / Web or device with no direct UPI handler -> show manual payment option
      if (mounted) {
        setState(() {
          _statusMessage = 'Pay ₹300 to UPI ID: 9709593705@ybl and click Verify';
        });
        _showManualUpiDialog();
      }
    }
  }

  Future<void> _verifyAndUnlock({bool silent = false}) async {
    setState(() {
      _isVerifying = true;
      _statusMessage = 'Verifying subscription payment...';
    });

    try {
      final success = await subscriptionService.activateSubscription(
        amount: 300.0,
        paymentRef: 'UPI_9709593705_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (success) {
        await db.updateSubscriptionStatus(true);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '🎉 Subscription Unlocked Successfully! Welcome to Apna POS.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );

        widget.onUnlocked?.call();
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        return;
      }
    } catch (e) {
      debugPrint('Verify error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  void _showManualUpiDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_2_rounded, color: Color(0xFF2563EB), size: 26),
            SizedBox(width: 10),
            Text('Pay ₹300 via UPI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please make the ₹300 payment to the following UPI ID from any UPI App (GPay, PhonePe, Paytm, BHIM):',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: SelectableText(
                      '9709593705@ybl',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(const ClipboardData(text: '9709593705@ybl'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('UPI ID 9709593705@ybl copied to clipboard!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.copy_rounded, size: 14, color: Color(0xFF2563EB)),
                          SizedBox(width: 4),
                          Text('Copy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Amount: ₹300 (1 Month POS Access)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _verifyAndUnlock();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('I Have Paid - Unlock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 40,
                offset: Offset(0, -10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Drag Pill Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Glowing 3D Golden Lock Illustration with 4 Sparkle Stars
                  _buildGlowing3DLockIllustration(),

                  const SizedBox(height: 16),

                  // Title: "Subscription Locked"
                  const Text(
                    'Subscription Locked',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),

                  // Subtitle
                  const Text(
                    'Your subscription is expired or inactive.\nRenew your plan to continue using Apna POS.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),

                  // 5 Feature Category Cards Row (POS Billing, Table Management, Reports & Analytics, Inventory, Customer & Loyalty)
                  _buildFeatureIconsRow(),

                  const SizedBox(height: 24),

                  if (_statusMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isVerifying) ...[
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              _statusMessage!,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Primary Blue Action Button: "👑 Unlock Your Subscription >"
                  Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E6EFA), Color(0xFF2563EB)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(27),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x592563EB),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: (_isProcessingPayment && !_isVerifying) ? () => _verifyAndUnlock() : _handleUnlockClick,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                      ),
                      child: _isVerifying
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Activating...',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('👑', style: TextStyle(fontSize: 17)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      'Unlock Your Subscription',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, size: 22, color: Colors.white),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Secondary Action Link: "Contact Support"
                  TextButton(
                    onPressed: () => subscriptionService.contactSupport(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    ),
                    child: const Text(
                      'Contact Support',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Glowing 3D Lock Illustration with Golden Aura & 4 Sparkle Stars
  Widget _buildGlowing3DLockIllustration() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, child) {
        final glowScale = 1.0 + (_glowController.value * 0.08);
        final shimmer = _glowController.value;

        return SizedBox(
          width: 140,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Ambient Radial Warm Golden Glow
              Transform.scale(
                scale: glowScale,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFDE68A).withValues(alpha: 0.65),
                        const Color(0xFFFEF3C7).withValues(alpha: 0.35),
                        const Color(0xFFFEF3C7).withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),

              // Inner Frosted Disc
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.9),
                      const Color(0xFFFEF3C7).withValues(alpha: 0.55),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),

              // 4 Sparkle Diamond Stars (matching reference image)
              // 1. Top-Left Golden Sparkle
              Positioned(
                top: 14,
                left: 18,
                child: _buildSparkleStar(color: const Color(0xFFF59E0B), size: 10 + (shimmer * 3)),
              ),
              // 2. Top-Right Golden Sparkle
              Positioned(
                top: 16,
                right: 18,
                child: _buildSparkleStar(color: const Color(0xFFF59E0B), size: 13 - (shimmer * 2)),
              ),
              // 3. Mid-Left Golden Sparkle
              Positioned(
                bottom: 26,
                left: 18,
                child: _buildSparkleStar(color: const Color(0xFFFBBF24), size: 11 + (shimmer * 2)),
              ),
              // 4. Mid-Right Cyan/Blue Sparkle
              Positioned(
                bottom: 24,
                right: 18,
                child: _buildSparkleStar(color: const Color(0xFF60A5FA), size: 11 - (shimmer * 2)),
              ),

              // 3D Padlock
              _build3DPadlock(),
            ],
          ),
        );
      },
    ),
    );
  }

  /// 3D Vector Padlock matching reference design
  Widget _build3DPadlock() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Metallic Golden Shackle (Curved U-arch)
        Container(
          width: 30,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            border: Border.all(
              color: const Color(0xFFD97706),
              width: 5.5,
            ),
          ),
        ),
        // Padlock Body with Keyhole
        Transform.translate(
          offset: const Offset(0, -3),
          child: Container(
            width: 44,
            height: 35,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFDE047),
                  Color(0xFFF59E0B),
                  Color(0xFFD97706),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40B45309),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6.5,
                    height: 6.5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF78350F),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 3.2,
                    height: 5.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF78350F),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Vector 4-point Sparkle Diamond Painter
  Widget _buildSparkleStar({required Color color, required double size}) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SparkleStarPainter(color: color),
    );
  }

  /// 5 Feature Category Cards Row (POS Billing, Table Management, Reports & Analytics, Inventory, Customer & Loyalty)
  Widget _buildFeatureIconsRow() {
    final features = [
      _FeatureItem(
        icon: Icons.calculate_rounded,
        label: 'POS Billing',
        iconColor: const Color(0xFF0284C7),
        bgColor: const Color(0xFFE0F2FE),
      ),
      _FeatureItem(
        icon: Icons.groups_rounded,
        label: 'Table\nManagement',
        iconColor: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFEDE9FE),
      ),
      _FeatureItem(
        icon: Icons.bar_chart_rounded,
        label: 'Reports &\nAnalytics',
        iconColor: const Color(0xFF10B981),
        bgColor: const Color(0xFFDCFCE7),
      ),
      _FeatureItem(
        icon: Icons.all_inbox_rounded,
        label: 'Inventory',
        iconColor: const Color(0xFFF59E0B),
        bgColor: const Color(0xFFFEF3C7),
      ),
      _FeatureItem(
        icon: Icons.diversity_1_rounded,
        label: 'Customer\n& Loyalty',
        iconColor: const Color(0xFFEC4899),
        bgColor: const Color(0xFFFCE7F3),
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features.map((f) {
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: f.bgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(f.icon, color: f.iconColor, size: 24),
              ),
              const SizedBox(height: 7),
              Text(
                f.label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                  height: 1.18,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;

  const _FeatureItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
  });
}

class _SparkleStarPainter extends CustomPainter {
  final Color color;
  const _SparkleStarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    path.moveTo(cx, 0);
    path.quadraticBezierTo(cx, cy, w, cy);
    path.quadraticBezierTo(cx, cy, cx, h);
    path.quadraticBezierTo(cx, cy, 0, cy);
    path.quadraticBezierTo(cx, cy, cx, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkleStarPainter oldDelegate) => oldDelegate.color != color;
}

/// A full-screen wrapper widget that renders blurred background behind the subscription lock
class SubscriptionLockedBarrier extends StatelessWidget {
  final Widget child;
  final bool isLocked;
  final VoidCallback? onUnlocked;

  const SubscriptionLockedBarrier({
    super.key,
    required this.child,
    required this.isLocked,
    this.onUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActuallyLocked = isLocked && !DatabaseService().isSubscribed;
    if (!isActuallyLocked) return child;

    return Stack(
      children: [
        // Background child (e.g. POS Screen) isolated from touch and repainting
        IgnorePointer(
          ignoring: isLocked,
          child: RepaintBoundary(child: child),
        ),

        // Premium Frosted Glass Blur Barrier (Hardware-isolated repaint boundary)
        Positioned.fill(
          child: RepaintBoundary(
            child: Container(
              color: const Color(0x880F172A),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
        ),

        // Centered / Bottom Sheet Card
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: RepaintBoundary(
            child: SubscriptionLockedBottomSheet(
              onUnlocked: onUnlocked,
            ),
          ),
        ),
      ],
    );
  }
}
