import 'package:flutter/material.dart';
import '../../../core/models/loyalty_program_model.dart';
import '../../../core/services/loyalty_service.dart';
import '../widgets/loyalty_program_card.dart';
import 'loyalty_performance_screen.dart';
import 'loyalty_details_screen.dart';
import 'loyalty_visit_made_screen.dart';

import '../../subscription/screens/subscription_screen.dart';

class LoyaltyLandingScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const LoyaltyLandingScreen({
    super.key,
    this.onBack,
  });

  @override
  State<LoyaltyLandingScreen> createState() => _LoyaltyLandingScreenState();
}

class _LoyaltyLandingScreenState extends State<LoyaltyLandingScreen> {
  final LoyaltyService _loyaltyService = LoyaltyService();

  static const Color _primaryThemeColor = Color(0xFF082559);
  static const Color _accentTeal = Color(0xFF0F766E);

  bool _isLoading = false;
  String? _errorMessage;
  LoyaltyBrandingModel? _brandingData;

  @override
  void initState() {
    super.initState();
    // Instant Load: populate immediately with cache or defaults without waiting
    _brandingData = _loyaltyService.cachedBranding ?? _loyaltyService.getDefaultLoyaltyBranding();
    _isLoading = false;
    _loadLoyaltyData();
  }

  Future<void> _loadLoyaltyData({bool forceRefresh = false}) async {
    // Keep loading flag false if data is already visible to prevent flicker
    if (_brandingData == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await _loyaltyService.fetchLoyaltyPrograms(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _brandingData = data;
          _isLoading = false;
        });
      }
    } catch (err) {
      if (mounted && _brandingData == null) {
        setState(() {
          _errorMessage = 'Unable to load loyalty programs. Please check connection and retry.';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToPerformance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoyaltyPerformanceScreen(),
      ),
    );
  }

  void _openSubscription() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SubscriptionScreen(sourceFeature: 'loyalty'),
      ),
    );
  }

  void _navigateToDetails(LoyaltyProgramModel program) {
    if (program.type == LoyaltyType.visitMade) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LoyaltyVisitMadeScreen(
            companyName: _brandingData?.companyName ?? '',
            companyLogo: _brandingData?.companyLogo ?? '',
            program: program,
            onCompleted: () => _loadLoyaltyData(forceRefresh: true),
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoyaltyDetailsScreen(
          program: program,
          companyName: _brandingData?.companyName ?? '',
          companyLogo: _brandingData?.companyLogo ?? '',
          onProgramUpdated: () => _loadLoyaltyData(forceRefresh: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 650;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Curved Header in App Default Color Theme (#082559)
            _buildTopCurvedHeader(),

            // 2. Scrollable Program List Content
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 640 : double.infinity,
                  ),
                  child: RefreshIndicator(
                    color: _primaryThemeColor,
                    onRefresh: () => _loadLoyaltyData(forceRefresh: true),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Pro Loyalty Upgrade Banner
                          _buildLoyaltyProBanner(),
                          const SizedBox(height: 12),

                          // Main Content (Loading, Error, Empty, or Dynamic Program Cards)
                          _buildBodyContent(),

                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltyProBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A082F), Color(0xFF8E1449)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF472B6), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFF472B6), size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pro Loyalty Engine 👑',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                ),
                Text(
                  'Automated cashbacks, SMS rewards & customer tiers.',
                  style: TextStyle(color: Color(0xFFFCE7F3), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _openSubscription,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Upgrade', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  /// Top Curved Header in App Theme Navy Color (#082559) with "Select Your Loyalty Program" text (Centered)
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top Navigation & Performance Action Row
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
              Row(
                children: [
                  _buildLoyaltyPerformanceHeaderButton(),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _openSubscription,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Plans 👑',
                            style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main Header Title: "Select Your Loyalty Program" (Centered)
          const Text(
            'Select Your Loyalty Program',
            style: TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),

          // Dynamic Subtitle in Curved Header (Centered)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Discover the perfect loyalty program and tailor it to fit your brand seamlessly!',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Frosted Glass Header Button for "Loyalty Performance"
  Widget _buildLoyaltyPerformanceHeaderButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _navigateToPerformance,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.query_stats_rounded,
                color: Colors.white,
                size: 15,
              ),
              SizedBox(width: 5),
              Text(
                'Performance',
                style: TextStyle(
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
    );
  }

  /// Body Content Renderer for States
  Widget _buildBodyContent() {
    if (_isLoading) {
      return _buildLoadingSkeletons();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    final programs = _brandingData?.programs ?? [];
    if (programs.isEmpty) {
      return _buildEmptyState();
    }

    final companyName = _brandingData?.companyName ?? 'MISSION MEATZ';
    final companyLogo = _brandingData?.companyLogo ?? '';

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: programs.length,
      itemBuilder: (context, index) {
        final prog = programs[index];
        return LoyaltyProgramCard(
          program: prog,
          companyName: companyName,
          companyLogo: companyLogo,
          onTap: () => _navigateToDetails(prog),
        );
      },
    );
  }

  /// Loading Shimmer Skeletons
  Widget _buildLoadingSkeletons() {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          height: i == 2 ? 260 : 160,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _primaryThemeColor.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Error State with Retry Button
  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFFEF4444), size: 40),
          const SizedBox(height: 12),
          const Text(
            'Failed to Load Loyalty Programs',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Please check your connection and try again.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _loadLoyaltyData(forceRefresh: true),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  /// Empty State
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.card_giftcard_rounded, color: _accentTeal, size: 44),
          const SizedBox(height: 12),
          const Text(
            'No Active Loyalty Programs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create your first loyalty reward program to drive repeat customer visits!',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _loadLoyaltyData(forceRefresh: true),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Initialize Default Programs'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryThemeColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
