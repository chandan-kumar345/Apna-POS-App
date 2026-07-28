import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/database/database_service.dart';
import '../../core/models/order_model.dart';

class KdsScreen extends StatefulWidget {
  const KdsScreen({super.key});

  @override
  State<KdsScreen> createState() => _KdsScreenState();
}

class _KdsScreenState extends State<KdsScreen> {
  final db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final pendingOrders = db.orders.where((o) => o.status == OrderStatus.pending).toList();
    final preparingOrders = db.orders.where((o) => o.status == OrderStatus.preparing).toList();
    final readyOrders = db.orders.where((o) => o.status == OrderStatus.ready).toList();

    return SafeArea(
      child: LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;

        Widget content = Row(
          children: [
            SizedBox(
              width: isNarrow ? 280 : (constraints.maxWidth - 28) / 3,
              child: _buildKotColumn('NEW ORDERS', pendingOrders, GlassTheme.accentAmber, OrderStatus.preparing, 'Start Cooking'),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: isNarrow ? 280 : (constraints.maxWidth - 28) / 3,
              child: _buildKotColumn('PREPARING', preparingOrders, GlassTheme.primaryCyan, OrderStatus.ready, 'Mark Dish Ready'),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: isNarrow ? 280 : (constraints.maxWidth - 28) / 3,
              child: _buildKotColumn('READY FOR SERVE', readyOrders, GlassTheme.accentNeonGreen, OrderStatus.completed, 'Complete / Served'),
            ),
          ],
        );

        if (isNarrow) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: content,
          );
        }

        return content;
      },
    ),
  );
}

  Widget _buildKotColumn(String header, List<OrderModel> list, Color themeColor, OrderStatus nextStatus, String actionText) {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      borderRadius: 20,
      blurStrength: 16,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                header,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: themeColor, letterSpacing: 0.5),
              ),
              GlassBadge(
                label: '${list.length}',
                color: themeColor,
                fontSize: 11,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: GlassTheme.glassBorder, height: 1),
          const SizedBox(height: 10),

          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, color: themeColor.withOpacity(0.5), size: 32),
                        const SizedBox(height: 6),
                        Text('No orders in $header', style: const TextStyle(color: GlassTheme.textMedium, fontSize: 11)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, idx) {
                      final order = list[idx];
                      return _buildKotTicketCard(order, themeColor, nextStatus, actionText);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKotTicketCard(OrderModel order, Color themeColor, OrderStatus nextStatus, String actionText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderColor: themeColor.withOpacity(0.6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.orderNumber,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                GlassBadge(
                  label: order.tableNumber ?? 'Takeaway',
                  color: themeColor,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Placed: ${order.createdAt}',
                  style: const TextStyle(color: GlassTheme.textMedium, fontSize: 10),
                ),
                Text(
                  order.orderType.name.toUpperCase(),
                  style: const TextStyle(color: GlassTheme.primaryCyan, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: GlassTheme.glassBorder, height: 1),
            const SizedBox(height: 6),

            ...order.items.map((cartItem) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${cartItem.quantity}x',
                        style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cartItem.item.name,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),

            GlassButton(
              label: actionText,
              icon: Icons.fast_forward_rounded,
              color: themeColor,
              height: 36,
              onPressed: () {
                db.updateOrderStatus(order.id, nextStatus);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }
}
