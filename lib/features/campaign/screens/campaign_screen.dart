import 'package:flutter/material.dart';
import '../../subscription/screens/subscription_screen.dart';
import '../../../core/services/subscription_service.dart';
import '../../../core/database/database_service.dart';

class CampaignScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final int initialTabIndex;

  const CampaignScreen({
    super.key,
    this.onBack,
    this.initialTabIndex = 0,
  });

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  static const Color _primaryThemeColor = Color(0xFF082559);
  static const Color _accentBurgundy = Color(0xFF4A082F);

  late int _activeTab; // 0 = Marketing Tools, 1 = Pro Plans & Pricing
  final SubscriptionService _subscriptionService = SubscriptionService();
  final DatabaseService _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTabIndex;
  }

  void _openLeadBottomSheet({
    required String campaignTitle,
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
    final notesCtrl = TextEditingController(text: 'Interested in activating $campaignTitle');

    bool isSubmitting = false;
    String? phoneError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AnimatedPadding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              child: Container(
                padding: const EdgeInsets.only(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  top: 14,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                          child: const Icon(Icons.campaign_rounded, color: Color(0xFF38BDF8), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Marketing Campaign Activation',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                campaignTitle,
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

                    // Notice
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
                              'Inquiry sent to sooftcode@gmail.com. We will configure your WhatsApp/SMS templates.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildTextField(
                      controller: restCtrl,
                      label: 'Restaurant / Business Name',
                      icon: Icons.storefront_rounded,
                      hint: 'e.g. The Royal Gardenia',
                    ),
                    const SizedBox(height: 10),

                    _buildTextField(
                      controller: contactCtrl,
                      label: 'Your Name (Contact Person)',
                      icon: Icons.person_rounded,
                      hint: 'e.g. Chandan Yaduvanshi',
                    ),
                    const SizedBox(height: 10),

                    _buildTextField(
                      controller: phoneCtrl,
                      label: 'Mobile / WhatsApp Number *',
                      icon: Icons.phone_android_rounded,
                      hint: 'e.g. 9876543210',
                      keyboardType: TextInputType.phone,
                      errorText: phoneError,
                    ),
                    const SizedBox(height: 10),

                    _buildTextField(
                      controller: emailCtrl,
                      label: 'Email ID (Optional)',
                      icon: Icons.email_rounded,
                      hint: 'e.g. store@gmail.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),

                    _buildTextField(
                      controller: notesCtrl,
                      label: 'Campaign Requirements / Message',
                      icon: Icons.notes_rounded,
                      hint: 'e.g. Weekend discount broadcast for 500 customers',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

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

                                await _subscriptionService.submitInterestLead(
                                  restaurantName: restCtrl.text.trim(),
                                  contactPerson: contactCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim(),
                                  email: emailCtrl.text.trim(),
                                  selectedPlan: 'Campaign: $campaignTitle',
                                  billingCycle: 'monthly',
                                  sourceFeature: featureSource ?? 'campaign',
                                  notes: notesCtrl.text.trim(),
                                  price: 499,
                                );

                                if (modalCtx.mounted) {
                                  Navigator.pop(modalCtx);
                                  _showCampaignSuccessDialog(
                                    campaignTitle: campaignTitle,
                                    phone: phoneCtrl.text.trim(),
                                    contactName: contactCtrl.text.trim(),
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
                                  Text('I\'m Interested • Request Setup', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                                ],
                              ),
                      ),
                    ),
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

  void _showCampaignSuccessDialog({
    required String campaignTitle,
    required String phone,
    required String contactName,
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
              'Thank you $contactName! Your request for "$campaignTitle" has been sent to sooftcode@gmail.com.',
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
                    'Our campaign team will call $phone shortly',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryThemeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _activeTab = 0);
                },
                child: const Text('Back to Campaign Tools', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ),
            ),
          ],
        ),
      ),
    );
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
          scrollPadding: const EdgeInsets.only(bottom: 90),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Curved Header in App Default Color (#082559)
            _buildTopCurvedHeader(),

            // Body: Switch between Marketing Tools and Pro Subscription Plans
            Expanded(
              child: _activeTab == 0
                  ? _buildMarketingToolsBody()
                  : const SubscriptionScreen(
                      isEmbedded: true,
                      sourceFeature: 'campaign',
                    ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top Bar
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
              InkWell(
                onTap: () => setState(() => _activeTab = (_activeTab == 0 ? 1 : 0)),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _activeTab == 1 ? const Color(0xFFF59E0B) : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _activeTab == 1 ? const Color(0xFFF59E0B) : Colors.white.withValues(alpha: 0.28),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _activeTab == 1 ? Icons.campaign_rounded : Icons.workspace_premium_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _activeTab == 1 ? 'Tools' : 'Plans 👑',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Header Title
          const Text(
            'Marketing & Campaigns',
            style: TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),

          // Header Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              _activeTab == 0
                  ? 'Launch high-converting WhatsApp broadcasts, festival coupons & auto-wishes.'
                  : 'Choose the best subscription package for your growing restaurant.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),

          // Segmented Header Switcher: [📢 Marketing Tools | 👑 Pro Plans & Pricing]
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: _activeTab == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _activeTab == 0
                            ? const [
                                BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '📢 Marketing Tools',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            color: _activeTab == 0 ? _primaryThemeColor : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: _activeTab == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: _activeTab == 1
                            ? const [
                                BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '👑 Pro Plans & Pricing',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            color: _activeTab == 1 ? _primaryThemeColor : Colors.white70,
                          ),
                        ),
                      ),
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

  Widget _buildMarketingToolsBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Banner
          _buildHeroBanner(),
          const SizedBox(height: 16),

          // Section Title
          const Text(
            '📢 Automated Campaign Templates',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Target customers with automated WhatsApp marketing and SMS discounts.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),

          // 4 Campaign Cards
          _buildCampaignCard(
            title: 'WhatsApp Broadcast Offers',
            subtitle: 'Send bulk promotional menus, weekend discounts, and images directly to saved customers.',
            icon: Icons.chat_rounded,
            iconColor: const Color(0xFF25D366),
            tag: 'High Conversion',
          ),
          const SizedBox(height: 10),
          _buildCampaignCard(
            title: 'Automated Birthday & Anniversary Wishes',
            subtitle: 'Automatically dispatch personalized discount coupons on customer birthdays & anniversaries.',
            icon: Icons.cake_rounded,
            iconColor: const Color(0xFFEC4899),
            tag: 'Auto-Pilot',
          ),
          const SizedBox(height: 10),
          _buildCampaignCard(
            title: 'Win-Back Inactive Customers',
            subtitle: 'Re-engage customers who haven\'t visited in 30+ days with special "We Miss You" vouchers.',
            icon: Icons.replay_circle_filled_rounded,
            iconColor: const Color(0xFFF59E0B),
            tag: 'Retention Engine',
          ),
          const SizedBox(height: 10),
          _buildCampaignCard(
            title: 'Festival & Flash Promo Coupons',
            subtitle: 'Generate single-use promo codes and track redemption ROI directly in the POS register.',
            icon: Icons.local_offer_rounded,
            iconColor: const Color(0xFF0284C7),
            tag: 'Instant Boost',
          ),
          const SizedBox(height: 16),

          // Switch to Pro Plans banner
          _buildUnlockCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_accentBurgundy, Color(0xFF8E1449)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
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
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '🔥 BOOST REVENUE BY 35%',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Smart WhatsApp & SMS Marketing',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Connect WhatsApp Business API to broadcast deals, re-engage lost diners, and celebrate customer milestones.',
            style: TextStyle(color: Color(0xFFF1F5F9), fontSize: 11.5, height: 1.35),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _openLeadBottomSheet(
              campaignTitle: 'Full Marketing Campaign Suite',
              featureSource: 'campaign_hero_banner',
            ),
            icon: const Icon(Icons.rocket_launch_rounded, size: 14),
            label: const Text('I\'m Interested • Request Setup', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _accentBurgundy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String tag,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.25),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _openLeadBottomSheet(
                    campaignTitle: title,
                    featureSource: 'campaign_card',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    minimumSize: Size.zero,
                    elevation: 0,
                  ),
                  child: const Text('I\'m Interested', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockCard() {
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
          const Icon(Icons.workspace_premium_rounded, color: Color(0xFF0284C7), size: 26),
          const SizedBox(height: 6),
          const Text(
            'Looking for all-in-one automation?',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 3),
          const Text(
            'Explore the Growth / Pro plan with WhatsApp marketing, inventory costing, and loyalty rewards.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => setState(() => _activeTab = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryThemeColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('View All Pro Plans 👑', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}
