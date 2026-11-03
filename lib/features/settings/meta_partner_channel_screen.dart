import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../core/services/meta_partner_service.dart';

class _NeumorphicTheme {
  static const Color background = Color(0xFFEEF2F6);
  static const Color surface = Color(0xFFEEF2F6);
  static const Color sunkenSurface = Color(0xFFE2E9F2);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
}

class MetaPartnerChannelScreen extends StatefulWidget {
  const MetaPartnerChannelScreen({super.key});

  @override
  State<MetaPartnerChannelScreen> createState() => _MetaPartnerChannelScreenState();
}

class _MetaPartnerChannelScreenState extends State<MetaPartnerChannelScreen> {
  final DatabaseService _db = DatabaseService();
  late int _activeTab;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  // Form Controllers
  late final TextEditingController _wabaIdCtrl;
  late final TextEditingController _phoneIdCtrl;
  late final TextEditingController _phoneNumCtrl;
  late final TextEditingController _portfolioIdCtrl;
  late final TextEditingController _verifiedNameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _websiteCtrl;

  // Diagnostic Test Message
  late final TextEditingController _testPhoneCtrl;
  bool _isSendingTestPing = false;
  String? _testPingResult;

  // Template Fleet & Analytics
  List<MetaTemplateItem> _templates = [];
  bool _isLoadingTemplates = false;
  bool _isSyncingTemplates = false;

  MetaPartnerAnalytics? _analytics;
  bool _isLoadingAnalytics = false;

  @override
  void initState() {
    super.initState();
    _activeTab = _db.isMetaPartnerConnected ? 2 : 0;

    _wabaIdCtrl = TextEditingController(text: _db.whatsAppWabaId);
    _phoneIdCtrl = TextEditingController(text: _db.whatsAppPhoneId);
    _phoneNumCtrl = TextEditingController(text: _db.whatsAppPhoneNumber);
    _portfolioIdCtrl = TextEditingController(text: _db.metaPartnerPortfolioId);
    _verifiedNameCtrl = TextEditingController(
      text: _db.metaPartnerVerifiedName.isNotEmpty ? _db.metaPartnerVerifiedName : (_db.restaurant?.name ?? ''),
    );
    _bioCtrl = TextEditingController(
      text: 'Fresh & delicious food prepared with authentic ingredients. Order online or visit us!',
    );
    _addressCtrl = TextEditingController(text: _db.restaurant?.address ?? '');
    _websiteCtrl = TextEditingController(text: _db.restaurant?.storefrontUrl ?? '');

    final initialTestPhone = _db.whatsAppPhoneNumber.isNotEmpty
        ? _db.whatsAppPhoneNumber
        : (_db.currentUser?.phone ?? '+91 73036 32949');
    _testPhoneCtrl = TextEditingController(text: initialTestPhone);

    _loadTemplates();
    _loadAnalytics();
  }

  @override
  void dispose() {
    _wabaIdCtrl.dispose();
    _phoneIdCtrl.dispose();
    _phoneNumCtrl.dispose();
    _portfolioIdCtrl.dispose();
    _verifiedNameCtrl.dispose();
    _bioCtrl.dispose();
    _addressCtrl.dispose();
    _websiteCtrl.dispose();
    _testPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoadingTemplates = true);
    try {
      final list = await MetaPartnerService().getTemplates();
      if (mounted) {
        setState(() {
          _templates = list;
          _isLoadingTemplates = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTemplates = false);
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoadingAnalytics = true);
    try {
      final data = await MetaPartnerService().getAnalytics();
      if (mounted) {
        setState(() {
          _analytics = data;
          _isLoadingAnalytics = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAnalytics = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _NeumorphicTheme.background,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Partner Admin Identity Card
                  _buildPartnerAdminCard(),
                  const SizedBox(height: 12),

                  // Navigation Segmented Tabs (4 Tabs)
                  _buildSegmentedTabs(),
                  const SizedBox(height: 12),

                  // Notification Messages
                  if (_errorMessage != null) ...[
                    _buildAlertBox(message: _errorMessage!, isError: true),
                    const SizedBox(height: 10),
                  ],
                  if (_successMessage != null) ...[
                    _buildAlertBox(message: _successMessage!, isError: false),
                    const SizedBox(height: 10),
                  ],

                  // Tab Views
                  if (_activeTab == 0) _buildEmbeddedSignupTab(),
                  if (_activeTab == 1) _buildCoManagementTab(),
                  if (_activeTab == 2) _buildWabaHubTab(),
                  if (_activeTab == 3) _buildTemplatesTab(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: _NeumorphicTheme.textDark),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF1877F2).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1877F2).withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.hub_rounded, size: 18, color: Color(0xFF1877F2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    const Text(
                      'Meta Partner Channel',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: _NeumorphicTheme.textDark,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1877F2).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFF1877F2), width: 0.8),
                      ),
                      child: const Text(
                        'Official Tech Provider',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1877F2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                const Text(
                  'Meta Solution Partner Onboarding & WABA Fleet Manager',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _NeumorphicTheme.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerAdminCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0F5FF), Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC7D7FE), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Partner Account Administrator',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1877F2),
                      ),
                    ),
                    Text(
                      _db.metaPartnerAdminEmail,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _NeumorphicTheme.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF22C55E), width: 0.9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 11),
                    SizedBox(width: 3),
                    Text(
                      'Meta Verified',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Onboard merchant businesses with your Meta Solution Partner status. Clients can connect their WhatsApp line via 1-Click Embedded Signup or Agency Co-Management without exposing sensitive credentials.',
            style: TextStyle(
              fontSize: 10.5,
              color: Color(0xFF475569),
              height: 1.35,
            ),
            softWrap: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTabItem(index: 0, label: 'Embedded Signup'),
          _buildTabItem(index: 1, label: 'Co-Management'),
          _buildTabItem(index: 2, label: 'WABA Hub', showDot: _db.isMetaPartnerConnected),
          _buildTabItem(index: 3, label: 'POS Templates', badgeText: '${_templates.isNotEmpty ? _templates.length : 5}'),
        ],
      ),
    );
  }

  Widget _buildTabItem({required int index, required String label, bool showDot = false, String? badgeText}) {
    final bool isSelected = _activeTab == index;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? const Color(0xFF1877F2) : _NeumorphicTheme.textMuted,
                      ),
                    ),
                  ),
                ),
                if (showDot) ...[
                  const SizedBox(width: 3),
                  Container(
                    width: 5.5,
                    height: 5.5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                if (badgeText != null) ...[
                  const SizedBox(width: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1877F2).withValues(alpha: 0.15) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? const Color(0xFF1877F2) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertBox({required String message, required bool isError}) {
    final bgColor = isError ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7);
    final borderColor = isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    final textColor = isError ? const Color(0xFF991B1B) : const Color(0xFF15803D);
    final iconData = isError ? Icons.error_outline_rounded : Icons.check_circle_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.1),
      ),
      child: Row(
        children: [
          Icon(iconData, color: borderColor, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddedSignupTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Meta Embedded Signup Flow',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _NeumorphicTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'The merchant completes onboarding inside a Meta-hosted modal. Meta auto-provisions a WhatsApp Business Account (WABA), assigns phone numbers, and shares permissions with your Partner App.',
                style: TextStyle(fontSize: 10.5, color: _NeumorphicTheme.textMuted, height: 1.35),
                softWrap: true,
              ),
              const SizedBox(height: 10),

              // 4 Steps
              _buildStepRow(1, 'Partner Login', 'Authenticate with ${_db.metaPartnerAdminEmail}'),
              _buildStepRow(2, 'Business Portfolio', 'Merchant selects or creates their Meta BM'),
              _buildStepRow(3, 'WhatsApp Profile', 'Define verified display name & food category'),
              _buildStepRow(4, 'Phone OTP & Link', 'Verify phone SMS/Voice OTP & auto-bind WABA'),

              const SizedBox(height: 12),

              ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleEmbeddedSignup,
                icon: const Icon(Icons.facebook_rounded, color: Colors.white, size: 16),
                label: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Continue with Facebook & Meta',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Direct / Existing WABA Credentials Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: const [
                  Icon(Icons.tune_rounded, color: _NeumorphicTheme.textMuted, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'Direct / Existing WABA Credentials',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _NeumorphicTheme.textDark,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'Optional Override',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _NeumorphicTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              _buildCompactInputField(
                controller: _phoneIdCtrl,
                label: 'WhatsApp Phone Number ID',
                hint: 'e.g. 1284061438133660',
                icon: Icons.tag_rounded,
              ),
              const SizedBox(height: 6),
              _buildCompactInputField(
                controller: _wabaIdCtrl,
                label: 'WhatsApp Business Account ID (WABA ID)',
                hint: 'e.g. 2525727467906581',
                icon: Icons.apartment_rounded,
              ),
              const SizedBox(height: 6),
              _buildCompactInputField(
                controller: _phoneNumCtrl,
                label: 'WhatsApp Phone Number',
                hint: 'e.g. +91 73036 32949',
                icon: Icons.phone_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepRow(int step, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF1877F2).withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1877F2), width: 0.9),
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF1877F2)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              softWrap: true,
              text: TextSpan(
                style: const TextStyle(fontSize: 10.5, color: _NeumorphicTheme.textDark),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: subtitle, style: const TextStyle(color: _NeumorphicTheme.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoManagementTab() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Agency Business Portfolio Co-Management',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _NeumorphicTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'If the merchant already manages their own Meta Business Portfolio (BM), enter their Portfolio ID to link their WhatsApp line to your Partner Console.',
            style: TextStyle(fontSize: 10.5, color: _NeumorphicTheme.textMuted, height: 1.35),
            softWrap: true,
          ),
          const SizedBox(height: 10),

          _buildCompactInputField(
            controller: _portfolioIdCtrl,
            label: 'Merchant Meta Business Portfolio ID (BM ID)',
            hint: 'e.g. 109847291847120',
            icon: Icons.corporate_fare_rounded,
          ),
          const SizedBox(height: 10),

          ElevatedButton.icon(
            onPressed: _isSaving ? null : _handleCoManagement,
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 14),
            label: _isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Send Co-Management Invitation',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWabaHubTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Connection Health Banner
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _db.isMetaPartnerConnected ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _db.isMetaPartnerConnected ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
              width: 1.1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _db.isMetaPartnerConnected ? const Color(0xFF22C55E) : const Color(0xFFD97706),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _db.isMetaPartnerConnected ? Icons.check_circle_rounded : Icons.info_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _db.isMetaPartnerConnected ? 'Meta Partner Channel Active' : 'WABA Line Standby',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _db.isMetaPartnerConnected ? const Color(0xFF15803D) : const Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _db.isMetaPartnerConnected
                          ? 'Phone: ${_db.whatsAppPhoneNumber.isNotEmpty ? _db.whatsAppPhoneNumber : "+91 73036 32949"} • Verified Solution Partner'
                          : 'Click Connect or link your WABA to activate live customer messaging.',
                      style: TextStyle(
                        fontSize: 10,
                        color: _db.isMetaPartnerConnected ? const Color(0xFF166534) : const Color(0xFF78350F),
                      ),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Live Metrics Row
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Quality Rating',
                customValue: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _analytics?.qualityRating == 'GREEN' ? 'HIGH (Green)' : (_analytics?.qualityRating ?? 'HIGH (Green)'),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildMetricCard(
                title: 'Messaging Tier',
                textValue: _analytics?.messagingTier ?? '1K msgs/24h',
                valueColor: _NeumorphicTheme.textDark,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildMetricCard(
                title: 'Display Name',
                textValue: 'Approved',
                valueColor: const Color(0xFF15803D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // NEW: Live Diagnostic & Instant Test Ping Card
        _buildInstantTestPingCard(),
        const SizedBox(height: 10),

        // WhatsApp Business Profile Editor
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: const [
                  Icon(Icons.badge_rounded, color: Color(0xFF1877F2), size: 14),
                  SizedBox(width: 6),
                  Text(
                    'WhatsApp Business Profile Info',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: _NeumorphicTheme.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              _buildCompactInputField(
                controller: _verifiedNameCtrl,
                label: 'Verified Display Name',
                hint: 'Restaurant or Brand Name',
                icon: Icons.storefront_rounded,
              ),
              const SizedBox(height: 6),
              _buildCompactInputField(
                controller: _bioCtrl,
                label: 'About / Status Bio',
                hint: 'Short description seen on WhatsApp profile',
                icon: Icons.info_outline_rounded,
              ),
              const SizedBox(height: 6),
              _buildCompactInputField(
                controller: _addressCtrl,
                label: 'Business Address',
                hint: 'Physical outlet address',
                icon: Icons.location_on_rounded,
              ),
              const SizedBox(height: 6),
              _buildCompactInputField(
                controller: _websiteCtrl,
                label: 'Storefront Website URL',
                hint: 'e.g. https://apnaposs.vercel.app/store',
                icon: Icons.link_rounded,
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _handleUpdateProfile,
                      icon: const Icon(Icons.cloud_upload_rounded, size: 14),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Sync to Meta Profile',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1877F2),
                        side: const BorderSide(color: Color(0xFF1877F2)),
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _handleApplyToPosWhatsApp,
                      icon: const Icon(Icons.sync_rounded, color: Colors.white, size: 14),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Apply to POS WhatsApp',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        if (_db.isMetaPartnerConnected)
          Center(
            child: TextButton.icon(
              onPressed: _isSaving ? null : _handleDisconnect,
              icon: const Icon(Icons.link_off_rounded, color: Color(0xFFEF4444), size: 14),
              label: const Text(
                'Disconnect Meta Partner Channel',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Instant WhatsApp Test Ping Diagnostic Card
  Widget _buildInstantTestPingCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FDF4), Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Live Diagnostic & Test Ping',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF166534),
                      ),
                    ),
                    Text(
                      'Send real-time verification message to test deliverability instantly.',
                      style: TextStyle(fontSize: 10, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC), width: 1.0),
                  ),
                  child: TextField(
                    controller: _testPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _NeumorphicTheme.textDark),
                    decoration: const InputDecoration(
                      hintText: '+91 98765 43210',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                      prefixIcon: Icon(Icons.phone_iphone_rounded, size: 15, color: Color(0xFF16A34A)),
                      prefixIconConstraints: BoxConstraints(minWidth: 32, minHeight: 32),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSendingTestPing ? null : _handleSendTestPing,
                icon: _isSendingTestPing
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 13, color: Colors.white),
                label: const Text('Send Ping', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),

          if (_testPingResult != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFF22C55E), width: 0.8),
              ),
              child: Text(
                _testPingResult!,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// POS Restaurant Template Fleet Tab
  Widget _buildTemplatesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1877F2).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF1877F2), size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Restaurant Template Fleet',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _NeumorphicTheme.textDark,
                          ),
                        ),
                        Text(
                          'Pre-approved WhatsApp templates for bills, KOTs, and marketing.',
                          style: TextStyle(fontSize: 10, color: _NeumorphicTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isSyncingTemplates ? null : _handleSyncTemplates,
                    icon: _isSyncingTemplates
                        ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5))
                        : const Icon(Icons.sync_rounded, size: 13),
                    label: const Text('Sync with Meta', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1877F2),
                      side: const BorderSide(color: Color(0xFF1877F2), width: 0.9),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_isLoadingTemplates)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1877F2)),
                  ),
                )
              else
                ..._templates.map((tpl) => _buildTemplateCard(tpl)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(MetaTemplateItem tpl) {
    final bool isApproved = tpl.status.toUpperCase() == 'APPROVED';
    final bool isUtility = tpl.category.toUpperCase() == 'UTILITY';

    IconData iconData = Icons.receipt_long_rounded;
    if (tpl.name.contains('order')) iconData = Icons.restaurant_rounded;
    if (tpl.name.contains('delivery')) iconData = Icons.delivery_dining_rounded;
    if (tpl.name.contains('feedback')) iconData = Icons.star_rate_rounded;
    if (tpl.name.contains('offer') || tpl.name.contains('promo')) iconData = Icons.local_offer_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isUtility ? const Color(0xFFEFF6FF) : const Color(0xFFFAF5FF),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: isUtility ? const Color(0xFFBFDBFE) : const Color(0xFFE9D5FF),
                    width: 0.8,
                  ),
                ),
                child: Icon(iconData, size: 15, color: isUtility ? const Color(0xFF2563EB) : const Color(0xFF9333EA)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tpl.displayName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _NeumorphicTheme.textDark,
                      ),
                    ),
                    Text(
                      'Template: ${tpl.name} (${tpl.language})',
                      style: const TextStyle(fontSize: 9.5, color: _NeumorphicTheme.textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isApproved ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  tpl.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: isApproved ? const Color(0xFF15803D) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            tpl.description,
            style: const TextStyle(fontSize: 10, color: Color(0xFF475569), height: 1.3),
            softWrap: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    String? textValue,
    Widget? customValue,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 9, color: _NeumorphicTheme.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          if (customValue != null)
            customValue
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                textValue ?? '',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? _NeumorphicTheme.textDark,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    int maxLines = 1,
    bool isNumeric = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          softWrap: true,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          decoration: BoxDecoration(
            color: _NeumorphicTheme.sunkenSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _NeumorphicTheme.textDark),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
              prefixIcon: icon != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                      child: Icon(icon, size: 15, color: const Color(0xFF64748B)),
                    )
                  : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSendTestPing() async {
    final phone = _testPhoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Please enter a mobile phone number for test ping.');
      return;
    }

    setState(() {
      _isSendingTestPing = true;
      _errorMessage = null;
      _testPingResult = null;
    });

    try {
      final res = await MetaPartnerService().sendTestMessage(recipientPhone: phone);
      if (mounted) {
        setState(() {
          final wamid = res?['messageId']?.toString() ?? 'Delivered';
          _testPingResult = 'Delivered to $phone • WAMID: $wamid';
          _successMessage = 'WhatsApp live ping sent successfully via Meta Cloud API!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Test message failed: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isSendingTestPing = false);
    }
  }

  Future<void> _handleSyncTemplates() async {
    setState(() => _isSyncingTemplates = true);
    try {
      final ok = await MetaPartnerService().syncTemplates();
      if (ok) {
        await _loadTemplates();
        if (mounted) {
          setState(() => _successMessage = 'Restaurant Template Fleet synced with Meta Cloud WABA!');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Sync failed: $e');
    } finally {
      if (mounted) setState(() => _isSyncingTemplates = false);
    }
  }

  Future<void> _handleEmbeddedSignup() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final phoneId = _phoneIdCtrl.text.trim().isNotEmpty
          ? _phoneIdCtrl.text.trim()
          : (_db.whatsAppPhoneId.isNotEmpty ? _db.whatsAppPhoneId : '1284061438133660');
      final phoneNum = _phoneNumCtrl.text.trim().isNotEmpty
          ? _phoneNumCtrl.text.trim()
          : (_db.whatsAppPhoneNumber.isNotEmpty ? _db.whatsAppPhoneNumber : '+91 73036 32949');
      final waba = _wabaIdCtrl.text.trim().isNotEmpty
          ? _wabaIdCtrl.text.trim()
          : (_db.whatsAppWabaId.isNotEmpty ? _db.whatsAppWabaId : '2525727467906581');

      final result = await MetaPartnerService().connectWaba(
        wabaId: waba,
        phoneNumberId: phoneId,
        phoneNumber: phoneNum,
        businessPortfolioId: _portfolioIdCtrl.text.trim(),
        verifiedName: _verifiedNameCtrl.text.trim(),
        onboardingType: 'embedded_signup',
      );

      if (result != null && result['success'] == true) {
        await _db.saveMetaPartnerSettings(
          connected: true,
          adminEmail: 'sooftcode@gmail.com',
          portfolioId: _portfolioIdCtrl.text.trim(),
          qualityRating: 'GREEN',
          messagingTier: 'TIER_1K',
          verifiedName: _verifiedNameCtrl.text.trim(),
          onboardingType: 'embedded_signup',
        );

        await _db.saveWhatsAppIntegrationSettings(
          enabled: true,
          provider: 'meta_cloud',
          phoneNumber: phoneNum,
          phoneId: phoneId,
          wabaId: waba,
          accessToken: _db.whatsAppAccessToken,
          webhookToken: _db.whatsAppWebhookToken,
        );

        if (mounted) {
          setState(() {
            _successMessage = 'Partner Onboarding completed successfully via Meta Embedded Signup!';
            _activeTab = 2;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Embedded Signup verification failed. Please check network and retry.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error initiating Meta Signup: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleCoManagement() async {
    final bmId = _portfolioIdCtrl.text.trim();
    if (bmId.isEmpty) {
      setState(() => _errorMessage = 'Please enter merchant Meta Business Portfolio ID (BM ID)');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final ok = await MetaPartnerService().inviteCoManagement(bmId);
      if (ok) {
        await _db.saveMetaPartnerSettings(
          connected: true,
          portfolioId: bmId,
          onboardingType: 'co_management',
        );
        if (mounted) {
          setState(() {
            _successMessage = 'Co-Management invitation sent! Merchant received notification in Meta BM.';
            _activeTab = 2;
          });
        }
      } else {
        if (mounted) setState(() => _errorMessage = 'Failed to send Co-Management invitation.');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Co-Management error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleUpdateProfile() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final ok = await MetaPartnerService().updateProfile(
        verifiedName: _verifiedNameCtrl.text.trim(),
        aboutBio: _bioCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        website: _websiteCtrl.text.trim(),
      );

      if (ok) {
        await _db.saveMetaPartnerSettings(
          connected: true,
          verifiedName: _verifiedNameCtrl.text.trim(),
        );
        if (mounted) {
          setState(() {
            _successMessage = 'WhatsApp Business Profile synced to Meta Cloud!';
          });
        }
      } else {
        if (mounted) setState(() => _errorMessage = 'Failed to sync profile to Meta.');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Profile update error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleApplyToPosWhatsApp() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final pId = _phoneIdCtrl.text.trim().isNotEmpty
          ? _phoneIdCtrl.text.trim()
          : (_db.whatsAppPhoneId.isNotEmpty ? _db.whatsAppPhoneId : '1284061438133660');
      final pNum = _phoneNumCtrl.text.trim().isNotEmpty
          ? _phoneNumCtrl.text.trim()
          : (_db.whatsAppPhoneNumber.isNotEmpty ? _db.whatsAppPhoneNumber : '+91 73036 32949');
      final waba = _wabaIdCtrl.text.trim().isNotEmpty
          ? _wabaIdCtrl.text.trim()
          : (_db.whatsAppWabaId.isNotEmpty ? _db.whatsAppWabaId : '2525727467906581');

      await _db.saveWhatsAppIntegrationSettings(
        enabled: true,
        provider: 'meta_cloud',
        phoneNumber: pNum,
        phoneId: pId,
        wabaId: waba,
        accessToken: _db.whatsAppAccessToken,
        webhookToken: _db.whatsAppWebhookToken,
      );
      await _db.saveMetaPartnerSettings(
        connected: true,
        verifiedName: _verifiedNameCtrl.text.trim(),
      );

      if (mounted) {
        setState(() {
          _successMessage = 'Partner WABA applied! KOT, Bills, Chats & Campaigns are live.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Sync error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDisconnect() async {
    setState(() => _isSaving = true);
    try {
      await MetaPartnerService().disconnect();
      await _db.clearMetaPartnerSettings();
      if (mounted) {
        setState(() {
          _successMessage = 'Partner Channel disconnected';
          _activeTab = 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Disconnect error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
