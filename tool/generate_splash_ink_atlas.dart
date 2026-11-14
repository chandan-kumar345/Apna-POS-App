import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

/// Build isolated ink glyphs for the supplied logo, without neighboring pieces.
/// Run: dart run tool/generate_splash_ink_atlas.dart
void main() {
  final source = img.decodePng(
    File('assets/images/android_launcher_logo.png').readAsBytesSync(),
  )!;
  final ownership = img.decodePng(
    File('tool/branding/logo_ink_ownership.png').readAsBytesSync(),
  )!;
  final glyphs =
      jsonDecode(File('tool/branding/logo_ink_strokes.json').readAsStringSync())
          as List<dynamic>;
  const tileSize = 512;
  final atlas = img.Image(
    width: tileSize * 3,
    height: tileSize * 3,
    numChannels: 4,
  );
  for (var index = 0; index < glyphs.length; index++) {
    final rect = List<int>.from(glyphs[index]['rect'] as List);
    final glyph = img.Image(width: rect[2], height: rect[3], numChannels: 4);
    for (final pixel in glyph) {
      final x = rect[0] + pixel.x;
      final y = rect[1] + pixel.y;
      final owner = ownership.getPixel(
        x * ownership.width ~/ source.width,
        y * ownership.height ~/ source.height,
      );
      if ((owner.r / 25).round() != index + 1) continue;
      final original = source.getPixel(x, y);
      if (index < 4) {
        pixel.setRgba(6, 38, 92, original.a);
      } else if (index < 8) {
        pixel.setRgba(7, 88, 245, original.a);
      } else {
        pixel.set(original);
      }
    }
    final tile = img.copyResize(
      glyph,
      width: tileSize,
      height: tileSize,
      interpolation: img.Interpolation.cubic,
    );
    img.compositeImage(
      atlas,
      tile,
      dstX: index % 3 * tileSize,
      dstY: index ~/ 3 * tileSize,
    );
  }
  File(
    'assets/images/apna_pos_logo_ink_atlas.png',
  ).writeAsBytesSync(img.encodePng(atlas));
  stdout.writeln(
    'Generated 9 isolated handwriting glyphs in the splash ink atlas.',
  );
}
