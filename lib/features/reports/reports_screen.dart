import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database/database_service.dart';
import '../../core/models/menu_item_model.dart';
import '../../core/models/order_model.dart';
import '../../core/services/report_service.dart';
import '../pos/receipt_dialog.dart';
import 'widgets/calendar_popup_card.dart';
import 'widgets/custom_date_range_picker_dialog.dart';
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
    'Sales Details',
    'Top Products',
    'Category Wise',
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
        if (_reportData == null) {
          _reportData = localData;
        }
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

  final GlobalKey _desktopDateRangeKey = GlobalKey();
  final GlobalKey _mobileDateRangeKey = GlobalKey();

  String _getDateRangeBoxDisplay() {
    final fmt = DateFormat('dd MMM yyyy');
    if (_customDateRange != null) {
      return '${fmt.format(_customDateRange!.start)} - ${fmt.format(_customDateRange!.end)}';
    }
    final now = DateTime.now();
    return '${fmt.format(DateTime(now.year, now.month, 1))} - ${fmt.format(now)}';
  }

  String _getPresetFilterDisplay() {
    switch (_selectedDateFilter) {
      case SalesDateFilter.today:
        return 'Today';
      case SalesDateFilter.yesterday:
        return 'Yesterday';
      case SalesDateFilter.thisWeek:
        return 'This Week';
      case SalesDateFilter.thisMonth:
        return 'This Month';
      case SalesDateFilter.allTime:
        return 'All Time';
      case SalesDateFilter.custom:
        return 'Custom Range';
    }
  }

  void _applyPresetFilter(SalesDateFilter filter) {
    final now = DateTime.now();
    DateTimeRange? range;
    switch (filter) {
      case SalesDateFilter.today:
        range = DateTimeRange(
          start: DateTime(now.year, now.month, now.day, 0, 0, 0),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );
        break;
      case SalesDateFilter.yesterday:
        final y = now.subtract(const Duration(days: 1));
        range = DateTimeRange(
          start: DateTime(y.year, y.month, y.day, 0, 0, 0),
          end: DateTime(y.year, y.month, y.day, 23, 59, 59, 999),
        );
        break;
      case SalesDateFilter.thisWeek:
        final diffToMonday = (now.weekday == 7 ? 6 : now.weekday - 1);
        final monday = now.subtract(Duration(days: diffToMonday));
        range = DateTimeRange(
          start: DateTime(monday.year, monday.month, monday.day, 0, 0, 0),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        );
        break;
      case SalesDateFilter.thisMonth:
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        range = DateTimeRange(
          start: DateTime(now.year, now.month, 1, 0, 0, 0),
          end: DateTime(now.year, now.month, lastDay, 23, 59, 59, 999),
        );
        break;
      case SalesDateFilter.allTime:
        range = DateTimeRange(
          start: DateTime(2020, 1, 1),
          end: now,
        );
        break;
      case SalesDateFilter.custom:
        break;
    }

    setState(() {
      _selectedDateFilter = filter;
      if (range != null) {
        _customDateRange = range;
      }
      _currentPage = 1;
    });
    _loadSalesReport();
  }

  void _openCalendarPopup(BuildContext context, {bool isMobile = false}) {
    final key = isMobile ? _mobileDateRangeKey : _desktopDateRangeKey;
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? const Offset(20, 80);
    final size = renderBox?.size ?? const Size(220, 36);
    final screenSize = MediaQuery.of(context).size;

    final now = DateTime.now();
    final initialStart = _customDateRange?.start ?? DateTime(now.year, now.month, 1);
    final initialEnd = _customDateRange?.end ?? now;

    double left = offset.dx;
    if (left + 315 > screenSize.width - 12) {
      left = (screenSize.width - 320).clamp(8.0, screenSize.width);
    }
    double top = offset.dy + size.height + 4;
    if (top + 340 > screenSize.height - 12) {
      top = (offset.dy - 346).clamp(8.0, screenSize.height);
    }

    showDialog(
      context: context,
      barrierColor: Colors.black12,
      builder: (ctx) {
        return Stack(
          children: [
            Positioned(
              left: isMobile ? (screenSize.width - 295) / 2 : left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: CalendarPopupCard(
                  initialStartDate: initialStart,
                  initialEndDate: initialEnd,
                  onRangeSelected: (newRange) {
                    setState(() {
                      _customDateRange = newRange;
                      _selectedDateFilter = SalesDateFilter.custom;
                      _currentPage = 1;
                    });
                    _loadSalesReport();
                  },
                  onApply: () {
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCustomDatePicker() async {
    final now = DateTime.now();
    final initialStart = _customDateRange?.start ?? DateTime(now.year, now.month, 1);
    final initialEnd = _customDateRange?.end ?? now;

    final picked = await CustomDateRangePickerDialog.show(
      context,
      initialStartDate: initialStart,
      initialEndDate: initialEnd,
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedDateFilter = SalesDateFilter.custom;
        _currentPage = 1;
      });
      _loadSalesReport();
    }
  }

  Widget _buildDateRangeBox({required bool isMobile}) {
    final dateRangeText = _getDateRangeBoxDisplay();
    final key = isMobile ? _mobileDateRangeKey : _desktopDateRangeKey;

    return InkWell(
      key: key,
      onTap: () => _openCalendarPopup(context, isMobile: isMobile),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: isMobile ? 34 : 42,
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: isMobile ? 13 : 16, color: const Color(0xFF0F172A)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      dateRangeText,
                      style: TextStyle(
                        fontSize: isMobile ? 10.5 : 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down_rounded, size: isMobile ? 15 : 19, color: const Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetFilterDropdown({required bool isMobile}) {
    final displayLabel = _getPresetFilterDisplay();

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          shadowColor: const Color(0x20000000),
        ),
      ),
      child: PopupMenuButton<SalesDateFilter>(
        tooltip: 'Select Preset Date Filter',
        offset: const Offset(0, 4),
        elevation: 8,
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        onSelected: (filter) {
          _applyPresetFilter(filter);
        },
        itemBuilder: (ctx) => [
          _buildPopupMenuItem(SalesDateFilter.today, 'Today', _selectedDateFilter == SalesDateFilter.today),
          _buildPopupMenuItem(SalesDateFilter.yesterday, 'Yesterday', _selectedDateFilter == SalesDateFilter.yesterday),
          _buildPopupMenuItem(SalesDateFilter.thisWeek, 'This Week', _selectedDateFilter == SalesDateFilter.thisWeek),
          _buildPopupMenuItem(SalesDateFilter.thisMonth, 'This Month', _selectedDateFilter == SalesDateFilter.thisMonth),
          _buildPopupMenuItem(SalesDateFilter.allTime, 'All Time', _selectedDateFilter == SalesDateFilter.allTime),
        ],
        child: Container(
          height: isMobile ? 34 : 42,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
          child: Row(
            mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_outlined, size: isMobile ? 14 : 17, color: const Color(0xFF0F172A)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        displayLabel,
                        style: TextStyle(
                          fontSize: isMobile ? 10.5 : 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down_rounded, size: isMobile ? 15 : 19, color: const Color(0xFF64748B)),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<SalesDateFilter> _buildPopupMenuItem(SalesDateFilter filter, String title, bool isSelected) {
    return PopupMenuItem<SalesDateFilter>(
      value: filter,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, size: 16, color: Color(0xFF2563EB)),
          ],
        ),
      ),
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

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
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
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            // Row 1: Two Date Filter Boxes Side by Side
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _buildDateRangeBox(isMobile: true),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 4,
                  child: _buildPresetFilterDropdown(isMobile: true),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: 3 Filter Dropdowns
            Row(
              children: [
                Expanded(
                  child: _buildCurvedDropdown(
                    value: _selectedOutlet,
                    items: ['All Outlets', _db.restaurant?.name ?? 'Main Outlet'],
                    isMobile: true,
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
                    isMobile: true,
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
                    isMobile: true,
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

            // Row 3: Action Buttons: Apply, Reset, and Refresh Icon
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _currentPage = 1);
                      _loadSalesReport();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Apply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 3,
                  child: OutlinedButton(
                    onPressed: _resetFilters,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: Colors.white,
                    ),
                    child: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF334155), size: 16),
                    tooltip: 'Refresh Data',
                    onPressed: () => _loadSalesReport(),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Desktop / Windows Filter Bar: Filter dropdowns on the left, Action buttons on the far right
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Left side: Filter dropdowns in a horizontally scrollable container if needed
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Box 1: Date Range Box
                  _buildDateRangeBox(isMobile: false),
                  const SizedBox(width: 10),

                  // Box 2: Preset Filter Dropdown Box
                  _buildPresetFilterDropdown(isMobile: false),
                  const SizedBox(width: 10),

                  // Outlet Dropdown
                  _buildCurvedDropdown(
                    value: _selectedOutlet,
                    items: ['All Outlets', _db.restaurant?.name ?? 'Main Outlet'],
                    isMobile: false,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedOutlet = val);
                    },
                  ),
                  const SizedBox(width: 10),

                  // Payment Mode Dropdown
                  _buildCurvedDropdown(
                    value: _selectedPaymentMode,
                    items: const ['All Payment Modes', 'Cash', 'UPI', 'Card', 'Wallet'],
                    isMobile: false,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPaymentMode = val);
                    },
                  ),
                  const SizedBox(width: 10),

                  // Order Types Dropdown
                  _buildCurvedDropdown(
                    value: _selectedOrderType,
                    items: const ['All Order Types', 'Dine In', 'Takeaway', 'Delivery'],
                    isMobile: false,
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedOrderType = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Right side: Action Buttons pinned to the right
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  minimumSize: const Size(70, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Apply', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),

              // Reset Button
              OutlinedButton(
                onPressed: _resetFilters,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  minimumSize: const Size(70, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  backgroundColor: Colors.white,
                ),
                child: const Text('Reset', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),

              // Refresh Icon Button beside Reset
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF334155)),
                  tooltip: 'Refresh Report Data',
                  onPressed: () => _loadSalesReport(),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurvedDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool isMobile = false,
  }) {
    final effectiveValue = items.contains(value) ? value : items.first;

    return Container(
      height: isMobile ? 34 : 42,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isDense: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(10),
          elevation: 6,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: isMobile ? 14 : 19, color: const Color(0xFF64748B)),
          style: TextStyle(
            fontSize: isMobile ? 10.5 : 13.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isMobile ? 10.5 : 13.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
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
      icon: Icons.south_west_rounded,
      iconBgColor: const Color(0xFFDCFCE7),
      iconColor: const Color(0xFF16A34A),
      cardGradient: const LinearGradient(
        colors: [Color(0xFFF0FDF4), Color(0xFFFAFDFA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: const Color(0xFFDCFCE7),
      title: 'Total Sales',
      value: '$currency${_formatKpiAmount(summary.totalRevenue)}',
      trendPct: summary.growthSalesPct,
      sparklineColor: const Color(0xFF16A34A),
      isMobile: isMobile,
    );

    final card2 = _buildKpiCard(
      icon: Icons.description_rounded,
      iconBgColor: const Color(0xFFEFF6FF),
      iconColor: const Color(0xFF2563EB),
      cardGradient: const LinearGradient(
        colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: const Color(0xFFDBEAFE),
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
      cardGradient: const LinearGradient(
        colors: [Color(0xFFFFFBEB), Color(0xFFFFFDF5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: const Color(0xFFFEF3C7),
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
      cardGradient: const LinearGradient(
        colors: [Color(0xFFFAF5FF), Color(0xFFFDFBFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: const Color(0xFFEDE9FE),
      title: isMobile ? 'Items Sold' : 'Total Items Sold',
      value: _formatKpiAmount(summary.totalItems.toDouble()),
      trendPct: summary.growthItemsPct,
      sparklineColor: const Color(0xFF7C3AED),
      isMobile: isMobile,
    );

    final card5 = _buildKpiCard(
      icon: Icons.receipt_rounded,
      iconBgColor: const Color(0xFFFCE7F3),
      iconColor: const Color(0xFFDB2777),
      cardGradient: const LinearGradient(
        colors: [Color(0xFFFFF1F2), Color(0xFFFFF8F8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: const Color(0xFFFCE7F3),
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
    required Gradient cardGradient,
    required Color borderColor,
    required String title,
    required String value,
    required double trendPct,
    required Color sparklineColor,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
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
                child: Icon(icon, color: iconColor, size: isMobile ? 15 : 17),
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
            ],
          ),
          const SizedBox(height: 8),

          // Big Amount
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 16 : 18.5,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          // Trend + Sparkline Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_drop_up_rounded, color: Color(0xFF16A34A), size: 16),
                        Text(
                          '+${trendPct.toInt()}%',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'vs previous period',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              MetricSparkline(
                color: sparklineColor,
                width: isMobile ? 42 : 52,
                height: isMobile ? 20 : 24,
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
    final effectiveOrders = orders;
    final totalRecords = orders.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with Tab Pills & Search Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      const SizedBox(height: 12),

                      // Search Box & Filter Button
                      Row(
                        children: [
                          Expanded(
                            child: _buildSearchInput(),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _openCustomDatePicker,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
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

                      // Search Input matching reference mockup
                      SizedBox(
                        width: 270,
                        child: _buildSearchInput(),
                      ),
                    ],
                  ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E60F2)),
            ),

          // Tab Content View
          _buildActiveTabContent(
            orders: effectiveOrders,
            currency: currency,
            isMobile: isMobile,
          ),

          // Pagination Bar Footer
          _buildPaginationFooter(
            totalRecords: totalRecords,
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
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.5),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E60F2) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
          hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
          prefixIcon: Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
          border: InputBorder.none,
          isDense: true,
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

    return LayoutBuilder(
      builder: (context, constraints) {
        const double minTableWidth = 880.0;
        final double effectiveWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

        final tableContent = SizedBox(
          width: effectiveWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row matching mockup
              Container(
                height: 42,
                color: const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Row(
                  children: [
                    SizedBox(width: 35, child: Text('#', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A)))),
                    Expanded(flex: 150, child: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A)))),
                    Expanded(flex: 85, child: Text('Bill No', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A)))),
                    Expanded(flex: 95, child: Text('Order Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A)))),
                    Expanded(flex: 60, child: Text('Table', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A)))),
                    Expanded(flex: 50, child: Text('Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A)))),
                    Expanded(flex: 110, child: Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A)))),
                    Expanded(flex: 115, child: Text('Customer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A)))),
                    Expanded(flex: 90, child: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A)))),
                    SizedBox(width: 45, child: Text('Action', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A)))),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Data Rows
              ...List.generate(pagedOrders.length, (idx) {
                final order = pagedOrders[idx];
                final globalIndex = startIndex + idx + 1;
                final totalQty = order.items.fold(0, (sum, i) => sum + i.quantity);

                String formattedDate = order.createdAt;
                final dt = DateTime.tryParse(order.createdAt);
                if (dt != null) {
                  formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dt.isUtc ? dt.toLocal() : dt);
                }

                return Column(
                  children: [
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 35,
                            child: Text('$globalIndex', style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                          ),
                          Expanded(
                            flex: 150,
                            child: Text(formattedDate, style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
                          ),
                          Expanded(
                            flex: 85,
                            child: Text(
                              order.orderNumber.startsWith('#') ? order.orderNumber : '#${order.orderNumber}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                          ),
                          Expanded(
                            flex: 95,
                            child: Align(alignment: Alignment.centerLeft, child: _buildOrderTypeChip(order.orderType)),
                          ),
                          Expanded(
                            flex: 60,
                            child: Text(order.tableNumber?.isNotEmpty == true ? order.tableNumber! : '-', style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                          ),
                          Expanded(
                            flex: 50,
                            child: Text('$totalQty', style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                          ),
                          Expanded(
                            flex: 110,
                            child: Text(order.paymentMethod, style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                          ),
                          Expanded(
                            flex: 115,
                            child: Text(
                              order.customerName?.isNotEmpty == true ? order.customerName! : 'Walk-in',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 90,
                            child: Text(
                              _formatNumber(order.totalAmount),
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                          ),
                          SizedBox(
                            width: 45,
                            child: PopupMenuButton<String>(
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
                              child: const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (idx < pagedOrders.length - 1)
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ],
                );
              }),
            ],
          ),
        );

        if (constraints.maxWidth < minTableWidth) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: tableContent,
          );
        }
        return tableContent;
      },
    );
  }

  String _formatNumber(double val) {
    final str = val.toStringAsFixed(0);
    return str.replaceAllMapped(RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))(\.\d+)?'), (Match m) => '${m[1]},');
  }

  Widget _buildOrderTypeChip(OrderType type) {
    Color bg;
    Color text;
    String label;

    switch (type) {
      case OrderType.dineIn:
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF16A34A);
        label = 'Dine In';
        break;
      case OrderType.takeaway:
        bg = const Color(0xFFDBEAFE);
        text = const Color(0xFF2563EB);
        label = 'Takeaway';
        break;
      case OrderType.delivery:
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFD97706);
        label = 'Delivery';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: text),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
              Text('$currency${_formatNumber(p.revenue)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF16A34A))),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
              Text('$currency${_formatNumber(c.totalRevenue)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
              Text('$currency${_formatNumber(m.amount)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.type, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text('${t.count} orders • Avg: $currency${_formatNumber(t.avgTicket)}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Text('$currency${_formatNumber(t.amount)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
              Text('$currency${_formatNumber(o.totalRevenue)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
              Text('$currency${_formatNumber(s.totalRevenue)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
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
    final maxDirectPages = totalPages > 5 ? 5 : totalPages;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: isMobile
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing $startRec - $endRec of $totalRecords',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
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
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E60F2)),
                      ),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF1E60F2)),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Text(
                  'Showing $startRec - $endRec of $totalRecords records',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                ),
                const Spacer(),

                // Prev Button
                InkWell(
                  onTap: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: _currentPage > 1 ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                const SizedBox(width: 5),

                // Page Pills
                for (int p = 1; p <= maxDirectPages; p++)
                  InkWell(
                    onTap: () => setState(() => _currentPage = p),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        color: _currentPage == p ? const Color(0xFF0A3F9B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: _currentPage == p ? null : Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Text(
                          '$p',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _currentPage == p ? FontWeight.w700 : FontWeight.w600,
                            color: _currentPage == p ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ),

                if (totalPages > 5) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  ),
                  InkWell(
                    onTap: () => setState(() => _currentPage = totalPages),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        color: _currentPage == totalPages ? const Color(0xFF0A3F9B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: _currentPage == totalPages ? null : Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Text(
                          '$totalPages',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _currentPage == totalPages ? FontWeight.w700 : FontWeight.w600,
                            color: _currentPage == totalPages ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(width: 5),

                // Next Button
                InkWell(
                  onTap: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: _currentPage < totalPages ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

