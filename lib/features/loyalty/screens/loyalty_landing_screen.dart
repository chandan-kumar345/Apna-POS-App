import 'package:flutter/material.dart';
import '../../../core/models/loyalty_program_model.dart';
import '../../../core/services/loyalty_service.dart';
import '../widgets/loyalty_program_card.dart';
import 'loyalty_performance_screen.dart';
import 'loyalty_details_screen.dart';
import 'loyalty_visit_made_screen.dart';

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

  bool _isLoading = true;
  String? _errorMessage;
  LoyaltyBrandingModel? _brandingData;

  @override
  void initState() {
    super.initState();
    _loadLoyaltyData();
  }

  Future<void> _loadLoyaltyData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _loyaltyService.fetchLoyaltyPrograms(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _brandingData = data;
          _isLoading = false;
        });
      }
    } catch (err) {
      if (mounted) {
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 640 : double.infinity,
            ),
            child: Column(
              children: [
                // Sticky Top Navigation Row (Circular Back Button)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: _buildTopAppBarRow(),
                ),

                // Scrollable Content
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF0D9488),
                    onRefresh: () => _loadLoyaltyData(forceRefresh: true),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 4),

                          // Dynamic Heading
                          const Text(
                            'Select Your Loyalty Program',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0D9488), // Reference Teal color
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 8),

                          // Dynamic Subtitle
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Discover the perfect loyalty program and tailor it to fit your brand seamlessly!',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF475569),
                                height: 1.35,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Loyalty Performance Pill Button
                          _buildLoyaltyPerformanceButton(),

                          const SizedBox(height: 20),

                          // Main Content (Loading, Error, Empty, or Dynamic List)
                          _buildBodyContent(),

                          const SizedBox(height: 30),
                        ],
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
  }

  /// Top Left Circular Back Arrow Button
  Widget _buildTopAppBarRow() {
    return Row(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.maybePop(context);
              }
            },
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF1F5F9),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF0F172A),
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Pill-Shaped "Loyalty Performance" Button with Analytics Icon
  Widget _buildLoyaltyPerformanceButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _navigateToPerformance,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF99F6E4).withValues(alpha: 0.7), // Light teal/mint
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF5EEAD4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.query_stats_rounded,
                color: Color(0xFF0F766E), // Deep teal
                size: 19,
              ),
              SizedBox(width: 8),
              Text(
                'Loyalty Performance',
                style: TextStyle(
                  color: Color(0xFF0F766E),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
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
                color: const Color(0xFF0D9488).withValues(alpha: 0.5),
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
          const Icon(Icons.card_giftcard_rounded, color: Color(0xFF0D9488), size: 44),
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
              backgroundColor: const Color(0xFF051C48),
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
