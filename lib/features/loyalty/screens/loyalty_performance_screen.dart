import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/models/loyalty_program_model.dart';
import '../../../core/services/loyalty_service.dart';
import '../../../core/database/database_service.dart';
import 'loyalty_visit_made_screen.dart';

class LoyaltyPerformanceScreen extends StatefulWidget {
  final int initialLibraryFilter;

  const LoyaltyPerformanceScreen({
    super.key,
    this.initialLibraryFilter = 0,
  });

  @override
  State<LoyaltyPerformanceScreen> createState() => _LoyaltyPerformanceScreenState();
}

class _LoyaltyPerformanceScreenState extends State<LoyaltyPerformanceScreen> {
  final LoyaltyService _loyaltyService = LoyaltyService();
  bool _isLoading = false;
  LoyaltyPerformanceModel? _performance;

  // App Theme Primary Color (Navy Blue from App Header)
  static const Color _primaryThemeColor = Color(0xFF082559);
  static const Color _accentTeal = Color(0xFF0F766E);
  static const Color _emeraldGreen = Color(0xFF059669);

  // Active Date Filter
  String _selectedDateRange = 'Last 7 Days';

  // Selected Program Filter: 'all' or programId e.g. 'prog_visit_made'
  String _selectedProgramId = 'all';

  // Summary Chart Mode: 0 for 'Redemption', 1 for 'Revenue'
  int _summaryChartMode = 0;

  // Program Library Tab Filter: 0: All, 1: Active, 2: Inactive, 3: Draft
  late int _programLibraryFilter;

  @override
  void initState() {
    super.initState();
    _programLibraryFilter = widget.initialLibraryFilter;
    _performance = _loyaltyService.cachedPerformance;
    _isLoading = _performance == null;
    if (_performance?.dateRangeText.isNotEmpty == true && _performance!.dateRangeText != 'Last 7 Days') {
      _selectedDateRange = _performance!.dateRangeText;
    }
    _loadPerformance(forceRefresh: true);
  }

  Future<void> _loadPerformance({bool forceRefresh = false, String? programId}) async {
    if (programId != null) _selectedProgramId = programId;
    if (_performance == null && !_isLoading) {
      setState(() => _isLoading = true);
    }
    final data = await _loyaltyService.fetchLoyaltyPerformance(
      forceRefresh: forceRefresh,
      dateRange: _selectedDateRange,
      programId: _selectedProgramId,
    );
    if (mounted) {
      setState(() {
        _performance = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final perf = _performance ?? LoyaltyPerformanceModel();
    final isTabletLandscape = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header styled same as Visit Made Screen (App Theme Color #082559)
            _buildTopHeader(),

            // 2. Wrapped Scrollable Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _primaryThemeColor, strokeWidth: 2.5),
                    )
                  : RefreshIndicator(
                      color: _primaryThemeColor,
                      onRefresh: () => _loadPerformance(forceRefresh: true),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isTabletLandscape ? 1000 : 540,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Program Status Breakdown Row (ACTIVE, INACTIVE, DRAFT)
                                _buildProgramStatusRow(perf),
                                const SizedBox(height: 12),

                                // 2. Loyalty Health Score Card with Radial Arc Gauge
                                _buildHealthScoreCard(perf),
                                const SizedBox(height: 16),

                                // 3. Overview Section Header & 3 Key Metric Cards
                                _buildOverviewSection(perf),
                                const SizedBox(height: 12),

                                // 4. Summary Chart Card (Redemption / Revenue toggle + Bar Graph)
                                _buildSummaryChartCard(perf),
                                const SizedBox(height: 12),

                                // 5. 4 Small Summary Metric Tiles
                                _buildSmallMetricsRow(perf),
                                const SizedBox(height: 12),

                                // 6. Top 10 Redeeming Customers & Reward Scoreboard
                                if (isTabletLandscape)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _buildTopCustomersCard(perf)),
                                      const SizedBox(width: 12),
                                      Expanded(child: _buildRewardScoreboardCard(perf)),
                                    ],
                                  )
                                else ...[
                                  _buildTopCustomersCard(perf),
                                  const SizedBox(height: 12),
                                  _buildRewardScoreboardCard(perf),
                                ],
                                const SizedBox(height: 12),

                                // 7. Recent Program Activity Table
                                _buildRecentActivityCard(perf),
                                const SizedBox(height: 16),

                                // 8. Program Library Section with Status Filter & Cards
                                _buildProgramLibrarySection(perf),
                                const SizedBox(height: 24),
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

  // --- 1. TOP HEADER (Matching Visit Made Screen in App Theme Navy Color #082559) ---
  Widget _buildTopHeader() {
    return Container(
      color: _primaryThemeColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 17),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Loyalty Performance',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Track your loyalty program insights',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFFCBD5E1),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          InkWell(
            onTap: _showFilterDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.filter_alt_outlined, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Filter',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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

  // --- 2. PROGRAM STATUS ROW (ACTIVE, INACTIVE, DRAFT) ---
  Widget _buildProgramStatusRow(LoyaltyPerformanceModel perf) {
    return Row(
      children: [
        // ACTIVE
        Expanded(
          child: _buildStatusCard(
            label: 'ACTIVE',
            count: '${perf.activeProgramsCount}',
            icon: Icons.groups_outlined,
            iconColor: const Color(0xFF059669),
            iconBg: const Color(0xFFDCFCE7),
            barColor: const Color(0xFF059669),
            onTap: () => setState(() => _programLibraryFilter = 1),
          ),
        ),
        const SizedBox(width: 8),
        // INACTIVE
        Expanded(
          child: _buildStatusCard(
            label: 'INACTIVE',
            count: '${perf.inactiveProgramsCount}',
            icon: Icons.people_outline_rounded,
            iconColor: const Color(0xFF7C3AED),
            iconBg: const Color(0xFFF3E8FF),
            barColor: const Color(0xFF7C3AED),
            onTap: () => setState(() => _programLibraryFilter = 2),
          ),
        ),
        const SizedBox(width: 8),
        // DRAFT
        Expanded(
          child: _buildStatusCard(
            label: 'DRAFT',
            count: '${perf.draftProgramsCount}',
            icon: Icons.shopping_bag_outlined,
            iconColor: const Color(0xFFD97706),
            iconBg: const Color(0xFFFEF3C7),
            barColor: const Color(0xFFD97706),
            onTap: () => setState(() => _programLibraryFilter = 3),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required String label,
    required String count,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color barColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 13),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              count,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const Text(
            'Programs',
            style: TextStyle(
              fontSize: 9,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            height: 2.5,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    ),
  );
}

  // --- 3. LOYALTY HEALTH SCORE CARD ---
  Widget _buildHealthScoreCard(LoyaltyPerformanceModel perf) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Text Info
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'LOYALTY HEALTH SCORE',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${perf.healthScore}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.4,
                        ),
                      ),
                      const Text(
                        '/100',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  perf.healthScoreStatus,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Right Radial Semi-Circle Gauge
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 60,
              child: CustomPaint(
                painter: _RadialArcGaugePainter(score: perf.healthScore),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. OVERVIEW SECTION (Date Filter & 3 Metric Cards) ---
  Widget _buildOverviewSection(LoyaltyPerformanceModel perf) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Date Pill
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            InkWell(
              onTap: _showDateRangePickerSheet,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 0.9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 11.5, color: Color(0xFF475569)),
                    const SizedBox(width: 4),
                    Text(
                      _selectedDateRange,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Program Selector Chips (All Programs vs Specific Loyalty Program)
        if (perf.programLibrary.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Programs'),
                  selected: _selectedProgramId == 'all',
                  selectedColor: _primaryThemeColor,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: _selectedProgramId == 'all' ? _primaryThemeColor : const Color(0xFFCBD5E1)),
                  labelStyle: TextStyle(
                    color: _selectedProgramId == 'all' ? Colors.white : const Color(0xFF475569),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      _loadPerformance(forceRefresh: true, programId: 'all');
                    }
                  },
                ),
                ...perf.programLibrary.map((prog) {
                  final isSel = _selectedProgramId == prog.id;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(prog.name),
                      selected: isSel,
                      selectedColor: _primaryThemeColor,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: isSel ? _primaryThemeColor : const Color(0xFFCBD5E1)),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : const Color(0xFF475569),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          _loadPerformance(forceRefresh: true, programId: prog.id);
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // 3 Key Metric Cards in a Row
        Row(
          children: [
            // Revenue
            Expanded(
              child: _buildOverviewMetricCard(
                value: '₹${perf.totalRevenue.toInt()}',
                valueColor: _emeraldGreen,
                label: 'Total Revenue\nGenerated',
                icon: Icons.trending_up_rounded,
                iconColor: _emeraldGreen,
                iconBg: const Color(0xFFDCFCE7),
              ),
            ),
            const SizedBox(width: 8),
            // Redemption
            Expanded(
              child: _buildOverviewMetricCard(
                value: '${perf.totalRedemptions}',
                valueColor: const Color(0xFFEA580C),
                label: 'Total Redemption\nof Points',
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFFEA580C),
                iconBg: const Color(0xFFFFEDD5),
              ),
            ),
            const SizedBox(width: 8),
            // Participants
            Expanded(
              child: _buildOverviewMetricCard(
                value: '${perf.totalParticipants}',
                valueColor: _accentTeal,
                label: 'Customers in\nProgram',
                icon: Icons.groups_outlined,
                iconColor: _accentTeal,
                iconBg: const Color(0xFFCCFBF1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewMetricCard({
    required String value,
    required Color valueColor,
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                      color: valueColor,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. SUMMARY CHART CARD ---
  Widget _buildSummaryChartCard(LoyaltyPerformanceModel perf) {
    final chartData = perf.chartData;
    final maxRedeem = chartData.fold<double>(1.0, (m, dp) => math.max(m, dp.redemptions));
    final maxRev = chartData.fold<double>(1000.0, (m, dp) => math.max(m, dp.revenue));

    final isRedeemMode = _summaryChartMode == 0;
    final maxVal = isRedeemMode ? (maxRedeem > 0 ? maxRedeem : 1.0) : (maxRev > 0 ? maxRev : 1000.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Summary + Segmented Pill Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Summary',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _summaryChartMode = 0),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: _summaryChartMode == 0 ? _accentTeal : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Redemption',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: _summaryChartMode == 0 ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _summaryChartMode = 1),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: _summaryChartMode == 1 ? _accentTeal : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Revenue',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: _summaryChartMode == 1 ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bar Chart Canvas / Layout
          if (chartData.isEmpty)
            Container(
              height: 100,
              alignment: Alignment.center,
              child: const Text(
                'No activity data for this date range',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              ),
            )
          else
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Y-Axis Labels
                  SizedBox(
                    width: 26,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(6, (idx) {
                        final stepRatio = (5 - idx) / 5.0;
                        final val = maxVal * stepRatio;
                        final label = isRedeemMode
                            ? (val >= 10 ? val.toInt().toString() : val.toStringAsFixed(1))
                            : (val >= 1000 ? '${(val / 1000).toStringAsFixed(val % 1000 == 0 ? 0 : 1)}k' : val.toInt().toString());
                        return Text(
                          label,
                          style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Grid lines and Bars
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              // 5 Horizontal Guide Lines
                              Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  6,
                                  (_) => Container(
                                    width: double.infinity,
                                    height: 1,
                                    color: const Color(0xFFF1F5F9),
                                  ),
                                ),
                              ),

                              // Dynamic Bars
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: chartData.map((dp) {
                                  final double val = isRedeemMode ? dp.redemptions : dp.revenue;
                                  final double ratio = maxVal > 0 ? (val / maxVal).clamp(0.0, 1.0) : 0.0;

                                  return Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        width: 12,
                                        height: (ratio * 88).clamp(2.0, 88.0),
                                        decoration: BoxDecoration(
                                          color: ratio > 0.02
                                              ? _accentTeal
                                              : Colors.transparent,
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),

                        // X-Axis Date Labels
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: chartData.map((dp) {
                            return Text(
                              dp.day,
                              style: const TextStyle(
                                fontSize: 8.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- 6. 4 SMALL SUMMARY METRIC TILES ---
  Widget _buildSmallMetricsRow(LoyaltyPerformanceModel perf) {
    final metrics = [
      {
        'label': 'Redemption\nRate',
        'val': perf.redemptionRate,
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF059669),
        'bg': const Color(0xFFDCFCE7),
      },
      {
        'label': 'Points\nRedeemed',
        'val': '${perf.pointsRedeemed}',
        'icon': Icons.card_giftcard_rounded,
        'color': const Color(0xFF7C3AED),
        'bg': const Color(0xFFF3E8FF),
      },
      {
        'label': 'Points\nIssued',
        'val': '${perf.pointsIssued}',
        'icon': Icons.star_outline_rounded,
        'color': const Color(0xFF2563EB),
        'bg': const Color(0xFFDBEAFE),
      },
      {
        'label': 'Avg. Reward /\nRedemption',
        'val': '₹${perf.avgRewardPerRedemption.toInt()}',
        'icon': Icons.currency_rupee_rounded,
        'color': const Color(0xFFD97706),
        'bg': const Color(0xFFFEF3C7),
      },
    ];

    return Row(
      children: metrics.map((m) {
        final iconColor = m['color'] as Color;
        final iconBg = m['bg'] as Color;

        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  child: Icon(m['icon'] as IconData, color: iconColor, size: 12),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    m['val'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  m['label'] as String,
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- 7A. TOP 10 REDEEMING CUSTOMERS CARD ---
  Widget _buildTopCustomersCard(LoyaltyPerformanceModel perf) {
    final list = perf.topRedeemingCustomers;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top 10 Redeeming Customers',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              child: const Text(
                'No customers have redeemed loyalty yet',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else ...[
            ...list.take(3).map((c) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline_rounded, size: 12.5, color: Color(0xFF059669)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          c.phone, // FULL UNMASKED PHONE NUMBER
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Text(
                        c.badgeText.isNotEmpty ? c.badgeText : 'Redemption ${c.redemptionCount} Times',
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 3),
            InkWell(
              onTap: () => _showAllTopCustomersSheet(list),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _accentTeal,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 14, color: _accentTeal),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- 7B. REWARD SCOREBOARD CARD ---
  Widget _buildRewardScoreboardCard(LoyaltyPerformanceModel perf) {
    final list = perf.rewardScoreboard;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reward Scoreboard',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              child: const Text(
                'No active reward stages found',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else ...[
            ...list.take(4).map((r) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.card_giftcard_rounded, size: 12.5, color: Color(0xFF059669)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r.rewardText,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF334155),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${r.claimCount} claimed',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 3),
            InkWell(
              onTap: () => _showAllRewardScoreboardSheet(list),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _accentTeal,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 14, color: _accentTeal),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- 8. RECENT PROGRAM ACTIVITY TABLE (Compact View: Customer + Action + Points) ---
  Widget _buildRecentActivityCard(LoyaltyPerformanceModel perf) {
    final activities = perf.recentActivity;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Program Activity',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (activities.isNotEmpty)
                InkWell(
                  onTap: () => _showAllRecentActivitySheet(activities),
                  child: const Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _accentTeal,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 14, color: _accentTeal),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (activities.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: const Text(
                'No recent loyalty activity recorded',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else ...[
            // Compact Table Header (Customer + Action + Points)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text('Customer', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text('Action', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('Points', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),

            // Compact Table Rows
            ...activities.take(4).map((a) {
              final isRedeem = a.action.toLowerCase().contains('redeem');

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  children: [
                    // Customer Phone (Unmasked)
                    Expanded(
                      flex: 5,
                      child: Text(
                        a.customerPhone, // FULL UNMASKED PHONE NUMBER
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Action
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isRedeem ? Icons.card_giftcard_rounded : Icons.north_east_rounded,
                            size: 11,
                            color: isRedeem ? const Color(0xFFEA580C) : const Color(0xFF059669),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              a.action,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isRedeem ? const Color(0xFFEA580C) : const Color(0xFF059669),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Points
                    Expanded(
                      flex: 2,
                      child: Text(
                        a.points,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isRedeem ? const Color(0xFFDC2626) : const Color(0xFF059669),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // --- 9. PROGRAM LIBRARY SECTION (Dynamic Filter & Live Cards) ---
  Widget _buildProgramLibrarySection(LoyaltyPerformanceModel perf) {
    final activeCount = perf.activeProgramsCount;
    final inactiveCount = perf.inactiveProgramsCount;
    final draftCount = perf.draftProgramsCount;
    final totalCount = perf.totalProgramsCount;

    List<ProgramLibraryItemModel> filteredPrograms = perf.programLibrary;
    if (_programLibraryFilter == 1) {
      filteredPrograms = perf.programLibrary.where((p) => p.status.toLowerCase() == 'active' || (p.isActive && p.status.toLowerCase() != 'draft' && p.status.toLowerCase() != 'inactive')).toList();
    } else if (_programLibraryFilter == 2) {
      filteredPrograms = perf.programLibrary.where((p) => p.status.toLowerCase() == 'inactive' || (!p.isActive && p.status.toLowerCase() != 'draft')).toList();
    } else if (_programLibraryFilter == 3) {
      filteredPrograms = perf.programLibrary.where((p) => p.status.toLowerCase() == 'draft').toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Description
        const Text(
          'Program Library',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Filter the loyalty list by status while keeping insights and live performance visible above.',
          style: TextStyle(
            fontSize: 10,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 10),

        // Filter Tabs: All | Active | Inactive | Draft
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildLibraryTab(index: 0, label: 'All', count: totalCount),
              const SizedBox(width: 6),
              _buildLibraryTab(index: 1, label: 'Active', count: activeCount),
              const SizedBox(width: 6),
              _buildLibraryTab(index: 2, label: 'Inactive', count: inactiveCount),
              const SizedBox(width: 6),
              _buildLibraryTab(index: 3, label: 'Draft', count: draftCount),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Program Cards or Empty State
        if (perf.programLibrary.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _primaryThemeColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.card_giftcard_rounded, size: 26, color: _primaryThemeColor),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No Loyalty Program Created Yet',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create your customized Visit Made loyalty program to start rewarding customers on every visit.',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 11.5, color: Color(0xFF64748B), height: 1.35),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LoyaltyVisitMadeScreen(
                          onCompleted: () => _loadPerformance(forceRefresh: true),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Create Visit Made Loyalty', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryThemeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          )
        else if (filteredPrograms.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 32, color: Color(0xFF94A3B8)),
                const SizedBox(height: 8),
                Text(
                  'No ${_getFilterName(_programLibraryFilter)} programs found',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          )
        else
          ...filteredPrograms.map((prog) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildLibraryProgramCard(prog),
              )),
      ],
    );
  }

  String _getFilterName(int filter) {
    switch (filter) {
      case 1:
        return 'active';
      case 2:
        return 'inactive';
      case 3:
        return 'draft';
      default:
        return '';
    }
  }

  Widget _buildLibraryTab({
    required int index,
    required String label,
    required int count,
  }) {
    final isSelected = _programLibraryFilter == index;

    return InkWell(
      onTap: () => setState(() => _programLibraryFilter = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _accentTeal : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _accentTeal : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleProgramActive(ProgramLibraryItemModel prog) async {
    final newActiveState = !prog.isActive;
    setState(() => _isLoading = true);
    await _loyaltyService.updateProgramStatus(
      prog.id,
      isActive: newActiveState,
      status: newActiveState ? 'active' : 'inactive',
    );
    await _loadPerformance(forceRefresh: true);
  }

  Color _parseHexColor(String hexString, Color fallback) {
    try {
      final buffer = StringBuffer();
      final clean = hexString.replaceAll('#', '').trim();
      if (clean.length == 6) {
        buffer.write('ff$clean');
      } else if (clean.length == 8) {
        buffer.write(clean);
      } else {
        return fallback;
      }
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  Widget _buildLibraryProgramCard(ProgramLibraryItemModel prog) {
    final currentUser = DatabaseService().currentUser;
    final dbRestaurant = DatabaseService().restaurant;
    final companyName = prog.name.isNotEmpty
        ? prog.name
        : (currentUser?.companyName ?? (dbRestaurant?.name ?? 'THE ROYAL GARDENIA'));

    final isDraft = prog.status.toLowerCase() == 'draft';
    final isActive = prog.isActive && !isDraft;

    final headerGradientStart = _parseHexColor(prog.bgGradientStart, const Color(0xFF4A082F));
    final headerGradientEnd = _parseHexColor(prog.bgGradientEnd, const Color(0xFF8E1449));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFF5EEAD4) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Centered Title ("Visit Made Loyalty" in Coral / Purple)
          Center(
            child: RichText(
              text: TextSpan(
                children: [
                  const TextSpan(
                    text: 'Visit ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFF5722), // Coral Orange
                    ),
                  ),
                  TextSpan(
                    text: '${prog.category.contains('Visit') ? 'Made' : prog.category} Loyalty',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF9333EA), // Purple
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 2. Main Content Row: Left Metadata & Actions | Right Vertical Card Preview
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Content (Flexible with zero overflow)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Switch & Status Badge
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: isActive,
                            activeThumbColor: Colors.white,
                            activeTrackColor: _emeraldGreen,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: const Color(0xFFCBD5E1),
                            onChanged: (_) => _toggleProgramActive(prog),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDraft
                                ? const Color(0xFFFEF3C7)
                                : (isActive ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isDraft ? 'Draft' : (isActive ? 'Active' : 'InActive'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDraft
                                  ? const Color(0xFFD97706)
                                  : (isActive ? const Color(0xFF16A34A) : const Color(0xFF475569)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Restaurant / Program Name
                    Text(
                      companyName,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Create Date
                    Text(
                      prog.createDate.isNotEmpty ? 'Create Date: ${prog.createDate}' : 'Create Date: 23/07/2026',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Row: Green index circle + Channel Type (RESPONSIVE WRAP - NO OVERFLOW)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        Container(
                          width: 17,
                          height: 17,
                          decoration: const BoxDecoration(
                            color: Color(0xFF059669),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              '5',
                              style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const Text(
                          'Channel Type: ',
                          style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            prog.channel.toLowerCase() == 'store visit' ? 'whatsapp' : prog.channel.toLowerCase(),
                            style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Row: Order Type: DineIn, TakeAway (RESPONSIVE WRAP - NO OVERFLOW)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'Order Type: ',
                          style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                        ),
                        ...prog.orderTypes.map((ot) {
                          final cleanOt = ot.replaceAll('-', '').replaceAll(' ', '');
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              cleanOt,
                              style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Action Buttons: View, Customer View, Edit, Delete
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        ElevatedButton(
                          onPressed: () => _showProgramDetailsSheet(prog),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            elevation: 0,
                          ),
                          child: const Text('View', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _showCustomerViewDialog(prog);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            elevation: 0,
                          ),
                          child: const Text('Customer View', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LoyaltyVisitMadeScreen(
                                  companyName: prog.name,
                                  onCompleted: () => _loadPerformance(forceRefresh: true),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            elevation: 0,
                          ),
                          child: const Text('Edit', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                        ),
                        ElevatedButton(
                          onPressed: () => _confirmDeleteProgram(prog),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            elevation: 0,
                          ),
                          child: const Text('Delete', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Right Vertical Loyalty Card Preview
              Container(
                width: 140,
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B0721),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Top Banner Image with Overlapping Circular Logo
                    SizedBox(
                      height: 75,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: prog.bannerImageUrl.isNotEmpty
                                ? Image.network(
                                    prog.bannerImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) => Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFFD97706), Color(0xFFB45309)],
                                        ),
                                      ),
                                      child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 28),
                                    ),
                                  )
                                : Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFFD97706), Color(0xFFB45309)],
                                      ),
                                    ),
                                    child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 28),
                                  ),
                          ),
                          Positioned(
                            bottom: -15,
                            child: Container(
                              width: 36,
                              height: 36,
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: prog.logoUrl.isNotEmpty
                                    ? Image.network(
                                        prog.logoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) => const Icon(Icons.storefront_rounded, color: Color(0xFFB45309), size: 18),
                                      )
                                    : const Icon(Icons.storefront_rounded, color: Color(0xFFB45309), size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Bottom Loyalty Card Content with Maroon/Burgundy Gradient
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [headerGradientStart, headerGradientEnd],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              children: [
                                Text(
                                  companyName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  prog.slogan.isNotEmpty ? prog.slogan : 'Get rewarded on every purchase',
                                  style: const TextStyle(
                                    color: Color(0xFFE2E8F0),
                                    fontSize: 6.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '1 Visit = ${prog.pointsPerVisit} ${prog.pointsName}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),

                            // Milestone / Reward Box
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    prog.starterRewardSubtext.isNotEmpty ? prog.starterRewardSubtext : '200 ${prog.pointsName}',
                                    style: const TextStyle(
                                      color: Color(0xFFFEF08A),
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    prog.starterRewardTitle.isNotEmpty ? prog.starterRewardTitle : 'Cheers ! Rs 100 off on your purchase',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 6.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Terms and conditions notes
                            const Text(
                              'Terms and conditions apply.\nNo minimum purchase limit.\n2 offers cannot be clubbed.',
                              style: TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 5.5,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
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
        ],
      ),
    );
  }

  void _showProgramDetailsSheet(ProgramLibraryItemModel prog) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  prog.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Category: ${prog.category}', style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
            const SizedBox(height: 4),
            Text('Channel: ${prog.channel}', style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
            const SizedBox(height: 4),
            Text('Order Types: ${prog.orderTypes.join(', ')}', style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
            const SizedBox(height: 4),
            Text('Earning Rule: 1 Visit = ${prog.pointsPerVisit} ${prog.pointsName}', style: const TextStyle(fontSize: 13, color: Color(0xFF475569))),
            const SizedBox(height: 4),
            Text('Status: ${prog.status.toUpperCase()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryThemeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerViewDialog(ProgramLibraryItemModel prog) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: _primaryThemeColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Customer View Preview',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Loyalty Card Preview
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _parseHexColor(prog.bgGradientStart, const Color(0xFF4A082F)),
                            _parseHexColor(prog.bgGradientEnd, const Color(0xFF8E1449)),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (prog.logoUrl.isNotEmpty)
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: NetworkImage(prog.logoUrl),
                              backgroundColor: Colors.white,
                            )
                          else
                            const CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.storefront_rounded, color: Color(0xFF4A082F), size: 24),
                            ),
                          const SizedBox(height: 10),
                          Text(
                            prog.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            prog.slogan,
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.stars_rounded, color: Color(0xFFFEF08A), size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  '1 Visit = ${prog.pointsPerVisit} ${prog.pointsName}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  prog.starterRewardTitle,
                                  style: const TextStyle(color: Color(0xFFFEF08A), fontWeight: FontWeight.w800, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  prog.starterRewardSubtext,
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryThemeColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close Preview', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteProgram(ProgramLibraryItemModel prog) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Program?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('Are you sure you want to remove "${prog.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _isLoading = true;
                if (_performance != null) {
                  final remaining = _performance!.programLibrary.where((p) => p.id != prog.id).toList();
                  _performance = LoyaltyPerformanceModel(
                    activeProgramsCount: remaining.where((p) => p.isActive).length,
                    inactiveProgramsCount: remaining.where((p) => !p.isActive).length,
                    draftProgramsCount: 0,
                    totalProgramsCount: remaining.length,
                    healthScore: remaining.isEmpty ? 0 : _performance!.healthScore,
                    healthScoreStatus: remaining.isEmpty ? 'Healthy score starts from 80+' : _performance!.healthScoreStatus,
                    dateRangeText: _performance!.dateRangeText,
                    totalRevenue: remaining.isEmpty ? 0.0 : _performance!.totalRevenue,
                    totalRedemptions: remaining.isEmpty ? 0 : _performance!.totalRedemptions,
                    totalParticipants: remaining.isEmpty ? 0 : _performance!.totalParticipants,
                    redemptionRate: remaining.isEmpty ? '0%' : _performance!.redemptionRate,
                    pointsRedeemed: remaining.isEmpty ? 0 : _performance!.pointsRedeemed,
                    pointsIssued: remaining.isEmpty ? 0 : _performance!.pointsIssued,
                    avgRewardPerRedemption: remaining.isEmpty ? 0.0 : _performance!.avgRewardPerRedemption,
                    chartData: remaining.isEmpty ? [] : _performance!.chartData,
                    topRedeemingCustomers: remaining.isEmpty ? [] : _performance!.topRedeemingCustomers,
                    rewardScoreboard: remaining.isEmpty ? [] : _performance!.rewardScoreboard,
                    recentActivity: remaining.isEmpty ? [] : _performance!.recentActivity,
                    programLibrary: remaining,
                  );
                }
              });
              await _loyaltyService.deleteLoyaltyProgram(prog.id);
              await _loadPerformance(forceRefresh: true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Loyalty program deleted successfully', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    backgroundColor: Color(0xFFDC2626),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // --- MODALS & BOTTOM SHEETS ---
  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter Insights',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.refresh_rounded, color: _primaryThemeColor, size: 20),
              title: const Text('Refresh Live Analytics', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              onTap: () {
                Navigator.pop(ctx);
                _loadPerformance(forceRefresh: true);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune_rounded, color: _primaryThemeColor, size: 20),
              title: const Text('Manage Loyalty Programs', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoyaltyVisitMadeScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDateRangePickerSheet() {
    final ranges = [
      'Today',
      'Last 7 Days',
      'Last 30 Days',
      'This Month',
      'All Time',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Overview Date Range',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            ...ranges.map((r) {
              final isSel = _selectedDateRange == r;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                title: Text(
                  r,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                    color: isSel ? _primaryThemeColor : const Color(0xFF334155),
                  ),
                ),
                trailing: isSel ? const Icon(Icons.check_rounded, color: _primaryThemeColor, size: 18) : null,
                onTap: () {
                  setState(() => _selectedDateRange = r);
                  Navigator.pop(ctx);
                  _loadPerformance(forceRefresh: true);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showAllTopCustomersSheet(List<TopCustomerModel> list) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Top Redeeming Customers',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (ctx, i) {
                  final c = list[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                      child: const Icon(Icons.person_outline_rounded, color: Color(0xFF059669), size: 14),
                    ),
                    title: Text(c.phone, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    subtitle: c.name.isNotEmpty ? Text(c.name, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))) : null,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(5), border: Border.all(color: const Color(0xFFBBF7D0))),
                      child: Text(c.badgeText.isNotEmpty ? c.badgeText : 'Redemption ${c.redemptionCount} Times', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllRewardScoreboardSheet(List<RewardScoreboardItem> list) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Reward Scoreboard',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (ctx, i) {
                  final r = list[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                      child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF059669), size: 14),
                    ),
                    title: Text(r.rewardText, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5)),
                    subtitle: Text(r.rewardType, style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllRecentActivitySheet(List<RecentActivityModel> list) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Program Activity',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (ctx, i) {
                  final a = list[i];
                  final isRedeem = a.action.toLowerCase().contains('redeem');

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isRedeem ? const Color(0xFFFFEDD5) : const Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isRedeem ? Icons.card_giftcard_rounded : Icons.north_east_rounded,
                        color: isRedeem ? const Color(0xFFEA580C) : const Color(0xFF059669),
                        size: 14,
                      ),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(a.customerPhone, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        Text(
                          a.points,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isRedeem ? const Color(0xFFDC2626) : const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${a.action} • ${a.orderType}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        Text(a.date, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- RADIAL ARC GAUGE PAINTER ---
class _RadialArcGaugePainter extends CustomPainter {
  final int score;

  _RadialArcGaugePainter({required this.score});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.9);
    final radius = math.min(size.width * 0.45, size.height * 0.85);

    const startAngle = math.pi; // 180 degrees
    const sweepAngle = math.pi; // 180 degrees sweep (semi-circle)

    // 1. Background Gray Track Arc
    final bgPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // 2. Filled Green / Teal Progress Arc
    final progressRatio = (score / 100.0).clamp(0.0, 1.0);
    final filledSweepAngle = sweepAngle * progressRatio;

    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF0D9488), Color(0xFF14B8A6)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      filledSweepAngle,
      false,
      progressPaint,
    );

    // 3. Score Indicator Knob Dot at current score point
    final currentAngle = startAngle + filledSweepAngle;
    final dotX = center.dx + radius * math.cos(currentAngle);
    final dotY = center.dy + radius * math.sin(currentAngle);

    final dotPaint = Paint()..color = const Color(0xFF047857);
    final dotInnerPaint = Paint()..color = Colors.white;

    canvas.drawCircle(Offset(dotX, dotY), 5.5, dotPaint);
    canvas.drawCircle(Offset(dotX, dotY), 2.5, dotInnerPaint);

    // 4. "0" and "100" Text Labels at the base
    const textStyle = TextStyle(
      color: Color(0xFF64748B),
      fontSize: 8.5,
      fontWeight: FontWeight.w600,
    );

    final textPainter0 = TextPainter(
      text: const TextSpan(text: '0', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter0.paint(canvas, Offset(center.dx - radius - 2, center.dy + 3));

    final textPainter100 = TextPainter(
      text: const TextSpan(text: '100', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter100.paint(canvas, Offset(center.dx + radius - textPainter100.width + 2, center.dy + 3));
  }

  @override
  bool shouldRepaint(covariant _RadialArcGaugePainter oldDelegate) => oldDelegate.score != score;
}
