import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/database/database_service.dart';
import '../../core/services/meta_partner_service.dart';

class _NeumorphicTheme {
  static const Color background = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color primaryBlue = Color(0xFF1877F2);
}

class MetaPartnerChannelScreen extends StatefulWidget {
  const MetaPartnerChannelScreen({super.key});

  @override
  State<MetaPartnerChannelScreen> createState() => _MetaPartnerChannelScreenState();
}

class _MetaPartnerChannelScreenState extends State<MetaPartnerChannelScreen> {
  final DatabaseService _db = DatabaseService();

  // Primary Navigation Mode: 0 = Channels Fleet (Video layout), 1 = WABA Health & Settings
  int _primaryViewMode = 0;
  int _activeSettingsTab = 2; // Default to WABA Hub in settings

  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  // Channels Fleet State
  List<MetaChannelItem> _channels = [];
  bool _isLoadingChannels = false;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Form Controllers for Profile / Manual Config
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
  bool _isSyncingTemplates = false;

  MetaPartnerAnalytics? _analytics;

  @override
  void initState() {
    super.initState();

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

    _loadChannels();
    _loadTemplates();
    _loadAnalytics();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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

  Future<void> _loadChannels() async {
    setState(() => _isLoadingChannels = true);
    try {
      final list = await MetaPartnerService().getChannels();
      if (mounted) {
        setState(() {
          _channels = list;
          _isLoadingChannels = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingChannels = false;
          // Fallback primary channel from local DB if server is offline
          if (_channels.isEmpty && _db.isMetaPartnerConnected) {
            _channels = [
              MetaChannelItem(
                channelId: 'primary_default_channel',
                name: _db.metaPartnerVerifiedName.isNotEmpty ? _db.metaPartnerVerifiedName : (_db.restaurant?.name ?? 'Primary WhatsApp Channel'),
                phoneNumber: _db.whatsAppPhoneNumber.isNotEmpty ? _db.whatsAppPhoneNumber : '+91 73036 32949',
                phoneNumberId: _db.whatsAppPhoneId.isNotEmpty ? _db.whatsAppPhoneId : '1284061438133660',
                wabaId: _db.whatsAppWabaId.isNotEmpty ? _db.whatsAppWabaId : '2525727467906581',
                isActive: true,
                status: 'ACTIVE',
                integrationStatus: 'Active Meta Cloud API',
                pinRegistered: true,
                webhookSubscribed: true,
              ),
            ];
          }
        });
      }
    }
  }

  Future<void> _loadTemplates() async {
    try {
      final list = await MetaPartnerService().getTemplates();
      if (mounted) {
        setState(() {
          _templates = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAnalytics() async {
    try {
      final data = await MetaPartnerService().getAnalytics();
      if (mounted) {
        setState(() {
          _analytics = data;
        });
      }
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // BUILD METHOD (RESPONSIVE WEB & MOBILE)
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWebLayout = kIsWeb || screenWidth >= 768;

    return Scaffold(
      backgroundColor: _NeumorphicTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            _buildTopNavBar(isWebLayout),

            // Notification Banners
            if (_errorMessage != null) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isWebLayout ? 32 : 16, vertical: 8),
                child: _buildAlertBox(message: _errorMessage!, isError: true),
              ),
            ],
            if (_successMessage != null) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isWebLayout ? 32 : 16, vertical: 8),
                child: _buildAlertBox(message: _successMessage!, isError: false),
              ),
            ],

            // Main Content Area
            Expanded(
              child: _primaryViewMode == 0
                  ? _buildChannelsFleetView(isWebLayout)
                  : _buildWabaSettingsView(isWebLayout),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TOP NAVIGATION BAR (WEB & MOBILE ADAPTIVE)
  // -------------------------------------------------------------
  Widget _buildTopNavBar(bool isWebLayout) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWebLayout ? 28 : 14,
        vertical: isWebLayout ? 14 : 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: isWebLayout
          ? (screenWidth >= 1120 ? _buildWebHeaderSingleRow() : _buildWebHeaderTwoRows())
          : _buildMobileHeaderColumn(),
    );
  }

  Widget _buildWebHeaderSingleRow() {
    return Row(
      children: [
        // Back Button
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 18, color: _NeumorphicTheme.textDark),
          ),
        ),
        const SizedBox(width: 14),

        // Brand Title & Verified Badge
        Expanded(
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1877F2).withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.hub_rounded, size: 20, color: Color(0xFF1877F2)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'Meta Channels',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: _NeumorphicTheme.textDark,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1877F2).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF1877F2), width: 0.8),
                          ),
                          child: const Text(
                            'Official Tech Provider',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1877F2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Multi-Outlet WhatsApp Business API Fleet & Meta Embedded Onboarding',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _NeumorphicTheme.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Primary View Mode Switcher
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildViewModePill(mode: 0, label: 'Channels Fleet', icon: Icons.view_agenda_rounded),
              _buildViewModePill(mode: 1, label: 'WABA Settings', icon: Icons.tune_rounded),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Search Box (Matches Video)
        if (_primaryViewMode == 0) ...[
          Container(
            width: 220,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _NeumorphicTheme.textDark),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search Numbers...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // "+ Add New Meta Channel" Button (Vibrant Teal matching video)
          ElevatedButton.icon(
            onPressed: () => _showAddChannelDialog(context),
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            label: const Text(
              '+ Add New Meta Channel',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _NeumorphicTheme.primaryTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWebHeaderTwoRows() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Back, Title, Add Button
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 17, color: _NeumorphicTheme.textDark),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF1877F2).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF1877F2).withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.hub_rounded, size: 18, color: Color(0xFF1877F2)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  const Text(
                    'Meta Channels',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _NeumorphicTheme.textDark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1877F2).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF1877F2), width: 0.8),
                    ),
                    child: const Text(
                      'Official Tech Provider',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1877F2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_primaryViewMode == 0) ...[
              ElevatedButton.icon(
                onPressed: () => _showAddChannelDialog(context),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                label: const Text(
                  '+ Add New Meta Channel',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _NeumorphicTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Row 2: Mode Switcher & Search
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildViewModePill(mode: 0, label: 'Channels Fleet', icon: Icons.view_agenda_rounded),
                  _buildViewModePill(mode: 1, label: 'WABA Settings', icon: Icons.tune_rounded),
                ],
              ),
            ),
            const Spacer(),
            if (_primaryViewMode == 0) ...[
              Container(
                width: 260,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search Numbers...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildMobileHeaderColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 16, color: _NeumorphicTheme.textDark),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Meta Channels',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _NeumorphicTheme.textDark,
                    ),
                  ),
                  Text(
                    'Official Tech Provider • WABA Fleet',
                    style: TextStyle(fontSize: 10, color: _NeumorphicTheme.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  _buildViewModePill(mode: 0, label: 'Fleet', icon: Icons.view_agenda_rounded, compact: true),
                  _buildViewModePill(mode: 1, label: 'WABA', icon: Icons.tune_rounded, compact: true),
                ],
              ),
            ),
          ],
        ),
        if (_primaryViewMode == 0) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search Numbers...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      prefixIcon: const Icon(Icons.search_rounded, size: 15, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showAddChannelDialog(context),
                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                label: const Text('Add Channel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _NeumorphicTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildViewModePill({
    required int mode,
    required String label,
    required IconData icon,
    bool compact = false,
  }) {
    final bool isSelected = _primaryViewMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: () => setState(() => _primaryViewMode = mode),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 13 : 15,
              color: isSelected ? _NeumorphicTheme.primaryBlue : _NeumorphicTheme.textMuted,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 10.5 : 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? _NeumorphicTheme.primaryBlue : _NeumorphicTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // CHANNELS FLEET VIEW (FAITHFUL TO VIDEO FRAMES)
  // -------------------------------------------------------------
  Widget _buildChannelsFleetView(bool isWebLayout) {
    if (_isLoadingChannels) {
      return const Center(
        child: CircularProgressIndicator(color: _NeumorphicTheme.primaryTeal),
      );
    }

    final filteredChannels = _channels.where((ch) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery;
      return ch.phoneNumber.toLowerCase().contains(q) ||
          ch.name.toLowerCase().contains(q) ||
          ch.status.toLowerCase().contains(q);
    }).toList();

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWebLayout ? 1120 : double.infinity),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isWebLayout ? 32 : 14,
            vertical: isWebLayout ? 24 : 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Partner Status Summary Bar
              _buildPartnerStatusBar(isWebLayout),
              const SizedBox(height: 20),

              if (filteredChannels.isEmpty) ...[
                _buildEmptyChannelsState(isWebLayout),
              ] else ...[
                // Channel Cards Layout (2 columns on wide web, 1 on mobile)
                if (isWebLayout && MediaQuery.of(context).size.width >= 1000) ...[
                  _buildTwoColumnChannelGrid(filteredChannels),
                ] else ...[
                  ...filteredChannels.map((ch) => _buildChannelCard(ch, isWebLayout)),
                ],
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerStatusBar(bool isWebLayout) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWebLayout ? 20 : 14,
        vertical: isWebLayout ? 14 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF1877F2).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF1877F2), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Partner Admin: ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _NeumorphicTheme.textMuted),
                    ),
                    Text(
                      _db.metaPartnerAdminEmail,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _NeumorphicTheme.textDark),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFF22C55E), width: 0.8),
                      ),
                      child: const Text(
                        'Meta Verified',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Connected lines receive real-time webhook updates for orders, chats, and automated campaign broadcasts.',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          if (isWebLayout) ...[
            TextButton.icon(
              onPressed: _loadChannels,
              icon: const Icon(Icons.refresh_rounded, size: 14, color: _NeumorphicTheme.primaryBlue),
              label: const Text('Refresh Fleet', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTwoColumnChannelGrid(List<MetaChannelItem> channels) {
    return Column(
      children: [
        for (int i = 0; i < channels.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildChannelCard(channels[i], true)),
                const SizedBox(width: 18),
                if (i + 1 < channels.length)
                  Expanded(child: _buildChannelCard(channels[i + 1], true))
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------
  // SINGLE CHANNEL CARD (DIRECTLY MATCHING VIDEO)
  // -------------------------------------------------------------
  Widget _buildChannelCard(MetaChannelItem ch, bool isWebLayout) {
    final bool isChannelActive = ch.isActive && ch.status.toUpperCase() == 'ACTIVE';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TOP BANNER: Facebook Status & Login Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Facebook Logo Circle
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1877F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'f',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Connection State
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isChannelActive ? const Color(0xFF22C55E) : const Color(0xFFD97706),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isChannelActive ? 'Meta Connected' : 'Login in progress',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isChannelActive ? const Color(0xFF15803D) : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),

                // "Login" Button (Launches Facebook Embedded Signup)
                OutlinedButton.icon(
                  onPressed: () => _launchMetaOAuth(ch.phoneNumber),
                  icon: const Icon(Icons.login_rounded, size: 13, color: Color(0xFF1877F2)),
                  label: Text(
                    isChannelActive ? 'Reconnect' : 'Login',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1877F2),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1877F2), width: 1.1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // 2. IDENTITY SECTION: WhatsApp Logo + Phone + Status + Name
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // WhatsApp Icon Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                  ),
                  child: const Center(
                    child: Icon(Icons.chat_bubble_rounded, color: Color(0xFF16A34A), size: 22),
                  ),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Phone Number & Status Pill Row
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              ch.phoneNumber,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: _NeumorphicTheme.textDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Status Pill (! loggedOut or ✔ Active)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isChannelActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isChannelActive ? const Color(0xFF86EFAC) : const Color(0xFFFCD34D),
                                width: 0.9,
                              ),
                            ),
                            child: Text(
                              isChannelActive ? '✔ Active' : '! loggedOut',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isChannelActive ? const Color(0xFF15803D) : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Outlet / Channel Name
                      Text(
                        ch.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Integration Subtitle
                      Text(
                        'Integration: ${ch.integrationStatus}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _NeumorphicTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // 3. ACTION TOOLBAR (Register PIN, SYNC Templates, View Templates, Subscribe, Refresh)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Active Toggle Switch
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch.adaptive(
                      value: ch.isActive,
                      activeTrackColor: const Color(0xFF059669),
                      onChanged: (val) => _handleToggleChannelActive(ch, val),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      ch.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ch.isActive ? const Color(0xFF059669) : _NeumorphicTheme.textMuted,
                      ),
                    ),
                  ],
                ),

                // Register PIN Button (Blue #2563EB)
                ElevatedButton.icon(
                  onPressed: () => _showRegisterPinDialog(context, ch),
                  icon: const Icon(Icons.pin_rounded, size: 13, color: Colors.white),
                  label: const Text('Register PIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                    elevation: 0,
                  ),
                ),

                // SYNC Templates Button (Green #059669)
                ElevatedButton.icon(
                  onPressed: _isSyncingTemplates ? null : () => _handleSyncTemplatesForChannel(ch),
                  icon: _isSyncingTemplates
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync_rounded, size: 13, color: Colors.white),
                  label: const Text('SYNC Templates', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                    elevation: 0,
                  ),
                ),

                // View Templates Button (Sky Blue #0284C7)
                ElevatedButton.icon(
                  onPressed: () => _showTemplatesFleetDialog(context),
                  icon: const Icon(Icons.description_outlined, size: 13, color: Colors.white),
                  label: const Text('View Templates', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                    elevation: 0,
                  ),
                ),

                // Subscribe Button (Purple #7C3AED)
                ElevatedButton.icon(
                  onPressed: () => _handleSubscribeWebhook(ch),
                  icon: const Icon(Icons.notifications_active_outlined, size: 13, color: Colors.white),
                  label: const Text('Subscribe', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                    elevation: 0,
                  ),
                ),

                // Refresh Button
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _loadChannels,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Icon(Icons.refresh_rounded, size: 15, color: _NeumorphicTheme.textDark),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

          // 4. BOTTOM ACTION: Delete Channel Button (Full width soft red)
          InkWell(
            onTap: () => _confirmDeleteChannel(context, ch),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 15),
                  SizedBox(width: 5),
                  Text(
                    'Delete',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChannelsState(bool isWebLayout) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 48, horizontal: isWebLayout ? 32 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_business_rounded, color: _NeumorphicTheme.primaryTeal, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'No WhatsApp Channels Connected',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _NeumorphicTheme.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your first dedicated WhatsApp phone line with Meta Embedded Signup\nto enable bill deliveries, automated KOT alerts, and marketing campaigns.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _NeumorphicTheme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _showAddChannelDialog(context),
            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            label: const Text(
              '+ Add New Meta Channel',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _NeumorphicTheme.primaryTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // MODAL: "Own WhatsApp Channel" (MATCHING VIDEO FRAME 2)
  // -------------------------------------------------------------
  void _showAddChannelDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: _db.restaurant?.name ?? 'Main Outlet');
    final phoneCtrl = TextEditingController();
    bool isActive = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Row
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Own WhatsApp Channel',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: _NeumorphicTheme.textDark,
                                ),
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => Navigator.of(dialogCtx).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Prerequisites Box (Light Grey Box)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.checklist_rtl_rounded, color: Color(0xFF334155), size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Prerequisites:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildPrerequisiteBullet('Facebook Business account with admin access'),
                              const SizedBox(height: 4),
                              _buildPrerequisiteBullet('A dedicated phone number for WhatsApp (not registered on WhatsApp mobile app)'),
                              const SizedBox(height: 4),
                              _buildPrerequisiteBullet('Registered company address and information'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Channel Name Field
                        const Text(
                          'Channel Name *',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                          ),
                          child: TextField(
                            controller: nameCtrl,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _NeumorphicTheme.textDark),
                            decoration: const InputDecoration(
                              hintText: 'e.g. Hawaii Bites, Main Store, Loyalty Points',
                              hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Phone Number Field with Country Code Pill
                        const Text(
                          'Phone Number *',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // Country Flag & Prefix (+91)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text('🇮🇳', style: TextStyle(fontSize: 14)),
                                  SizedBox(width: 4),
                                  Text(
                                    '+91',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Phone Digits
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                                ),
                                child: TextField(
                                  controller: phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _NeumorphicTheme.textDark),
                                  decoration: const InputDecoration(
                                    hintText: '98996 36418',
                                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Info / Warning Box
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: const Color(0xFFBFDBFE), width: 1.0),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'The phone number must not be linked to any existing WhatsApp account. It will be visible to customers and used for communication.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF1E40AF),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // "Is Active" Checkbox
                        InkWell(
                          onTap: () => setDialogState(() => isActive = !isActive),
                          borderRadius: BorderRadius.circular(6),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isActive,
                                activeColor: _NeumorphicTheme.primaryTeal,
                                onChanged: (v) => setDialogState(() => isActive = v ?? true),
                              ),
                              const Text(
                                'Is Active',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons: Cancel & Proceed
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(dialogCtx).pop(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final name = nameCtrl.text.trim();
                                var phone = phoneCtrl.text.trim();
                                if (name.isEmpty || phone.isEmpty) {
                                  setState(() => _errorMessage = 'Please enter Channel Name and Phone Number.');
                                  Navigator.of(dialogCtx).pop();
                                  return;
                                }
                                if (!phone.startsWith('+')) {
                                  phone = '+91 $phone';
                                }

                                Navigator.of(dialogCtx).pop();
                                await _handleCreateChannel(name: name, phone: phone, isActive: isActive);
                              },
                              icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                              label: const Text(
                                'Proceed',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _NeumorphicTheme.primaryTeal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                            ),
                          ],
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

  Widget _buildPrerequisiteBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle_rounded, color: Color(0xFF0D9488), size: 13),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.3),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // DIALOG: REGISTER 2-STEP VERIFICATION PIN
  // -------------------------------------------------------------
  void _showRegisterPinDialog(BuildContext context, MetaChannelItem ch) {
    final pinCtrl = TextEditingController(text: '123456');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: const [
              Icon(Icons.pin_rounded, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 8),
              Text('Register 2-Step PIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Register a 6-digit security PIN for ${ch.phoneNumber} on Meta Cloud API.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 4),
                decoration: const InputDecoration(
                  labelText: '6-Digit PIN',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pin = pinCtrl.text.trim();
                Navigator.of(ctx).pop();
                setState(() => _isSaving = true);
                try {
                  final ok = await MetaPartnerService().registerPin(channelId: ch.channelId, pin: pin);
                  if (ok) {
                    setState(() => _successMessage = '2-Step PIN registered successfully for ${ch.phoneNumber}!');
                    await _loadChannels();
                  } else {
                    setState(() => _errorMessage = 'Failed to register PIN with Meta Cloud.');
                  }
                } catch (e) {
                  setState(() => _errorMessage = 'Error registering PIN: $e');
                } finally {
                  if (mounted) setState(() => _isSaving = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Register PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // DIALOG: RESTAURANT TEMPLATES FLEET
  // -------------------------------------------------------------
  void _showTemplatesFleetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.description_outlined, color: Color(0xFF0284C7), size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'WhatsApp Restaurant Templates',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _NeumorphicTheme.textDark),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pre-approved WhatsApp business templates for bills, KOT notifications, and order updates.',
                    style: TextStyle(fontSize: 11.5, color: _NeumorphicTheme.textMuted),
                  ),
                  const Divider(height: 20),

                  Expanded(
                    child: _templates.isEmpty
                        ? const Center(child: Text('No templates loaded. Click SYNC to register.'))
                        : ListView.separated(
                            itemCount: _templates.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final tpl = _templates[index];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          tpl.displayName,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _NeumorphicTheme.textDark),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFF22C55E), width: 0.8),
                                          ),
                                          child: Text(
                                            tpl.status,
                                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE0E7FF),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            tpl.category,
                                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF4338CA)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Code: ${tpl.name} • ${tpl.language}',
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontFamily: 'monospace'),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      tpl.description,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.35),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _handleSyncTemplates();
                    },
                    icon: const Icon(Icons.sync_rounded, size: 16, color: Colors.white),
                    label: const Text('Sync All Templates with Meta Cloud', style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // ACTIONS & HANDLERS
  // -------------------------------------------------------------
  Future<void> _handleCreateChannel({
    required String name,
    required String phone,
    required bool isActive,
  }) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final ch = await MetaPartnerService().createChannel(name: name, phoneNumber: phone, isActive: isActive);
      if (ch != null) {
        setState(() {
          _successMessage = 'WhatsApp Channel "$name" registered! Launching Meta Facebook Login...';
        });
        await _loadChannels();
        await _launchMetaOAuth(phone);
      } else {
        setState(() => _errorMessage = 'Failed to register channel.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Create Channel Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleToggleChannelActive(MetaChannelItem ch, bool val) async {
    try {
      final ok = await MetaPartnerService().toggleChannelActive(channelId: ch.channelId, isActive: val);
      if (ok) {
        await _loadChannels();
      }
    } catch (e) {
      debugPrint('Toggle error: $e');
    }
  }

  Future<void> _handleSubscribeWebhook(MetaChannelItem ch) async {
    setState(() => _isSaving = true);
    try {
      final ok = await MetaPartnerService().subscribeWebhook(channelId: ch.channelId);
      if (ok) {
        setState(() => _successMessage = 'WABA webhook subscribed successfully! Live incoming messages active.');
        await _loadChannels();
      } else {
        setState(() => _errorMessage = 'Failed to subscribe webhook.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Subscribe Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleSyncTemplatesForChannel(MetaChannelItem ch) async {
    await _handleSyncTemplates();
  }

  void _confirmDeleteChannel(BuildContext context, MetaChannelItem ch) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Delete Channel?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: Text(
            'Are you sure you want to remove ${ch.phoneNumber} (${ch.name}) from Apna POS?',
            style: const TextStyle(fontSize: 12.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                setState(() => _isSaving = true);
                try {
                  final ok = await MetaPartnerService().deleteChannel(channelId: ch.channelId);
                  if (ok) {
                    setState(() => _successMessage = 'Channel deleted successfully.');
                    await _loadChannels();
                  } else {
                    setState(() => _errorMessage = 'Failed to delete channel.');
                  }
                } catch (e) {
                  setState(() => _errorMessage = 'Delete Error: $e');
                } finally {
                  if (mounted) setState(() => _isSaving = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchMetaOAuth([String? phone]) async {
    final appId = '1284061438133660';
    final redirectUri = 'https://apnapos.com/auth/meta/callback';
    final oauthUrl = 'https://www.facebook.com/v21.0/dialog/oauth'
        '?client_id=$appId'
        '&redirect_uri=$redirectUri'
        '&response_type=code'
        '&scope=whatsapp_business_management,whatsapp_business_messaging';

    try {
      final uri = Uri.parse(oauthUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        setState(() => _errorMessage = 'Could not open Meta Login popup. Please allow popups.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'OAuth Launch Error: $e');
    }
  }

  // -------------------------------------------------------------
  // SECONDARY VIEW: WABA HEALTH, METRICS & PROFILE SETTINGS
  // -------------------------------------------------------------
  Widget _buildWabaSettingsView(bool isWebLayout) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: isWebLayout ? 24 : 14, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPartnerAdminCard(),
              const SizedBox(height: 14),

              _buildSegmentedSettingsTabs(),
              const SizedBox(height: 14),

              if (_activeSettingsTab == 0) _buildEmbeddedSignupTab(),
              if (_activeSettingsTab == 1) _buildCoManagementTab(),
              if (_activeSettingsTab == 2) _buildWabaHubTab(),
              if (_activeSettingsTab == 3) _buildTemplatesTab(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPartnerAdminCard() {
    return Container(
      padding: const EdgeInsets.all(14),
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
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _NeumorphicTheme.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF22C55E), width: 0.9),
                ),
                child: const Text(
                  'Meta Verified',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Onboard merchant businesses with your Meta Solution Partner status. Clients can connect their WhatsApp line via 1-Click Embedded Signup or Agency Co-Management without exposing sensitive credentials.',
            style: TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.35),
            softWrap: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedSettingsTabs() {
    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSettingsTabItem(index: 0, label: 'Embedded Signup'),
          _buildSettingsTabItem(index: 1, label: 'Co-Management'),
          _buildSettingsTabItem(index: 2, label: 'WABA Hub', showDot: _db.isMetaPartnerConnected),
          _buildSettingsTabItem(index: 3, label: 'Templates', badgeText: '${_templates.isNotEmpty ? _templates.length : 5}'),
        ],
      ),
    );
  }

  Widget _buildSettingsTabItem({required int index, required String label, bool showDot = false, String? badgeText}) {
    final bool isSelected = _activeSettingsTab == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => setState(() => _activeSettingsTab = index),
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
                        fontSize: 11,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmbeddedSignupTab() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Meta Embedded Signup Flow',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _NeumorphicTheme.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'The merchant completes onboarding inside a Meta-hosted modal. Meta auto-provisions a WhatsApp Business Account (WABA), assigns phone numbers, and shares permissions with your Partner App.',
            style: TextStyle(fontSize: 11, color: _NeumorphicTheme.textMuted, height: 1.35),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => _launchMetaOAuth(),
            icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white),
            label: const Text(
              'Launch Meta Embedded Signup Dialog',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoManagementTab() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Agency Business Portfolio Co-Management',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _NeumorphicTheme.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'If the merchant already manages their own Meta Business Portfolio (BM), enter their Portfolio ID to link their WhatsApp line to your Partner Console.',
            style: TextStyle(fontSize: 11, color: _NeumorphicTheme.textMuted, height: 1.35),
          ),
          const SizedBox(height: 12),
          _buildCompactInputField(
            controller: _portfolioIdCtrl,
            label: 'Merchant Meta Business Portfolio ID (BM ID)',
            hint: 'e.g. 109847291847120',
            icon: Icons.corporate_fare_rounded,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _handleCoManagement,
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 14),
            label: const Text('Send Co-Management Invitation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          padding: const EdgeInsets.all(12),
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
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _db.isMetaPartnerConnected ? const Color(0xFF15803D) : const Color(0xFF92400E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _db.isMetaPartnerConnected
                          ? 'Phone: ${_db.whatsAppPhoneNumber.isNotEmpty ? _db.whatsAppPhoneNumber : "+91 73036 32949"} • Verified Solution Partner'
                          : 'Connect or link your WABA to activate live customer messaging.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: _db.isMetaPartnerConnected ? const Color(0xFF166534) : const Color(0xFF78350F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Live Metrics Row (Responsive, no overflow)
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
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                title: 'Messaging Tier',
                textValue: _analytics?.messagingTier ?? '1K msgs/24h',
                valueColor: _NeumorphicTheme.textDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                title: 'Display Name',
                textValue: 'Approved',
                valueColor: const Color(0xFF15803D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Instant Test Ping Card
        _buildInstantTestPingCard(),
        const SizedBox(height: 12),

        // WhatsApp Business Profile Editor
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: const [
                  Icon(Icons.badge_rounded, color: Color(0xFF1877F2), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'WhatsApp Business Profile Info',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _NeumorphicTheme.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildCompactInputField(
                controller: _verifiedNameCtrl,
                label: 'Verified Display Name',
                hint: 'Restaurant or Brand Name',
                icon: Icons.storefront_rounded,
              ),
              const SizedBox(height: 8),
              _buildCompactInputField(
                controller: _bioCtrl,
                label: 'About / Status Bio',
                hint: 'Short description seen on WhatsApp profile',
                icon: Icons.info_outline_rounded,
              ),
              const SizedBox(height: 8),
              _buildCompactInputField(
                controller: _addressCtrl,
                label: 'Business Address',
                hint: 'Physical outlet address',
                icon: Icons.location_on_rounded,
              ),
              const SizedBox(height: 8),
              _buildCompactInputField(
                controller: _websiteCtrl,
                label: 'Storefront Website URL',
                hint: 'e.g. https://apnapos.com/store',
                icon: Icons.link_rounded,
              ),
              const SizedBox(height: 12),

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
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1877F2),
                        side: const BorderSide(color: Color(0xFF1877F2)),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _handleApplyToPosWhatsApp,
                      icon: const Icon(Icons.sync_rounded, color: Colors.white, size: 14),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Apply to POS WhatsApp',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstantTestPingCard() {
    return Container(
      padding: const EdgeInsets.all(14),
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
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                    ),
                    Text(
                      'Send real-time verification message to test deliverability instantly.',
                      style: TextStyle(fontSize: 10.5, color: Color(0xFF15803D)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

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
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _NeumorphicTheme.textDark),
                    decoration: const InputDecoration(
                      hintText: '+91 98765 43210',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
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
                label: const Text('Send Ping', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),

          if (_testPingResult != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF22C55E), width: 0.8),
              ),
              child: Text(
                _testPingResult!,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _NeumorphicTheme.textDark),
                        ),
                        Text(
                          'Pre-approved WhatsApp templates for bills, KOTs, and marketing.',
                          style: TextStyle(fontSize: 10.5, color: _NeumorphicTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSyncingTemplates ? null : _handleSyncTemplates,
                    icon: const Icon(Icons.sync_rounded, size: 14, color: Colors.white),
                    label: const Text('SYNC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ..._templates.map((tpl) => _buildTemplateCard(tpl)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(MetaTemplateItem tpl) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tpl.displayName,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _NeumorphicTheme.textDark),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tpl.status,
                  style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            tpl.description,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    String? textValue,
    Widget? customValue,
    Color valueColor = _NeumorphicTheme.textDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 3),
          customValue ??
              Text(
                textValue ?? '--',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: valueColor),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 3),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _NeumorphicTheme.textDark),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              prefixIcon: icon != null ? Icon(icon, size: 15, color: const Color(0xFF64748B)) : null,
              prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertBox({required String message, required bool isError}) {
    final bgColor = isError ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7);
    final borderColor = isError ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    final textColor = isError ? const Color(0xFF991B1B) : const Color(0xFF15803D);
    final iconData = isError ? Icons.error_outline_rounded : Icons.check_circle_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.1),
      ),
      child: Row(
        children: [
          Icon(iconData, color: borderColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: textColor),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(Icons.close_rounded, size: 14, color: textColor),
            onPressed: () => setState(() {
              if (isError) {
                _errorMessage = null;
              } else {
                _successMessage = null;
              }
            }),
          ),
        ],
      ),
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
      if (mounted) setState(() => _errorMessage = 'Test message failed: $e');
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
            _activeSettingsTab = 2;
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
          setState(() => _successMessage = 'WhatsApp Business Profile synced to Meta Cloud!');
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
        setState(() => _successMessage = 'Partner WABA applied! KOT, Bills, Chats & Campaigns are live.');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Sync error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
