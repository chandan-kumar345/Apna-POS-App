import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';
import '../pos/receipt_dialog.dart';

enum SalesDateFilter { today, yesterday, thisWeek, thisMonth, allTime, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final db = DatabaseService();

  SalesDateFilter _selectedDateFilter = SalesDateFilter.allTime;
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    db.addListener(_onDbChange);
    db.syncWithBackend();
  }

  @override
  void dispose() {
    db.removeListener(_onDbChange);
    super.dispose();
  }

  void _onDbChange() {
    if (mounted) setState(() {});
  }

  List<OrderModel> get _filteredOrders {
    final allOrders = db.orders.where((o) =>
      o.status == OrderStatus.completed &&
      !o.paymentMethod.toLowerCase().contains('kot')
    ).toList();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    switch (_selectedDateFilter) {
      case SalesDateFilter.today:
        return allOrders.where((o) {
          final dt = DateTime.tryParse(o.createdAt);
          if (dt == null) return true;
          return dt.isAfter(todayStart);
        }).toList();

      case SalesDateFilter.yesterday:
        return allOrders.where((o) {
          final dt = DateTime.tryParse(o.createdAt);
          if (dt == null) return false;
          return dt.isAfter(yesterdayStart) && dt.isBefore(todayStart);
        }).toList();

      case SalesDateFilter.thisWeek:
        final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
        return allOrders.where((o) {
          final dt = DateTime.tryParse(o.createdAt);
          if (dt == null) return true;
          return dt.isAfter(weekStart);
        }).toList();

      case SalesDateFilter.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        return allOrders.where((o) {
          final dt = DateTime.tryParse(o.createdAt);
          if (dt == null) return true;
          return dt.isAfter(monthStart);
        }).toList();

      case SalesDateFilter.custom:
        if (_customDateRange == null) return allOrders;
        final start = _customDateRange!.start;
        final end = _customDateRange!.end.add(const Duration(days: 1));
        return allOrders.where((o) {
          final dt = DateTime.tryParse(o.createdAt);
          if (dt == null) return true;
          return dt.isAfter(start) && dt.isBefore(end);
        }).toList();

      case SalesDateFilter.allTime:
        return allOrders;
    }
  }

  Future<void> _exportSalesToExcel() async {
    final ordersToExport = _filteredOrders;
    if (ordersToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No sales orders found for the selected date filter to export.'),
          backgroundColor: Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final currency = db.restaurant?.currencySymbol ?? '₹';
    final List<List<dynamic>> rows = [];

    // CSV Header
    rows.add([
      'Order Number',
      'Date & Time',
      'Order Type',
      'Table Number',
      'Payment Method',
      'Total Items',
      'Subtotal ($currency)',
      'Tax Amount ($currency)',
      'Discount ($currency)',
      'Grand Total ($currency)',
    ]);

    // Data Rows
    for (final order in ordersToExport) {
      final totalQty = order.items.fold(0, (sum, item) => sum + item.quantity);
      final typeStr = order.orderType == OrderType.dineIn
          ? 'Dine In'
          : (order.orderType == OrderType.takeaway ? 'Takeaway' : 'Delivery');

      rows.add([
        order.orderNumber,
        order.createdAt,
        typeStr,
        order.tableNumber ?? 'N/A',
        order.paymentMethod,
        totalQty,
        order.subtotal.toStringAsFixed(2),
        order.taxAmount.toStringAsFixed(2),
        order.discountAmount.toStringAsFixed(2),
        order.totalAmount.toStringAsFixed(2),
      ]);
    }

    final StringBuffer csvBuffer = StringBuffer();
    for (final row in rows) {
      final line = row.map((field) => '"${field.toString().replaceAll('"', '""')}"').join(',');
      csvBuffer.writeln(line);
    }
    final String csvData = csvBuffer.toString();

    try {
      final tempDir = await getTemporaryDirectory();
      final String filterName = _selectedDateFilter.name;
      final String filePath = '${tempDir.path}/Apna_POS_Sales_Report_$filterName.csv';
      final File file = File(filePath);

      await file.writeAsString(csvData);

      final XFile xFile = XFile(filePath, mimeType: 'text/csv');
      await Share.shareXFiles(
        [xFile],
        text: 'Apna POS Sales Report Export (${ordersToExport.length} Bills)',
        subject: 'Sales Report Excel File',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export error: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        _selectedDateFilter = SalesDateFilter.custom;
      });
    }
  }

  String _getFilterLabel() {
    switch (_selectedDateFilter) {
      case SalesDateFilter.today:
        return 'Today';
      case SalesDateFilter.yesterday:
        return 'Yesterday';
      case SalesDateFilter.thisWeek:
        return 'This Week';
      case SalesDateFilter.thisMonth:
        return 'This Month';
      case SalesDateFilter.custom:
        if (_customDateRange != null) {
          final fmt = DateFormat('d MMM');
          return '${fmt.format(_customDateRange!.start)} - ${fmt.format(_customDateRange!.end)}';
        }
        return 'Custom Range';
      case SalesDateFilter.allTime:
        return 'All Time';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = db.restaurant?.currencySymbol ?? '₹';
    final filtered = _filteredOrders;

    final totalOrdersCount = filtered.length;
    final totalRevenue = filtered.fold(0.0, (sum, o) => sum + o.totalAmount);
    final avgOrderValue = totalOrdersCount > 0 ? (totalRevenue / totalOrdersCount) : 0.0;

    final upiTotal = filtered.where((o) => o.paymentMethod == 'UPI').fold(0.0, (sum, o) => sum + o.totalAmount);
    final cashTotal = filtered.where((o) => o.paymentMethod == 'Cash').fold(0.0, (sum, o) => sum + o.totalAmount);
    final cardTotal = filtered.where((o) => o.paymentMethod == 'Card').fold(0.0, (sum, o) => sum + o.totalAmount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SCREEN HEADER BANNER WITH EXPORT BUTTON
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF051C48), Color(0xFF0A2B6E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.analytics_rounded, color: Color(0xFF00C2FF), size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sales & Analytics Report',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 1),
                          // Text(
                          //   'Track revenue, payment breakdown & export bills (${_getFilterLabel()})',
                          //   style: const TextStyle(fontSize: 11.5, color: Color(0xFFCBD5E1)),
                          // ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _exportSalesToExcel,
                     // icon: const Icon(Icons.description_rounded, size: 18, color: Colors.white),
                      label: const Text('Export Excel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // DATE FILTER SELECTION BAR (WHITE SEMI-CURVED BOX)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt_rounded, color: Color(0xFF051C48), size: 18),
                    const SizedBox(width: 8),
                    // const Text(
                    //   'Date Filter:',
                    //   style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    // ),
                    //const SizedBox(width: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterChip('All Time', SalesDateFilter.allTime),
                            _buildFilterChip('Today', SalesDateFilter.today),
                            _buildFilterChip('Yesterday', SalesDateFilter.yesterday),
                            _buildFilterChip('This Week', SalesDateFilter.thisWeek),
                            _buildFilterChip('This Month', SalesDateFilter.thisMonth),
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                avatar: const Icon(Icons.calendar_month_rounded, size: 14),
                                label: Text(_selectedDateFilter == SalesDateFilter.custom ? _getFilterLabel() : 'Custom'),
                                selected: _selectedDateFilter == SalesDateFilter.custom,
                                selectedColor: const Color(0xFF051C48),
                                backgroundColor: const Color(0xFFF1F5F9),
                                labelStyle: TextStyle(
                                  color: _selectedDateFilter == SalesDateFilter.custom ? Colors.white : const Color(0xFF334155),
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
              ),

              const SizedBox(height: 16),

              // COMPACT STAT SUMMARY BOXES (4 BOXES IN GRID/ROW)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  final crossCount = isWide ? 4 : 2;

                  return GridView.count(
                    crossAxisCount: crossCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: isWide ? 1.8 : 1.6,
                    children: [
                      _buildCompactStatCard(
                        title: 'Total Sales Revenue',
                        value: '$currency${totalRevenue.toStringAsFixed(2)}',
                        subtitle: '$totalOrdersCount Total Bills (${_getFilterLabel()})',
                        icon: Icons.payments_rounded,
                        accentColor: const Color(0xFF10B981),
                      ),
                      _buildCompactStatCard(
                        title: 'Total Bills Generated',
                        value: '$totalOrdersCount Bills',
                        subtitle: 'Dine-In, Takeaway & Delivery',
                        icon: Icons.receipt_long_rounded,
                        accentColor: const Color(0xFF00C2FF),
                      ),
                      _buildCompactStatCard(
                        title: 'Average Order Value',
                        value: '$currency${avgOrderValue.toStringAsFixed(2)}',
                        subtitle: 'Per Completed Guest Bill',
                        icon: Icons.trending_up_rounded,
                        accentColor: const Color(0xFF8B5CF6),
                      ),
                      _buildCompactStatCard(
                        title: 'UPI / Online Sales',
                        value: '$currency${upiTotal.toStringAsFixed(2)}',
                        subtitle: 'Cash: $currency${cashTotal.toStringAsFixed(0)} | Card: $currency${cardTotal.toStringAsFixed(0)}',
                        icon: Icons.qr_code_2_rounded,
                        accentColor: const Color(0xFF051C48),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              // SECTION 3 & 4: PAYMENT BREAKDOWN & RECENT BILLS TABLE
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 850;

                  Widget paymentBreakdownCard = Container(
                    padding: const EdgeInsets.all(16),
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Color(0xFF051C48), shape: BoxShape.circle),
                              child: const Icon(Icons.pie_chart_rounded, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Revenue by Payment Mode',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        _buildPaymentRow('UPI / Digital QR', upiTotal, totalRevenue, currency, const Color(0xFF00C2FF), Icons.qr_code_2_rounded),
                        const SizedBox(height: 12),
                        _buildPaymentRow('Cash Payments', cashTotal, totalRevenue, currency, const Color(0xFF10B981), Icons.payments_rounded),
                        const SizedBox(height: 12),
                        _buildPaymentRow('Cards (Debit/Credit)', cardTotal, totalRevenue, currency, const Color(0xFF8B5CF6), Icons.credit_card_rounded),

                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lightbulb_rounded, color: Color(0xFF051C48), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tip: Filter sales by date to review shift collection before cash drawer settlement.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );

                  Widget billsListCard = Container(
                    padding: const EdgeInsets.all(16),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(color: Color(0xFF051C48), shape: BoxShape.circle),
                                  child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 16),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Sales Bills & Receipts (${filtered.length})',
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getFilterLabel(),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF051C48)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        filtered.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.inbox_rounded, color: Color(0xFFCBD5E1), size: 36),
                                      SizedBox(height: 8),
                                      Text('No sales bills found for this date range', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 12),
                                itemBuilder: (context, idx) {
                                  final order = filtered[idx];
                                  final totalQty = order.items.fold(0, (sum, i) => sum + i.quantity);

                                  return Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.receipt_rounded, color: Color(0xFF051C48), size: 18),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '#${order.orderNumber} • ${order.tableNumber ?? "Takeaway"}',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${order.createdAt} • ${order.paymentMethod} • $totalQty items',
                                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '$currency${order.totalAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: const Icon(Icons.visibility_rounded, color: Color(0xFF051C48), size: 18),
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                        tooltip: 'View Invoice',
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => ReceiptDialog(order: order, currency: currency),
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ],
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      children: [
                        paymentBreakdownCard,
                        const SizedBox(height: 14),
                        billsListCard,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: paymentBreakdownCard),
                      const SizedBox(width: 14),
                      Expanded(flex: 3, child: billsListCard),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, SalesDateFilter filter) {
    final isSelected = _selectedDateFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF051C48),
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF334155),
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          fontSize: 11.5,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedDateFilter = filter;
            });
          }
        },
      ),
    );
  }

  Widget _buildCompactStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String mode, double amount, double total, String currency, Color color, IconData icon) {
    final pct = total > 0 ? (amount / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 6),
                Text(
                  mode,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                ),
              ],
            ),
            Text(
              '$currency${amount.toStringAsFixed(2)} (${(pct * 100).toStringAsFixed(0)}%)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
