import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../core/database/database_service.dart';
import '../../core/services/dashboard_service.dart';
import '../../core/services/report_service.dart';
import '../../core/models/order_model.dart';

/// Glass Liquid UI Dashboard Screen matching Apna POS design theme
class GlassDashboardScreen extends StatefulWidget {
  final Function(int index)? onNavigateTab;
  final bool isActive;

  const GlassDashboardScreen({
    super.key,
    this.onNavigateTab,
    this.isActive = true,
  });

  @override
  State<GlassDashboardScreen> createState() => GlassDashboardScreenState();
}

class GlassDashboardScreenState extends State<GlassDashboardScreen> {
  final DatabaseService _db = DatabaseService();
  final DashboardService _dashboardService = DashboardService();

  String _dashboardFilter = 'Today';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Cloud API State
  bool _isManualRefreshing = false;
  String? _errorMessage;
  DashboardSummaryData _summaryData = DashboardSummaryData();
  OrderTypeStatsData _orderTypesData = OrderTypeStatsData.empty();
  List<ItemSaleReportItem> _productSales = [];
  CustomerAnalyticsData _customerData = CustomerAnalyticsData();
  PaymentMethodsSummaryData _paymentMethodsData = PaymentMethodsSummaryData();
  TaxSummaryData _taxData = TaxSummaryData();
  OrderStatsSummaryData _orderStatsData = OrderStatsSummaryData();

  @override
  void initState() {
    super.initState();
    _db.addListener(_onDbChange);
    // Instant initial render from local cache if available
    if (_db.orders.isNotEmpty) {
      final initialLocal = _computeLocalDashboardData(_dashboardFilter, _customStartDate, _customEndDate);
      if (initialLocal != null) {
        _summaryData = initialLocal.summary;
        _orderTypesData = initialLocal.orderTypes;
        _productSales = initialLocal.productSales;
        _customerData = initialLocal.customers;
        _paymentMethodsData = initialLocal.payments;
        _taxData = initialLocal.taxes;
        _orderStatsData = initialLocal.orderStats;
      }
    }
    _loadDashboardData(isManual: false);
  }

  @override
  void didUpdateWidget(covariant GlassDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadDashboardData(isManual: false);
    }
  }

  void refreshDashboard() {
    _loadDashboardData(isManual: false);
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChange);
    super.dispose();
  }

  void _onDbChange() {
    if (!mounted) return;
    if (widget.isActive) {
      _loadDashboardData(isManual: false);
    } else {
      final localData = _computeLocalDashboardData(_dashboardFilter, _customStartDate, _customEndDate);
      if (localData != null && mounted) {
        setState(() {
          _summaryData = localData.summary;
          _orderTypesData = localData.orderTypes;
          _productSales = localData.productSales;
          _customerData = localData.customers;
          _paymentMethodsData = localData.payments;
          _taxData = localData.taxes;
          _orderStatsData = localData.orderStats;
        });
      }
    }
  }

  DateTimeRange _getFilterDateRange() {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    if (_dashboardFilter == 'Custom Date' && _customStartDate != null && _customEndDate != null) {
      start = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day, 0, 0, 0);
      end = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59, 999);
    } else {
      final p = _dashboardFilter.toLowerCase();
      if (p == 'yesterday') {
        final y = now.subtract(const Duration(days: 1));
        start = DateTime(y.year, y.month, y.day, 0, 0, 0);
        end = DateTime(y.year, y.month, y.day, 23, 59, 59, 999);
      } else if (p == 'week' || p == 'this week') {
        final diff = (now.weekday == 7 ? 6 : now.weekday - 1);
        final mon = now.subtract(Duration(days: diff));
        start = DateTime(mon.year, mon.month, mon.day, 0, 0, 0);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      } else if (p == 'month' || p == 'this month') {
        start = DateTime(now.year, now.month, 1, 0, 0, 0);
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        end = DateTime(now.year, now.month, lastDay, 23, 59, 59, 999);
      } else if (p == 'year' || p == 'this year') {
        start = DateTime(now.year, 1, 1, 0, 0, 0);
        end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
      } else if (p == 'all time' || p == 'all') {
        start = DateTime(2020, 1, 1, 0, 0, 0);
        end = DateTime(now.year + 1, 12, 31, 23, 59, 59, 999);
      } else {
        // Today default
        start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      }
    }
    return DateTimeRange(start: start, end: end);
  }

  String get _startDateParam {
    final range = _getFilterDateRange();
    return range.start.toUtc().toIso8601String();
  }

  String get _endDateParam {
    final range = _getFilterDateRange();
    return range.end.toUtc().toIso8601String();
  }

  Future<void> _loadDashboardData({bool isManual = false}) async {
    if (!mounted) return;
    if (isManual) {
      setState(() {
        _isManualRefreshing = true;
        _errorMessage = null;
      });
    }

    try {
      final isAuth = await _db.authService.isAuthenticated();
      if (!isAuth) {
        final localData = _computeLocalDashboardData(_dashboardFilter, _customStartDate, _customEndDate);
        if (mounted) {
          setState(() {
            if (localData != null) {
              _summaryData = localData.summary;
              _orderTypesData = localData.orderTypes;
              _productSales = localData.productSales;
              _customerData = localData.customers;
              _paymentMethodsData = localData.payments;
              _taxData = localData.taxes;
              _orderStatsData = localData.orderStats;
            }
            _isManualRefreshing = false;
            _errorMessage = null;
          });
        }
        return;
      }

      final sDate = _startDateParam;
      final eDate = _endDateParam;

      final overview = await _dashboardService.fetchOverview(
        period: _dashboardFilter,
        startDate: sDate,
        endDate: eDate,
      );

      if (mounted) {
        setState(() {
          _summaryData = overview.summary;
          _orderTypesData = overview.orderTypes;
          _productSales = overview.productSales;
          _customerData = overview.customers;
          _paymentMethodsData = overview.paymentMethods;
          _taxData = overview.taxes;
          _orderStatsData = overview.orderStats;
          _isManualRefreshing = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('[GlassDashboardScreen] Error fetching dashboard data: $e');
      if (mounted) {
        final localData = _computeLocalDashboardData(_dashboardFilter, _customStartDate, _customEndDate);
        setState(() {
          if (localData != null) {
            _summaryData = localData.summary;
            _orderTypesData = localData.orderTypes;
            _productSales = localData.productSales;
            _customerData = localData.customers;
            _paymentMethodsData = localData.payments;
            _taxData = localData.taxes;
            _orderStatsData = localData.orderStats;
          }
          _isManualRefreshing = false;
          _errorMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadDashboardData(isManual: true),
          color: const Color(0xFF0284C7),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 12 : 24,
                  isMobile ? 12 : 20,
                  isMobile ? 12 : 24,
                  isMobile ? 20 : 28,
                ),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Header Bar
                    _buildHeader(),
                    const SizedBox(height: 14),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFFDC2626),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFB91C1C),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 16,
                                color: Color(0xFFDC2626),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _loadDashboardData(isManual: true),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Order Summary Section (Total Orders & Total Revenue)
                    _buildSummaryCards(isMobile),
                    const SizedBox(height: 14),

                    // Order Type Grid (4 Cards: Total Orders, Dine In, Take Away, Delivery)
                    _buildOrderTypeGrid(isMobile),
                    const SizedBox(height: 14),

                    // Product Sales Section
                    _buildProductPerformanceCards(isMobile),
                    const SizedBox(height: 14),

                    // Customer Insights (New & Returning Customers)
                    _buildCustomerInsights(isMobile),
                    const SizedBox(height: 14),

                    // Total Sales & Taxes Section (Aligned side-by-side on Desktop/Tablet, stacked on Mobile)
                    _buildSalesAndTaxesSection(isMobile),
                    const SizedBox(height: 14),

                    // Order Statistics (Successful vs Cancelled vs Total)
                    _buildOrderStatistics(isMobile),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Top Header Bar with Neumorphic Filter Pill & Refresh Button
  Widget _buildHeader() {
    final user = _db.currentUser;
    final isStaff = user != null && !user.isOwner && !user.isAdmin;
    final staffCompanyName = user?.companyName;
    final storeName = _db.restaurant?.name ??
        ((isStaff && staffCompanyName != null && staffCompanyName.isNotEmpty)
            ? staffCompanyName
            : 'Apna POS Diner');

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      storeName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isStaff &&
                      staffCompanyName != null &&
                      staffCompanyName.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6FB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.white,
                            offset: Offset(-1.5, -1.5),
                            blurRadius: 3,
                          ),
                          BoxShadow(
                            color: Color(0x14000000),
                            offset: Offset(1.5, 1.5),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.business_rounded,
                              size: 12, color: Color(0xFF0A1931)),
                          const SizedBox(width: 4),
                          Text(
                            staffCompanyName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0A1931),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                isStaff &&
                        staffCompanyName != null &&
                        staffCompanyName.isNotEmpty
                    ? 'Workplace: $staffCompanyName • Real-Time Business Analytics'
                    : 'Real-Time Cloud Business Analytics',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildDropdownPill(
          value: _dashboardFilter,
          onChanged: (val) {
            setState(() => _dashboardFilter = val);
            _loadDashboardData(isManual: true);
          },
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _loadDashboardData(isManual: true),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-2, -2),
                    blurRadius: 4,
                  ),
                  BoxShadow(
                    color: Color(0x18000000),
                    offset: Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: _isManualRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0284C7),
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: Color(0xFF0284C7),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  /// 1. Order Summary Section
  Widget _buildSummaryCards(bool isMobile) {
    final int totalOrdersCount = _summaryData.totalOrders;
    final double totalRevenue = _summaryData.revenue;
    final String currentDateStr =
        DateFormat('d MMM yyyy').format(DateTime.now());

    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6FB),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.white,
                          offset: Offset(-2, -2),
                          blurRadius: 4,
                        ),
                        BoxShadow(
                          color: Color(0x16000000),
                          offset: Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      color: Color(0xFF9333EA),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.white,
                      offset: Offset(-1.5, -1.5),
                      blurRadius: 3,
                    ),
                    BoxShadow(
                      color: Color(0x10000000),
                      offset: Offset(1.5, 1.5),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: Text(
                  _dashboardFilter,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Metrics in 2 Neumorphic Inset Wells
          Row(
            children: [
              Expanded(
                child: _buildNeumorphicInset(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Orders',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$totalOrdersCount',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildNeumorphicInset(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Revenue',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '₹${totalRevenue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 12,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Text(
                currentDateStr,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Order Type Grid (Dine In, Take Away, Delivery, Total Orders)
  Widget _buildOrderTypeGrid(bool isMobile) {
    final cards = [
      _buildOrderTypeCard(
        title: 'Total Orders',
        amount: _orderTypesData.total.amount,
        count: _orderTypesData.total.count,
        icon: Icons.assignment_rounded,
        accentColor: const Color(0xFF10B981),
      ),
      _buildOrderTypeCard(
        title: 'Dine In',
        amount: _orderTypesData.dineIn.amount,
        count: _orderTypesData.dineIn.count,
        icon: Icons.restaurant_rounded,
        imageAsset: 'assets/images/dinein.png',
        accentColor: const Color(0xFF8B5CF6),
      ),
      _buildOrderTypeCard(
        title: 'Take Away',
        amount: _orderTypesData.takeaway.amount,
        count: _orderTypesData.takeaway.count,
        icon: Icons.local_mall_rounded,
        imageAsset: 'assets/images/takeaway.png',
        accentColor: const Color(0xFF0284C7),
      ),
      _buildOrderTypeCard(
        title: 'Delivery',
        amount: _orderTypesData.delivery.amount,
        count: _orderTypesData.delivery.count,
        icon: Icons.two_wheeler_rounded,
        imageAsset: 'assets/images/delivery.png',
        accentColor: const Color(0xFFF97316),
      ),
    ];

    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isMobile ? 1.3 : 1.4,
      children: cards,
    );
  }

  Widget _buildOrderTypeCard({
    required String title,
    required int count,
    required double amount,
    required IconData icon,
    String? imageAsset,
    required Color accentColor,
  }) {
    return _buildNeumorphicCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FB),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-1.5, -1.5),
                    blurRadius: 3,
                  ),
                  BoxShadow(
                    color: Color(0x14000000),
                    offset: Offset(1.5, 1.5),
                    blurRadius: 3,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: imageAsset != null && imageAsset.isNotEmpty
                  ? Image.asset(
                      imageAsset,
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(icon, color: accentColor, size: 17),
                    )
                  : Icon(icon, color: accentColor, size: 17),
            ),
            const SizedBox(height: 5),
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-1, -1),
                    blurRadius: 2,
                  ),
                  BoxShadow(
                    color: Color(0x10000000),
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: Text(
                '$count Orders',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 3. Top Product Sales Section
  Widget _buildProductPerformanceCards(bool isMobile) {
    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Total sale of item',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.white,
                      offset: Offset(-1.5, -1.5),
                      blurRadius: 3,
                    ),
                    BoxShadow(
                      color: Color(0x10000000),
                      offset: Offset(1.5, 1.5),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: Text(
                  _dashboardFilter,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_productSales.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6FB),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.white,
                            offset: Offset(-2, -2),
                            blurRadius: 4,
                          ),
                          BoxShadow(
                            color: Color(0x16000000),
                            offset: Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFD97706),
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No product sales yet',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Item-wise sales data will appear here\nonce orders are completed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                _buildNeumorphicInset(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text(
                          '#',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Product Name',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Price',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'QTY',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          'Total',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                if (_productSales.length <= 5)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _productSales.length,
                    separatorBuilder: (context, index) =>
                        const Divider(color: Color(0xFFE2E8F0), height: 10),
                    itemBuilder: (context, index) {
                      final p = _productSales[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              child: Text(
                                '${p.srNo > 0 ? p.srNo : index + 1}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                p.productName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: Text(
                                  '₹${p.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                                child: Text(
                                  '${p.quantity}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '₹${p.totalAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  SizedBox(
                    height: 230,
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _productSales.length,
                      separatorBuilder: (context, index) =>
                          const Divider(color: Color(0xFFE2E8F0), height: 10),
                      itemBuilder: (context, index) {
                        final p = _productSales[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                child: Text(
                                  '${p.srNo > 0 ? p.srNo : index + 1}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  p.productName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '₹${p.price.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${p.quantity}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '₹${p.totalAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  /// 4. Customer Insights (New & Returning Customers)
  Widget _buildCustomerInsights(bool isMobile) {
    Widget buildCustomerList(
      List<CustomerInsightItem> list,
      String emptyTitle,
      String emptySubtitle,
      IconData emptyIcon,
      Color iconColor,
      Color iconBg,
    ) {
      if (list.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'NO ROWS YET',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6FB),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.white,
                            offset: Offset(-2, -2),
                            blurRadius: 4,
                          ),
                          BoxShadow(
                            color: Color(0x16000000),
                            offset: Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(emptyIcon, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emptyTitle,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            emptySubtitle,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        separatorBuilder: (context, index) =>
            const Divider(color: Color(0xFFE2E8F0), height: 10),
        itemBuilder: (context, index) {
          final item = list[index];
          return Row(
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name.isEmpty ? 'Customer' : item.name,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.phone.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        item.phone,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.white,
                      offset: Offset(-1, -1),
                      blurRadius: 2,
                    ),
                    BoxShadow(
                      color: Color(0x10000000),
                      offset: Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Visits: ${item.visitCount}',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    Widget newCust = _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('New Customers'),
          const SizedBox(height: 12),
          buildCustomerList(
            _customerData.newCustomers,
            'No new customers in this range',
            'Make a sale to record customer details.',
            Icons.person_add_alt_1_rounded,
            const Color(0xFF3B82F6),
            const Color(0xFFEFF6FF),
          ),
        ],
      ),
    );

    Widget retCust = _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Returning Customers'),
          const SizedBox(height: 12),
          buildCustomerList(
            _customerData.returningCustomers,
            'No returning customers in this range',
            'Repeat guest orders will appear here.',
            Icons.group_rounded,
            const Color(0xFF8B5CF6),
            const Color(0xFFF5F3FF),
          ),
        ],
      ),
    );

    if (isMobile) {
      return Column(children: [newCust, const SizedBox(height: 14), retCust]);
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: newCust),
          const SizedBox(width: 14),
          Expanded(child: retCust),
        ],
      );
    }
  }

  /// 5. Total Sales & Taxes Responsive Combined Layout
  Widget _buildSalesAndTaxesSection(bool isMobile) {
    final salesCard = _buildTotalSales(isMobile);
    final taxesCard = _buildTaxes(isMobile);

    if (isMobile) {
      return Column(
        children: [
          salesCard,
          const SizedBox(height: 14),
          taxesCard,
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: salesCard),
          const SizedBox(width: 14),
          Expanded(child: taxesCard),
        ],
      );
    }
  }

  /// Total Sales by Payment Method
  Widget _buildTotalSales(bool isMobile) {
    double cash = 0, card = 0, upi = 0, split = 0;
    for (var p in _paymentMethodsData.payments) {
      final m = p.method.toUpperCase();
      if (m.contains('CASH')) {
        cash += p.amount;
      } else if (m.contains('CARD')) {
        card += p.amount;
      } else if (m.contains('UPI')) {
        upi += p.amount;
      } else {
        split += p.amount;
      }
    }

    final total = _paymentMethodsData.totalAmount > 0
        ? _paymentMethodsData.totalAmount
        : (cash + card + upi + split);
    final maxVal = [
      cash,
      card,
      upi,
      split,
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Total Sales'),
          const SizedBox(height: 12),
          _buildProgressBarRow('CASH', cash, maxVal, const Color(0xFF0284C7)),
          _buildProgressBarRow('CARD', card, maxVal, const Color(0xFF3B82F6)),
          _buildProgressBarRow('UPI', upi, maxVal, const Color(0xFF8B5CF6)),
          if (split > 0)
            _buildProgressBarRow(
              'OTHER / SPLIT',
              split,
              maxVal,
              const Color(0xFFF59E0B),
            ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-2, -2),
                    blurRadius: 4,
                  ),
                  BoxShadow(
                    color: Color(0x14000000),
                    offset: Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Total: ₹${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 6. Taxes & GST Breakdown
  Widget _buildTaxes(bool isMobile) {
    final double gst = _taxData.totalGST;
    final double cgst = _taxData.cgst;
    final double sgst = _taxData.sgst;

    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Taxes'),
          const SizedBox(height: 12),
          _buildProgressBarRow(
            'TOTAL GST',
            gst,
            gst > 0 ? gst : 1.0,
            const Color(0xFF64748B),
          ),
          _buildProgressBarRow(
            'CGST',
            cgst,
            gst > 0 ? gst : 1.0,
            const Color(0xFF0284C7),
          ),
          _buildProgressBarRow(
            'SGST',
            sgst,
            gst > 0 ? gst : 1.0,
            const Color(0xFF818CF8),
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-2, -2),
                    blurRadius: 4,
                  ),
                  BoxShadow(
                    color: Color(0x14000000),
                    offset: Offset(2, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Total Taxes: ₹${gst.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 7. Order Statistics (Successful vs Cancelled vs Total)
  Widget _buildOrderStatistics(bool isMobile) {
    final int success = _orderStatsData.successfulOrders;
    final int cancelled = _orderStatsData.cancelledOrders;
    final int total = _orderStatsData.totalOrders;

    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Order Statistics'),
          const SizedBox(height: 12),
          _buildStatRow(
            'SUCCESS ORDER:',
            success.toString(),
            const Color(0xFF16A34A),
          ),
          _buildStatRow(
            'CANCELLED ORDER:',
            cancelled.toString(),
            const Color(0xFFDC2626),
          ),
          _buildStatRow(
            'TOTAL ORDERS:',
            total.toString(),
            const Color(0xFF0F172A),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBarRow(
    String label,
    double value,
    double max,
    Color color,
  ) {
    final double safeVal =
        (!value.isNaN && !value.isInfinite && value > 0) ? value : 0.0;
    final double safeMax =
        (!max.isNaN && !max.isInfinite && max > 0) ? max : 1.0;
    double progress = (max > 0) ? (safeVal / safeMax).clamp(0.0, 1.0) : 0.0;
    if (progress.isNaN || progress.isInfinite) progress = 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF3F9),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x10000000),
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-1, -1),
                    blurRadius: 2,
                  ),
                ],
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 75,
            child: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.white,
                    offset: Offset(-1, -1),
                    blurRadius: 2,
                  ),
                  BoxShadow(
                    color: Color(0x10000000),
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '₹${value.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color badgeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.white,
                  offset: Offset(-1.5, -1.5),
                  blurRadius: 3,
                ),
                BoxShadow(
                  color: Color(0x12000000),
                  offset: Offset(1.5, 1.5),
                  blurRadius: 3,
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6FB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Colors.white,
                offset: Offset(-1, -1),
                blurRadius: 2,
              ),
              BoxShadow(
                color: Color(0x10000000),
                offset: Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Text(
            _dashboardFilter,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  /// Custom Date Range Interactive Calendar Popup Dialog (Matching Mockup & Neumorphic Design)
  Future<void> _showCustomDateRangeDialog() async {
    DateTime tempStart =
        _customStartDate ?? DateTime.now().subtract(const Duration(days: 7));
    DateTime tempEnd = _customEndDate ?? DateTime.now();
    DateTime currentMonth = DateTime(tempStart.year, tempStart.month, 1);
    bool isSelectingFrom = false;

    final result = await showGeneralDialog<Map<String, DateTime>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Custom Date Range',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            void selectPreset(Duration duration) {
              final now = DateTime.now();
              setDialogState(() {
                tempEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
                tempStart =
                    DateTime(now.year, now.month, now.day).subtract(duration);
                currentMonth = DateTime(tempStart.year, tempStart.month, 1);
                isSelectingFrom = false;
              });
            }

            void selectThisWeek() {
              final now = DateTime.now();
              final diff = (now.weekday == 7 ? 6 : now.weekday - 1);
              final mon = now.subtract(Duration(days: diff));
              setDialogState(() {
                tempStart = DateTime(mon.year, mon.month, mon.day, 0, 0, 0);
                tempEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
                currentMonth = DateTime(tempStart.year, tempStart.month, 1);
                isSelectingFrom = false;
              });
            }

            void selectThisMonth() {
              final now = DateTime.now();
              setDialogState(() {
                tempStart = DateTime(now.year, now.month, 1);
                tempEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
                currentMonth = DateTime(tempStart.year, tempStart.month, 1);
                isSelectingFrom = false;
              });
            }

            void onDateTapped(DateTime date) {
              setDialogState(() {
                final cleanDate = DateTime(date.year, date.month, date.day);
                if (isSelectingFrom) {
                  tempStart = cleanDate;
                  if (tempEnd.isBefore(tempStart)) {
                    tempEnd = tempStart;
                  }
                  isSelectingFrom = false;
                } else {
                  if (cleanDate.isBefore(tempStart)) {
                    tempStart = cleanDate;
                    isSelectingFrom = false;
                  } else {
                    tempEnd = cleanDate;
                    isSelectingFrom = true;
                  }
                }
              });
            }

            final rangeDisplayText = (tempStart.year == tempEnd.year &&
                    tempStart.month == tempEnd.month &&
                    tempStart.day == tempEnd.day)
                ? DateFormat('dd MMM yyyy').format(tempStart)
                : '${DateFormat('dd MMM').format(tempStart)} – ${DateFormat('dd MMM yyyy').format(tempEnd)}';

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FB),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x28000000),
                        offset: Offset(0, 12),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Drag Handle Pill
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1D5DB),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Month Navigator Header (< Month Year > & Close Button)
                        Row(
                          children: [
                            // Previous Month Button
                            Material(
                              color: const Color(0xFFF4F6FB),
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    currentMonth = DateTime(
                                      currentMonth.year,
                                      currentMonth.month - 1,
                                      1,
                                    );
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.white,
                                        offset: Offset(-1.5, -1.5),
                                        blurRadius: 3,
                                      ),
                                      BoxShadow(
                                        color: Color(0x14000000),
                                        offset: Offset(1.5, 1.5),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.chevron_left_rounded,
                                    size: 18,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Month and Year Title
                            Expanded(
                              child: Center(
                                child: Text(
                                  DateFormat('MMMM yyyy').format(currentMonth),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Next Month Button
                            Material(
                              color: const Color(0xFFF4F6FB),
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                onTap: () {
                                  setDialogState(() {
                                    currentMonth = DateTime(
                                      currentMonth.year,
                                      currentMonth.month + 1,
                                      1,
                                    );
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.white,
                                        offset: Offset(-1.5, -1.5),
                                        blurRadius: 3,
                                      ),
                                      BoxShadow(
                                        color: Color(0x14000000),
                                        offset: Offset(1.5, 1.5),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Close Button
                            Material(
                              color: const Color(0xFFF4F6FB),
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: () => Navigator.pop(dialogCtx),
                                customBorder: const CircleBorder(),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFF4F6FB),
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.white,
                                        offset: Offset(-1.5, -1.5),
                                        blurRadius: 3,
                                      ),
                                      BoxShadow(
                                        color: Color(0x14000000),
                                        offset: Offset(1.5, 1.5),
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Quick Preset Chips (Wrapped)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildPresetChip(
                                'Today', () => selectPreset(Duration.zero)),
                            _buildPresetChip('Yesterday', () {
                              final now = DateTime.now();
                              final y = now.subtract(const Duration(days: 1));
                              setDialogState(() {
                                tempStart =
                                    DateTime(y.year, y.month, y.day, 0, 0, 0);
                                tempEnd = DateTime(
                                    y.year, y.month, y.day, 23, 59, 59);
                                currentMonth =
                                    DateTime(tempStart.year, tempStart.month, 1);
                                isSelectingFrom = false;
                              });
                            }),
                            _buildPresetChip('This Week', selectThisWeek),
                            _buildPresetChip('Last 7 Days',
                                () => selectPreset(const Duration(days: 6))),
                            _buildPresetChip('This Month', selectThisMonth),
                            _buildPresetChip('Last 30 Days',
                                () => selectPreset(const Duration(days: 29))),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Weekdays Header Strip
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9EEF6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                  child: Center(
                                      child: Text('Su',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF64748B))))),
                              Expanded(
                                  child: Center(
                                      child: Text('Mo',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF64748B))))),
                              Expanded(
                                  child: Center(
                                      child: Text('Tu',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF64748B))))),
                              Expanded(
                                  child: Center(
                                      child: Text('We',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF64748B))))),
                              Expanded(
                                  child: Center(
                                      child: Text('Th',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF64748B))))),
                              Expanded(
                                  child: Center(
                                      child: Text('Fr',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF64748B))))),
                              Expanded(
                                  child: Center(
                                      child: Text('Sa',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF64748B))))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Interactive Month Calendar Grid
                        ..._buildNeumorphicMonthGrid(
                          currentMonth,
                          tempStart,
                          tempEnd,
                          onDateTapped,
                        ),
                        const SizedBox(height: 14),

                        // Bottom Action Bar: [ Recessed Date Pill ] [ Apply Button ]
                        Row(
                          children: [
                            // Recessed Date Pill
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF3F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x10000000),
                                      offset: Offset(1.5, 1.5),
                                      blurRadius: 3,
                                    ),
                                    BoxShadow(
                                      color: Colors.white,
                                      offset: Offset(-1.5, -1.5),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 13,
                                      color: Color(0xFF1D61E7),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        rangeDisplayText,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Apply Button
                            SizedBox(
                              height: 38,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(dialogCtx, {
                                    'start': tempStart,
                                    'end': tempEnd,
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1D61E7),
                                  foregroundColor: Colors.white,
                                  elevation: 3,
                                  shadowColor: const Color(0xFF1D61E7)
                                      .withValues(alpha: 0.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                ),
                                child: const Text(
                                  'Apply',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    color: Colors.white,
                                  ),
                                ),
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
      transitionBuilder: (dialogCtx, anim1, anim2, child) {
        final curved =
            CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _customStartDate = result['start'];
        _customEndDate = result['end'];
        _dashboardFilter = 'Custom Date';
      });
      _loadDashboardData();
    }
  }

  /// Calendar Day Cell Builder for Neumorphic Range Picker
  List<Widget> _buildNeumorphicMonthGrid(
    DateTime month,
    DateTime startDate,
    DateTime endDate,
    ValueChanged<DateTime> onDateTapped,
  ) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final prevMonthDays = DateTime(month.year, month.month, 0).day;

    final leadingCount = firstDay.weekday % 7;
    final totalDaysShown = leadingCount + daysInMonth;
    final trailingCount = (7 - (totalDaysShown % 7)) % 7;
    final totalCells = totalDaysShown + trailingCount;

    final List<Widget> rows = [];
    List<Widget> currentRow = [];

    final normStart =
        DateTime(startDate.year, startDate.month, startDate.day);
    final normEnd = DateTime(endDate.year, endDate.month, endDate.day);

    for (int i = 0; i < totalCells; i++) {
      DateTime cellDate;
      bool isCurrentMonth = true;

      if (i < leadingCount) {
        final day = prevMonthDays - leadingCount + 1 + i;
        cellDate = DateTime(month.year, month.month - 1, day);
        isCurrentMonth = false;
      } else if (i < leadingCount + daysInMonth) {
        final day = i - leadingCount + 1;
        cellDate = DateTime(month.year, month.month, day);
      } else {
        final day = i - (leadingCount + daysInMonth) + 1;
        cellDate = DateTime(month.year, month.month + 1, day);
        isCurrentMonth = false;
      }

      final isStart = cellDate.year == normStart.year &&
          cellDate.month == normStart.month &&
          cellDate.day == normStart.day;
      final isEnd = cellDate.year == normEnd.year &&
          cellDate.month == normEnd.month &&
          cellDate.day == normEnd.day;
      final isBetween =
          cellDate.isAfter(normStart) && cellDate.isBefore(normEnd);
      final isSingle = isStart && isEnd;

      Color textColor;
      if (isStart || isEnd) {
        textColor = Colors.white;
      } else if (!isCurrentMonth) {
        textColor = const Color(0xFF94A3B8);
      } else {
        textColor = const Color(0xFF0F172A);
      }

      currentRow.add(
        Expanded(
          child: InkWell(
            onTap: () => onDateTapped(cellDate),
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Connected Range Light Blue Band
                if (isBetween)
                  Container(
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDBEAFE),
                    ),
                  ),

                if (isStart && !isSingle)
                  Positioned.fill(
                    child: Row(
                      children: [
                        const Expanded(child: SizedBox()),
                        Expanded(
                          child: Container(
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDBEAFE),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (isEnd && !isSingle)
                  Positioned.fill(
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDBEAFE),
                            ),
                          ),
                        ),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ),

                // Date Cell Node
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: (isStart || isEnd)
                        ? const Color(0xFF1D61E7)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${cellDate.day}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: (isStart || isEnd || isBetween)
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (currentRow.length == 7) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(children: currentRow),
          ),
        );
        currentRow = [];
      }
    }

    return rows;
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return Material(
      color: const Color(0xFFF4F6FB),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Colors.white,
                offset: Offset(-1, -1),
                blurRadius: 2,
              ),
              BoxShadow(
                color: Color(0x10000000),
                offset: Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  /// Dropdown Pill Button (Neumorphic Redesigned)
  Widget _buildDropdownPill({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    String displayValue = value;
    if (value == 'Custom Date' &&
        _customStartDate != null &&
        _customEndDate != null) {
      displayValue =
          '${DateFormat('dd MMM').format(_customStartDate!)} – ${DateFormat('dd MMM').format(_customEndDate!)}';
    } else if (value == 'Week') {
      displayValue = 'This Week';
    } else if (value == 'Month') {
      displayValue = 'This Month';
    } else if (value == 'Year') {
      displayValue = 'This Year';
    }

    final options = [
      {'value': 'Today', 'label': 'Today', 'icon': Icons.today_rounded},
      {
        'value': 'Yesterday',
        'label': 'Yesterday',
        'icon': Icons.history_rounded
      },
      {'value': 'Week', 'label': 'This Week', 'icon': Icons.view_week_rounded},
      {
        'value': 'Month',
        'label': 'This Month',
        'icon': Icons.calendar_view_month_rounded
      },
      {
        'value': 'Year',
        'label': 'This Year',
        'icon': Icons.calendar_today_rounded
      },
      {
        'value': 'All Time',
        'label': 'All Time',
        'icon': Icons.all_inclusive_rounded
      },
      {
        'value': 'Custom Date',
        'label': 'Custom Date Range',
        'icon': Icons.date_range_rounded
      },
    ];

    return PopupMenuButton<String>(
      initialValue: value,
      color: Colors.white,
      elevation: 6,
      offset: const Offset(0, 36),
      onSelected: (val) async {
        if (val == 'Custom Date') {
          await _showCustomDateRangeDialog();
        } else {
          onChanged(val);
        }
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      itemBuilder: (context) => options.map((opt) {
        final optVal = opt['value'] as String;
        final optLabel = opt['label'] as String;
        final optIcon = opt['icon'] as IconData;
        final isSelected = value == optVal;

        return PopupMenuItem<String>(
          value: optVal,
          height: 38,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFEFF6FF)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  optIcon,
                  size: 15,
                  color: isSelected
                      ? const Color(0xFF1D61E7)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    optLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF1D61E7)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 15,
                    color: Color(0xFF1D61E7),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Colors.white,
              offset: Offset(-2, -2),
              blurRadius: 4,
            ),
            BoxShadow(
              color: Color(0x18000000),
              offset: Offset(2, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.date_range_rounded,
              size: 14,
              color: Color(0xFF1D61E7),
            ),
            const SizedBox(width: 5),
            Text(
              displayValue,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 15,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  /// Reusable Neumorphic Card Base
  Widget _buildNeumorphicCard({
    required Widget child,
    Color? color,
    Color? borderColor,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFF4F6FB),
        borderRadius: borderRadius ?? BorderRadius.circular(18),
        border: Border.all(
          color: borderColor ?? const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.white,
            offset: Offset(-3, -3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: Color(0x14000000),
            offset: Offset(3, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: child,
    );
  }

  /// Reusable Neumorphic Inset / Recessed Base
  Widget _buildNeumorphicInset({
    required Widget child,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
    Color? color,
  }) {
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFEFF3F9),
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            offset: Offset(1.5, 1.5),
            blurRadius: 3,
          ),
          BoxShadow(
            color: Colors.white,
            offset: Offset(-1.5, -1.5),
            blurRadius: 3,
          ),
        ],
      ),
      child: child,
    );
  }

  /// Fallback computation from local device memory/storage when cloud returns 0 or offline
  _LocalDashboardComputed? _computeLocalDashboardData(
    String period,
    DateTime? customStart,
    DateTime? customEnd,
  ) {
    try {
      final range = _getFilterDateRange();
      final start = range.start;
      final end = range.end;

      final allOrders = _db.deduplicateOrdersList(_db.orders);
      final settledOrders = _db.getCompletedOrders(start: start, end: end);

      final int totalOrders = settledOrders.length;
      final double totalRevenue = settledOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
      final int activeOrdersCount = allOrders.where((o) =>
          (o.status == OrderStatus.pending || o.status == OrderStatus.preparing || o.status == OrderStatus.ready) &&
          !o.isPaid &&
          o.paymentStatus.toLowerCase() != 'paid' &&
          o.status != OrderStatus.completed &&
          o.status != OrderStatus.cancelled).length;
      final int totalProductsCount = _db.menuItems.length;

      int dineInCount = 0;
      double dineInAmount = 0;
      int deliveryCount = 0;
      double deliveryAmount = 0;
      int takeawayCount = 0;
      double takeawayAmount = 0;

      for (var o in settledOrders) {
        if (o.orderType == OrderType.dineIn) {
          dineInCount++;
          dineInAmount += o.totalAmount;
        } else if (o.orderType == OrderType.delivery) {
          deliveryCount++;
          deliveryAmount += o.totalAmount;
        } else {
          takeawayCount++;
          takeawayAmount += o.totalAmount;
        }
      }

      final Map<String, _LocalItemSaleAgg> productMap = {};
      final List<TopProductData> topProductList = [];
      for (var o in settledOrders) {
        for (var item in o.items) {
          final name = item.item.name;
          final rev = item.item.effectivePrice * item.quantity;
          if (!productMap.containsKey(name)) {
            productMap[name] = _LocalItemSaleAgg(
              productId: item.item.id,
              productName: name,
              price: item.item.price,
              quantity: 0,
              totalAmount: 0,
            );
          }
          productMap[name]!.quantity += item.quantity;
          productMap[name]!.totalAmount += rev;
        }
      }

      final productSalesList = productMap.values.toList()
        ..sort((a, b) => b.quantity.compareTo(a.quantity));
      final List<ItemSaleReportItem> itemsList = [];
      for (int i = 0; i < productSalesList.length; i++) {
        final p = productSalesList[i];
        itemsList.add(ItemSaleReportItem(
          srNo: i + 1,
          productId: p.productId,
          productName: p.productName,
          price: p.price,
          quantity: p.quantity,
          totalAmount: p.totalAmount,
        ));
        topProductList.add(TopProductData(
          name: p.productName,
          quantity: p.quantity,
          revenue: p.totalAmount,
        ));
      }

      final Map<String, _LocalPaymentAgg> payMap = {};
      double totalPayAmount = 0.0;
      for (var o in settledOrders) {
        var m = o.paymentMethod.toUpperCase().trim();
        if (m.startsWith('CASH')) {
          m = 'CASH';
        } else if (m.startsWith('CARD') || m.startsWith('DEBIT') || m.startsWith('CREDIT')) {
          m = 'CARD';
        } else if (m.startsWith('UPI') || m.startsWith('ONLINE') || m.startsWith('QR') || m.startsWith('GPAY') || m.startsWith('PHONEPE') || m.startsWith('PAYTM')) {
          m = 'UPI';
        } else if (m.startsWith('SPLIT')) {
          m = 'SPLIT';
        } else if (m.isEmpty) {
          m = 'CASH';
        } else {
          m = 'OTHER';
        }

        if (!payMap.containsKey(m)) {
          payMap[m] = _LocalPaymentAgg(method: m, count: 0, amount: 0.0);
        }
        payMap[m]!.count += 1;
        payMap[m]!.amount += o.totalAmount;
        totalPayAmount += o.totalAmount;
      }

      final payList = payMap.values
          .map((p) => PaymentMethodSaleItem(
                method: p.method,
                count: p.count,
                amount: p.amount,
              ))
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

      double totalTax = 0.0;
      for (var o in settledOrders) {
        totalTax += o.taxAmount;
      }

      bool isSameCust(OrderModel o1, String targetPhone, String targetName) {
        final p1 = (o1.customerPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        final p2 = targetPhone.replaceAll(RegExp(r'[^0-9]'), '');
        if (p1.isNotEmpty && p2.isNotEmpty) {
          final sub1 = p1.length >= 10 ? p1.substring(p1.length - 10) : p1;
          final sub2 = p2.length >= 10 ? p2.substring(p2.length - 10) : p2;
          return sub1 == sub2;
        }
        if (targetName.isNotEmpty && targetName != 'Customer' && targetName != 'Guest Customer') {
          return (o1.customerName ?? '').trim().toLowerCase() == targetName.trim().toLowerCase();
        }
        return false;
      }

      final Map<String, CustomerInsightItem> custMap = {};
      final dbCusts = DatabaseService().customers;

      for (var o in settledOrders) {
        if (o.status == OrderStatus.cancelled) continue;
        final name = (o.customerName ?? '').trim();
        final phone = (o.customerPhone ?? '').trim();
        final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
        final p10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
        final key = p10.isNotEmpty ? p10 : (name.isNotEmpty && name != 'Customer' ? name.toLowerCase() : '');
        if (key.isEmpty) continue;

        if (!custMap.containsKey(key)) {
          final totalVisits = allOrders.where((ao) {
            if (ao.status == OrderStatus.cancelled) return false;
            return isSameCust(ao, phone, name);
          }).length;

          int baselineOrders = 0;
          for (final c in dbCusts) {
            final cClean = c.phone.replaceAll(RegExp(r'[^0-9]'), '');
            final c10 = cClean.length >= 10 ? cClean.substring(cClean.length - 10) : cClean;
            if ((p10.isNotEmpty && c10 == p10) || (name.isNotEmpty && name != 'Customer' && c.name.trim().toLowerCase() == name.toLowerCase())) {
              baselineOrders = math.max(baselineOrders, c.totalOrders);
            }
          }

          final effVisits = math.max(totalVisits, baselineOrders);

          custMap[key] = CustomerInsightItem(
            name: name.isNotEmpty ? name : 'Customer',
            phone: phone,
            visitCount: effVisits > 0 ? effVisits : 1,
          );
        }
      }

      final List<CustomerInsightItem> localNewCust = [];
      final List<CustomerInsightItem> localRetCust = [];
      for (var item in custMap.values) {
        if (item.visitCount > 1) {
          localRetCust.add(item);
        } else {
          localNewCust.add(item);
        }
      }

      return _LocalDashboardComputed(
        summary: DashboardSummaryData(
          period: period,
          revenue: totalRevenue,
          totalOrders: totalOrders,
          activeOrdersCount: activeOrdersCount,
          totalProductsCount: totalProductsCount,
          topProducts: topProductList.take(15).toList(),
        ),
        orderTypes: OrderTypeStatsData(
          dineIn: OrderTypeCountAmount(count: dineInCount, amount: dineInAmount),
          delivery: OrderTypeCountAmount(count: deliveryCount, amount: deliveryAmount),
          takeaway: OrderTypeCountAmount(count: takeawayCount, amount: takeawayAmount),
          total: OrderTypeCountAmount(count: totalOrders, amount: totalRevenue),
        ),
        productSales: itemsList,
        customers: CustomerAnalyticsData(
          newCustomers: localNewCust,
          returningCustomers: localRetCust,
        ),
        payments: PaymentMethodsSummaryData(payments: payList, totalAmount: totalPayAmount),
        taxes: TaxSummaryData(
          totalGST: totalTax,
          cgst: totalTax / 2,
          sgst: totalTax / 2,
          igst: 0,
        ),
        orderStats: OrderStatsSummaryData(
          successfulOrders: settledOrders.length,
          cancelledOrders: allOrders.where((o) {
            final oDate = o.createdDateTime.toLocal();
            return o.status == OrderStatus.cancelled && !oDate.isBefore(start) && !oDate.isAfter(end);
          }).length,
          otherOrders: activeOrdersCount,
          totalOrders: settledOrders.length,
        ),
      );
    } catch (e) {
      debugPrint('Error computing local dashboard data: $e');
      return null;
    }
  }
}

class _LocalDashboardComputed {
  final DashboardSummaryData summary;
  final OrderTypeStatsData orderTypes;
  final List<ItemSaleReportItem> productSales;
  final CustomerAnalyticsData customers;
  final PaymentMethodsSummaryData payments;
  final TaxSummaryData taxes;
  final OrderStatsSummaryData orderStats;

  _LocalDashboardComputed({
    required this.summary,
    required this.orderTypes,
    required this.productSales,
    required this.customers,
    required this.payments,
    required this.taxes,
    required this.orderStats,
  });
}

class _LocalItemSaleAgg {
  final String productId;
  final String productName;
  final double price;
  int quantity;
  double totalAmount;

  _LocalItemSaleAgg({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.totalAmount,
  });
}

class _LocalPaymentAgg {
  final String method;
  int count;
  double amount;

  _LocalPaymentAgg({
    required this.method,
    required this.count,
    required this.amount,
  });
}
