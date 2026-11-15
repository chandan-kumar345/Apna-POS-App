import 'dart:io';
import 'dart:ui' as ui;

import 'package:apna_pos/features/auth/widgets/logo_writing_reveal.dart';
import 'package:apna_pos/features/auth/widgets/splash_brand_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final fonts = Platform.environment['SPLASH_CAPTURE_FONT_DIR'];
    if (fonts != null) {
      final loader = FontLoader('Roboto');
      for (final name in [
        'roboto-regular.ttf',
        'roboto-medium.ttf',
        'roboto-bold.ttf',
      ]) {
        final bytes = File('$fonts/$name').readAsBytesSync();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
      }
      await loader.load();
    }
  });
  testWidgets('writing ticks retain the background and logo widgets', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: tester,
      duration: LogoWritingReveal.duration,
    );
    await tester.pumpWidget(
      MaterialApp(home: SplashBrandView(animation: controller)),
    );
    final background = tester.widget<Scaffold>(find.byType(Scaffold));
    final wordmark = tester.widget<LogoWritingReveal>(
      find.byType(LogoWritingReveal),
    );
    controller.value = 0.35;
    await tester.pump();
    expect(
      identical(background, tester.widget<Scaffold>(find.byType(Scaffold))),
      isTrue,
    );
    expect(
      identical(
        wordmark,
        tester.widget<LogoWritingReveal>(find.byType(LogoWritingReveal)),
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets('writing and captions stay centered at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final captureKey = GlobalKey();

      for (final progress in [0.2, 0.65, 0.7, 0.93, 1.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: captureKey,
              child: SplashBrandView(
                animation: AlwaysStoppedAnimation(progress),
                isPreparing: progress == 1,
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
        final logo = tester.getRect(find.byType(LogoWritingReveal));
        expect(logo.center.dx, closeTo(size.width / 2, 0.01));
        expect(logo.center.dy, closeTo(size.height / 2, 0.01));
        for (final element in find.byType(Text).evaluate()) {
          final text = element.widget as Text;
          if (text.data?.isNotEmpty != true) continue;
          expect(
            tester.getRect(find.byWidget(text)).center.dx,
            closeTo(size.width / 2, 0.01),
            reason: text.data,
          );
        }
        expect(tester.takeException(), isNull);

        final directory = Platform.environment['SPLASH_CAPTURE_DIR'];
        if (directory != null && size.width == 390) {
          await tester.runAsync(() async {
            final boundary =
                captureKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            Directory(directory).createSync(recursive: true);
            File(
              '$directory/centered-${(progress * 100).round()}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
