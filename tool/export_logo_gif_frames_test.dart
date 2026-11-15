// Render the app's actual logo painter for a GIF export:
// flutter test tool/export_logo_gif_frames_test.dart
// PNG frames are written to build/logo_gif/frames.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:apna_pos/features/auth/widgets/logo_writing_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('render the branded writing animation for export', (
    tester,
  ) async {
    const canvasSize = 600.0;
    const stepMilliseconds = 40; // 25 fps, exactly representable by GIF timing.
    const firstMilliseconds = 144; // Match the app's first visible ink frame.
    final output = Directory('build/logo_gif/frames')
      ..createSync(recursive: true);
    final key = GlobalKey();
    final animation = ValueNotifier<double>(0);
    addTearDown(animation.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(canvasSize, canvasSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFFF7F9FE),
            child: Center(
              child: ValueListenableBuilder<double>(
                valueListenable: animation,
                builder: (context, progress, child) => LogoWritingReveal(
                  animation: AlwaysStoppedAnimation(progress),
                  size: 440,
                ),
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

    final duration = LogoWritingReveal.duration.inMilliseconds;
    final frameCount = ((duration - firstMilliseconds) / stepMilliseconds)
        .ceil();
    for (var frame = 0; frame <= frameCount; frame++) {
      final milliseconds = (firstMilliseconds + frame * stepMilliseconds).clamp(
        0,
        duration,
      );
      animation.value = milliseconds / duration;
      await tester.pump();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '${output.path}/frame-${frame.toString().padLeft(3, '0')}.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(output.listSync().whereType<File>().length, frameCount + 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
