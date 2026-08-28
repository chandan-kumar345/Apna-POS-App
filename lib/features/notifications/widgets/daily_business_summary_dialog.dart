import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/order_model.dart';
import '../../../core/services/report_service.dart';
import '../../orders/order_detail_sheet.dart';
import '../../reports/reports_screen.dart';

class DailyBusinessSummaryDialog extends StatefulWidget {
  final Map<String, dynamic> metadata;
  final String title;
  final String message;

  const DailyBusinessSummaryDialog({
    super.key,
    required this.metadata,
    this.title = 'Daily Business Summary',
    this.message = '',
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> metadata,
    String title = 'Daily Business Summary',
    String message = '',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DailyBusinessSummaryDialog(
        metadata: metadata,
        title: title,
        message: message,
      ),
    );
  }

  @override
  State<DailyBusinessSummaryDialog> createState() => _DailyBusinessSummaryDialogState();
}

class _DailyBusinessSummaryDialogState extends State<DailyBusinessSummaryDialog> {
  final ReportService _reportService = ReportService();
  final List<Map<String, dynamic>> _displayOrders = [];

  double _totalSales = 0.0;
  int _ordersCount = 0;
  double _avgOrderValue = 0.0;
  String _formattedDate = '';
  late DateTime _targetDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _targetDate = _parseTargetDate();
    _initData();
  }

  /// Robustly resolves the exact target date mentioned in metadata, entityId, message, or timestamp
  DateTime _parseTargetDate() {
    // 1. Check metadata['date'] (e.g. '2026-08-28' or '28 Aug 2026')
    final d1 = widget.metadata['date']?.toString();
    if (d1 != null && d1.trim().isNotEmpty) {
      final parsed = _tryParseAnyDate(d1);
      if (parsed != null) return parsed;
    }

    // 2. Check metadata['entityId'] (often has 'YYYY-MM-DD')
    final d2 = widget.metadata['entityId']?.toString();
    if (d2 != null && d2.trim().isNotEmpty && d2.contains('-')) {
      final parsed = _tryParseAnyDate(d2);
      if (parsed != null) return parsed;
    }

    // 3. Check metadata['formattedDate'] (e.g. '28 Aug 2026')
    final d3 = widget.metadata['formattedDate']?.toString();
    if (d3 != null && d3.trim().isNotEmpty) {
      final parsed = _tryParseAnyDate(d3);
      if (parsed != null) return parsed;
    }

    // 4. Extract date directly from notification message text (e.g. "business summary for 28 Aug 2026")
    if (widget.message.isNotEmpty) {
      final dateMatch = RegExp(
        r'for\s+([0-9]{1,2}\s+[A-Za-z]{3,9}\s+[0-9]{4})',
        caseSensitive: false,
      ).firstMatch(widget.message);
      if (dateMatch != null && dateMatch.group(1) != null) {
        final parsed = _tryParseAnyDate(dateMatch.group(1)!);
        if (parsed != null) return parsed;
      }

      final isoMatch = RegExp(r'([0-9]{4}-[0-9]{2}-[0-9]{2})').firstMatch(widget.message);
      if (isoMatch != null && isoMatch.group(1) != null) {
        final parsed = _tryParseAnyDate(isoMatch.group(1)!);
        if (parsed != null) return parsed;
      }
    }

    // 5. Check metadata['timestamp'] or notification creation time
    final d5 = widget.metadata['timestamp']?.toString() ?? widget.metadata['createdAt']?.toString();
    if (d5 != null && d5.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(d5);
      if (parsed != null) return parsed.toLocal();
    }

    return DateTime.now();
  }

  DateTime? _tryParseAnyDate(String str) {
    final trimmed = str.trim();
    if (trimmed.isEmpty) return null;

    // Direct ISO / standard parser
    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct.toLocal();

    final patterns = [
      'dd MMM yyyy',
      'd MMM yyyy',
      'dd MMMM yyyy',
      'd MMMM yyyy',
      'dd-MM-yyyy',
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'yyyy/MM/dd',
    ];

    for (final p in patterns) {
      try {
        final parsed = DateFormat(p).parseLoose(trimmed);
        return parsed;
      } catch (_) {}
    }

    return null;
  }

  void _initData() {
    _totalSales = (widget.metadata['totalSales'] as num?)?.toDouble() ?? 0.0;
    _ordersCount = (widget.metadata['ordersCount'] as num?)?.toInt() ?? 0;
    _formattedDate = DateFormat('dd MMM yyyy').format(_targetDate);

    // If totalSales or ordersCount were not in metadata, extract them from the notification message text
    if (_totalSales == 0 && widget.message.isNotEmpty) {
      final salesMatch = RegExp(
        r'Total Sales\s+₹?\s*([0-9,]+(?:\.[0-9]+)?)',
        caseSensitive: false,
      ).firstMatch(widget.message);
      if (salesMatch != null && salesMatch.group(1) != null) {
        final cleanStr = salesMatch.group(1)!.replaceAll(',', '');
        _totalSales = double.tryParse(cleanStr) ?? 0.0;
      }
    }

    if (_ordersCount == 0 && widget.message.isNotEmpty) {
      final countMatch = RegExp(
        r'from\s+([0-9]+)\s+order',
        caseSensitive: false,
      ).firstMatch(widget.message);
      if (countMatch != null && countMatch.group(1) != null) {
        _ordersCount = int.tryParse(countMatch.group(1)!) ?? 0;
      }
    }

    // 1. Load orders directly from notification metadata if available
    final rawOrders = widget.metadata['orders'];
    if (rawOrders is List && rawOrders.isNotEmpty) {
      for (final item in rawOrders) {
        if (item is Map) {
          _displayOrders.add(Map<String, dynamic>.from(item));
        }
      }
    }

    // 2. Fetch all matching orders for the mentioned target date from DB & API
    _loadOrdersForMentionedDate();
  }

  Future<void> _loadOrdersForMentionedDate() async {
    setState(() => _isLoading = true);

    final seenOrderNumbers = _displayOrders.map((o) => o['orderNumber']?.toString()).toSet();

    // A. Check local database orders matching the exact target date (year, month, day) in local time
    try {
      final allDbOrders = DatabaseService().orders;
      final matchingOrders = allDbOrders.where((ord) {
        final rawDt = DateTime.tryParse(ord.createdAt) ?? ord.createdDateTime;
        final ordDate = rawDt.toLocal();
        final isSameDate = ordDate.year == _targetDate.year &&
            ordDate.month == _targetDate.month &&
            ordDate.day == _targetDate.day;
        final isCompleted = ord.status == OrderStatus.completed || ord.isPaid;
        return isSameDate && isCompleted;
      }).toList();

      for (final ord in matchingOrders) {
        final numStr = ord.orderNumber.toString();
        if (!seenOrderNumbers.contains(numStr)) {
          seenOrderNumbers.add(numStr);
          _displayOrders.add({
            'id': ord.id,
            'orderNumber': ord.orderNumber,
            'totalAmount': ord.totalAmount,
            'orderType': ord.orderType.name,
            'paymentMethod': ord.paymentMethod.isNotEmpty ? ord.paymentMethod : 'Paid',
            'createdAt': ord.createdAt,
            'customerName': ord.customerName ?? '',
            'itemsCount': ord.items.length,
          });
        }
      }
    } catch (_) {}

    // B. Fetch live from Sales Report & Sales API for the mentioned target date
    try {
      final dateIso = DateFormat('yyyy-MM-dd').format(_targetDate);
      final reportData = await _reportService.fetchSalesReport(
        startDate: dateIso,
        endDate: dateIso,
        limit: 300,
      );

      if (reportData.orders.isNotEmpty) {
        for (final ord in reportData.orders) {
          final numStr = ord.orderNumber.toString();
          if (!seenOrderNumbers.contains(numStr)) {
            seenOrderNumbers.add(numStr);
            _displayOrders.add({
              'id': ord.id,
              'orderNumber': ord.orderNumber,
              'totalAmount': ord.totalAmount,
              'orderType': ord.orderType.name,
              'paymentMethod': ord.paymentMethod.isNotEmpty ? ord.paymentMethod : 'Paid',
              'createdAt': ord.createdAt,
              'customerName': ord.customerName ?? '',
              'itemsCount': ord.items.length,
            });
          }
        }
      }

      // Secondary fallback to sales endpoint if needed
      if (_displayOrders.isEmpty) {
        final salesList = await _reportService.fetchSales(
          startDate: dateIso,
          endDate: dateIso,
          limit: 300,
        );
        for (final ord in salesList) {
          final numStr = ord.orderNumber.toString();
          if (!seenOrderNumbers.contains(numStr)) {
            seenOrderNumbers.add(numStr);
            _displayOrders.add({
              'id': ord.id,
              'orderNumber': ord.orderNumber,
              'totalAmount': ord.totalAmount,
              'orderType': ord.orderType.name,
              'paymentMethod': ord.paymentMethod.isNotEmpty ? ord.paymentMethod : 'Paid',
              'createdAt': ord.createdAt,
              'customerName': ord.customerName ?? '',
              'itemsCount': ord.items.length,
            });
          }
        }
      }

      if (_totalSales == 0 && reportData.summary.totalRevenue > 0) {
        _totalSales = reportData.summary.totalRevenue;
      }
    } catch (e) {
      debugPrint('[DailyBusinessSummaryDialog] API fetch notice: $e');
    }

    _computeMetrics();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _computeMetrics() {
    if (_displayOrders.isNotEmpty) {
      // Sort orders descending by time
      _displayOrders.sort((a, b) {
        final dtA = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime(2000);
        final dtB = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime(2000);
        return dtB.compareTo(dtA);
      });

      final calculatedSum = _displayOrders.fold<double>(
        0.0,
        (sum, ord) => sum + ((ord['totalAmount'] as num?)?.toDouble() ?? 0.0),
      );
      if (_totalSales == 0 || calculatedSum > _totalSales) {
        _totalSales = calculatedSum;
      }
      if (_displayOrders.length > _ordersCount) {
        _ordersCount = _displayOrders.length;
      }
    }
    _avgOrderValue = _ordersCount > 0 ? (_totalSales / _ordersCount) : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    const primaryNavy = Color(0xFF082559);
    final maxHeight = MediaQuery.of(context).size.height * 0.76;
    final totalOrdersDisplayCount = _ordersCount > 0 ? _ordersCount : _displayOrders.length;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 28,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Header with Mentioned Date & Quick Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: primaryNavy.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bar_chart_rounded, color: primaryNavy, size: 16),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Business Summary',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                _formattedDate,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: primaryNavy,
                                ),
                              ),
                              if (totalOrdersDisplayCount > 0) ...[
                                Text(
                                  ' • $totalOrdersDisplayCount Orders',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
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
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: primaryNavy),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 12),

          // KPI Cards Grid (Total Sales with Price, Total Orders, Avg Value) for Mentioned Date
          Row(
            children: [
              _buildKpiCard(
                title: 'Total Sales',
                value: '₹${_totalSales.toStringAsFixed(0)}',
                color: const Color(0xFF10B981),
                icon: Icons.payments_outlined,
              ),
              const SizedBox(width: 5),
              _buildKpiCard(
                title: 'Total Orders',
                value: '$totalOrdersDisplayCount',
                color: primaryNavy,
                icon: Icons.receipt_long_outlined,
              ),
              const SizedBox(width: 5),
              _buildKpiCard(
                title: 'Avg. Order',
                value: '₹${_avgOrderValue.toStringAsFixed(0)}',
                color: const Color(0xFF0284C7),
                icon: Icons.trending_up_rounded,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Section Title: Total Orders with Price & Mentioned Date
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_outlined, size: 13, color: primaryNavy),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Total Orders with Price • $_formattedDate ($totalOrdersDisplayCount)',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_displayOrders.isNotEmpty)
                  const Text(
                    'Tap order for details',
                    style: TextStyle(
                      fontSize: 8.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),

          // Orders List with Order No & Price for the Mentioned Date
          Expanded(
            child: _displayOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.receipt_outlined, color: Color(0xFF94A3B8), size: 22),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          totalOrdersDisplayCount > 0
                              ? '$totalOrdersDisplayCount completed orders on $_formattedDate'
                              : 'No completed orders found for $_formattedDate',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _displayOrders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 5),
                    itemBuilder: (context, idx) {
                      final ord = _displayOrders[idx];
                      final orderNum = ord['orderNumber']?.toString() ?? '${idx + 1}';
                      final amt = (ord['totalAmount'] as num?)?.toDouble() ?? 0.0;
                      final type = ord['orderType']?.toString() ?? 'Dine-In';
                      final method = ord['paymentMethod']?.toString() ?? 'Paid';
                      final customerName = ord['customerName']?.toString() ?? '';

                      String timeStr = '';
                      if (ord['createdAt'] != null) {
                        final dt = DateTime.tryParse(ord['createdAt'].toString())?.toLocal();
                        if (dt != null) {
                          timeStr = DateFormat('hh:mm a').format(dt);
                        }
                      }

                      return InkWell(
                        onTap: () {
                          OrderDetailSheet.show(
                            context,
                            orderId: ord['id']?.toString(),
                            orderNumber: ord['orderNumber']?.toString(),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: primaryNavy.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Center(
                                  child: Icon(Icons.receipt_long_rounded, color: primaryNavy, size: 14),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Order No & Time
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Order #$orderNum',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF0F172A),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (timeStr.isNotEmpty) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            '• $timeStr',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        _buildBadge(type, const Color(0xFF0284C7)),
                                        const SizedBox(width: 3),
                                        _buildBadge(method, const Color(0xFF16A34A)),
                                        if (customerName.isNotEmpty) ...[
                                          const SizedBox(width: 3),
                                          Expanded(
                                            child: Text(
                                              customerName,
                                              style: const TextStyle(
                                                fontSize: 8.5,
                                                color: Color(0xFF64748B),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Price Section
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${amt.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: primaryNavy,
                                    ),
                                  ),
                                  const Text(
                                    'Completed',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 6),

          // Bottom Action: View Full Sales Report
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 7),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReportsScreen()),
                );
              },
              icon: const Icon(Icons.analytics_outlined, size: 13),
              label: const Text(
                'View Detailed Sales Report',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 10),
                const SizedBox(width: 2.5),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 8.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
