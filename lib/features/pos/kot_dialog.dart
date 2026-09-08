import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/order_model.dart';
import '../../core/database/database_service.dart';
import '../../core/services/bluetooth_printer_service.dart';

class KotDialog extends StatefulWidget {
  final OrderModel order;
  final String? restaurantName;
  final Future<void> Function(OrderModel updatedOrder)? onPrintKot;
  final VoidCallback? onLegacyPrintKot;
  final bool isReprint;

  const KotDialog({
    super.key,
    required this.order,
    this.restaurantName,
    this.onPrintKot,
    this.onLegacyPrintKot,
    this.isReprint = false,
  });

  @override
  State<KotDialog> createState() => _KotDialogState();
}

class _KotDialogState extends State<KotDialog> {
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final resName = widget.restaurantName ?? db.restaurant?.name ?? 'Loyalty Restaurant';

    // Format Date & Time matching reference UI: 04-08-2026,06:45:55 pm
    final dt = DateTime.tryParse(widget.order.createdAt) ?? DateTime.now();
    final formattedDateTime = DateFormat('dd-MM-yyyy,hh:mm:ss a').format(dt).toLowerCase();

    // Table / Order Type Title
    final orderTypeTitle = widget.order.orderType == OrderType.dineIn
        ? 'DineIn'
        : widget.order.orderType == OrderType.takeaway
            ? 'Takeaway'
            : 'Delivery';

    final tableTitle = widget.order.orderType == OrderType.dineIn
        ? (widget.order.tableNumber != null && widget.order.tableNumber!.isNotEmpty
            ? (widget.order.tableNumber!.toLowerCase().startsWith('table')
                ? 'Dine In-${widget.order.tableNumber}'
                : 'Dine In-Table ${widget.order.tableNumber!.replaceAll(RegExp(r'[^0-9]'), '').padLeft(2, '0')}')
            : 'Dine In-Table 06')
        : 'Takeaway';

    // Resolve items to show (Pending delta items or full items list)
    final pendingItems = widget.order.items.where((i) => i.pendingKotQuantity > 0).toList();
    final bool showDeltaOnly = !widget.isReprint && pendingItems.isNotEmpty;
    final List<CartItemModel> displayItems = showDeltaOnly ? pendingItems : widget.order.items;

    final String titleHeader = widget.isReprint
        ? 'KOT (REPRINT)'
        : (showDeltaOnly && widget.order.items.any((i) => i.kotQuantity > 0) ? 'KOT (ADD-ON)' : 'KOT');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title Header: KOT
              Text(
                titleHeader,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2D3748),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),

              // Restaurant Name
              Text(
                resName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A5568),
                ),
              ),
              const SizedBox(height: 4),

              // Order Type (DineIn)
              Text(
                orderTypeTitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF718096),
                ),
              ),
              const SizedBox(height: 2),

              // Table info (Dine In-Table 06)
              Text(
                tableTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF4A5568),
                ),
              ),
              const SizedBox(height: 2),

              // Date & Time (04-08-2026,06:45:55 pm)
              Text(
                formattedDateTime,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF718096),
                ),
              ),
              const SizedBox(height: 12),

              const Divider(color: Color(0xFFE2E8F0), thickness: 1, height: 1),
              const SizedBox(height: 8),

              // Table Header: Sn | Items | Qty
              Row(
                children: const [
                  SizedBox(
                    width: 24,
                    child: Text(
                      'Sn',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Items',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                    ),
                  ),
                  Text(
                    'Qty',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: Color(0xFFE2E8F0), thickness: 1, height: 1),
              const SizedBox(height: 8),

              // Dynamic Items List
              ...displayItems.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final item = entry.value;

                String displayQty;
                if (widget.isReprint) {
                  displayQty = '${item.quantity}';
                } else if (item.kotQuantity > 0 && item.pendingKotQuantity > 0) {
                  displayQty = '+${item.pendingKotQuantity}';
                } else if (item.pendingKotQuantity > 0) {
                  displayQty = '${item.pendingKotQuantity}';
                } else {
                  displayQty = '${item.quantity}';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$idx',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4A5568)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.item.name,
                          style: const TextStyle(fontSize: 14, color: Color(0xFF4A5568)),
                        ),
                      ),
                      Text(
                        displayQty,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4A5568)),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 12),
              const Divider(color: Color(0xFFE2E8F0), thickness: 1, height: 1),
              const SizedBox(height: 12),

              // Thank you message
              const Text(
                'Thank you for dining with us!',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF718096),
                ),
              ),
              const SizedBox(height: 18),

              // Action Buttons: Print KOT | Close (App Theme #051C48 Pill Buttons)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _isPrinting
                            ? null
                            : () async {
                                setState(() => _isPrinting = true);
                                try {
                                  // 1. Mark all quantities as sent (kotQuantity = quantity)
                                  final updatedItems = widget.order.items.map((i) {
                                    return i.copyWith(kotQuantity: i.quantity);
                                  }).toList();

                                  final updatedOrder = widget.order.copyWith(
                                    items: updatedItems,
                                    status: OrderStatus.preparing,
                                  );

                                  // 2. ALWAYS perform the order & table status update to Running KOT
                                  if (widget.onPrintKot != null) {
                                    await widget.onPrintKot!(updatedOrder);
                                  } else if (widget.onLegacyPrintKot != null) {
                                    widget.onLegacyPrintKot!();
                                  }

                                  // 3. Attempt thermal printer output if printer is available (non-blocking)
                                  bool printedSuccessfully = false;
                                  try {
                                    final printerService = BluetoothPrinterService();
                                    bool isConnected = await printerService.isConnected();
                                    if (!isConnected) {
                                      isConnected = await printerService.autoConnectSavedPrinter();
                                    }

                                    if (isConnected) {
                                      printedSuccessfully = await printerService.printKOT(
                                        order: widget.order,
                                        restaurant: db.restaurant,
                                        isReprint: widget.isReprint || pendingItems.isEmpty,
                                        customItemsToPrint: displayItems,
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint('Thermal KOT printer non-blocking error: $e');
                                  }

                                  if (!context.mounted) return;

                                  if (printedSuccessfully) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('KOT Printed via Thermal Printer & Table set to Running KOT!'),
                                        backgroundColor: Color(0xFF051C48),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Running KOT created & Table updated!'),
                                        backgroundColor: Color(0xFF051C48),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }

                                  Navigator.pop(context, true);
                                } catch (e) {
                                  debugPrint('KOT error: $e');
                                } finally {
                                  if (mounted) setState(() => _isPrinting = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF051C48),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isPrinting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                widget.isReprint || pendingItems.isEmpty ? 'Reprint KOT' : 'Print KOT',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF051C48),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
    );
  }
}
