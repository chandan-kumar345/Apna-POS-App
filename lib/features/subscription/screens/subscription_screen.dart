import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../inventory/inventory_screen.dart';
import '../../loyalty/screens/loyalty_landing_screen.dart';
import '../../campaign/screens/campaign_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  final String sourceFeature;
  final String? preSelectedPlan;
  final bool isEmbedded;
  final VoidCallback? onBack;
  final void Function(String feature)? onNavigateToFeature;

  const SubscriptionScreen({
    super.key,
    this.sourceFeature = 'subscription_screen',
    this.preSelectedPlan,
    this.isEmbedded = false,
    this.onBack,
    this.onNavigateToFeature,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final DatabaseService _db = DatabaseService();

  int _selectedTierIndex = 0; // 0: Yearly (Recommended), 1: Monthly
  bool _isLoading = false;
  SubscriptionDataModel _data = const SubscriptionDataModel();

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _data = _subscriptionService.getDefaultPlans();
    _loadPlans();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    final data = await _subscriptionService.fetchPlans();
    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
    }
  }

  String get _featureSubtitleHighlight {
    final s = widget.sourceFeature.toLowerCase();
    if (s.contains('loyalty')) return 'Loyalty Plus';
    if (s.contains('campaign')) return 'Campaign Pro';
    if (s.contains('inventory')) return 'Inventory Suite';
    return 'Pro Suite';
  }

  String get _heroDescription {
    final s = widget.sourceFeature.toLowerCase();
    if (s.contains('loyalty')) {
      return 'Build stronger customer relationships with smart loyalty tools.';
    }
    if (s.contains('campaign')) {
      return 'Drive revenue and repeat visits with automated WhatsApp marketing.';
    }
    if (s.contains('inventory')) {
      return 'Real-time stock control, recipe costing and smart supplier tracking.';
    }
    return 'All-in-one POS, loyalty, marketing campaigns & smart inventory.';
  }

  List<Map<String, dynamic>> get _featuresList {
    final s = widget.sourceFeature.toLowerCase();
    if (s.contains('loyalty')) {
      return [
        {
          'title': 'Automated Rewards',
          'subtitle': 'Cashback, Points & Visit Rewards',
          'icon': Icons.card_giftcard_rounded,
          'bgColor': const Color(0xFFDCFCE7),
          'iconColor': const Color(0xFF16A34A),
        },
        {
          'title': 'Customer Tier Badges',
          'subtitle': 'Engage with tier-based offers',
          'icon': Icons.verified_user_rounded,
          'bgColor': const Color(0xFFDBEAFE),
          'iconColor': const Color(0xFF2563EB),
        },
        {
          'title': 'Instant OTP Redemption',
          'subtitle': 'Redeem loyalty at POS',
          'icon': Icons.bolt_rounded,
          'bgColor': const Color(0xFFFEF3C7),
          'iconColor': const Color(0xFFD97706),
        },
        {
          'title': 'Customer Insights',
          'subtitle': 'Detailed retention & visit analytics',
          'icon': Icons.bar_chart_rounded,
          'bgColor': const Color(0xFFF3E8FF),
          'iconColor': const Color(0xFF9333EA),
        },
      ];
    }
    if (s.contains('campaign')) {
      return [
        {
          'title': 'Automated Broadcasts',
          'subtitle': 'Targeted WhatsApp & SMS campaigns',
          'icon': Icons.send_rounded,
          'bgColor': const Color(0xFFDCFCE7),
          'iconColor': const Color(0xFF16A34A),
        },
        {
          'title': 'Inactive Recovery',
          'subtitle': 'Re-engage lost diners automatically',
          'icon': Icons.replay_rounded,
          'bgColor': const Color(0xFFDBEAFE),
          'iconColor': const Color(0xFF2563EB),
        },
        {
          'title': 'Festival & Promo Coupons',
          'subtitle': 'Create custom promotional discounts',
          'icon': Icons.local_offer_rounded,
          'bgColor': const Color(0xFFFEF3C7),
          'iconColor': const Color(0xFFD97706),
        },
        {
          'title': 'Real-time ROI Analytics',
          'subtitle': 'Track conversions & campaign revenue',
          'icon': Icons.insights_rounded,
          'bgColor': const Color(0xFFF3E8FF),
          'iconColor': const Color(0xFF9333EA),
        },
      ];
    }
    if (s.contains('inventory')) {
      return [
        {
          'title': 'Live Stock Tracking',
          'subtitle': 'Ingredient-level consumption on POS & KOT',
          'icon': Icons.inventory_2_rounded,
          'bgColor': const Color(0xFFDCFCE7),
          'iconColor': const Color(0xFF16A34A),
        },
        {
          'title': 'Recipe Management',
          'subtitle': 'Automatic item deduct with sub-recipes',
          'icon': Icons.restaurant_menu_rounded,
          'bgColor': const Color(0xFFDBEAFE),
          'iconColor': const Color(0xFF2563EB),
        },
        {
          'title': 'Low Stock Alerts',
          'subtitle': 'Instant notification when ingredients run low',
          'icon': Icons.warning_amber_rounded,
          'bgColor': const Color(0xFFFEF3C7),
          'iconColor': const Color(0xFFD97706),
        },
        {
          'title': 'Purchase & Vendor Ledger',
          'subtitle': 'Manage supplier bills, POs & Khata',
          'icon': Icons.receipt_long_rounded,
          'bgColor': const Color(0xFFF3E8FF),
          'iconColor': const Color(0xFF9333EA),
        },
      ];
    }

    return [
      {
        'title': 'Automated Rewards',
        'subtitle': 'Cashback, Points & Visit Rewards',
        'icon': Icons.card_giftcard_rounded,
        'bgColor': const Color(0xFFDCFCE7),
        'iconColor': const Color(0xFF16A34A),
      },
      {
        'title': 'Customer Tier Badges',
        'subtitle': 'Engage with tier-based offers',
        'icon': Icons.verified_user_rounded,
        'bgColor': const Color(0xFFDBEAFE),
        'iconColor': const Color(0xFF2563EB),
      },
      {
        'title': 'Instant OTP Redemption',
        'subtitle': 'Redeem loyalty at POS',
        'icon': Icons.bolt_rounded,
        'bgColor': const Color(0xFFFEF3C7),
        'iconColor': const Color(0xFFD97706),
      },
      {
        'title': 'Customer Insights',
        'subtitle': 'Detailed retention & visit analytics',
        'icon': Icons.bar_chart_rounded,
        'bgColor': const Color(0xFFF3E8FF),
        'iconColor': const Color(0xFF9333EA),
      },
    ];
  }

  double get _yearlyPrice =>
      _data.plans.isNotEmpty && _data.plans.first.priceAnnual > 0
          ? _data.plans.first.priceAnnual
          : 7999.0;

  double get _monthlyPrice =>
      _data.plans.isNotEmpty && _data.plans.first.priceMonthly > 0
          ? _data.plans.first.priceMonthly
          : 999.0;

  void _handlePrimaryCta() {
    final selectedPlanName =
        _selectedTierIndex == 0 ? 'Yearly Plan (₹${_yearlyPrice.toStringAsFixed(0)})' : 'Monthly Plan (₹${_monthlyPrice.toStringAsFixed(0)})';
    final selectedPrice = _selectedTierIndex == 0 ? _yearlyPrice : _monthlyPrice;

    _openLeadBottomSheet(
      planName: selectedPlanName,
      price: selectedPrice,
      featureSource: widget.sourceFeature,
    );
  }

  void _openLeadBottomSheet({
    required String planName,
    required double price,
    String? featureSource,
  }) {
    final user = _db.currentUser;
    final rest = _db.restaurant;

    final initialRestName = rest?.name.isNotEmpty == true
        ? rest!.name
        : ((user?.companyName != null && user!.companyName!.isNotEmpty)
            ? user.companyName!
            : 'Apna Restaurant');
    final initialContact =
        (user?.name.isNotEmpty == true) ? user!.name : initialRestName;
    final initialPhone = user?.phone ?? '';
    final initialEmail = user?.email ?? '';

    final restCtrl = TextEditingController(text: initialRestName);
    final contactCtrl = TextEditingController(text: initialContact);
    final phoneCtrl = TextEditingController(text: initialPhone);
    final emailCtrl = TextEditingController(text: initialEmail);
    final notesCtrl = TextEditingController();

    bool isSubmitting = false;
    String? phoneError;
    final bool isDemo =
        featureSource == 'demo_request' || planName.toLowerCase().contains('demo');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final screenWidth = MediaQuery.of(ctx).size.width;
            return Center(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Container(
                  constraints:
                      BoxConstraints(maxWidth: math.min(screenWidth, 460.0)),
                  padding: const EdgeInsets.only(
                    left: 18,
                    right: 18,
                    top: 14,
                    bottom: 18,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 28,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 34,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDemo
                                      ? const Color(0xFF93C5FD)
                                      : const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: Icon(
                                isDemo
                                    ? Icons.play_circle_fill_rounded
                                    : Icons.workspace_premium_rounded,
                                color: const Color(0xFF2563EB),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isDemo
                                        ? 'Request a Product Demo'
                                        : 'Request Pro Access',
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    isDemo
                                        ? '1-on-1 Guided Walkthrough'
                                        : 'Plan: $planName',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Value Banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_rounded,
                                  color: Color(0xFF16A34A), size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  isDemo
                                      ? 'Lead dispatched to sooftcode@gmail.com for priority scheduling.'
                                      : 'Notification sent to sooftcode@gmail.com for immediate activation.',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFF15803D),
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Business Name
                        _buildLightTextField(
                          controller: restCtrl,
                          label: 'Business / Restaurant Name',
                          icon: Icons.storefront_rounded,
                          hint: 'e.g. Apna Restaurant & Cafe',
                        ),
                        const SizedBox(height: 8),

                        // Contact Person
                        _buildLightTextField(
                          controller: contactCtrl,
                          label: 'Your Name (Contact Person)',
                          icon: Icons.person_rounded,
                          hint: 'e.g. Chandan Kumar',
                        ),
                        const SizedBox(height: 8),

                        // Phone Number
                        _buildLightTextField(
                          controller: phoneCtrl,
                          label: 'Mobile / WhatsApp Number *',
                          icon: Icons.phone_android_rounded,
                          hint: 'e.g. 9876543210',
                          keyboardType: TextInputType.phone,
                          errorText: phoneError,
                        ),
                        const SizedBox(height: 8),

                        // Email
                        _buildLightTextField(
                          controller: emailCtrl,
                          label: 'Email ID (Optional)',
                          icon: Icons.email_rounded,
                          hint: 'e.g. contact@myrestaurant.com',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 8),

                        // Notes
                        _buildLightTextField(
                          controller: notesCtrl,
                          label: isDemo
                              ? 'Preferred Time / Questions'
                              : 'Specific Requirements / Notes',
                          icon: Icons.notes_rounded,
                          hint: isDemo
                              ? 'e.g. Best time to call'
                              : 'e.g. Need WhatsApp campaign setup',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),

                        // Submit CTA Button
                        Container(
                          width: double.infinity,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: const Color(0xFF2563EB),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x302563EB),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isSubmitting
                                  ? null
                                  : () async {
                                      if (phoneCtrl.text.trim().isEmpty) {
                                        setModalState(() {
                                          phoneError =
                                              'Please enter a valid mobile number';
                                        });
                                        return;
                                      }

                                      setModalState(() {
                                        phoneError = null;
                                        isSubmitting = true;
                                      });

                                      final effectiveSource =
                                          featureSource ?? widget.sourceFeature;
                                      final billingCycle = isDemo
                                          ? 'demo'
                                          : (_selectedTierIndex == 0
                                              ? 'annual'
                                              : 'monthly');

                                      await _subscriptionService.submitInterestLead(
                                        restaurantName: restCtrl.text.trim(),
                                        contactPerson: contactCtrl.text.trim(),
                                        phone: phoneCtrl.text.trim(),
                                        email: emailCtrl.text.trim(),
                                        selectedPlan: planName,
                                        billingCycle: billingCycle,
                                        sourceFeature: effectiveSource,
                                        notes: notesCtrl.text.trim(),
                                        price: price,
                                      );

                                      if (modalCtx.mounted) {
                                        Navigator.pop(modalCtx);
                                        _showSuccessDialog(
                                          planName: planName,
                                          phone: phoneCtrl.text.trim(),
                                          contactName: contactCtrl.text.trim(),
                                          sourceFeature: effectiveSource,
                                          isDemo: isDemo,
                                        );
                                      }
                                    },
                              borderRadius: BorderRadius.circular(10),
                              child: Center(
                                child: isSubmitting
                                    ? const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Submitting...',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            isDemo
                                                ? Icons.calendar_month_rounded
                                                : Icons.check_circle_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isDemo
                                                ? 'Submit Demo Request'
                                                : 'Submit Access Request',
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      restCtrl.dispose();
      contactCtrl.dispose();
      phoneCtrl.dispose();
      emailCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  void _showSuccessDialog({
    required String planName,
    required String phone,
    required String contactName,
    required String sourceFeature,
    bool isDemo = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: math.min(screenWidth * 0.90, 360.0),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 28,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF16A34A),
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isDemo
                          ? 'Demo Request Submitted'
                          : 'Pro Access Requested',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isDemo
                          ? (contactName.isNotEmpty
                              ? 'Thank you $contactName! Your request for a live product demo has been sent to sooftcode@gmail.com.'
                              : 'Your request for a live product demo has been sent to sooftcode@gmail.com.')
                          : (contactName.isNotEmpty
                              ? 'Thank you $contactName! Your request for $planName has been sent to sooftcode@gmail.com.'
                              : 'Your request for $planName has been sent to sooftcode@gmail.com.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_in_talk_rounded,
                              color: Color(0xFF2563EB), size: 13),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              phone.isNotEmpty
                                  ? 'Our team will contact you at $phone shortly.'
                                  : 'Our team will contact you shortly.',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Done / Close Action
                    Container(
                      width: double.infinity,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFF0F172A),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(ctx),
                          borderRadius: BorderRadius.circular(8),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline_rounded,
                                    size: 15, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Got It',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getProceedButtonLabel(String source) {
    if (source.contains('inventory')) return 'Open Inventory';
    if (source.contains('loyalty')) return 'Open Loyalty Hub';
    if (source.contains('campaign')) return 'Open Marketing Campaigns';
    return 'Continue to POS';
  }

  void _navigateToTargetScreen(String source) {
    if (!_db.isSubscribed) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }

    if (widget.onNavigateToFeature != null) {
      widget.onNavigateToFeature!(source);
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }

    if (source.contains('inventory')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const InventoryScreen()),
      );
    } else if (source.contains('loyalty')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoyaltyLandingScreen()),
      );
    } else if (source.contains('campaign')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CampaignScreen()),
      );
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  static Widget _buildLightTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 3),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          scrollPadding: const EdgeInsets.only(bottom: 90),
          style: const TextStyle(
              fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            prefixIcon: Icon(icon, size: 15, color: const Color(0xFF2563EB)),
            errorText: errorText,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Top Circular Back Button Row
                  _buildCircledBackButton(),
                  const SizedBox(height: 8),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        color: Color(0xFF2563EB),
                      ),
                    ),

                  // 2. Main Content Area filling remaining space
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Hero Header Section with 3D Illustration
                          _buildHeroSection(),
                          const SizedBox(height: 12),

                          // Features White Card Box
                          _buildFeaturesCard(),
                          const SizedBox(height: 12),

                          // 2-Tier Pricing Cards (Yearly 20% OFF & Monthly)
                          _buildPricingTiers(),
                          const SizedBox(height: 12),

                          // Action Buttons
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Primary Blue CTA: "Upgrade to Pro Suite →"
                              _buildPrimaryCtaButton(),
                              const SizedBox(height: 8),

                              // Secondary Outlined CTA: "▶ I am Interested for Demo"
                              _buildSecondaryActionButton(),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Footer Links & Promo Code
                          _buildFooterLinks(),
                        ],
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

  /// Top Circular Back Button (Matching reference screenshot)
  Widget _buildCircledBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A),
              size: 15,
            ),
          ),
        ),
      ),
    );
  }

  /// 1. Hero Header Section with 3D Graphics
  Widget _buildHeroSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left text: Apna POS + [Feature Title] in Blue + Subtitle
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apna POS',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              Text(
                _featureSubtitleHighlight,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2563EB),
                  letterSpacing: -0.5,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _heroDescription,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Right 3D Visual Cards Showcase
        Expanded(
          flex: 5,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseAnimation.value * 0.02),
                child: SizedBox(
                  height: 98,
                  child: Image.asset(
                    'assets/images/subscription_hero_crown.png',
                    height: 98,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildFallbackHeroIllustration();
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackHeroIllustration() {
    return SizedBox(
      height: 90,
      child: Stack(
        alignment: Alignment.centerRight,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 2,
            top: 10,
            child: Container(
              width: 50,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFBAE6FD),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Icon(Icons.star_rounded, color: Color(0xFFFDE047), size: 24),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 10,
            child: Container(
              width: 50,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFDDD6FE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
          Positioned(
            left: 22,
            top: 2,
            child: Container(
              width: 72,
              height: 76,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text('👑', style: TextStyle(fontSize: 36)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Features White Card Box
  Widget _buildFeaturesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: _featuresList.map((feature) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.5),
            child: Row(
              children: [
                // Colorful Icon Container
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: feature['bgColor'] as Color,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Icon(
                      feature['icon'] as IconData,
                      color: feature['iconColor'] as Color,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature['title'] as String,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        feature['subtitle'] as String,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 3. Pricing Tier Cards (Yearly Plan & Monthly Plan)
  Widget _buildPricingTiers() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Yearly Plan
        Expanded(
          child: _buildTierCard(
            index: 0,
            title: 'Yearly Plan',
            price: '₹${_yearlyPrice.toStringAsFixed(0)}',
            subtitle: 'Billed Annually',
            badgeText: '20% OFF',
            isYearly: true,
            bullets: [
              'Full access to all features',
              'Best value',
              'Priority support',
            ],
          ),
        ),
        const SizedBox(width: 10),

        // 2. Monthly Plan
        Expanded(
          child: _buildTierCard(
            index: 1,
            title: 'Monthly Plan',
            price: '₹${_monthlyPrice.toStringAsFixed(0)}',
            subtitle: 'Billed Monthly',
            isYearly: false,
            bullets: [
              'All core features',
              'Flexible subscription',
              'Cancel anytime',
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTierCard({
    required int index,
    required String title,
    required String price,
    required String subtitle,
    String? badgeText,
    required bool isYearly,
    required List<String> bullets,
  }) {
    final isSelected = _selectedTierIndex == index;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => setState(() => _selectedTierIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                width: isSelected ? 2.0 : 1.0,
              ),
              boxShadow: isSelected
                  ? const [
                      BoxShadow(
                        color: Color(0x142563EB),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x04000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Radio icon + Title row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFCBD5E1),
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Price
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    price,
                    style: TextStyle(
                      color: isYearly ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),

                // Subtitle
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),

                // Bullet checklist
                ...bullets.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFE2E8F0),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: isSelected ? Colors.white : const Color(0xFF64748B),
                            size: 9,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            b,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFF334155)
                                  : const Color(0xFF64748B),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              height: 1.15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Top-left Pill Badge (20% OFF)
        if (badgeText != null)
          Positioned(
            top: -7,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                badgeText,
                style: const TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 4. Primary Blue CTA: "Upgrade to Pro Suite →"
  Widget _buildPrimaryCtaButton() {
    return Container(
      width: double.infinity,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        color: const Color(0xFF2563EB),
        boxShadow: const [
          BoxShadow(
            color: Color(0x302563EB),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handlePrimaryCta,
          borderRadius: BorderRadius.circular(23),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Upgrade to Pro Suite',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.1,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 5. Secondary Action Pill: "▶ I am Interested for Demo"
  Widget _buildSecondaryActionButton() {
    return Container(
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDBEAFE), width: 1.3),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openLeadBottomSheet(
            planName: 'Live Product Demo Request',
            price: 0,
            featureSource: 'demo_request',
          ),
          borderRadius: BorderRadius.circular(22),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_circle_outline_rounded,
                  color: Color(0xFF2563EB),
                  size: 17,
                ),
                SizedBox(width: 7),
                Text(
                  'I am Interested for Demo',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 6. Footer Links
  Widget _buildFooterLinks() {
    return Column(
      children: [
        // Divider with "Have a Promo Code?"
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFFE2E8F0), height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: GestureDetector(
                onTap: () => _openLeadBottomSheet(
                  planName: 'Promo Code Inquiry',
                  price: 0,
                  featureSource: 'promo_code',
                ),
                child: const Text(
                  'Have a Promo Code?',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const Expanded(child: Divider(color: Color(0xFFE2E8F0), height: 1)),
          ],
        ),
        const SizedBox(height: 8),

        // Restore Purchases, Terms, Privacy Policy
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Checking store purchases... No prior purchase found.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text(
                'Restore Purchases',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
              ),
            ),
            const Text('•',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5)),
            GestureDetector(
              onTap: () {},
              child: const Text(
                'Terms of Services',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Text('•',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5)),
            GestureDetector(
              onTap: () {},
              child: const Text(
                'Privacy Policy',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
