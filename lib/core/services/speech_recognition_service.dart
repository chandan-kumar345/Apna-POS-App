import 'dart:async';
import 'package:flutter/foundation.dart';

enum SpeechStatus { idle, listening, processing, done, error }

class SpeechRecognitionService extends ChangeNotifier {
  static final SpeechRecognitionService _instance = SpeechRecognitionService._internal();
  factory SpeechRecognitionService() => _instance;
  SpeechRecognitionService._internal();

  SpeechStatus _status = SpeechStatus.idle;
  SpeechStatus get status => _status;
  bool get isListening => _status == SpeechStatus.listening;

  String _currentLocale = 'hinglish'; // 'hinglish', 'hi_IN', 'en_IN'
  String get currentLocale => _currentLocale;

  String _liveTranscription = '';
  String get liveTranscription => _liveTranscription;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  Timer? _silenceTimer;
  Timer? _simulationTimer;

  // Preset sample commands for testing in noisy environments / desktop testing
  static const List<String> sampleHinglishPhrases = [
    'Table 5 pe do butter naan aur ek paneer tikka laga do',
    'Table 12 mein ek coke aur do butter naan add karo',
    'Table 8 ka bill bana do',
    'Do butter naan aur ek dal makhani',
    'Table 4 se ek butter naan hata do',
    'Paneer tikka spicy kar do',
    'Table 5 ka KOT bhej do',
    'Hey Chotu, table 15 pe teen butter naan laga do',
  ];

  static const List<String> sampleEnglishPhrases = [
    'Add one paneer tikka to table 5',
    'Add two butter naan and one dal makhani to table 12',
    'Table 8 generate bill',
    'Remove one coke from table 4',
  ];

  void setLocale(String locale) {
    _currentLocale = locale;
    notifyListeners();
  }

  /// Start listening for voice input
  Future<void> startListening({
    String? initialText,
    Duration silenceTimeout = const Duration(seconds: 4),
  }) async {
    _status = SpeechStatus.listening;
    _liveTranscription = initialText ?? '';
    _errorMessage = '';
    notifyListeners();

    _silenceTimer?.cancel();
    _silenceTimer = Timer(silenceTimeout, () {
      if (_status == SpeechStatus.listening) {
        stopListening();
      }
    });
  }

  /// Simulate live streaming speech recognition for testing/verification
  void simulateSpeechInput(String phrase) {
    _simulationTimer?.cancel();
    _silenceTimer?.cancel();

    _status = SpeechStatus.listening;
    _liveTranscription = '';
    _errorMessage = '';
    notifyListeners();

    final words = phrase.split(' ');
    int index = 0;

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 180), (timer) {
      if (index < words.length) {
        _liveTranscription = words.sublist(0, index + 1).join(' ');
        notifyListeners();
        index++;
      } else {
        timer.cancel();
        _status = SpeechStatus.done;
        notifyListeners();
      }
    });
  }

  /// Update transcription from speech engine or text input
  void updateTranscription(String text) {
    _liveTranscription = text;
    notifyListeners();
  }

  /// Stop listening
  void stopListening() {
    _silenceTimer?.cancel();
    _simulationTimer?.cancel();
    if (_status == SpeechStatus.listening) {
      _status = SpeechStatus.done;
      notifyListeners();
    }
  }

  /// Reset speech state
  void reset() {
    _silenceTimer?.cancel();
    _simulationTimer?.cancel();
    _status = SpeechStatus.idle;
    _liveTranscription = '';
    _errorMessage = '';
    notifyListeners();
  }

  /// Set error
  void setError(String error) {
    _silenceTimer?.cancel();
    _simulationTimer?.cancel();
    _status = SpeechStatus.error;
    _errorMessage = error;
    notifyListeners();
  }
}
