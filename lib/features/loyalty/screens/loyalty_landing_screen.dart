import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/database/database_service.dart';
import '../../../core/models/loyalty_program_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/services/loyalty_service.dart';
import '../../../core/widgets/pos_screen_top_header.dart';
import '../../campaign/mobile/campaign_style.dart' show muted;
import '../../campaign/mobile/customer_style.dart';
import '../../notifications/screens/notifications_screen.dart';
import 'create_loyalty_program_screen.dart';
import 'loyalty_program_details_screen.dart';

class LoyaltyLandingScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onOpenDrawer;
  final bool showHeader;
  final LoyaltyBrandingModel? initialBranding;

  const LoyaltyLandingScreen({
    super.key,
    this.onBack,
    this.onOpenDrawer,
    this.showHeader = true,
    this.initialBranding,
  });

  @override
  State<LoyaltyLandingScreen> createState() => _LoyaltyLandingScreenState();
}

class _LoyaltyLandingScreenState extends State<LoyaltyLandingScreen> {
  final LoyaltyService _loyaltyService = LoyaltyService();
  final DatabaseService _db = DatabaseService();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  bool _isLoading = false;
  String? _errorMessage;
  LoyaltyBrandingModel? _brandingData;
  int _lastCompletedOrderCount = -1;
  Timer? _dbRefreshDebounce;

  @override
  void initState() {
    super.initState();
    _brandingData = widget.initialBranding ?? _loyaltyService.cachedBranding;
    try {
      _lastCompletedOrderCount = _db.orders
          .where((o) => o.status == OrderStatus.completed)
          .length;
      _db.addListener(_onDatabaseChanged);
    } catch (_) {}
    if (widget.initialBranding == null) {
      _loadLoyaltyData(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    _dbRefreshDebounce?.cancel();
    try {
      _db.removeListener(_onDatabaseChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onDatabaseChanged() {
    if (!mounted) return;
    final completedCount = _db.orders
        .where((o) => o.status == OrderStatus.completed)
        .length;
    if (completedCount != _lastCompletedOrderCount) {
      _lastCompletedOrderCount = completedCount;
      _dbRefreshDebounce?.cancel();
      _dbRefreshDebounce = Timer(const Duration(milliseconds: 900), () {
        if (mounted) {
          _loadLoyaltyData(forceRefresh: true);
        }
      });
    }
  }

  Future<void> _loadLoyaltyData({bool forceRefresh = false}) async {
    if (_brandingData == null) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else if (forceRefresh && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final data = await _loyaltyService.fetchLoyaltyPrograms(
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _brandingData = data;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_brandingData == null) {
            _errorMessage =
                'Unable to load loyalty programs. Please check connection and retry.';
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateToCreateProgram() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateLoyaltyProgramScreen(
          onSaved: () => _loadLoyaltyData(forceRefresh: true),
        ),
      ),
    );
    if (mounted) {
      _loadLoyaltyData(forceRefresh: true);
    }
  }

  Future<void> _navigateToProgramDetails(LoyaltyProgramModel program) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoyaltyProgramDetailsScreen(
          program: program,
          onProgramChanged: () => _loadLoyaltyData(forceRefresh: true),
        ),
      ),
    );
    if (mounted) {
      _loadLoyaltyData(forceRefresh: true);
    }
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }

  void _onCashbackBannerTap(LoyaltyBrandingModel data) {
    final activeCb = data.programs
        .where((p) => p.isActive && p.type != LoyaltyType.visitMade)
        .toList();
    if (activeCb.isNotEmpty) {
      _navigateToProgramDetails(activeCb.first);
      return;
    }
    final anyCb = data.programs
        .where((p) => p.type != LoyaltyType.visitMade)
        .toList();
    if (anyCb.isNotEmpty) {
      _navigateToProgramDetails(anyCb.first);
      return;
    }
    _navigateToCreateProgram();
  }

  void _showRevenueInfoDialog(LoyaltyBrandingModel data) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2FE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                color: Color(0xFF0284C7),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Loyalty Revenue',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total revenue (${_currencyFormat.format(data.revenue)}) generated dynamically from completed orders associated with loyalty members and reward transactions.',
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF475569),
                height: 1.45,
              ),
            ),
            if (data.revenueGrowthPercent != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: data.revenueGrowthPercent! >= 0
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${data.revenueGrowthPercent! >= 0 ? '+' : ''}${data.revenueGrowthPercent!.round()}% vs previous period',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: data.revenueGrowthPercent! >= 0
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB91C1C),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Got it',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF0A4B67),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return PosScreenTopHeader(
      onLogoTap: widget.onOpenDrawer,
      onStoreTap: widget.onOpenDrawer,
      onNotificationTap: _openNotifications,
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEAF3FF),
            Color(0xFFE2EEFC),
            Color(0xFFEBF5FF),
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 720;
          final content = Column(
            children: [
              Expanded(child: _buildMainContent(isWide: isWide)),
              _buildCreateProgramFooter(isWide: isWide),
            ],
          );

          if (isWide) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: content,
              ),
            );
          }
          return content;
        },
      ),
    );

    if (widget.showHeader) {
      return CustomerShell(
        header: _buildTopHeader(),
        body: workspace,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      resizeToAvoidBottomInset: false,
      body: workspace,
    );
  }

  Widget _buildMainContent({required bool isWide}) {
    if (_isLoading && _brandingData == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF192452)),
      );
    }

    if (_errorMessage != null && _brandingData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 42,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: customerText(13.5, color: muted),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () => _loadLoyaltyData(forceRefresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A4B67),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _brandingData ?? _loyaltyService.getDefaultLoyaltyBranding();
    final allPrograms = data.programs;
    final activePrograms = allPrograms.where((p) => p.isActive).toList();
    final inactivePrograms = allPrograms.where((p) => !p.isActive).toList();
    final hasInactivePrograms = inactivePrograms.isNotEmpty;
    final displayedPrograms = [...activePrograms, ...inactivePrograms];

    return RefreshIndicator(
      color: const Color(0xFF192452),
      onRefresh: () => _loadLoyaltyData(forceRefresh: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Dark Midnight-Indigo Curved Hero Header Banner with HD 3D Gift + Coin Graphic
            _buildCurvedHeroBanner(isWide: isWide),

            // 2. Main Light Ice-Blue Content Body
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Elevated Cashback Rewards Card with HD 3D Golden Trophy
                  _buildCashbackRewardsBannerCard(data),
                  const SizedBox(height: 14),

                  // 2x2 Dynamic Metric Grid (Members, Total Cashback, Redemptions, Revenue)
                  _buildMetricsGrid(data),
                  const SizedBox(height: 20),

                  // Programs Section Header
                  _buildProgramsSectionHeader(
                    displayedCount: displayedPrograms.length,
                    hasInactivePrograms: hasInactivePrograms,
                  ),

                  const SizedBox(height: 10),

                  // Program Cards List or Empty State
                  if (displayedPrograms.isNotEmpty)
                    for (final program in displayedPrograms)
                      _buildProgramCard(program)
                  else
                    _buildEmptyProgramsCard(),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurvedHeroBanner({required bool isWide}) {
    final canPopStandalone = widget.showHeader && Navigator.of(context).canPop();

    final banner = ClipPath(
      clipper: isWide ? null : _HeroBottomCurveClipper(),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: isWide ? BorderRadius.circular(24) : null,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0E1635),
              Color(0xFF18224E),
              Color(0xFF25326E),
            ],
          ),
          boxShadow: isWide
              ? [
                  BoxShadow(
                    color: const Color(0xFF0E1635).withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Soft ambient highlights & wave reflection
            Positioned.fill(
              child: CustomPaint(
                painter: _HeroAmbientGlowPainter(),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                isWide ? 18 : 16,
                14,
                isWide ? 18 : 26,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (canPopStandalone) ...[
                              InkWell(
                                onTap: () => Navigator.of(context).pop(),
                                borderRadius: BorderRadius.circular(12),
                                child: const Padding(
                                  padding: EdgeInsets.only(right: 8, top: 2, bottom: 2),
                                  child: Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                            const Flexible(
                              child: Text(
                                'Loyalty Program',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Boost customer loyalty with cashback,\nrewards & more.',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 11.8,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.86),
                            height: 1.36,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // HD 3D Gift Box + Golden Coin + Sparkles Graphic
                  SizedBox(
                    width: isWide ? 120 : 108,
                    height: isWide ? 104 : 94,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF7C3AED).withValues(alpha: 0.36),
                                const Color(0xFF4F46E5).withValues(alpha: 0.14),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Image.asset(
                          'assets/images/loyalty_hero_gift_3d.png',
                          width: isWide ? 116 : 104,
                          height: isWide ? 102 : 92,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, _, _) => const _HeroGiftFallback(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isWide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: banner,
      );
    }
    return banner;
  }

  Widget _buildCashbackRewardsBannerCard(LoyaltyBrandingModel data) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFBF9FF),
            Color(0xFFF3EEFF),
          ],
        ),
        border: Border.all(color: Colors.white, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.09),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onCashbackBannerTap(data),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                // Raised Porcelain Squircle + HD 3D Golden Trophy
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFFEDE9FE),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/loyalty_trophy_3d.png',
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFF59E0B),
                        size: 30,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Cashback Rewards',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 15.0,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Give instant or future cashback on every order.',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF64748B),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(LoyaltyBrandingModel data) {
    final membersStr = NumberFormat.decimalPattern('en_IN').format(data.members);
    final cashbackStr = _currencyFormat.format(data.totalCashback);
    final redemptionsStr =
        NumberFormat.decimalPattern('en_IN').format(data.redemptions);
    final revenueStr = _currencyFormat.format(data.revenue);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                gradient: const [Color(0xFFE7F9EF), Color(0xFFD5F5E3)],
                shadowColor: const Color(0xFF10B981),
                badgeBg: const Color(0xFF10B981).withValues(alpha: 0.14),
                iconWidget: const Icon(
                  Icons.groups_rounded,
                  color: Color(0xFF059669),
                  size: 20,
                ),
                label: 'Members',
                value: membersStr,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                gradient: const [Color(0xFFF3EEFF), Color(0xFFE9DEFF)],
                shadowColor: const Color(0xFF8B5CF6),
                badgeBg: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                iconWidget: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CustomPaint(painter: _StackedCoinsPainter()),
                ),
                label: 'Total Cashback',
                value: cashbackStr,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                gradient: const [Color(0xFFFFF4E6), Color(0xFFFFE7CB)],
                shadowColor: const Color(0xFFF59E0B),
                badgeBg: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                iconWidget: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFFEA8B07),
                  size: 18,
                ),
                label: 'Redemptions',
                value: redemptionsStr,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildRevenueMetricCard(
                data: data,
                revenueStr: revenueStr,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required List<Color> gradient,
    required Color shadowColor,
    required Color badgeBg,
    required Widget iconWidget,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.11),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
            ),
            child: Center(child: iconWidget),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 10.8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 19.0,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
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

  Widget _buildRevenueMetricCard({
    required LoyaltyBrandingModel data,
    required String revenueStr,
  }) {
    final growth = data.revenueGrowthPercent;
    final isPositive = (growth ?? 0) >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEBF6FF), Color(0xFFD8ECFF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: SizedBox(
                width: 19,
                height: 19,
                child: CustomPaint(painter: _MiniRevenueBarsPainter()),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'Revenue',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 10.8,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _showRevenueInfoDialog(data),
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(1),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 13.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        revenueStr,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 18.0,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (growth != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isPositive
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 10.5,
                              color: isPositive
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFFB91C1C),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${isPositive ? '+' : ''}${growth.round()}%',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 9.8,
                                fontWeight: FontWeight.w800,
                                color: isPositive
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB91C1C),
                              ),
                            ),
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
    );
  }

  Widget _buildProgramsSectionHeader({
    required int displayedCount,
    required bool hasInactivePrograms,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${hasInactivePrograms ? 'All Programs' : 'Active Programs'} ($displayedCount)',
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15.0,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF0A4B67),
              ),
            ),
          )
        else
          IconButton(
            onPressed: () => _loadLoyaltyData(forceRefresh: true),
            tooltip: 'Refresh',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(
              Icons.refresh_rounded,
              size: 17,
              color: Color(0xFF64748B),
            ),
          ),
      ],
    );
  }

  Widget _buildProgramCard(LoyaltyProgramModel program) {
    final isVisitMade = program.type == LoyaltyType.visitMade;
    final iconBg =
        isVisitMade ? const Color(0xFFFEF3C7) : const Color(0xFFE2F7EC);
    final subtitleText = program.description.trim().isNotEmpty
        ? program.description.trim()
        : (program.earningRule.trim().isNotEmpty
            ? program.earningRule.trim()
            : 'Give cashback to customers on their orders.');
    final customerLabel =
        'Used by: ${program.membersCount} ${program.membersCount == 1 ? 'customer' : 'customers'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToProgramDetails(program),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Circular icon badge
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconBg,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isVisitMade
                            ? const Icon(
                                Icons.card_membership_rounded,
                                color: Color(0xFFD97706),
                                size: 19,
                              )
                            : const SizedBox(
                                width: 22,
                                height: 22,
                                child: CustomPaint(
                                  painter: _CashbackLoopPainter(),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Title + Active Pill + Description
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  program.title,
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: program.isActive
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  program.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontFamily: 'Roboto',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: program.isActive
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF475569),
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitleText,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 11.2,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 8),

                // Metadata Row: Valid till | Used by: X customers
                Row(
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 12.5,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Valid till: ${program.formattedValidTill}',
                                maxLines: 1,
                                softWrap: false,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.1,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: const Color(0xFFCBD5E1),
                    ),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people_outline_rounded,
                            size: 13.5,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                customerLabel,
                                maxLines: 1,
                                softWrap: false,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.1,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                        ],
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
  }

  Widget _buildEmptyProgramsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2545).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Color(0xFFEBF5FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.loyalty_outlined,
              size: 28,
              color: Color(0xFF0A4B67),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'No active programs yet',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Create your first cashback or loyalty program to reward repeat customers.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12.5,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateProgramFooter({required bool isWide}) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, isWide ? 16 : 14),
      color: Colors.transparent,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0C5270),
              Color(0xFF073B52),
              Color(0xFF032234),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF042638).withValues(alpha: 0.30),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _navigateToCreateProgram,
            borderRadius: BorderRadius.circular(26),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Create Loyalty Program',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sweeping wave clipper matching the top midnight hero banner
class _HeroBottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 6);
    path.cubicTo(
      size.width * 0.28,
      size.height + 6,
      size.width * 0.70,
      size.height - 26,
      size.width,
      size.height - 16,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Subtle sweeping glow inside the dark midnight-indigo hero banner
class _HeroAmbientGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final arcPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.06),
          const Color(0xFF6366F1).withValues(alpha: 0.14),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final arcPath = Path();
    arcPath.moveTo(size.width * 0.45, size.height);
    arcPath.quadraticBezierTo(
      size.width * 0.72,
      size.height * 0.42,
      size.width,
      size.height * 0.25,
    );
    arcPath.lineTo(size.width, size.height);
    arcPath.close();
    canvas.drawPath(arcPath, arcPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Vector fallback when HD hero PNG is unavailable (e.g., isolated asset-less unit test)
class _HeroGiftFallback extends StatelessWidget {
  const _HeroGiftFallback();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8B5CF6), Color(0xFF4F46E5)],
            ),
          ),
          child: const Icon(
            Icons.card_giftcard_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
        Positioned(
          bottom: 8,
          left: 8,
          child: Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFBBF24),
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Color(0xFF92400E),
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom HD-style stacked violet coins graphic matching Total Cashback card
class _StackedCoinsPainter extends CustomPainter {
  const _StackedCoinsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFF7C3AED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = const Color(0xFF8B5CF6).withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    // Back stack (left-top)
    final topOval = Rect.fromCenter(
      center: Offset(size.width * 0.42, size.height * 0.30),
      width: size.width * 0.50,
      height: size.height * 0.22,
    );
    canvas.drawOval(topOval, fill);
    canvas.drawOval(topOval, stroke);

    // Cylinder sides & bottom arcs for top stack
    final path = Path()
      ..moveTo(topOval.left, topOval.center.dy)
      ..lineTo(topOval.left, size.height * 0.68)
      ..arcTo(
        Rect.fromCenter(
          center: Offset(topOval.center.dx, size.height * 0.68),
          width: topOval.width,
          height: topOval.height,
        ),
        3.14159,
        -1.5,
        false,
      );
    canvas.drawPath(path, stroke);

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(topOval.center.dx, size.height * 0.49),
        width: topOval.width,
        height: topOval.height,
      ),
      0.1,
      2.94,
      false,
      stroke,
    );

    // Front coin stack (right-bottom)
    final frontOval = Rect.fromCenter(
      center: Offset(size.width * 0.62, size.height * 0.56),
      width: size.width * 0.48,
      height: size.height * 0.21,
    );
    canvas.drawOval(frontOval, Paint()..color = const Color(0xFFEDE9FE));
    canvas.drawOval(frontOval, stroke);

    final frontBody = Path()
      ..moveTo(frontOval.left, frontOval.center.dy)
      ..lineTo(frontOval.left, size.height * 0.78)
      ..arcTo(
        Rect.fromCenter(
          center: Offset(frontOval.center.dx, size.height * 0.78),
          width: frontOval.width,
          height: frontOval.height,
        ),
        3.14159,
        -3.14159,
        false,
      )
      ..lineTo(frontOval.right, frontOval.center.dy);
    canvas.drawPath(frontBody, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom 3 ascending sky-blue rounded bar chart icon matching Revenue card
class _MiniRevenueBarsPainter extends CustomPainter {
  const _MiniRevenueBarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final barPaint = Paint()
      ..color = const Color(0xFF0EA5E9)
      ..style = PaintingStyle.fill;

    final bw = size.width * 0.22;
    final bottom = size.height * 0.86;
    final bars = [
      (size.width * 0.14, size.height * 0.34),
      (size.width * 0.42, size.height * 0.52),
      (size.width * 0.70, size.height * 0.72),
    ];

    for (final b in bars) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(b.$1, bottom - b.$2, bw, b.$2),
          const Radius.circular(2.5),
        ),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Circular green arrow enclosing a bold rupee symbol matching Active Program card
class _CashbackLoopPainter extends CustomPainter {
  const _CashbackLoopPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

    final arcPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;

    // Circular arrow arc (~305 degrees)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -0.4,
      5.25,
      false,
      arcPaint,
    );

    // Arrowhead at top-right of arc
    final ax = center.dx + radius * 0.88;
    final ay = center.dy - radius * 0.44;
    final arrowPath = Path()
      ..moveTo(ax - 3.8, ay - 0.8)
      ..lineTo(ax + 1.0, ay + 1.6)
      ..lineTo(ax + 2.2, ay - 3.6);
    canvas.drawPath(arrowPath, arcPaint);

    // Rupee symbol centered inside
    final tp = TextPainter(
      text: const TextSpan(
        text: '₹',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF059669),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2 + 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
