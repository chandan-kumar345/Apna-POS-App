import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/order_model.dart';
import '../../core/database/database_service.dart';
import '../../core/services/bluetooth_printer_service.dart';

class KotDialog extends StatelessWidget {
  final OrderModel order;
  final String? restaurantName;
  final VoidCallback? onPrintKot;

  const KotDialog({
    super.key,
    required this.order,
    this.restaurantName,
    this.onPrintKot,
  });

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final resName = restaurantName ?? db.restaurant?.name ?? 'Loyalty Restaurant';

    // Format Date & Time matching reference UI: 04-08-2026,06:45:55 pm
    final dt = DateTime.tryParse(order.createdAt) ?? DateTime.now();
    final formattedDateTime = DateFormat('dd-MM-yyyy,hh:mm:ss a').format(dt).toLowerCase();

    // Table / Order Type Title
    final orderTypeTitle = order.orderType == OrderType.dineIn
        ? 'DineIn'
        : order.orderType == OrderType.takeaway
            ? 'Takeaway'
            : 'Delivery';

    final tableTitle = order.orderType == OrderType.dineIn
        ? (order.tableNumber != null && order.tableNumber!.isNotEmpty
            ? (order.tableNumber!.toLowerCase().startsWith('table')
                ? 'Dine In-${order.tableNumber}'
                : 'Dine In-Table ${order.tableNumber!.replaceAll(RegExp(r'[^0-9]'), '').padLeft(2, '0')}')
            : 'Dine In-Table 06')
        : 'Takeaway';

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
            const Text(
              'KOT',
              style: TextStyle(
                fontSize: 22,
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
                fontSize: 18,
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
            ...order.items.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final item = entry.value;
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
                      '${item.quantity}',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF4A5568)),
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
                      onPressed: () async {
                        if (onPrintKot != null) {
                          onPrintKot!();
                        }
                        
                        final printerService = BluetoothPrinterService();
                        final bool isConnected = await printerService.isConnected();
                        if (isConnected) {
                          await printerService.printKOT(order: order, restaurant: db.restaurant);
                        } else {
                          final bool reconnected = await printerService.autoConnectSavedPrinter();
                          if (reconnected) {
                            await printerService.printKOT(order: order, restaurant: db.restaurant);
                          }
                        }

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('KOT Printed via Thermal Printer & Table updated!'),
                            backgroundColor: Color(0xFF051C48),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF051C48),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Print KOT',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
