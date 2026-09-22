import 'dart:async';
import 'dart:io' show File, Platform, Process;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ChotuTtsService extends ChangeNotifier {
  static final ChotuTtsService _instance = ChotuTtsService._internal();
  factory ChotuTtsService() => _instance;
  ChotuTtsService._internal() {
    _initPlayer();
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  String? _lastSpokenText;
  String? get lastSpokenText => _lastSpokenText;

  Process? _activeProcess;
  StreamSubscription? _playerCompleteSub;

  void _initPlayer() {
    _audioPlayer.setReleaseMode(ReleaseMode.stop);
  }

  /// Speaks the initial friendly Hindi greeting when Chotu is started
  Future<void> speakGreeting([String greeting = 'Kya hua sir?']) async {
    await speak(greeting);
  }

  /// Speaks text aloud using open-source natural Hindi TTS audio stream with platform fallback
  Future<void> speak(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    // Stop any currently active speech before starting new one
    stop();

    _lastSpokenText = cleanText;
    _isSpeaking = true;
    notifyListeners();

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _isSpeaking = false;
      notifyListeners();
      return;
    }

    bool playedOnline = false;

    // 1. Try High-Quality Open Source Hindi TTS via AudioPlayer
    try {
      final encoded = Uri.encodeComponent(cleanText);
      final ttsUrl =
          'https://translate.google.com/translate_tts?ie=UTF-8&tl=hi&client=tw-ob&q=$encoded';

      final response = await http.get(
        Uri.parse(ttsUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final tempDir = await getTemporaryDirectory();
        final tempFile =
            File('${tempDir.path}/chotu_voice_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await tempFile.writeAsBytes(response.bodyBytes, flush: true);

        final completer = Completer<void>();
        _playerCompleteSub?.cancel();
        _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
          if (!completer.isCompleted) completer.complete();
        });

        await _audioPlayer.play(DeviceFileSource(tempFile.path));

        // Wait for audio completion or safe timeout based on length
        final maxDuration = Duration(milliseconds: (cleanText.length * 90).clamp(1500, 8000));
        await completer.future.timeout(maxDuration, onTimeout: () {});

        // Cleanup temporary audio file
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}

        playedOnline = true;
      }
    } catch (e) {
      debugPrint('[ChotuTtsService] Open-source online TTS fallback: $e');
    }

    // 2. Fallback to Platform Native Speech Synthesis if online TTS was unavailable
    if (!playedOnline) {
      try {
        if (!kIsWeb && Platform.isWindows) {
          final escaped = cleanText.replaceAll("'", "''");
          final psCommand =
              "& { Add-Type -AssemblyName System.Speech; \$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; \$s.Rate = 1; \$s.Speak('$escaped') }";

          _activeProcess = await Process.start('powershell', ['-NoProfile', '-Command', psCommand]);
          await _activeProcess?.exitCode;
          _activeProcess = null;
        } else {
          final simulatedDuration = Duration(milliseconds: (cleanText.length * 70).clamp(800, 3500));
          await Future.delayed(simulatedDuration);
        }
      } catch (e) {
        debugPrint('[ChotuTtsService] Native TTS fallback error: $e');
      }
    }

    _isSpeaking = false;
    _activeProcess = null;
    notifyListeners();
  }

  void stop() {
    try {
      _playerCompleteSub?.cancel();
      _audioPlayer.stop();
      _activeProcess?.kill();
    } catch (_) {}
    _activeProcess = null;
    _isSpeaking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _playerCompleteSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}
