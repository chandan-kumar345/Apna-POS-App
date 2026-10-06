import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  static const String _prefKeySoundEnabled = 'sound_feedback_enabled';
  static bool soundEnabled = true;

  AudioPlayer? _buttonPlayer;
  AudioPlayer? _keyPlayer;
  AudioPlayer? _notificationPlayer;

  bool _isInitialized = false;
  int _lastButtonClickTime = 0;
  int _lastKeyPressTime = 0;
  int _lastNotificationSoundTime = 0;

  /// Initialize sound service and preload audio sources lazily
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      soundEnabled = prefs.getBool(_prefKeySoundEnabled) ?? true;

      _buttonPlayer = AudioPlayer();
      _keyPlayer = AudioPlayer();
      _notificationPlayer = AudioPlayer();

      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
        await _buttonPlayer?.setPlayerMode(PlayerMode.lowLatency);
        await _keyPlayer?.setPlayerMode(PlayerMode.lowLatency);
        await _notificationPlayer?.setPlayerMode(PlayerMode.lowLatency);
      }

      await _buttonPlayer?.setReleaseMode(ReleaseMode.stop);
      await _keyPlayer?.setReleaseMode(ReleaseMode.stop);
      await _notificationPlayer?.setReleaseMode(ReleaseMode.stop);

      await _buttonPlayer?.setSource(AssetSource('sounds/ios_click.wav'));
      await _keyPlayer?.setSource(AssetSource('sounds/ios_keypress.wav'));
      await _notificationPlayer?.setSource(AssetSource('sounds/Notification_sound.mp3'));

      // Clean, crisp acoustic volumes
      await _buttonPlayer?.setVolume(0.40);
      await _keyPlayer?.setVolume(0.30);
      await _notificationPlayer?.setVolume(0.95);

      _isInitialized = true;
    } catch (_) {
      _isInitialized = false;
    }
  }

  /// Toggle sound enabled/disabled setting
  static Future<void> setSoundEnabled(bool enabled) async {
    soundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeySoundEnabled, enabled);
    } catch (_) {}
  }

  /// Play notification mp3 sound whenever a push or notification arrives
  static void playNotificationSound() {
    if (!soundEnabled) return;

    // Debounce within 400ms to avoid overlapping audio
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _instance._lastNotificationSoundTime < 400) {
      return;
    }
    _instance._lastNotificationSoundTime = now;

    // Trigger haptic notification feedback
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    if (_instance._isInitialized) {
      _instance._playNotificationAsset();
    } else {
      _instance.init().then((_) => _instance._playNotificationAsset()).catchError((_) {});
    }
  }

  void _playNotificationAsset() async {
    try {
      await _notificationPlayer?.stop();
      await _notificationPlayer?.play(AssetSource('sounds/Notification_sound.mp3'));
    } catch (_) {}
  }

  /// Play light button click sound on button/interactive tap with safe debouncing
  static void playButtonClick() {
    if (!soundEnabled) return;

    // Strong debounce within 140ms to protect Android message queue from flooding
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _instance._lastButtonClickTime < 140) {
      return;
    }
    _instance._lastButtonClickTime = now;

    // Fast native hardware sound & haptic feedback
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    // Low-latency asset playback
    if (_instance._isInitialized) {
      _instance._playButtonAsset();
    }
  }

  void _playButtonAsset() {
    try {
      _buttonPlayer?.play(AssetSource('sounds/ios_click.wav'), mode: PlayerMode.lowLatency);
    } catch (_) {}
  }

  /// Play light keypress sound on text field tap or typing with safe debouncing
  static void playKeyPress() {
    if (!soundEnabled) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _instance._lastKeyPressTime < 120) {
      return;
    }
    _instance._lastKeyPressTime = now;

    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    if (_instance._isInitialized) {
      _instance._playKeyAsset();
    }
  }

  void _playKeyAsset() {
    try {
      _keyPlayer?.play(AssetSource('sounds/ios_keypress.wav'), mode: PlayerMode.lowLatency);
    } catch (_) {}
  }
}
