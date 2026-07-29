import 'package:flutter/material.dart';
import '../../core/models/order_model.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';

class KotDialog extends StatelessWidget {
  final OrderModel order;

  const KotDialog({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: 24,
            blurStrength: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1420),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: GlassTheme.accentAmber.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.soup_kitchen_rounded, color: GlassTheme.accentAmber, size: 36),
                      const SizedBox(height: 6),
                      const Text(
                        'KITCHEN ORDER TICKET (KOT)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: GlassTheme.accentAmber, letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Text('Order ${order.orderNumber}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text('Time: ${order.createdAt} • Table: ${order.tableNumber ?? "Takeaway"}', style: const TextStyle(fontSize: 11, color: GlassTheme.textMedium)),
                      if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Delivery: ${order.deliveryAddress}', style: const TextStyle(fontSize: 11, color: GlassTheme.primaryCyan, fontWeight: FontWeight.w500)),
                      ],
                      const SizedBox(height: 12),
                      const Divider(color: GlassTheme.glassBorder, height: 1),
                      const SizedBox(height: 10),

                      // Items list
                      ...order.items.map((cartItem) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: GlassTheme.accentAmber.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${cartItem.quantity}x',
                                  style: const TextStyle(color: GlassTheme.accentAmber, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  cartItem.item.name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 14),
                      const Divider(color: GlassTheme.glassBorder, height: 1),
                      const SizedBox(height: 8),
                      Text(
                        'Status: ${order.status.name.toUpperCase()}',
                        style: const TextStyle(color: GlassTheme.primaryCyan, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        label: 'Print KOT',
                        icon: Icons.print_rounded,
                        isSecondary: true,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('KOT sent to Kitchen Thermal Printer!')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassButton(
                        label: 'Close',
                        icon: Icons.check,
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
}
