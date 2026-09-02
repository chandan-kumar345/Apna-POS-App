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

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final DatabaseService _db = DatabaseService();

  bool _isAnnual = true;
  bool _isLoading = false;
  SubscriptionDataModel _data = const SubscriptionDataModel();

  static const Color _primaryThemeColor = Color(0xFF082559);
  static const Color _accentCyan = Color(0xFF00C2FF);

  @override
  void initState() {
    super.initState();
    _data = _subscriptionService.getDefaultPlans();
    _loadPlans();
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
            : 'The Royal Gardenia');
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                left: 16,
                right: 16,
                top: 14,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
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
                            color: _primaryThemeColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Upgrade Inquiry & Request',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Plan: $planName (${_isAnnual ? 'Annual' : 'Monthly'})',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0284C7),
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Direct notification sent to sooftcode@gmail.com. We will activate your feature swiftly.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF15803D),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Restaurant Name
                    _buildTextField(
                      controller: restCtrl,
                      label: 'Restaurant / Business Name',
                      icon: Icons.storefront_rounded,
                      hint: 'e.g. The Royal Gardenia',
                    ),
                    const SizedBox(height: 10),

                    // Contact Person
                    _buildTextField(
                      controller: contactCtrl,
                      label: 'Your Name (Contact Person)',
                      icon: Icons.person_rounded,
                      hint: 'e.g. Chandan Yaduvanshi',
                    ),
                    const SizedBox(height: 10),

                    // Mobile Number
                    _buildTextField(
                      controller: phoneCtrl,
                      label: 'Mobile / WhatsApp Number *',
                      icon: Icons.phone_android_rounded,
                      hint: 'e.g. 9876543210',
                      keyboardType: TextInputType.phone,
                      errorText: phoneError,
                    ),
                    const SizedBox(height: 10),

                    // Email (Optional)
                    _buildTextField(
                      controller: emailCtrl,
                      label: 'Email ID (Optional)',
                      icon: Icons.email_rounded,
                      hint: 'e.g. store@gmail.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),

                    // Custom Notes / Requirements
                    _buildTextField(
                      controller: notesCtrl,
                      label: 'Any Specific Requirements?',
                      icon: Icons.notes_rounded,
                      hint: 'e.g. Need WhatsApp campaign and inventory setup',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Submit CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: isSubmitting
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
                                await _subscriptionService.submitInterestLead(
                                  restaurantName: restCtrl.text.trim(),
                                  contactPerson: contactCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim(),
                                  email: emailCtrl.text.trim(),
                                  selectedPlan: planName,
                                  billingCycle: _isAnnual ? 'annual' : 'monthly',
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
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryThemeColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Submitting to sooftcode@gmail.com...', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 18),
                                  SizedBox(width: 6),
                                  Text('I\'m Interested • Submit Inquiry', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                                ],
                              ),
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

  void _showSuccessDialog({
    required String planName,
    required String phone,
    required String contactName,
    required String sourceFeature,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 30),
            ),
            const SizedBox(height: 12),
            const Text(
              '🎉 Inquiry Received!',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Thank you $contactName! Your interest in $planName has been sent to sooftcode@gmail.com.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.35),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.support_agent_rounded, color: Color(0xFF0284C7), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Our sales team will call $phone shortly',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Open Feature Main Screen Action
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryThemeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(
                  _getProceedButtonLabel(sourceFeature),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _navigateToTargetScreen(sourceFeature);
                },
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Stay on Plans', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            ),
          ],
        ),
      ),
    );
  }

  String _getProceedButtonLabel(String source) {
    if (source.contains('inventory')) return 'Open Inventory Screen 📦';
    if (source.contains('loyalty')) return 'Open Loyalty Screen 👑';
    if (source.contains('campaign')) return 'Open Campaign Tools 📢';
    return 'Proceed to Main Screen 🚀';
  }

  void _navigateToTargetScreen(String source) {
    if (widget.onNavigateToFeature != null) {
      widget.onNavigateToFeature!(source);
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

  static Widget _buildTextField({
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
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            prefixIcon: Icon(icon, size: 16, color: const Color(0xFF0284C7)),
            errorText: errorText,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return _buildScrollableBody();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Curved Header (#082559)
            _buildTopCurvedHeader(),

            // Scrollable Content
            Expanded(
              child: _buildScrollableBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCurvedHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _primaryThemeColor,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x22082559),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else {
                    Navigator.maybePop(context);
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                onPressed: () => _loadPlans(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Apna POS Pro Plans & Pricing',
            style: TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Choose the perfect plan to automate and supercharge your business.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollableBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _primaryThemeColor));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Banner
          _buildHeroHeader(),
          const SizedBox(height: 14),

          // Billing Cycle Toggle (Annual / Monthly)
          _buildBillingCycleToggle(),
          const SizedBox(height: 14),

          // Pricing Plans Cards
          ..._data.plans.map((plan) => _buildPlanCard(plan)),

          const SizedBox(height: 18),

          // Specialized Addons (Inventory, Loyalty, Campaign)
          const Text(
            '⚡ Powerhouse Add-on Modules',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Upgrade individual modules or get everything in Growth / Pro.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),

          ..._data.addons.map((addon) => _buildAddonCard(addon)),

          const SizedBox(height: 18),

          // Contact & WhatsApp Help Banner
          _buildSalesSupportCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryThemeColor, Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18082559),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _accentCyan.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accentCyan),
            ),
            child: const Text(
              '👑 ENTERPRISE RESTAURANT SUITE',
              style: TextStyle(
                color: _accentCyan,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Unlock Full Power for Your Restaurant',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Automate Inventory, boost customer retention with Loyalty rewards, and run high-converting WhatsApp marketing campaigns.',
            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingCycleToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isAnnual = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _isAnnual ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _isAnnual
                      ? const [
                          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Annual Billing',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: _isAnnual ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'SAVE 33% 🔥',
                        style: TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w900,
                          fontSize: 8.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isAnnual = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_isAnnual ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: !_isAnnual
                      ? const [
                          BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Monthly Billing',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: !_isAnnual ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlanModel plan) {
    final isPopular = plan.popular;
    final price = _isAnnual ? plan.priceAnnual : plan.priceMonthly;
    final priceText = plan.priceMonthly == 0
        ? 'Free Forever'
        : (_isAnnual ? '₹${plan.priceAnnual.toInt()} / yr' : '₹${plan.priceMonthly.toInt()} / mo');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
          width: isPopular ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPopular ? const Color(0x180284C7) : const Color(0x06000000),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: const Center(
                child: Text(
                  '⭐ MOST POPULAR • BEST VALUE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (plan.badge.isNotEmpty && !isPopular)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          plan.badge,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  plan.description,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 8),

                // Price display
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      priceText,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: isPopular ? const Color(0xFF0284C7) : const Color(0xFF0F172A),
                      ),
                    ),
                    if (_isAnnual && plan.annualSavingsText.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${plan.annualSavingsText})',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ],
                ),
                const Divider(height: 18, color: Color(0xFFE2E8F0)),

                // Feature Checklist
                ...plan.features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            f,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton(
                    onPressed: plan.isCurrent
                        ? null
                        : () => _openLeadBottomSheet(
                              planName: plan.name,
                              price: price,
                              featureSource: 'plan_${plan.id}',
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPopular ? const Color(0xFF0284C7) : _primaryThemeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text(
                      plan.ctaLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddonCard(SubscriptionAddonModel addon) {
    IconData getIcon() {
      if (addon.id.contains('inventory')) return Icons.inventory_2_rounded;
      if (addon.id.contains('loyalty')) return Icons.card_giftcard_rounded;
      if (addon.id.contains('campaign')) return Icons.campaign_rounded;
      return Icons.star_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(getIcon(), color: const Color(0xFF0284C7), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  addon.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 1),
                Text(
                  addon.description,
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _openLeadBottomSheet(
              planName: addon.name,
              price: addon.priceMonthly,
              featureSource: addon.id,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Interested', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesSupportCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        children: [
          const Text(
            'Need Custom Setup or Instant Assistance?',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 3),
          const Text(
            'Our onboarding specialists are available on WhatsApp & Phone.',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _openLeadBottomSheet(
                  planName: 'Sales Inquiry',
                  price: 0,
                  featureSource: 'sales_support_banner',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.chat_rounded, size: 14),
                label: const Text('Chat on WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _openLeadBottomSheet(
                  planName: 'Enterprise Demo',
                  price: 0,
                  featureSource: 'sales_support_call',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryThemeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                icon: const Icon(Icons.phone_rounded, size: 14),
                label: const Text('Call Sales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
