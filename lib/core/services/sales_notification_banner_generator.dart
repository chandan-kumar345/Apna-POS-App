import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class SalesNotificationBannerGenerator {
  /// Generates a high-resolution, enlarged notification banner image containing the 3 summary metric cards:
  /// 1. Total Sales (Green)
  /// 2. Total Orders (Blue)
  /// 3. Avg Order Value (Orange/Amber)
  ///
  /// Returns the absolute path of the generated PNG file, or null if generation fails.
  static Future<String?> generateBannerFile({
    required double totalSales,
    required int orderCount,
    double? avgOrderValue,
  }) async {
    try {
      final double calculatedAvg = avgOrderValue ??
          (orderCount > 0 ? (totalSales / orderCount).roundToDouble() : 0.0);

      final currencyFormatter = NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: 0,
      );

      final String salesFormatted = currencyFormatter.format(totalSales.round());
      final String ordersFormatted = '$orderCount';
      final String avgFormatted = currencyFormatter.format(calculatedAvg.round());

      // Enlarged canvas dimensions (1080 x 280 px) for maximum native notification visibility
      const double width = 1080.0;
      const double height = 280.0;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

      // 1. Sleek dark container background
      final bgPaint = Paint()..color = const Color(0xFF131722);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, width, height),
          const Radius.circular(28.0),
        ),
        bgPaint,
      );

      // Card layout calculations (3 enlarged wide boxes)
      const double padding = 12.0;
      const double cardGap = 14.0;
      const double cardWidth = (width - (padding * 2) - (cardGap * 2)) / 3.0; // ~341.3px
      const double cardHeight = height - (padding * 2); // 256px
      const double cardRadius = 24.0;

      // Draw Card 1: Total Sales (Emerald Green)
      _drawMetricCard(
        canvas: canvas,
        rect: const Rect.fromLTWH(padding, padding, cardWidth, cardHeight),
        radius: cardRadius,
        cardColor: const Color(0xFF0F9D58),
        badgeColor: const Color(0xFF0B7D46),
        title: 'Total Sales',
        value: salesFormatted,
        iconType: _IconType.rupee,
      );

      // Draw Card 2: Total Orders (Royal Blue)
      _drawMetricCard(
        canvas: canvas,
        rect: const Rect.fromLTWH(padding + cardWidth + cardGap, padding, cardWidth, cardHeight),
        radius: cardRadius,
        cardColor: const Color(0xFF1A73E8),
        badgeColor: const Color(0xFF1557B0),
        title: 'Total Orders',
        value: ordersFormatted,
        iconType: _IconType.cart,
      );

      // Draw Card 3: Avg Order Value (Amber/Orange)
      _drawMetricCard(
        canvas: canvas,
        rect: const Rect.fromLTWH(padding + (cardWidth + cardGap) * 2, padding, cardWidth, cardHeight),
        radius: cardRadius,
        cardColor: const Color(0xFFE37400),
        badgeColor: const Color(0xFFB55D00),
        title: 'Avg Order Value',
        value: avgFormatted,
        iconType: _IconType.chart,
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/sales_summary_notification_banner.png');
      await file.writeAsBytes(bytes, flush: true);

      return file.path;
    } catch (e) {
      debugPrint('[SalesNotificationBannerGenerator] Error generating banner: $e');
      return null;
    }
  }

  static void _drawMetricCard({
    required Canvas canvas,
    required Rect rect,
    required double radius,
    required Color cardColor,
    required Color badgeColor,
    required String title,
    required String value,
    required _IconType iconType,
  }) {
    // 1. Card Background
    final cardPaint = Paint()..color = cardColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      cardPaint,
    );

    // 2. Left Icon Badge (Enlarged Circle)
    const double badgeRadius = 36.0;
    final double badgeCenterX = rect.left + 52.0;
    final double badgeCenterY = rect.top + (rect.height / 2.0);

    final badgePaint = Paint()..color = badgeColor;
    canvas.drawCircle(Offset(badgeCenterX, badgeCenterY), badgeRadius, badgePaint);

    // 3. Draw Vector Icon inside badge
    _drawBadgeIcon(canvas, Offset(badgeCenterX, badgeCenterY), badgeRadius, iconType);

    // 4. Texts on right side of badge
    final double textLeft = rect.left + 102.0;
    final double maxTextWidth = rect.width - 110.0;

    // Title (e.g. "Total Sales")
    final titleSpan = TextSpan(
      text: title,
      style: TextStyle(
        color: Colors.white.withOpacity(0.92),
        fontSize: 23.0,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    );
    final titlePainter = TextPainter(
      text: titleSpan,
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxTextWidth);

    // Value (e.g. "₹7,136")
    // Dynamically adjust font size if text is long
    final double valueFontSize = value.length > 9 ? 30.0 : (value.length > 7 ? 36.0 : 44.0);
    final valueSpan = TextSpan(
      text: value,
      style: TextStyle(
        color: Colors.white,
        fontSize: valueFontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.6,
      ),
    );
    final valuePainter = TextPainter(
      text: valueSpan,
      textDirection: ui.TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxTextWidth);

    // Center texts vertically inside card
    final double totalTextHeight = titlePainter.height + 8.0 + valuePainter.height;
    final double textStartY = rect.top + ((rect.height - totalTextHeight) / 2.0);

    titlePainter.paint(canvas, Offset(textLeft, textStartY));
    valuePainter.paint(canvas, Offset(textLeft, textStartY + titlePainter.height + 8.0));
  }

  static void _drawBadgeIcon(
    Canvas canvas,
    Offset center,
    double radius,
    _IconType type,
  ) {
    switch (type) {
      case _IconType.rupee:
        final strokePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        // Top horizontal line
        canvas.drawLine(
          Offset(center.dx - 15.0, center.dy - 15.0),
          Offset(center.dx + 15.0, center.dy - 15.0),
          strokePaint,
        );

        // Middle horizontal line
        canvas.drawLine(
          Offset(center.dx - 15.0, center.dy - 5.0),
          Offset(center.dx + 10.0, center.dy - 5.0),
          strokePaint,
        );

        // Curved Loop & Leg
        final rPath = Path();
        rPath.moveTo(center.dx - 4.0, center.dy - 15.0);
        rPath.lineTo(center.dx + 6.0, center.dy - 15.0);
        rPath.arcToPoint(
          Offset(center.dx - 3.0, center.dy + 4.0),
          radius: const Radius.circular(9.5),
          clockwise: true,
        );
        rPath.lineTo(center.dx + 15.0, center.dy + 20.0);
        canvas.drawPath(rPath, strokePaint);
        break;

      case _IconType.cart:
        final paint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        final path = Path();
        // Cart basket
        path.moveTo(center.dx - 19.0, center.dy - 11.0);
        path.lineTo(center.dx - 13.0, center.dy - 11.0);
        path.lineTo(center.dx - 7.0, center.dy + 6.0);
        path.lineTo(center.dx + 15.0, center.dy + 6.0);
        path.lineTo(center.dx + 19.0, center.dy - 5.0);
        path.lineTo(center.dx - 10.0, center.dy - 5.0);

        canvas.drawPath(path, paint);

        // Wheels
        final wheelPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(center.dx - 5.0, center.dy + 14.0), 3.5, wheelPaint);
        canvas.drawCircle(Offset(center.dx + 12.0, center.dy + 14.0), 3.5, wheelPaint);
        break;

      case _IconType.chart:
        final barPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

        const double barWidth = 6.5;
        const double barGap = 5.0;
        final double baseY = center.dy + 12.0;

        // Bar 1 (Short)
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(center.dx - 12.0, baseY - 14.0, barWidth, 14.0),
            const Radius.circular(2.5),
          ),
          barPaint,
        );

        // Bar 2 (Medium)
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(center.dx - 12.0 + barWidth + barGap, baseY - 23.0, barWidth, 23.0),
            const Radius.circular(2.5),
          ),
          barPaint,
        );

        // Bar 3 (Tall)
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(center.dx - 12.0 + (barWidth + barGap) * 2, baseY - 32.0, barWidth, 32.0),
            const Radius.circular(2.5),
          ),
          barPaint,
        );
        break;
    }
  }
}

enum _IconType { rupee, cart, chart }
