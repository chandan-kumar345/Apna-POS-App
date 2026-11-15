import 'dart:convert';
import 'dart:ui' as ui;

import 'package:apna_pos/core/models/menu_item_model.dart';
import 'package:apna_pos/features/pos/widgets/pos_product_media_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [const Size(800, 400), const Size(400, 800)]) {
    testWidgets('decoded product photo preserves proportions at $size', (
      tester,
    ) async {
      final bytes = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(
          recorder,
        ).drawRect(Offset.zero & size, Paint()..color = Colors.orange);
        final picture = recorder.endRecording();
        final image = await picture.toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        picture.dispose();
        return png!.buffer.asUint8List();
      });
      final provider = ResizeImage(MemoryImage(bytes!), width: 480);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 180,
              child: PosProductMediaBox(
                item: MenuItemModel(
                  id: 'photo',
                  name: 'Photo',
                  category: 'Food',
                  price: 10,
                  description: '',
                  imageUrl: 'data:image/png;base64,${base64Encode(bytes)}',
                ),
                fit: BoxFit.contain,
                showDots: false,
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          provider,
          tester.element(find.byType(PosProductMediaBox)),
        ),
      );
      await tester.pumpAndSettle();
      final decoded = tester.widget<RawImage>(find.byType(RawImage)).image!;
      expect(
        decoded.width / decoded.height,
        closeTo(size.width / size.height, .01),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
