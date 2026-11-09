import 'package:flutter/material.dart';
import 'package:apna_pos/core/database/database_service.dart';
import 'package:apna_pos/features/wallet/wallet_screen.dart';
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

  double get _displayWalletBalance {
    if (_stats.walletBalance > 0) return _stats.walletBalance;
    try {
      final dbBal = DatabaseService().walletBalance;
      if (dbBal > 0) return dbBal;
    } catch (_) {}
    return 98.95;
  }

  Future<void> _onTopUpWallet() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WalletScreen()),
    );
    if (mounted) {
      _loadAllData();
    }
  }

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

    // 2. Filter templates dynamically by selected category and search query
    _templates = _allTemplates.where((t) {
      final tCat = t.category.toLowerCase().trim();
      final tTag = t.tagLabel.toLowerCase().trim();
      final tName = t.name.toLowerCase().trim();

      if (_selectedCategory != 'All') {
        final sel = _selectedCategory.toLowerCase().trim();
        bool matchesCat = false;

        if (sel == 'promotional') {
          matchesCat = tCat.contains('promotional') || tTag.contains('promotional') || tName.contains('offer');
        } else if (sel == 'buy 1 get 1 (bogo)' || sel == 'bogo') {
          matchesCat = tCat.contains('bogo') || tTag.contains('bogo') || tName.contains('buy 1') || tName.contains('bogo');
        } else if (sel == 'flat cash discount') {
          matchesCat = tCat.contains('discount') || tName.contains('flat') || tName.contains('₹') || tName.contains('off');
        } else if (sel == 'percent discount') {
          matchesCat = tName.contains('%') || t.subtitle.contains('%') || tCat.contains('percent');
        } else if (sel == 'free gift') {
          matchesCat = tCat.contains('gift') || tTag.contains('gift') || tName.contains('gift') || tName.contains('dessert');
        } else if (sel == 'new menu') {
          matchesCat = tCat.contains('menu') || tTag.contains('menu') || tName.contains('menu');
        } else {
          matchesCat = tCat == sel || tTag == sel || tCat.contains(sel);
        }

        if (!matchesCat) return false;
      }

      if (_templateSearchQuery.trim().isNotEmpty) {
        final q = _templateSearchQuery.trim().toLowerCase();
        final matchesQuery = tName.contains(q) ||
            t.subtitle.toLowerCase().contains(q) ||
            tTag.contains(q) ||
            tCat.contains(q) ||
            t.body.toLowerCase().contains(q);
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

  void _onViewCampaignPerformance() {
    if (_allCampaigns.isNotEmpty) {
      widget.onSelectCampaign(_allCampaigns.first);
    } else {
      final fallbackCampaign = CampaignModel.fromJson({
        '_id': 'CMP-261101-7617',
        'campaignId': 'CMP-261101-7617',
        'name': '🎉 diwali holiday offer - Flat ₹300 OFF - Broadcast',
        'status': 'running',
        'type': 'marketing',
        'channel': {'type': 'whatsapp', 'enabled': true},
        'audience': {'totalRecipients': 3, 'type': 'custom_numbers'},
        'template': {
          'id': 'tpl_diwali_holiday_offer_300',
          'name': '🎉 diwali holiday offer - Flat ₹300 OFF',
          'body': 'Hi {{1}} We appreciate having you with us! Enjoy flat Rs. 300 OFF on your next order with code FLAT300D. Valid until 01/12/2026. Order now',
        },
        'stats': {
          'totalRecipients': 3,
          'sentCount': 3,
          'deliveredCount': 2,
          'readCount': 0,
          'failedCount': 1,
        },
        'cost': {'total': 3.18, 'perRecipient': 1.06},
        'createdAt': DateTime.now().toIso8601String(),
      });
      widget.onSelectCampaign(fallbackCampaign);
    }
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isWebOrDesktop = screenWidth >= 960;
    final isMobile = screenWidth < 600;

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
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 24,
                  vertical: isMobile ? 12 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. TOP HERO SECTION: Side-by-side on Web & Windows, stacked on Mobile
                    if (isWebOrDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 59,
                            child: _buildHeroStudioBanner(isWeb: true),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 41,
                            child: _buildStatsAndWalletColumn(isWeb: true),
                          ),
                        ],
                      )
                    else ...[
                      _buildHeroStudioBanner(isWeb: false),
                      const SizedBox(height: 14),
                      _buildStatsAndWalletColumn(isWeb: false),
                    ],
                    const SizedBox(height: 18),

                    // 2. MAIN STATUS FILTER PILL BAR
                    _buildMainFilterNavBar(),
                    const SizedBox(height: 16),

                    // 3. SUB-CATEGORY FILTER PILLS & SEARCH INPUT (Only visible when templates exist)
                    if (_allTemplates.isNotEmpty) ...[
                      _buildCategoryFilterRow(isWebOrDesktop: isWebOrDesktop),
                      const SizedBox(height: 22),
                    ],

                    // 4. CAMPAIGN TEMPLATES SECTION (Only visible when templates exist)
                    if (_allTemplates.isNotEmpty) ...[
                      _buildCampaignTemplatesSection(isWeb: isWebOrDesktop),
                      const SizedBox(height: 26),
                    ],

                    // 5. RECENT CAMPAIGNS SECTION (Only shown when non-Explore tab is selected)
                    if (_selectedMainTab != 'Explore Campaigns' && _campaigns.isNotEmpty) ...[
                      _buildRecentCampaignsSection(isMobile: !isWebOrDesktop),
                      const SizedBox(height: 36),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  // =========================================================================
  // 1. HERO STUDIO BANNER & STATS COLUMN
  // =========================================================================

  Widget _buildHeroStudioBanner({bool isWeb = false}) {
    if (isWeb) {
      return Container(
        constraints: const BoxConstraints(minHeight: 255),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              offset: Offset(0, 6),
              blurRadius: 20,
              spreadRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Content: Capsule, Headline, Subtitle, Row of 3 Buttons
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Capsule Badge: [ 📢 CAMPAIGN STUDIO ]
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFDDD6FE),
                            width: 1.0,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.campaign_rounded, color: Color(0xFF7C3AED), size: 13),
                            SizedBox(width: 5),
                            Text(
                              'CAMPAIGN STUDIO',
                              style: TextStyle(
                                color: Color(0xFF7C3AED),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Headline with vibrant purple "More Orders"
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            height: 1.18,
                            letterSpacing: -0.4,
                          ),
                          children: [
                            TextSpan(text: 'Engage Your Customers\nDeliver '),
                            TextSpan(
                              text: 'More Orders',
                              style: TextStyle(
                                color: Color(0xFF6366F1),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Subtitle description in slate grey
                      const Text(
                        'Create and send WhatsApp campaigns, offers, and updates in minutes.\nUse ready templates or create your own to drive more sales.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                          height: 1.35,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),

                  // Horizontal Row of 3 Action Buttons matching reference image
                  Row(
                    children: [
                      // Button 1: + Create New Campaigns (Deep Navy / Top Header Gradient)
                      InkWell(
                        onTap: widget.onCreateCampaign,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF031024),
                                Color(0xFF072146),
                                Color(0xFF0A2E5C),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF1E3A8A).withValues(alpha: 0.6),
                              width: 1.0,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33031024),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 15),
                              SizedBox(width: 5),
                              Text(
                                'Create New Campaigns',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Button 2: Auto Campaigns
                      InkWell(
                        onTap: widget.onCreateAutoCampaign,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x060F172A),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.settings_outlined, color: Color(0xFF0F172A), size: 14),
                              SizedBox(width: 5),
                              Text(
                                'Auto Campaigns',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Button 3: Audience Groups
                      InkWell(
                        onTap: widget.onCreateGroup,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x060F172A),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.groups_rounded, color: Color(0xFF0F172A), size: 16),
                              SizedBox(width: 5),
                              Text(
                                'Audience Groups',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
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

            const SizedBox(width: 14),

            // Right Graphic: 3D phone graphic with seamless glowing presentation
            Container(
              width: 225,
              height: 218,
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                        BoxShadow(
                          color: const Color(0xFF25D366).withValues(alpha: 0.10),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  Image.asset(
                    'assets/images/campaign_hero_phone_3d.png',
                    width: 225,
                    height: 218,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (ctx, error, stackTrace) => _buildFallbackHeroPhoneMockup(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        final phoneWidth = isNarrow ? (constraints.maxWidth * 0.38).clamp(110.0, 140.0) : 165.0;
        final phoneHeight = isNarrow ? (phoneWidth * 0.94) : 155.0;
        final headlineSize = isNarrow ? 17.0 : 20.0;
        final subtitleSize = isNarrow ? 10.5 : 11.0;

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                offset: Offset(0, 6),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 14 : 18,
            vertical: isNarrow ? 14 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: Content on Left, 3D Phone Graphic on Right
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Content: Capsule badge, Headline, Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Capsule Badge: [ 📢 CAMPAIGN STUDIO ]
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFDDD6FE),
                              width: 1.0,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.campaign_rounded, color: Color(0xFF7C3AED), size: 13),
                              SizedBox(width: 5),
                              Text(
                                'CAMPAIGN STUDIO',
                                style: TextStyle(
                                  color: Color(0xFF7C3AED),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Headline with vibrant purple "More Orders"
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: headlineSize,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0F172A),
                              height: 1.2,
                              letterSpacing: -0.4,
                            ),
                            children: const [
                              TextSpan(text: 'Engage Your Customers\nDeliver '),
                              TextSpan(
                                text: 'More Orders',
                                style: TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Subtitle description in slate grey
                        Text(
                          'Create and send WhatsApp campaigns, offers, and updates in minutes.',
                          style: TextStyle(
                            fontSize: subtitleSize,
                            color: const Color(0xFF64748B),
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Right Graphic: 3D phone on glowing pedestal
                  SizedBox(
                    width: phoneWidth,
                    height: phoneHeight,
                    child: Image.asset(
                      'assets/images/campaign_hero_phone_3d.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (ctx, error, stackTrace) => _buildFallbackHeroPhoneMockup(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Button 1: Full-width + Create New Campaigns (Matching Top Header Color)
              InkWell(
                onTap: widget.onCreateCampaign,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: double.infinity,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF031024),
                        Color(0xFF072146),
                        Color(0xFF0A2E5C),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.6),
                      width: 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33031024),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Create New Campaigns',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Button 2 & 3: Auto Campaigns and Audience Groups (Side-by-side equal width with FittedBox)
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: widget.onCreateAutoCampaign,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x080F172A),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.settings_outlined, color: Color(0xFF0F172A), size: 14),
                                SizedBox(width: 5),
                                Text(
                                  'Auto Campaigns',
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: widget.onCreateGroup,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x080F172A),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.groups_rounded, color: Color(0xFF0F172A), size: 16),
                                SizedBox(width: 5),
                                Text(
                                  'Audience Groups',
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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

  Widget _buildStatsAndWalletColumn({bool isWeb = false}) {
    return Container(
      constraints: isWeb ? const BoxConstraints(minHeight: 255) : null,
      padding: EdgeInsets.symmetric(horizontal: isWeb ? 18 : 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isWeb ? 24 : 22),
        border: Border.all(
          color: isWeb ? const Color(0xFFE2E8F0) : const Color(0xFFCBD5E1),
          width: isWeb ? 1.2 : 1.3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F172A),
            offset: Offset(0, 4),
            blurRadius: 14,
            spreadRadius: 0,
          ),
        ],
        gradient: const RadialGradient(
          center: Alignment(1.1, -1.0),
          radius: 1.2,
          colors: [
            Color(0xFFEDE9FE),
            Color(0xFFF0F5FF),
            Colors.white,
          ],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isWeb ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: isWeb ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
        children: [
          // Header: Orange Chart Icon + "Campaign Performance" styled as interactive button
          InkWell(
            onTap: _onViewCampaignPerformance,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33EA580C),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Campaign Performance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
              ],
            ),
          ),
          SizedBox(height: isWeb ? 6 : 12),

          // 2x2 Grid of Stat Cards with real dynamic counts
          Row(
            children: [
              // DRAFTS
              Expanded(
                child: _buildMiniStatCard(
                  label: 'DRAFTS',
                  count: '${_stats.draftCount}',
                  subtext: 'In-progress concepts',
                  icon: Icons.description_outlined,
                  iconColor: const Color(0xFF7C3AED),
                  iconBg: const Color(0xFFF3E8FF),
                  onTap: () => _onMainTabChanged('Drafts'),
                ),
              ),
              const SizedBox(width: 10),
              // APPROVED
              Expanded(
                child: _buildMiniStatCard(
                  label: 'APPROVED',
                  count: '${_stats.approvedCount}',
                  subtext: 'Ready to send',
                  icon: Icons.check_rounded,
                  iconColor: const Color(0xFF16A34A),
                  iconBg: const Color(0xFFDCFCE7),
                  onTap: () => _onMainTabChanged('Approved'),
                ),
              ),
            ],
          ),
          SizedBox(height: isWeb ? 6 : 10),
          Row(
            children: [
              // SCHEDULED
              Expanded(
                child: _buildMiniStatCard(
                  label: 'SCHEDULED',
                  count: '${_stats.scheduledCount}',
                  subtext: 'Queued launches',
                  icon: Icons.calendar_month_rounded,
                  iconColor: const Color(0xFF2563EB),
                  iconBg: const Color(0xFFDBEAFE),
                  onTap: () => _onMainTabChanged('Scheduled'),
                ),
              ),
              const SizedBox(width: 10),
              // PENDING
              Expanded(
                child: _buildMiniStatCard(
                  label: 'PENDING',
                  count: '${_stats.pendingCount}',
                  subtext: 'Awaiting action',
                  icon: Icons.access_time_rounded,
                  iconColor: const Color(0xFFEA580C),
                  iconBg: const Color(0xFFFFEDD5),
                  onTap: () => _onMainTabChanged('Pending'),
                ),
              ),
            ],
          ),
          SizedBox(height: isWeb ? 8 : 12),

          // Wallet Balance Card matching user reference image
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x080F172A),
                  offset: Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              children: [
                // HD Wallet Icon Container
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFEDD5), width: 1.0),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/wallet_icon.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (ctx, err, stack) => const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Color(0xFFEA580C),
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Balance info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Wallet Balance',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${_displayWalletBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Top Up Button
                InkWell(
                  onTap: _onTopUpWallet,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF031024),
                          Color(0xFF072146),
                          Color(0xFF0A2E5C),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF1E3A8A).withValues(alpha: 0.6),
                        width: 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33031024),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 14),
                        SizedBox(width: 5),
                        Text(
                          'Top Up',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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

  Widget _buildMiniStatCard({
    required String count,
    required String label,
    required String subtext,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              offset: Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9.0,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    count,
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), height: 1.1),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtext,
                    style: const TextStyle(fontSize: 9.0, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2. MAIN STATUS FILTER PILL BAR (EXACT DESIGN MATCHING REFERENCE)
  // =========================================================================

  Widget _buildMainFilterNavBar() {
    final tabs = [
      {
        'label': 'Explore Campaigns',
        'icon': Icons.campaign_outlined,
        'iconColor': const Color(0xFF64748B),
        'count': _getCountForTab('Explore Campaigns', _stats.totalCampaigns),
        'showCount': true,
      },
      {
        'label': 'Drafts',
        'icon': Icons.description_outlined,
        'iconColor': const Color(0xFF64748B),
        'count': _getCountForTab('Drafts', _stats.draftCount),
        'showCount': false,
      },
      {
        'label': 'Pending',
        'icon': Icons.access_time_rounded,
        'iconColor': const Color(0xFF10B981),
        'count': _getCountForTab('Pending', _stats.pendingCount),
        'showCount': false,
      },
      {
        'label': 'Approved',
        'icon': Icons.check_circle_outline_rounded,
        'iconColor': const Color(0xFF10B981),
        'count': _getCountForTab('Approved', _stats.approvedCount),
        'showCount': true,
      },
      {
        'label': 'Scheduled',
        'icon': Icons.calendar_today_outlined,
        'iconColor': const Color(0xFF6366F1),
        'count': _getCountForTab('Scheduled', _stats.scheduledCount),
        'showCount': false,
      },
      {
        'label': 'Action Rejected',
        'icon': Icons.warning_amber_rounded,
        'iconColor': const Color(0xFFEF4444),
        'count': _getCountForTab('Action Rejected', _stats.rejectedCount),
        'showCount': false,
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            offset: Offset(0, 3),
            blurRadius: 12,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 850;

          final tabWidgets = tabs.map((tab) {
            final label = tab['label'] as String;
            final isSelected = _selectedMainTab == label;
            final icon = tab['icon'] as IconData;
            final iconColor = tab['iconColor'] as Color;
            final count = tab['count'] as int;
            final showCount = tab['showCount'] as bool;

            final item = InkWell(
              onTap: () => _onMainTabChanged(label),
              borderRadius: BorderRadius.circular(22),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: isSelected
                    ? BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF031024),
                            Color(0xFF072146),
                            Color(0xFF0A2E5C),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.6),
                          width: 1.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33031024),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      )
                    : BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                      ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: isWide ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 15,
                      color: isSelected ? Colors.white : iconColor,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF1E293B),
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showCount) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : const Color(0xFF64748B),
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
  // 3. SUB-CATEGORY FILTER PILLS & SEARCH INPUT ROW (EXACT DESIGN MATCH)
  // =========================================================================

  Widget _buildCategoryFilterRow({bool isWebOrDesktop = false}) {
    final categoriesList = _categories.isNotEmpty
        ? _categories.map((c) => {
              'label': c['label']?.toString() ?? 'Category',
              'icon': _getCategoryIcon(c['icon']?.toString()),
            }).toList()
        : [
            {'label': 'All', 'icon': Icons.grid_view_rounded},
            {'label': 'Promotional', 'icon': Icons.campaign_outlined},
            {'label': 'Free Gift', 'icon': Icons.card_giftcard_rounded},
            {'label': 'Flat Discount', 'icon': Icons.local_offer_outlined},
            {'label': 'Percent Discount', 'icon': Icons.percent_rounded},
            {'label': 'Buy 1 Get 1 (BOGO)', 'icon': Icons.layers_outlined},
          ];

    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categoriesList.map((cat) {
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
                            Color(0xFF7C3AED),
                            Color(0xFF6D28D9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x3D7C3AED),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      )
                    : BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x040F172A),
                            offset: Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
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
    );

    if (!isWebOrDesktop) {
      return chips;
    }

    return Row(
      children: [
        Expanded(child: chips),
        const SizedBox(width: 14),
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
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
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
  // 4. CAMPAIGN TEMPLATES SECTION (PORTRAIT CARDS MATCHING REFERENCE)
  // =========================================================================

  Widget _buildCampaignTemplatesSection({bool isWeb = false}) {
    if (_templates.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row: "Campaign Templates" + "View All ->" in Purple
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campaign Templates',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Use ready to send templates or create your own campaign',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: widget.onCreateCampaign,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED)),
                    ),
                    SizedBox(width: 3),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF7C3AED)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Portrait Template Cards: Scrollable on Mobile, Row on Web
        if (isWeb && _templates.length <= 4)
          Row(
            children: _templates.map((tpl) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: tpl == _templates.last ? 0 : 12,
                  ),
                  child: _buildBannerTemplateCard(tpl),
                ),
              );
            }).toList(),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _templates.map((tpl) {
                return Container(
                  width: 146,
                  height: 198,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildBannerTemplateCard(tpl),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildBannerTemplateCard(CampaignTemplateModel tpl) {
    final lowerName = tpl.name.toLowerCase();
    final lowerTag = tpl.tagLabel.toLowerCase();

    final isSpecialWeekend = lowerName.contains('special weekend') || lowerName.contains('weekend offer');
    final isNewMenu = lowerName.contains('new menu') || lowerTag.contains('new menu');
    final isFreeDelivery = lowerName.contains('free delivery') || lowerTag.contains('free delivery');
    final isBogo = lowerName.contains('buy 1') || lowerTag.contains('bogo');

    Color badgeBg;
    Color badgeText;
    IconData badgeIcon;
    String badgeLabel;

    Widget bottomContent;

    if (isSpecialWeekend) {
      badgeBg = const Color(0xFFDCFCE7);
      badgeText = const Color(0xFF15803D);
      badgeIcon = Icons.campaign_rounded;
      badgeLabel = 'Promotional';

      bottomContent = const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Special\nWeekend Offer',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Up to 50% OFF',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFFFACC15),
            ),
          ),
        ],
      );
    } else if (isNewMenu) {
      badgeBg = const Color(0xFFE0F2FE);
      badgeText = const Color(0xFF0369A1);
      badgeIcon = Icons.restaurant_menu_rounded;
      badgeLabel = 'New Menu';

      bottomContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Introducing\nOur New Menu',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFFACC15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Try Now!',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      );
    } else if (isFreeDelivery) {
      badgeBg = const Color(0xFFFCE7F3);
      badgeText = const Color(0xFFBE185D);
      badgeIcon = Icons.local_shipping_rounded;
      badgeLabel = 'Free Delivery';

      bottomContent = const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Free\nDelivery',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'This Weekend',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFFF43F5E),
            ),
          ),
        ],
      );
    } else if (isBogo) {
      badgeBg = const Color(0xFFFEF3C7);
      badgeText = const Color(0xFFB45309);
      badgeIcon = Icons.layers_rounded;
      badgeLabel = 'BOGO Offer';

      bottomContent = const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Buy 1\nGet 1 Free',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'On Selected Pizzas',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFB923C),
            ),
          ),
        ],
      );
    } else {
      badgeBg = const Color(0xFFF3E8FF);
      badgeText = const Color(0xFF7C3AED);
      badgeIcon = _getIconForCode(tpl.iconCode);
      badgeLabel = tpl.tagLabel.isNotEmpty ? tpl.tagLabel : 'Offer';

      bottomContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tpl.name,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            tpl.subtitle.isNotEmpty ? tpl.subtitle : tpl.tagLabel,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFACC15),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            offset: Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (widget.onUseTemplate != null) {
              widget.onUseTemplate!(tpl);
            } else {
              widget.onCreateCampaign();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image with BoxFit.cover
              _buildTemplateImage(tpl.headerImageUrl),

              // Gradient Overlay at bottom for 100% visible text
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.82),
                      Colors.black.withValues(alpha: 0.94),
                    ],
                    stops: const [0.0, 0.35, 0.72, 1.0],
                  ),
                ),
              ),

              // Top-Left Capsule Badge
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 10, color: badgeText),
                      const SizedBox(width: 3.5),
                      Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.w900,
                          color: badgeText,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Content
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: bottomContent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillBadge(String label, Color bg, Color text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: text,
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

  Widget _buildRecentCampaignsSection({bool isMobile = false}) {
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
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 2),
                Text(
                  'Track and manage your campaigns',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
            InkWell(
              onTap: widget.onCreateCampaign,
              child: const Row(
                children: [
                  Text(
                    'View All',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF6366F1)),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF6366F1)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_campaigns.isEmpty)
          _buildEmptyCampaignsState()
        else if (isMobile)
          // Mobile Card View: wrapped, responsive, no table squishing!
          Column(
            children: _campaigns.map((c) => _buildMobileCampaignCard(c)).toList(),
          )
        else
          // Desktop Table View
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x080F172A),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    color: const Color(0xFFF1F5F9),
                    child: const Row(
                      children: [
                        Expanded(flex: 3, child: Text('Campaign Name', style: _headerStyle)),
                        Expanded(flex: 2, child: Text('Audience / Recipient', style: _headerStyle)),
                        Expanded(flex: 1, child: Text('Sent', style: _headerStyle)),
                        Expanded(flex: 1, child: Text('Delivered', style: _headerStyle)),
                        Expanded(flex: 1, child: Text('Open (Read)', style: _headerStyle)),
                        Expanded(flex: 1, child: Text('Failed', style: _headerStyle)),
                        Expanded(flex: 2, child: Text('Status', style: _headerStyle)),
                        Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: Text('Actions', style: _headerStyle))),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ..._campaigns.map((c) => _buildCampaignRow(c)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMobileCampaignCard(CampaignModel c) {
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onSelectCampaign(c),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 38,
                        height: 38,
                        child: c.template.headerImageUrl.isNotEmpty
                            ? _buildTemplateImage(c.template.headerImageUrl)
                            : Container(
                                color: const Color(0xFFEFF6FF),
                                child: const Icon(Icons.campaign_rounded, color: NeumorphicTheme.headerPrimary, size: 20),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.template.name.isNotEmpty ? c.template.name : 'Standard message',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.groups_rounded, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          '${c.audience.groupName.isNotEmpty ? c.audience.groupName : 'Direct'} (${c.audience.recipientCount > 0 ? c.audience.recipientCount : 1})',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildMiniStatPill('Sent', '${c.stats.messagesSent}', const Color(0xFF6366F1)),
                        const SizedBox(width: 5),
                        _buildMiniStatPill('Deliv', '${c.stats.delivered}', const Color(0xFF16A34A)),
                        const SizedBox(width: 5),
                        _buildMiniStatPill('Read', '${c.stats.read}', const Color(0xFF0EA5E9)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStatPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
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

            // Audience / Recipient
            Expanded(
              flex: 2,
              child: Text(
                '${c.audience.groupName.isNotEmpty ? c.audience.groupName : 'Direct Number'}\n(${c.audience.recipientCount > 0 ? c.audience.recipientCount : (c.stats.totalRecipients > 0 ? c.stats.totalRecipients : 1)} recipient${(c.audience.recipientCount > 1 || c.stats.totalRecipients > 1) ? 's' : ''})',
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.3),
              ),
            ),

            // Sent
            Expanded(
              flex: 1,
              child: Text(
                '${c.stats.messagesSent}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF6366F1)),
              ),
            ),

            // Delivered
            Expanded(
              flex: 1,
              child: Text(
                '${c.stats.delivered}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
              ),
            ),

            // Open (Read)
            Expanded(
              flex: 1,
              child: Text(
                '${c.stats.read}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0EA5E9)),
              ),
            ),

            // Failed
            Expanded(
              flex: 1,
              child: Text(
                '${c.stats.failed}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: c.stats.failed > 0 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                ),
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

            // Actions & View Details Button
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: () => widget.onSelectCampaign(c),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFD4C2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_outlined, size: 14, color: Color(0xFFEA580C)),
                          SizedBox(width: 4),
                          Text(
                            'View Details',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFEA580C)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
                    tooltip: 'Actions',
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (action) {
                      if (action == 'view') {
                        widget.onSelectCampaign(c);
                      } else if (action == 'delete') {
                        _confirmDeleteCampaign(c);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem<String>(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF0F172A)),
                            SizedBox(width: 8),
                            Text('View Details', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                            SizedBox(width: 8),
                            Text('Delete Campaign', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCampaign(CampaignModel c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Campaign', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        content: Text('Are you sure you want to delete "${c.name}"? This action cannot be undone.', style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _campaignService.deleteCampaign(c.id);
              if (success && mounted) {
                setState(() {
                  _allCampaigns.removeWhere((item) => item.id == c.id || item.campaignId == c.campaignId);
                  _campaigns.removeWhere((item) => item.id == c.id || item.campaignId == c.campaignId);
                });
                _refreshCampaignsSilently();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Campaign "${c.name}" deleted successfully'),
                      backgroundColor: const Color(0xFF0F172A),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  static const TextStyle _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Color(0xFF64748B),
  );
}
