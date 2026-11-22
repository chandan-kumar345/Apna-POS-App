import 'package:flutter/material.dart';
import 'package:apna_pos/features/wallet/wallet_screen.dart';
import '../../models/campaign_models.dart';
import '../../services/campaign_service.dart';
import '../widgets/campaign_studio_layout.dart';

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
  final VoidCallback? onViewCustomers;

  const CampaignDashboardView({
    super.key,
    required this.onCreateCampaign,
    required this.onCreateGroup,
    required this.onCreateAutoCampaign,
    required this.onSelectCampaign,
    this.onUseTemplate,
    this.onViewCustomers,
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

  int _loadGeneration = 0;
  int _campaignDataGeneration = 0;

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
    final generation = ++_loadGeneration;
    final campaignsGeneration = ++_campaignDataGeneration;
    if (isInitial && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final statsFuture = _campaignService.fetchDashboardStats();
      final campaignsFuture = _campaignService.fetchCampaigns();
      final templatesFuture = _campaignService.fetchTemplates(
        channel: 'whatsapp',
      );
      final categoriesFuture = _campaignService.fetchCategories();

      final results = await Future.wait([
        statsFuture,
        campaignsFuture,
        templatesFuture,
        categoriesFuture,
      ]);

      if (mounted && generation == _loadGeneration) {
        setState(() {
          _stats = results[0] as CampaignStatsModel;
          if (campaignsGeneration == _campaignDataGeneration) {
            _allCampaigns = results[1] as List<CampaignModel>;
          }
          _allTemplates = results[2] as List<CampaignTemplateModel>;
          _categories = results[3] as List<Map<String, dynamic>>;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[CampaignDashboardView] _loadAllData error: $e');
      if (mounted && generation == _loadGeneration) {
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
          matchesCat =
              tCat.contains('promotional') ||
              tTag.contains('promotional') ||
              tName.contains('offer');
        } else if (sel == 'buy 1 get 1 (bogo)' || sel == 'bogo') {
          matchesCat =
              tCat.contains('bogo') ||
              tTag.contains('bogo') ||
              tName.contains('buy 1') ||
              tName.contains('bogo');
        } else if (sel == 'flat cash discount') {
          matchesCat =
              tCat.contains('discount') ||
              tName.contains('flat') ||
              tName.contains('₹') ||
              tName.contains('off');
        } else if (sel == 'percent discount') {
          matchesCat =
              tName.contains('%') ||
              t.subtitle.contains('%') ||
              tCat.contains('percent');
        } else if (sel == 'free gift') {
          matchesCat =
              tCat.contains('gift') ||
              tTag.contains('gift') ||
              tName.contains('gift') ||
              tName.contains('dessert');
        } else if (sel == 'new menu') {
          matchesCat =
              tCat.contains('menu') ||
              tTag.contains('menu') ||
              tName.contains('menu');
        } else {
          matchesCat = tCat == sel || tTag == sel || tCat.contains(sel);
        }

        if (!matchesCat) return false;
      }

      if (_templateSearchQuery.trim().isNotEmpty) {
        final q = _templateSearchQuery.trim().toLowerCase();
        final matchesQuery =
            tName.contains(q) ||
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
    final generation = ++_campaignDataGeneration;
    final status = _mapTabToStatus(_selectedMainTab);
    final fresh = await _campaignService.fetchCampaigns(status: status);
    if (!mounted || generation != _campaignDataGeneration) return;
    setState(() {
      if (status == null) {
        _allCampaigns = fresh;
      } else {
        _allCampaigns.removeWhere((campaign) {
          final value = campaign.status.toLowerCase();
          if (status == 'running')
            return value == 'running' || value == 'pending';
          if (status == 'completed')
            return value == 'completed' || value == 'approved';
          if (status == 'cancelled')
            return value == 'cancelled' || value == 'rejected';
          return value == status;
        });
        _allCampaigns.addAll(
          fresh.where(
            (campaign) =>
                !_allCampaigns.any((existing) => existing.id == campaign.id),
          ),
        );
      }
      _applyFilters();
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a campaign to view its performance.'),
        ),
      );
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
  Widget build(BuildContext context) => CampaignStudioLayout(
    stats: _stats,
    campaigns: _campaigns,
    templates: _templates,
    categories: {
      'All',
      ..._categories
          .map((item) => (item['label'] ?? item['name'] ?? '').toString())
          .where((label) => label.isNotEmpty),
      ..._allTemplates.map((item) => item.category),
    }.toList(),
    counts: {
      'Explore Campaigns': _allCampaigns.length,
      'Drafts': _getCountForTab('Drafts', _stats.draftCount),
      'Pending': _getCountForTab('Pending', _stats.pendingCount),
      'Approved': _getCountForTab('Approved', _stats.approvedCount),
      'Scheduled': _getCountForTab('Scheduled', _stats.scheduledCount),
      'Action Rejected': _getCountForTab(
        'Action Rejected',
        _stats.rejectedCount,
      ),
    },
    tab: _selectedMainTab,
    category: _selectedCategory,
    loading: _isLoading,
    onCreate: widget.onCreateCampaign,
    onAuto: widget.onCreateAutoCampaign,
    onGroups: widget.onCreateGroup,
    onCustomers: widget.onViewCustomers,
    onTopUp: _onTopUpWallet,
    onPerformance: _onViewCampaignPerformance,
    onTab: _onMainTabChanged,
    onCategory: _onCategoryChanged,
    onSearch: (query) => setState(() {
      _templateSearchQuery = query;
      _applyFilters();
    }),
    onCampaign: widget.onSelectCampaign,
    onTemplate: (template) {
      if (widget.onUseTemplate != null) {
        widget.onUseTemplate!(template);
      } else {
        widget.onCreateCampaign();
      }
    },
    onRefresh: _loadAllData,
  );
}
