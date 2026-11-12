import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Regenerate Android launcher resources from the transparent logo:
/// dart run tool/generate_android_launcher_icons.dart
void main() {
  final decoded = img.decodePng(
    File('assets/images/android_launcher_logo.png').readAsBytesSync(),
  );
  if (decoded == null) {
    throw StateError('The Android launcher logo must be a PNG.');
  }
  final source = trimTransparentPadding(decoded);
  final radius = artworkRadius(source);
  final longestEdge = math.max(source.width, source.height);

  const densities = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  };

  for (final density in densities.entries) {
    final scale = density.value;
    final size = (48 * scale).round();
    final directory = Directory(
      'android/app/src/main/res/mipmap-${density.key}',
    )..createSync(recursive: true);

    writeIcon(directory, 'ic_launcher', centeredLogo(source, size, 46 * scale));

    // Preserve transparency and fit the actual silhouette inside a round mask.
    final roundLogoSize = longestEdge * (23.7 * scale) / radius;
    writeIcon(
      directory,
      'ic_launcher_round',
      centeredLogo(source, size, roundLogoSize),
    );

    // Fit the actual artwork within the 66dp safe circle of the 108dp layer.
    // This keeps the lettering and receipt visible under different OEM masks.
    // https://developer.android.com/develop/ui/compose/system/icon_design_adaptive
    // Leave a fraction of a dp for antialiased edge pixels after downsampling.
    final adaptiveLogoSize = longestEdge * (32.8 * scale) / radius;
    writeIcon(
      directory,
      'ic_launcher_foreground',
      centeredLogo(source, (108 * scale).round(), adaptiveLogoSize),
    );

    final splashDirectory = Directory(
      'android/app/src/main/res/drawable-${density.key}',
    )..createSync(recursive: true);
    writeIcon(
      splashDirectory,
      'splash_logo',
      centeredLogo(source, (224 * scale).round(), 208 * scale),
    );
    // Android 12+: 288dp icon canvas with artwork inside a 192dp circle.
    // https://developer.android.com/develop/ui/views/launch/splash-screen
    writeIcon(
      splashDirectory,
      'splash_icon',
      centeredLogo(
        source,
        (288 * scale).round(),
        longestEdge * (94 * scale) / radius,
      ),
    );
  }

  stdout.writeln(
    'Generated launcher icons and native splash artwork at 5 densities.',
  );
}

img.Image trimTransparentPadding(img.Image source) {
  var left = source.width;
  var top = source.height;
  var right = -1;
  var bottom = -1;
  for (final pixel in source) {
    if (pixel.a < 16) continue;
    left = math.min(left, pixel.x);
    top = math.min(top, pixel.y);
    right = math.max(right, pixel.x);
    bottom = math.max(bottom, pixel.y);
  }
  if (right < left || bottom < top) {
    throw StateError('The Android launcher logo is fully transparent.');
  }
  return img.copyCrop(
    source,
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
}

double artworkRadius(img.Image source) {
  final centerX = (source.width - 1) / 2;
  final centerY = (source.height - 1) / 2;
  var radiusSquared = 0.0;
  for (final pixel in source) {
    if (pixel.a < 16) continue;
    final dx = pixel.x - centerX;
    final dy = pixel.y - centerY;
    radiusSquared = math.max(radiusSquared, dx * dx + dy * dy);
  }
  return math.sqrt(radiusSquared);
}

img.Image centeredLogo(img.Image source, int size, double logoSize) {
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  final longestEdge = math.max(source.width, source.height);
  final scale = logoSize / longestEdge;
  final logo = img.copyResize(
    source,
    width: (source.width * scale).floor(),
    height: (source.height * scale).floor(),
    interpolation: img.Interpolation.average,
  );
  return img.compositeImage(canvas, logo, center: true);
}

void writeIcon(Directory directory, String name, img.Image icon) {
  File('${directory.path}/$name.png').writeAsBytesSync(img.encodePng(icon));
}
