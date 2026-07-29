import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';

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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: SingleChildScrollView(
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: 24,
            blurStrength: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              // Receipt Container styled like a modern glass thermal slip
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D111A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: GlassTheme.primaryCyan.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: GlassTheme.primaryCyan.withOpacity(0.15),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline, color: GlassTheme.accentNeonGreen, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      rest?.name ?? 'Apna POS Diner',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      rest?.tagline ?? 'Tasty Food & Quick Service',
                      style: const TextStyle(fontSize: 11, color: GlassTheme.textMedium),
                    ),
                    Text(
                      rest?.address ?? 'Connaught Place, New Delhi',
                      style: const TextStyle(fontSize: 10, color: GlassTheme.textLow),
                    ),
                    Text(
                      'Ph: ${rest?.phone ?? "+91 98765 43210"}',
                      style: const TextStyle(fontSize: 10, color: GlassTheme.textLow),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: GlassTheme.glassBorder),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Order: ${order.orderNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Time: ${order.createdAt}', style: const TextStyle(color: GlassTheme.textMedium, fontSize: 12)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Table: ${order.tableNumber ?? "Takeaway"}', style: const TextStyle(color: GlassTheme.primaryCyan, fontSize: 12)),
                        Text('Mode: ${order.paymentMethod}', style: const TextStyle(color: GlassTheme.accentAmber, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: GlassTheme.glassBorder),
                    const SizedBox(height: 6),

                    // Items
                    ...order.items.map((cartItem) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text('${cartItem.quantity}x ', style: const TextStyle(color: GlassTheme.primaryCyan, fontWeight: FontWeight.bold, fontSize: 13)),
                            Expanded(
                              child: Text(
                                cartItem.item.name,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$currency${cartItem.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 10),
                    const Divider(color: GlassTheme.glassBorder),
                    const SizedBox(height: 6),

                    _buildAmountRow('Subtotal', '$currency${order.subtotal.toStringAsFixed(2)}'),
                    if (order.discountAmount > 0)
                      _buildAmountRow('Discount', '-$currency${order.discountAmount.toStringAsFixed(2)}', color: GlassTheme.accentRose),
                    _buildAmountRow('GST Tax (${rest?.taxRate ?? 5.0}%)', '$currency${order.taxAmount.toStringAsFixed(2)}'),

                    const SizedBox(height: 6),
                    const Divider(color: GlassTheme.glassBorder),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('GRAND TOTAL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          '$currency${order.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(color: GlassTheme.accentNeonGreen, fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Thank you for dining with us!',
                      style: TextStyle(color: GlassTheme.textMedium, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      label: 'Simulate Thermal Print',
                      icon: Icons.print_rounded,
                      isSecondary: true,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Receipt sent to Thermal Receipt Printer!')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassButton(
                      label: 'Done',
                      icon: Icons.check_rounded,
                      onPressed: () => Navigator.pop(context),
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
}

  Widget _buildAmountRow(String label, String val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: GlassTheme.textMedium, fontSize: 12)),
          Text(val, style: TextStyle(color: color ?? Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
