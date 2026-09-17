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
  String _selectedFrequency = 'Daily';

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

    if (maxSales <= 0) maxSales = 25000;
    if (maxOrders <= 0) maxOrders = 100;

    // Round up maxSales to nearest clean 5000 or 10000
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
          // Header Row with Title, Legends, and Frequency Selector
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
                );
              },
            ),
          ),

          // Hover Tooltip Info Banner
          if (_hoveredIndex != null && _hoveredIndex! < points.length) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${points[_hoveredIndex!].dateLabel}: ',
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Sales: ${widget.currency}${points[_hoveredIndex!].salesAmount.toStringAsFixed(0)}',
                    style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  const Text('•', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(width: 8),
                  Text(
                    'Orders: ${points[_hoveredIndex!].orderCount}',
                    style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: Color(0xFF051C48),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.show_chart_rounded, color: Colors.white, size: 16),
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

        // Legends & Frequency Dropdown
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
                    color: Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.isMobile ? 'Sales' : 'Sales (${widget.currency})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),

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
                const SizedBox(width: 4),
                const Text(
                  'Orders',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),

            if (widget.isMobile) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFrequency,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF475569)),
                    items: const [
                      DropdownMenuItem(value: 'Daily', child: Text('Daily', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                      DropdownMenuItem(value: 'Weekly', child: Text('Weekly', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedFrequency = val);
                        widget.onFrequencyChanged?.call(val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _handleTouch(Offset localPos, double totalWidth, int count) {
    if (count <= 0) return;
    const double leftMargin = 42;
    const double rightMargin = 32;
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
    if (val <= 5000) return 5000;
    if (val <= 10000) return 10000;
    if (val <= 20000) return 20000;
    if (val <= 50000) return 50000;
    if (val <= 100000) return 100000;
    return (val * 1.15).ceilToDouble();
  }

  int _calculateOrdersCeiling(int val) {
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
        salesAmount: (index + 2) * 2800.0,
        orderCount: (index + 2) * 8,
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
    final double leftMargin = isMobile ? 36 : 46;
    final double rightMargin = isMobile ? 26 : 34;
    final double bottomMargin = 24;
    final double topMargin = 12;

    final double chartWidth = size.width - leftMargin - rightMargin;
    final double chartHeight = size.height - topMargin - bottomMargin;
    if (chartWidth <= 0 || chartHeight <= 0 || points.isEmpty) return;

    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0;

    final textStyle = const TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w600,
      color: Color(0xFF94A3B8),
    );

    // Draw 4 Horizontal Grid lines & Axis Labels
    const int gridSteps = 4;
    for (int i = 0; i <= gridSteps; i++) {
      final y = topMargin + (chartHeight * (gridSteps - i) / gridSteps);

      // Grid line
      canvas.drawLine(Offset(leftMargin, y), Offset(leftMargin + chartWidth, y), gridPaint);

      // Left Y-Axis Label (Sales in ₹)
      final salesVal = (maxSales * i / gridSteps);
      final salesText = salesVal >= 1000
          ? '$currency${(salesVal / 1000).toStringAsFixed(salesVal % 1000 == 0 ? 0 : 1)}k'
          : '$currency${salesVal.toInt()}';
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
    final double barWidth = math.min(stepX * 0.45, isMobile ? 18.0 : 26.0);

    // 1. Draw Sales Bars (Blue with rounded top)
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final centerX = leftMargin + (i * stepX) + (stepX / 2);
      final barHeight = maxSales > 0 ? (p.salesAmount / maxSales) * chartHeight : 0.0;
      final topY = topMargin + chartHeight - barHeight;

      final isHovered = hoveredIndex == i;
      final barPaint = Paint()
        ..color = isHovered ? const Color(0xFF2563EB) : const Color(0xFF60A5FA).withValues(alpha: 0.85);

      final rrect = RRect.fromRectAndCorners(
        Rect.fromLTRB(centerX - barWidth / 2, topY, centerX + barWidth / 2, topMargin + chartHeight),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      );
      canvas.drawRRect(rrect, barPaint);

      // Bottom X-Axis Date Label
      String dateLabel = p.dateLabel;
      if (isMobile && dateLabel.contains(' ')) {
        // e.g. "11 Sep" -> "11" for clean mobile fit
        dateLabel = dateLabel.split(' ').first;
      }
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

        final outerPaint = Paint()..color = const Color(0xFF10B981);
        final innerPaint = Paint()..color = Colors.white;

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
