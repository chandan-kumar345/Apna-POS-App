import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';
import '../../core/models/table_model.dart';
import 'order_detail_sheet.dart';
import '../pos/receipt_dialog.dart';
import '../pos/payment_modal.dart';
import '../../core/services/bluetooth_printer_service.dart';
import '../../core/widgets/printer_selection_dialog.dart';

enum OrderDateFilter { allTime, today, yesterday, thisWeek, thisMonth, thisYear, custom }

class OrdersScreen extends StatefulWidget {
  final Function(String tableName)? onOpenPosForTable;
  final String? initialOrderId;
  final String? initialOrderNumber;
  final bool showBackButton;

  const OrdersScreen({
    super.key,
    this.onOpenPosForTable,
    this.initialOrderId,
    this.initialOrderNumber,
    this.showBackButton = false,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final db = DatabaseService();

  // Date Filter matching Sales Report & Dashboard Screen
  OrderDateFilter _selectedDateFilter = OrderDateFilter.allTime;
  String _dashboardFilter = 'All Time';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  DateTimeRange? _customDateRange;

  // Filter state defaulting to DineIn and Preparing (cannot be deselected)
  String _selectedOrderTypeFilter = 'DineIn'; // 'DineIn', 'TakeAway', 'Delivery'
  String _selectedStatusFilter = 'Preparing'; // 'Pending', 'Preparing', 'Ready', 'Completed', 'Cancelled'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isManualRefreshing = false;
  bool _hasCheckedInitialOrder = false;

  @override
  void initState() {
    super.initState();
    db.addListener(_onDbChange);
    db.syncWithBackend().then((_) {
      if (mounted) _checkInitialOrder();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialOrder();
    });
  }

  void _checkInitialOrder() {
    if (_hasCheckedInitialOrder) return;
    if (widget.initialOrderId == null && widget.initialOrderNumber == null) return;

    final targetId = widget.initialOrderId?.trim().toLowerCase();
    final targetNum = widget.initialOrderNumber?.trim().toLowerCase();

    final matched = db.orders.firstWhere(
      (o) =>
          (targetId != null &&
              (o.id.toLowerCase() == targetId || o.orderNumber.toLowerCase() == targetId)) ||
          (targetNum != null && o.orderNumber.toLowerCase() == targetNum),
      orElse: () => OrderModel(
        id: '',
        orderNumber: '',
        items: const [],
        subtotal: 0,
        taxAmount: 0,
        totalAmount: 0,
        createdAt: '',
      ),
    );

    if (matched.id.isNotEmpty && mounted) {
      _hasCheckedInitialOrder = true;
      setState(() {
        if (matched.orderType == OrderType.takeaway) {
          _selectedOrderTypeFilter = 'TakeAway';
        } else if (matched.orderType == OrderType.delivery) {
          _selectedOrderTypeFilter = 'Delivery';
        } else {
          _selectedOrderTypeFilter = 'DineIn';
        }

        if (matched.status == OrderStatus.completed) {
          _selectedStatusFilter = 'Completed';
        } else if (matched.status == OrderStatus.ready) {
          _selectedStatusFilter = 'Ready';
        } else if (matched.status == OrderStatus.cancelled) {
          _selectedStatusFilter = 'Cancelled';
        } else if (matched.status == OrderStatus.pending) {
          _selectedStatusFilter = 'Pending';
        } else {
          _selectedStatusFilter = 'Preparing';
        }

        _searchQuery = matched.orderNumber;
        _searchController.text = matched.orderNumber;
      });

      // Automatically open the detailed order bottom sheet dialog
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          OrderDetailSheet.show(context, initialOrder: matched);
        }
      });
    }
  }

  Future<void> _refreshOrders() async {
    setState(() => _isManualRefreshing = true);
    await db.syncWithBackend();
    if (mounted) {
      setState(() => _isManualRefreshing = false);
    }
  }

  Future<void> _settleOrderFromList(OrderModel order) async {
    final currency = db.restaurant?.currencySymbol ?? '₹';
    final modalResult = await showDialog<dynamic>(
      context: context,
      builder: (_) => PaymentModal(
        order: order,
        currency: currency,
      ),
    );

    if (modalResult != null) {
      final String resultMethod = modalResult is PaymentModalResult
          ? modalResult.paymentMethod
          : modalResult.toString();
      final double? roundOff = modalResult is PaymentModalResult ? modalResult.roundOff : null;
      final double? totalAmount = modalResult is PaymentModalResult ? modalResult.totalAmount : null;

      if (resultMethod.isNotEmpty) {
        final completedOrder = await db.settleOrder(
          orderId: order.id,
          paymentMethod: resultMethod,
          totalAmount: totalAmount ?? order.effectiveTotalAmount,
          roundOff: roundOff ?? 0.0,
        );

        if (!mounted) return;
        showDialog(
          context: context,
          useRootNavigator: true,
          barrierDismissible: true,
          builder: (_) => ReceiptDialog(order: completedOrder, currency: currency),
        );
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    db.removeListener(_onDbChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onDbChange() {
    if (mounted) setState(() {});
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B); // Amber
      case OrderStatus.preparing:
        return const Color(0xFFEA580C); // Warm Orange
      case OrderStatus.ready:
        return const Color(0xFF10B981); // Emerald Green
      case OrderStatus.completed:
        return const Color(0xFF051C48); // Navy
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444); // Red
    }
  }

  String _getStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _getOrderTypeLabel(OrderType type) {
    switch (type) {
      case OrderType.dineIn:
        return 'DineIn';
      case OrderType.takeaway:
        return 'TakeAway';
      case OrderType.delivery:
        return 'Delivery';
    }
  }

  bool _matchesDateFilter(OrderModel o) {
    if (_selectedDateFilter == OrderDateFilter.allTime) return true;
    final orderDate = o.createdDateTime;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (_selectedDateFilter) {
      case OrderDateFilter.allTime:
        return true;
      case OrderDateFilter.today:
        return orderDate.isAfter(todayStart.subtract(const Duration(milliseconds: 1))) &&
            orderDate.isBefore(todayEnd.add(const Duration(milliseconds: 1)));
      case OrderDateFilter.yesterday:
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));
        final yesterdayEnd = DateTime(yesterdayStart.year, yesterdayStart.month, yesterdayStart.day, 23, 59, 59, 999);
        return orderDate.isAfter(yesterdayStart.subtract(const Duration(milliseconds: 1))) &&
            orderDate.isBefore(yesterdayEnd.add(const Duration(milliseconds: 1)));
      case OrderDateFilter.thisWeek:
        final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
        return orderDate.isAfter(weekStart.subtract(const Duration(milliseconds: 1))) &&
            orderDate.isBefore(todayEnd.add(const Duration(milliseconds: 1)));
      case OrderDateFilter.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        final nextMonth = (now.month == 12) ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
        final monthEnd = nextMonth.subtract(const Duration(milliseconds: 1));
        return orderDate.isAfter(monthStart.subtract(const Duration(milliseconds: 1))) &&
            orderDate.isBefore(monthEnd.add(const Duration(milliseconds: 1)));
      case OrderDateFilter.thisYear:
        final yearStart = DateTime(now.year, 1, 1);
        final yearEnd = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        return orderDate.isAfter(yearStart.subtract(const Duration(milliseconds: 1))) &&
            orderDate.isBefore(yearEnd.add(const Duration(milliseconds: 1)));
      case OrderDateFilter.custom:
        if (_customDateRange == null && (_customStartDate == null || _customEndDate == null)) return true;
        final start = _customDateRange != null
            ? DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day)
            : DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
        final end = _customDateRange != null
            ? DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59, 999)
            : DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day, 23, 59, 59, 999);
        return orderDate.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
            orderDate.isBefore(end.add(const Duration(milliseconds: 1)));
    }
  }

  void _syncDateFilterFromDashboardString(String val) {
    if (val == 'Today') {
      _selectedDateFilter = OrderDateFilter.today;
    } else if (val == 'Yesterday') {
      _selectedDateFilter = OrderDateFilter.yesterday;
    } else if (val == 'Week' || val == 'This Week') {
      _selectedDateFilter = OrderDateFilter.thisWeek;
    } else if (val == 'Month' || val == 'This Month') {
      _selectedDateFilter = OrderDateFilter.thisMonth;
    } else if (val == 'Year' || val == 'This Year') {
      _selectedDateFilter = OrderDateFilter.thisYear;
    } else if (val == 'All Time') {
      _selectedDateFilter = OrderDateFilter.allTime;
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

  /// Interactive Custom Date Range Popup Dialog matching Dashboard
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
        _customDateRange = DateTimeRange(start: result['start']!, end: result['end']!);
        _dashboardFilter = 'Custom Date';
        _selectedDateFilter = OrderDateFilter.custom;
      });
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

  /// Neumorphic Dropdown Pill matching design
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
    } else if (_selectedDateFilter == OrderDateFilter.today) {
      displayValue = 'Today';
    } else if (_selectedDateFilter == OrderDateFilter.yesterday) {
      displayValue = 'Yesterday';
    } else if (_selectedDateFilter == OrderDateFilter.thisWeek) {
      displayValue = 'This Week';
    } else if (_selectedDateFilter == OrderDateFilter.thisMonth) {
      displayValue = 'This Month';
    } else if (_selectedDateFilter == OrderDateFilter.thisYear) {
      displayValue = 'This Year';
    } else if (_selectedDateFilter == OrderDateFilter.allTime) {
      displayValue = 'All Time';
    }

    final options = [
      {'value': 'Today', 'label': 'Today'},
      {'value': 'Yesterday', 'label': 'Yesterday'},
      {'value': 'Week', 'label': 'This Week'},
      {'value': 'Month', 'label': 'This Month'},
      {'value': 'Year', 'label': 'This Year'},
      {'value': 'All Time', 'label': 'All Time'},
      {'value': 'Custom Date', 'label': 'Custom Date Range'},
    ];

    return PopupMenuButton<String>(
      initialValue: value,
      color: Colors.white,
      elevation: 6,
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
        final isSelected = value == optVal ||
            (optVal == 'Week' && value == 'This Week') ||
            (optVal == 'Month' && value == 'This Month') ||
            (optVal == 'Year' && value == 'This Year');

        return PopupMenuItem<String>(
          value: optVal,
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 15,
                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 8),
              Text(
                optLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.9),
              offset: const Offset(-2, -2),
              blurRadius: 4,
            ),
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
              offset: const Offset(2, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: Color(0xFF0284C7),
            ),
            const SizedBox(width: 6),
            Text(
              displayValue,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  // Neumorphic Box Decoration Helper
  BoxDecoration _neumorphicBox({
    double borderRadius = 18,
    Color color = Colors.white,
    bool isSelected = false,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: isSelected ? const Color(0xFFF0F7FF) : color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isSelected
            ? const Color(0xFF2563EB)
            : (borderColor ?? const Color(0xFFE2E8F0).withValues(alpha: 0.8)),
        width: isSelected ? 1.5 : 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.95),
          offset: const Offset(-3, -3),
          blurRadius: 6,
        ),
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
          offset: const Offset(3, 4),
          blurRadius: 8,
        ),
      ],
    );
  }

  Widget _buildItemThumbnail(CartItemModel cartItem) {
    String? img = cartItem.item.imageUrl;
    if ((img.isEmpty) && cartItem.item.images.isNotEmpty) {
      img = cartItem.item.images.first;
    }
    if (img.isEmpty) {
      final dbItem = db.menuItems.where((m) => m.id == cartItem.item.id || m.name.toLowerCase() == cartItem.item.name.toLowerCase()).firstOrNull;
      if (dbItem != null) {
        img = dbItem.imageUrl.isNotEmpty ? dbItem.imageUrl : (dbItem.images.isNotEmpty ? dbItem.images.first : null);
      }
    }

    Widget? imageWidget;
    if (img != null && img.isNotEmpty) {
      if (img.startsWith('data:image') || (img.length > 100 && !img.startsWith('http') && !img.startsWith('assets/'))) {
        try {
          final cleanBase64 = img.contains(',') ? img.split(',').last.trim() : img.trim();
          final bytes = base64Decode(cleanBase64);
          imageWidget = Image.memory(
            bytes,
            width: 38,
            height: 38,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildDefaultProductImage(),
          );
        } catch (_) {}
      } else if (img.startsWith('http')) {
        imageWidget = Image.network(
          img,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildDefaultProductImage(),
        );
      } else if (img.startsWith('assets/')) {
        imageWidget = Image.asset(
          img,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildDefaultProductImage(),
        );
      }
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageWidget ?? _buildDefaultProductImage(),
    );
  }

  Widget _buildDefaultProductImage() {
    return Image.asset(
      'assets/images/product_placeholder.png',
      width: 38,
      height: 38,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFFE2E8F0),
        alignment: Alignment.center,
        child: const Icon(Icons.fastfood_rounded, size: 18, color: Color(0xFF94A3B8)),
      ),
    );
  }

  /// Status Pill with Text, Icon & Live Count (Horizontal Sliding)
  /// Status Pill with Text, Icon & Live Count (Horizontal Sliding)
  Widget _buildStatusPill({
    required String statusKey,
    required String label,
    required String emoji,
    required int count,
    required Color color,
  }) {
    final isSelected = _selectedStatusFilter == statusKey;

    return InkWell(
      onTap: () {
        if (_selectedStatusFilter != statusKey) {
          setState(() {
            _selectedStatusFilter = statusKey;
          });
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.95),
              offset: const Offset(-2, -2),
              blurRadius: 4,
            ),
            BoxShadow(
              color: (isSelected ? color : const Color(0xFF0F172A)).withValues(alpha: isSelected ? 0.15 : 0.05),
              offset: const Offset(2, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? color : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? color : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Order Type Pill (Horizontal Sliding)
  Widget _buildOrderTypePill({
    required String type,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedOrderTypeFilter == type;

    return InkWell(
      onTap: () {
        if (_selectedOrderTypeFilter != type) {
          setState(() {
            _selectedOrderTypeFilter = type;
          });
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.95),
              offset: const Offset(-2, -2),
              blurRadius: 4,
            ),
            BoxShadow(
              color: (isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A)).withValues(alpha: isSelected ? 0.12 : 0.05),
              offset: const Offset(2, 3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0284C7),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = db.restaurant?.currencySymbol ?? '₹';

    return ListenableBuilder(
      listenable: db,
      builder: (context, _) {
        // Filter orders by OrderType (DineIn, TakeAway, Delivery) and Date Filter
        List<OrderModel> typeFilteredOrders = db.orders.where((o) {
          final matchesType = (_selectedOrderTypeFilter.isEmpty)
              ? true
              : (_selectedOrderTypeFilter == 'Delivery')
                  ? o.orderType == OrderType.delivery
                  : (_selectedOrderTypeFilter == 'DineIn')
                      ? o.orderType == OrderType.dineIn
                      : (_selectedOrderTypeFilter == 'TakeAway')
                          ? o.orderType == OrderType.takeaway
                          : true;
          return matchesType && _matchesDateFilter(o);
        }).toList();

        // RUNNING KOT AUTOMATICALLY LOGIC FOR PREPARING
        int countForStatus(OrderStatus s) {
          return typeFilteredOrders.where((o) {
            if (s == OrderStatus.preparing) {
              if (o.status == OrderStatus.cancelled || o.status == OrderStatus.completed) return false;
              if (o.orderType == OrderType.dineIn && o.tableNumber != null) {
                final tbl = db.tables.where((t) => isSameTable(t.name, o.tableNumber) || isSameTable(t.tableNumber.toString(), o.tableNumber)).firstOrNull;
                if (tbl != null && tbl.status == TableStatus.free) {
                  return false;
                }
              }
              final isRunningKotTable = o.tableNumber != null &&
                  db.tables.any((t) => (isSameTable(t.name, o.tableNumber) || isSameTable(t.tableNumber.toString(), o.tableNumber)) && t.status == TableStatus.runningKot);
              return o.status == OrderStatus.preparing || (isRunningKotTable && o.status == OrderStatus.pending);
            }
            return o.status == s;
          }).length;
        }

        final pendingCount = countForStatus(OrderStatus.pending);
        final preparingCount = countForStatus(OrderStatus.preparing);
        final readyCount = countForStatus(OrderStatus.ready);
        final completedCount = countForStatus(OrderStatus.completed);
        final cancelledCount = countForStatus(OrderStatus.cancelled);

        // Filter orders by selected status with Running KOT auto-classification
        List<OrderModel> filteredOrders = typeFilteredOrders.where((o) {
          if (_selectedStatusFilter.isEmpty) return true;
          if (_selectedStatusFilter == 'Pending') return o.status == OrderStatus.pending;
          if (_selectedStatusFilter == 'Preparing') {
            if (o.status == OrderStatus.cancelled || o.status == OrderStatus.completed) return false;
            if (o.orderType == OrderType.dineIn && o.tableNumber != null) {
              final tbl = db.tables.where((t) => isSameTable(t.name, o.tableNumber) || isSameTable(t.tableNumber.toString(), o.tableNumber)).firstOrNull;
              if (tbl != null && tbl.status == TableStatus.free) {
                return false;
              }
            }
            final isRunningKotTable = o.tableNumber != null &&
                db.tables.any((t) => (isSameTable(t.name, o.tableNumber) || isSameTable(t.tableNumber.toString(), o.tableNumber)) && t.status == TableStatus.runningKot);
            return o.status == OrderStatus.preparing || (isRunningKotTable && o.status == OrderStatus.pending);
          }
          if (_selectedStatusFilter == 'Ready') return o.status == OrderStatus.ready;
          if (_selectedStatusFilter == 'Completed') return o.status == OrderStatus.completed;
          if (_selectedStatusFilter == 'Cancelled') return o.status == OrderStatus.cancelled;
          return true;
        }).toList();

        // Search Filter
        if (_searchQuery.trim().isNotEmpty) {
          final q = _searchQuery.toLowerCase().trim();
          filteredOrders = filteredOrders.where((o) {
            final matchesNum = o.orderNumber.toLowerCase().contains(q);
            final matchesTable = (o.tableNumber ?? '').toLowerCase().contains(q);
            final matchesAddress = (o.deliveryAddress ?? '').toLowerCase().contains(q);
            final matchesCustomer = (o.customerName ?? '').toLowerCase().contains(q);
            final matchesItem = o.items.any((i) => i.item.name.toLowerCase().contains(q));
            return matchesNum || matchesTable || matchesAddress || matchesCustomer || matchesItem;
          }).toList();
        }

        // Sort latest orders first using timezone-aware createdDateTime
        filteredOrders.sort((a, b) => b.createdDateTime.compareTo(a.createdDateTime));

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: const Color(0xFFF4F7FB),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Title, Subtitle, Date Pill & Refresh Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      if (widget.showBackButton) ...[
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: _neumorphicBox(borderRadius: 12),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'My Orders',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Manage and track all your orders',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Date Filter Pill
                      _buildDropdownPill(
                        value: _dashboardFilter,
                        onChanged: (val) {
                          setState(() {
                            _dashboardFilter = val;
                            _syncDateFilterFromDashboardString(val);
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      // Circular Neumorphic Refresh Button
                      InkWell(
                        onTap: _isManualRefreshing ? null : _refreshOrders,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.95),
                                offset: const Offset(-2, -2),
                                blurRadius: 4,
                              ),
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                offset: const Offset(2, 3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isManualRefreshing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                                  )
                                : const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A), size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 1) Single Row Order Type Filter (Horizontal Sliding, without "All Types")
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildOrderTypePill(
                        type: 'DineIn',
                        label: 'DineIn',
                        icon: Icons.restaurant_rounded,
                      ),
                      const SizedBox(width: 10),
                      _buildOrderTypePill(
                        type: 'TakeAway',
                        label: 'TakeAway',
                        icon: Icons.shopping_bag_outlined,
                      ),
                      const SizedBox(width: 10),
                      _buildOrderTypePill(
                        type: 'Delivery',
                        label: 'Delivery',
                        icon: Icons.delivery_dining_rounded,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 2) Single Row Status Filter (Horizontal Sliding, with text and Cancelled, without "All")
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildStatusPill(
                        statusKey: 'Pending',
                        label: 'Pending',
                        emoji: '⏳',
                        count: pendingCount,
                        color: const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 10),
                      _buildStatusPill(
                        statusKey: 'Preparing',
                        label: 'Preparing',
                        emoji: '👨‍🍳',
                        count: preparingCount,
                        color: const Color(0xFFEA580C),
                      ),
                      const SizedBox(width: 10),
                      _buildStatusPill(
                        statusKey: 'Ready',
                        label: 'Ready',
                        emoji: '🔔',
                        count: readyCount,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 10),
                      _buildStatusPill(
                        statusKey: 'Completed',
                        label: 'Completed',
                        emoji: '✅',
                        count: completedCount,
                        color: const Color(0xFF051C48),
                      ),
                      const SizedBox(width: 10),
                      _buildStatusPill(
                        statusKey: 'Cancelled',
                        label: 'Cancelled',
                        emoji: '❌',
                        count: cancelledCount,
                        color: const Color(0xFFEF4444),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 3) Full-Width Recessed Neumorphic Search Bar (Filter Icon Removed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Search orders by Order #, Table or Address...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.normal),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0F172A), size: 21),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 4) Responsive Order Cards (Pull Refresh removed)
                Expanded(
                  child: filteredOrders.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.receipt_long_outlined, size: 38, color: Color(0xFF94A3B8)),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'No ${_selectedStatusFilter.isNotEmpty ? _selectedStatusFilter : ""} ${_selectedOrderTypeFilter.isNotEmpty ? _selectedOrderTypeFilter : ""} Orders'
                                      .trim(),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'New orders will automatically appear here',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 700;
                            return ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: isWide
                                  ? (filteredOrders.length / 2).ceil()
                                  : filteredOrders.length,
                              itemBuilder: (context, rowIdx) {
                                if (isWide) {
                                  final leftIdx = rowIdx * 2;
                                  final rightIdx = leftIdx + 1;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _buildNeumorphicOrderCard(filteredOrders[leftIdx], currency, isWide)),
                                        const SizedBox(width: 14),
                                        if (rightIdx < filteredOrders.length)
                                          Expanded(child: _buildNeumorphicOrderCard(filteredOrders[rightIdx], currency, isWide))
                                        else
                                          const Expanded(child: SizedBox()),
                                      ],
                                    ),
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _buildNeumorphicOrderCard(filteredOrders[rowIdx], currency, isWide),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Single Neumorphic Order Card with Balanced Header, Items, Actions & Bottom Bar
  Widget _buildNeumorphicOrderCard(OrderModel order, String currency, bool isWide) {
    final isRunningKot = order.tableNumber != null &&
        order.status != OrderStatus.cancelled &&
        db.tables.any((t) =>
            (t.name == order.tableNumber || t.tableNumber.toString() == order.tableNumber) &&
            t.status == TableStatus.runningKot);
    final effectiveStatus = (isRunningKot && order.status == OrderStatus.pending)
        ? OrderStatus.preparing
        : order.status;
    final statusColor = _getStatusColor(effectiveStatus);

    // Format Created Date
    String formattedTime = '';
    try {
      formattedTime = DateFormat('d MMM, hh:mm a').format(order.createdDateTime);
    } catch (_) {
      formattedTime = order.createdAt;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.95),
            offset: const Offset(-3, -3),
            blurRadius: 6,
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            offset: const Offset(3, 5),
            blurRadius: 10,
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Order # and Order Type Capsule on Row 1
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Order Number
              Expanded(
                child: Text(
                  '#${order.orderNumber}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),

              // Order Type & Table Capsule (e.g. 🍽️ DineIn (T-1)) + Print Count
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          order.orderType == OrderType.dineIn
                              ? Icons.restaurant_rounded
                              : (order.orderType == OrderType.takeaway
                                  ? Icons.shopping_bag_outlined
                                  : Icons.delivery_dining_rounded),
                          size: 12,
                          color: const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_getOrderTypeLabel(order.orderType)}${order.tableNumber != null && order.orderType == OrderType.dineIn ? " (${order.tableNumber})" : ""}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (order.printCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        'P#${order.printCount}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Header Row 2: PAID / UNPAID pill & Status pill
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // PAID / UNPAID pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: order.isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: order.isPaid ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                  ),
                ),
                child: Text(
                  order.isPaid ? 'PAID' : 'UNPAID',
                  style: TextStyle(
                    color: order.isPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Status Pill (Completed, Cancelled, Preparing, etc.)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: effectiveStatus == OrderStatus.completed
                      ? const Color(0xFFF1F5F9)
                      : (effectiveStatus == OrderStatus.cancelled
                          ? const Color(0xFFFEE2E2)
                          : statusColor.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: effectiveStatus == OrderStatus.completed
                        ? const Color(0xFFCBD5E1)
                        : (effectiveStatus == OrderStatus.cancelled
                            ? const Color(0xFFFECACA)
                            : statusColor.withValues(alpha: 0.4)),
                  ),
                ),
                child: Text(
                  _getStatusLabel(effectiveStatus),
                  style: TextStyle(
                    color: effectiveStatus == OrderStatus.completed
                        ? const Color(0xFF334155)
                        : (effectiveStatus == OrderStatus.cancelled ? const Color(0xFFDC2626) : statusColor),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Items Body: Thumbnail (or Default Product Image), Quantity x Item Name, Price
          if (order.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No item details',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            )
          else
            ...order.items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    // Item Thumbnail or default image placeholder
                    _buildItemThumbnail(item),
                    const SizedBox(width: 9),

                    // Item Quantity and Title
                    Expanded(
                      child: RichText(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${item.quantity}  ×  ',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            TextSpan(
                              text: item.item.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Item Price
                    Text(
                      '$currency ${(item.totalPrice).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 10),

          // 3. Action Row: Total Amount on Left, Action Buttons on Right
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              // Total Amount Block
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$currency ${(order.effectiveTotalAmount).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),

              // Action Buttons (KOT, Bill, POS, Settle) with Increased Size
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // KOT Button
                  InkWell(
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final printerService = BluetoothPrinterService();
                      final bool isConnected = await printerService.isConnected();
                      if (!mounted) return;

                      if (isConnected) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Printing KOT Ticket...'),
                            backgroundColor: Color(0xFFD97706),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        final rest = DatabaseService().restaurant;
                        final success = await printerService.printKOT(order: order, restaurant: rest, isReprint: true);
                        if (mounted && !success) {
                          PrinterSelectionDialog.show(context, orderToPrint: order, isKot: true, currency: currency);
                        }
                      } else {
                        final bool reconnected = await printerService.autoConnectSavedPrinter();
                        if (reconnected) {
                          final rest = DatabaseService().restaurant;
                          await printerService.printKOT(order: order, restaurant: rest, isReprint: true);
                        } else if (mounted) {
                          PrinterSelectionDialog.show(context, orderToPrint: order, isKot: true, currency: currency);
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('👨‍🍳', style: TextStyle(fontSize: 13)),
                          SizedBox(width: 4),
                          Text(
                            'KOT',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFEA580C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bill Button
                  InkWell(
                    onTap: () => showDialog(
                      context: context,
                      useRootNavigator: true,
                      barrierDismissible: true,
                      builder: (_) => ReceiptDialog(order: order, currency: currency),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF2563EB)),
                          SizedBox(width: 4),
                          Text(
                            'Bill',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // POS jump button if active dine-in table
                  if (order.tableNumber != null &&
                      order.tableNumber!.trim().isNotEmpty &&
                      (effectiveStatus == OrderStatus.pending || effectiveStatus == OrderStatus.preparing)) ...[
                    InkWell(
                      onTap: () {
                        if (widget.onOpenPosForTable != null) {
                          widget.onOpenPosForTable!(order.tableNumber!);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.point_of_sale_rounded, size: 13, color: Color(0xFF0F172A)),
                            SizedBox(width: 3.5),
                            Text(
                              'POS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Status Transition Button (Accept / Mark Ready / Settle)
                  if (effectiveStatus == OrderStatus.pending ||
                      effectiveStatus == OrderStatus.preparing ||
                      effectiveStatus == OrderStatus.ready) ...[
                    InkWell(
                      onTap: () {
                        if (effectiveStatus == OrderStatus.pending) {
                          db.updateOrderStatus(order.id, OrderStatus.preparing);
                        } else if (effectiveStatus == OrderStatus.preparing) {
                          db.updateOrderStatus(order.id, OrderStatus.ready);
                        } else if (effectiveStatus == OrderStatus.ready) {
                          _settleOrderFromList(order);
                        }
                        setState(() {});
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: effectiveStatus == OrderStatus.preparing
                              ? const Color(0xFF10B981)
                              : (effectiveStatus == OrderStatus.ready ? const Color(0xFFD97706) : const Color(0xFF0F172A)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          effectiveStatus == OrderStatus.pending
                              ? 'Accept'
                              : (effectiveStatus == OrderStatus.preparing ? 'Mark Ready' : 'Settle'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 4. Bottom Row: Date Timestamp on Far Left & Large Neumorphic Chevron Button on Far Right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Timestamp on Far Left
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    formattedTime,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // Large Circular Neumorphic Chevron Button at Far Right Corner
              InkWell(
                onTap: () => OrderDetailSheet.show(context, initialOrder: order),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF3F9),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.95),
                        offset: const Offset(-2, -2),
                        blurRadius: 3,
                      ),
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                        offset: const Offset(2, 3),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
