import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';
import '../../core/services/report_service.dart';
import '../pos/receipt_dialog.dart';
import 'widgets/metric_sparkline.dart';
import 'widgets/payment_mode_donut_chart.dart';
import 'widgets/sales_trend_chart.dart';

enum SalesDateFilter { allTime, today, yesterday, thisWeek, thisMonth, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseService _db = DatabaseService();
  final ReportService _reportService = ReportService();

  // Filters State
  SalesDateFilter _selectedDateFilter = SalesDateFilter.thisMonth;
  DateTimeRange? _customDateRange;
  String _selectedOutlet = 'All Outlets';
  String _selectedPaymentMode = 'All Payment Modes';
  String _selectedOrderType = 'All Order Types';
  final TextEditingController _searchController = TextEditingController();

  // Data State
  bool _isLoading = false;
  SalesReportData? _reportData;
  int _requestSeq = 0;

  // Active Tab & Pagination
  int _activeTabIndex = 0;
  int _currentPage = 1;
  int _pageSize = 6;

  final List<String> _desktopTabs = [
    'Sales Details',
    'Top Products',
    'Category Wise',
    'Payment Mode',
    'Order Type',
    'Outlet Wise',
    'Staff Wise',
  ];

  final List<String> _mobileTabs = [
    'Recent Sales',
    'Top Products',
    'Category',
    'Payment Mode',
    'Order Type',
    'Outlet Wise',
    'Staff Wise',
  ];

  @override
  void initState() {
    super.initState();
    _db.addListener(_onDbChange);

    // Initial default: 1st of month to today
    final now = DateTime.now();
    _customDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: now,
    );

    // Initial instant cached compute
    final params = _resolveFilterParams();
    _reportData = _reportService.getLocalSalesReport(
      period: params.$1,
      startDate: params.$2,
      endDate: params.$3,
      paymentMethod: _selectedPaymentMode,
      orderType: _selectedOrderType,
      outlet: _selectedOutlet,
      search: _searchController.text,
    );

    _loadSalesReport(showLoading: false);
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onDbChange() {
    if (mounted) {
      _loadSalesReport(showLoading: false);
    }
  }

  (String?, String?, String?) _resolveFilterParams() {
    String? period;
    String? startDate;
    String? endDate;

    final now = DateTime.now();
    switch (_selectedDateFilter) {
      case SalesDateFilter.allTime:
        period = 'allTime';
        break;
      case SalesDateFilter.today:
        period = 'today';
        final startToday = DateTime(now.year, now.month, now.day, 0, 0, 0);
        final endToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        startDate = startToday.toUtc().toIso8601String();
        endDate = endToday.toUtc().toIso8601String();
        break;
      case SalesDateFilter.yesterday:
        period = 'yesterday';
        final y = now.subtract(const Duration(days: 1));
        final startY = DateTime(y.year, y.month, y.day, 0, 0, 0);
        final endY = DateTime(y.year, y.month, y.day, 23, 59, 59, 999);
        startDate = startY.toUtc().toIso8601String();
        endDate = endY.toUtc().toIso8601String();
        break;
      case SalesDateFilter.thisWeek:
        period = 'thisWeek';
        final diffToMonday = (now.weekday == 7 ? 6 : now.weekday - 1);
        final monday = now.subtract(Duration(days: diffToMonday));
        final startWeek = DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
        final endWeek = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        startDate = startWeek.toUtc().toIso8601String();
        endDate = endWeek.toUtc().toIso8601String();
        break;
      case SalesDateFilter.thisMonth:
        period = 'thisMonth';
        final startMonth = DateTime(now.year, now.month, 1, 0, 0, 0);
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        final endMonth = DateTime(now.year, now.month, lastDay, 23, 59, 59, 999);
        startDate = startMonth.toUtc().toIso8601String();
        endDate = endMonth.toUtc().toIso8601String();
        break;
      case SalesDateFilter.custom:
        if (_customDateRange != null) {
          final start = DateTime(
            _customDateRange!.start.year,
            _customDateRange!.start.month,
            _customDateRange!.start.day,
            0,
            0,
            0,
          );
          final end = DateTime(
            _customDateRange!.end.year,
            _customDateRange!.end.month,
            _customDateRange!.end.day,
            23,
            59,
            59,
            999,
          );
          startDate = start.toUtc().toIso8601String();
          endDate = end.toUtc().toIso8601String();
        } else {
          period = 'allTime';
        }
        break;
    }
    return (period, startDate, endDate);
  }

  Future<void> _loadSalesReport({bool showLoading = true}) async {
    final currentSeq = ++_requestSeq;
    final params = _resolveFilterParams();

    final localData = _reportService.getLocalSalesReport(
      period: params.$1,
      startDate: params.$2,
      endDate: params.$3,
      paymentMethod: _selectedPaymentMode,
      orderType: _selectedOrderType,
      outlet: _selectedOutlet,
      search: _searchController.text,
    );

    if (mounted) {
      setState(() {
        _reportData = localData;
        if (showLoading) _isLoading = true;
      });
    }

    try {
      final data = await _reportService.fetchSalesReport(
        period: params.$1,
        startDate: params.$2,
        endDate: params.$3,
        paymentMethod: _selectedPaymentMode,
        orderType: _selectedOrderType,
        outlet: _selectedOutlet,
        search: _searchController.text,
      );

      if (mounted && currentSeq == _requestSeq) {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && currentSeq == _requestSeq) {
        setState(() {
          _isLoading = false;
          _reportData ??= localData;
        });
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _selectedDateFilter = SalesDateFilter.thisMonth;
      final now = DateTime.now();
      _customDateRange = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      );
      _selectedOutlet = 'All Outlets';
      _selectedPaymentMode = 'All Payment Modes';
      _selectedOrderType = 'All Order Types';
      _searchController.clear();
      _currentPage = 1;
    });
    _loadSalesReport();
  }

  String _getDateFilterDisplay() {
    final fmt = DateFormat('dd MMM yyyy');
    if (_selectedDateFilter == SalesDateFilter.custom && _customDateRange != null) {
      return '${fmt.format(_customDateRange!.start)} - ${fmt.format(_customDateRange!.end)}';
    }
    if (_selectedDateFilter == SalesDateFilter.today) {
      return fmt.format(DateTime.now());
    }
    if (_selectedDateFilter == SalesDateFilter.yesterday) {
      return fmt.format(DateTime.now().subtract(const Duration(days: 1)));
    }
    if (_selectedDateFilter == SalesDateFilter.thisWeek) {
      final now = DateTime.now();
      final diff = (now.weekday == 7 ? 6 : now.weekday - 1);
      final mon = now.subtract(Duration(days: diff));
      return '${fmt.format(mon)} - ${fmt.format(now)}';
    }
    if (_selectedDateFilter == SalesDateFilter.thisMonth) {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      return '${fmt.format(start)} - ${fmt.format(now)}';
    }
    return '01 Sep 2025 - 17 Sep 2025';
  }

  void _showDateFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB), size: 22),
              SizedBox(width: 8),
              Text(
                'Select Date Range',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDatePresetTile('Today', SalesDateFilter.today, ctx),
              _buildDatePresetTile('Yesterday', SalesDateFilter.yesterday, ctx),
              _buildDatePresetTile('This Week', SalesDateFilter.thisWeek, ctx),
              _buildDatePresetTile('This Month', SalesDateFilter.thisMonth, ctx),
              _buildDatePresetTile('All Time', SalesDateFilter.allTime, ctx),
              const Divider(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.date_range_rounded, color: Color(0xFF2563EB), size: 18),
                ),
                title: const Text('Custom Date Range...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2022),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDateRange: _customDateRange ?? DateTimeRange(
                      start: DateTime.now().subtract(const Duration(days: 7)),
                      end: DateTime.now(),
                    ),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xFF2563EB),
                            onPrimary: Colors.white,
                            surface: Colors.white,
                            onSurface: Color(0xFF0F172A),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _customDateRange = picked;
                      _selectedDateFilter = SalesDateFilter.custom;
                      _currentPage = 1;
                    });
                    _loadSalesReport();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDatePresetTile(String label, SalesDateFilter filter, BuildContext dialogCtx) {
    final isSelected = _selectedDateFilter == filter;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF334155),
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 18) : null,
      onTap: () {
        Navigator.pop(dialogCtx);
        setState(() {
          _selectedDateFilter = filter;
          _currentPage = 1;
        });
        _loadSalesReport();
      },
    );
  }

  Future<void> _exportSalesToExcel() async {
    final ordersToExport = _reportData?.orders ?? [];
    if (ordersToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No sales records found to export.'),
          backgroundColor: Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final currency = _db.restaurant?.currencySymbol ?? '₹';
    final List<List<dynamic>> rows = [
      ['Bill No', 'Date & Time', 'Order Type', 'Table', 'Items Count', 'Payment Mode', 'Customer', 'Amount ($currency)'],
    ];

    for (final o in ordersToExport) {
      final itemsCount = o.items.fold(0, (sum, i) => sum + i.quantity);
      final typeStr = o.orderType == OrderType.dineIn
          ? 'Dine In'
          : (o.orderType == OrderType.takeaway ? 'Takeaway' : 'Delivery');

      rows.add([
        o.orderNumber,
        o.createdAt,
        typeStr,
        o.tableNumber ?? '-',
        itemsCount,
        o.paymentMethod,
        o.customerName ?? 'Walk-in',
        o.totalAmount.toStringAsFixed(2),
      ]);
    }

    final StringBuffer csvBuffer = StringBuffer();
    for (final row in rows) {
      final line = row.map((f) => '"${f.toString().replaceAll('"', '""')}"').join(',');
      csvBuffer.writeln(line);
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/Sales_Report_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File(filePath);
      await file.writeAsString(csvBuffer.toString());

      await SharePlus.instance.share(
        ShareParams(
          text: 'Apna POS Sales Report Export (${ordersToExport.length} Bills)',
          files: [XFile(filePath, mimeType: 'text/csv')],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = _db.restaurant?.currencySymbol ?? '₹';
    final summary = _reportData?.summary ?? SalesReportSummary();
    final paymentModes = _reportData?.paymentModes ?? [];
    final salesTrend = _reportData?.salesTrend ?? [];
    final allOrders = _reportData?.orders ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 750;
            final isDesktop = constraints.maxWidth >= 1050;

            return RefreshIndicator(
              onRefresh: () async => await _loadSalesReport(),
              color: const Color(0xFF2563EB),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 20,
                  vertical: isMobile ? 12 : 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1. TOP FILTER BAR ---
                    _buildTopFilterBar(isMobile: isMobile),
                    const SizedBox(height: 16),

                    // --- 2. TOP 5 METRIC CARDS ---
                    _buildTopMetricCards(summary: summary, currency: currency, isMobile: isMobile, isDesktop: isDesktop),
                    const SizedBox(height: 16),

                    // --- 3. CHARTS & VISUAL ANALYTICS SECTION ---
                    _buildChartsSection(
                      salesTrend: salesTrend,
                      paymentModes: paymentModes,
                      totalSales: summary.totalRevenue,
                      currency: currency,
                      isMobile: isMobile,
                    ),
                    const SizedBox(height: 18),

                    // --- 4. TABBED DATA & RECENT SALES TABLE SECTION ---
                    _buildTabbedDataSection(
                      orders: allOrders,
                      currency: currency,
                      isMobile: isMobile,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================
  // 1. TOP FILTER BAR
  // ==========================================
  Widget _buildTopFilterBar({required bool isMobile}) {
    if (isMobile) {
      return Column(
        children: [
          // Date Filter Box
          InkWell(
            onTap: _showDateFilterDialog,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF475569)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getDateFilterDisplay(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 3 Dropdowns Row
          Row(
            children: [
              Expanded(
                child: _buildCurvedDropdown(
                  value: _selectedOutlet,
                  items: ['All Outlets', _db.restaurant?.name ?? 'Main Outlet'],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedOutlet = val);
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCurvedDropdown(
                  value: _selectedPaymentMode == 'All Payment Modes' ? 'All Payments' : _selectedPaymentMode,
                  items: const ['All Payments', 'Cash', 'UPI', 'Card', 'Wallet'],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedPaymentMode = val == 'All Payments' ? 'All Payment Modes' : val;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildCurvedDropdown(
                  value: _selectedOrderType == 'All Order Types' ? 'All Orders' : _selectedOrderType,
                  items: const ['All Orders', 'Dine In', 'Takeaway', 'Delivery'],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedOrderType = val == 'All Orders' ? 'All Order Types' : val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Action Buttons: Apply & Reset
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _currentPage = 1);
                    _loadSalesReport();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Apply', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: _resetFilters,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: Colors.white,
                  ),
                  child: const Text('Reset', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Desktop Filter Bar: Single Clean Row
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Date Input Box
          InkWell(
            onTap: _showDateFilterDialog,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 15, color: Color(0xFF475569)),
                  const SizedBox(width: 8),
                  Text(
                    _getDateFilterDisplay(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Outlet Dropdown
          _buildCurvedDropdown(
            value: _selectedOutlet,
            items: ['All Outlets', _db.restaurant?.name ?? 'Main Outlet'],
            onChanged: (val) {
              if (val != null) setState(() => _selectedOutlet = val);
            },
          ),
          const SizedBox(width: 10),

          // Payment Mode Dropdown
          _buildCurvedDropdown(
            value: _selectedPaymentMode,
            items: const ['All Payment Modes', 'Cash', 'UPI', 'Card', 'Wallet'],
            onChanged: (val) {
              if (val != null) setState(() => _selectedPaymentMode = val);
            },
          ),
          const SizedBox(width: 10),

          // Order Types Dropdown
          _buildCurvedDropdown(
            value: _selectedOrderType,
            items: const ['All Order Types', 'Dine In', 'Takeaway', 'Delivery'],
            onChanged: (val) {
              if (val != null) setState(() => _selectedOrderType = val);
            },
          ),
          const Spacer(),

          // Apply Button
          ElevatedButton(
            onPressed: () {
              setState(() => _currentPage = 1);
              _loadSalesReport();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Apply', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),

          // Reset Button
          OutlinedButton(
            onPressed: _resetFilters,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF334155),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: Colors.white,
            ),
            child: const Text('Reset', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCurvedDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final effectiveValue = items.contains(value) ? value : items.first;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ==========================================
  // 2. TOP 5 METRIC CARDS
  // ==========================================
  Widget _buildTopMetricCards({
    required SalesReportSummary summary,
    required String currency,
    required bool isMobile,
    required bool isDesktop,
  }) {
    final card1 = _buildKpiCard(
      icon: Icons.account_balance_wallet_rounded,
      iconBgColor: const Color(0xFFDCFCE7),
      iconColor: const Color(0xFF16A34A),
      title: 'Total Sales',
      value: '$currency${_formatKpiAmount(summary.totalRevenue)}',
      trendPct: summary.growthSalesPct,
      sparklineColor: const Color(0xFF16A34A),
      isMobile: isMobile,
    );

    final card2 = _buildKpiCard(
      icon: Icons.receipt_long_rounded,
      iconBgColor: const Color(0xFFEFF6FF),
      iconColor: const Color(0xFF2563EB),
      title: 'Total Orders',
      value: '${summary.totalOrders}',
      trendPct: summary.growthOrdersPct,
      sparklineColor: const Color(0xFF2563EB),
      isMobile: isMobile,
    );

    final card3 = _buildKpiCard(
      icon: Icons.shopping_cart_rounded,
      iconBgColor: const Color(0xFFFEF3C7),
      iconColor: const Color(0xFFD97706),
      title: isMobile ? 'Avg Order Value' : 'Average Order Value',
      value: '$currency${summary.avgOrderValue.toStringAsFixed(0)}',
      trendPct: summary.growthAovPct,
      sparklineColor: const Color(0xFFD97706),
      isMobile: isMobile,
    );

    final card4 = _buildKpiCard(
      icon: Icons.inventory_2_rounded,
      iconBgColor: const Color(0xFFF3E8FF),
      iconColor: const Color(0xFF7C3AED),
      title: isMobile ? 'Items Sold' : 'Total Items Sold',
      value: '${summary.totalItems}',
      trendPct: summary.growthItemsPct,
      sparklineColor: const Color(0xFF7C3AED),
      isMobile: isMobile,
    );

    final card5 = _buildKpiCard(
      icon: Icons.description_rounded,
      iconBgColor: const Color(0xFFFCE7F3),
      iconColor: const Color(0xFFDB2777),
      title: 'Total Bills',
      value: '${summary.totalOrders}',
      trendPct: summary.growthOrdersPct,
      sparklineColor: const Color(0xFFDB2777),
      isMobile: isMobile,
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: card1),
          const SizedBox(width: 12),
          Expanded(child: card2),
          const SizedBox(width: 12),
          Expanded(child: card3),
          const SizedBox(width: 12),
          Expanded(child: card4),
          const SizedBox(width: 12),
          Expanded(child: card5),
        ],
      );
    }

    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: card1),
              const SizedBox(width: 8),
              Expanded(child: card2),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: card3),
              const SizedBox(width: 8),
              Expanded(child: card4),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: card5),
        ],
      );
    }

    // Tablet: Wrap in 3 + 2 grid
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(width: 200, child: card1),
        SizedBox(width: 200, child: card2),
        SizedBox(width: 200, child: card3),
        SizedBox(width: 200, child: card4),
        SizedBox(width: 200, child: card5),
      ],
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String value,
    required double trendPct,
    required Color sparklineColor,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon & Title Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: isMobile ? 16 : 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isMobile)
                const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFFCBD5E1)),
            ],
          ),
          const SizedBox(height: 8),

          // Big Amount
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Trend + Sparkline Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_drop_up_rounded, color: Color(0xFF16A34A), size: 16),
                    Text(
                      '${trendPct.toInt()}%',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: 3),
                      const Text(
                        'vs prev',
                        style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
              MetricSparkline(
                color: sparklineColor,
                width: isMobile ? 50 : 60,
                height: isMobile ? 22 : 26,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatKpiAmount(double amt) {
    if (amt >= 1000) {
      final str = amt.toStringAsFixed(0);
      return str.replaceAllMapped(RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))(\.\d+)?'), (Match m) => '${m[1]},');
    }
    return amt.toStringAsFixed(0);
  }

  // ==========================================
  // 3. CHARTS & VISUAL ANALYTICS SECTION
  // ==========================================
  Widget _buildChartsSection({
    required List<DailySalesTrendPoint> salesTrend,
    required List<PaymentModeStat> paymentModes,
    required double totalSales,
    required String currency,
    required bool isMobile,
  }) {
    final trendWidget = SalesTrendChart(
      dataPoints: salesTrend,
      currency: currency,
      isMobile: isMobile,
    );

    final donutWidget = PaymentModeDonutChart(
      paymentModes: paymentModes,
      totalSales: totalSales,
      currency: currency,
      isMobile: isMobile,
      onTap: () {
        setState(() {
          _activeTabIndex = 3; // Switch to Payment Mode tab
        });
      },
    );

    if (isMobile) {
      return Column(
        children: [
          trendWidget,
          const SizedBox(height: 12),
          donutWidget,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: trendWidget),
        const SizedBox(width: 14),
        Expanded(flex: 2, child: donutWidget),
      ],
    );
  }

  // ==========================================
  // 4. TABBED DATA SECTION & TABLES
  // ==========================================
  Widget _buildTabbedDataSection({
    required List<OrderModel> orders,
    required String currency,
    required bool isMobile,
  }) {
    final tabs = isMobile ? _mobileTabs : _desktopTabs;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with Tab Pills & Search Input
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scrollable Horizontal Pills
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: List.generate(tabs.length, (idx) {
                            return _buildTabPill(
                              title: tabs[idx],
                              isSelected: _activeTabIndex == idx,
                              onTap: () => setState(() {
                                _activeTabIndex = idx;
                                _currentPage = 1;
                              }),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Search Box & Filter Button
                      Row(
                        children: [
                          Expanded(
                            child: _buildSearchInput(),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _showDateFilterDialog,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Icon(Icons.filter_alt_rounded, size: 18, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      // Desktop Horizontal Pills
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: List.generate(tabs.length, (idx) {
                              return _buildTabPill(
                                title: tabs[idx],
                                isSelected: _activeTabIndex == idx,
                                onTap: () => setState(() {
                                  _activeTabIndex = idx;
                                  _currentPage = 1;
                                }),
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Search Input & Export Button
                      SizedBox(
                        width: 250,
                        child: _buildSearchInput(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _exportSalesToExcel,
                        tooltip: 'Export to Excel / CSV',
                        icon: const Icon(Icons.download_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                    ],
                  ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            )
          else
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Tab Content View
          _buildActiveTabContent(
            orders: orders,
            currency: currency,
            isMobile: isMobile,
          ),

          // Pagination Bar Footer
          _buildPaginationFooter(
            totalRecords: orders.length,
            isMobile: isMobile,
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) {
          setState(() => _currentPage = 1);
          _loadSalesReport(showLoading: false);
        },
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
        decoration: const InputDecoration(
          hintText: 'Search by bill no, order no...',
          hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
          prefixIcon: Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 9),
        ),
      ),
    );
  }

  // Active Tab Body Switcher
  Widget _buildActiveTabContent({
    required List<OrderModel> orders,
    required String currency,
    required bool isMobile,
  }) {
    switch (_activeTabIndex) {
      case 0:
        return _buildSalesDetailsView(orders: orders, currency: currency, isMobile: isMobile);
      case 1:
        return _buildTopProductsView(currency: currency, isMobile: isMobile);
      case 2:
        return _buildCategoryWiseView(currency: currency, isMobile: isMobile);
      case 3:
        return _buildPaymentModeDetailView(currency: currency, isMobile: isMobile);
      case 4:
        return _buildOrderTypeDetailView(currency: currency, isMobile: isMobile);
      case 5:
        return _buildOutletWiseView(currency: currency, isMobile: isMobile);
      case 6:
        return _buildStaffWiseView(currency: currency, isMobile: isMobile);
      default:
        return _buildSalesDetailsView(orders: orders, currency: currency, isMobile: isMobile);
    }
  }

  // --- TAB 1: SALES DETAILS / RECENT SALES ---
  Widget _buildSalesDetailsView({
    required List<OrderModel> orders,
    required String currency,
    required bool isMobile,
  }) {
    if (orders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFFCBD5E1)),
              SizedBox(height: 10),
              Text(
                'No sales records found',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    final startIndex = (_currentPage - 1) * _pageSize;
    final pagedOrders = orders.skip(startIndex).take(_pageSize).toList();

    if (isMobile) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: pagedOrders.length,
        separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (ctx, idx) {
          final order = pagedOrders[idx];
          return _buildMobileOrderRow(order: order, currency: currency);
        },
      );
    }

    // Desktop Table View
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        dataRowMinHeight: 46,
        dataRowMaxHeight: 50,
        horizontalMargin: 16,
        columnSpacing: 22,
        columns: const [
          DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
          DataColumn(label: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
          DataColumn(label: Text('Bill No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
          DataColumn(label: Text('Order Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
          DataColumn(label: Text('Table', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
          DataColumn(label: Text('Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
          DataColumn(label: Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
          DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
          DataColumn(label: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
        ],
        rows: List.generate(pagedOrders.length, (idx) {
          final order = pagedOrders[idx];
          final globalIndex = startIndex + idx + 1;
          final totalQty = order.items.fold(0, (sum, i) => sum + i.quantity);

          String formattedDate = order.createdAt;
          final dt = DateTime.tryParse(order.createdAt);
          if (dt != null) {
            formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dt.isUtc ? dt.toLocal() : dt);
          }

          return DataRow(
            cells: [
              DataCell(Text('$globalIndex', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
              DataCell(Text(formattedDate, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
              DataCell(Text('#${order.orderNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
              DataCell(_buildOrderTypeChip(order.orderType)),
              DataCell(Text(order.tableNumber?.isNotEmpty == true ? order.tableNumber! : '-', style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
              DataCell(Text(totalQty.toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
              DataCell(Text(order.paymentMethod, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
              DataCell(Text(order.customerName?.isNotEmpty == true ? order.customerName! : 'Walk-in', style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
              DataCell(Text(order.totalAmount.toStringAsFixed(0), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))),
              DataCell(
                PopupMenuButton<String>(
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (val) {
                    if (val == 'view') {
                      showDialog(
                        context: context,
                        builder: (_) => ReceiptDialog(order: order, currency: currency),
                      );
                    } else if (val == 'share') {
                      SharePlus.instance.share(
                        ShareParams(
                          text: 'Apna POS Bill #${order.orderNumber}\nAmount: $currency${order.totalAmount}\nPayment: ${order.paymentMethod}',
                        ),
                      );
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'view', child: Text('View Invoice / Receipt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                    PopupMenuItem(value: 'share', child: Text('Share Bill Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMobileOrderRow({
    required OrderModel order,
    required String currency,
  }) {
    final totalQty = order.items.fold(0, (sum, i) => sum + i.quantity);

    String formattedTime = order.createdAt;
    final dt = DateTime.tryParse(order.createdAt);
    if (dt != null) {
      formattedTime = DateFormat('hh:mm a').format(dt.isUtc ? dt.toLocal() : dt);
    }

    final isDineIn = order.orderType == OrderType.dineIn;
    final isTakeaway = order.orderType == OrderType.takeaway;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Order Type Icon Avatar
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDineIn
                  ? const Color(0xFFDCFCE7)
                  : (isTakeaway ? const Color(0xFFE0F2FE) : const Color(0xFFFEF3C7)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDineIn
                  ? Icons.restaurant_rounded
                  : (isTakeaway ? Icons.shopping_bag_rounded : Icons.delivery_dining_rounded),
              size: 16,
              color: isDineIn
                  ? const Color(0xFF16A34A)
                  : (isTakeaway ? const Color(0xFF0284C7) : const Color(0xFFD97706)),
            ),
          ),
          const SizedBox(width: 10),

          // Bill No & Time
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${order.orderNumber}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 1),
                Text(
                  formattedTime,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Order Type Chip
          _buildOrderTypeChip(order.orderType),
          const SizedBox(width: 8),

          // Table / Items
          if (order.tableNumber?.isNotEmpty == true) ...[
            Text(
              order.tableNumber!,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
          ],

          Text(
            '$totalQty items',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const Spacer(),

          // Bold Amount
          Text(
            '$currency${order.totalAmount.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          const SizedBox(width: 6),

          // 3 Dots Action
          PopupMenuButton<String>(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (val) {
              if (val == 'view') {
                showDialog(
                  context: context,
                  builder: (_) => ReceiptDialog(order: order, currency: currency),
                );
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'view', child: Text('View Invoice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
            ],
            child: const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTypeChip(OrderType type) {
    Color bg;
    Color text;
    String label;

    switch (type) {
      case OrderType.dineIn:
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        label = 'Dine In';
        break;
      case OrderType.takeaway:
        bg = const Color(0xFFE0F2FE);
        text = const Color(0xFF0369A1);
        label = 'Takeaway';
        break;
      case OrderType.delivery:
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        label = 'Delivery';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: text),
      ),
    );
  }

  // --- TAB 2: TOP PRODUCTS ---
  Widget _buildTopProductsView({required String currency, required bool isMobile}) {
    final topProds = _reportData?.topProducts ?? [];
    if (topProds.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('No top selling products recorded', style: TextStyle(color: Color(0xFF64748B)))),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: topProds.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (ctx, idx) {
        final p = topProds[idx];
        final isVeg = p.foodType == 'veg';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text('#${idx + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(width: 10),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  border: Border.all(color: isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626), width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    Text(p.category, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              Text('${p.quantity} sold', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              const SizedBox(width: 14),
              Text('$currency${p.revenue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 3: CATEGORY WISE ---
  Widget _buildCategoryWiseView({required String currency, required bool isMobile}) {
    final categories = _reportData?.categoryWise ?? [];
    if (categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('No category statistics found', style: TextStyle(color: Color(0xFF64748B)))),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (ctx, idx) {
        final c = categories[idx];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.categoryName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text('${c.itemsSold} items sold • ${c.percentage.toStringAsFixed(1)}% share', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Text('$currency${c.totalRevenue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 4: PAYMENT MODE DETAIL ---
  Widget _buildPaymentModeDetailView({required String currency, required bool isMobile}) {
    final modes = _reportData?.paymentModes ?? [];
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modes.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (ctx, idx) {
        final m = modes[idx];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.mode, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text('${m.count} bills • ${m.percentage.toStringAsFixed(1)}% of total sales', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Text('$currency${m.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 5: ORDER TYPE DETAIL ---
  Widget _buildOrderTypeDetailView({required String currency, required bool isMobile}) {
    final types = _reportData?.salesByOrderType ?? [];
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: types.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (ctx, idx) {
        final t = types[idx];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.type, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text('${t.count} orders • Avg: $currency${t.avgTicket.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Text('$currency${t.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 6: OUTLET WISE ---
  Widget _buildOutletWiseView({required String currency, required bool isMobile}) {
    final outlets = _reportData?.outletWise ?? [];
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: outlets.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (ctx, idx) {
        final o = outlets[idx];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.outletName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text('${o.billsCount} bills settled', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Text('$currency${o.totalRevenue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 7: STAFF WISE ---
  Widget _buildStaffWiseView({required String currency, required bool isMobile}) {
    final staff = _reportData?.staffWise ?? [];
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: staff.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (ctx, idx) {
        final s = staff[idx];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.staffName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text('${s.billsCount} bills processed', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Text('$currency${s.totalRevenue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // PAGINATION FOOTER
  // ==========================================
  Widget _buildPaginationFooter({
    required int totalRecords,
    required bool isMobile,
  }) {
    if (totalRecords == 0) return const SizedBox.shrink();

    final totalPages = (totalRecords / _pageSize).ceil();
    final startRec = (_currentPage - 1) * _pageSize + 1;
    final endRec = (_currentPage * _pageSize).clamp(1, totalRecords);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: isMobile
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing $startRec - $endRec of $totalRecords',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _pageSize = totalRecords;
                      _currentPage = 1;
                    });
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                      ),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Text(
                  'Showing $startRec - $endRec of $totalRecords records',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const Spacer(),

                // Prev Button
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  color: _currentPage > 1 ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                  onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                const SizedBox(width: 4),

                // Page Pills
                ...List.generate(totalPages.clamp(1, 5), (idx) {
                  final pageNum = idx + 1;
                  final isCurrent = pageNum == _currentPage;
                  return InkWell(
                    onTap: () => setState(() => _currentPage = pageNum),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: isCurrent ? const Color(0xFF051C48) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isCurrent ? const Color(0xFF051C48) : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '$pageNum',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                          color: isCurrent ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  );
                }),

                if (totalPages > 5) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('..', style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                  InkWell(
                    onTap: () => setState(() => _currentPage = totalPages),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: _currentPage == totalPages ? const Color(0xFF051C48) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _currentPage == totalPages ? const Color(0xFF051C48) : const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        '$totalPages',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: _currentPage == totalPages ? FontWeight.bold : FontWeight.w600,
                          color: _currentPage == totalPages ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(width: 4),
                // Next Button
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  color: _currentPage < totalPages ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                  onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                const SizedBox(width: 10),

                // Page Size Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _pageSize,
                      isDense: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF64748B)),
                      items: const [
                        DropdownMenuItem(value: 6, child: Text('6 / page', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 10, child: Text('10 / page', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 20, child: Text('20 / page', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 50, child: Text('50 / page', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _pageSize = val;
                            _currentPage = 1;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

