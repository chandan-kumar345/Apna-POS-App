import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/database/database_service.dart';
import '../pos/receipt_dialog.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final db = DatabaseService();

  @override
  Widget build(BuildContext context) {
    final currency = db.restaurant?.currencySymbol ?? '₹';

    final totalOrdersCount = db.orders.length;
    final totalRevenue = db.orders.fold(0.0, (sum, o) => sum + o.totalAmount);
    final avgOrderValue = totalOrdersCount > 0 ? (totalRevenue / totalOrdersCount) : 0.0;

    final upiTotal = db.orders.where((o) => o.paymentMethod == 'UPI').fold(0.0, (sum, o) => sum + o.totalAmount);
    final cashTotal = db.orders.where((o) => o.paymentMethod == 'Cash').fold(0.0, (sum, o) => sum + o.totalAmount);
    final cardTotal = db.orders.where((o) => o.paymentMethod == 'Card').fold(0.0, (sum, o) => sum + o.totalAmount);

    return SafeArea(
      child: Column(
      children: [
        // Top Metric Stat Cards (Scrollable to prevent overflow)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: 250,
                child: GlassStatCard(
                  title: 'Total Revenue Today',
                  value: '$currency${totalRevenue.toStringAsFixed(2)}',
                  subtitle: '+$totalOrdersCount Completed Orders',
                  icon: Icons.payments_rounded,
                  color: GlassTheme.accentNeonGreen,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 230,
                child: GlassStatCard(
                  title: 'Total Orders',
                  value: '$totalOrdersCount',
                  subtitle: 'Dine-In & Takeaway',
                  icon: Icons.receipt_rounded,
                  color: GlassTheme.primaryCyan,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 230,
                child: GlassStatCard(
                  title: 'Average Order Value',
                  value: '$currency${avgOrderValue.toStringAsFixed(2)}',
                  subtitle: 'Per Guest Ticket',
                  icon: Icons.trending_up_rounded,
                  color: GlassTheme.primaryViolet,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 850;

              Widget paymentBreakdown = GlassContainer(
                padding: const EdgeInsets.all(18),
                borderRadius: 20,
                blurStrength: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Revenue Breakdown by Payment Mode',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 14),

                    _buildPaymentBreakdownRow('UPI Payments', upiTotal, totalRevenue, currency, GlassTheme.primaryCyan, Icons.qr_code_2),
                    const SizedBox(height: 10),
                    _buildPaymentBreakdownRow('Cash Transactions', cashTotal, totalRevenue, currency, GlassTheme.accentNeonGreen, Icons.payments),
                    const SizedBox(height: 10),
                    _buildPaymentBreakdownRow('Cards (Credit/Debit)', cardTotal, totalRevenue, currency, GlassTheme.primaryViolet, Icons.credit_card),

                    const Spacer(),
                    GlassContainer(
                      padding: const EdgeInsets.all(12),
                      backgroundColor: GlassTheme.primaryViolet.withOpacity(0.15),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: GlassTheme.primaryCyan, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Apna POS Insight: Peak dining hours 19:00 - 21:00 with maximum orders.',
                              style: TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              Widget recentLogs = GlassContainer(
                padding: const EdgeInsets.all(18),
                borderRadius: 20,
                blurStrength: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Bills & Orders',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        GlassBadge(label: 'Realtime', color: GlassTheme.primaryCyan, fontSize: 10),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Expanded(
                      child: ListView.builder(
                        itemCount: db.orders.length,
                        itemBuilder: (context, idx) {
                          final order = db.orders[idx];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GlassCard(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: GlassTheme.primaryViolet.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.receipt_rounded, color: GlassTheme.primaryCyan, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${order.orderNumber} • ${order.tableNumber ?? "Takeaway"}',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${order.createdAt} • ${order.paymentMethod}',
                                          style: const TextStyle(color: GlassTheme.textMedium, fontSize: 10),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$currency${order.totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(color: GlassTheme.accentNeonGreen, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.receipt_long_rounded, color: GlassTheme.primaryCyan, size: 18),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                    tooltip: 'View / Print Invoice',
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => ReceiptDialog(order: order, currency: currency),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                return SingleChildScrollView(
                  child: SizedBox(
                    height: constraints.maxHeight * 1.6,
                    child: Column(
                      children: [
                        SizedBox(height: 280, child: paymentBreakdown),
                        const SizedBox(height: 12),
                        Expanded(child: recentLogs),
                      ],
                    ),
                  ),
                );
              }

              return Row(
                children: [
                  Expanded(flex: 2, child: paymentBreakdown),
                  const SizedBox(width: 14),
                  Expanded(flex: 3, child: recentLogs),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

  Widget _buildPaymentBreakdownRow(String mode, double amount, double total, String currency, Color color, IconData icon) {
    final pct = total > 0 ? (amount / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      mode,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$currency${amount.toStringAsFixed(2)} (${(pct * 100).toStringAsFixed(0)}%)',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: GlassTheme.glassInput,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 5,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
