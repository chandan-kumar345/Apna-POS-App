import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/services/report_service.dart';

class PaymentModeDonutChart extends StatelessWidget {
  final List<PaymentModeStat> paymentModes;
  final double totalSales;
  final String currency;
  final bool isMobile;
  final VoidCallback? onTap;

  const PaymentModeDonutChart({
    super.key,
    required this.paymentModes,
    required this.totalSales,
    this.currency = '₹',
    this.isMobile = false,
    this.onTap,
  });

  List<PaymentModeStat> _getCanonicalModes() {
    double cashAmount = 0.0;
    int cashCount = 0;
    double upiAmount = 0.0;
    int upiCount = 0;
    double cardAmount = 0.0;
    int cardCount = 0;
    double walletAmount = 0.0;
    int walletCount = 0;
    double otherAmount = 0.0;
    int otherCount = 0;

    for (final item in paymentModes) {
      final combined = '${item.mode} ${item.rawMode}'.toLowerCase().trim();

      if (combined.contains('upi') ||
          combined.contains('qr') ||
          combined.contains('online') ||
          combined.contains('gpay') ||
          combined.contains('phonepe') ||
          combined.contains('paytm') ||
          combined.contains('digital')) {
        upiAmount += item.amount;
        upiCount += item.count;
      } else if (combined.contains('card') ||
          combined.contains('debit') ||
          combined.contains('credit') ||
          combined.contains('swipe')) {
        cardAmount += item.amount;
        cardCount += item.count;
      } else if (combined.contains('wallet')) {
        walletAmount += item.amount;
        walletCount += item.count;
      } else if (combined.contains('cash') || combined.isEmpty) {
        cashAmount += item.amount;
        cashCount += item.count;
      } else {
        otherAmount += item.amount;
        otherCount += item.count;
      }
    }

    final totalSum = cashAmount + upiAmount + cardAmount + walletAmount + otherAmount;
    final effectiveTotal = totalSales > 0 ? totalSales : totalSum;

    double calcPct(double amt) {
      if (effectiveTotal <= 0) return 0.0;
      return (amt / effectiveTotal) * 100;
    }

    // Real 0 state when no sales recorded
    if (totalSum == 0 && totalSales <= 0) {
      return [
        PaymentModeStat(mode: 'Cash', rawMode: 'cash', amount: 0, count: 0, percentage: 0),
        PaymentModeStat(mode: 'UPI / Digital QR', rawMode: 'upi', amount: 0, count: 0, percentage: 0),
        PaymentModeStat(mode: 'Card (Debit/Credit)', rawMode: 'card', amount: 0, count: 0, percentage: 0),
        PaymentModeStat(mode: 'Wallet', rawMode: 'wallet', amount: 0, count: 0, percentage: 0),
        PaymentModeStat(mode: 'Other', rawMode: 'other', amount: 0, count: 0, percentage: 0),
      ];
    }

    return [
      PaymentModeStat(
        mode: 'Cash',
        rawMode: 'cash',
        amount: cashAmount,
        count: cashCount,
        percentage: calcPct(cashAmount),
      ),
      PaymentModeStat(
        mode: 'UPI / Digital QR',
        rawMode: 'upi',
        amount: upiAmount,
        count: upiCount,
        percentage: calcPct(upiAmount),
      ),
      PaymentModeStat(
        mode: 'Card (Debit/Credit)',
        rawMode: 'card',
        amount: cardAmount,
        count: cardCount,
        percentage: calcPct(cardAmount),
      ),
      PaymentModeStat(
        mode: 'Wallet',
        rawMode: 'wallet',
        amount: walletAmount,
        count: walletCount,
        percentage: calcPct(walletAmount),
      ),
      PaymentModeStat(
        mode: 'Other',
        rawMode: 'other',
        amount: otherAmount,
        count: otherCount,
        percentage: calcPct(otherAmount),
      ),
    ];
  }

  double _getEffectiveTotal(List<PaymentModeStat> modes) {
    if (totalSales > 0) return totalSales;
    final sum = modes.fold(0.0, (s, p) => s + p.amount);
    return sum;
  }

  Color _getColorForMode(String mode, int index) {
    final m = mode.toLowerCase();
    if (m.contains('cash')) return const Color(0xFF10B981); // Emerald Green
    if (m.contains('upi') || m.contains('qr') || m.contains('online') || m.contains('digital')) {
      return const Color(0xFF2563EB); // Royal Blue
    }
    if (m.contains('card') || m.contains('credit') || m.contains('debit')) {
      return const Color(0xFF8B5CF6); // Purple
    }
    if (m.contains('wallet')) return const Color(0xFFF59E0B); // Amber / Orange
    if (m.contains('other') || m.contains('split')) return const Color(0xFF94A3B8); // Slate Gray

    final fallbackColors = [
      const Color(0xFF10B981),
      const Color(0xFF2563EB),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFF94A3B8),
    ];
    return fallbackColors[index % fallbackColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final canonicalModes = _getCanonicalModes();
    final effectiveTotal = _getEffectiveTotal(canonicalModes);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isMobile ? 40 : 46,
                      height: isMobile ? 40 : 46,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Image.asset(
                        'assets/images/sales report icon/payment mode.png',
                        width: isMobile ? 28 : 34,
                        height: isMobile ? 28 : 34,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.credit_card_rounded,
                          color: const Color(0xFF0F172A),
                          size: isMobile ? 20 : 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isMobile ? 'Payment Mode' : 'Sales by Payment Mode',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                if (isMobile)
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
              ],
            ),
            const SizedBox(height: 16),

            // Responsive Layout: Side-by-side on Desktop, Stacked on Mobile
            if (!isMobile)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Donut Canvas with Center Text
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(150, 150),
                          painter: _DonutChartPainter(
                            paymentModes: canonicalModes,
                            totalSales: effectiveTotal,
                            getColor: _getColorForMode,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$currency${_formatAmount(effectiveTotal)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Total Sales',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Legends List: Exactly 5 single lines
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(canonicalModes.length, (idx) {
                        final mode = canonicalModes[idx];
                        final color = _getColorForMode(mode.mode, idx);
                        final pct = mode.percentage;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.5),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  mode.mode,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '$currency${_formatAmount(mode.amount)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '${pct.toStringAsFixed(0)}%',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  // Donut Canvas with Center Text
                  Center(
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(140, 140),
                            painter: _DonutChartPainter(
                              paymentModes: canonicalModes,
                              totalSales: effectiveTotal,
                              getColor: _getColorForMode,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$currency${_formatAmount(effectiveTotal)}',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Total Sales',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Mobile 2-Column Wrapped Legends
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: List.generate(canonicalModes.length, (idx) {
                      final mode = canonicalModes[idx];
                      final color = _getColorForMode(mode.mode, idx);
                      final pct = mode.percentage;

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            mode.mode.replaceAll('(Debit/Credit)', '').replaceAll('/ Digital QR', '').trim(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${pct.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) {
      final formatted = amount.toStringAsFixed(0);
      return formatted.replaceAllMapped(RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))(\.\d+)?'), (Match m) => '${m[1]},');
    }
    return amount.toStringAsFixed(0);
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<PaymentModeStat> paymentModes;
  final double totalSales;
  final Color Function(String mode, int index) getColor;

  _DonutChartPainter({
    required this.paymentModes,
    required this.totalSales,
    required this.getColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 24.0;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // Filter only modes with amount > 0
    final activeModes = paymentModes.where((m) => m.amount > 0).toList();

    if (totalSales <= 0 || activeModes.isEmpty) {
      final defaultPaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, defaultPaint);
      return;
    }

    double startAngle = -math.pi / 2;

    // If there is only 1 mode with 100%, draw full complete circle
    if (activeModes.length == 1) {
      final mode = activeModes.first;
      final originalIdx = paymentModes.indexOf(mode);
      final paint = Paint()
        ..color = getColor(mode.mode, originalIdx >= 0 ? originalIdx : 0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    for (int i = 0; i < activeModes.length; i++) {
      final mode = activeModes[i];
      final sweepAngle = (mode.amount / totalSales) * 2 * math.pi;

      if (sweepAngle > 0.001) {
        final originalIdx = paymentModes.indexOf(mode);
        final paint = Paint()
          ..color = getColor(mode.mode, originalIdx >= 0 ? originalIdx : i)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;

        // Add slight gap between arcs
        const gap = 0.025;
        final actualSweep = (sweepAngle > gap * 2) ? (sweepAngle - gap) : sweepAngle;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle + gap / 2,
          actualSweep,
          false,
          paint,
        );
      }

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.totalSales != totalSales || !listEquals(oldDelegate.paymentModes, paymentModes);
  }
}
