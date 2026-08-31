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
  String _selectedPaymentStatus = 'All';
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

  final List<String> _paymentStatusOptions = [
    'All',
    'Paid',
    'Pending',
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

      final logs = await _printLogService.fetchPrintLogs(
        period: _selectedPeriod == 'Custom Date' ? null : _selectedPeriod,
        startDate: startDate,
        endDate: endDate,
        paymentStatus: _selectedPaymentStatus == 'All' ? null : _selectedPaymentStatus,
        search: _searchQuery.trim().isNotEmpty ? _searchQuery.trim() : null,
      );

      if (mounted) {
        setState(() {
          _printLogs = logs;
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
        title: const Text(
          'Print Logs & Invoices',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                    hintText: 'Search Order #, Customer, Table, Invoice...',
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
                const SizedBox(height: 12),

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
                const SizedBox(height: 8),

                // Status Filter Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text(
                        'Payment: ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                      ..._paymentStatusOptions.map((status) {
                        final isSelected = _selectedPaymentStatus == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(
                              status,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF051C48) : const Color(0xFF64748B),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 11.5,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: const Color(0xFF051C48).withOpacity(0.12),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isSelected ? const Color(0xFF051C48) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            onSelected: (selected) {
                              setState(() => _selectedPaymentStatus = status);
                              _loadPrintLogs();
                            },
                          ),
                        );
                      }),
                    ],
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
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'No print logs found',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Save & Print operations will be snapshot and logged here.',
                                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFF051C48),
                            onRefresh: _loadPrintLogs,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
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

  Widget _buildPrintLogCard(PrintLogModel log, String currency) {
    final isPaid = log.isPaid;
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(log.createdDateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Order # + Version Badge + Payment Status
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '#${log.orderNumber}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: log.isReprint
                              ? const Color(0xFFEDE9FE)
                              : const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: log.isReprint
                                ? const Color(0xFF8B5CF6)
                                : const Color(0xFF6366F1),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          log.isReprint ? 'REPRINT #${log.printNumber}' : 'COPY #${log.printNumber}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: log.isReprint ? const Color(0xFF6D28D9) : const Color(0xFF4338CA),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                    ),
                  ),
                  child: Text(
                    isPaid ? 'PAID' : 'UNPAID / RUNNING',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isPaid ? const Color(0xFF166534) : const Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),
            // Timestamp & Table Info
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                if (log.tableNumber != null && log.tableNumber!.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF051C48).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Table ${log.tableNumber}',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF051C48)),
                    ),
                  ),
                ],
              ],
            ),

            if (log.customerName != null && log.customerName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Customer: ${log.customerName}${log.customerPhone != null && log.customerPhone!.isNotEmpty ? " (${log.customerPhone})" : ""}',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
              ),
            ],

            const SizedBox(height: 10),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 10),

            // Items Snapshot Snippet
            Text(
              'Snapshot Items (${log.items.length}):',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            ...log.items.take(3).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${item.quantity}x ${item.name}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$currency${item.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )),
            if (log.items.length > 3)
              Text(
                '+ ${log.items.length - 3} more items in snapshot',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
              ),

            const SizedBox(height: 10),
            const Divider(color: Color(0xFFF1F5F9), height: 1),
            const SizedBox(height: 10),

            // Total Amount & Action Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Snapshot Total', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                    Text(
                      '$currency${log.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF051C48),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // View Invoice Button
                    OutlinedButton.icon(
                      onPressed: () {
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
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 14, color: Color(0xFF051C48)),
                      label: const Text(
                        'View Invoice',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF051C48)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF051C48), width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Reprint Button
                    ElevatedButton.icon(
                      onPressed: () => _handleReprint(log),
                      icon: const Icon(Icons.print_rounded, size: 14, color: Colors.white),
                      label: const Text(
                        'Reprint',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF051C48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
