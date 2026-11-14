import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Writes isolated characters in brand-colored ink, then blends the completed
/// wordmark into the original glossy logo without changing its letter shapes.
class LogoWritingReveal extends StatefulWidget {
  static const duration = Duration(milliseconds: 3600);
  static const assetPath = 'assets/images/android_launcher_logo.png';
  static const inkAssetPath = 'assets/images/apna_pos_logo_ink_atlas.png';

  final Animation<double> animation;
  final double size;

  const LogoWritingReveal({
    super.key,
    required this.animation,
    required this.size,
  });

  @override
  State<LogoWritingReveal> createState() => _LogoWritingRevealState();
}

class _LogoWritingRevealState extends State<LogoWritingReveal> {
  ImageStream? _stream;
  ImageInfo? _frame;
  ImageStream? _inkStream;
  ImageInfo? _inkFrame;
  late final _listener = ImageStreamListener(
    _handleImage,
    onError: (Object error, StackTrace? stackTrace) {
      debugPrint('[LogoWritingReveal] Logo asset could not be decoded: $error');
    },
  );
  late final _inkListener = ImageStreamListener(
    _handleInkImage,
    onError: (Object error, StackTrace? stackTrace) {
      debugPrint('[LogoWritingReveal] Ink atlas could not be decoded: $error');
    },
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = const AssetImage(
      LogoWritingReveal.assetPath,
    ).resolve(createLocalImageConfiguration(context));
    if (_stream?.key != stream.key) {
      _stream?.removeListener(_listener);
      _stream = stream..addListener(_listener);
    }
    final inkStream = const AssetImage(
      LogoWritingReveal.inkAssetPath,
    ).resolve(createLocalImageConfiguration(context));
    if (_inkStream?.key != inkStream.key) {
      _inkStream?.removeListener(_inkListener);
      _inkStream = inkStream..addListener(_inkListener);
    }
  }

  void _handleImage(ImageInfo frame, bool synchronousCall) =>
      _replaceFrame(frame, isInk: false);

  void _handleInkImage(ImageInfo frame, bool synchronousCall) =>
      _replaceFrame(frame, isInk: true);

  void _replaceFrame(ImageInfo frame, {required bool isInk}) {
    if (!mounted) {
      frame.dispose();
      return;
    }
    final previous = isInk ? _inkFrame : _frame;
    setState(() {
      if (isInk) {
        _inkFrame = frame;
      } else {
        _frame = frame;
      }
    });
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _inkStream?.removeListener(_inkListener);
    _frame?.dispose();
    _inkFrame?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Apna POS',
      image: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: _frame == null || _inkFrame == null
            // A visible brand is present even during the first image decode.
            ? const Center(
                child: Text(
                  'Apna\nPOS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0758F5),
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    height: 0.95,
                  ),
                ),
              )
            : CustomPaint(
                painter: _LogoInkPainter(
                  image: _frame!.image,
                  inkAtlas: _inkFrame!.image,
                  animation: widget.animation,
                ),
              ),
      ),
    );
  }
}

class _InkGlyph {
  final Rect bounds;
  final Path path;
  final double width;
  late final metrics = path.computeMetrics().toList();
  late final length = metrics.fold<double>(
    0,
    (sum, metric) => sum + metric.length,
  );

  _InkGlyph(this.bounds, this.path, this.width);
}

class _LogoInkPainter extends CustomPainter {
  // Stroke offsets use the original authored timeline. Playback duration is
  // controlled independently so slowing it also slows every stroke and blend.
  static const _timelineMilliseconds = 3600;
  final ui.Image image;
  final ui.Image inkAtlas;
  final Animation<double> animation;

  _LogoInkPainter({
    required this.image,
    required this.inkAtlas,
    required this.animation,
  }) : super(repaint: animation);

  // Coordinates follow the supplied 1254px logo, in writing order:
  // A-p-n-a, P-O-S, the right-hand flourish, then the receipt.
  static final _glyphs = <_InkGlyph>[
    _InkGlyph(
      const Rect.fromLTRB(25, 375, 375, 735),
      Path()
        ..moveTo(73, 678)
        ..lineTo(215, 426)
        ..lineTo(334, 678)
        ..moveTo(131, 615)
        ..lineTo(291, 615),
      108,
    ),
    _InkGlyph(
      const Rect.fromLTRB(352, 476, 602, 800),
      Path()
        ..moveTo(410, 746)
        ..lineTo(410, 523)
        ..cubicTo(616, 429, 622, 731, 442, 680),
      110,
    ),
    _InkGlyph(
      const Rect.fromLTRB(596, 478, 835, 738),
      Path()
        ..moveTo(649, 683)
        ..lineTo(649, 526)
        ..cubicTo(681, 469, 787, 495, 783, 589)
        ..lineTo(783, 683),
      112,
    ),
    _InkGlyph(
      const Rect.fromLTRB(828, 477, 1065, 739),
      Path()
        ..moveTo(894, 532)
        ..cubicTo(1046, 447, 1071, 704, 926, 680)
        ..cubicTo(819, 682, 850, 563, 1016, 590)
        ..moveTo(1017, 541)
        ..lineTo(1017, 685),
      100,
    ),
    _InkGlyph(
      const Rect.fromLTRB(34, 748, 407, 1176),
      Path()
        ..moveTo(106, 1114)
        ..lineTo(106, 814)
        ..lineTo(245, 814)
        ..cubicTo(421, 802, 414, 993, 215, 991)
        ..lineTo(111, 991),
      122,
    ),
    _InkGlyph(
      const Rect.fromLTRB(397, 746, 804, 1183),
      Path()
        ..moveTo(601, 812)
        ..cubicTo(375, 795, 379, 1115, 599, 1118)
        ..cubicTo(835, 1113, 807, 787, 601, 812),
      114,
    ),
    _InkGlyph(
      const Rect.fromLTRB(756, 745, 1106, 1183),
      Path()
        ..moveTo(1048, 825)
        ..cubicTo(842, 730, 745, 903, 931, 969)
        ..cubicTo(1154, 1055, 1015, 1177, 832, 1106),
      118,
    ),
    _InkGlyph(
      const Rect.fromLTRB(1047, 312, 1236, 1194),
      Path()
        ..moveTo(1055, 359)
        ..cubicTo(1158, 349, 1176, 377, 1176, 503)
        ..lineTo(1176, 1040)
        ..quadraticBezierTo(1187, 1130, 1129, 1157),
      102,
    ),
    _InkGlyph(
      const Rect.fromLTRB(493, 74, 1105, 477),
      Path()
        ..moveTo(546, 419)
        ..quadraticBezierTo(559, 369, 675, 367)
        ..moveTo(850, 113)
        ..lineTo(850, 443),
      504,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final time = animation.value * _timelineMilliseconds;
    final glossyFinish = ((time - 3020) / 420).clamp(0.0, 1.0);
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    const artwork = Rect.fromLTWH(0, 0, 1254, 1254);
    canvas.save();
    canvas.scale(size.width / 1254, size.height / 1254);

    if (glossyFinish >= 1) {
      canvas.drawImageRect(
        image,
        source,
        artwork,
        Paint()..filterQuality = FilterQuality.high,
      );
      canvas.restore();
      return;
    }

    for (var index = 0; index < _glyphs.length; index++) {
      // Each character settles before the next begins. The emblem follows POS.
      final start = index < 7 ? 100 + index * 320 : (index == 7 ? 2390 : 2680);
      final duration = index < 7 ? 280 : (index == 7 ? 350 : 360);
      final amount = Curves.easeOutCubic.transform(
        ((time - start) / duration).clamp(0.0, 1.0),
      );
      if (amount == 0) break;
      final glyph = _glyphs[index];
      final tile = Rect.fromLTWH(
        (index % 3) * 512.0,
        (index ~/ 3) * 512.0,
        512,
        512,
      );
      final inkPaint = Paint()..filterQuality = FilterQuality.high;
      canvas.save();
      canvas.clipRect(glyph.bounds);
      if (amount == 1) {
        canvas.drawImageRect(inkAtlas, tile, glyph.bounds, inkPaint);
      } else {
        canvas.saveLayer(glyph.bounds, Paint());
        canvas.drawImageRect(inkAtlas, tile, glyph.bounds, inkPaint);
        canvas.saveLayer(glyph.bounds, Paint()..blendMode = BlendMode.dstIn);
        final ink = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = glyph.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        var remaining = glyph.length * amount;
        for (final metric in glyph.metrics) {
          final length = math.min(remaining, metric.length);
          if (length <= 0) break;
          canvas.drawPath(metric.extractPath(0, length), ink);
          remaining -= length;
        }
        canvas.restore();
        canvas.restore();
      }
      canvas.restore();
    }
    if (glossyFinish > 0) {
      canvas.drawImageRect(
        image,
        source,
        artwork,
        Paint()
          ..color = Color.fromRGBO(255, 255, 255, glossyFinish)
          ..filterQuality = FilterQuality.high,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoInkPainter oldDelegate) =>
      image != oldDelegate.image ||
      inkAtlas != oldDelegate.inkAtlas ||
      animation != oldDelegate.animation;
}
