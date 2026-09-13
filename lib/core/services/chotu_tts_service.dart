import 'dart:async';
import 'dart:io' show Platform, Process;
import 'package:flutter/foundation.dart';

class ChotuTtsService extends ChangeNotifier {
  static final ChotuTtsService _instance = ChotuTtsService._internal();
  factory ChotuTtsService() => _instance;
  ChotuTtsService._internal();

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  String? _lastSpokenText;
  String? get lastSpokenText => _lastSpokenText;

  Process? _activeProcess;

  /// Speaks text aloud using platform native speech synthesis
  Future<void> speak(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    _lastSpokenText = cleanText;
    _isSpeaking = true;
    notifyListeners();

    try {
      if (!kIsWeb && Platform.isWindows) {
        // Escape single quotes for PowerShell
        final escaped = cleanText.replaceAll("'", "''");
        final psCommand =
            "& { Add-Type -AssemblyName System.Speech; \$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; \$s.Rate = 0; \$s.Speak('$escaped') }";

        await Process.run('powershell', ['-NoProfile', '-Command', psCommand]);
      } else {
        debugPrint('[ChotuTtsService] Speak (visual/log on non-windows platform): $cleanText');
      }
    } catch (e) {
      debugPrint('[ChotuTtsService] Error speaking: $e');
    } finally {
      _isSpeaking = false;
      notifyListeners();
    }
  }

  void stop() {
    _activeProcess?.kill();
    _activeProcess = null;
    _isSpeaking = false;
    notifyListeners();
  }
}
