import 'dart:math' as math;
import 'package:flutter/material.dart';

class MetricSparkline extends StatelessWidget {
  final Color color;
  final double width;
  final double height;
  final List<double>? customPoints;

  const MetricSparkline({
    super.key,
    required this.color,
    this.width = 65,
    this.height = 28,
    this.customPoints,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(
          color: color,
          points: customPoints,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final Color color;
  final List<double>? points;

  _SparklinePainter({required this.color, this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final values = points ?? [0.35, 0.45, 0.38, 0.65, 0.55, 0.85, 0.95];
    if (values.length < 2) return;

    final double minVal = values.reduce(math.min);
    final double maxVal = values.reduce(math.max);
    final double range = (maxVal - minVal == 0) ? 1.0 : (maxVal - minVal);

    final path = Path();
    final fillPath = Path();
    final stepX = size.width / (values.length - 1);

    final List<Offset> normalizedPoints = [];
    for (int i = 0; i < values.length; i++) {
      final normY = (values[i] - minVal) / range;
      // Invert Y for canvas (top is 0)
      final y = size.height - (normY * (size.height - 6)) - 3;
      final x = i * stepX;
      normalizedPoints.add(Offset(x, y));
    }

    path.moveTo(normalizedPoints[0].dx, normalizedPoints[0].dy);
    fillPath.moveTo(normalizedPoints[0].dx, normalizedPoints[0].dy);

    for (int i = 0; i < normalizedPoints.length - 1; i++) {
      final p0 = normalizedPoints[i];
      final p1 = normalizedPoints[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    // Close fill path down to the bottom
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    // 1. Draw gradient fill area beneath curve
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.32),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // 2. Draw smooth stroke line on top
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.points != points;
  }
}
