import 'package:flutter/material.dart';
import '../../models/campaign_models.dart';
import '../../services/campaign_service.dart';

class CampaignDashboardView extends StatefulWidget {
  final VoidCallback onCreateCampaign;
  final VoidCallback onCreateGroup;
  final VoidCallback onCreateAutoCampaign;
  final ValueChanged<CampaignModel> onSelectCampaign;
  final ValueChanged<CampaignTemplateModel>? onUseTemplate;

  const CampaignDashboardView({
    super.key,
    required this.onCreateCampaign,
    required this.onCreateGroup,
    required this.onCreateAutoCampaign,
    required this.onSelectCampaign,
    this.onUseTemplate,
  });

  @override
  State<CampaignDashboardView> createState() => _CampaignDashboardViewState();
}

class _CampaignDashboardViewState extends State<CampaignDashboardView> {
  final CampaignService _campaignService = CampaignService();

  String _selectedMainTab = 'Explore Campaigns'; // Explore Campaigns, Drafts, Pending, Approved, Scheduled, Action Rejected
  String _selectedCategory = 'AI'; // AI, Promotional, Free Gift, Flat Cash Discount, Percent Discount, etc.
  String _templateSearchQuery = '';
  bool _isLoading = true;

  CampaignStatsModel _stats = const CampaignStatsModel();
  List<CampaignModel> _campaigns = [];
  List<CampaignTemplateModel> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    final statsFuture = _campaignService.fetchDashboardStats();
    final campaignsFuture = _campaignService.fetchCampaigns(
      status: _mapTabToStatus(_selectedMainTab),
    );
    final templatesFuture = _campaignService.fetchTemplates(
      channel: 'whatsapp',
      category: _selectedCategory == 'AI' ? null : _selectedCategory,
      search: _templateSearchQuery,
    );

    final results = await Future.wait([statsFuture, campaignsFuture, templatesFuture]);

    if (mounted) {
      setState(() {
        _stats = results[0] as CampaignStatsModel;
        _campaigns = results[1] as List<CampaignModel>;
        _templates = results[2] as List<CampaignTemplateModel>;
        _isLoading = false;
      });
    }
  }

  String? _mapTabToStatus(String tab) {
    switch (tab) {
      case 'Drafts':
        return 'draft';
      case 'Pending':
        return 'running';
      case 'Approved':
        return 'completed';
      case 'Scheduled':
        return 'scheduled';
      case 'Action Rejected':
        return 'cancelled';
      case 'Explore Campaigns':
      default:
        return null;
    }
  }

  void _onMainTabChanged(String tab) {
    setState(() => _selectedMainTab = tab);
    _loadAllData();
  }

  void _onCategoryChanged(String cat) {
    setState(() => _selectedCategory = cat);
    _loadAllData();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5722)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Section: Hero Banner (Left) + Stats & Wallet Grid (Right)
                  _buildTopSplitSection(),
                  const SizedBox(height: 20),

                  // 2. Main Status Navigation Bar (Horizontal Rounded Pill Container)
                  _buildMainFilterNavBar(),
                  const SizedBox(height: 16),

                  // 3. Sub-Category Filter Pills & Search Input Row
                  _buildCategoryFilterRow(),
                  const SizedBox(height: 24),

                  // 4. Campaign Templates Horizontal Row (Meta Verified)
                  _buildCampaignTemplatesSection(),
                  const SizedBox(height: 32),

                  // 5. Recent Campaigns Management Table
                  _buildRecentCampaignsSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // =========================================================================
  // 1. TOP SPLIT SECTION: HERO BANNER & STATS/WALLET GRID
  // =========================================================================

  Widget _buildTopSplitSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 960;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Banner Left (63% width)
              Expanded(
                flex: 63,
                child: _buildHeroStudioBanner(),
              ),
              const SizedBox(width: 18),
              // Stats & Wallet Right (37% width)
              Expanded(
                flex: 37,
                child: _buildStatsAndWalletColumn(),
              ),
            ],
          );
        }

        // Stacked vertically for narrower views
        return Column(
          children: [
            _buildHeroStudioBanner(),
            const SizedBox(height: 18),
            _buildStatsAndWalletColumn(),
          ],
        );
      },
    );
  }

  Widget _buildHeroStudioBanner() {
    return Container(
      constraints: const BoxConstraints(minHeight: 250),
      padding: const EdgeInsets.only(left: 28, top: 18, bottom: 18, right: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF09393C), // Matching exact pixels from reference
            Color(0xFF0D454E),
            Color(0xFF08272C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3309393C),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Content
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Capsule Badge: CAMPAIGN STUDIO
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF143B38),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFF2DD4BF), size: 12),
                      SizedBox(width: 6),
                      Text(
                        'CAMPAIGN STUDIO',
                        style: TextStyle(
                          color: Color(0xFF2DD4BF),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Headline with colored "More Orders"
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.22,
                    ),
                    children: [
                      TextSpan(text: 'Engage Your Customers\nDeliver '),
                      TextSpan(
                        text: 'More Orders',
                        style: TextStyle(
                          color: Color(0xFFFF5722),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Subtitle description
                const Text(
                  'Create and send WhatsApp campaigns, offers, and updates in minutes.\nUse ready templates or create your own to drive more sales.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white70,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // + Create New Campaign (Orange gradient pill button)
                    InkWell(
                      onTap: widget.onCreateCampaign,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF5722), Color(0xFFFF7A00)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66FF5722),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Create New Campaign',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Auto Campaigns Button
                    InkWell(
                      onTap: widget.onCreateAutoCampaign,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.settings_outlined, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Auto Campaigns',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Audience Groups Button
                    InkWell(
                      onTap: widget.onCreateGroup,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.groups_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Audience Groups',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right Graphic: Exact 3D phone on glowing pedestal with WhatsApp logo & floating notification cards
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 230,
              child: Image.asset(
                'assets/images/campaign_hero_phone_3d.png',
                fit: BoxFit.contain,
                alignment: Alignment.centerRight,
                filterQuality: FilterQuality.high,
                errorBuilder: (ctx, error, stackTrace) => _buildFallbackHeroPhoneMockup(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackHeroPhoneMockup() {
    return Center(
      child: SizedBox(
        width: 210,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 120,
              height: 185,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF334155), width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x6625D366),
                    blurRadius: 28,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x6625D366),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'WhatsApp',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 15,
              left: -20,
              child: _buildFloatingHeroChip(
                title: 'Special Offer',
                sub: '50% OFF',
                color: const Color(0xFFFF5722),
              ),
            ),
            Positioned(
              top: 25,
              right: -30,
              child: _buildFloatingHeroChip(
                title: 'Order Update',
                sub: 'Your order is ready!',
                color: const Color(0xFF0093B8),
              ),
            ),
            Positioned(
              bottom: 30,
              left: -15,
              child: _buildFloatingHeroChip(
                title: 'New Menu',
                sub: 'Try Now!',
                color: const Color(0xFF2563EB),
              ),
            ),
            Positioned(
              bottom: 20,
              right: -25,
              child: _buildFloatingHeroChip(
                title: 'Free Delivery',
                sub: 'This Weekend',
                color: const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingHeroChip({
    required String title,
    required String sub,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600),
          ),
          Text(
            sub,
            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsAndWalletColumn() {
    return Column(
      children: [
        // 2x2 Stats Grid
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                count: '${_stats.draftCount}',
                label: 'Draft Campaigns',
                icon: Icons.send_rounded,
                iconColor: const Color(0xFFEA580C),
                iconBg: const Color(0xFFFFF7ED),
                onTap: () => _onMainTabChanged('Drafts'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatTile(
                count: '${_stats.approvedCount}',
                label: 'Approved',
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF10B981),
                iconBg: const Color(0xFFECFDF5),
                onTap: () => _onMainTabChanged('Approved'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                count: '${_stats.scheduledCount}',
                label: 'Scheduled',
                icon: Icons.access_time_rounded,
                iconColor: const Color(0xFF3B82F6),
                iconBg: const Color(0xFFEFF6FF),
                onTap: () => _onMainTabChanged('Scheduled'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatTile(
                count: '${_stats.pendingCount}',
                label: 'Pending',
                icon: Icons.near_me_rounded,
                iconColor: const Color(0xFFA855F7),
                iconBg: const Color(0xFFFAF5FF),
                onTap: () => _onMainTabChanged('Pending'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Wallet Balance Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFEA580C), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Wallet Balance',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${_stats.walletBalance.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF1E8),
                    foregroundColor: const Color(0xFFEA580C),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Top Up', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile({
    required String count,
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    count,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2. MAIN STATUS FILTER BAR
  // =========================================================================

  Widget _buildMainFilterNavBar() {
    final tabs = [
      {'label': 'Explore Campaigns', 'icon': Icons.explore_rounded, 'color': const Color(0xFFFF5722)},
      {'label': 'Drafts', 'icon': Icons.drafts_outlined, 'color': const Color(0xFF64748B)},
      {'label': 'Pending', 'icon': Icons.schedule_rounded, 'color': const Color(0xFF0D9488)},
      {'label': 'Approved', 'icon': Icons.verified_user_outlined, 'color': const Color(0xFF10B981)},
      {'label': 'Scheduled', 'icon': Icons.event_available_outlined, 'color': const Color(0xFF3B82F6)},
      {'label': 'Action Rejected', 'icon': Icons.warning_amber_rounded, 'color': const Color(0xFFEF4444)},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final isSelected = _selectedMainTab == tab['label'];
            final tabColor = tab['color'] as Color;

            if (isSelected) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5722), Color(0xFFFF7A00)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4DFF5722),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(tab['icon'] as IconData, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      tab['label'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => _onMainTabChanged(tab['label'] as String),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Row(
                    children: [
                      Icon(tab['icon'] as IconData, color: tabColor, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        tab['label'] as String,
                        style: TextStyle(
                          color: tabColor == const Color(0xFFEF4444) ? tabColor : const Color(0xFF64748B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // =========================================================================
  // 3. SUB-CATEGORY FILTER PILLS & SEARCH INPUT ROW
  // =========================================================================

  Widget _buildCategoryFilterRow() {
    final categories = [
      {'label': 'AI', 'icon': Icons.auto_awesome},
      {'label': 'Promotional', 'icon': Icons.campaign_outlined},
      {'label': 'Free Gift', 'icon': Icons.card_giftcard_rounded},
      {'label': 'Flat Cash Discount', 'icon': Icons.local_offer_outlined},
      {'label': 'Percent Discount', 'icon': Icons.percent_rounded},
      {'label': 'Combo / Bundle', 'icon': Icons.fastfood_outlined},
      {'label': 'Buy 1 Get 1 (BOGO)', 'icon': Icons.layers_outlined},
      {'label': 'New Menu', 'icon': Icons.restaurant_menu_rounded},
      {'label': 'Festival', 'icon': Icons.celebration_outlined},
      {'label': 'Re-engagement', 'icon': Icons.replay_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Scrolling Category Pills
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat['label'];
                  final isAi = cat['label'] == 'AI';

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => _onCategoryChanged(cat['label'] as String),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF5722)
                              : (isAi ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFF5722)
                                : (isAi ? const Color(0xFFFFEDD5) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cat['icon'] as IconData,
                              size: 14,
                              color: isSelected
                                  ? Colors.white
                                  : (isAi ? const Color(0xFFFF5722) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cat['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : (isAi ? const Color(0xFFFF5722) : const Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Search Field on Right
          SizedBox(
            width: 220,
            height: 38,
            child: TextField(
              onChanged: (val) {
                _templateSearchQuery = val;
                _loadAllData();
              },
              decoration: InputDecoration(
                hintText: 'Search templates...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFFF5722), width: 1.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. CAMPAIGN TEMPLATES SECTION (META VERIFIED CHIPS & CARDS)
  // =========================================================================

  Widget _buildCampaignTemplatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Campaign Templates',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 3),
                Text(
                  'Use ready to send templates or create your own campaign',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
            InkWell(
              onTap: widget.onCreateCampaign,
              child: const Row(
                children: [
                  Text(
                    'View All Templates',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFFF5722)),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFFF5722)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Horizontal Grid of Templates
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _templates.map((tpl) => _buildTemplateCard(tpl)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(CampaignTemplateModel tpl) {
    // Parse tag color
    Color tagBgColor;
    Color tagTextColor;
    switch (tpl.tagLabel.toLowerCase()) {
      case 'promotional':
        tagBgColor = const Color(0xFFDCFCE7);
        tagTextColor = const Color(0xFF15803D);
        break;
      case 'discount':
        tagBgColor = const Color(0xFFFFEDD5);
        tagTextColor = const Color(0xFFC2410C);
        break;
      case 'bogo':
        tagBgColor = const Color(0xFFF3E8FF);
        tagTextColor = const Color(0xFF7E22CE);
        break;
      case 'new menu':
        tagBgColor = const Color(0xFFDBEAFE);
        tagTextColor = const Color(0xFF1D4ED8);
        break;
      case 'free gift':
        tagBgColor = const Color(0xFFFCE7F3);
        tagTextColor = const Color(0xFFBE185D);
        break;
      case 're-engagement':
        tagBgColor = const Color(0xFFCCFBF1);
        tagTextColor = const Color(0xFF0F766E);
        break;
      default:
        tagBgColor = const Color(0xFFEFF6FF);
        tagTextColor = const Color(0xFF2563EB);
        break;
    }

    return Container(
      width: 215,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food Image with Overlaid Chips
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 125,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildTemplateImage(tpl.headerImageUrl),

                  // Only overlay badge if not pre-baked into template crop
                  if (!tpl.headerImageUrl.contains('tpl_food_')) ...[
                    // Gradient Dark Overlay for Badge Readability
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black54, Colors.transparent, Colors.black45],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),

                    // Overlaid Category Tag (Top-Left)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: tagBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 3, backgroundColor: tagTextColor),
                            const SizedBox(width: 4),
                            Text(
                              tpl.tagLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: tagTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Body Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon in box
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: tagBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(_getIconForCode(tpl.iconCode), size: 14, color: tagTextColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              tpl.name,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (tpl.isApprovedByMeta) ...[
                            const SizedBox(width: 4),
                            const Tooltip(
                              message: 'Meta Verified WhatsApp Template',
                              child: Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Description
                Text(
                  tpl.subtitle.isNotEmpty ? tpl.subtitle : tpl.body,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),

                // Use Template Button (Orange pill)
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () {
                      if (widget.onUseTemplate != null) {
                        widget.onUseTemplate!(tpl);
                      } else {
                        widget.onCreateCampaign();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Use Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 13),
                      ],
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

  Widget _buildTemplateImage(String url) {
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (ctx, error, stackTrace) => Container(
          color: const Color(0xFF1E293B),
          child: const Center(
            child: Icon(Icons.fastfood_rounded, color: Colors.white30, size: 36),
          ),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (ctx, error, stackTrace) => Container(
        color: const Color(0xFF1E293B),
        child: const Center(
          child: Icon(Icons.fastfood_rounded, color: Colors.white30, size: 36),
        ),
      ),
    );
  }

  IconData _getIconForCode(String code) {
    switch (code) {
      case 'crown':
        return Icons.emoji_events_rounded;
      case 'tag':
        return Icons.local_offer_rounded;
      case 'clock':
        return Icons.timer_rounded;
      case 'cloche':
        return Icons.restaurant_menu_rounded;
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'refresh':
        return Icons.replay_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  // =========================================================================
  // 5. RECENT CAMPAIGNS SECTION (DYNAMIC TABLE)
  // =========================================================================

  Widget _buildRecentCampaignsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent Campaigns',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 3),
                Text(
                  'Track and manage your campaigns',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
            InkWell(
              onTap: widget.onCreateCampaign,
              child: const Row(
                children: [
                  Text(
                    'View All',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFFF5722)),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFFF5722)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Table Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  color: const Color(0xFFF8FAFC),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text('Campaign Name', style: _headerStyle)),
                      Expanded(flex: 2, child: Text('Type', style: _headerStyle)),
                      Expanded(flex: 2, child: Text('Audience', style: _headerStyle)),
                      Expanded(flex: 2, child: Text('Channel', style: _headerStyle)),
                      Expanded(flex: 2, child: Text('Scheduled Date', style: _headerStyle)),
                      Expanded(flex: 1, child: Text('Sent', style: _headerStyle)),
                      Expanded(flex: 2, child: Text('Delivery Rate', style: _headerStyle)),
                      Expanded(flex: 2, child: Text('Status', style: _headerStyle)),
                      SizedBox(width: 40, child: Text('Actions', style: _headerStyle)),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Table Rows
                if (_campaigns.isEmpty)
                  _buildSampleOrEmptyRecentRow()
                else
                  ..._campaigns.map((c) => _buildCampaignRow(c)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSampleOrEmptyRecentRow() {
    // If database is clean, show the sample row matching the reference screenshot
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          // Campaign Name + Thumbnail
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/tpl_food_diwali_pizza.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 38,
                      height: 38,
                      color: const Color(0xFFFFF7ED),
                      child: const Icon(Icons.campaign_rounded, color: Color(0xFFFF5722), size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Diwali Special Offer',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Festive discount campaign',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Type
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Promotional',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                ),
              ),
            ),
          ),

          // Audience
          const Expanded(
            flex: 2,
            child: Text(
              'VIP Customers\n(320 customers)',
              style: TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
            ),
          ),

          // Channel (WhatsApp)
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFF25D366),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.chat_bubble, size: 12, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'WhatsApp',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),

          // Scheduled Date
          const Expanded(
            flex: 2,
            child: Text(
              '25 Oct 2026\n11:00 AM',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
            ),
          ),

          // Sent
          const Expanded(
            flex: 1,
            child: Text(
              '320',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
          ),

          // Delivery Rate with Progress Bar
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '92%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(
                          value: 0.92,
                          backgroundColor: Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
              ],
            ),
          ),

          // Status
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Completed',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                ),
              ),
            ),
          ),

          // Actions
          const SizedBox(
            width: 40,
            child: Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignRow(CampaignModel c) {
    return InkWell(
      onTap: () => widget.onSelectCampaign(c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            // Name + Thumbnail
            Expanded(
              flex: 3,
              child: Row(
                children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: c.template.headerImageUrl.isNotEmpty
                        ? _buildTemplateImage(c.template.headerImageUrl)
                        : Container(
                            color: const Color(0xFFFFF7ED),
                            child: const Icon(Icons.campaign_rounded, color: Color(0xFFFF5722), size: 18),
                          ),
                  ),
                ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          c.template.name,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Type
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    c.type.toUpperCase(),
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                  ),
                ),
              ),
            ),

            // Audience
            Expanded(
              flex: 2,
              child: Text(
                '${c.audience.groupName}\n(${c.audience.recipientCount} rec.)',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.3),
              ),
            ),

            // Channel
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                    child: const Icon(Icons.chat_bubble, size: 11, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                ],
              ),
            ),

            // Scheduled Date
            Expanded(
              flex: 2,
              child: Text(
                c.scheduledAt != null
                    ? '${c.scheduledAt!.day}/${c.scheduledAt!.month}/${c.scheduledAt!.year}'
                    : 'Now',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),

            // Sent
            Expanded(
              flex: 1,
              child: Text(
                '${c.stats.messagesSent}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ),

            // Delivery Rate
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.stats.deliveryRate.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (c.stats.deliveryRate / 100).clamp(0.0, 1.0),
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF94A3B8)),
                ],
              ),
            ),

            // Status
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.isCompleted
                        ? const Color(0xFFDCFCE7)
                        : (c.isRunning ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    c.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: c.isCompleted
                          ? const Color(0xFF15803D)
                          : (c.isRunning ? const Color(0xFF2563EB) : const Color(0xFFB45309)),
                    ),
                  ),
                ),
              ),
            ),

            // Action
            const SizedBox(
              width: 40,
              child: Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Color(0xFF64748B),
  );
}
