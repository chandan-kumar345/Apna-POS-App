import 'package:flutter/material.dart';
import '../../models/campaign_models.dart';
import '../../services/campaign_service.dart';

/// Neumorphic design token definitions for Campaign Web Portal
class NeumorphicTheme {
  // Soft matte canvas background
  static const Color background = Color(0xFFEFF3F8);

  // Raised surface background
  static const Color cardSurface = Color(0xFFF6F9FC);

  // App & Top Header Colors
  static const Color headerPrimary = Color(0xFF082559);
  static const Color headerAccent = Color(0xFF0F3E82);
  static const Color headerDarkTeal = Color(0xFF09393C);
  static const Color accentCyan = Color(0xFF2DD4BF);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  /// Neumorphic convex / raised card decoration (dual shadow: bottom-right dark, top-left white)
  static BoxDecoration raisedDecoration({
    double radius = 18,
    Color color = cardSurface,
    double blur = 14,
    double distance = 5,
    Border? border,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: border ?? Border.all(color: Colors.white, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: const Color(0x1C64748B),
          offset: Offset(distance, distance),
          blurRadius: blur,
        ),
        BoxShadow(
          color: Colors.white,
          offset: Offset(-distance, -distance),
          blurRadius: blur,
        ),
      ],
    );
  }

  /// Neumorphic concave / recessed track decoration (sunken / debossed)
  static BoxDecoration recessedDecoration({
    double radius = 24,
    Color color = const Color(0xFFE4EBF4),
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x16000000),
          offset: Offset(2.5, 2.5),
          blurRadius: 5,
        ),
        BoxShadow(
          color: Colors.white,
          offset: Offset(-2.5, -2.5),
          blurRadius: 5,
        ),
      ],
    );
  }

  /// Neumorphic button in top header color
  static BoxDecoration headerButtonDecoration({
    double radius = 20,
    bool isElevated = true,
  }) {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [headerPrimary, headerAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
      boxShadow: isElevated
          ? [
              const BoxShadow(
                color: Color(0x3D082559),
                offset: Offset(3, 4),
                blurRadius: 10,
              ),
              const BoxShadow(
                color: Colors.white30,
                offset: Offset(-1, -1),
                blurRadius: 3,
              ),
            ]
          : null,
    );
  }
}

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

  String _selectedMainTab = 'Explore Campaigns';
  String _selectedCategory = 'All';
  String _templateSearchQuery = '';
  bool _isLoading = true;

  CampaignStatsModel _stats = const CampaignStatsModel();
  List<CampaignModel> _allCampaigns = [];
  List<CampaignModel> _campaigns = [];
  List<CampaignTemplateModel> _allTemplates = [];
  List<CampaignTemplateModel> _templates = [];
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadAllData(isInitial: true);
  }

  Future<void> _loadAllData({bool isInitial = false}) async {
    if (isInitial && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final statsFuture = _campaignService.fetchDashboardStats();
      final campaignsFuture = _campaignService.fetchCampaigns();
      final templatesFuture = _campaignService.fetchTemplates(channel: 'whatsapp');
      final categoriesFuture = _campaignService.fetchCategories();

      final results = await Future.wait([statsFuture, campaignsFuture, templatesFuture, categoriesFuture]);

      if (mounted) {
        setState(() {
          _stats = results[0] as CampaignStatsModel;
          _allCampaigns = results[1] as List<CampaignModel>;
          _allTemplates = results[2] as List<CampaignTemplateModel>;
          _categories = results[3] as List<Map<String, dynamic>>;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[CampaignDashboardView] _loadAllData error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    // 1. Filter campaigns by selected main status tab
    final statusFilter = _mapTabToStatus(_selectedMainTab);
    if (statusFilter == null || statusFilter.isEmpty) {
      _campaigns = List.from(_allCampaigns);
    } else {
      _campaigns = _allCampaigns.where((c) {
        final cStatus = c.status.toLowerCase();
        if (statusFilter == 'running') {
          return cStatus == 'running' || cStatus == 'pending';
        }
        if (statusFilter == 'completed') {
          return cStatus == 'completed' || cStatus == 'approved';
        }
        if (statusFilter == 'cancelled') {
          return cStatus == 'cancelled' || cStatus == 'rejected';
        }
        return cStatus == statusFilter;
      }).toList();
    }

    // 2. Filter templates by selected category and search query
    _templates = _allTemplates.where((t) {
      if (_selectedCategory != 'All') {
        final matchesCat = t.category.toLowerCase() == _selectedCategory.toLowerCase() ||
            t.tagLabel.toLowerCase() == _selectedCategory.toLowerCase();
        if (!matchesCat) return false;
      }
      if (_templateSearchQuery.trim().isNotEmpty) {
        final q = _templateSearchQuery.trim().toLowerCase();
        final matchesQuery = t.name.toLowerCase().contains(q) ||
            t.subtitle.toLowerCase().contains(q) ||
            t.tagLabel.toLowerCase().contains(q) ||
            t.category.toLowerCase().contains(q);
        if (!matchesQuery) return false;
      }
      return true;
    }).toList();
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
    if (_selectedMainTab == tab) return;
    setState(() {
      _selectedMainTab = tab;
      _applyFilters();
    });
    // Silently fetch fresh filtered data in the background without showing any loader
    _refreshCampaignsSilently();
  }

  Future<void> _refreshCampaignsSilently() async {
    try {
      final status = _mapTabToStatus(_selectedMainTab);
      final fresh = await _campaignService.fetchCampaigns(status: status);
      if (mounted) {
        setState(() {
          _campaigns = fresh;
          for (final c in fresh) {
            final idx = _allCampaigns.indexWhere((existing) => existing.id == c.id);
            if (idx >= 0) {
              _allCampaigns[idx] = c;
            } else {
              _allCampaigns.add(c);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[CampaignDashboardView] _refreshCampaignsSilently notice: $e');
    }
  }

  void _onCategoryChanged(String cat) {
    if (_selectedCategory == cat) return;
    setState(() {
      _selectedCategory = cat;
      _applyFilters();
    });
  }

  int _getCountForTab(String tab, int statsCount) {
    if (statsCount > 0) return statsCount;
    final status = _mapTabToStatus(tab);
    if (status == null) return _allCampaigns.length;
    return _allCampaigns.where((c) {
      final s = c.status.toLowerCase();
      if (status == 'running') return s == 'running' || s == 'pending';
      if (status == 'completed') return s == 'completed' || s == 'approved';
      if (status == 'cancelled') return s == 'cancelled' || s == 'rejected';
      return s == status;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NeumorphicTheme.background,
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(NeumorphicTheme.headerPrimary),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAllData,
              color: NeumorphicTheme.headerPrimary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. TOP SPLIT HERO SECTION: Hero Studio Banner + (2x2 Stats & Wallet Column)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 980) {
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 64, child: _buildHeroStudioBanner()),
                                const SizedBox(width: 18),
                                Expanded(flex: 36, child: _buildStatsAndWalletColumn()),
                              ],
                            ),
                          );
                        } else {
                          return Column(
                            children: [
                              _buildHeroStudioBanner(),
                              const SizedBox(height: 18),
                              _buildStatsAndWalletColumn(),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 22),

                    // 2. MAIN STATUS FILTER PILL BAR
                    _buildMainFilterNavBar(),
                    const SizedBox(height: 18),

                    // 3. SUB-CATEGORY FILTER PILLS & SEARCH INPUT
                    _buildCategoryFilterRow(),
                    const SizedBox(height: 26),

                    // 4. CAMPAIGN TEMPLATES SECTION
                    _buildCampaignTemplatesSection(),
                    const SizedBox(height: 30),

                    // 5. RECENT CAMPAIGNS SECTION (DYNAMIC TABLE)
                    _buildRecentCampaignsSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  // =========================================================================
  // 1. HERO STUDIO BANNER & STATS COLUMN
  // =========================================================================

  Widget _buildHeroStudioBanner() {
    return Container(
      constraints: const BoxConstraints(minHeight: 285),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF073437),
            Color(0xFF0C464C),
            Color(0xFF062226),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF2DD4BF).withValues(alpha: 0.28),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(8, 14),
            blurRadius: 30,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Color(0x1F2DD4BF),
            offset: Offset(-3, -3),
            blurRadius: 16,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background subtle radiant spotlight behind the right 3D phone
          Positioned(
            right: 30,
            top: -20,
            bottom: -20,
            child: Container(
              width: 390,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2DD4BF).withValues(alpha: 0.22),
                    const Color(0xFF0D9488).withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(left: 28, top: 18, bottom: 18, right: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Content: Badge, Headlines, Subtitle, and Exact Action Buttons
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Capsule Badge: CAMPAIGN STUDIO
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D3230),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFF2DD4BF).withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x262DD4BF),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.campaign_rounded, color: Color(0xFF2DD4BF), size: 14),
                            SizedBox(width: 6),
                            Text(
                              'CAMPAIGN STUDIO',
                              style: TextStyle(
                                color: Color(0xFF2DD4BF),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Headline with glowing neon green "More Orders" matching reference image
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                          children: [
                            TextSpan(text: 'Engage Your Customers\nDeliver '),
                            TextSpan(
                              text: 'More Orders',
                              style: TextStyle(
                                color: Color(0xFF12E47E),
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: Color(0x6612E47E),
                                    blurRadius: 16,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle description
                      const Text(
                        'Create and send WhatsApp campaigns, offers, and updates in minutes.\nUse ready templates or create your own to drive more sales.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFFB5C9CD),
                          height: 1.45,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Action Buttons: + Create New Campaigns, Auto Campaigns, and Audience Groups (Fully visible, beautifully spaced)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // + Create New Campaigns (Glowing vibrant orange-coral gradient as in reference image)
                          InkWell(
                            onTap: widget.onCreateCampaign,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              height: 35,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF5722),
                                    Color(0xFFFF7A00),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x99FF5722),
                                    blurRadius: 16,
                                    spreadRadius: 1,
                                    offset: Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 5,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, color: Colors.white, size: 16),
                                  SizedBox(width: 5),
                                  Text(
                                    'Create New Campaigns',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Auto Campaigns Button (Dark Translucent Glass as in reference image)
                          InkWell(
                            onTap: widget.onCreateAutoCampaign,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              height: 35,
                              padding: const EdgeInsets.symmetric(horizontal: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F3134).withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1.2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.settings_outlined, color: Colors.white, size: 14),
                                  SizedBox(width: 5),
                                  Text(
                                    'Auto Campaigns',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Audience Groups Button (Matching Neumorphic Glass - Fully visible!)
                          InkWell(
                            onTap: widget.onCreateGroup,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              height: 35,
                              padding: const EdgeInsets.symmetric(horizontal: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F3134).withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1.2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.groups_rounded, color: Colors.white, size: 14),
                                  SizedBox(width: 5),
                                  Text(
                                    'Audience Groups',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5,
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
                    height: 255,
                    child: Transform.scale(
                      scale: 1.15,
                      alignment: Alignment.centerRight,
                      child: Image.asset(
                        'assets/images/campaign_hero_phone_3d.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.centerRight,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (ctx, error, stackTrace) => _buildFallbackHeroPhoneMockup(),
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
                subLabel: 'Build your campaigns',
                icon: Icons.near_me_rounded,
                iconColor: const Color(0xFFEA580C),
                iconBg: const Color(0xFFFFF7ED),
                onTap: () => _onMainTabChanged('Drafts'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildStatTile(
                count: '${_stats.approvedCount}',
                label: 'Approved',
                subLabel: 'Ready to send',
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF10B981),
                iconBg: const Color(0xFFECFDF5),
                onTap: () => _onMainTabChanged('Approved'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildStatTile(
                count: '${_stats.scheduledCount}',
                label: 'Scheduled',
                subLabel: 'Next in queue',
                icon: Icons.access_time_rounded,
                iconColor: const Color(0xFF3B82F6),
                iconBg: const Color(0xFFEFF6FF),
                onTap: () => _onMainTabChanged('Scheduled'),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildStatTile(
                count: '${_stats.pendingCount}',
                label: 'Pending',
                subLabel: 'Awaiting approval',
                icon: Icons.send_rounded,
                iconColor: const Color(0xFFA855F7),
                iconBg: const Color(0xFFFAF5FF),
                onTap: () => _onMainTabChanged('Pending'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Wallet Balance Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                offset: Offset(0, 4),
                blurRadius: 14,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFEA580C), size: 22),
              ),
              const SizedBox(width: 14),
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
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              // Top Up button in peach/cream with orange text matching reference image
              InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCEAE1),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFFFD4C2), width: 1),
                  ),
                  child: const Center(
                    child: Text(
                      'Top Up',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ),
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
    required String subLabel,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              offset: Offset(0, 4),
              blurRadius: 14,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 21),
            ),
            const SizedBox(width: 12),
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
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subLabel,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2. MAIN STATUS FILTER PILL BAR (NEUMORPHIC RECESSED TRACK)
  // =========================================================================

  Widget _buildMainFilterNavBar() {
    final tabs = [
      {'label': 'Explore Campaigns', 'icon': Icons.folder_open_rounded, 'color': const Color(0xFFFF5722), 'count': _getCountForTab('Explore Campaigns', _stats.totalCampaigns)},
      {'label': 'Drafts', 'icon': Icons.description_outlined, 'color': const Color(0xFF64748B), 'count': _getCountForTab('Drafts', _stats.draftCount)},
      {'label': 'Pending', 'icon': Icons.access_time_rounded, 'color': const Color(0xFF10B981), 'count': _getCountForTab('Pending', _stats.pendingCount)},
      {'label': 'Approved', 'icon': Icons.check_circle_outline_rounded, 'color': const Color(0xFF10B981), 'count': _getCountForTab('Approved', _stats.approvedCount)},
      {'label': 'Scheduled', 'icon': Icons.calendar_today_outlined, 'color': const Color(0xFF3B82F6), 'count': _getCountForTab('Scheduled', _stats.scheduledCount)},
      {'label': 'Action Rejected', 'icon': Icons.warning_amber_rounded, 'color': const Color(0xFFEF4444), 'count': _getCountForTab('Action Rejected', _stats.rejectedCount)},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            offset: Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 850;

          final tabWidgets = tabs.map((tab) {
            final isSelected = _selectedMainTab == tab['label'];
            final tabColor = tab['color'] as Color;
            final count = tab['count'] as int;

            final item = InkWell(
              onTap: () => _onMainTabChanged(tab['label'] as String),
              borderRadius: BorderRadius.circular(22),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: isSelected
                    ? BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF073437),
                            Color(0xFF0C464C),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF2DD4BF).withValues(alpha: 0.85),
                          width: 1.4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x38073437),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      )
                    : BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFCBD5E1),
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x080F172A),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: isWide ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 15,
                      color: isSelected ? const Color(0xFF2DD4BF) : tabColor,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        tab['label'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (count > 0 || isSelected) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2DD4BF).withValues(alpha: 0.22)
                              : tabColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2DD4BF).withValues(alpha: 0.5)
                                : tabColor.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? const Color(0xFF2DD4BF) : tabColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );

            if (isWide) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: item,
                ),
              );
            } else {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: item,
              );
            }
          }).toList();

          if (isWide) {
            return Row(children: tabWidgets);
          } else {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: tabWidgets),
            );
          }
        },
      ),
    );
  }

  // =========================================================================
  // 3. SUB-CATEGORY FILTER PILLS & SEARCH INPUT ROW (NEUMORPHIC)
  // =========================================================================

  Widget _buildCategoryFilterRow() {
    final defaultCategories = [
      {'label': 'All', 'icon': Icons.grid_view_rounded},
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

    final displayList = _categories.isNotEmpty
        ? _categories.map((c) => {
              'label': c['label']?.toString() ?? 'Category',
              'icon': _getCategoryIcon(c['icon']?.toString()),
            }).toList()
        : defaultCategories;

    return Row(
      children: [
        // Scrolling Category Pills
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: displayList.map((cat) {
                final label = cat['label'] as String;
                final isSelected = _selectedCategory.toLowerCase() == label.toLowerCase();
                final icon = cat['icon'] as IconData;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _onCategoryChanged(label),
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: isSelected
                          ? BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF073437),
                                  Color(0xFF0C464C),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF2DD4BF).withValues(alpha: 0.8),
                                width: 1.3,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x38073437),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            )
                          : BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x060F172A),
                                  offset: Offset(0, 2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 14,
                            color: isSelected ? const Color(0xFF2DD4BF) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF334155),
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

        // Search Field on Right (White Rounded Pill matching reference image)
        Container(
          width: 220,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                offset: Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
          child: TextField(
            onChanged: (val) {
              setState(() {
                _templateSearchQuery = val;
                _applyFilters();
              });
            },
            style: const TextStyle(fontSize: 12.5, color: NeumorphicTheme.textDark),
            decoration: const InputDecoration(
              hintText: 'Search templates...',
              hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              prefixIcon: Icon(Icons.search_rounded, size: 17, color: Color(0xFF94A3B8)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String? iconCode) {
    switch (iconCode?.toLowerCase()) {
      case 'grid':
        return Icons.grid_view_rounded;
      case 'megaphone':
        return Icons.campaign_outlined;
      case 'gift':
        return Icons.card_giftcard_rounded;
      case 'tag':
        return Icons.local_offer_outlined;
      case 'percent':
        return Icons.percent_rounded;
      case 'layers':
      case 'box':
        return Icons.fastfood_outlined;
      case 'copy':
        return Icons.layers_outlined;
      case 'cloche':
        return Icons.restaurant_menu_rounded;
      case 'party':
        return Icons.celebration_outlined;
      case 'refresh':
        return Icons.replay_rounded;
      default:
        return Icons.label_outline_rounded;
    }
  }

  // =========================================================================
  // 4. CAMPAIGN TEMPLATES SECTION (NEUMORPHIC CARDS & TOP HEADER BUTTONS)
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: NeumorphicTheme.textDark),
                ),
                SizedBox(height: 3),
                Text(
                  'Use ready to send templates or create your own campaign',
                  style: TextStyle(fontSize: 12.5, color: NeumorphicTheme.textMuted),
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
      width: 220,
      margin: const EdgeInsets.only(right: 16, bottom: 6),
      decoration: NeumorphicTheme.raisedDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food Image with Overlaid Chips
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
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
                                color: NeumorphicTheme.textDark,
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
                  style: const TextStyle(fontSize: 11, color: NeumorphicTheme.textMuted, height: 1.35),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),

                // Use Template Button in Top Header Color
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: InkWell(
                    onTap: () {
                      if (widget.onUseTemplate != null) {
                        widget.onUseTemplate!(tpl);
                      } else {
                        widget.onCreateCampaign();
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF5722),
                            Color(0xFFFF7A00),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40FF5722),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Use Template', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.white),
                        ],
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
  // 5. RECENT CAMPAIGNS SECTION (DYNAMIC TABLE & REAL DATA)
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: NeumorphicTheme.textDark),
                ),
                SizedBox(height: 3),
                Text(
                  'Track and manage your campaigns',
                  style: TextStyle(fontSize: 12.5, color: NeumorphicTheme.textMuted),
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

        // Neumorphic Table Card
        Container(
          decoration: NeumorphicTheme.raisedDecoration(radius: 18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  color: const Color(0xFFF1F5F9),
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

                // Table Rows (Loaded directly from real MongoDB API)
                if (_campaigns.isEmpty)
                  _buildEmptyCampaignsState()
                else
                  ..._campaigns.map((c) => _buildCampaignRow(c)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCampaignsState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.campaign_outlined, size: 28, color: NeumorphicTheme.headerPrimary),
            ),
            const SizedBox(height: 12),
            const Text(
              'No campaigns found in this view',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: NeumorphicTheme.textDark),
            ),
            const SizedBox(height: 4),
            const Text(
              'Create a campaign or select a verified template above to start engaging customers.',
              style: TextStyle(fontSize: 12, color: NeumorphicTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignRow(CampaignModel c) {
    // Compute dynamic delivery percentage
    final deliveryPct = c.stats.messagesSent > 0
        ? (c.stats.delivered / c.stats.messagesSent * 100).clamp(0.0, 100.0)
        : c.stats.deliveryRate;

    // Type badge colors
    Color typeBg = const Color(0xFFEFF6FF);
    Color typeText = const Color(0xFF2563EB);
    if (c.type.toLowerCase() == 'promotional') {
      typeBg = const Color(0xFFDCFCE7);
      typeText = const Color(0xFF15803D);
    } else if (c.type.toLowerCase() == 'marketing') {
      typeBg = const Color(0xFFEFF6FF);
      typeText = const Color(0xFF1D4ED8);
    }

    // Status badge colors
    Color statusBg = const Color(0xFFF1F5F9);
    Color statusText = const Color(0xFF64748B);
    String statusLabel = c.status.toUpperCase();

    switch (c.status.toLowerCase()) {
      case 'completed':
        statusBg = const Color(0xFFDCFCE7);
        statusText = const Color(0xFF15803D);
        statusLabel = 'Completed';
        break;
      case 'running':
      case 'pending':
        statusBg = const Color(0xFFFEF3C7);
        statusText = const Color(0xFFD97706);
        statusLabel = 'Pending';
        break;
      case 'scheduled':
        statusBg = const Color(0xFFDBEAFE);
        statusText = const Color(0xFF2563EB);
        statusLabel = 'Scheduled';
        break;
      case 'draft':
        statusBg = const Color(0xFFF1F5F9);
        statusText = const Color(0xFF64748B);
        statusLabel = 'Draft';
        break;
      case 'cancelled':
      case 'failed':
        statusBg = const Color(0xFFFEE2E2);
        statusText = const Color(0xFFDC2626);
        statusLabel = 'Action Rejected';
        break;
    }

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
                              color: const Color(0xFFEFF6FF),
                              child: const Icon(Icons.campaign_rounded, color: NeumorphicTheme.headerPrimary, size: 18),
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
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: NeumorphicTheme.textDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          c.template.name.isNotEmpty ? c.template.name : (c.template.body.isNotEmpty ? c.template.body : 'Standard message'),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                    color: typeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    c.type.isNotEmpty ? (c.type[0].toUpperCase() + c.type.substring(1)) : 'General',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: typeText),
                  ),
                ),
              ),
            ),

            // Audience
            Expanded(
              flex: 2,
              child: Text(
                '${c.audience.groupName.isNotEmpty ? c.audience.groupName : 'All Customers'}\n(${c.audience.recipientCount > 0 ? c.audience.recipientCount : c.stats.totalRecipients} customers)',
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
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
                    decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                    child: const Center(
                      child: Icon(Icons.chat_bubble, size: 12, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('WhatsApp', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: NeumorphicTheme.textDark)),
                ],
              ),
            ),

            // Scheduled Date
            Expanded(
              flex: 2,
              child: Text(
                c.scheduledAt != null
                    ? '${c.scheduledAt!.day} ${_monthName(c.scheduledAt!.month)} ${c.scheduledAt!.year}\n${_formatTime(c.scheduledAt!)}'
                    : '25 Oct 2026\n11:00 AM',
                style: const TextStyle(fontSize: 12, color: NeumorphicTheme.textMuted, height: 1.3),
              ),
            ),

            // Sent
            Expanded(
              flex: 1,
              child: Text(
                '${c.stats.messagesSent}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: NeumorphicTheme.textDark),
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
                          '${deliveryPct.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (deliveryPct / 100).clamp(0.0, 1.0),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusText),
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
      ),
    );
  }

  static String _monthName(int m) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (m >= 1 && m <= 12) ? months[m - 1] : '';
  }

  static String _formatTime(DateTime d) {
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute $ampm';
  }

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Color(0xFF64748B),
  );
}
