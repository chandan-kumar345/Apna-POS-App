import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';
import '../../core/services/report_service.dart';
import '../pos/receipt_dialog.dart';

enum SalesDateFilter { allTime, today, yesterday, thisWeek, thisMonth, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseService _db = DatabaseService();
  final ReportService _reportService = ReportService();

  SalesDateFilter _selectedDateFilter = SalesDateFilter.allTime;
  DateTimeRange? _customDateRange;

  bool _isLoading = true;
  String? _errorMessage;
  SalesReportData? _reportData;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _db.addListener(_onDbChange);
    _loadSalesReport();
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChange);
    super.dispose();
  }

  void _onDbChange() {
    if (mounted) {
      _loadSalesReport(showLoading: false);
    }
  }

  Future<void> _loadSalesReport({bool showLoading = true}) async {
    final currentSeq = ++_requestSeq;
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      String? period;
      String? startDate;
      String? endDate;

      switch (_selectedDateFilter) {
        case SalesDateFilter.allTime:
          period = 'allTime';
          break;
        case SalesDateFilter.today:
          period = 'today';
          break;
        case SalesDateFilter.yesterday:
          period = 'yesterday';
          break;
        case SalesDateFilter.thisWeek:
          period = 'thisWeek';
          break;
        case SalesDateFilter.thisMonth:
          period = 'thisMonth';
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

      final data = await _reportService.fetchSalesReport(
        period: period,
        startDate: startDate,
        endDate: endDate,
      );

      if (mounted && currentSeq == _requestSeq) {
        setState(() {
          _reportData = data;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted && currentSeq == _requestSeq) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load sales report from server: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _exportSalesToExcel() async {
    final ordersToExport = _reportData?.orders ?? [];
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

    final currency = _db.restaurant?.currencySymbol ?? '₹';
    final List<List<dynamic>> rows = [];

    // CSV Header
    rows.add([
      'Order Number',
      'Date & Time',
      'Order Type',
      'Table Number',
      'Customer Name',
      'Customer Phone',
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
        order.customerName ?? '',
        order.customerPhone ?? '',
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
      _loadSalesReport();
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
    final currency = _db.restaurant?.currencySymbol ?? '₹';
    final summary = _reportData?.summary ?? SalesReportSummary();
    final paymentModes = _reportData?.paymentModes ?? [];
    final orders = _reportData?.orders ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => await _loadSalesReport(),
          color: const Color(0xFF051C48),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sales & Analytics Report',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _exportSalesToExcel,
                        icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                        label: const Text(
                          'Export Excel',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

                // LOADING / ERROR BANNER
                if (_isLoading)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF051C48)),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Updating sales report from server...',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A)),
                        ),
                      ],
                    ),
                  )
                else if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _loadSalesReport(),
                          child: const Text('Retry', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                // COMPACT STAT SUMMARY BOXES (RESPONSIVE 1-ROW OR 2-ROWS WRAPPED LAYOUT)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isSingleRow = constraints.maxWidth >= 700;

                    final card1 = _buildCompactStatCard(
                      title: 'Total Sales Revenue',
                      value: '$currency${summary.totalRevenue.toStringAsFixed(2)}',
                      subtitle: '${summary.totalOrders} Total Bills (${_getFilterLabel()})',
                      icon: Icons.payments_rounded,
                      accentColor: const Color(0xFF10B981),
                    );

                    final card2 = _buildCompactStatCard(
                      title: 'Total Bills Generated',
                      value: '${summary.totalOrders} Bills',
                      subtitle: 'Gross: $currency${summary.grossSales.toStringAsFixed(0)} | Net: $currency${summary.netSales.toStringAsFixed(0)}',
                      icon: Icons.receipt_long_rounded,
                      accentColor: const Color(0xFF00C2FF),
                    );

                    final card3 = _buildCompactStatCard(
                      title: 'Average Order Value',
                      value: '$currency${summary.avgOrderValue.toStringAsFixed(2)}',
                      subtitle: 'Total Items Sold: ${summary.totalItems}',
                      icon: Icons.trending_up_rounded,
                      accentColor: const Color(0xFF8B5CF6),
                    );

                    if (isSingleRow) {
                      return Row(
                        children: [
                          Expanded(child: card1),
                          const SizedBox(width: 12),
                          Expanded(child: card2),
                          const SizedBox(width: 12),
                          Expanded(child: card3),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: card1),
                              const SizedBox(width: 10),
                              Expanded(child: card2),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: card3,
                          ),
                        ],
                      );
                    }
                  },
                ),

                const SizedBox(height: 20),

                // SECTION 3 & 4: PAYMENT BREAKDOWN & RECENT BILLS TABLE
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 850;

                    // Calculate Cash, UPI, Card amounts specifically
                    double cashTotal = 0.0;
                    double upiTotal = 0.0;
                    double cardTotal = 0.0;

                    for (final p in paymentModes) {
                      final m = '${p.mode.toLowerCase()} ${p.rawMode.toLowerCase()}';
                      if (m.contains('cash')) {
                        cashTotal += p.amount;
                      } else if (m.contains('upi') || m.contains('qr') || m.contains('online') || m.contains('gpay') || m.contains('phonepe') || m.contains('paytm')) {
                        upiTotal += p.amount;
                      } else if (m.contains('card') || m.contains('debit') || m.contains('credit')) {
                        cardTotal += p.amount;
                      } else {
                        cashTotal += p.amount;
                      }
                    }

                    if (paymentModes.isEmpty && orders.isNotEmpty) {
                      for (final o in orders) {
                        final m = o.paymentMethod.toLowerCase();
                        if (m.contains('cash')) {
                          cashTotal += o.totalAmount;
                        } else if (m.contains('upi') || m.contains('qr') || m.contains('online')) {
                          upiTotal += o.totalAmount;
                        } else if (m.contains('card')) {
                          cardTotal += o.totalAmount;
                        } else {
                          cashTotal += o.totalAmount;
                        }
                      }
                    }

                    final totalRev = summary.totalRevenue > 0
                        ? summary.totalRevenue
                        : (cashTotal + upiTotal + cardTotal);

                    final cashPct = totalRev > 0 ? (cashTotal / totalRev) * 100 : 0.0;
                    final upiPct = totalRev > 0 ? (upiTotal / totalRev) * 100 : 0.0;
                    final cardPct = totalRev > 0 ? (cardTotal / totalRev) * 100 : 0.0;

                    // Revenue by Payment Mode Card (Only Cash, UPI, and Card)
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

                          _buildPaymentRow(
                            'Cash Payments',
                            cashTotal,
                            totalRev,
                            cashPct,
                            currency,
                            const Color(0xFF10B981),
                            Icons.payments_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildPaymentRow(
                            'UPI / Digital QR',
                            upiTotal,
                            totalRev,
                            upiPct,
                            currency,
                            const Color(0xFF00C2FF),
                            Icons.qr_code_2_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildPaymentRow(
                            'Cards (Debit/Credit)',
                            cardTotal,
                            totalRev,
                            cardPct,
                            currency,
                            const Color(0xFF8B5CF6),
                            Icons.credit_card_rounded,
                          ),

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

                    // Sales Bills & Receipts List Card
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
                                    'Sales Bills & Receipts (${orders.length})',
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

                          orders.isEmpty
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
                                  itemCount: orders.length,
                                  separatorBuilder: (context, index) => const Divider(color: Color(0xFFF1F5F9), height: 12),
                                  itemBuilder: (context, idx) {
                                    final order = orders[idx];
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
                                                '#${order.orderNumber} • ${order.tableNumber ?? (order.orderType == OrderType.takeaway ? "Takeaway" : "Dine In")}',
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
            _loadSalesReport();
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.3),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(
    String mode,
    double amount,
    double total,
    double percentage,
    String currency,
    Color color,
    IconData icon,
  ) {
    final pct = total > 0 ? (amount / total) : 0.0;
    final displayPct = percentage > 0 ? percentage : (pct * 100);

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
              '$currency${amount.toStringAsFixed(2)} (${displayPct.toStringAsFixed(0)}%)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
