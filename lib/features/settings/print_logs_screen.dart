import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_service.dart';
import '../../core/models/print_log_model.dart';
import '../../core/services/print_log_service.dart';
import '../../core/services/bluetooth_printer_service.dart';
import '../pos/receipt_dialog.dart';

class PrintLogsScreen extends StatefulWidget {
  const PrintLogsScreen({super.key});

  @override
  State<PrintLogsScreen> createState() => _PrintLogsScreenState();
}

class _PrintLogsScreenState extends State<PrintLogsScreen> {
  final DatabaseService _db = DatabaseService();
  final PrintLogService _printLogService = PrintLogService();

  String _selectedPeriod = 'All Time';
  String _searchQuery = '';
  DateTimeRange? _customDateRange;

  bool _isLoading = true;
  String? _errorMessage;
  List<PrintLogModel> _printLogs = [];

  final List<String> _periodOptions = [
    'All Time',
    'Today',
    'Yesterday',
    'This Week',
    'This Month',
    'Custom Date',
  ];

  @override
  void initState() {
    super.initState();
    _loadPrintLogs();
  }

  Future<void> _loadPrintLogs() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? startDate;
      String? endDate;

      if (_selectedPeriod == 'Custom Date' && _customDateRange != null) {
        startDate = _customDateRange!.start.toIso8601String();
        endDate = _customDateRange!.end.toIso8601String();
      }

      // Strictly fetch clear_cart logs
      final logs = await _printLogService.fetchPrintLogs(
        period: _selectedPeriod == 'Custom Date' ? null : _selectedPeriod,
        startDate: startDate,
        endDate: endDate,
        printType: 'clear_cart',
        search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
      );

      // Strictly ensure only cleared cart / voided logs are displayed
      final clearCartOnly = logs.where((l) =>
        l.isClearCart ||
        l.printType == 'clear_cart' ||
        l.orderStatus == 'cancelled' ||
        l.paymentStatus == 'voided'
      ).toList();

      if (mounted) {
        setState(() {
          _printLogs = clearCartOnly;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load print logs: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF051C48),
              onPrimary: Colors.white,
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
        _selectedPeriod = 'Custom Date';
      });
      _loadPrintLogs();
    }
  }

  Future<void> _handleReprint(PrintLogModel log) async {
    final currency = _db.restaurant?.currencySymbol ?? '₹';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sending reprint to Bluetooth Thermal Printer...'),
        backgroundColor: Color(0xFF051C48),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final orderSnapshot = log.toOrderModel();
      final printerService = BluetoothPrinterService();
      final rest = _db.restaurant;

      final success = await printerService.printBill(
        order: orderSnapshot,
        restaurant: rest,
        user: _db.currentUser,
        currency: currency,
      );

      // Record reprint on backend
      await _printLogService.reprintLog(log.id);

      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reprint completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not print. Please check Bluetooth printer connection.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      _loadPrintLogs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reprint failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = _db.restaurant?.currencySymbol ?? '₹';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Print Logs',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            Text(
              'Cleared Cart & Voided Order History',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF051C48)),
            onPressed: _loadPrintLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Search Header Card
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                TextField(
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _loadPrintLogs();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search Order #, Customer, Table, Staff...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Period Filter Pills Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _periodOptions.map((period) {
                      final isSelected = _selectedPeriod == period;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            period == 'Custom Date' && _customDateRange != null
                                ? '${DateFormat('dd MMM').format(_customDateRange!.start)} - ${DateFormat('dd MMM').format(_customDateRange!.end)}'
                                : period,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF051C48),
                          backgroundColor: const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          onSelected: (selected) {
                            if (period == 'Custom Date') {
                              _pickCustomDateRange();
                            } else {
                              setState(() {
                                _selectedPeriod = period;
                                _customDateRange = null;
                              });
                              _loadPrintLogs();
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Print Logs List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF051C48)),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                            const SizedBox(height: 12),
                            Text(_errorMessage!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadPrintLogs,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF051C48)),
                              child: const Text('Retry', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : _printLogs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.remove_shopping_cart_outlined, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No cleared cart logs found',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'When a table cart with active running KOT is cleared via Manager Security PIN, the audit snapshot will appear here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF051C48),
                            onRefresh: _loadPrintLogs,
                            child: ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              itemCount: _printLogs.length,
                              itemBuilder: (context, index) {
                                final log = _printLogs[index];
                                return _buildPrintLogCard(log, currency);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  /// Print Log Card matching EXACT My Orders Screen Card styling & layout
  Widget _buildPrintLogCard(PrintLogModel log, String currency) {
    final isPaid = log.isPaid;
    final isClear = log.isClearCart;
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(log.createdDateTime);

    // Status styling matching My Orders screen
    Color statusColor;
    String statusLabel;

    if (isClear) {
      statusColor = const Color(0xFFEF4444);
      statusLabel = 'Cart Cleared';
    } else if (log.orderStatus == 'completed') {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'Completed';
    } else if (log.orderStatus == 'preparing') {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Preparing';
    } else {
      statusColor = const Color(0xFF051C48);
      statusLabel = log.orderStatus.toUpperCase();
    }

    final orderTypeLabel = log.orderType == 'takeaway'
        ? 'TakeAway'
        : (log.orderType == 'delivery' ? 'Delivery' : 'Dine-In');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isClear ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
          width: isClear ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header: Order # + Type Badge + Print/Clear Badge + Payment Badge + Status Badge
          Row(
            children: [
              Flexible(
                child: Text(
                  '#${log.orderNumber}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),

              // Order Type Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF051C48).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFF051C48).withValues(alpha: 0.2)),
                ),
                child: Text(
                  '$orderTypeLabel${log.tableNumber != null && log.tableNumber!.isNotEmpty ? " (${log.tableNumber})" : ""}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF051C48)),
                ),
              ),
              const SizedBox(width: 4),

              // Print Version / Clear Badge
              if (isClear)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
                  ),
                  child: const Text(
                    'VOIDED',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: log.isReprint
                        ? const Color(0xFFEDE9FE)
                        : const Color(0xFF051C48).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: log.isReprint
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFF051C48).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    log.isReprint ? 'R#${log.printNumber}' : 'P#${log.printNumber}',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: log.isReprint ? const Color(0xFF6D28D9) : const Color(0xFF051C48),
                    ),
                  ),
                ),

              const Spacer(),

              // Payment Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isClear
                      ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                      : (isPaid
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: isClear
                        ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                        : (isPaid
                            ? const Color(0xFF10B981).withValues(alpha: 0.4)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                  ),
                ),
                child: Text(
                  isClear ? 'VOIDED' : (isPaid ? 'PAID' : 'UNPAID'),
                  style: TextStyle(
                    color: isClear
                        ? const Color(0xFFDC2626)
                        : (isPaid ? const Color(0xFF10B981) : const Color(0xFFD97706)),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Date & Audit Details Row
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              if (log.customerName != null && log.customerName!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '• ${log.customerName}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),

          if (isClear && log.notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.shield_outlined, size: 12, color: Color(0xFFDC2626)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    log.notes,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 8),

          // 2. Items List Snapshot (Identical to My Orders screen)
          ...log.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Text(
                      '${item.quantity}×',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF051C48),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$currency ${item.totalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 8),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 8),

          // 3. Footer: Total & Actions
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isClear ? 'Cleared Total' : 'Total',
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                  ),
                  Text(
                    '$currency ${log.totalAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: isClear ? const Color(0xFFDC2626) : const Color(0xFF051C48),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // View Invoice Button
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    useRootNavigator: true,
                    barrierDismissible: true,
                    builder: (_) => ReceiptDialog(
                      order: log.toOrderModel(),
                      currency: currency,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 29,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF051C48).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF051C48).withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.remove_red_eye_outlined, size: 12, color: Color(0xFF051C48)),
                      const SizedBox(width: 4),
                      Text(
                        isClear ? 'Snapshot' : 'Invoice',
                        style: const TextStyle(color: Color(0xFF051C48), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

              if (!isClear) ...[
                const SizedBox(width: 6),
                // Reprint Button
                InkWell(
                  onTap: () => _handleReprint(log),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 29,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF051C48),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.print_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Reprint',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

