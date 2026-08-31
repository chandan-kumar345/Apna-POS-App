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

enum OrderDateFilter { allTime, today, yesterday, thisWeek, thisMonth, custom }

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

  // Date Filter matching Sales Report Screen
  OrderDateFilter _selectedDateFilter = OrderDateFilter.allTime;
  DateTimeRange? _customDateRange;

  // REMOVED 'All' OPTION; DEFAULT TO 'DineIn' & 'Preparing'
  String _selectedOrderTypeFilter = 'DineIn'; // 'DineIn', 'TakeAway', 'Delivery'
  String _selectedStatusFilter = 'Preparing'; // 'Pending', 'Preparing', 'Ready', 'Completed', 'Cancelled'
  String _searchQuery = '';
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
          totalAmount: totalAmount ?? order.totalAmount,
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
        return const Color(0xFF051C48); // Theme Navy
      case OrderStatus.ready:
        return const Color(0xFF10B981); // Emerald Green
      case OrderStatus.completed:
        return const Color(0xFF051C48); // Theme Navy
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
    if (o.createdAt.trim().isEmpty) return true;

    DateTime? orderDate = DateTime.tryParse(o.createdAt);
    if (orderDate == null) {
      try {
        orderDate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(o.createdAt, true);
      } catch (_) {
        return true;
      }
    }
    orderDate = orderDate.toLocal();

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
      case OrderDateFilter.custom:
        if (_customDateRange == null) return true;
        final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
        final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59, 999);
        return orderDate.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
            orderDate.isBefore(end.add(const Duration(milliseconds: 1)));
    }
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF051C48),
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
        _selectedDateFilter = OrderDateFilter.custom;
      });
    }
  }

  String _getFilterLabel() {
    switch (_selectedDateFilter) {
      case OrderDateFilter.today:
        return 'Today';
      case OrderDateFilter.yesterday:
        return 'Yesterday';
      case OrderDateFilter.thisWeek:
        return 'This Week';
      case OrderDateFilter.thisMonth:
        return 'This Month';
      case OrderDateFilter.custom:
        if (_customDateRange != null) {
          final fmt = DateFormat('d MMM');
          return '${fmt.format(_customDateRange!.start)} - ${fmt.format(_customDateRange!.end)}';
        }
        return 'Custom';
      case OrderDateFilter.allTime:
        return 'All Time';
    }
  }

  Widget _buildDateFilterChip(String label, OrderDateFilter filter) {
    final isSelected = _selectedDateFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF051C48),
        backgroundColor: const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(
          color: isSelected ? const Color(0xFF051C48) : const Color(0xFFCBD5E1),
          width: isSelected ? 1.5 : 1,
        ),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF334155),
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
        ),
        onSelected: (_) {
          setState(() {
            _selectedDateFilter = filter;
          });
        },
      ),
    );
  }

  Widget _buildDateFilterBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded, color: Color(0xFF051C48), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildDateFilterChip('All Time', OrderDateFilter.allTime),
                  _buildDateFilterChip('Today', OrderDateFilter.today),
                  _buildDateFilterChip('Yesterday', OrderDateFilter.yesterday),
                  _buildDateFilterChip('This Week', OrderDateFilter.thisWeek),
                  _buildDateFilterChip('This Month', OrderDateFilter.thisMonth),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      avatar: const Icon(Icons.calendar_month_rounded, size: 14),
                      label: Text(_selectedDateFilter == OrderDateFilter.custom ? _getFilterLabel() : 'Custom'),
                      selected: _selectedDateFilter == OrderDateFilter.custom,
                      selectedColor: const Color(0xFF051C48),
                      backgroundColor: const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(
                        color: _selectedDateFilter == OrderDateFilter.custom ? const Color(0xFF051C48) : const Color(0xFFCBD5E1),
                        width: _selectedDateFilter == OrderDateFilter.custom ? 1.5 : 1,
                      ),
                      labelStyle: TextStyle(
                        color: _selectedDateFilter == OrderDateFilter.custom ? Colors.white : const Color(0xFF334155),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                      onSelected: (_) => _pickCustomDateRange(),
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

  @override
  Widget build(BuildContext context) {
    final currency = db.restaurant?.currencySymbol ?? '₹';

    return ListenableBuilder(
      listenable: db,
      builder: (context, _) {
        // Filter orders by OrderType (NO 'All' option) and Date Filter
        List<OrderModel> typeFilteredOrders = db.orders.where((o) {
          final matchesType = (_selectedOrderTypeFilter == 'Delivery')
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
              final isRunningKotTable = o.tableNumber != null &&
                  db.tables.any((t) => (t.name == o.tableNumber || t.tableNumber.toString() == o.tableNumber) && t.status == TableStatus.runningKot);
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
          if (_selectedStatusFilter == 'Pending') return o.status == OrderStatus.pending;
          if (_selectedStatusFilter == 'Preparing') {
            final isRunningKotTable = o.tableNumber != null &&
                db.tables.any((t) => (t.name == o.tableNumber || t.tableNumber.toString() == o.tableNumber) && t.status == TableStatus.runningKot);
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
            return matchesNum || matchesTable || matchesAddress;
          }).toList();
        }

        // Sort latest orders first
        filteredOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar: Clean Title with Back & Refresh Action
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                  child: Row(
                    children: [
                      if (Navigator.of(context).canPop() || widget.showBackButton) ...[
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF051C48), size: 20),
                          tooltip: 'Back',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Expanded(
                        child: Text(
                          'All Received Orders',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _isManualRefreshing ? null : _refreshOrders,
                        icon: _isManualRefreshing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF051C48)),
                              )
                            : const Icon(Icons.refresh_rounded, color: Color(0xFF051C48), size: 22),
                        tooltip: 'Refresh Orders from Server',
                      ),
                    ],
                  ),
                ),

                // Date Filter Bar (Matches Sales Report Screen)
                _buildDateFilterBar(),

                // 1) Order Type Section Chips (NO 'All' OPTION)
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: ['DineIn', 'TakeAway', 'Delivery'].map((type) {
                      final isSel = _selectedOrderTypeFilter == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(type),
                          selected: isSel,
                          selectedColor: const Color(0xFF051C48),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: isSel ? const Color(0xFF051C48) : const Color(0xFFCBD5E1), width: isSel ? 1.5 : 1),
                          labelStyle: TextStyle(color: isSel ? Colors.white : const Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 13),
                          onSelected: (_) {
                            setState(() {
                              _selectedOrderTypeFilter = type;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 10),

                // 2) Order Status Pills Row (NO 'All' OPTION)
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildStatusPill('Pending', '⏳ Pending', pendingCount, const Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      _buildStatusPill('Preparing', '👨‍🍳 Preparing', preparingCount, const Color(0xFF051C48)),
                      const SizedBox(width: 8),
                      _buildStatusPill('Ready', '🔔 Ready', readyCount, const Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      _buildStatusPill('Completed', '✅ Completed', completedCount, const Color(0xFF051C48)),
                      const SizedBox(width: 8),
                      _buildStatusPill('Cancelled', '❌ Cancelled', cancelledCount, const Color(0xFFEF4444)),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 3) Search Bar Field with Semi-Curved Corners
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Search orders by Order #, Table or Address...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF051C48), size: 22),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFF051C48), width: 2),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 4) Responsive Order Cards with Pull to Refresh
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshOrders,
                    color: const Color(0xFF051C48),
                    child: filteredOrders.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.shopping_cart_outlined, size: 48, color: Color(0xFF94A3B8)),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'No $_selectedStatusFilter $_selectedOrderTypeFilter Orders',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'New active orders will automatically show here',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 650;
                            return ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: isWide
                                  ? (filteredOrders.length / 2).ceil()
                                  : filteredOrders.length,
                              itemBuilder: (context, rowIdx) {
                                Widget buildCard(OrderModel order) {
                                  final isRunningKot = order.tableNumber != null &&
                                      db.tables.any((t) =>
                                          (t.name == order.tableNumber ||
                                              t.tableNumber.toString() == order.tableNumber) &&
                                          t.status == TableStatus.runningKot);
                                  final effectiveStatus = (isRunningKot && order.status == OrderStatus.pending) ? OrderStatus.preparing : order.status;
                                  final statusColor = _getStatusColor(effectiveStatus);

                                  return InkWell(
                                    onTap: () => OrderDetailSheet.show(context, initialOrder: order),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 0),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.04),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                    padding: const EdgeInsets.all(11),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Header: Order #, Type Badge, Status Badge
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                '#${order.orderNumber}',
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF051C48).withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(7),
                                                border: Border.all(color: const Color(0xFF051C48).withOpacity(0.2)),
                                              ),
                                              child: Text(
                                                '${_getOrderTypeLabel(order.orderType)}${order.tableNumber != null && order.orderType == OrderType.dineIn ? " (${order.tableNumber})" : ""}',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF051C48)),
                                              ),
                                            ),
                                            if (order.printCount > 0) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF051C48).withOpacity(0.06),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'P#${order.printCount}',
                                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF051C48)),
                                                ),
                                              ),
                                            ],
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: order.isPaid
                                                    ? const Color(0xFF10B981).withOpacity(0.12)
                                                    : const Color(0xFFF59E0B).withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(7),
                                                border: Border.all(
                                                  color: order.isPaid
                                                      ? const Color(0xFF10B981).withOpacity(0.4)
                                                      : const Color(0xFFF59E0B).withOpacity(0.4),
                                                ),
                                              ),
                                              child: Text(
                                                order.isPaid ? 'PAID' : 'UNPAID',
                                                style: TextStyle(
                                                  color: order.isPaid ? const Color(0xFF10B981) : const Color(0xFFD97706),
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(9),
                                                border: Border.all(color: statusColor.withOpacity(0.4)),
                                              ),
                                              child: Text(
                                                _getStatusLabel(effectiveStatus),
                                                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900),
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 7),
                                        const Divider(color: Color(0xFFF1F5F9), height: 1),
                                        const SizedBox(height: 7),

                                        // Items list — Column, no fixed height
                                        ...order.items.map((item) => Padding(
                                              padding: const EdgeInsets.only(bottom: 3),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    '${item.quantity}×',
                                                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF051C48), fontSize: 12),
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Expanded(
                                                    child: Text(
                                                      item.item.name,
                                                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Text(
                                                    '$currency ${item.totalPrice.toStringAsFixed(0)}',
                                                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            )),

                                        const SizedBox(height: 7),
                                        const Divider(color: Color(0xFFF1F5F9), height: 1),
                                        const SizedBox(height: 7),

                                        // Footer: Total & Action Buttons
                                        Row(
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Total', style: TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                                                Text(
                                                  '$currency ${order.totalAmount.toStringAsFixed(0)}',
                                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF051C48)),
                                                ),
                                              ],
                                            ),
                                            const Spacer(),
                                            if (order.tableNumber != null &&
                                                 order.tableNumber!.trim().isNotEmpty &&
                                                 (effectiveStatus == OrderStatus.pending ||
                                                     effectiveStatus == OrderStatus.preparing))
                                               Padding(
                                                 padding: const EdgeInsets.only(right: 5),
                                                 child: InkWell(
                                                   onTap: () {
                                                     if (widget.onOpenPosForTable != null) {
                                                       widget.onOpenPosForTable!(order.tableNumber!);
                                                     }
                                                   },
                                                   borderRadius: BorderRadius.circular(8),
                                                   child: Container(
                                                     height: 29,
                                                     padding: const EdgeInsets.symmetric(horizontal: 8),
                                                     decoration: BoxDecoration(
                                                       color: const Color(0xFF051C48).withOpacity(0.08),
                                                       borderRadius: BorderRadius.circular(8),
                                                       border: Border.all(color: const Color(0xFF051C48).withOpacity(0.3)),
                                                     ),
                                                     alignment: Alignment.center,
                                                     child: const Row(
                                                       mainAxisSize: MainAxisSize.min,
                                                       children: [
                                                         Icon(Icons.point_of_sale_rounded, size: 12, color: Color(0xFF051C48)),
                                                         SizedBox(width: 3),
                                                         Text('POS', style: TextStyle(color: Color(0xFF051C48), fontSize: 11, fontWeight: FontWeight.bold)),
                                                       ],
                                                     ),
                                                   ),
                                                 ),
                                               ),
                                             // KOT Button
                                             InkWell(
                                               onTap: () async {
                                                 final printerService = BluetoothPrinterService();
                                                 final bool isConnected = await printerService.isConnected();
                                                 if (!context.mounted) return;

                                                 if (isConnected) {
                                                   ScaffoldMessenger.of(context).showSnackBar(
                                                     const SnackBar(
                                                       content: Text('Printing KOT Ticket...'),
                                                       backgroundColor: Color(0xFFD97706),
                                                       duration: Duration(seconds: 2),
                                                     ),
                                                   );
                                                   final rest = DatabaseService().restaurant;
                                                   final success = await printerService.printKOT(order: order, restaurant: rest);
                                                   if (context.mounted && !success) {
                                                     PrinterSelectionDialog.show(context, orderToPrint: order, currency: currency);
                                                   }
                                                 } else {
                                                   final bool reconnected = await printerService.autoConnectSavedPrinter();
                                                   if (reconnected) {
                                                     final rest = DatabaseService().restaurant;
                                                     await printerService.printKOT(order: order, restaurant: rest);
                                                   } else if (context.mounted) {
                                                     PrinterSelectionDialog.show(context, orderToPrint: order, currency: currency);
                                                   }
                                                 }
                                               },
                                               borderRadius: BorderRadius.circular(8),
                                               child: Container(
                                                 height: 29,
                                                 padding: const EdgeInsets.symmetric(horizontal: 8),
                                                 decoration: BoxDecoration(
                                                   color: const Color(0xFFD97706).withOpacity(0.08),
                                                   borderRadius: BorderRadius.circular(8),
                                                   border: Border.all(color: const Color(0xFFD97706).withOpacity(0.4)),
                                                 ),
                                                 alignment: Alignment.center,
                                                 child: const Row(
                                                   mainAxisSize: MainAxisSize.min,
                                                   children: [
                                                     Icon(Icons.soup_kitchen_rounded, size: 12, color: Color(0xFFD97706)),
                                                     SizedBox(width: 3),
                                                     Text('KOT', style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold)),
                                                   ],
                                                 ),
                                               ),
                                             ),
                                             const SizedBox(width: 5),
                                             // Bill Button
                                             InkWell(
                                               onTap: () => showDialog(
                                                 context: context,
                                                 useRootNavigator: true,
                                                 barrierDismissible: true,
                                                 builder: (_) => ReceiptDialog(order: order, currency: currency),
                                               ),
                                               borderRadius: BorderRadius.circular(8),
                                               child: Container(
                                                 height: 29,
                                                 padding: const EdgeInsets.symmetric(horizontal: 8),
                                                 decoration: BoxDecoration(
                                                   color: const Color(0xFF051C48).withOpacity(0.08),
                                                   borderRadius: BorderRadius.circular(8),
                                                   border: Border.all(color: const Color(0xFF051C48).withOpacity(0.3)),
                                                 ),
                                                 alignment: Alignment.center,
                                                 child: const Row(
                                                   mainAxisSize: MainAxisSize.min,
                                                   children: [
                                                     Icon(Icons.receipt_rounded, size: 12, color: Color(0xFF051C48)),
                                                     SizedBox(width: 3),
                                                     Text('Bill', style: TextStyle(color: Color(0xFF051C48), fontSize: 11, fontWeight: FontWeight.bold)),
                                                   ],
                                                 ),
                                               ),
                                             ),
                                             if (effectiveStatus == OrderStatus.pending ||
                                                 effectiveStatus == OrderStatus.preparing ||
                                                 effectiveStatus == OrderStatus.ready) ...[
                                               const SizedBox(width: 5),
                                               // Status Transition Button (Accept / Mark Ready / Settle)
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
                                                 borderRadius: BorderRadius.circular(8),
                                                 child: Container(
                                                   height: 29,
                                                   padding: const EdgeInsets.symmetric(horizontal: 9),
                                                   decoration: BoxDecoration(
                                                     color: effectiveStatus == OrderStatus.preparing
                                                         ? const Color(0xFF10B981)
                                                         : (effectiveStatus == OrderStatus.ready
                                                             ? const Color(0xFFD97706)
                                                             : const Color(0xFF051C48)),
                                                     borderRadius: BorderRadius.circular(8),
                                                   ),
                                                   alignment: Alignment.center,
                                                   child: Text(
                                                     effectiveStatus == OrderStatus.pending
                                                         ? 'Accept'
                                                         : (effectiveStatus == OrderStatus.preparing ? 'Mark Ready' : 'Settle'),
                                                     style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                   ),
                                                 ),
                                               ),
                                             ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                                if (isWide) {
                                  final leftIdx = rowIdx * 2;
                                  final rightIdx = leftIdx + 1;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: buildCard(filteredOrders[leftIdx])),
                                        const SizedBox(width: 12),
                                        if (rightIdx < filteredOrders.length)
                                          Expanded(child: buildCard(filteredOrders[rightIdx]))
                                        else
                                          const Expanded(child: SizedBox()),
                                      ],
                                    ),
                                  );
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: buildCard(filteredOrders[rowIdx]),
                                );
                              },
                            );
                          },
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusPill(String filterKey, String label, int count, Color color) {
    final isSel = _selectedStatusFilter == filterKey;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatusFilter = filterKey;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel ? color : Colors.white,
          borderRadius: BorderRadius.circular(12), // SEMI CURVED CORNERS BOX
          border: Border.all(color: isSel ? color : const Color(0xFFCBD5E1)),
        ),
        child: Row(
          children: [
            Text(
              '$label ($count)',
              style: TextStyle(
                color: isSel ? Colors.white : const Color(0xFF475569),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
