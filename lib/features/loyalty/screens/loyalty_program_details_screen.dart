import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/models/loyalty_program_model.dart';
import '../../../core/services/loyalty_service.dart';
import '../../campaign/mobile/campaign_style.dart';
import '../../campaign/mobile/customer_style.dart';
import 'create_loyalty_program_screen.dart';

class LoyaltyProgramDetailsScreen extends StatefulWidget {
  final LoyaltyProgramModel program;
  final VoidCallback? onProgramChanged;

  const LoyaltyProgramDetailsScreen({
    super.key,
    required this.program,
    this.onProgramChanged,
  });

  @override
  State<LoyaltyProgramDetailsScreen> createState() =>
      _LoyaltyProgramDetailsScreenState();
}

class _LoyaltyProgramDetailsScreenState
    extends State<LoyaltyProgramDetailsScreen> {
  static const List<String> _dateRangeOptions = [
    'Today',
    'Last 7 Days',
    'Last 30 Days',
    'Last 90 Days',
    'This Month',
    'All Time',
  ];

  final LoyaltyService _loyaltyService = LoyaltyService();
  final NumberFormat _intCurrencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final NumberFormat _decCurrencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  late LoyaltyProgramModel _currentProgram;
  late bool _isActive;
  bool _isToggling = false;
  bool _isLoadingAnalytics = false;
  String _selectedDateRange = 'Last 30 Days';
  LoyaltyPerformanceModel? _performance;

  @override
  void initState() {
    super.initState();
    _currentProgram = widget.program;
    _isActive = widget.program.isActive;
    _loadAnalytics();
  }

  Future<void> _loadAnalytics({bool forceRefresh = false}) async {
    if (mounted) setState(() => _isLoadingAnalytics = true);
    try {
      final perf = await _loyaltyService.fetchProgramPerformance(
        forceRefresh: forceRefresh,
        dateRange: _selectedDateRange,
        programId: _currentProgram.id,
      );
      if (!mounted) return;
      setState(() {
        if (perf != null) _performance = perf;
        _isLoadingAnalytics = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingAnalytics = false);
    }
  }

  Future<void> _refreshAll() async {
    try {
      final branding = await _loyaltyService.fetchLoyaltyPrograms(
        forceRefresh: true,
      );
      final updated = branding.programs
          .where((p) => p.id == _currentProgram.id)
          .firstOrNull;
      if (mounted && updated != null) {
        setState(() {
          _currentProgram = updated;
          _isActive = updated.isActive;
        });
      }
    } catch (_) {}
    await _loadAnalytics(forceRefresh: true);
  }

  Future<void> _handleToggle(bool value) async {
    setState(() {
      _isToggling = true;
      _isActive = value;
    });

    final ok = await _loyaltyService.updateProgramStatus(
      _currentProgram.id,
      isActive: value,
    );

    if (!mounted) return;
    setState(() {
      _isToggling = false;
      if (ok) {
        _currentProgram = _currentProgram.copyWith(isActive: value);
        widget.onProgramChanged?.call();
      } else {
        _isActive = !value;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (value
                    ? 'Program activated successfully'
                    : 'Program deactivated successfully')
              : 'Could not update program status',
        ),
        backgroundColor: ok
            ? (value ? const Color(0xFF10B981) : Colors.black87)
            : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Deactivate Program?',
          style: campaignText(18, weight: FontWeight.w800),
        ),
        content: Text(
          'Are you sure you want to deactivate "${_currentProgram.title}"? Customers will no longer earn or redeem cashback for this program.',
          style: campaignText(13.5, color: muted, weight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: campaignText(14, color: muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _handleToggle(false);
    }
  }

  Future<void> _openEditProgram() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateLoyaltyProgramScreen(
          programToEdit: _currentProgram,
          onSaved: () => widget.onProgramChanged?.call(),
        ),
      ),
    );
    if (updated == true && mounted) {
      widget.onProgramChanged?.call();
      await _refreshAll();
    }
  }

  void _showEligibleCustomersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: Color(0xFF6D28D9),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Eligible Customers',
                      style: campaignText(17, weight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Targeting: ${_currentProgram.eligibleCustomers}',
                        style: campaignText(
                          14,
                          weight: FontWeight.w700,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This cashback program applies to ${_currentProgram.orderTypes.join(', ')} orders with a minimum bill of ${_formatCurrency(_currentProgram.minimumOrder)}.',
                style: campaignText(13, color: muted, weight: FontWeight.w500),
              ),
              if (_currentProgram.orderTypes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final type in _currentProgram.orderTypes)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          type,
                          style: campaignText(
                            11.5,
                            color: const Color(0xFF334155),
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAllTransactionsSheet() {
    final allRows = _performance?.recentActivity ?? const [];
    String statusFilter = 'All';
    String searchQuery = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = allRows.where((tx) {
            final isRedeem = _isTransactionRedeemed(tx);
            if (statusFilter == 'Redeemed' && !isRedeem) return false;
            if (statusFilter == 'Earned' && isRedeem) return false;
            if (searchQuery.isNotEmpty) {
              final q = searchQuery.toLowerCase();
              final matchesPhone = tx.customerPhone.toLowerCase().contains(q);
              final matchesOrder = tx.orderNumber.toLowerCase().contains(q);
              if (!matchesPhone && !matchesOrder) return false;
            }
            return true;
          }).toList();

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.78,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE9FE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: Color(0xFF6D28D9),
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'All Cashback Transactions',
                                style: campaignText(
                                  16.5,
                                  weight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '$_selectedDateRange · ${filtered.length} records',
                                style: campaignText(
                                  11.5,
                                  color: muted,
                                  weight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        onChanged: (v) =>
                            setSheetState(() => searchQuery = v.trim()),
                        style: campaignText(13, weight: FontWeight.w500),
                        decoration: const InputDecoration(
                          hintText: 'Search customer phone or order ID...',
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF94A3B8),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final opt in const ['All', 'Redeemed', 'Earned'])
                          ChoiceChip(
                            label: Text(opt),
                            selected: statusFilter == opt,
                            selectedColor: const Color(0xFF0E7490),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusFilter == opt
                                  ? Colors.white
                                  : const Color(0xFF334155),
                            ),
                            backgroundColor: const Color(0xFFF1F5F9),
                            side: BorderSide.none,
                            onSelected: (_) =>
                                setSheetState(() => statusFilter = opt),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No cashback transactions found for this filter.',
                                style: campaignText(
                                  13,
                                  color: muted,
                                  weight: FontWeight.w500,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: _buildTransactionsTable(
                                filtered,
                                showEmptyInside: false,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // FORMATTING & DATA HELPERS
  // =========================================================================

  String get _heroSubtitle {
    if (_currentProgram.earningRule.trim().isNotEmpty) {
      return _currentProgram.earningRule.trim();
    }
    if (_currentProgram.cashbackType == 'percentage') {
      final pct = _cleanNum(_currentProgram.cashbackPercentage);
      return 'Get $pct% cashback on all orders';
    }
    return 'Get ₹${_cleanNum(_currentProgram.cashbackAmount)} cashback on orders';
  }

  String _cleanNum(double value) {
    if (value == value.truncateToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  String _formatCurrency(double amount, {bool forceTwoDecimals = false}) {
    if (forceTwoDecimals || amount != amount.truncateToDouble()) {
      return _decCurrencyFormat.format(amount);
    }
    return _intCurrencyFormat.format(amount);
  }

  String _formatPhoneDisplay(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return '—';
    final digits = clean.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      final ten = digits.substring(2);
      return '+91 ${ten.substring(0, 5)} ${ten.substring(5)}';
    }
    return clean;
  }

  bool _isTransactionRedeemed(RecentActivityModel tx) {
    return tx.status.toLowerCase().contains('redeem') ||
        tx.action.toLowerCase().contains('redeem');
  }

  String _formatTransactionDate(RecentActivityModel tx) {
    final parsed = DateTime.tryParse(tx.createdAt);
    if (parsed != null) {
      final ist = parsed.toUtc().add(const Duration(hours: 5, minutes: 30));
      return DateFormat('dd MMM yyyy, hh:mm a').format(ist);
    }
    return tx.date.isNotEmpty ? tx.date : '—';
  }

  String _formattedDateWindow() {
    final cb = _performance?.cashbackMetrics;
    if (cb != null && cb.dateRangeStart.isNotEmpty && cb.dateRangeEnd.isNotEmpty) {
      final start = DateTime.tryParse(cb.dateRangeStart);
      final end = DateTime.tryParse(cb.dateRangeEnd);
      if (start != null && end != null) {
        if (_selectedDateRange == 'All Time') return 'All Time';
        final sLocal = start.toLocal();
        final eLocal = end.toLocal();
        if (_selectedDateRange == 'Today') {
          return DateFormat('dd MMM yyyy').format(eLocal);
        }
        return '${DateFormat('dd MMM yyyy').format(sLocal)} – ${DateFormat('dd MMM yyyy').format(eLocal)}';
      }
    }

    final now = DateTime.now();
    switch (_selectedDateRange) {
      case 'Today':
        return DateFormat('dd MMM yyyy').format(now);
      case 'Last 7 Days':
        final start = now.subtract(const Duration(days: 6));
        return '${DateFormat('dd MMM yyyy').format(start)} – ${DateFormat('dd MMM yyyy').format(now)}';
      case 'Last 30 Days':
        final start = now.subtract(const Duration(days: 29));
        return '${DateFormat('dd MMM yyyy').format(start)} – ${DateFormat('dd MMM yyyy').format(now)}';
      case 'Last 90 Days':
        final start = now.subtract(const Duration(days: 89));
        return '${DateFormat('dd MMM yyyy').format(start)} – ${DateFormat('dd MMM yyyy').format(now)}';
      case 'This Month':
        final start = DateTime(now.year, now.month, 1);
        return '${DateFormat('dd MMM yyyy').format(start)} – ${DateFormat('dd MMM yyyy').format(now)}';
      case 'All Time':
        return 'All Time';
      default:
        return _selectedDateRange;
    }
  }

  _CashbackDisplayStats _resolvedStats() {
    final cb = _performance?.cashbackMetrics;
    if (_performance != null && cb != null) {
      final hasLiveTxData =
          cb.totalCustomers > 0 ||
          cb.ordersCount > 0 ||
          cb.cashbackGiven > 0 ||
          cb.totalRevenue > 0;
      if (hasLiveTxData) {
        return _CashbackDisplayStats(
          totalCustomers: cb.totalCustomers,
          ordersCount: cb.ordersCount,
          cashbackGiven: cb.cashbackGiven,
          redemptionRate: cb.redemptionRate,
          revenue: cb.totalRevenue,
          revenueGrowthPercent: cb.revenueGrowthPercent,
          avgRevenuePerRedemption: cb.avgRevenuePerRedemption,
        );
      }
    }

    // Offline / initial fallback to cached program stats
    return _CashbackDisplayStats(
      totalCustomers: _currentProgram.membersCount,
      ordersCount: _currentProgram.ordersCount,
      cashbackGiven: _currentProgram.cashbackGiven,
      redemptionRate: _currentProgram.redemptionRate,
      revenue: _performance?.totalRevenue ?? 0.0,
      revenueGrowthPercent: cb?.revenueGrowthPercent,
      avgRevenuePerRedemption: cb?.avgRevenuePerRedemption ?? 0.0,
    );
  }

  // =========================================================================
  // BUILD & RESPONSIVE LAYOUT
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useMobileShell =
            (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS)) ||
            constraints.maxWidth < 860;

        if (useMobileShell) {
          return CustomerShell(
            header: _buildTopHeader(),
            body: RefreshIndicator(
              onRefresh: _refreshAll,
              color: const Color(0xFF0E9F6E),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProgramHeroCard(),
                    const SizedBox(height: 11),
                    _buildDateRangeBar(),
                    const SizedBox(height: 11),
                    if (_isLoadingAnalytics)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                          child: LinearProgressIndicator(
                            minHeight: 2.5,
                            color: Color(0xFF10B981),
                            backgroundColor: Color(0xFFD1FAE5),
                          ),
                        ),
                      ),
                    _buildKpiGrid(),
                    const SizedBox(height: 12),
                    _buildProgramDetailsCard(),
                    const SizedBox(height: 12),
                    _buildRecentTransactionsCard(),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
            footer: _buildStickyActionFooter(),
          );
        }

        return _buildDesktopLayout();
      },
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Back',
          ),
          const SizedBox(width: 2),
          const Expanded(
            child: Text(
              'Cashback Program',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. HERO STATUS BANNER
  // =========================================================================

  Widget _buildProgramHeroCard() {
    final gradientColors = _isActive
        ? const [Color(0xFF0A665B), Color(0xFF0E8F76), Color(0xFF13B888)]
        : const [Color(0xFF475569), Color(0xFF64748B)];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                (_isActive ? const Color(0xFF0E8F76) : const Color(0xFF334155))
                    .withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            // Smooth layered organic wave shapes matching the design mockup
            Positioned.fill(
              child: CustomPaint(
                painter: _HeroWavePainter(isActive: _isActive),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // White Glossy Circle with Rupee Loop Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CustomPaint(
                          painter: _CashbackRupeePainter(
                            color: _isActive
                                ? const Color(0xFF0E8F76)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title, Subtitle & Active Pill
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentProgram.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.2,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _heroSubtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.88),
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _isActive
                                ? const Color(0xFFBBF7D0)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6.5,
                                height: 6.5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isActive
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _isActive
                                      ? const Color(0xFF065F46)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Glossy Toggle Switch
                  _GlossyStatusSwitch(
                    value: _isActive,
                    busy: _isToggling,
                    onChanged: _handleToggle,
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
  // 2. DATE RANGE FILTER BAR
  // =========================================================================

  Widget _buildDateRangeBar() {
    final rangeSpan = _formattedDateWindow();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFDDEAF5), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2942).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 330;
          final selectorChip = PopupMenuButton<String>(
            initialValue: _selectedDateRange,
            onSelected: (value) {
              if (value == _selectedDateRange) return;
              setState(() => _selectedDateRange = value);
              _loadAnalytics(forceRefresh: true);
            },
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            itemBuilder: (ctx) => [
              for (final opt in _dateRangeOptions)
                PopupMenuItem<String>(
                  value: opt,
                  child: Row(
                    children: [
                      Icon(
                        opt == _selectedDateRange
                            ? Icons.check_circle_rounded
                            : Icons.calendar_today_outlined,
                        size: 16,
                        color: opt == _selectedDateRange
                            ? const Color(0xFF0E8F76)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        opt,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: opt == _selectedDateRange
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: const Color(0xFF0F1E36),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedDateRange,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F1E36),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: Color(0xFF475569),
                  ),
                ],
              ),
            ),
          );

          final dateWindowWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.date_range_outlined,
                size: 14.5,
                color: Color(0xFF475569),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  rangeSpan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
            ],
          );

          if (isCompact) {
            return Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: Color(0xFF1E3A5F),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Date Range',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F1E36),
                      ),
                    ),
                    const SizedBox(width: 6),
                    selectorChip,
                  ],
                ),
                dateWindowWidget,
              ],
            );
          }

          return Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                size: 16.5,
                color: Color(0xFF1E3A5F),
              ),
              const SizedBox(width: 5),
              const Text(
                'Date Range',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F1E36),
                ),
              ),
              const SizedBox(width: 7),
              selectorChip,
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: const Color(0xFFCBD5E1),
              ),
              Expanded(child: dateWindowWidget),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // 3. 3x2 KPI GRID (6 COLORED GLASS CARDS)
  // =========================================================================

  Widget _buildKpiGrid() {
    final stats = _resolvedStats();
    final intFmt = NumberFormat.decimalPattern('en_IN');

    final cards = [
      _KpiCardData(
        label: 'Total Customers',
        value: intFmt.format(stats.totalCustomers),
        icon: Icons.groups_rounded,
        iconColor: const Color(0xFF16A34A),
        gradient: const [Color(0xFFE7FBEF), Color(0xFFD3F7E2)],
        waveColor: const Color(0xFF86EFAC),
      ),
      _KpiCardData(
        label: 'Orders',
        value: intFmt.format(stats.ordersCount),
        icon: Icons.shopping_cart_outlined,
        iconColor: const Color(0xFF6D28D9),
        gradient: const [Color(0xFFF3EEFF), Color(0xFFE6DCFE)],
        waveColor: const Color(0xFFC4B5FD),
      ),
      _KpiCardData(
        label: 'Cashback Given',
        value: _formatCurrency(stats.cashbackGiven),
        icon: Icons.toll_rounded,
        iconColor: const Color(0xFF0284C7),
        gradient: const [Color(0xFFE8F4FF), Color(0xFFD5EBFF)],
        waveColor: const Color(0xFF93C5FD),
      ),
      _KpiCardData(
        label: 'Redemption Rate',
        value: '${stats.redemptionRate.toStringAsFixed(2)}%',
        icon: Icons.card_giftcard_rounded,
        iconColor: const Color(0xFFEA580C),
        gradient: const [Color(0xFFFFF2E2), Color(0xFFFFE4C4)],
        waveColor: const Color(0xFFFDBA74),
      ),
      _KpiCardData(
        label: 'Revenue',
        value: _formatCurrency(stats.revenue),
        icon: Icons.trending_up_rounded,
        iconColor: const Color(0xFF059669),
        gradient: const [Color(0xFFE6FBF0), Color(0xFFD0F6E2)],
        waveColor: const Color(0xFF6EE7B7),
        growthPercent: stats.revenueGrowthPercent,
      ),
      _KpiCardData(
        label: 'Avg. Revenue / Redemption',
        value: _formatCurrency(stats.avgRevenuePerRedemption),
        icon: Icons.currency_rupee_rounded,
        circledIcon: true,
        iconColor: const Color(0xFFDB2777),
        gradient: const [Color(0xFFFDECF5), Color(0xFFF9DBE9)],
        waveColor: const Color(0xFFF9A8D4),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 325 ? 3 : 2;
        final rows = <Widget>[];
        for (int i = 0; i < cards.length; i += cols) {
          final slice = cards.sublist(i, math.min(i + cols, cards.length));
          rows.add(
            Padding(
              padding: EdgeInsets.only(bottom: i + cols < cards.length ? 8 : 0),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int c = 0; c < slice.length; c++) ...[
                      if (c > 0) const SizedBox(width: 8),
                      Expanded(child: _buildKpiTile(slice[c])),
                    ],
                    for (int pad = slice.length; pad < cols; pad++) ...[
                      const SizedBox(width: 8),
                      const Expanded(child: SizedBox()),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }

  Widget _buildKpiTile(_KpiCardData data) {
    final growth = data.growthPercent;
    final hasGrowth = growth != null && growth != 0;
    final isPositive = (growth ?? 0) >= 0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: data.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: data.iconColor.withValues(alpha: 0.11),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -18,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: data.waveColor.withValues(alpha: 0.28),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 9, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (data.circledIcon)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: data.iconColor, width: 1.7),
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    child: Icon(data.icon, color: data.iconColor, size: 14),
                  )
                else
                  Icon(data.icon, color: data.iconColor, size: 21),
                const SizedBox(height: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        data.value,
                        style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F1E36),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (hasGrowth) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isPositive
                                ? const Color(0xFFBBF7D0)
                                : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${isPositive ? '↑ +' : '↓ '}${growth.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isPositive
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. PROGRAM DETAILS CARD
  // =========================================================================

  Widget _buildProgramDetailsCard() {
    final cashbackText = _currentProgram.cashbackType == 'percentage'
        ? '${_cleanNum(_currentProgram.cashbackPercentage)}% of order value'
        : '₹${_cleanNum(_currentProgram.cashbackAmount)} per order';
    final minOrderText = _currentProgram.minimumOrder > 0
        ? _formatCurrency(_currentProgram.minimumOrder)
        : 'No minimum';
    final maxCashbackText = _currentProgram.maximumCashback > 0
        ? '${_formatCurrency(_currentProgram.maximumCashback)} per order'
        : 'No limit';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8F3), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2942).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF6D28D9),
                  size: 17,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Program Details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F1E36),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            icon: Icons.local_offer_outlined,
            label: 'Program Type',
            valueWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Cashback',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF15803D),
                ),
              ),
            ),
          ),
          const Divider(height: 16, thickness: 0.8, color: Color(0xFFF1F5F9)),
          _buildDetailRow(
            icon: Icons.percent_rounded,
            label: 'Cashback',
            value: cashbackText,
          ),
          const Divider(height: 16, thickness: 0.8, color: Color(0xFFF1F5F9)),
          _buildDetailRow(
            icon: Icons.shopping_cart_outlined,
            label: 'Minimum Order',
            value: minOrderText,
          ),
          const Divider(height: 16, thickness: 0.8, color: Color(0xFFF1F5F9)),
          _buildDetailRow(
            icon: Icons.toll_rounded,
            label: 'Maximum Cashback',
            value: maxCashbackText,
          ),
          const Divider(height: 16, thickness: 0.8, color: Color(0xFFF1F5F9)),
          _buildDetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Validity',
            value: _currentProgram.validity.isNotEmpty
                ? _currentProgram.validity
                : 'Continuous',
          ),
          const Divider(height: 16, thickness: 0.8, color: Color(0xFFF1F5F9)),
          _buildDetailRow(
            icon: Icons.groups_outlined,
            label: 'Eligible Customers',
            value: _currentProgram.eligibleCustomers,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    String? value,
    Widget? valueWidget,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF16A34A)),
        const SizedBox(width: 9),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child:
                valueWidget ??
                Text(
                  value ?? '',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F1E36),
                  ),
                ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 5. RECENT TRANSACTIONS TABLE CARD
  // =========================================================================

  Widget _buildRecentTransactionsCard() {
    final allTransactions = _performance?.recentActivity ?? const [];
    final previewRows = allTransactions.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE8F3), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F2942).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.format_list_bulleted_rounded,
                  color: Color(0xFF6D28D9),
                  size: 17,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Recent Transactions',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F1E36),
                  ),
                ),
              ),
              InkWell(
                onTap: _showAllTransactionsSheet,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: Color(0xFF0284C7),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          _buildTransactionsTable(previewRows, showEmptyInside: true),
        ],
      ),
    );
  }

  Widget _buildTransactionsTable(
    List<RecentActivityModel> rows, {
    required bool showEmptyInside,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tableWidth = math.max(constraints.maxWidth, 510.0);
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dark Teal Header Row matching screenshot
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0A4F5C), Color(0xFF0E7490)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 24, child: _TableHeaderCell('Customer')),
                          Expanded(flex: 15, child: _TableHeaderCell('Order ID')),
                          Expanded(
                            flex: 16,
                            child: _TableHeaderCell(
                              'Order Value',
                              align: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            flex: 15,
                            child: _TableHeaderCell(
                              'Cashback',
                              align: TextAlign.right,
                            ),
                          ),
                          Expanded(
                            flex: 19,
                            child: _TableHeaderCell(
                              'Status',
                              align: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            flex: 28,
                            child: _TableHeaderCell(
                              'Date',
                              align: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (rows.isEmpty && showEmptyInside)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 22,
                          horizontal: 16,
                        ),
                        color: const Color(0xFFF8FAFC),
                        child: Text(
                          _isLoadingAnalytics
                              ? 'Loading transactions...'
                              : 'No cashback transactions recorded for $_selectedDateRange.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      )
                    else
                      for (int i = 0; i < rows.length; i++)
                        _buildTransactionRow(rows[i], isEven: i.isEven),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTransactionRow(
    RecentActivityModel tx, {
    required bool isEven,
  }) {
    final isRedeemed = _isTransactionRedeemed(tx);
    final orderLabel = tx.orderNumber.isNotEmpty
        ? (tx.orderNumber.startsWith('#') ? tx.orderNumber : '#${tx.orderNumber}')
        : '—';
    final orderValueStr =
        tx.orderValue > 0 ? _formatCurrency(tx.orderValue) : '—';
    final cashbackStr = _formatCurrency(
      tx.cashbackAmount,
      forceTwoDecimals: true,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF8FAFC),
        border: const Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 24,
            child: Text(
              _formatPhoneDisplay(tx.customerPhone),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          Expanded(
            flex: 15,
            child: Text(
              orderLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D9488),
              ),
            ),
          ),
          Expanded(
            flex: 16,
            child: Text(
              orderValueStr,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F1E36),
              ),
            ),
          ),
          Expanded(
            flex: 15,
            child: Text(
              cashbackStr,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F1E36),
              ),
            ),
          ),
          Expanded(
            flex: 19,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isRedeemed
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRedeemed
                          ? Icons.check_rounded
                          : Icons.access_time_rounded,
                      size: 10.5,
                      color: isRedeemed
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        isRedeemed ? 'Redeemed' : 'Earned',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isRedeemed
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 28,
            child: Text(
              _formatTransactionDate(tx),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 6. BOTTOM 3 ACTION CARDS
  // =========================================================================

  Widget _buildStickyActionFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD).withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1),
        ),
      ),
      child: _buildActionButtonsRow(),
    );
  }

  Widget _buildActionButtonsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildActionCardButton(
            icon: Icons.edit_note_rounded,
            label: 'Edit Program',
            iconColor: const Color(0xFF0284C7),
            textColor: const Color(0xFF0F1E36),
            onTap: _openEditProgram,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionCardButton(
            icon: Icons.groups_rounded,
            label: 'Eligible Customers',
            iconColor: const Color(0xFF6D28D9),
            textColor: const Color(0xFF0F1E36),
            onTap: _showEligibleCustomersSheet,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionCardButton(
            icon: _isActive
                ? Icons.delete_outline_rounded
                : Icons.power_settings_new_rounded,
            label: _isActive ? 'Deactivate' : 'Activate',
            iconColor: _isActive
                ? const Color(0xFFDC2626)
                : const Color(0xFF059669),
            textColor: _isActive
                ? const Color(0xFFDC2626)
                : const Color(0xFF059669),
            bgColor: _isActive
                ? const Color(0xFFFFF1F2)
                : const Color(0xFFECFDF5),
            borderColor: _isActive
                ? const Color(0xFFFECDD3)
                : const Color(0xFFA7F3D0),
            onTap: _isActive ? _confirmDeactivate : () => _handleToggle(true),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCardButton({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color textColor,
    Color? bgColor,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor ?? Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: borderColor ?? const Color(0xFFDCE8F3),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F2942).withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(height: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // DESKTOP & WIDE WEB RESPONSIVE LAYOUT
  // =========================================================================

  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF061E38),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cashback Program',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              _currentProgram.title,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _openEditProgram,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF08435E),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text(
                  'Edit Program',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          color: const Color(0xFF0E8F76),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProgramHeroCard(),
                    const SizedBox(height: 16),
                    _buildDateRangeBar(),
                    const SizedBox(height: 16),
                    if (_isLoadingAnalytics)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                          child: LinearProgressIndicator(
                            minHeight: 2.5,
                            color: Color(0xFF10B981),
                            backgroundColor: Color(0xFFD1FAE5),
                          ),
                        ),
                      ),
                    _buildKpiGrid(),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: _buildProgramDetailsCard()),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 6,
                          child: _buildRecentTransactionsCard(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: _buildActionButtonsRow(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// DATA & CUSTOM PAINTER HELPERS
// ===========================================================================

class _CashbackDisplayStats {
  final int totalCustomers;
  final int ordersCount;
  final double cashbackGiven;
  final double redemptionRate;
  final double revenue;
  final double? revenueGrowthPercent;
  final double avgRevenuePerRedemption;

  const _CashbackDisplayStats({
    required this.totalCustomers,
    required this.ordersCount,
    required this.cashbackGiven,
    required this.redemptionRate,
    required this.revenue,
    required this.revenueGrowthPercent,
    required this.avgRevenuePerRedemption,
  });
}

class _KpiCardData {
  final String label;
  final String value;
  final IconData icon;
  final bool circledIcon;
  final Color iconColor;
  final List<Color> gradient;
  final Color waveColor;
  final double? growthPercent;

  const _KpiCardData({
    required this.label,
    required this.value,
    required this.icon,
    this.circledIcon = false,
    required this.iconColor,
    required this.gradient,
    required this.waveColor,
    this.growthPercent,
  });
}

class _TableHeaderCell extends StatelessWidget {
  final String label;
  final TextAlign align;

  const _TableHeaderCell(this.label, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }
}

class _GlossyStatusSwitch extends StatelessWidget {
  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  const _GlossyStatusSwitch({
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      label: value ? 'Deactivate cashback program' : 'Activate cashback program',
      child: GestureDetector(
        onTap: busy ? null : () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 54,
          height: 30,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: value
                  ? const [Color(0xFF16A34A), Color(0xFF22C55E)]
                  : const [Color(0xFF94A3B8), Color(0xFF64748B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.45),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(5),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0E8F76),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroWavePainter extends CustomPainter {
  final bool isActive;
  const _HeroWavePainter({required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final wave1 = Paint()
      ..color = Colors.white.withValues(alpha: isActive ? 0.14 : 0.08)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(size.width * 0.45, size.height)
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.45,
        size.width * 0.78,
        size.height * 0.56,
      )
      ..quadraticBezierTo(
        size.width * 0.90,
        size.height * 0.65,
        size.width,
        size.height * 0.35,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path1, wave1);

    final wave2 = Paint()
      ..color = Colors.white.withValues(alpha: isActive ? 0.10 : 0.05)
      ..style = PaintingStyle.fill;

    final path2 = Path()
      ..moveTo(size.width * 0.60, size.height)
      ..quadraticBezierTo(
        size.width * 0.76,
        size.height * 0.68,
        size.width,
        size.height * 0.55,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path2, wave2);
  }

  @override
  bool shouldRepaint(covariant _HeroWavePainter oldDelegate) =>
      oldDelegate.isActive != isActive;
}

class _CashbackRupeePainter extends CustomPainter {
  final Color color;
  const _CashbackRupeePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.44;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;

    // Top circular arc + arrowhead
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -2.65,
      2.3,
      false,
      stroke,
    );
    // Bottom circular arc + arrowhead
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.48,
      2.3,
      false,
      stroke,
    );

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Right arrowhead at end of top arc (~ -0.35 rad)
    final topTip = Offset(
      center.dx + radius * math.cos(-0.35),
      center.dy + radius * math.sin(-0.35),
    );
    final topArrow = Path()
      ..moveTo(topTip.dx + 1.5, topTip.dy + 2.5)
      ..lineTo(topTip.dx - 4.5, topTip.dy - 1.0)
      ..lineTo(topTip.dx + 1.5, topTip.dy - 4.0)
      ..close();
    canvas.drawPath(topArrow, fill);

    // Left arrowhead at end of bottom arc (~ 2.78 rad)
    final botTip = Offset(
      center.dx + radius * math.cos(2.78),
      center.dy + radius * math.sin(2.78),
    );
    final botArrow = Path()
      ..moveTo(botTip.dx - 1.5, botTip.dy - 2.5)
      ..lineTo(botTip.dx + 4.5, botTip.dy + 1.0)
      ..lineTo(botTip.dx - 1.5, botTip.dy + 4.0)
      ..close();
    canvas.drawPath(botArrow, fill);

    // Centered ₹ symbol
    final tp = TextPainter(
      text: TextSpan(
        text: '₹',
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: color,
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
  bool shouldRepaint(covariant _CashbackRupeePainter oldDelegate) =>
      oldDelegate.color != color;
}
