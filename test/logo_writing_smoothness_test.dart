import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:apna_pos/features/auth/widgets/logo_writing_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('completed letters do not pop into a different silhouette', (
    tester,
  ) async {
    final key = GlobalKey();
    Future<Uint8List> render(double milliseconds, {String? capturePath}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: Colors.white,
                child: LogoWritingReveal(
                  animation: AlwaysStoppedAnimation(milliseconds / 3600),
                  size: 300,
                ),
              ),
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(LogoWritingReveal));
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage(LogoWritingReveal.assetPath),
          context,
        );
        await precacheImage(
          const AssetImage(LogoWritingReveal.inkAssetPath),
          context,
        );
      });
      await tester.pump();
      late Uint8List result;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        result = Uint8List.fromList(bytes!.buffer.asUint8List());
        if (capturePath != null) {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File(capturePath).writeAsBytesSync(png!.buffer.asUint8List());
        }
        image.dispose();
      });
      return result;
    }

    final deltas = <double>[];
    final boundaries = <double>[
      for (var letter = 0; letter < 14; letter++)
        100 + (letter % 7) * 320 + (letter < 7 ? 280 : 360),
      3000,
      3040,
      3500,
    ];
    for (final end in boundaries) {
      // Cover both the former pop boundaries and the current completion times.
      final before = await render(end - 0.1);
      final after = await render(end + 0.1);
      var difference = 0;
      for (var pixel = 0; pixel < before.length; pixel++) {
        difference += (before[pixel] - after[pixel]).abs();
      }
      deltas.add(difference / before.length);
    }
    final directory = Platform.environment['SPLASH_SMOOTHNESS_DIR'];
    if (directory != null) {
      Directory(directory).createSync(recursive: true);
      File(
        '$directory/letter-completion-deltas.json',
      ).writeAsStringSync(jsonEncode(deltas));
    }
    expect(
      deltas,
      everyElement(lessThan(0.05)),
      reason: 'A 0.2ms boundary must not suddenly fill missing letter areas.',
    );
    if (directory != null &&
        Platform.environment['SPLASH_CAPTURE_ANIMATION'] == 'true') {
      for (var frame = 0; frame <= 216; frame++) {
        await render(
          frame * 1000 / 60,
          capturePath:
              '$directory/frame-${frame.toString().padLeft(3, '0')}.png',
        );
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
