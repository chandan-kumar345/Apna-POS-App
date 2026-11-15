import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, Process;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

enum SpeechStatus { idle, listening, processing, done, error }

class SpeechRecognitionService extends ChangeNotifier {
  static final SpeechRecognitionService _instance = SpeechRecognitionService._internal();
  factory SpeechRecognitionService() => _instance;
  SpeechRecognitionService._internal();

  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isSttInitialized = false;

  SpeechStatus _status = SpeechStatus.idle;
  SpeechStatus get status => _status;
  bool get isListening => _status == SpeechStatus.listening;

  String _currentLocale = 'hinglish'; // 'hinglish', 'hi_IN', 'en_IN'
  String get currentLocale => _currentLocale;

  String _liveTranscription = '';
  String get liveTranscription => _liveTranscription;

  double _audioLevel = 0.0; // 0.0 to 1.0 (Google Voice Search equalizer)
  double get audioLevel => _audioLevel;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  Process? _activeProcess;
  StreamSubscription? _stdoutSub;
  Timer? _silenceTimer;
  Timer? _speechTimeoutTimer;
  int _generation = 0;
  bool _starting = false;

  void setLocale(String locale) {
    _currentLocale = locale;
    notifyListeners();
  }

  /// Request microphone permission on Android/iOS devices
  Future<bool> requestMicrophonePermission() async {
    if (kIsWeb) return true;
    try {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        final current = await Permission.microphone.status;
        if (current.isGranted) return true;
        if (!current.isDenied) return false;
        return (await Permission.microphone.request()).isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('[SpeechRecognitionService] Permission check error: $e');
      return !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    }
  }

  /// Start listening for voice input from default microphone
  Future<void> startListening({
    String? initialText,
    Duration timeout = const Duration(seconds: 16),
  }) async {
    if (_starting) return;
    // Stop any existing session
    final generation = ++_generation;
    _starting = true;
    _silenceTimer?.cancel();
    _speechTimeoutTimer?.cancel();
    _cleanupProcess();
    _status = SpeechStatus.idle;
    _liveTranscription = '';

    // 1. Ensure microphone permission is granted on mobile devices
    final hasPermission = await requestMicrophonePermission();
    if (generation != _generation) return;
    if (!hasPermission) {
      _starting = false;
      setError('Microphone access is off. Enable it in phone settings or type your order.');
      return;
    }

    _status = SpeechStatus.listening;
    _liveTranscription = initialText ?? '';
    _audioLevel = 0.0;
    _errorMessage = '';
    notifyListeners();

    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      _starting = false;
      return;
    }

    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      // Use on-device Android/iOS Speech-to-Text plugin
      await _startMobileSpeechRecognition(generation);
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      // Use Python Voice Engine with native PowerShell fallback on Windows
      final pythonSuccess = await _tryStartPythonVoiceEngine();
      if (!pythonSuccess) {
        _cleanupProcess();
        await _startWindowsNativeMicrophoneListener();
      }
    } else {
      setError('Voice recognition is unavailable on this platform. Type your order instead.');
    }
    _starting = false;
    if (generation == _generation && _status == SpeechStatus.listening) {
      _speechTimeoutTimer = Timer(timeout, stopListening);
    }
  }

  /// Starts native Android/iOS Speech-to-Text with intelligent locale discovery & natural VAD
  Future<void> _startMobileSpeechRecognition(int generation) async {
    try {
      if (!_isSttInitialized) {
        _isSttInitialized = await _speechToText.initialize(
          onStatus: (status) {
            debugPrint('[SpeechRecognitionService:Mobile] Status: $status');
            if (status == 'done' || status == 'notListening') {
              if (_starting) return;
              if (_liveTranscription.trim().isNotEmpty) {
                _onSpeechCompleted();
              } else if (_status == SpeechStatus.listening) {
                _status = SpeechStatus.idle;
                _audioLevel = 0.0;
                notifyListeners();
              }
            }
          },
          onError: (err) {
            debugPrint('[SpeechRecognitionService:Mobile] Error: ${err.errorMsg}');
            if (err.errorMsg == 'error_no_match' || err.errorMsg == 'error_speech_timeout') {
              if (_liveTranscription.trim().isNotEmpty) {
                _onSpeechCompleted();
              } else {
                setError('No speech detected. Tap the microphone to retry or type your order.');
              }
            } else {
              setError('Voice recognition notice: ${err.errorMsg}');
            }
          },
        );

        if (!_isSttInitialized) {
          setError('Speech recognition service not ready on this device. Please check microphone permission.');
          return;
        }
      }

      if (_isSttInitialized) {
        if (generation != _generation) return;
        String? targetLocaleId;
        try {
          final locales = await _speechToText.locales();
          if (_currentLocale == 'hi_IN' || _currentLocale == 'hinglish') {
            final hiLocale = locales.where((l) => l.localeId.toLowerCase().startsWith('hi')).firstOrNull;
            if (hiLocale != null) {
              targetLocaleId = hiLocale.localeId;
            } else {
              final enInLocale = locales.where((l) => l.localeId.toLowerCase().replaceAll('-', '_') == 'en_in').firstOrNull;
              targetLocaleId = enInLocale?.localeId;
            }
          } else if (_currentLocale == 'en_IN') {
            final enInLocale = locales.where((l) => l.localeId.toLowerCase().replaceAll('-', '_') == 'en_in').firstOrNull;
            targetLocaleId = enInLocale?.localeId;
          }
        } catch (e) {
          debugPrint('[SpeechRecognitionService:Mobile] Locale check: $e');
        }

        await _speechToText.listen(
          onResult: (result) {
            if (generation != _generation || _status != SpeechStatus.listening) return;
            final words = result.recognizedWords.trim();
            if (words.isNotEmpty) {
              _liveTranscription = words;
              _audioLevel = 0.85;
              notifyListeners();

              if (result.finalResult) {
                _onSpeechCompleted();
              }
            }
          },
          onSoundLevelChange: (level) {
            if (generation != _generation || !isListening) return;
            _audioLevel = ((level + 2) / 12).clamp(0.0, 1.0);
            notifyListeners();
          },
          listenOptions: stt.SpeechListenOptions(
            localeId: targetLocaleId,
            listenMode: stt.ListenMode.dictation,
            cancelOnError: false,
            partialResults: true,
            pauseFor: const Duration(milliseconds: 2800),
            listenFor: const Duration(seconds: 30),
          ),
        ).timeout(const Duration(seconds: 12));
      }
    } catch (e) {
      debugPrint('[SpeechRecognitionService:Mobile] STT start failed: $e');
      setError('Voice recognition could not start: $e');
    }
  }

  /// Tries starting the high-accuracy Python voice engine with ambient noise filter & fast VAD
  Future<bool> _tryStartPythonVoiceEngine() async {
    try {
      final ready = Completer<bool>();
      _activeProcess = await Process.start(
        'python',
        ['scripts/chotu_voice_engine.py'],
        runInShell: false,
      );

      _stdoutSub = _activeProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) return;

          debugPrint('[SpeechRecognitionService:Python] $trimmed');

          try {
            final data = jsonDecode(trimmed) as Map<String, dynamic>;
            final statusStr = data['status']?.toString();

            if (statusStr == 'READY' || statusStr == 'LISTENING') {
              if (!ready.isCompleted) ready.complete(true);
              _audioLevel = 0.35;
              notifyListeners();
            } else if (statusStr == 'PROCESSING') {
              _audioLevel = 0.70;
              notifyListeners();
            } else if (statusStr == 'PARTIAL') {
              final partial = data['text']?.toString() ?? '';
              if (partial.trim().isNotEmpty) {
                _liveTranscription = partial.trim();
                _audioLevel = 0.85;
                notifyListeners();
                _restartSilenceTimer();
              }
            } else if (statusStr == 'RECOGNIZED') {
              final recognized = data['text']?.toString() ?? '';
              if (recognized.trim().isNotEmpty) {
                _liveTranscription = recognized.trim();
                _onSpeechCompleted();
              } else {
                _status = SpeechStatus.idle;
                notifyListeners();
              }
            } else if (statusStr == 'SILENCE') {
              if (_liveTranscription.trim().isNotEmpty) {
                _onSpeechCompleted();
              } else {
                _status = SpeechStatus.idle;
                _audioLevel = 0.0;
                notifyListeners();
              }
            } else if (statusStr == 'ERROR') {
              if (!ready.isCompleted) {
                ready.complete(false);
              } else if (isListening) {
                setError('Voice engine failed. Retry the microphone or type your order.');
              }
              debugPrint('[SpeechRecognitionService:Python] Error: ${data['message']}');
            }
          } catch (_) {}
        },
        onError: (err) {
          debugPrint('[SpeechRecognitionService:Python] Process error: $err');
        },
        onDone: () {
          if (!ready.isCompleted) ready.complete(false);
          if (_status == SpeechStatus.listening && _liveTranscription.trim().isNotEmpty) {
            _onSpeechCompleted();
          }
        },
      );

      return await ready.future.timeout(const Duration(seconds: 5), onTimeout: () => false);
    } catch (e) {
      debugPrint('[SpeechRecognitionService] Python voice engine launch failed: $e');
      return false;
    }
  }

  /// Fallback: Starts Windows native microphone recognition via System.Speech.Recognition
  Future<void> _startWindowsNativeMicrophoneListener() async {
    try {
      final psScript = r'''
Add-Type -AssemblyName System.Speech;
$engine = New-Object System.Speech.Recognition.SpeechRecognitionEngine;
try {
  $engine.SetInputToDefaultAudioDevice();
} catch {
  [System.Console]::WriteLine("NO_MIC");
  [System.Console]::Out.Flush();
  exit 0;
}

$engine.InitialSilenceTimeout = [TimeSpan]::FromSeconds(5);
$engine.EndSilenceTimeout = [TimeSpan]::FromMilliseconds(700);
$engine.EndSilenceTimeoutAmbiguous = [TimeSpan]::FromMilliseconds(700);
$engine.BabbleTimeout = [TimeSpan]::FromMilliseconds(0);

$grammar = New-Object System.Speech.Recognition.DictationGrammar;
$engine.LoadGrammar($grammar);

Register-ObjectEvent -InputObject $engine -EventName SpeechHypothesized -Action {
  if ($EventArgs.Result -and $EventArgs.Result.Confidence -ge 0.15) {
    [System.Console]::WriteLine("PARTIAL:" + $EventArgs.Result.Text.Trim());
    [System.Console]::Out.Flush();
  }
};

Register-ObjectEvent -InputObject $engine -EventName AudioLevelUpdated -Action {
  [System.Console]::WriteLine("LEVEL:" + $EventArgs.AudioLevel);
  [System.Console]::Out.Flush();
};

[System.Console]::WriteLine("READY");
[System.Console]::Out.Flush();

$res = $engine.Recognize([TimeSpan]::FromSeconds(10));
if ($res -ne $null -and $res.Confidence -ge 0.18 -and $res.Text.Trim().Length -gt 0) {
  [System.Console]::WriteLine("FINAL:" + $res.Text.Trim());
} else {
  [System.Console]::WriteLine("SILENCE");
}
[System.Console]::Out.Flush();
''';

      _activeProcess = await Process.start(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', psScript],
      );

      _stdoutSub = _activeProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) return;

          if (trimmed.startsWith('FINAL:')) {
            final recognized = trimmed.substring(6).trim();
            if (recognized.isNotEmpty) {
              _liveTranscription = recognized;
              _onSpeechCompleted();
            }
          } else if (trimmed.startsWith('PARTIAL:')) {
            final partial = trimmed.substring(8).trim();
            if (partial.isNotEmpty) {
              _liveTranscription = partial;
              _audioLevel = 0.75;
              notifyListeners();
              _restartSilenceTimer();
            }
          } else if (trimmed.startsWith('LEVEL:')) {
            final lvlInt = int.tryParse(trimmed.substring(6)) ?? 0;
            _audioLevel = (lvlInt / 100.0).clamp(0.0, 1.0);
            notifyListeners();
          } else if (trimmed == 'SILENCE' || trimmed == 'NO_MIC') {
            if (_liveTranscription.isNotEmpty) {
              _onSpeechCompleted();
            } else {
              _status = SpeechStatus.idle;
              _audioLevel = 0.0;
              notifyListeners();
            }
          }
        },
        onError: (err) {
          debugPrint('[SpeechRecognitionService:Native] Mic error: $err');
        },
        onDone: () {
          if (_status == SpeechStatus.listening && _liveTranscription.isNotEmpty) {
            _onSpeechCompleted();
          }
        },
      );
    } catch (e) {
      debugPrint('[SpeechRecognitionService:Native] Failed to start Windows mic: $e');
    }
  }

  /// Automatically triggered when speech recognition finishes or silence is detected (Google Voice Search style)
  void _onSpeechCompleted() {
    _silenceTimer?.cancel();
    _speechTimeoutTimer?.cancel();
    _cleanupProcess();

    if (_status == SpeechStatus.listening) {
      _audioLevel = 0.0;
      _status = SpeechStatus.done;
      notifyListeners();
    }
  }

  /// Restarts silence debounce timer: triggers execution 1100ms after user stops speaking
  void _restartSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(milliseconds: 2800), () {
      if (_status == SpeechStatus.listening && _liveTranscription.isNotEmpty) {
        _onSpeechCompleted();
      }
    });
  }

  /// Update transcription from speech engine, test simulation, or keyboard
  void updateTranscription(String text) {
    _liveTranscription = text;
    _audioLevel = 0.8;
    notifyListeners();
    _restartSilenceTimer();
  }

  /// Stop listening and finalize captured speech
  void stopListening() {
    _generation++;
    _starting = false;
    _silenceTimer?.cancel();
    _speechTimeoutTimer?.cancel();
    _cleanupProcess();

    if (_speechToText.isListening) {
      _speechToText.stop();
    }

    if (_status == SpeechStatus.listening) {
      _audioLevel = 0.0;
      _status = _liveTranscription.trim().isEmpty ? SpeechStatus.idle : SpeechStatus.done;
      notifyListeners();
    }
  }

  void _cleanupProcess() {
    try {
      if (_speechToText.isListening) {
        _speechToText.stop();
      }
      _stdoutSub?.cancel();
      _activeProcess?.kill();
    } catch (_) {}
    _stdoutSub = null;
    _activeProcess = null;
  }

  /// Reset speech state
  void reset() {
    _generation++;
    _starting = false;
    _silenceTimer?.cancel();
    _speechTimeoutTimer?.cancel();
    _cleanupProcess();

    _status = SpeechStatus.idle;
    _liveTranscription = '';
    _audioLevel = 0.0;
    _errorMessage = '';
    notifyListeners();
  }

  /// Set error
  void setError(String error) {
    _silenceTimer?.cancel();
    _speechTimeoutTimer?.cancel();
    _cleanupProcess();

    _status = SpeechStatus.error;
    _audioLevel = 0.0;
    _errorMessage = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _speechTimeoutTimer?.cancel();
    _cleanupProcess();
    super.dispose();
  }
}
