import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../../core/database/database_service.dart';
import '../../core/services/dashboard_service.dart';

/// Glass Liquid UI Dashboard Screen matching Apna POS design theme
class GlassDashboardScreen extends StatefulWidget {
  final Function(int index)? onNavigateTab;

  const GlassDashboardScreen({super.key, this.onNavigateTab});

  @override
  State<GlassDashboardScreen> createState() => _GlassDashboardScreenState();
}

class _GlassDashboardScreenState extends State<GlassDashboardScreen> {
  final DatabaseService _db = DatabaseService();
  final DashboardService _dashboardService = DashboardService();

  String _dashboardFilter = 'Today';
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // Cloud API State
  bool _isLoading = true;
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
    _loadDashboardData();
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChange);
    super.dispose();
  }

  void _onDbChange() {
    if (mounted) {
      _loadDashboardData();
    }
  }

  String? get _startDateParam {
    if (_dashboardFilter == 'Custom Date' && _customStartDate != null) {
      return _customStartDate!.toIso8601String();
    }
    return null;
  }

  String? get _endDateParam {
    if (_dashboardFilter == 'Custom Date' && _customEndDate != null) {
      return _customEndDate!.toIso8601String();
    }
    return null;
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sDate = _startDateParam;
      final eDate = _endDateParam;

      final results = await Future.wait([
        _dashboardService.fetchSummary(
          period: _dashboardFilter,
          startDate: sDate,
          endDate: eDate,
        ),
        _dashboardService.fetchOrderTypes(
          period: _dashboardFilter,
          startDate: sDate,
          endDate: eDate,
        ),
        _dashboardService.fetchProductSales(
          period: _dashboardFilter,
          startDate: sDate,
          endDate: eDate,
        ),
        _dashboardService.fetchCustomers(
          period: _dashboardFilter,
          startDate: sDate,
          endDate: eDate,
        ),
        _dashboardService.fetchPaymentMethods(
          period: _dashboardFilter,
          startDate: sDate,
          endDate: eDate,
        ),
        _dashboardService.fetchTaxes(
          period: _dashboardFilter,
          startDate: sDate,
          endDate: eDate,
        ),
        _dashboardService.fetchOrderStats(
          period: _dashboardFilter,
          startDate: sDate,
          endDate: eDate,
        ),
      ]);

      if (mounted) {
        setState(() {
          _summaryData = results[0] as DashboardSummaryData;
          _orderTypesData = results[1] as OrderTypeStatsData;
          _productSales = results[2] as List<ItemSaleReportItem>;
          _customerData = results[3] as CustomerAnalyticsData;
          _paymentMethodsData = results[4] as PaymentMethodsSummaryData;
          _taxData = results[5] as TaxSummaryData;
          _orderStatsData = results[6] as OrderStatsSummaryData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[GlassDashboardScreen] Error fetching dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Failed to refresh cloud dashboard metrics. Showing cached data.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF5F9),
      body: Stack(
        children: [
          // 1. Ambient Liquid Background Blobs
          _buildLiquidBackground(size),

          // 2. Main Scrollable Content
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: const Color(0xFF0284C7),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 12 : 24,
                  isMobile ? 10 : 20,
                  isMobile ? 12 : 24,
                  isMobile ? 16 : 24,
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
                              onPressed: _loadDashboardData,
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Order Summary Section (Total Orders & Total Revenue)
                    _buildSummaryCards(isMobile),
                    const SizedBox(height: 14),

                    // Order Type Liquid Glass Grid (4 Cards: Dine In, Take Away, Delivery, Total)
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
        ],
      ),
    );
  }

  /// Ambient Liquid Background Blobs for depth & glass refraction
  Widget _buildLiquidBackground(Size size) {
    return Stack(
      children: [
        Positioned(
          top: -40,
          right: -40,
          child: Container(
            width: size.width * 0.7,
            height: size.width * 0.7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x3300C2FF),
                  Color(0x18A5F3FC),
                  Colors.transparent,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: size.height * 0.35,
          left: -80,
          child: Container(
            width: size.width * 0.6,
            height: size.width * 0.6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x228B5CF6),
                  Color(0x10DDD6FE),
                  Colors.transparent,
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          right: -60,
          child: Container(
            width: size.width * 0.65,
            height: size.width * 0.65,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x2510B981),
                  Color(0x10A7F3D0),
                  Colors.transparent,
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Top Header Bar with Refresh
  Widget _buildHeader() {
    final storeName = _db.restaurant?.name ?? 'Apna POS Diner';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                storeName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              const Text(
                'Real-Time Cloud Business Analytics',
                style: TextStyle(
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
            _loadDashboardData();
          },
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: _loadDashboardData,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A0052FF),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
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
      ],
    );
  }

  /// 1. Order Summary Section
  Widget _buildSummaryCards(bool isMobile) {
    final int totalOrdersCount = _summaryData.totalOrders;
    final double totalRevenue = _summaryData.revenue;
    final String currentDateStr = DateFormat(
      'd MMM yyyy',
    ).format(DateTime.now());

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_rounded,
                      color: Color(0xFF9333EA),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _dashboardFilter,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Orders',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$totalOrdersCount',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Revenue',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '₹${totalRevenue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 11,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 5),
              Text(
                currentDateStr,
                style: const TextStyle(
                  fontSize: 10.5,
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
        bgColor: const Color(0xFFECFDF5),
        borderColor: const Color(0xFFA7F3D0),
      ),
      _buildOrderTypeCard(
        title: 'Dine In',
        amount: _orderTypesData.dineIn.amount,
        count: _orderTypesData.dineIn.count,
        icon: Icons.restaurant_rounded,
        accentColor: const Color(0xFF8B5CF6),
        bgColor: const Color(0xFFF5F3FF),
        borderColor: const Color(0xFFDDD6FE),
      ),
      _buildOrderTypeCard(
        title: 'Take Away',
        amount: _orderTypesData.takeaway.amount,
        count: _orderTypesData.takeaway.count,
        icon: Icons.local_mall_rounded,
        accentColor: const Color(0xFF0284C7),
        bgColor: const Color(0xFFF0F9FF),
        borderColor: const Color(0xFFBAE6FD),
      ),
      _buildOrderTypeCard(
        title: 'Delivery',
        amount: _orderTypesData.delivery.amount,
        count: _orderTypesData.delivery.count,
        icon: Icons.two_wheeler_rounded,
        accentColor: const Color(0xFFF97316),
        bgColor: const Color(0xFFFFF7ED),
        borderColor: const Color(0xFFFED7AA),
      ),
    ];

    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isMobile ? 1.3 : 1.45,
      children: cards,
    );
  }

  Widget _buildOrderTypeCard({
    required String title,
    required int count,
    required double amount,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
  }) {
    return _buildGlassCard(
      color: bgColor,
      borderColor: borderColor,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: accentColor, size: 16),
            ),
            const SizedBox(height: 3),
            Text(
              '₹${amount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
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
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
              ),
              child: Text(
                '$count Orders',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
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
    return _buildGlassCard(
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  _dashboardFilter,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
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
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFD97706),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No product sales yet',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Item-wise sales data will appear here\nonce orders are completed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text(
                          '#',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Product Name',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
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
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
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
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
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
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _productSales.length,
                  separatorBuilder: (context, index) =>
                      Divider(color: Colors.white.withOpacity(0.5), height: 12),
                  itemBuilder: (context, index) {
                    final p = _productSales[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            child: Text(
                              '${p.srNo > 0 ? p.srNo : index + 1}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              p.productName,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
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
                                  fontSize: 10.5,
                                  color: Color(0xFF64748B),
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
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
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
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
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
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'NO ROWS YET',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(emptyIcon, color: iconColor, size: 24),
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
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            emptySubtitle,
                            style: const TextStyle(
                              fontSize: 10,
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
            const Divider(color: Color(0xFFE2E8F0), height: 12),
        itemBuilder: (context, index) {
          final item = list[index];
          return Row(
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontSize: 10,
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
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
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
                          fontSize: 9.5,
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Visits: ${item.visitCount}',
                    style: const TextStyle(
                      fontSize: 9.5,
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

    Widget newCust = _buildGlassCard(
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

    Widget retCust = _buildGlassCard(
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

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Total Sales'),
          const SizedBox(height: 12),
          _buildProgressBarRow('CASH', cash, maxVal, const Color(0xFF00C2FF)),
          _buildProgressBarRow('CARD', card, maxVal, const Color(0xFF3B82F6)),
          _buildProgressBarRow('UPI', upi, maxVal, const Color(0xFF8B5CF6)),
          if (split > 0)
            _buildProgressBarRow(
              'OTHER / SPLIT',
              split,
              maxVal,
              const Color(0xFFF59E0B),
            ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Total: ₹${total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
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

    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Taxes'),
          const SizedBox(height: 12),
          _buildProgressBarRow(
            'TOTAL GST',
            gst,
            gst > 0 ? gst : 1.0,
            const Color(0xFF94A3B8),
          ),
          _buildProgressBarRow(
            'CGST',
            cgst,
            gst > 0 ? gst : 1.0,
            const Color(0xFF38BDF8),
          ),
          _buildProgressBarRow(
            'SGST',
            sgst,
            gst > 0 ? gst : 1.0,
            const Color(0xFF818CF8),
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Total Taxes: ₹${gst.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
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

    return _buildGlassCard(
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
    double progress = max > 0 ? (value / max).clamp(0.0, 1.0) : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
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
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(5),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.4),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '₹${value.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
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
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _dashboardFilter,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  /// Custom Date Range TO or FROM Popup Dialog
  Future<void> _showCustomDateRangeDialog() async {
    DateTime tempStart = _customStartDate ?? DateTime.now().subtract(const Duration(days: 7));
    DateTime tempEnd = _customEndDate ?? DateTime.now();

    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final fromStr = DateFormat('dd MMM yyyy').format(tempStart);
            final toStr = DateFormat('dd MMM yyyy').format(tempEnd);

            void selectPreset(Duration duration) {
              final now = DateTime.now();
              setDialogState(() {
                tempEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
                tempStart = DateTime(now.year, now.month, now.day).subtract(duration);
              });
            }

            void selectThisMonth() {
              final now = DateTime.now();
              setDialogState(() {
                tempStart = DateTime(now.year, now.month, 1);
                tempEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              elevation: 10,
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dialog Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.date_range_rounded,
                                color: Color(0xFF0284C7),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Custom Date Range',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Select FROM & TO filter dates',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Quick Preset Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPresetChip('Today', () => selectPreset(Duration.zero)),
                          const SizedBox(width: 6),
                          _buildPresetChip('Last 7 Days', () => selectPreset(const Duration(days: 6))),
                          const SizedBox(width: 6),
                          _buildPresetChip('Last 30 Days', () => selectPreset(const Duration(days: 29))),
                          const SizedBox(width: 6),
                          _buildPresetChip('This Month', selectThisMonth),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // FROM & TO Date Boxes
                    Row(
                      children: [
                        // FROM DATE
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempStart,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                builder: (context, child) => Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFF0284C7),
                                      onPrimary: Colors.white,
                                      onSurface: Color(0xFF0F172A),
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  tempStart = picked;
                                  if (tempEnd.isBefore(tempStart)) {
                                    tempEnd = picked;
                                  }
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF0284C7)),
                                      SizedBox(width: 4),
                                      Text(
                                        'FROM DATE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0284C7),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    fromStr,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // TO DATE
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempEnd,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                                builder: (context, child) => Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFF0284C7),
                                      onPrimary: Colors.white,
                                      onSurface: Color(0xFF0F172A),
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  tempEnd = picked;
                                  if (tempStart.isAfter(tempEnd)) {
                                    tempStart = picked;
                                  }
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.event_outlined, size: 12, color: Color(0xFF0284C7)),
                                      SizedBox(width: 4),
                                      Text(
                                        'TO DATE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0284C7),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    toStr,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop({'start': tempStart, 'end': tempEnd});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Apply Filter',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
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

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  /// Dropdown Pill Button
  Widget _buildDropdownPill({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    String displayValue = value;
    if (value == 'Custom Date' &&
        _customStartDate != null &&
        _customEndDate != null) {
      displayValue =
          '${DateFormat('d MMM').format(_customStartDate!)} - ${DateFormat('d MMM').format(_customEndDate!)}';
    }

    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: (val) async {
        if (val == 'Custom Date') {
          await _showCustomDateRangeDialog();
        } else {
          onChanged(val);
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'Today', child: Text('Today')),
        PopupMenuItem(value: 'Yesterday', child: Text('Yesterday')),
        PopupMenuItem(value: 'Week', child: Text('This Week')),
        PopupMenuItem(value: 'Month', child: Text('This Month')),
        PopupMenuItem(value: 'Year', child: Text('This Year')),
        PopupMenuItem(value: 'Custom Date', child: Text('Custom Date Range')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0052FF),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.date_range_rounded,
              size: 13,
              color: Color(0xFF0284C7),
            ),
            const SizedBox(width: 5),
            Text(
              displayValue,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 13,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  /// Reusable Glass Card Base
  Widget _buildGlassCard({
    required Widget child,
    Color? color,
    Color? borderColor,
    EdgeInsetsGeometry? padding,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.9),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0C0052FF),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
