import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Ultra-fast background image compression utility
/// Resizes and converts images to lightweight, web-optimized JPEGs
/// without blocking the UI thread (runs in background isolate via compute).
class ImageCompressHelper {
  /// Compresses [rawBytes] to maximum [maxWidth] x [maxHeight] at [quality] (1-100).
  /// Skips compression if image is already small (<160KB).
  static Future<Uint8List> compressImageBytes(
    Uint8List rawBytes, {
    int maxWidth = 1024,
    int maxHeight = 1024,
    int quality = 82,
  }) async {
    // If the image is already lightweight (<160KB), don't waste CPU cycles re-encoding
    if (rawBytes.lengthInBytes < 160 * 1024) {
      return rawBytes;
    }

    try {
      final compressed = await compute(_compressImageIsolate, {
        'bytes': rawBytes,
        'maxWidth': maxWidth,
        'maxHeight': maxHeight,
        'quality': quality,
      });
      return compressed;
    } catch (e) {
      debugPrint('[ImageCompressHelper] Compression error, using original: $e');
      return rawBytes;
    }
  }

  /// Compresses [file] and returns compressed bytes.
  static Future<Uint8List> compressImageFile(
    File file, {
    int maxWidth = 1024,
    int maxHeight = 1024,
    int quality = 82,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      return await compressImageBytes(
        bytes,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        quality: quality,
      );
    } catch (e) {
      debugPrint('[ImageCompressHelper] Error reading file for compression: $e');
      return await file.readAsBytes();
    }
  }

  /// Background isolate entrypoint
  static Uint8List _compressImageIsolate(Map<String, dynamic> params) {
    final Uint8List bytes = params['bytes'];
    final int maxWidth = params['maxWidth'];
    final int maxHeight = params['maxHeight'];
    final int quality = params['quality'];

    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    img.Image resized = decoded;
    if (decoded.width > maxWidth || decoded.height > maxHeight) {
      if (decoded.width >= decoded.height) {
        resized = img.copyResize(decoded, width: maxWidth, interpolation: img.Interpolation.linear);
      } else {
        resized = img.copyResize(decoded, height: maxHeight, interpolation: img.Interpolation.linear);
      }
    }

    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }
}
