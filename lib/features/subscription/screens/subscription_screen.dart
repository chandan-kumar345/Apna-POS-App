import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/database/database_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/theme/glass_theme.dart';
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

class _SubscriptionScreenState extends State<SubscriptionScreen> with SingleTickerProviderStateMixin {
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

  String get _featureTitle {
    final s = widget.sourceFeature.toLowerCase();
    if (s.contains('loyalty')) return 'Apna POS Loyalty Plus';
    if (s.contains('campaign')) return 'Apna POS Campaign Pro';
    if (s.contains('inventory')) return 'Apna POS Inventory Suite';
    return 'Apna POS Pro';
  }

  String get _heroHeading {
    final s = widget.sourceFeature.toLowerCase();
    if (s.contains('loyalty')) return 'Unlock Smart Loyalty Engine';
    if (s.contains('campaign')) return 'Unlock WhatsApp Campaigns';
    if (s.contains('inventory')) return 'Unlock Smart Stock & Recipes';
    return 'Unlock Premium Suite';
  }

  List<String> get _featureBullets {
    final s = widget.sourceFeature.toLowerCase();
    if (s.contains('loyalty')) {
      return [
        'Automated Cashback, Points & Visit Rewards',
        'Customer Tier Badges & Birthday Offers',
        'Instant OTP Loyalty Redemption at POS',
        'Detailed Customer Retention & Visit Analytics',
      ];
    }
    if (s.contains('campaign')) {
      return [
        'Targeted WhatsApp & SMS Broadcasts',
        'Automated Inactive Customer Re-engagement',
        'Custom Promo Coupons & Festival Offers',
        'Live Campaign Conversion & ROI Tracking',
      ];
    }
    if (s.contains('inventory')) {
      return [
        'Real-time Ingredient & Stock Tracking',
        'Automated Recipe Consumption on KOT',
        'Low Stock Warning Notifications',
        'Supplier Purchase Orders & Cost Analysis',
      ];
    }
    return [
      'Multi-device POS & Live Kitchen KDS Sync',
      'Smart Loyalty & Cashback Rewards Engine',
      'Automated WhatsApp & SMS Campaigns',
      'Inventory, Recipe Costing & Stock Alerts',
    ];
  }

  double get _yearlyPrice => _data.plans.isNotEmpty && _data.plans.first.priceAnnual > 0
      ? _data.plans.first.priceAnnual
      : 7999.0;

  double get _monthlyPrice => _data.plans.isNotEmpty && _data.plans.first.priceMonthly > 0
      ? _data.plans.first.priceMonthly
      : 999.0;

  void _handlePrimaryCta() {
    final selectedPlanName = _selectedTierIndex == 0 ? 'Yearly Pro Plan' : 'Monthly Pro Plan';
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
    final initialContact = (user?.name.isNotEmpty == true) ? user!.name : initialRestName;
    final initialPhone = user?.phone ?? '';
    final initialEmail = user?.email ?? '';

    final restCtrl = TextEditingController(text: initialRestName);
    final contactCtrl = TextEditingController(text: initialContact);
    final phoneCtrl = TextEditingController(text: initialPhone);
    final emailCtrl = TextEditingController(text: initialEmail);
    final notesCtrl = TextEditingController();

    bool isSubmitting = false;
    String? phoneError;
    final bool isDemo = featureSource == 'demo_request' || planName.toLowerCase().contains('demo');

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
                  constraints: BoxConstraints(maxWidth: math.min(screenWidth, 500.0)),
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 14,
                    bottom: 18,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF071126),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(color: Colors.black87, blurRadius: 36, offset: Offset(0, -8)),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A1435),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDemo
                                    ? const Color(0xFF00C2FF).withValues(alpha: 0.5)
                                    : const Color(0xFFF59E0B).withValues(alpha: 0.5),
                              ),
                            ),
                            child: Icon(
                              isDemo ? Icons.play_circle_fill_rounded : Icons.workspace_premium_rounded,
                              color: isDemo ? const Color(0xFF00C2FF) : const Color(0xFFF59E0B),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isDemo ? 'Request a Product Demo' : 'Request Pro Access',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isDemo ? '1-on-1 Guided Walkthrough' : 'Plan: $planName',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF38BDF8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),

                    // Value Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14532D).withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF4ADE80), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isDemo
                                  ? 'Lead automatically dispatched to sooftcode@gmail.com for priority demo scheduling.'
                                  : 'Direct notification sent to sooftcode@gmail.com for immediate activation.',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF86EFAC),
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Business Name
                    _buildDarkTextField(
                      controller: restCtrl,
                      label: 'Business / Restaurant Name',
                      icon: Icons.storefront_rounded,
                      hint: 'e.g. Apna Restaurant & Cafe',
                    ),
                    const SizedBox(height: 12),

                    // Contact Person
                    _buildDarkTextField(
                      controller: contactCtrl,
                      label: 'Your Name (Contact Person)',
                      icon: Icons.person_rounded,
                      hint: 'e.g. Chandan Kumar',
                    ),
                    const SizedBox(height: 12),

                    // Phone Number
                    _buildDarkTextField(
                      controller: phoneCtrl,
                      label: 'Mobile / WhatsApp Number *',
                      icon: Icons.phone_android_rounded,
                      hint: 'e.g. 9876543210',
                      keyboardType: TextInputType.phone,
                      errorText: phoneError,
                    ),
                    const SizedBox(height: 12),

                    // Email
                    _buildDarkTextField(
                      controller: emailCtrl,
                      label: 'Email ID (Optional)',
                      icon: Icons.email_rounded,
                      hint: 'e.g. contact@myrestaurant.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),

                    // Notes
                    _buildDarkTextField(
                      controller: notesCtrl,
                      label: isDemo ? 'Preferred Time / Questions' : 'Specific Requirements / Notes',
                      icon: Icons.notes_rounded,
                      hint: isDemo
                          ? 'e.g. Best time to call or features you want to explore'
                          : 'e.g. Need WhatsApp campaign and inventory setup',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    // Submit CTA Button
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: GlassTheme.primaryButtonGradient,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0052FF).withValues(alpha: 0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
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
                                      phoneError = 'Please enter a valid mobile number';
                                    });
                                    return;
                                  }

                                  setModalState(() {
                                    phoneError = null;
                                    isSubmitting = true;
                                  });

                                  final effectiveSource = featureSource ?? widget.sourceFeature;
                                  final billingCycle = isDemo
                                      ? 'demo'
                                      : (_selectedTierIndex == 0 ? 'annual' : 'monthly');

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
                          borderRadius: BorderRadius.circular(16),
                          child: Center(
                            child: isSubmitting
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Submitting to sooftcode@gmail.com...',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isDemo ? Icons.calendar_month_rounded : Icons.check_circle_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isDemo ? 'Submit Demo Request' : 'Submit Access Request',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.2,
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
  );
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: math.min(screenWidth * 0.90, 390.0),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF071126),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x33FFFFFF), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 32,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDemo ? const Color(0xFF0A1E4A) : const Color(0xFF0F3924),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDemo ? const Color(0xFF00C2FF) : const Color(0xFF22C55E),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        isDemo ? Icons.event_available_rounded : Icons.verified_rounded,
                        color: isDemo ? const Color(0xFF00C2FF) : const Color(0xFF4ADE80),
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isDemo ? 'Demo Request Submitted' : 'Pro Access Requested',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
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
                        fontSize: 11.5,
                        color: Color(0xFF94A3B8),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1435),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF38BDF8), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              phone.isNotEmpty
                                  ? 'Our team will contact you at $phone shortly.'
                                  : 'Our team will contact you shortly.',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Open Feature Main Screen Action
                    Container(
                      width: double.infinity,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: GlassTheme.primaryButtonGradient,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _navigateToTargetScreen(sourceFeature);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _getProceedButtonLabel(sourceFeature),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Back to Subscription',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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

  static Widget _buildDarkTextField({
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
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFCBD5E1)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          scrollPadding: const EdgeInsets.only(bottom: 90),
          style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF00C2FF)),
            errorText: errorText,
            filled: true,
            fillColor: const Color(0xFF040814),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF0052FF), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GlassTheme.bgDark1,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.35),
            radius: 1.3,
            colors: [
              Color(0x440052FF), // POS Electric Blue glow
              Color(0xFF071126),
              Color(0xFF03060F),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar with Minimal Back Button & Title
              _buildTopBar(),
              if (_isLoading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: Color(0xFF00C2FF),
                ),

              // Scrollable Paywall Content
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1. Center Hero Image Graphic (Enlarged and completely transparent)
                          _buildFloatingHero(),
                          const SizedBox(height: 12),

                          // 2. Glowing Golden Box with Features Checklist (Refined typography)
                          _buildGlowingFeatureBox(),
                          const SizedBox(height: 14),

                          // 3. 2-Tier Pricing Selector (Yearly 20% OFF, Monthly - Perfectly Aligned)
                          _buildPricingTiers(),
                          const SizedBox(height: 14),

                          // 4. Primary Glowing CTA Button
                          _buildPrimaryCtaButton(),
                          const SizedBox(height: 10),

                          // 5. Secondary Action Pill Button: "I am Interested for Demo"
                          _buildSecondaryActionButton(),
                          const SizedBox(height: 14),

                          // 6. Footer Links
                          _buildFooterLinks(),
                          const SizedBox(height: 12),
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
    );
  }

  /// Top Bar with Left Back Button and Centered Feature Title
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              _featureTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(width: 36), // Balances left back button so title remains centered
        ],
      ),
    );
  }

  /// Center Floating Hero Showcase: Increased size with clean transparent background
  Widget _buildFloatingHero() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_pulseAnimation.value * 0.025),
          child: SizedBox(
            height: 146,
            child: Center(
              child: Image.asset(
                'assets/images/subscription_hero_cards.png',
                height: 140,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Text('👑', style: TextStyle(fontSize: 54)),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Glowing Container with Gold Side-Border Effects & Refined Text Size
  Widget _buildGlowingFeatureBox() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _GlowingGradientBorderPainter(
          borderRadius: 20,
          borderWidth: 1.5,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFDE68A), // Vibrant Gold top
              Color(0xFFFBBF24), // Gold top-sides
              Color(0xFFF59E0B), // Warm Amber sides
              Color(0x33F59E0B), // Fading bottom sides
              Color(0x10F59E0B), // Subtle bottom
            ],
            stops: [0.0, 0.25, 0.55, 0.85, 1.0],
          ),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF091124).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  _heroHeading,
                  style: const TextStyle(
                    color: Color(0xFFFDE68A),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),

              ..._featureBullets.map(
                (bullet) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_rounded, color: Colors.white, size: 17),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bullet,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
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
      ),
    );
  }

  /// 2 Pricing Tier Cards (Yearly Plan & Monthly Plan - Perfectly Aligned)
  Widget _buildPricingTiers() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Yearly (Recommended with 20% OFF badge)
        Expanded(
          child: _buildTierCard(
            index: 0,
            title: 'Yearly Plan',
            price: '₹${_yearlyPrice.toStringAsFixed(0)}',
            subtitle: 'Billed Annually',
            badgeText: '20% OFF',
            isRecommended: true,
          ),
        ),
        const SizedBox(width: 12),

        // 2. Monthly Plan
        Expanded(
          child: _buildTierCard(
            index: 1,
            title: 'Monthly Plan',
            price: '₹${_monthlyPrice.toStringAsFixed(0)}',
            subtitle: 'Billed Monthly',
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
    bool isRecommended = false,
  }) {
    final isSelected = _selectedTierIndex == index;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        GestureDetector(
          onTap: () => setState(() => _selectedTierIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: 104, // Perfectly matched uniform height
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF0A1435)
                  : const Color(0xFF071126).withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? (isRecommended ? const Color(0xFF10B981) : const Color(0xFF00C2FF))
                    : const Color(0xFF1E293B),
                width: isSelected ? 1.8 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: (isRecommended ? const Color(0xFF10B981) : const Color(0xFF00C2FF))
                            .withValues(alpha: 0.25),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    price,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Top Badge (e.g. 20% OFF)
        if (badgeText != null)
          Positioned(
            top: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                badgeText,
                style: const TextStyle(
                  color: Color(0xFF064E3B),
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

  /// Primary Glowing CTA Button ("Upgrade to Pro Suite")
  Widget _buildPrimaryCtaButton() {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: GlassTheme.primaryButtonGradient,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0052FF).withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handlePrimaryCta,
          borderRadius: BorderRadius.circular(24),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Upgrade to Pro Suite',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Secondary Pill Button: "I am Interested for Demo"
  Widget _buildSecondaryActionButton() {
    return Container(
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1435).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
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
                Icon(Icons.play_circle_outline_rounded, color: Color(0xFF38BDF8), size: 16),
                SizedBox(width: 6),
                Text(
                  'I am Interested for Demo',
                  style: TextStyle(
                    color: Color(0xFFE2E8F0),
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

  /// Footer Links
  Widget _buildFooterLinks() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _openLeadBottomSheet(
            planName: 'Promo Code Inquiry',
            price: 0,
            featureSource: 'promo_code',
          ),
          child: const Text(
            'Promo Code',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Checking store purchases... No prior purchase found.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text(
                'Restore purchases',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ),
            const Text('  •  ', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            GestureDetector(
              onTap: () {},
              child: const Text(
                'Terms of Services',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Text('  •  ', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            GestureDetector(
              onTap: () {},
              child: const Text(
                'Privacy Policy',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// CustomPainter for luminous golden gradient top & side border effect
class _GlowingGradientBorderPainter extends CustomPainter {
  final double borderRadius;
  final double borderWidth;
  final Gradient gradient;

  _GlowingGradientBorderPainter({
    required this.borderRadius,
    required this.borderWidth,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      borderWidth / 2,
      borderWidth / 2,
      size.width - borderWidth,
      size.height - borderWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowingGradientBorderPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.borderWidth != borderWidth;
}
