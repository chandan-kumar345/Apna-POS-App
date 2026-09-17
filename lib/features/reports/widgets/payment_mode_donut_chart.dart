import 'dart:math' as math;
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

  Color _getColorForMode(String mode, int index) {
    final m = mode.toLowerCase();
    if (m.contains('cash')) return const Color(0xFF10B981); // Emerald Green
    if (m.contains('upi') || m.contains('qr') || m.contains('online')) return const Color(0xFF2563EB); // Royal Blue
    if (m.contains('card')) return const Color(0xFF8B5CF6); // Purple
    if (m.contains('wallet')) return const Color(0xFFF59E0B); // Amber
    if (m.contains('other') || m.contains('split')) return const Color(0xFF94A3B8); // Slate Gray

    final fallbackColors = [
      const Color(0xFF10B981),
      const Color(0xFF2563EB),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFF94A3B8),
      const Color(0xFFEC4899),
    ];
    return fallbackColors[index % fallbackColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTotal = totalSales > 0
        ? totalSales
        : paymentModes.fold(0.0, (sum, p) => sum + p.amount);

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
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Color(0xFF051C48),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.pie_chart_rounded, color: Colors.white, size: 16),
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
                    width: 170,
                    height: 170,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(160, 160),
                          painter: _DonutChartPainter(
                            paymentModes: paymentModes,
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
                            const Text(
                              'Total Sales',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Legends List
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(paymentModes.length, (idx) {
                        final mode = paymentModes[idx];
                        final color = _getColorForMode(mode.mode, idx);
                        final pct = effectiveTotal > 0 ? (mode.amount / effectiveTotal) * 100 : 0.0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
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
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  mode.mode,
                                  style: const TextStyle(
                                    fontSize: 11.5,
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
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 34,
                                child: Text(
                                  '${pct.toStringAsFixed(0)}%',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
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
                              paymentModes: paymentModes,
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
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
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
                    children: List.generate(paymentModes.length, (idx) {
                      final mode = paymentModes[idx];
                      final color = _getColorForMode(mode.mode, idx);
                      final pct = effectiveTotal > 0 ? (mode.amount / effectiveTotal) * 100 : 0.0;

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
                            mode.mode.replaceAll('Payments', '').replaceAll('(Debit/Credit)', '').trim(),
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${pct.toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
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
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 22.0;

    if (totalSales <= 0 || paymentModes.isEmpty) {
      final defaultPaint = Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius - strokeWidth / 2, defaultPaint);
      return;
    }

    double startAngle = -math.pi / 2;

    for (int i = 0; i < paymentModes.length; i++) {
      final mode = paymentModes[i];
      final sweepAngle = (mode.amount / totalSales) * 2 * math.pi;

      if (sweepAngle > 0.001) {
        final paint = Paint()
          ..color = getColor(mode.mode, i)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;

        // Add a slight arc gap
        const gap = 0.03;
        final actualSweep = (sweepAngle > gap * 2) ? (sweepAngle - gap) : sweepAngle;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
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
    return oldDelegate.totalSales != totalSales || oldDelegate.paymentModes != paymentModes;
  }
}
