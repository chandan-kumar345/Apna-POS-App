import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';
import '../../core/services/report_service.dart';
import '../pos/receipt_dialog.dart';
import 'widgets/calendar_popup_card.dart';
import 'widgets/metric_sparkline.dart';
import 'widgets/payment_mode_donut_chart.dart';
import 'widgets/sales_trend_chart.dart';

enum SalesDateFilter { allTime, today, yesterday, thisWeek, thisMonth, custom }

/// Neumorphic Theme & Shadow Configurations for Sales Report - Calibrated for high performance & tactile depth
class _ReportsNeumorphicTheme {
  static const Color background = Color(0xFFEEF2F6);
  static const Color surface = Color(0xFFEEF2F6);
  static const Color sunkenSurface = Color(0xFFE2E9F2);
  static const Color darkShadow = Color(0xFFC5D1E0);

  static const Color textDark = Color(0xFF0F172A);
  static const Color textBody = Color(0xFF334155);
  static const Color textMuted = Color(0xFF64748B);
  static const Color navyBrand = Color(0xFF051C48);
  static const Color blueBrand = Color(0xFF1E60F2);

  /// Standard raised card shadows - crisp, clean, soft neumorphic depth without light spreading
  static List<BoxShadow> get raisedShadows => [
        BoxShadow(
          color: darkShadow.withValues(alpha: 0.22),
          offset: const Offset(0, 3),
          blurRadius: 6,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.6),
          offset: const Offset(0, -1),
          blurRadius: 2,
          spreadRadius: 0,
        ),
      ];

  /// Soft raised shadows for compact buttons, dropdowns, page pills - crisp, tight shadow
  static List<BoxShadow> get softRaisedShadows => [
        BoxShadow(
          color: darkShadow.withValues(alpha: 0.18),
          offset: const Offset(0, 1.5),
          blurRadius: 3.5,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.5),
          offset: const Offset(0, -0.5),
          blurRadius: 1.5,
          spreadRadius: 0,
        ),
      ];

  /// Sunken / Inset well shadows for unselected tabs, inner boxes & search bar
  static List<BoxShadow> get sunkenShadows => [
        BoxShadow(
          color: darkShadow.withValues(alpha: 0.15),
          offset: const Offset(0, 1.5),
          blurRadius: 3,
          spreadRadius: 0,
        ),
      ];

  /// Clean accent shadow for active pills & primary action buttons without diffuse light spreading
  static List<BoxShadow> get accentShadows => [
        BoxShadow(
          color: blueBrand.withValues(alpha: 0.24),
          offset: const Offset(0, 2.5),
          blurRadius: 5,
          spreadRadius: 0,
        ),
      ];
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseService _db = DatabaseService();
  final ReportService _reportService = ReportService();

  // Filters State
  SalesDateFilter _selectedDateFilter = SalesDateFilter.today;
  DateTimeRange? _customDateRange;
  String _selectedOutlet = 'All Outlets';
  String _selectedPaymentMode = 'All Payment Modes';
  String _selectedOrderType = 'All Order Types';
  String _selectedStaff = 'All Staff';
  final TextEditingController _searchController = TextEditingController();

  // Data State
  bool _isLoading = false;
  SalesReportData? _reportData;
  int _requestSeq = 0;
  final Set<String> _expandedStaffIds = {};
  Timer? _dbDebounceTimer;

  // Active Tab & Pagination
  int _activeTabIndex = 0;
  int _currentPage = 1;
  int _pageSize = 15;

  bool get _isStaffUser => _db.currentUser != null && !_db.currentUser!.isOwner && !_db.currentUser!.isAdmin;

  List<String> get _staffDropdownItems {
    final Set<String> staffSet = {'All Staff'};
    for (final s in _db.staffList) {
      if (s.name.trim().isNotEmpty) {
        staffSet.add(s.name.trim());
      }
    }
    if (_reportData?.staffWise != null) {
      for (final s in _reportData!.staffWise) {
        if (s.staffName.trim().isNotEmpty) {
          staffSet.add(s.staffName.trim());
        }
      }
    }
    for (final o in _db.orders) {
      if (o.staffName != null && o.staffName!.trim().isNotEmpty) {
        staffSet.add(o.staffName!.trim());
      }
    }
    return staffSet.toList();
  }

  List<String> get _effectiveTabs {
    if (_isStaffUser) {
      return [
        'My Sales Details',
        'Top Products',
        'Category Wise',
        'Payment Mode',
        'Order Type',
      ];
    }
    return [
      'Sales Details',
      'Top Products',
      'Category Wise',
      'Payment Mode',
      'Order Type',
      'Outlet Wise',
      'Staff Wise',
    ];
  }

  @override
  void initState() {
    super.initState();
    _db.addListener(_onDbChange);

    // Initial default: Today
    final now = DateTime.now();
    _selectedDateFilter = SalesDateFilter.today;
    _customDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day, 0, 0, 0),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
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
      staff: params.$4,
      search: _searchController.text,
    );

    _loadSalesReport(showLoading: false);
  }

  @override
  void dispose() {
    _dbDebounceTimer?.cancel();
    _db.removeListener(_onDbChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onDbChange() {
    if (!mounted) return;
    _dbDebounceTimer?.cancel();
    _dbDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        _loadSalesReport(showLoading: false);
      }
    });
  }

  (String?, String?, String?, String?) _resolveFilterParams() {
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
        startDate = startToday.toIso8601String();
        endDate = endToday.toIso8601String();
        break;
      case SalesDateFilter.yesterday:
        period = 'yesterday';
        final y = now.subtract(const Duration(days: 1));
        final startY = DateTime(y.year, y.month, y.day, 0, 0, 0);
        final endY = DateTime(y.year, y.month, y.day, 23, 59, 59, 999);
        startDate = startY.toIso8601String();
        endDate = endY.toIso8601String();
        break;
      case SalesDateFilter.thisWeek:
        period = 'thisWeek';
        final diffToMonday = (now.weekday == 7 ? 6 : now.weekday - 1);
        final monday = now.subtract(Duration(days: diffToMonday));
        final startWeek = DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
        final endWeek = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        startDate = startWeek.toIso8601String();
        endDate = endWeek.toIso8601String();
        break;
      case SalesDateFilter.thisMonth:
        period = 'thisMonth';
        final startMonth = DateTime(now.year, now.month, 1, 0, 0, 0);
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        final endMonth = DateTime(now.year, now.month, lastDay, 23, 59, 59, 999);
        startDate = startMonth.toIso8601String();
        endDate = endMonth.toIso8601String();
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
          startDate = start.toIso8601String();
          endDate = end.toIso8601String();
          period = (start.year == end.year && start.month == end.month && start.day == end.day) ? 'singleDay' : 'custom';
        } else {
          period = 'allTime';
        }
        break;
    }

    final staffParam = _isStaffUser ? null : (_selectedStaff == 'All Staff' ? null : _selectedStaff);
    return (period, startDate, endDate, staffParam);
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
      staff: params.$4,
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
        staff: params.$4,
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
      _selectedDateFilter = SalesDateFilter.today;
      final now = DateTime.now();
      _customDateRange = DateTimeRange(
        start: DateTime(now.year, now.month, now.day, 0, 0, 0),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
      );
      _selectedOutlet = 'All Outlets';
      _selectedPaymentMode = 'All Payment Modes';
      _selectedOrderType = 'All Order Types';
      _selectedStaff = 'All Staff';
      _searchController.clear();
      _currentPage = 1;
    });
    _loadSalesReport();
  }

  final GlobalKey _desktopDateRangeKey = GlobalKey();
  final GlobalKey _mobileDateRangeKey = GlobalKey();

  String _getDateRangeBoxDisplay() {
    final fmt = DateFormat('dd MMM yyyy');
    if (_selectedDateFilter == SalesDateFilter.today) {
      return DateFormat('dd MMM yyyy').format(DateTime.now());
    }
    if (_selectedDateFilter == SalesDateFilter.yesterday) {
      final y = DateTime.now().subtract(const Duration(days: 1));
      return DateFormat('dd MMM yyyy').format(y);
    }
    if (_customDateRange != null) {
      final startStr = fmt.format(_customDateRange!.start);
      final endStr = fmt.format(_customDateRange!.end);
      if (startStr == endStr) {
        return startStr;
      }
      return '$startStr - $endStr';
    }
    final now = DateTime.now();
    return fmt.format(now);
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

  Widget _buildDateRangeBox({required bool isMobile}) {
    final dateRangeText = _getDateRangeBoxDisplay();
    final key = isMobile ? _mobileDateRangeKey : _desktopDateRangeKey;

    return InkWell(
      key: key,
      onTap: () => _openCalendarPopup(context, isMobile: isMobile),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: isMobile ? 38 : 42,
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 9 : 14),
        decoration: BoxDecoration(
          color: _ReportsNeumorphicTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
          boxShadow: _ReportsNeumorphicTheme.softRaisedShadows,
        ),
        child: Row(
          mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded, size: isMobile ? 14 : 16, color: _ReportsNeumorphicTheme.navyBrand),
            SizedBox(width: isMobile ? 6 : 8),
            if (isMobile)
              Expanded(
                child: Text(
                  dateRangeText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _ReportsNeumorphicTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              Text(
                dateRangeText,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _ReportsNeumorphicTheme.textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            SizedBox(width: isMobile ? 4 : 6),
            Icon(Icons.keyboard_arrow_down_rounded, size: isMobile ? 16 : 19, color: _ReportsNeumorphicTheme.textMuted),
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
          color: _ReportsNeumorphicTheme.surface,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.1),
          ),
          shadowColor: _ReportsNeumorphicTheme.darkShadow.withValues(alpha: 0.5),
        ),
      ),
      child: PopupMenuButton<SalesDateFilter>(
        tooltip: 'Select Preset Date Filter',
        offset: const Offset(0, 4),
        elevation: 8,
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        color: _ReportsNeumorphicTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.1),
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
          height: isMobile ? 38 : 42,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 9 : 14),
          decoration: BoxDecoration(
            color: _ReportsNeumorphicTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
            boxShadow: _ReportsNeumorphicTheme.softRaisedShadows,
          ),
          child: Row(
            mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_outlined, size: isMobile ? 15 : 17, color: _ReportsNeumorphicTheme.navyBrand),
              SizedBox(width: isMobile ? 6 : 8),
              if (isMobile)
                Expanded(
                  child: Text(
                    displayLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _ReportsNeumorphicTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                Text(
                  displayLabel,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _ReportsNeumorphicTheme.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              SizedBox(width: isMobile ? 4 : 6),
              Icon(Icons.keyboard_arrow_down_rounded, size: isMobile ? 16 : 19, color: _ReportsNeumorphicTheme.textMuted),
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
          color: isSelected ? _ReportsNeumorphicTheme.sunkenSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: _ReportsNeumorphicTheme.blueBrand.withValues(alpha: 0.3), width: 1) : null,
          boxShadow: isSelected ? _ReportsNeumorphicTheme.sunkenShadows : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? _ReportsNeumorphicTheme.blueBrand : _ReportsNeumorphicTheme.textDark,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, size: 16, color: _ReportsNeumorphicTheme.blueBrand),
          ],
        ),
      ),
    );
  }

  Future<void> _exportSalesToExcel() async {
    final ordersToExport = _reportData?.orders ?? [];
    if (ordersToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No sales records found to export.'),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final currency = _db.restaurant?.currencySymbol ?? '₹';
    final List<List<dynamic>> rows = [
      _isStaffUser
          ? ['Bill No', 'Date & Time', 'Order Type', 'Table', 'Ordered Products (Bill-Wise)', 'Items Count', 'Payment Mode', 'Customer', 'Amount ($currency)']
          : ['Bill No', 'Date & Time', 'Handled By / Staff', 'Order Type', 'Table', 'Ordered Products (Bill-Wise)', 'Items Count', 'Payment Mode', 'Customer', 'Amount ($currency)'],
    ];

    for (final o in ordersToExport) {
      final itemsCount = o.items.fold(0, (sum, i) => sum + i.quantity);
      final typeStr = o.orderType == OrderType.dineIn
          ? 'Dine In'
          : (o.orderType == OrderType.takeaway ? 'Takeaway' : 'Delivery');

      final orderedProducts = o.items.isEmpty
          ? '-'
          : o.items
              .map((i) => '${i.item.name} x${i.quantity} ($currency${(i.item.effectivePrice * i.quantity).toStringAsFixed(0)})')
              .join('; ');

      if (_isStaffUser) {
        rows.add([
          o.orderNumber,
          o.createdAt,
          typeStr,
          o.tableNumber ?? '-',
          orderedProducts,
          itemsCount,
          o.paymentMethod,
          o.customerName ?? 'Walk-in',
          o.totalAmount.toStringAsFixed(2),
        ]);
      } else {
        rows.add([
          o.orderNumber,
          o.createdAt,
          o.staffName ?? 'Direct / Owner',
          typeStr,
          o.tableNumber ?? '-',
          orderedProducts,
          itemsCount,
          o.paymentMethod,
          o.customerName ?? 'Walk-in',
          o.totalAmount.toStringAsFixed(2),
        ]);
      }
    }

    final StringBuffer csvBuffer = StringBuffer();
    for (final row in rows) {
      final line = row.map((f) => '"${f.toString().replaceAll('"', '""')}"').join(',');
      csvBuffer.writeln(line);
    }

    try {
      Directory? targetDir;
      try {
        if (Platform.isAndroid) {
          final docsDir = Directory('/storage/emulated/0/Documents');
          if (!docsDir.existsSync()) {
            try {
              await docsDir.create(recursive: true);
            } catch (_) {}
          }
          if (await docsDir.exists()) {
            targetDir = docsDir;
          } else {
            final downloadDir = Directory('/storage/emulated/0/Download');
            if (await downloadDir.exists()) {
              targetDir = downloadDir;
            }
          }
        }
      } catch (_) {}

      try {
        targetDir ??= await getApplicationDocumentsDirectory();
      } catch (_) {}
      try {
        targetDir ??= await getDownloadsDirectory();
      } catch (_) {}
      try {
        targetDir ??= await getExternalStorageDirectory();
      } catch (_) {}
      try {
        targetDir ??= await getTemporaryDirectory();
      } catch (_) {}
      targetDir ??= Directory.systemTemp;

      final now = DateTime.now();
      final dateTag = DateFormat('yyyyMMdd_HHmmss').format(now);
      final filePath = '${targetDir.path}/Sales_Report_$dateTag.csv';
      final file = File(filePath);
      await file.writeAsString(csvBuffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your Excel sales report is downloaded.',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
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
      backgroundColor: _ReportsNeumorphicTheme.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 750;
            final isDesktop = constraints.maxWidth >= 1050;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 20,
                vertical: isMobile ? 12 : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- STAFF NOTICE BANNER (WHEN LOGGED IN AS STAFF) ---
                  if (_isStaffUser) ...[
                    RepaintBoundary(
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _ReportsNeumorphicTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD6E2EE), width: 1.1),
                          boxShadow: _ReportsNeumorphicTheme.softRaisedShadows,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [_ReportsNeumorphicTheme.blueBrand, _ReportsNeumorphicTheme.navyBrand],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: _ReportsNeumorphicTheme.accentShadows,
                              ),
                              child: const Icon(Icons.person_rounded, size: 16, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Personal Sales Report: ${_db.currentUser?.name ?? "Staff"}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _ReportsNeumorphicTheme.navyBrand,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Role: ${(_db.currentUser?.role ?? "Staff").toUpperCase()} • Displaying only your processed orders',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _ReportsNeumorphicTheme.blueBrand,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _ReportsNeumorphicTheme.navyBrand,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'My Orders Only',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  // --- 1. TOP FILTER BAR ---
                  RepaintBoundary(
                    child: _buildTopFilterBar(isMobile: isMobile),
                  ),
                  const SizedBox(height: 16),

                  // --- 2. TOP 5 METRIC CARDS ---
                  RepaintBoundary(
                    child: _buildTopMetricCards(summary: summary, currency: currency, isMobile: isMobile, isDesktop: isDesktop),
                  ),
                  const SizedBox(height: 16),

                  // --- 3. CHARTS & VISUAL ANALYTICS SECTION ---
                  RepaintBoundary(
                    child: _buildChartsSection(
                      salesTrend: salesTrend,
                      paymentModes: paymentModes,
                      totalSales: summary.totalRevenue,
                      currency: currency,
                      isMobile: isMobile,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // --- 4. TABBED DATA & RECENT SALES TABLE SECTION ---
                  RepaintBoundary(
                    child: _buildTabbedDataSection(
                      orders: allOrders,
                      currency: currency,
                      isMobile: isMobile,
                    ),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _ReportsNeumorphicTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD6E2EE), width: 1.1),
          boxShadow: _ReportsNeumorphicTheme.raisedShadows,
        ),
        child: Column(
          children: [
            // Row 1: Two Date Filter Boxes Side by Side
            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: _buildDateRangeBox(isMobile: true),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: _buildPresetFilterDropdown(isMobile: true),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Outlet and Payment Mode Dropdowns
            Row(
              children: [
                Expanded(
                  child: _buildCurvedDropdown(
                    value: _selectedOutlet,
                    items: ['All Outlets', _db.restaurant?.name ?? 'Main Outlet'],
                    isMobile: true,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedOutlet = val;
                          _currentPage = 1;
                        });
                        _loadSalesReport(showLoading: false);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCurvedDropdown(
                    value: _selectedPaymentMode == 'All Payment Modes' ? 'All Payments' : _selectedPaymentMode,
                    items: const ['All Payments', 'Cash', 'UPI', 'Card', 'Wallet'],
                    isMobile: true,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedPaymentMode = val == 'All Payments' ? 'All Payment Modes' : val;
                          _currentPage = 1;
                        });
                        _loadSalesReport(showLoading: false);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 3: Order Type and Staff Dropdowns
            Row(
              children: [
                Expanded(
                  child: _buildCurvedDropdown(
                    value: _selectedOrderType == 'All Order Types' ? 'All Orders' : _selectedOrderType,
                    items: const ['All Orders', 'Dine In', 'Takeaway', 'Delivery'],
                    isMobile: true,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedOrderType = val == 'All Orders' ? 'All Order Types' : val;
                          _currentPage = 1;
                        });
                        _loadSalesReport(showLoading: false);
                      }
                    },
                  ),
                ),
                if (!_isStaffUser) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCurvedDropdown(
                      value: _selectedStaff,
                      items: _staffDropdownItems,
                      isMobile: true,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedStaff = val;
                            _currentPage = 1;
                          });
                          _loadSalesReport(showLoading: false);
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Row 4: Action Buttons: Apply, Reset, and Refresh Icon
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _currentPage = 1);
                      _loadSalesReport(showLoading: false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ReportsNeumorphicTheme.blueBrand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      shadowColor: _ReportsNeumorphicTheme.blueBrand.withValues(alpha: 0.3),
                    ),
                    child: const Text('Apply', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: InkWell(
                    onTap: _resetFilters,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _ReportsNeumorphicTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                        boxShadow: _ReportsNeumorphicTheme.softRaisedShadows,
                      ),
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _ReportsNeumorphicTheme.textBody,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _exportSalesToExcel,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 38,
                    width: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _ReportsNeumorphicTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                      boxShadow: _ReportsNeumorphicTheme.softRaisedShadows,
                    ),
                    child: const Icon(Icons.file_download_outlined, color: _ReportsNeumorphicTheme.navyBrand, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _loadSalesReport(showLoading: false),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 38,
                    width: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _ReportsNeumorphicTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                      boxShadow: _ReportsNeumorphicTheme.softRaisedShadows,
                    ),
                    child: const Icon(Icons.refresh_rounded, color: _ReportsNeumorphicTheme.navyBrand, size: 18),
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
        color: _ReportsNeumorphicTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E2EE), width: 1.1),
        boxShadow: _ReportsNeumorphicTheme.raisedShadows,
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
                      if (val != null) {
                        setState(() {
                          _selectedOutlet = val;
                          _currentPage = 1;
                        });
                        _loadSalesReport(showLoading: false);
                      }
                    },
                  ),
                  const SizedBox(width: 10),

                  // Payment Mode Dropdown
                  _buildCurvedDropdown(
                    value: _selectedPaymentMode,
                    items: const ['All Payment Modes', 'Cash', 'UPI', 'Card', 'Wallet'],
                    isMobile: false,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedPaymentMode = val;
                          _currentPage = 1;
                        });
                        _loadSalesReport(showLoading: false);
                      }
                    },
                  ),
                  const SizedBox(width: 10),

                  // Order Types Dropdown
                  _buildCurvedDropdown(
                    value: _selectedOrderType,
                    items: const ['All Order Types', 'Dine In', 'Takeaway', 'Delivery'],
                    isMobile: false,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedOrderType = val;
                          _currentPage = 1;
                        });
                        _loadSalesReport(showLoading: false);
                      }
                    },
                  ),

                  // Staff Dropdown (Owner Exclusive)
                  if (!_isStaffUser) ...[
                    const SizedBox(width: 10),
                    _buildCurvedDropdown(
                      value: _selectedStaff,
                      items: _staffDropdownItems,
                      isMobile: false,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedStaff = val;
                            _currentPage = 1;
                          });
                          _loadSalesReport(showLoading: false);
                        }
                      },
                    ),
                  ],
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
                  _loadSalesReport(showLoading: false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _ReportsNeumorphicTheme.blueBrand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  minimumSize: const Size(70, 42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  shadowColor: _ReportsNeumorphicTheme.blueBrand.withValues(alpha: 0.3),
                ),
                child: const Text('Apply', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),

              // Reset Button
              InkWell(
                onTap: _resetFilters,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _ReportsNeumorphicTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                    boxShadow: _ReportsNeumorphicTheme.softRaisedShadows,
                  ),
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _ReportsNeumorphicTheme.textBody,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Export CSV Button
              InkWell(
                onTap: _exportSalesToExcel,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _ReportsNeumorphicTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                    boxShadow: _ReportsNeumorphicTheme.softRaisedShadows,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.file_download_outlined, size: 18, color: _ReportsNeumorphicTheme.navyBrand),
                      SizedBox(width: 5),
                      Text(
                        'Export',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _ReportsNeumorphicTheme.textBody,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Refresh Icon Button beside Reset
              InkWell(
                onTap: () => _loadSalesReport(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 42,
                  width: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _ReportsNeumorphicTheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                    boxShadow: _ReportsNeumorphicTheme.softRaisedShadows,
                  ),
                  child: const Icon(Icons.refresh_rounded, size: 20, color: _ReportsNeumorphicTheme.navyBrand),
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
      height: isMobile ? 38 : 42,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 9 : 14),
      decoration: BoxDecoration(
        color: _ReportsNeumorphicTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
        boxShadow: _ReportsNeumorphicTheme.softRaisedShadows,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isDense: true,
          isExpanded: isMobile,
          dropdownColor: _ReportsNeumorphicTheme.surface,
          borderRadius: BorderRadius.circular(12),
          elevation: 6,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: isMobile ? 16 : 19, color: _ReportsNeumorphicTheme.textMuted),
          style: TextStyle(
            fontSize: isMobile ? 11 : 13.5,
            fontWeight: FontWeight.w600,
            color: _ReportsNeumorphicTheme.textDark,
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isMobile ? 11 : 13.5,
                  fontWeight: FontWeight.w600,
                  color: _ReportsNeumorphicTheme.textDark,
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
      iconAsset: 'assets/images/sales report icon/total sales.png',
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
      iconAsset: 'assets/images/sales report icon/total orders.png',
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
      iconAsset: 'assets/images/sales report icon/avg order value.png',
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
      iconAsset: 'assets/images/sales report icon/items sold.png',
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
      iconAsset: 'assets/images/sales report icon/Total bills.png',
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
    String? iconAsset,
    IconData? icon,
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
        color: _ReportsNeumorphicTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E2EE), width: 1.1),
        boxShadow: _ReportsNeumorphicTheme.raisedShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon & Title Row
          Row(
            children: [
              Container(
                width: isMobile ? 40 : 46,
                height: isMobile ? 40 : 46,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _ReportsNeumorphicTheme.sunkenSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                  boxShadow: _ReportsNeumorphicTheme.sunkenShadows,
                ),
                alignment: Alignment.center,
                child: iconAsset != null
                    ? Image.asset(
                        iconAsset,
                        width: isMobile ? 28 : 34,
                        height: isMobile ? 28 : 34,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          icon ?? Icons.analytics_rounded,
                          color: iconColor,
                          size: isMobile ? 20 : 24,
                        ),
                      )
                    : Icon(
                        icon ?? Icons.analytics_rounded,
                        color: iconColor,
                        size: isMobile ? 20 : 24,
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 11.5 : 12.5,
                    fontWeight: FontWeight.w700,
                    color: _ReportsNeumorphicTheme.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Big Amount
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 17 : 20,
                fontWeight: FontWeight.w900,
                color: _ReportsNeumorphicTheme.textDark,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 8),

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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFF86EFAC), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_drop_up_rounded, color: Color(0xFF16A34A), size: 14),
                          Text(
                            '+${trendPct.toInt()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'vs previous period',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: _ReportsNeumorphicTheme.textMuted,
                        fontWeight: FontWeight.w600,
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
    final tabs = _effectiveTabs;
    final effectiveOrders = orders;
    final totalRecords = orders.length;

    return Container(
      decoration: BoxDecoration(
        color: _ReportsNeumorphicTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E2EE), width: 1.1),
        boxShadow: _ReportsNeumorphicTheme.raisedShadows,
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

                      // Search Box (Filtering driven by top filter section)
                      _buildSearchInput(),
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
              valueColor: AlwaysStoppedAnimation<Color>(_ReportsNeumorphicTheme.blueBrand),
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
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [_ReportsNeumorphicTheme.blueBrand, _ReportsNeumorphicTheme.navyBrand],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : _ReportsNeumorphicTheme.sunkenSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? Colors.white.withValues(alpha: 0.3) : const Color(0xFFCBD5E1),
              width: 1,
            ),
            boxShadow: isSelected
                ? _ReportsNeumorphicTheme.accentShadows
                : _ReportsNeumorphicTheme.sunkenShadows,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : _ReportsNeumorphicTheme.textBody,
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
        color: _ReportsNeumorphicTheme.sunkenSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        boxShadow: _ReportsNeumorphicTheme.sunkenShadows,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) {
          setState(() => _currentPage = 1);
          _loadSalesReport(showLoading: false);
        },
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ReportsNeumorphicTheme.textDark),
        decoration: const InputDecoration(
          hintText: 'Search by bill no, order no...',
          hintStyle: TextStyle(fontSize: 11.5, color: _ReportsNeumorphicTheme.textMuted, fontWeight: FontWeight.w500),
          prefixIcon: Icon(Icons.search_rounded, size: 16, color: _ReportsNeumorphicTheme.navyBrand),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
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
    final tabs = _effectiveTabs;
    final currentTabTitle = _activeTabIndex < tabs.length ? tabs[_activeTabIndex] : tabs.first;

    switch (currentTabTitle) {
      case 'Sales Details':
      case 'My Sales Details':
        return _buildSalesDetailsView(orders: orders, currency: currency, isMobile: isMobile);
      case 'Top Products':
        return _buildTopProductsView(currency: currency, isMobile: isMobile);
      case 'Category Wise':
        return _buildCategoryWiseView(currency: currency, isMobile: isMobile);
      case 'Payment Mode':
        return _buildPaymentModeDetailView(currency: currency, isMobile: isMobile);
      case 'Order Type':
        return _buildOrderTypeDetailView(currency: currency, isMobile: isMobile);
      case 'Outlet Wise':
        return _buildOutletWiseView(currency: currency, isMobile: isMobile);
      case 'Staff Wise':
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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ReportsNeumorphicTheme.textMuted),
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
        final double minTableWidth = _isStaffUser ? 880.0 : 980.0;
        final double effectiveWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

        final tableContent = SizedBox(
          width: effectiveWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row matching mockup
              Container(
                height: 44,
                decoration: const BoxDecoration(
                  color: _ReportsNeumorphicTheme.sunkenSurface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const SizedBox(width: 35, child: Text('#', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _ReportsNeumorphicTheme.textDark))),
                    const Expanded(flex: 140, child: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _ReportsNeumorphicTheme.textDark))),
                    const Expanded(flex: 85, child: Text('Bill No', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _ReportsNeumorphicTheme.textDark))),
                    if (!_isStaffUser)
                      const Expanded(flex: 100, child: Text('Staff', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _ReportsNeumorphicTheme.textDark))),
                    const Expanded(flex: 95, child: Text('Order Type', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _ReportsNeumorphicTheme.textDark))),
                    const Expanded(flex: 60, child: Text('Table', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _ReportsNeumorphicTheme.textDark))),
                    const Expanded(flex: 50, child: Text('Items', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _ReportsNeumorphicTheme.textDark))),
                    const Expanded(flex: 110, child: Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _ReportsNeumorphicTheme.textDark))),
                    const Expanded(flex: 115, child: Text('Customer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _ReportsNeumorphicTheme.textDark))),
                    const Expanded(flex: 90, child: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _ReportsNeumorphicTheme.textDark))),
                    const SizedBox(width: 45, child: Text('Action', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _ReportsNeumorphicTheme.textDark))),
                  ],
                ),
              ),
              Divider(height: 1, color: _ReportsNeumorphicTheme.darkShadow.withValues(alpha: 0.3)),

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
                            child: Text('$globalIndex', style: const TextStyle(fontSize: 12.5, color: _ReportsNeumorphicTheme.textMuted, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            flex: 140,
                            child: Text(formattedDate, style: const TextStyle(fontSize: 12.5, color: _ReportsNeumorphicTheme.textBody, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            flex: 85,
                            child: Text(
                              order.orderNumber.startsWith('#') ? order.orderNumber : '#${order.orderNumber}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _ReportsNeumorphicTheme.textDark),
                            ),
                          ),
                          if (!_isStaffUser)
                            Expanded(
                              flex: 100,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: (order.staffName != null && order.staffName!.isNotEmpty)
                                          ? _ReportsNeumorphicTheme.blueBrand
                                          : _ReportsNeumorphicTheme.textMuted,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      order.staffName?.isNotEmpty == true ? order.staffName! : 'Direct / Owner',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: order.staffName?.isNotEmpty == true
                                            ? _ReportsNeumorphicTheme.navyBrand
                                            : _ReportsNeumorphicTheme.textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            flex: 95,
                            child: Align(alignment: Alignment.centerLeft, child: _buildOrderTypeChip(order.orderType)),
                          ),
                          Expanded(
                            flex: 60,
                            child: Text(order.tableNumber?.isNotEmpty == true ? order.tableNumber! : '-', style: const TextStyle(fontSize: 12.5, color: _ReportsNeumorphicTheme.textBody)),
                          ),
                          Expanded(
                            flex: 50,
                            child: Text('$totalQty', style: const TextStyle(fontSize: 12.5, color: _ReportsNeumorphicTheme.textBody)),
                          ),
                          Expanded(
                            flex: 110,
                            child: Text(order.paymentMethod, style: const TextStyle(fontSize: 12.5, color: _ReportsNeumorphicTheme.textBody)),
                          ),
                          Expanded(
                            flex: 115,
                            child: Text(
                              order.customerName?.isNotEmpty == true ? order.customerName! : 'Walk-in',
                              style: const TextStyle(fontSize: 12.5, color: _ReportsNeumorphicTheme.textBody),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 90,
                            child: Text(
                              _formatNumber(order.totalAmount),
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: _ReportsNeumorphicTheme.textDark),
                            ),
                          ),
                          SizedBox(
                            width: 45,
                            child: PopupMenuButton<String>(
                              color: _ReportsNeumorphicTheme.surface,
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
                                PopupMenuItem(value: 'view', child: Text('View Invoice / Receipt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ReportsNeumorphicTheme.textDark))),
                                PopupMenuItem(value: 'share', child: Text('Share Bill Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ReportsNeumorphicTheme.textDark))),
                              ],
                              child: const Icon(Icons.more_horiz_rounded, size: 18, color: _ReportsNeumorphicTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (idx < pagedOrders.length - 1)
                      Divider(height: 1, color: _ReportsNeumorphicTheme.darkShadow.withValues(alpha: 0.2)),
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

  Widget _buildOrderTypeChip(OrderType type, {bool isCompact = false}) {
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
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 5 : 9,
        vertical: isCompact ? 1.5 : 3.5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(isCompact ? 4 : 6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: isCompact ? 9 : 11,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }

  // --- TAB 2: TOP PRODUCTS ---
  Widget _buildTopProductsView({required String currency, required bool isMobile}) {
    final topProds = _reportData?.topProducts ?? [];
    if (topProds.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('No top selling products recorded', style: TextStyle(color: _ReportsNeumorphicTheme.textMuted))),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: topProds.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: _ReportsNeumorphicTheme.darkShadow.withValues(alpha: 0.2)),
      itemBuilder: (ctx, idx) {
        final p = topProds[idx];
        final isVeg = p.foodType == 'veg';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Text('#${idx + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _ReportsNeumorphicTheme.textMuted)),
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
                    Text(p.name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _ReportsNeumorphicTheme.textDark)),
                    Text(p.category, style: const TextStyle(fontSize: 10, color: _ReportsNeumorphicTheme.textMuted)),
                  ],
                ),
              ),
              Text('${p.quantity} sold', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _ReportsNeumorphicTheme.textBody)),
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
        child: Center(child: Text('No category statistics found', style: TextStyle(color: _ReportsNeumorphicTheme.textMuted))),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: _ReportsNeumorphicTheme.darkShadow.withValues(alpha: 0.2)),
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
                    Text(c.categoryName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _ReportsNeumorphicTheme.textDark)),
                    const SizedBox(height: 2),
                    Text('${c.itemsSold} items sold • ${c.percentage.toStringAsFixed(1)}% share', style: const TextStyle(fontSize: 10.5, color: _ReportsNeumorphicTheme.textMuted)),
                  ],
                ),
              ),
              Text('$currency${_formatNumber(c.totalRevenue)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _ReportsNeumorphicTheme.blueBrand)),
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
      separatorBuilder: (_, _) => Divider(height: 1, color: _ReportsNeumorphicTheme.darkShadow.withValues(alpha: 0.2)),
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
                    Text(m.mode, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _ReportsNeumorphicTheme.textDark)),
                    const SizedBox(height: 2),
                    Text('${m.count} bills • ${m.percentage.toStringAsFixed(1)}% of total sales', style: const TextStyle(fontSize: 10.5, color: _ReportsNeumorphicTheme.textMuted)),
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
      separatorBuilder: (_, _) => Divider(height: 1, color: _ReportsNeumorphicTheme.darkShadow.withValues(alpha: 0.2)),
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
                    Text(t.type, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _ReportsNeumorphicTheme.textDark)),
                    const SizedBox(height: 2),
                    Text('${t.count} orders • Avg: $currency${_formatNumber(t.avgTicket)}', style: const TextStyle(fontSize: 10.5, color: _ReportsNeumorphicTheme.textMuted)),
                  ],
                ),
              ),
              Text('$currency${_formatNumber(t.amount)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _ReportsNeumorphicTheme.blueBrand)),
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
      separatorBuilder: (_, _) => Divider(height: 1, color: _ReportsNeumorphicTheme.darkShadow.withValues(alpha: 0.2)),
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
                    Text(o.outletName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _ReportsNeumorphicTheme.textDark)),
                    const SizedBox(height: 2),
                    Text('${o.billsCount} bills settled', style: const TextStyle(fontSize: 10.5, color: _ReportsNeumorphicTheme.textMuted)),
                  ],
                ),
              ),
              Text('$currency${_formatNumber(o.totalRevenue)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _ReportsNeumorphicTheme.blueBrand)),
            ],
          ),
        );
      },
    );
  }

  // --- TAB 7: STAFF WISE (OWNER EXCLUSIVE) ---
  Widget _buildStaffWiseView({required String currency, required bool isMobile}) {
    final staff = _reportData?.staffWise ?? [];

    if (staff.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.badge_outlined, size: 40, color: Color(0xFFCBD5E1)),
              SizedBox(height: 10),
              Text(
                'No staff performance records found for this period.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ReportsNeumorphicTheme.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    final totalSales = staff.fold<double>(0.0, (sum, s) => sum + s.totalRevenue);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: staff.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: _ReportsNeumorphicTheme.darkShadow.withValues(alpha: 0.2)),
      itemBuilder: (ctx, idx) {
        final s = staff[idx];
        final isExpanded = _expandedStaffIds.contains(s.staffName);
        final pct = totalSales > 0 ? (s.totalRevenue / totalSales) * 100 : s.percentage;

        // Staff Initial
        String initials = '';
        if (s.staffName.isNotEmpty) {
          final parts = s.staffName.trim().split(RegExp(r'\s+'));
          initials = parts.length >= 2
              ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
              : s.staffName.substring(0, s.staffName.length >= 2 ? 2 : 1).toUpperCase();
        }

        return Container(
          decoration: BoxDecoration(
            color: isExpanded ? _ReportsNeumorphicTheme.sunkenSurface.withValues(alpha: 0.5) : Colors.transparent,
          ),
          child: Column(
            children: [
              InkWell(
                onTap: s.orders.isNotEmpty
                    ? () {
                        setState(() {
                          if (isExpanded) {
                            _expandedStaffIds.remove(s.staffName);
                          } else {
                            _expandedStaffIds.add(s.staffName);
                          }
                        });
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Staff Avatar / Initials
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_ReportsNeumorphicTheme.blueBrand, _ReportsNeumorphicTheme.navyBrand],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _ReportsNeumorphicTheme.accentShadows,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials.isNotEmpty ? initials : 'ST',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Staff Name & Role & Bills
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  s.staffName,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _ReportsNeumorphicTheme.textDark),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Text(
                                    s.role.toUpperCase(),
                                    style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: _ReportsNeumorphicTheme.blueBrand),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '${s.billsCount} bills settled',
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w500, color: _ReportsNeumorphicTheme.textMuted),
                                ),
                                const Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 9.5)),
                                Text(
                                  'Avg: $currency${_formatNumber(s.avgTicket)}',
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: _ReportsNeumorphicTheme.textBody),
                                ),
                                const Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 9.5)),
                                Text(
                                  '${pct.toStringAsFixed(1)}% share',
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Revenue & Drilldown Toggle
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$currency${_formatNumber(s.totalRevenue)}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: _ReportsNeumorphicTheme.textDark),
                          ),
                          if (s.orders.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isExpanded ? 'Hide bills' : 'View bills (${s.orders.length})',
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: _ReportsNeumorphicTheme.blueBrand),
                                ),
                                Icon(
                                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                  size: 14,
                                  color: _ReportsNeumorphicTheme.blueBrand,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Expandable Order Drilldown
              if (isExpanded && s.orders.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _ReportsNeumorphicTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                      boxShadow: _ReportsNeumorphicTheme.sunkenShadows,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: const BoxDecoration(
                            color: _ReportsNeumorphicTheme.sunkenSurface,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                          ),
                          child: Text(
                            'Recent Orders Settled by ${s.staffName} (${s.orders.length} total)',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _ReportsNeumorphicTheme.textDark),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...s.orders.take(15).map((o) {
                          String dateStr = o.createdAt;
                          final dt = DateTime.tryParse(o.createdAt);
                          if (dt != null) {
                            dateStr = DateFormat('dd MMM, hh:mm a').format(dt.isUtc ? dt.toLocal() : dt);
                          }
                          return InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => ReceiptDialog(order: o, currency: currency),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: _ReportsNeumorphicTheme.darkShadow.withValues(alpha: 0.15))),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 2,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              o.orderNumber.startsWith('#') ? o.orderNumber : '#${o.orderNumber}',
                                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _ReportsNeumorphicTheme.textDark),
                                            ),
                                            Text(
                                              dateStr,
                                              style: const TextStyle(fontSize: 9.5, color: _ReportsNeumorphicTheme.textMuted),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Wrap(
                                          spacing: 5,
                                          runSpacing: 2,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            _buildOrderTypeChip(o.orderType, isCompact: true),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: _ReportsNeumorphicTheme.sunkenSurface,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                o.paymentMethod,
                                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _ReportsNeumorphicTheme.textBody),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$currency${_formatNumber(o.totalAmount)}',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _ReportsNeumorphicTheme.textDark),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
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
        color: _ReportsNeumorphicTheme.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: isMobile
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing $startRec - $endRec of $totalRecords',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _ReportsNeumorphicTheme.textMuted),
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
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _ReportsNeumorphicTheme.blueBrand),
                      ),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: _ReportsNeumorphicTheme.blueBrand),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Text(
                  'Showing $startRec - $endRec of $totalRecords records',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _ReportsNeumorphicTheme.textMuted),
                ),
                const Spacer(),

                // Prev Button
                InkWell(
                  onTap: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _ReportsNeumorphicTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                      boxShadow: _ReportsNeumorphicTheme.softRaisedShadows,
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: _currentPage > 1 ? _ReportsNeumorphicTheme.textDark : const Color(0xFFCBD5E1),
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
                      width: 34,
                      height: 34,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        color: _currentPage == p ? _ReportsNeumorphicTheme.navyBrand : _ReportsNeumorphicTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: _currentPage == p ? null : Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                        boxShadow: _currentPage == p
                            ? _ReportsNeumorphicTheme.accentShadows
                            : _ReportsNeumorphicTheme.softRaisedShadows,
                      ),
                      child: Center(
                        child: Text(
                          '$p',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _currentPage == p ? FontWeight.w800 : FontWeight.w600,
                            color: _currentPage == p ? Colors.white : _ReportsNeumorphicTheme.textBody,
                          ),
                        ),
                      ),
                    ),
                  ),

                if (totalPages > 5) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('...', style: TextStyle(color: _ReportsNeumorphicTheme.textMuted, fontSize: 12)),
                  ),
                  InkWell(
                    onTap: () => setState(() => _currentPage = totalPages),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 34,
                      height: 34,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        color: _currentPage == totalPages ? _ReportsNeumorphicTheme.navyBrand : _ReportsNeumorphicTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: _currentPage == totalPages ? null : Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                        boxShadow: _currentPage == totalPages
                            ? _ReportsNeumorphicTheme.accentShadows
                            : _ReportsNeumorphicTheme.softRaisedShadows,
                      ),
                      child: Center(
                        child: Text(
                          '$totalPages',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _currentPage == totalPages ? FontWeight.w800 : FontWeight.w600,
                            color: _currentPage == totalPages ? Colors.white : _ReportsNeumorphicTheme.textBody,
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
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _ReportsNeumorphicTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
                      boxShadow: _ReportsNeumorphicTheme.softRaisedShadows,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: _currentPage < totalPages ? _ReportsNeumorphicTheme.textDark : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}


