import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../core/services/report_service.dart';

class SalesTrendChart extends StatefulWidget {
  final List<DailySalesTrendPoint> dataPoints;
  final String currency;
  final bool isMobile;
  final ValueChanged<String>? onFrequencyChanged;

  const SalesTrendChart({
    super.key,
    required this.dataPoints,
    this.currency = '₹',
    this.isMobile = false,
    this.onFrequencyChanged,
  });

  @override
  State<SalesTrendChart> createState() => _SalesTrendChartState();
}

class _SalesTrendChartState extends State<SalesTrendChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    // If no data points, generate a 7-day default sample
    final points = widget.dataPoints.isNotEmpty
        ? widget.dataPoints
        : _generateSamplePoints();

    double maxSales = 0.0;
    int maxOrders = 0;

    for (final p in points) {
      if (p.salesAmount > maxSales) maxSales = p.salesAmount;
      if (p.orderCount > maxOrders) maxOrders = p.orderCount;
    }

    // Dynamic clean ceilings
    final double salesCeiling = _calculateCeiling(maxSales);
    final int ordersCeiling = _calculateOrdersCeiling(maxOrders);

    return Container(
      padding: EdgeInsets.all(widget.isMobile ? 14 : 18),
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
          // Header Row with Title, Legends
          _buildHeader(),
          const SizedBox(height: 16),

          // Chart Area with Left/Right Y-Axes and Interactive Canvas
          SizedBox(
            height: widget.isMobile ? 180 : 210,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onPanDown: (details) => _handleTouch(details.localPosition, constraints.maxWidth, points.length),
                  onPanUpdate: (details) => _handleTouch(details.localPosition, constraints.maxWidth, points.length),
                  onPanEnd: (_) => setState(() => _hoveredIndex = null),
                  onTapUp: (_) => setState(() => _hoveredIndex = null),
                  child: MouseRegion(
                    onHover: (event) => _handleTouch(event.localPosition, constraints.maxWidth, points.length),
                    onExit: (_) => setState(() => _hoveredIndex = null),
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _DualAxisChartPainter(
                        points: points,
                        maxSales: salesCeiling,
                        maxOrders: ordersCeiling,
                        currency: widget.currency,
                        isMobile: widget.isMobile,
                        hoveredIndex: _hoveredIndex,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Hover Tooltip Info Banner
          if (_hoveredIndex != null && _hoveredIndex! < points.length) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(9),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.insights_rounded, size: 14, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 6),
                  Text(
                    '${points[_hoveredIndex!].dateLabel}: ',
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Sales: ${widget.currency}${_formatTooltipAmount(points[_hoveredIndex!].salesAmount)}',
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  const Text('•', style: TextStyle(color: Colors.white38, fontSize: 11.5)),
                  const SizedBox(width: 8),
                  Text(
                    'Orders: ${points[_hoveredIndex!].orderCount}',
                    style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTooltipAmount(double amount) {
    if (amount >= 1000) {
      final str = amount.toStringAsFixed(0);
      return str.replaceAllMapped(RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))(\.\d+)?'), (Match m) => '${m[1]},');
    }
    return amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Title with Icon
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: widget.isMobile ? 38 : 44,
              height: widget.isMobile ? 38 : 44,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Image.asset(
                'assets/images/sales report icon/sales trend.png',
                width: widget.isMobile ? 26 : 32,
                height: widget.isMobile ? 26 : 32,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.analytics_rounded,
                  color: const Color(0xFF0F172A),
                  size: widget.isMobile ? 20 : 24,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Sales Trend',
              style: TextStyle(
                fontSize: widget.isMobile ? 14 : 15.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),

        // Legends (Sales & Orders)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Legend: Sales
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  widget.isMobile ? 'Sales' : 'Sales (${widget.currency})',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Legend: Orders
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'Orders',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  void _handleTouch(Offset localPos, double totalWidth, int count) {
    if (count <= 0) return;
    final double leftMargin = widget.isMobile ? 44 : 56;
    final double rightMargin = widget.isMobile ? 26 : 34;
    final chartWidth = totalWidth - leftMargin - rightMargin;
    if (chartWidth <= 0) return;

    final xInChart = localPos.dx - leftMargin;
    if (xInChart >= 0 && xInChart <= chartWidth) {
      final step = chartWidth / count;
      final idx = (xInChart / step).floor().clamp(0, count - 1);
      setState(() {
        _hoveredIndex = idx;
      });
    }
  }

  double _calculateCeiling(double val) {
    if (val <= 0) return 500;
    if (val <= 100) return 100;
    if (val <= 250) return 250;
    if (val <= 500) return 500;
    if (val <= 1000) return 1000;
    if (val <= 2500) return 2500;
    if (val <= 5000) return 5000;
    if (val <= 10000) return 10000;
    if (val <= 15000) return 15000;
    if (val <= 20000) return 20000;
    if (val <= 25000) return 25000;
    if (val <= 50000) return 50000;
    if (val <= 100000) return 100000;
    return (val * 1.15).ceilToDouble();
  }

  int _calculateOrdersCeiling(int val) {
    if (val <= 0) return 5;
    if (val <= 5) return 5;
    if (val <= 10) return 10;
    if (val <= 20) return 20;
    if (val <= 50) return 50;
    if (val <= 100) return 100;
    if (val <= 200) return 200;
    return (val * 1.2).ceil();
  }

  List<DailySalesTrendPoint> _generateSamplePoints() {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final d = now.subtract(Duration(days: 6 - index));
      return DailySalesTrendPoint(
        date: d,
        dateLabel: DateFormat('d MMM').format(d),
        salesAmount: 0.0,
        orderCount: 0,
      );
    });
  }
}

class _DualAxisChartPainter extends CustomPainter {
  final List<DailySalesTrendPoint> points;
  final double maxSales;
  final int maxOrders;
  final String currency;
  final bool isMobile;
  final int? hoveredIndex;

  _DualAxisChartPainter({
    required this.points,
    required this.maxSales,
    required this.maxOrders,
    required this.currency,
    required this.isMobile,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double leftMargin = isMobile ? 44 : 56;
    final double rightMargin = isMobile ? 26 : 34;
    final double bottomMargin = 24;
    final double topMargin = 12;

    final double chartWidth = size.width - leftMargin - rightMargin;
    final double chartHeight = size.height - topMargin - bottomMargin;
    if (chartWidth <= 0 || chartHeight <= 0 || points.isEmpty) return;

    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0;

    const textStyle = TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w600,
      color: Color(0xFF94A3B8),
    );

    // Draw 5 Horizontal Grid lines & Axis Labels (0, 1/5, 2/5, 3/5, 4/5, 5/5)
    const int gridSteps = 5;
    for (int i = 0; i <= gridSteps; i++) {
      final y = topMargin + (chartHeight * (gridSteps - i) / gridSteps);

      // Grid line
      canvas.drawLine(Offset(leftMargin, y), Offset(leftMargin + chartWidth, y), gridPaint);

      // Left Y-Axis Label (Sales in ₹)
      final salesVal = (maxSales * i / gridSteps).round();
      String salesText;
      if (salesVal == 0) {
        salesText = '$currency 0';
      } else if (salesVal >= 1000) {
        final str = salesVal.toString();
        final formatted = str.replaceAllMapped(RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))(\.\d+)?'), (Match m) => '${m[1]},');
        salesText = '$currency$formatted';
      } else {
        salesText = '$currency$salesVal';
      }

      final tpLeft = TextPainter(
        text: TextSpan(text: salesText, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tpLeft.paint(canvas, Offset(leftMargin - tpLeft.width - 6, y - tpLeft.height / 2));

      // Right Y-Axis Label (Orders Count)
      final ordersVal = (maxOrders * i / gridSteps).round();
      final tpRight = TextPainter(
        text: TextSpan(text: '$ordersVal', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tpRight.paint(canvas, Offset(leftMargin + chartWidth + 6, y - tpRight.height / 2));
    }

    final double stepX = chartWidth / points.length;
    final double barWidth = math.min(stepX * 0.44, isMobile ? 18.0 : 28.0);

    // Dynamic label spacing interval to prevent overlap when points count is large
    final int labelInterval = points.length > 20
        ? (points.length / 6).ceil()
        : (points.length > 12 ? (points.length / 7).ceil() : 1);

    // Draw vertical indicator line for hovered item
    if (hoveredIndex != null && hoveredIndex! >= 0 && hoveredIndex! < points.length) {
      final hX = leftMargin + (hoveredIndex! * stepX) + (stepX / 2);
      final highlightPaint = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.25)
        ..strokeWidth = barWidth + 8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(hX, topMargin),
        Offset(hX, topMargin + chartHeight),
        highlightPaint,
      );
    }

    // 1. Draw Sales Bars (Blue with gradient and rounded top)
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final centerX = leftMargin + (i * stepX) + (stepX / 2);
      final rawHeight = maxSales > 0 ? (p.salesAmount / maxSales) * chartHeight : 0.0;
      final barHeight = p.salesAmount > 0 ? math.max(4.0, rawHeight) : 0.0;
      final topY = topMargin + chartHeight - barHeight;

      final isHovered = hoveredIndex == i;
      final barRect = Rect.fromLTRB(
        centerX - barWidth / 2,
        topY,
        centerX + barWidth / 2,
        topMargin + chartHeight,
      );

      if (barHeight > 0) {
        final barPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isHovered
                ? const [Color(0xFF2563EB), Color(0xFF1D4ED8)]
                : [const Color(0xFF60A5FA), const Color(0xFF2563EB).withValues(alpha: 0.88)],
          ).createShader(barRect);

        final cornerRadius = Radius.circular(math.min(5.0, barHeight / 2));
        final rrect = RRect.fromRectAndCorners(
          barRect,
          topLeft: cornerRadius,
          topRight: cornerRadius,
        );
        canvas.drawRRect(rrect, barPaint);
      }

      // Bottom X-Axis Date Label
      String dateLabel = p.dateLabel;
      if (isMobile && dateLabel.contains(' ') && !dateLabel.endsWith('AM') && !dateLabel.endsWith('PM')) {
        dateLabel = dateLabel.split(' ').first;
      }

      final bool showLabel = (i % labelInterval == 0) || (i == points.length - 1) || isHovered;

      if (showLabel) {
        final tpBottom = TextPainter(
          text: TextSpan(
            text: dateLabel,
            style: TextStyle(
              fontSize: isMobile ? 9 : 10,
              fontWeight: isHovered ? FontWeight.bold : FontWeight.w600,
              color: isHovered ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tpBottom.paint(canvas, Offset(centerX - tpBottom.width / 2, topMargin + chartHeight + 6));
      }
    }

    // 2. Draw Orders Line (Green smooth bezier curve)
    final linePath = Path();
    final List<Offset> orderPoints = [];

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final centerX = leftMargin + (i * stepX) + (stepX / 2);
      final normOrders = maxOrders > 0 ? (p.orderCount / maxOrders).clamp(0.0, 1.0) : 0.0;
      final y = topMargin + chartHeight - (normOrders * chartHeight);
      orderPoints.add(Offset(centerX, y));
    }

    if (orderPoints.isNotEmpty) {
      linePath.moveTo(orderPoints[0].dx, orderPoints[0].dy);
      for (int i = 0; i < orderPoints.length - 1; i++) {
        final p0 = orderPoints[i];
        final p1 = orderPoints[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        linePath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      }

      final linePaint = Paint()
        ..color = const Color(0xFF10B981)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(linePath, linePaint);

      // Draw Circular Nodes on Line Points
      for (int i = 0; i < orderPoints.length; i++) {
        final pt = orderPoints[i];
        final isHovered = hoveredIndex == i;

        final outerPaint = Paint()..color = isHovered ? const Color(0xFF059669) : const Color(0xFF10B981);
        final innerPaint = Paint()..color = Colors.white;

        if (isHovered) {
          final glowPaint = Paint()
            ..color = const Color(0xFF10B981).withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
          canvas.drawCircle(pt, 8.0, glowPaint);
        }

        canvas.drawCircle(pt, isHovered ? 5.5 : 4.0, outerPaint);
        canvas.drawCircle(pt, isHovered ? 2.5 : 2.0, innerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DualAxisChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.maxSales != maxSales ||
        oldDelegate.maxOrders != maxOrders;
  }
}
