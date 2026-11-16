import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'chotu_service.dart';
import 'speech_recognition_service.dart';
import 'chotu_tts_service.dart';

/// Foreground, time-bounded standby. Android's general speech recognizer is
/// deliberately not used as an always-on background hotword engine.
class ChotuActivationService extends ChangeNotifier {
  static final _instance = ChotuActivationService._();
  factory ChotuActivationService() => _instance;
  ChotuActivationService._();
  static const channel = MethodChannel('com.apnapos.app/chotu_activation');
  final _speech = SpeechRecognitionService();
  VoidCallback? _onActivate;
  Timer? _expiry;
  Timer? _restart;
  bool _armed = false;
  bool _suspended = true;
  bool _listening = false;
  bool _screenLocked = false;
  int _epoch = 0;
  bool get isArmed => _armed;
  bool get isScreenLocked => _screenLocked;

  static bool isWakePhrase(String text) => RegExp(
    r'^(?:hello|hey|हेलो|हैलो|हे)\s+(?:chotu|chhotu|छोटू|छोटु)[.!?,।\s]*$',
    caseSensitive: false,
  ).hasMatch(text.trim());

  void attach(VoidCallback onActivate) {
    _onActivate = onActivate;
    _speech.addListener(_onSpeech);
    channel.setMethodCallHandler((call) async {
      if (call.method == 'activate') await consumeAssistantRequest();
      if (call.method == 'deactivate') {
        _screenLocked = true;
        disarm();
        _speech.reset();
        ChotuTtsService().stop();
      }
      if (call.method == 'unlocked') _screenLocked = false;
    });
    unawaited(consumeAssistantRequest());
  }

  void detach() {
    disarm();
    _speech.removeListener(_onSpeech);
    _onActivate = null;
    channel.setMethodCallHandler(null);
  }

  Future<void> consumeAssistantRequest() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (await channel.invokeMethod<bool>('consumeActivation') == true) {
        disarm();
        _onActivate?.call();
      }
    } on PlatformException catch (_) {
      /* Leave normal POS usable. */
    } on MissingPluginException catch (_) {}
  }

  Future<void> openAssistantSettings() async {
    await channel.invokeMethod<void>('openAssistantSettings');
  }

  Future<bool> arm() async {
    final epoch = ++_epoch;
    if (_screenLocked ||
        _onActivate == null ||
        !await ChotuService().checkBackendHealth() ||
        epoch != _epoch ||
        !await _speech.requestMicrophonePermission() ||
        epoch != _epoch ||
        _onActivate == null) {
      return false;
    }
    _armed = true;
    _expiry?.cancel();
    _expiry = Timer(const Duration(minutes: 2), disarm);
    notifyListeners();
    _schedule();
    return true;
  }

  void suspend(bool value) {
    _suspended = value;
    if (value) {
      _restart?.cancel();
      if (_listening) {
        _listening = false;
        _speech.reset();
      }
    } else {
      _schedule();
    }
  }

  void disarm() {
    _epoch++;
    _armed = false;
    _expiry?.cancel();
    _restart?.cancel();
    if (_listening) {
      _listening = false;
      _speech.reset();
    }
    notifyListeners();
  }

  void _schedule() {
    _restart?.cancel();
    if (!_armed || _suspended || _listening || _screenLocked) return;
    _restart = Timer(const Duration(milliseconds: 900), () async {
      if (!_armed || _suspended || _listening || _speech.isListening) return;
      _listening = true;
      await _speech.startListening(timeout: const Duration(seconds: 12));
    });
  }

  void _onSpeech() {
    if (!_armed || _suspended || !_listening) return;
    if (_speech.status == SpeechStatus.done &&
        isWakePhrase(_speech.liveTranscription)) {
      disarm();
      _onActivate?.call();
    } else if (_speech.status == SpeechStatus.error) {
      // Avoid repeated permission prompts/network failures/microphone churn.
      disarm();
    } else if (_speech.status == SpeechStatus.done ||
        _speech.status == SpeechStatus.idle) {
      _listening = false;
      _schedule();
    }
  }
}
