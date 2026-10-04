import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/super_admin_theme.dart';

/// Interactive Line Chart with Gradient Fill & Tooltips
class SuperAdminLineChart extends StatefulWidget {
  final List<String> labels;
  final List<double> values;
  final List<double>? secondaryValues;
  final String primaryLabel;
  final String? secondaryLabel;
  final Color primaryColor;
  final Color secondaryColor;
  final double height;
  final String valuePrefix;

  const SuperAdminLineChart({
    super.key,
    required this.labels,
    required this.values,
    this.secondaryValues,
    this.primaryLabel = 'Revenue',
    this.secondaryLabel,
    this.primaryColor = SuperAdminTheme.primary,
    this.secondaryColor = SuperAdminTheme.accent,
    this.height = 240,
    this.valuePrefix = '₹',
  });

  @override
  State<SuperAdminLineChart> createState() => _SuperAdminLineChartState();
}

class _SuperAdminLineChartState extends State<SuperAdminLineChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.values.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('No chart data available', style: TextStyle(color: SuperAdminTheme.textMuted)),
        ),
      );
    }

    final double maxValue = math.max(
      widget.values.reduce(math.max),
      (widget.secondaryValues != null && widget.secondaryValues!.isNotEmpty)
          ? widget.secondaryValues!.reduce(math.max)
          : 0.0,
    );

    final effectiveMax = maxValue == 0 ? 1000.0 : maxValue * 1.15;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend Header
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildLegendItem(widget.primaryLabel, widget.primaryColor),
            if (widget.secondaryValues != null && widget.secondaryLabel != null) ...[
              const SizedBox(width: 16),
              _buildLegendItem(widget.secondaryLabel!, widget.secondaryColor),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Canvas Area
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return MouseRegion(
                onHover: (event) {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    final local = renderBox.globalToLocal(event.position);
                    final widthPerPoint = constraints.maxWidth / (widget.values.length - 1);
                    final idx = (local.dx / widthPerPoint).round().clamp(0, widget.values.length - 1);
                    setState(() {
                      _hoveredIndex = idx;
                    });
                  }
                },
                onExit: (_) {
                  setState(() {
                    _hoveredIndex = null;
                  });
                },
                child: CustomPaint(
                  size: Size(constraints.maxWidth, widget.height),
                  painter: _LineChartPainter(
                    labels: widget.labels,
                    values: widget.values,
                    secondaryValues: widget.secondaryValues,
                    primaryColor: widget.primaryColor,
                    secondaryColor: widget.secondaryColor,
                    maxValue: effectiveMax,
                    hoveredIndex: _hoveredIndex,
                    valuePrefix: widget.valuePrefix,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: SuperAdminTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final List<double>? secondaryValues;
  final Color primaryColor;
  final Color secondaryColor;
  final double maxValue;
  final int? hoveredIndex;
  final String valuePrefix;

  _LineChartPainter({
    required this.labels,
    required this.values,
    this.secondaryValues,
    required this.primaryColor,
    required this.secondaryColor,
    required this.maxValue,
    this.hoveredIndex,
    required this.valuePrefix,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPadding = 28.0;
    const topPadding = 16.0;
    final chartHeight = size.height - bottomPadding - topPadding;
    final n = values.length;
    final stepX = n > 1 ? size.width / (n - 1) : size.width;

    // Draw grid lines (4 horizontal dashed lines)
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 3; i++) {
      final y = topPadding + (chartHeight / 3) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Path builder helper
    List<Offset> buildPoints(List<double> data) {
      final points = <Offset>[];
      for (int i = 0; i < data.length; i++) {
        final x = i * stepX;
        final norm = (data[i] / maxValue).clamp(0.0, 1.0);
        final y = topPadding + chartHeight - (norm * chartHeight);
        points.add(Offset(x, y));
      }
      return points;
    }

    // Secondary Line
    if (secondaryValues != null && secondaryValues!.isNotEmpty) {
      final secPoints = buildPoints(secondaryValues!);
      _drawSmoothCurve(canvas, secPoints, secondaryColor, false, size, topPadding + chartHeight);
    }

    // Primary Line with gradient fill
    final primPoints = buildPoints(values);
    _drawSmoothCurve(canvas, primPoints, primaryColor, true, size, topPadding + chartHeight);

    // Draw bottom X-axis labels
    const textStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: SuperAdminTheme.textMuted,
    );

    for (int i = 0; i < labels.length; i++) {
      final textSpan = TextSpan(text: labels[i], style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final x = (i * stepX) - (textPainter.width / 2);
      textPainter.paint(canvas, Offset(x.clamp(0.0, size.width - textPainter.width), size.height - 18));
    }

    // Draw hover indicator if active
    if (hoveredIndex != null && hoveredIndex! < primPoints.length) {
      final p = primPoints[hoveredIndex!];
      final linePaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.5)
        ..strokeWidth = 1.5;

      canvas.drawLine(Offset(p.dx, topPadding), Offset(p.dx, topPadding + chartHeight), linePaint);

      // Primary Point dot
      final dotOuter = Paint()..color = Colors.white;
      final dotInner = Paint()..color = primaryColor;
      canvas.drawCircle(p, 6, dotOuter);
      canvas.drawCircle(p, 4, dotInner);

      // Value Tooltip Box
      final valStr = '$valuePrefix${values[hoveredIndex!].toStringAsFixed(0)}';
      final tp = TextPainter(
        text: TextSpan(
          text: valStr,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final tooltipW = tp.width + 16;
      const tooltipH = 24.0;
      final tooltipX = (p.dx - (tooltipW / 2)).clamp(4.0, size.width - tooltipW - 4.0);
      final tooltipY = math.max(0.0, p.dy - 32.0);

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipX, tooltipY, tooltipW, tooltipH),
        const Radius.circular(6),
      );

      final boxPaint = Paint()..color = const Color(0xFF0F172A);
      canvas.drawRRect(rrect, boxPaint);
      tp.paint(canvas, Offset(tooltipX + 8, tooltipY + 4));
    }
  }

  void _drawSmoothCurve(
    Canvas canvas,
    List<Offset> points,
    Color color,
    bool isFill,
    Size size,
    double baselineY,
  ) {
    if (points.isEmpty) return;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    if (isFill) {
      final fillPath = Path.from(path);
      fillPath.lineTo(points.last.dx, baselineY);
      fillPath.lineTo(points.first.dx, baselineY);
      fillPath.close();

      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.25),
          color.withValues(alpha: 0.0),
        ],
      );

      final fillPaint = Paint()
        ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, baselineY))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);
    }

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.hoveredIndex != hoveredIndex ||
        oldDelegate.values != values ||
        oldDelegate.maxValue != maxValue;
  }
}

/// Bar chart for sales / subscriptions breakdown
class SuperAdminBarChart extends StatelessWidget {
  final List<String> categories;
  final List<double> values;
  final List<Color>? barColors;
  final double height;
  final String valuePrefix;

  const SuperAdminBarChart({
    super.key,
    required this.categories,
    required this.values,
    this.barColors,
    this.height = 220,
    this.valuePrefix = '',
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final maxValue = values.reduce(math.max);
    final effectiveMax = maxValue == 0 ? 10.0 : maxValue;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(categories.length, (idx) {
          final val = values[idx];
          final heightFactor = (val / effectiveMax).clamp(0.08, 1.0);
          final color = (barColors != null && idx < barColors!.length)
              ? barColors![idx]
              : SuperAdminTheme.primary;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '$valuePrefix${val.toInt()}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: SuperAdminTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Container(
                      height: (height - 50) * heightFactor,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            offset: const Offset(0, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    categories[idx],
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: SuperAdminTheme.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
