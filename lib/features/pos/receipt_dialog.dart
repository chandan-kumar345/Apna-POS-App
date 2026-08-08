import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';
import '../../core/services/bluetooth_printer_service.dart';

class ReceiptDialog extends StatelessWidget {
  final OrderModel order;
  final String currency;

  const ReceiptDialog({
    super.key,
    required this.order,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService();
    final rest = db.restaurant;

    final String restName = rest?.name.isNotEmpty == true ? rest!.name : 'cafe de feasto';
    final String restAddress = rest?.address.isNotEmpty == true
        ? rest!.address
        : 'Dakshin Jagaddal, Narendrapur, Kolkata, West Bengal, India - 700149';
    final String restPhone = rest?.phone.isNotEmpty == true ? rest!.phone : '+91 7980614787';
    final String gstNumber = rest?.gstNumber.isNotEmpty == true ? rest!.gstNumber : '19FPYPD2539M1Z0';
    final double taxRate = rest?.taxRate ?? 5.0;
    final double cgstRate = taxRate / 2;
    final double sgstRate = taxRate / 2;
    final double cgstAmount = order.taxAmount / 2;
    final double sgstAmount = order.taxAmount / 2;

    // Build initials for circle logo
    final String initials = restName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(3).join('').toUpperCase();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Action Bar (Header with Print, Share & Close)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF051C48),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Thermal Bill Preview',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // Scrollable Thermal Paper Slip
            Flexible(
              child: Container(
                color: const Color(0xFFF1F5F9), // Light background behind slip
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: SingleChildScrollView(
                  child: Center(
                    child: Container(
                      width: 360, // Standard 80mm thermal slip preview width
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1. Logo Badge (Black circle with gold text style)
                          Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials.isNotEmpty ? initials : 'CDF',
                              style: const TextStyle(
                                color: Color(0xFFD4AF37), // Gold accent
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // 2. Restaurant Name
                          Text(
                            restName.toLowerCase(),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF000000),
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),

                          // Address & Phone
                          Text(
                            restAddress,
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF1E293B), height: 1.3),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mob: $restPhone',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),

                          // Order Type & Table
                          Text(
                            order.orderType == OrderType.dineIn
                                ? 'DineIn'
                                : (order.orderType == OrderType.takeaway ? 'Takeaway' : 'Delivery'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                          ),
                          if (order.tableNumber != null && order.tableNumber!.isNotEmpty)
                            Text(
                              'Dine In - Table ${order.tableNumber!.replaceAll('T-', '')}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                            ),
                          const SizedBox(height: 6),

                          // Customer Info
                          if (order.customerName != null && order.customerName!.isNotEmpty)
                            Text(
                              'Customer Name: ${order.customerName!.toUpperCase()}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                            ),
                          if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                            Text(
                              'Customer Mobile: ${order.customerPhone}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                            ),
                          const SizedBox(height: 4),

                          // Date & Time
                          Text(
                            order.createdAt.isNotEmpty ? order.createdAt : '07/08/2026 09:20:58 PM',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF000000)),
                          ),
                          const SizedBox(height: 6),

                          // Bill, Invoice, Order No & GST
                          Text('Bill: #${order.orderNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF000000))),
                          Text('Invoice: #INV-${order.orderNumber}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF000000))),
                          Text('Order No: #${order.id.isNotEmpty ? order.id : order.orderNumber}', style: const TextStyle(fontSize: 10, color: Color(0xFF000000))),
                          Text('GST: #$gstNumber', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF000000))),
                          const SizedBox(height: 6),

                          // Pay To line
                          Text('Pay To : $restName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF000000))),
                          const SizedBox(height: 8),

                          // Dashed Line Divider
                          _buildDashedLine(),
                          const SizedBox(height: 6),

                          // Header Columns
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('ITEM DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF000000))),
                              Text('TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF000000))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildDashedLine(),
                          const SizedBox(height: 8),

                          // Items List
                          ...order.items.map((cartItem) {
                            final double unitPrice = cartItem.item.price;
                            final double lineTotal = cartItem.totalPrice;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cartItem.item.name,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$currency${lineTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${cartItem.quantity} @ $currency${unitPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                                ),
                                const SizedBox(height: 6),
                                _buildDashedLine(),
                                const SizedBox(height: 6),
                              ],
                            );
                          }),

                          const SizedBox(height: 8),
                          _buildCenterLine(),
                          const SizedBox(height: 8),

                          // Gross Amount & Tax Breakdown
                          _buildReceiptRow('GROSS AMOUNT', '$currency${order.subtotal.toStringAsFixed(2)}', isBold: true),
                          const SizedBox(height: 4),
                          _buildReceiptRow('CGST (${cgstRate.toStringAsFixed(1)}%)', cgstAmount.toStringAsFixed(2)),
                          const SizedBox(height: 4),
                          _buildReceiptRow('SGST (${sgstRate.toStringAsFixed(1)}%)', sgstAmount.toStringAsFixed(2)),
                          if (order.discountAmount > 0) ...[
                            const SizedBox(height: 4),
                            _buildReceiptRow('DISCOUNT', '-$currency${order.discountAmount.toStringAsFixed(2)}'),
                          ],

                          const SizedBox(height: 8),
                          _buildCenterLine(),
                          const SizedBox(height: 8),

                          // Total Amount Section
                          _buildDashedLine(),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'TOTAL AMOUNT',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF000000)),
                              ),
                              Text(
                                '$currency${order.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF000000)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildDashedLine(),
                          const SizedBox(height: 14),

                          // Footer
                          const Text(
                            '*********************************',
                            style: TextStyle(fontSize: 10, color: Color(0xFF475569), letterSpacing: 1),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Need help? Contact us: $restPhone',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF000000)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Thank you for visiting',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF000000)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Powered by Apna POS',
                            style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Buttons (Print, Share, Done)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final printerService = BluetoothPrinterService();

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Printing Thermal Bill via Bluetooth...'),
                              backgroundColor: Color(0xFF051C48),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }

                        final rest = DatabaseService().restaurant;
                        final success = await printerService.printBill(
                          order: order,
                          restaurant: rest,
                          currency: currency,
                        );

                        if (!context.mounted) return;

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Bill printed successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not print bill. Check Bluetooth printer power & connection.'),
                              backgroundColor: Colors.redAccent,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.print_rounded, size: 18, color: Colors.white),
                      label: const Text('Print Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF051C48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bill summary copied / shared!'),
                            backgroundColor: Color(0xFF051C48),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF051C48)),
                      label: const Text('Share Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF051C48))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF051C48), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashedLine() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        const double dashWidth = 4;
        const double dashSpace = 3;
        final int count = (width / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(count, (_) {
            return SizedBox(
              width: dashWidth,
              height: 1,
              child: const DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFF94A3B8)),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildCenterLine() {
    return Center(
      child: Container(
        width: 160,
        height: 1,
        color: const Color(0xFF64748B),
      ),
    );
  }

  Widget _buildReceiptRow(String title, String val, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isBold ? 11.5 : 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: const Color(0xFF000000),
          ),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: isBold ? 11.5 : 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: const Color(0xFF000000),
          ),
        ),
      ],
    );
  }
}
