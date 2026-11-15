import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'logo_writing_reveal.dart';

/// The first Flutter frame is branded; the original logo is then written in ink.
class SplashBrandView extends StatelessWidget {
  static const backgroundColor = Color(0xFFF7F9FE);
  static const logoAsset = LogoWritingReveal.assetPath;
  static const _blue = Color(0xFF0758F5);
  static const _ink = Color(0xFF102548);

  final Animation<double> animation;
  final bool isPreparing;

  const SplashBrandView({
    super.key,
    required this.animation,
    this.isPreparing = false,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final entrance = reduceMotion
        ? const AlwaysStoppedAnimation<double>(1)
        : animation;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: backgroundColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.65, -0.65),
              radius: 1.4,
              colors: [Color(0xFFEAF1FF), backgroundColor, Color(0xFFFEFFFF)],
              stops: [0, 0.5, 1],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 500;
                final inset = compact ? 20.0 : 32.0;
                final logoSize = math.min(
                  constraints.maxWidth * 0.62,
                  compact ? 132.0 : 232.0,
                );

                return AnimatedBuilder(
                  animation: entrance,
                  child: LogoWritingReveal(animation: entrance, size: logoSize),
                  builder: (context, logo) {
                    final progress = entrance.value.clamp(0.0, 1.0);
                    final captions = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _WritingText(
                          text: 'SMART RESTAURANT POS',
                          progress: _phase(progress, 0.58, 0.78),
                          style: const TextStyle(
                            color: _blue,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.4,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: compact ? 10 : 16),
                        _WritingText(
                          text: compact
                              ? 'Smart billing. Better business.'
                              : 'Smart billing.\nBetter business.',
                          progress: _phase(progress, 0.87, 0.98),
                          style: TextStyle(
                            color: _ink,
                            fontSize: compact ? 19 : 29,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.7,
                            height: 1.25,
                          ),
                        ),
                      ],
                    );
                    final footer = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 92,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              minHeight: 2,
                              value:
                                  progress >= 1 && isPreparing && !reduceMotion
                                  ? null
                                  : progress,
                              color: _blue,
                              backgroundColor: const Color(0xFFDCE6FA),
                              semanticsLabel: 'Opening Apna POS',
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _WritingText(
                          text: 'BILLING  /  ORDERS  /  INSIGHTS',
                          progress: _phase(progress, 0.90, 1),
                          style: const TextStyle(
                            color: Color(0xFF6B7B94),
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.7,
                            height: 1.5,
                          ),
                        ),
                        if (progress >= 1 && isPreparing) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Preparing your workspace...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF6B7B94),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    );
                    // Anchor the artwork itself to the center. Captions and a
                    // changing preparation footer must not move the wordmark.
                    if (constraints.maxHeight >= 700 &&
                        MediaQuery.textScalerOf(context).scale(1) <= 1.2) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(child: logo),
                          Positioned(
                            top: constraints.maxHeight / 2 + logoSize / 2 + 28,
                            left: 28,
                            right: 28,
                            child: RepaintBoundary(child: captions),
                          ),
                          Positioned(
                            bottom: inset,
                            left: 28,
                            right: 28,
                            child: RepaintBoundary(child: footer),
                          ),
                        ],
                      );
                    }
                    // Short windows and enlarged text retain a centered,
                    // scrollable composition without overlapping the footer.
                    return Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: inset,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(
                              0,
                              constraints.maxHeight - inset * 2,
                            ),
                            maxWidth: 480,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              logo!,
                              SizedBox(height: compact ? 16 : 28),
                              RepaintBoundary(child: captions),
                              const SizedBox(height: 32),
                              RepaintBoundary(child: footer),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  double _phase(double progress, double start, double end) =>
      ((progress - start) / (end - start)).clamp(0.0, 1.0);
}

/// Reserve each complete line's height while centering only the visible ink.
class _WritingText extends StatelessWidget {
  final String text;
  final double progress;
  final TextStyle style;

  const _WritingText({
    required this.text,
    required this.progress,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final count = (text.length * progress).floor().clamp(0, text.length);
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          var offset = 0;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: text.split('\n').map((line) {
              final visible = (count - offset).clamp(0, line.length);
              offset += line.length + 1;
              final painter = TextPainter(
                text: TextSpan(text: line, style: effectiveStyle),
                textDirection: Directionality.of(context),
                textAlign: TextAlign.center,
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: constraints.maxWidth);
              final height = painter.height;
              painter.dispose();
              return SizedBox(
                width: constraints.maxWidth,
                height: height,
                child: Center(
                  child: Text(
                    line.substring(0, visible),
                    style: style,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
