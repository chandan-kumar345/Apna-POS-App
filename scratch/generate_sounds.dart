import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void generateWavFile(String filePath, {required double frequency, required double durationMs, required double decayFactor, required double amplitude}) {
  final int sampleRate = 44100;
  final int numSamples = (sampleRate * (durationMs / 1000.0)).round();
  final int dataSize = numSamples * 2; // 16-bit PCM mono
  final int fileSize = 36 + dataSize;

  final bytes = ByteData(44 + dataSize);

  // RIFF header
  bytes.setUint8(0, 0x52); // R
  bytes.setUint8(1, 0x49); // I
  bytes.setUint8(2, 0x46); // F
  bytes.setUint8(3, 0x46); // F
  bytes.setUint32(4, fileSize, Endian.little);
  bytes.setUint8(8, 0x57);  // W
  bytes.setUint8(9, 0x41);  // A
  bytes.setUint8(10, 0x56); // V
  bytes.setUint8(11, 0x45); // E

  // fmt chunk
  bytes.setUint8(12, 0x66); // f
  bytes.setUint8(13, 0x6d); // m
  bytes.setUint8(14, 0x74); // t
  bytes.setUint8(15, 0x20); // ' '
  bytes.setUint32(16, 16, Endian.little); // chunk size
  bytes.setUint16(20, 1, Endian.little);  // PCM format
  bytes.setUint16(22, 1, Endian.little);  // Mono
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
  bytes.setUint16(32, 2, Endian.little);  // Block align
  bytes.setUint16(34, 16, Endian.little); // Bits per sample

  // data chunk
  bytes.setUint8(36, 0x64); // d
  bytes.setUint8(37, 0x61); // a
  bytes.setUint8(38, 0x74); // t
  bytes.setUint8(39, 0x61); // a
  bytes.setUint32(40, dataSize, Endian.little);

  // Generate PCM samples - ultra-fast exponential decay for lighter iOS tick sound
  int offset = 44;
  for (int i = 0; i < numSamples; i++) {
    double t = i / sampleRate;
    double envelope = exp(-t * decayFactor);
    double val = (sin(2 * pi * frequency * t) * 0.8 + sin(2 * pi * (frequency * 1.5) * t) * 0.2) * envelope * amplitude;
    int sample = val.clamp(-32768.0, 32767.0).round();
    bytes.setInt16(offset, sample, Endian.little);
    offset += 2;
  }

  final file = File(filePath);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes.buffer.asUint8List());
  print('Generated $filePath (${file.lengthSync()} bytes)');
}

void main() {
  // Ultra-light, fast iOS button click sound (2200Hz, 8ms duration, steep decay)
  generateWavFile(
    'assets/sounds/ios_click.wav',
    frequency: 2200.0,
    durationMs: 8.0,
    decayFactor: 800.0,
    amplitude: 11000.0,
  );

  // Soft & feather-light iOS keypress click (3200Hz, 6ms duration, steep decay)
  generateWavFile(
    'assets/sounds/ios_keypress.wav',
    frequency: 3200.0,
    durationMs: 6.0,
    decayFactor: 1100.0,
    amplitude: 7500.0,
  );
}
